// rakun — the container's doors, node half: the bean registry, the lifecycle
// table, the listener table, the request-scope cache and the exit-code
// generators.
//
// WHAT LIVES HERE AND WHY. botopink has no top-level mutable state, so a
// registry lives in the host — the same reason `runtime.mjs` holds the scan
// list and the router table, and `file_router.mjs` the App-Router table. What
// this one stores is a FACTORY, a lifecycle THUNK, a listener CLOSURE and an
// exit-code GENERATOR. None of them is a string, so no string property table
// holds them, which is the measurement front 22 and front 62 each made and
// front 05 made the other way.
//
// WHAT DOES *NOT* LIVE HERE. The bean record's grammar, the choice between two
// candidates, every refusal message, the boot-event order and the reverse of
// the pre-destroy pass are botopink (`context.bp`, `lifecycle.bp`,
// `events.bp`), compiled to both targets. This file is handed a finished
// `path|type|qualifier|scope|primary|lazy` LINE and appends it beside its
// function; it never parses one, never compares a qualifier and never decides
// which of two beans wins. Neither host knows the format, which is what makes
// "the two rows cannot disagree about what the container holds" a property
// rather than a hope.
//
// The BEAM twin is `./sidecars/rakun_context.erl`; the two answer the same
// cells with the same values, and `test/context_test.bp` and
// `test/events_test.bp` are one set of assertions run on both rows.

// ── beans ───────────────────────────────────────────────────────────────────

const beans = []; // { record: string, factory: function }

export function beanRegister(record, factory) {
  beans.push({ record, factory });
  return beans.length;
}

// The table, in registration order, `\n`-separated — exactly the blob
// `parseBeans` reads.
export function beanTable() {
  return beans.map((b) => b.record).join("\n");
}

export function beanCount() {
  return beans.length;
}

export function beanHasRecord(record) {
  return beans.some((b) => b.record === record);
}

// Invoke the factory stored under this EXACT record line. botopink picked the
// line out of `beanTable()`; this is an equality test and a call.
export function beanInvoke(record) {
  for (const b of beans) if (b.record === record) return b.factory();
  return null;
}

// The same call with the value discarded, for the eager pass: the caller has no
// type to bind the result to, and a construction that raises must still raise.
export function beanTouch(record) {
  for (const b of beans) {
    if (b.record === record) {
      b.factory();
      return 1;
    }
  }
  return 0;
}

// The eager pass needs the FAILURE, not the halt: `bootSequence` publishes
// `ApplicationFailed` instead of the tail and only then raises, so it has to see
// the construction fail without being taken down by it. Answers "" on success
// and the error text otherwise.
export function beanTry(record) {
  for (const b of beans) {
    if (b.record === record) {
      try {
        b.factory();
        return "";
      } catch (e) {
        return e && e.message ? e.message : String(e);
      }
    }
  }
  return "";
}

export function beanReset() {
  beans.length = 0;
  return 0;
}

// ── request scope ───────────────────────────────────────────────────────────
//
// `singleton` one scope down. On the BEAM this is the process dictionary, so
// two concurrent requests are two processes and get their own instance for
// free; node is single-threaded, so the scope is the bracket the dispatcher
// opens and `requestScopeEnd` closes.

let requestCache = new Map();

export function requestScoped(key, build) {
  if (requestCache.has(key)) return requestCache.get(key);
  const value = build();
  requestCache.set(key, value);
  return value;
}

export function requestScopeEnd() {
  const n = requestCache.size;
  requestCache = new Map();
  return n;
}

// ── lifecycle ───────────────────────────────────────────────────────────────
//
// A `#[postConstruct]` runs exactly once for a singleton however many sites
// resolve it, so an entry that has run is marked and skipped — the pass is
// idempotent, not the caller's responsibility.

const hooks = []; // { record: "owner|method|phase|order", run: function, done: bool }

export function lifecycleRegister(record, run) {
  hooks.push({ record, run, done: false });
  return hooks.length;
}

export function lifecycleTable() {
  return hooks.map((h) => h.record).join("\n");
}

function hookPhase(record) {
  return record.split("|")[2];
}

function hookOrder(record) {
  const n = parseInt(record.split("|")[3], 10);
  return Number.isNaN(n) ? 0 : n;
}

function hookOwnerMethod(record) {
  const f = record.split("|");
  return f[0] + "|" + f[1];
}

// Run every not-yet-run entry of `phase`, by `order` then registration order —
// REVERSED for `pre`, which is reverse dependency order because a component is
// registered after the components it was constructed from. Answers the
// `owner|method` of each entry that raised, `\n`-separated; `tolerant` decides
// whether the pass stops at the first one. The caller writes the message.
export function lifecycleRun(phase, tolerant) {
  const picked = [];
  for (let i = 0; i < hooks.length; i++) {
    if (!hooks[i].done && hookPhase(hooks[i].record) === phase) picked.push(i);
  }
  picked.sort((a, b) => {
    const d = hookOrder(hooks[a].record) - hookOrder(hooks[b].record);
    return d !== 0 ? d : a - b;
  });
  if (phase === "pre") picked.reverse();
  const failed = [];
  for (const i of picked) {
    hooks[i].done = true;
    try {
      hooks[i].run();
    } catch (e) {
      failed.push(hookOwnerMethod(hooks[i].record));
      if (!tolerant) break;
    }
  }
  return failed.join("\n");
}

export function lifecycleReset() {
  hooks.length = 0;
  return 0;
}

// ── listeners ───────────────────────────────────────────────────────────────

const listeners = []; // { record: "event|owner", run: function }
const listenerFailed = [];

export function listenerRegister(record, run) {
  listeners.push({ record, run });
  return listeners.length;
}

export function listenerTable() {
  return listeners.map((l) => l.record).join("\n");
}

// Dispatch is synchronous and in registration order. A listener that raises is
// recorded and the sequence continues, because a broken audit listener must not
// take the boot down. Answers how many listeners ran.
export function listenerEmit(eventName, event) {
  let delivered = 0;
  for (const l of listeners) {
    if (l.record.split("|")[0] !== eventName) continue;
    delivered += 1;
    try {
      l.run(event);
    } catch (e) {
      listenerFailed.push(l.record);
    }
  }
  return delivered;
}

export function listenerFailures() {
  return listenerFailed.join("\n");
}

export function listenerReset() {
  listeners.length = 0;
  listenerFailed.length = 0;
  return 0;
}

// ── exit codes ──────────────────────────────────────────────────────────────

const exits = []; // { name: string, gen: function }

export function exitRegister(name, gen) {
  exits.push({ name, gen });
  return exits.length;
}

// Every generator called, its answer `\n`-separated in registration order. The
// caller takes the maximum — arithmetic is botopink's.
export function exitValues() {
  return exits.map((e) => String(e.gen())).join("\n");
}

export function exitReset() {
  exits.length = 0;
  return 0;
}

// ── the test seam: an ordered note log and a counter table ──────────────────
//
// The boot sequence is asserted by registering a listener for every one of the
// eight events that appends its name here, then comparing the log to the
// documented order — which catches a reordering a per-event test would not.

const notes = [];
const counters = new Map();

export function note(line) {
  notes.push(line);
  return notes.length;
}

export function noteLog() {
  return notes.join("\n");
}

export function noteReset() {
  notes.length = 0;
  counters.clear();
  return 0;
}

export function bump(key) {
  const n = (counters.get(key) || 0) + 1;
  counters.set(key, n);
  return n;
}

export function counted(key) {
  return counters.get(key) || 0;
}
