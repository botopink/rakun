// rakun — the SSR pipeline's node half.
//
// WHAT LIVES HERE AND WHY. Three things this front needs are not values a
// string table can hold, and botopink has no top-level mutable state:
//
//   1. the installed `RenderHooks` — a record of seven FUNCTIONS (decision 77);
//   2. the gather over unstarted THUNKS, one per unit of server work;
//   3. two per-render ordinals (the layout depth a layout reads back, and the
//      navigation counter a `data-onze-t` key carries).
//
// That is front 22's test — "is the thing being stored pure?" — answered the
// same way front 22, front 62 and front 06 answered it, and the opposite way
// front 05 did: front 05's readers were pure, so a host file would have been a
// second copy of something botopink can do. A closure is not.
//
// WHAT DOES *NOT* LIVE HERE. The escaping, the walker, the composition order,
// the payload format, the document shell and the chunk protocol are botopink in
// `ssr.bp`, compiled to both targets. This file knows nothing about HTML.
//
// The BEAM twin is `./sidecars/rakun_ssr.erl`; the two answer the same cells
// with the same values, and `test/ssr_test.bp` is one set of assertions run on
// both rows. The two rows differ in exactly one place and it is stated rather
// than papered over: `all` spawns a process per thunk on the BEAM and node has
// no process, so node runs the thunks in order. `concurrent()` answers which
// row you are on, and the one timing assertion in the suite reads it.
//
// `__onzeFill` is the other half of this file and is not a host cell at all: it
// is the browser function the streaming fill chunk calls, shipped with the
// client bundle (front 68) and asserted here against a DOM fake.

let hooks = null;
let selected = 0;
let nav = 0;
let settleOrder = "";

export function setHooks(h) {
  hooks = h;
  return 0;
}

export function hasHooks() {
  return hooks !== null;
}

export function hooksOr(fallback) {
  return hooks === null ? fallback : hooks;
}

export function setSelected(depth) {
  selected = depth;
  return depth;
}

export function selectedDepth() {
  return selected;
}

export function nextNav() {
  nav = nav + 1;
  return nav;
}

// Run every thunk and answer the results BY INDEX. On this row there is no
// process: the thunks are started in order and awaited together, so a thunk
// that blocks the event loop blocks the ones after it. That is why
// `concurrent()` answers false here — no assertion claims otherwise.
export async function all(thunks) {
  const order = [];
  const started = thunks.map((t, i) =>
    Promise.resolve()
      .then(() => t())
      .then((v) => {
        order.push(i);
        return v;
      }),
  );
  const out = await Promise.all(started);
  settleOrder = order.join(",");
  return out;
}

// The order the LAST `all` in this process settled in, as indices. Front 23's
// fill chunks go out in resolution order, and this is where that order comes
// from: a gather by index cannot also answer it.
export function settledOrder() {
  return settleOrder;
}

export function concurrent() {
  return false;
}

export function reset() {
  hooks = null;
  selected = 0;
  nav = 0;
  settleOrder = "";
  return 0;
}

// ── the browser half ────────────────────────────────────────────────────────
//
// A fill chunk is `<template data-onze-f="h1">…</template><script>__onzeFill("h1")</script>`.
// `__onzeFill` moves the template's content into the hole and removes both
// markers. It is IDEMPOTENT: a second call for the same id finds no template,
// or finds no hole, and leaves the DOM exactly as it was — a streamed response
// that is replayed, or a bundle that runs the tail twice, must not double a
// section of the page.
export function __onzeFill(id, doc) {
  const d = doc || (typeof document === "undefined" ? null : document);
  if (d === null) return 0;
  const tpl = d.querySelector('template[data-onze-f="' + id + '"]');
  const hole = d.querySelector('[data-onze-h="' + id + '"]');
  if (tpl === null || hole === null) return 0;
  hole.innerHTML = tpl.innerHTML;
  hole.removeAttribute("data-onze-h");
  tpl.remove();
  return 1;
}
