// jhonstart — the render's host half on the js row (front 30).
//
// Two kinds of cell live here.
//
// 1. PER-RENDER STATE, the twin of `sidecars/jhonstart_render.erl`: the
//    boundaries `Suspense` registers, the islands `mountIsland` registers, the
//    nearest not-found tree a signal met, the write counter behind the
//    `Response` guard, the navigation counter `data-jh-t` carries, the hooks
//    `setHooks` stored, and `eachCompleted` — the completion-order gather the
//    streamed render drives. botopink has no top-level mutable state, so this
//    state is the host's. On node it is one module global per process, so two
//    CONCURRENT renders in one node process share it; the server render is the
//    erlang row's, where each render is its own process.
//
// 2. THE BROWSER HALF, called only by onze front 68's generated entry: the
//    payload script's text (`payloadText`), the fill function registered under
//    `globals.fill` and the signal function under `globals.signal`. No
//    global name is spelled here — the entry passes the names the registry
//    derived.

let boundaries = [];
let treeNodes = [];
let islandRows = [];
let islandBase = 0;
let stash = null;
let writeCount = 0;
let navCounter = 0;
let hooksValue = null;
let holeCounter = 0;
let lateState = "";
let resolvedRows = [];
let styledSheetValue = null;

export function stateReset() {
  boundaries = [];
  treeNodes = [];
  islandRows = [];
  islandBase = 0;
  stash = null;
  writeCount = 0;
  holeCounter = 0;
  lateState = "";
  styledSheetValue = null;
  return 0;
}

// The render's `styled` sheet (front 119): what the components computed at
// render registered through `StyledContext`, a `styled` `Sheet` value kept
// opaquely — `styled_root.bp` adds to it, the sink reads it.
export function styledSheet(fallback) {
  return styledSheetValue === null ? fallback : styledSheetValue;
}

export function setStyledSheet(s) {
  styledSheetValue = s;
  return 0;
}

export function setLate(state) {
  if (lateState === "") lateState = state;
  return 0;
}

export function collectResolved(r) {
  resolvedRows.push(r);
  return resolvedRows.length;
}

export function takeResolved() {
  const out = resolvedRows;
  resolvedRows = [];
  return out;
}

export function late() {
  return lateState;
}

export function nextHoleOrdinal() {
  holeCounter += 1;
  return holeCounter;
}

export function pushBoundary(b) {
  boundaries.push(b);
  return boundaries.length;
}

// The boundary nodes a composition placed in its tree (decision 414): an
// error or a not-found boundary, its placeholder carrying the index.
export function pushNode(n) {
  treeNodes.push(n);
  return treeNodes.length - 1;
}

export function nodeAt(index) {
  return treeNodes[Number(index)];
}

export function takeBoundaries() {
  const out = boundaries;
  boundaries = [];
  return out;
}

export function nextIslandOrdinal() {
  return islandBase + islandRows.length;
}

export function pushIsland(row) {
  islandRows.push(row);
  return islandRows.length;
}

export function islands() {
  return Array.from(islandRows);
}

export function setIslandBase(n) {
  islandBase = n;
  islandRows = [];
  return 0;
}

export function stashNotFound(e) {
  if (stash === null) stash = e;
  return 0;
}

export function stashedNotFound(fallback) {
  return stash === null ? fallback : stash;
}

export function hasStash() {
  return stash !== null;
}

export function markWrite() {
  writeCount += 1;
  return writeCount;
}

export function writes() {
  return writeCount;
}

export function nextNav() {
  navCounter += 1;
  return navCounter;
}

export function setHooks(h) {
  hooksValue = h;
}

export function hooks(fallback) {
  return hooksValue === null ? fallback : hooksValue;
}

// Call every thunk at once and hand each value to `onDone(index, value)` in
// the order the thunks COMPLETE, one `onDone` at a time (each awaited before
// the next starts), resolving when the last has been handed over.
export async function eachCompleted(tasks, onDone) {
  let queue = Promise.resolve();
  await Promise.all(
    tasks.map((task, i) =>
      Promise.resolve()
        .then(() => task())
        .then((value) => {
          queue = queue.then(() => onDone(i, value));
          return queue;
        }),
    ),
  );
  await queue;
  return 0;
}

// ── the browser half ────────────────────────────────────────────────────────

const PAYLOAD_PREFIX = (name) => "window." + name + " = ";

export function payloadText(name) {
  const doc = globalThis.document;
  if (!doc) return "";
  const prefix = PAYLOAD_PREFIX(name);
  const scripts = Array.from(doc.getElementsByTagName("script"));
  for (let i = scripts.length - 1; i >= 0; i -= 1) {
    const text = scripts[i].textContent || "";
    if (text.startsWith(prefix)) return text.substring(prefix.length);
  }
  return "";
}

let stopped = false;
let openHoles = [];

// The fill function: replace the contents of `[data-jh-h=ID]` with the
// template `[data-jh-f=ID]`'s, then remove the template. A fill for a hole that
// is not present is dropped, and a second call for one id finds no template —
// the function is idempotent. After a late signal every fill is dropped.
export function registerFill(name, holes) {
  openHoles = Array.from(holes);
  globalThis[name] = function fill(id) {
    const doc = globalThis.document;
    if (!doc) return;
    const tpl = doc.querySelector('template[data-jh-f="' + id + '"]');
    if (!tpl) return;
    const hole = doc.querySelector('[data-jh-h="' + id + '"]');
    if (hole && !stopped) hole.replaceChildren(tpl.content.cloneNode(true));
    tpl.remove();
    openHoles = openHoles.filter((h) => h !== id);
  };
  return 0;
}

function isAbsolute(to) {
  return to.startsWith("//") || /^[a-zA-Z][a-zA-Z0-9+.-]*:/.test(to);
}

// The signal function a late navigation signal's `<script>` calls. A relative
// redirect is a client navigation (`history.replaceState`, no reload, then the
// `popstate` the client router listens to); an absolute one is followed only
// when listed in `allowedRedirects`. A not-found swaps the template's markup
// into `[data-jh-root]`. Either way every later fill is dropped.
export function registerSignal(name, allowedRedirects) {
  globalThis[name] = function signal() {
    const doc = globalThis.document;
    if (!doc) return;
    const all = doc.querySelectorAll("template[data-jh-g]");
    const tpl = all[all.length - 1];
    if (!tpl) return;
    stopped = true;
    const kind = tpl.getAttribute("data-jh-g");
    if (kind === "redirect") {
      const to = tpl.getAttribute("data-jh-to") || "";
      if (isAbsolute(to)) {
        if (allowedRedirects.includes(to)) globalThis.location.replace(to);
      } else {
        globalThis.history.replaceState({}, "", to);
        globalThis.dispatchEvent(new globalThis.PopStateEvent("popstate", { state: {} }));
      }
    } else if (kind === "not-found") {
      const root = doc.querySelector("[data-jh-root]");
      if (root) root.replaceChildren(tpl.content.cloneNode(true));
    }
    tpl.remove();
  };
  return 0;
}
