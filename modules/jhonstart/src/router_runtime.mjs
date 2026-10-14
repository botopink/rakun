// jhonstart — the router's host half on the js row (front 26).
//
// The route snapshot is one of the three things that CROSSES: the server fills
// it before the render, and the client rebuilds it from front 30's payload (`globals.payload`)
// on hydration and on every client-side transition. `router.bp` reads
// it through five cells; this module is what those cells are on node and in
// the browser, and `src/sidecars/jhonstart_router.erl` is the same five on the
// BEAM over the process dictionary.
//
// It is deliberately a plain module-global store and nothing else. The five
// values arrive already encoded exactly as the payload carries them (`p`, `m`,
// `q`, `r`, plus the per-layout `selected`), so this module parses nothing,
// matches nothing and knows no route table — a second matcher is a matcher
// that disagrees with the server about precedence on the routes nobody tested.
//
// `fill` is the only writer. A client navigation calls it with the values the
// payload carried and re-renders; the server adapter calls it once per request.
// Nothing here is reactive: re-rendering is the caller's job, because the
// router is a snapshot and not a subscription.

const store = {
  path: "",
  params: "",
  search: "",
  pattern: "",
  selected: 0,
};

export function path() {
  return store.path;
}

export function params() {
  return store.params;
}

export function search() {
  return store.search;
}

export function pattern() {
  return store.pattern;
}

export function selected() {
  return store.selected;
}

// Replace the whole snapshot. Every field at once, never one at a time: a
// half-updated snapshot is a component reading the previous route's params
// against the next route's pattern.
export function fill(p, m, q, r, s) {
  store.path = p;
  store.params = m;
  store.search = q;
  store.pattern = r;
  store.selected = s;
  return 0;
}

// The navigation verbs, all six behind one cell. On the server they record a
// redirect; here they are the History API, and `refresh`/`prefetch` are front
// 27's and front 29's to drive — the seam is here so that `router.bp` has one
// cell rather than six, and so that a verb nobody has wired yet is a no-op and
// not a crash.
//
// Every call is recorded first, so `lastNavigation()` answers on a node row
// that has no `history` at all — the same one-line assertion the erlang half
// answers with the redirect it recorded.
let lastNav = "";

export function navigate(kind, href) {
  lastNav = kind + " " + href;
  const h = typeof globalThis.history === "undefined" ? null : globalThis.history;
  if (h === null) return 0;
  if (kind === "push") h.pushState({}, "", href);
  if (kind === "replace") h.replaceState({}, "", href);
  if (kind === "back") h.back();
  if (kind === "forward") h.forward();
  return 0;
}

export function lastNavigation() {
  return lastNav;
}

// The render's DYNAMIC mark: set by the two readers of per-request input
// (`searchParams()` and front 28's `request()`), read by front 30's payload
// writer as `d`, cleared when a render starts. On node every render shares
// this module, so a boundary's mark is the page's mark already.
let dynamicMark = false;

export function markDynamic() {
  dynamicMark = true;
  return 0;
}

export function dynamic() {
  return dynamicMark;
}

export function resetDynamic() {
  dynamicMark = false;
  return 0;
}
