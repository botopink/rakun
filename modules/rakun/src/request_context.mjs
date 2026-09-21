// rakun — the request context, node half: the frame the serving scope hangs on.
//
// WHAT LIVES HERE AND WHY. botopink has no top-level mutable state and no
// mutable record field, so the request frame has to live in the host — the same
// reason `runtime.mjs` holds the scan list and `file_router.mjs` holds the route
// table. And the frame is emphatically NOT pure: it carries a queue of deferred
// THUNKS and a memo table of arbitrary typed VALUES, neither of which a string
// table can hold. That is front 22's test, not front 05's, so this front ships
// both host files rather than writing itself over `std`.
//
// WHAT DOES *NOT* LIVE HERE. The phase table, the header wire grammar, the
// cookie grammar, the `Set-Cookie` serialization, the draft-mode signature and
// every refusal message are botopink, compiled to both targets. This file holds
// a keyed slot store, a keyed line list, a queue, a table and a counter. It
// never parses a header, never builds a cookie and never decides what a phase
// permits — which is what makes "the two rows cannot disagree about what a
// request context says" a property rather than a hope.
//
// THE SCOPE. On the BEAM a request is served by a process and the twin hangs
// the frame off that process's dictionary. Node has no such scope: the twin is
// a module global, which is the same thing for rakun's node server, because
// `runtime.mjs`'s dispatcher runs one request to completion before it reads the
// next. The epoch is what makes a leak loud on either row.

let seq = 0; // the epoch source: strictly increasing, never reused
let frame = null;

// The area deferred work runs in. It deliberately OUTLIVES the frame: the work
// runs after `endRequest` erased the key, so its bookkeeping cannot live there.
const area = { queued: [], frozen: null, timeout: 0, id: "", log: [] };
const stats = new Map(); // started · ok · failed · killed

// The shared scratch a deferred child or a memo loader writes where the parent
// can read it. On the BEAM this is ETS, because a child is a different process;
// here one Map is the same thing.
const shared = new Map();

function live() {
  return frame !== null;
}

// ── the frame ────────────────────────────────────────────────────────────────

export function begin(id) {
  seq += 1;
  frame = {
    epoch: seq,
    slots: new Map([["id", id]]),
    cookies: [], // { name, line } — insertion-ordered, replaced by name
    deferred: [], // thunks
    memo: new Map(), // key -> { state: "resolved", value }
  };
  return seq;
}

export function end() {
  frame = null;
  return 0;
}

export function isLive() {
  return live();
}

export function epoch() {
  return live() ? frame.epoch : 0;
}

export function slot(name) {
  if (!live()) return "";
  const v = frame.slots.get(name);
  return v === undefined ? "" : v;
}

export function putSlot(name, value) {
  if (live()) frame.slots.set(name, value);
  return 0;
}

// ── the queued `Set-Cookie` lines ────────────────────────────────────────────
//
// A keyed line list, insertion-ordered and replaced by key — the same primitive
// `runtime.mjs`'s `setReplyHeader` already is. This file does not know what a
// cookie looks like: it is handed a name and a finished line.

export function queueCookie(name, line) {
  if (!live()) return 0;
  const at = frame.cookies.findIndex((c) => c.name === name);
  if (at >= 0) frame.cookies[at] = { name, line };
  else frame.cookies.push({ name, line });
  return frame.cookies.length;
}

export function cookieBlob() {
  if (!live()) return "";
  return frame.cookies.map((c) => c.line).join("\n");
}

// ── deferred work ────────────────────────────────────────────────────────────
//
// THE ONE PLACE THE TWO ROWS ARE NOT THE SAME MECHANISM, stated plainly. On the
// BEAM each thunk is a `spawn_monitor` child with a frozen copy of the frame,
// and a child that outlives the budget is KILLED. Node has no process and
// cannot interrupt a synchronous function: it runs each thunk in a try/catch
// with the frozen copy installed, and a thunk that OVERRAN the budget is
// counted and logged in the same slot the BEAM kills into. The counters and the
// log agree; the interruption is real on one row and after the fact on the
// other, and no assertion here claims otherwise.

function bump(name, by) {
  stats.set(name, (stats.get(name) || 0) + by);
}

export function defer(work) {
  if (!live()) return 0;
  frame.deferred.push(work);
  return frame.deferred.length;
}

