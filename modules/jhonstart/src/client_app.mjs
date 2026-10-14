// jhonstart — `clientApp`'s browser cells (front 26 Step 6, decision 117).
//
// A client-only app has no server: `clientApp(routes, mount, …).start()`
// matches `window.location` and renders the matched chain into `mount`. Four
// cells: the location's path and query, the mount write, and `location.replace`
// for a listed absolute redirect. With no `window` (node — the test row) the
// cells read and write a module store instead, so the whole start-and-signal
// path is assertable without a DOM; `setLocation` / `mounted` / `replaced` are
// that store's test surface. `sidecars/jhonstart_client_app.erl` answers the
// same store on the BEAM.

const store = { path: "/", search: "", mounted: {}, replaced: "" };

export function locationPath() {
  const loc = globalThis.location;
  return loc ? loc.pathname : store.path;
}

export function locationSearch() {
  const loc = globalThis.location;
  if (loc) return loc.search.startsWith("?") ? loc.search.substring(1) : loc.search;
  return store.search;
}

export function mount(selector, html) {
  const doc = globalThis.document;
  if (doc) {
    const el = doc.querySelector(selector);
    if (el) el.innerHTML = html;
    return 0;
  }
  store.mounted[selector] = html;
  return 0;
}

export function locationReplace(to) {
  const loc = globalThis.location;
  if (loc) loc.replace(to);
  else store.replaced = to;
  return 0;
}

export function setLocation(path, search) {
  store.path = path;
  store.search = search;
  store.replaced = "";
  store.mounted = {};
  return 0;
}

export function mounted(selector) {
  const html = store.mounted[selector];
  return html === undefined ? "" : html;
}

export function replaced() {
  return store.replaced;
}
