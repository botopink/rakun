// rakun — the auto-configuration registry, node half.
//
// WHAT LIVES HERE AND WHY. botopink has no top-level mutable state, so a
// registry lives in the host. What this one stores is four STRINGS per
// registration — the name, the condition blob, the `before` list and the
// `after` list — plus one decision per name once the apply pass has run.
//
// That measurement is the whole design. Front 06 stores a bean FACTORY, a
// lifecycle THUNK, a listener CLOSURE and an exit-code GENERATOR, and no
// string table holds a fun, so its grammar had to stay in botopink while the
// table lived in the host. Here NOTHING is a fun: the blob grammar, the
// topological sort, the evaluation of every condition record, the refusal
// texts and the rendered report are all botopink (`conditions.bp`,
// `autoconfig.bp`, `condition_report.bp`), compiled to both targets. This file
// appends a row and answers a lookup. It never splits a blob, never compares a
// property and never decides whether anything matched — which is what makes
// "the two rows cannot disagree about what was auto-configured" a property
// rather than a hope.
//
// The BEAM twin is `./sidecars/rakun_autoconfig.erl`; the two answer the same
// cells with the same values, and `test/autoconfig_test.bp` and
// `test/conditions_test.bp` are one set of assertions run on both rows.

// { name, conditions, before, after } in registration order.
const entries = [];
// name -> the bean type the entry provides once it is applied
const provides = new Map();
// name -> { state, reason }
const decisions = new Map();
// "" until the apply pass seals the table; then the sorted order, comma-joined.
let sealed = false;
let order = "";

function find(name) {
  for (const e of entries) if (e.name === name) return e;
  return null;
}

// Append-only. A second registration of one name REPLACES the first rather
// than appending a twin: a module loaded twice must not double a row, and a
// row that appears twice would make the report lie about the table's size.
export function autoRegister(name, conditions, before, after) {
  const found = find(name);
  if (found) {
    found.conditions = conditions;
    found.before = before;
    found.after = after;
    return entries.length;
  }
  entries.push({ name, conditions, before, after });
  return entries.length;
}

// What an entry contributes to the registered set once it matches. It is NOT a
// condition and therefore not a record of the condition blob: `autoConditions`
// has to answer the blob the annotations produced, verbatim, or it stops being
// the comptime half's assertion point.
export function autoProvides(name, typeName) {
  provides.set(name, typeName);
  return provides.size;
}

export function autoProvided(name) {
  const v = provides.get(name);
  return v ? v : "";
}

export function autoNames() {
  return entries.map((e) => e.name).join(",");
}

export function autoCount() {
  return entries.length;
}

export function autoConditions(name) {
  const e = find(name);
  return e ? e.conditions : "";
}

export function autoBefore(name) {
  const e = find(name);
  return e ? e.before : "";
}

export function autoAfter(name) {
  const e = find(name);
  return e ? e.after : "";
}

export function autoKnown(name) {
  return find(name) !== null;
}

export function autoDecide(name, state, reason) {
  decisions.set(name, { state, reason });
  return decisions.size;
}

export function autoState(name) {
  const d = decisions.get(name);
  return d ? d.state : "";
}

export function autoReason(name) {
  const d = decisions.get(name);
  return d ? d.reason : "";
}

// The seal is what makes `autoConfigure()` idempotent and what lets the report
// say "never called" instead of printing an empty table.
export function autoSeal(sortedOrder) {
  sealed = true;
  order = sortedOrder;
  return 1;
}

export function autoSealed() {
  return sealed;
}

export function autoOrder() {
  return order;
}

// Registrations survive; only the decisions and the seal are dropped. A test
// re-applies over the same table, which is the shape every assertion here
// wants.
export function autoUnseal() {
  decisions.clear();
  sealed = false;
  order = "";
  return 0;
}

export function autoReset() {
  entries.length = 0;
  provides.clear();
  decisions.clear();
  sealed = false;
  order = "";
  return 0;
}

// The `--debug` printer. `println` is a `libs/std` builtin with no erlang
// lowering (measured: the emitted module calls a bare local `println/1`, `erlc`
// refuses it, and the test runner's `__bp_load_siblings/0` then skips the whole
// module SILENTLY, so every function in it answers `undef`). One line of host
// per row costs less than a report that only prints on one target.
export function printLine(line) {
  console.log(line);
  return 1;
}
