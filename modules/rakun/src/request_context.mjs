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

// The area deferred work runs in. It deliberately OUTLIVES the frame: a child
// runs after `endRequest` erased the key, so its bookkeeping cannot live there.
let after = null;
const ticks = new Map(); // named counters a test's loader bumps

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
