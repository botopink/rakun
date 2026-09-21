// rakun-validation — the host half, node: a constraint registry and one
// request-scoped accumulator.
//
// WHAT LIVES HERE AND WHY. botopink has no top-level mutable state and no
// mutable record field, so the two things this module needs that are not a
// value live in the host: (1) the SPI registry, which maps a name to a
// `Constraint` VALUE — not a string, so no property table can hold it; and
// (2) the binding accumulator, which the `bind…` readers append to and
// `bindingReport()` drains, because records are immutable and a binder record
// cannot accumulate as it goes.
//
// WHAT DOES *NOT* LIVE HERE. Every constraint predicate, every message
// template, every refusal text, the constraint table and the report's JSON are
// botopink, compiled to both rows. This file holds a Map and an array. It never
// decides whether a value is acceptable — which is what makes "the server and
// the client run the same predicate" a property rather than a hope.
//
// THE SCOPE. On the BEAM a request is served by a process and the twin hangs
// the accumulator off that process's dictionary, so two concurrent requests
// cannot see each other's violations. Node has no such scope: the twin is a
// module global, which is the same thing for rakun's node server, because
// `runtime.mjs`'s dispatcher runs one request to completion before it reads the
// next.

const constraints = new Map(); // name -> the registered Constraint value

export function registerConstraint(name, c) {
  constraints.set(name, c);
  return constraints.size;
}
export function hasConstraint(name) {
  return constraints.has(name);
}
// Guarded by `hasConstraint` at every call site in `spi.bp`: an unregistered
// name is a VIOLATION there, never a lookup that answers a stand-in here.
export function constraintOf(name) {
  return constraints.get(name);
}
const codes = new Map(); // name -> the constraint's own `code()`

export function putCode(name, code) {
  codes.set(name, code);
  return codes.size;
}
export function codeOf(name) {
  return codes.has(name) ? codes.get(name) : "";
}
export function registeredNames() {
  return Array.from(constraints.keys()).join(",");
}
export function constraintReset() {
  constraints.clear();
  codes.clear();
  return 0;
}

let pending = []; // the violations bound since the last drain

export function bindPush(v) {
  pending.push(v);
  return pending.length;
}
export function bindCount() {
  return pending.length;
}
// Drains: the next request on the same process starts clean, which is the
// property `bindingReport()` is specified to have.
export function bindDrain() {
  const out = pending;
  pending = [];
  return out;
}
export function bindReset() {
  pending = [];
  return 0;
}

// The isolation claim, node half. There is no second scope on this row: the
// accumulator is a module global and `runtime.mjs`'s dispatcher runs one
// request to completion before it reads the next, the same claim
// `request_context.mjs` makes about the request frame. The BEAM half MEASURES
// the same answer by spawning; this one states it.
export function bindIsolated() {
  return true;
}