export function deferCount() {
  return live() ? frame.deferred.length : 0;
}

export function startDeferred(timeoutMs) {
  if (!live()) return 0;
  const slots = new Map(frame.slots);
  slots.set("phase", "after");
  area.frozen = {
    epoch: frame.epoch,
    slots,
    cookies: [],
    deferred: [],
    memo: new Map(frame.memo),
  };
  area.queued = frame.deferred.slice();
  area.timeout = timeoutMs;
  area.id = frame.slots.get("id") || "";
  bump("started", area.queued.length);
  return area.queued.length;
}

export function afterWait(budgetMs) {
  const jobs = area.queued;
  area.queued = [];
  const saved = frame;
  const deadline = Date.now() + budgetMs;
  let settled = 0;
  for (const job of jobs) {
    frame = area.frozen;
    const t0 = Date.now();
    try {
      job();
      const spent = Date.now() - t0;
      const overran = area.timeout > 0 && spent > area.timeout;
      if (overran) {
        bump("killed", 1);
        area.log.push("after: killed " + area.id + " after " + area.timeout + "ms");
      } else {
        bump("ok", 1);
      }
    } catch (e) {
      bump("failed", 1);
      const msg = e && e.message ? e.message : String(e);
      area.log.push("after: failed " + area.id + " " + msg);
    }
    settled += 1;
    if (Date.now() > deadline) break;
  }
  frame = saved;
  return settled;
}

export function afterStat(name) {
  return stats.get(name) || 0;
}

export function afterLog() {
  return area.log.join("\n");
}

export function afterReset() {
  area.queued = [];
  area.frozen = null;
  area.timeout = 0;
  area.id = "";
  area.log.length = 0;
  stats.clear();
  return 0;
}

// ── the shared scratch, and a blocking sleep ─────────────────────────────────

export function shareBump(key) {
  const n = (shared.get(key) || 0) + 1;
  shared.set(key, n);
  return n;
}

export function shareCount(key) {
  const v = shared.get(key);
  return typeof v === "number" ? v : 0;
}

export function sharePut(key, value) {
  shared.set(key, value);
  return 0;
}

export function shareGet(key) {
  const v = shared.get(key);
  return typeof v === "string" ? v : "";
}

export function shareReset() {
  shared.clear();
  return 0;
}

// A BLOCKING sleep, because the deferred-work assertions need a thunk that is
// still running. `Atomics.wait` is the only synchronous one node has.
export function sleep(ms) {
  if (ms > 0) {
    Atomics.wait(new Int32Array(new SharedArrayBuffer(4)), 0, 0, ms);
  }
  return 0;
}

// ── the per-request memo table ───────────────────────────────────────────────
//
// `rkSingleton` one scope down: answer the stored value, or run the thunk and
// store it. The table lives IN the frame, so it dies with the request — a memo
// that survives a request is a cache, and caches belong to front 12.
//
// Node has no process, so `preload` runs the loader immediately and stores the
// resolved value; the "pending" row of the front's table is a BEAM shape and
// this row can only ever be at the resolved one. Every assertion the front
// makes about preload — the loader runs once, the memo answers the preloaded
// value — holds either way; what differs is whether anything was ever in
// flight.

function memoBump(name) {
  if (!live()) return 0;
  const key = "memo:" + name;
  const n = (frame.slots.get(key) ? Number(frame.slots.get(key)) : 0) + 1;
  frame.slots.set(key, String(n));
  return n;
}

export function memoCount(name) {
  if (!live()) return 0;
  const v = frame.slots.get("memo:" + name);
  return v ? Number(v) : 0;
}

export function memoState(key) {
  if (!live()) return 0;
  return frame.memo.has(key) ? 1 : 0;
}

export function memoResolve(key, load) {
  if (!live()) return load();
  if (frame.memo.has(key)) {
    memoBump("hits");
    return frame.memo.get(key);
  }
  memoBump("misses");
  const value = load();
  if (live()) frame.memo.set(key, value);
  return value;
}

export function memoPreload(key, load) {
  if (!live()) return 0;
  if (frame.memo.has(key)) return 0;
  memoBump("misses");
  const value = load();
  if (live()) frame.memo.set(key, value);
  return 1;
}
