// jhonstart — the island hydrate point on the js row (front 29 Step 4).
//
// The starter table is `globalThis[<globals.starters>]` — the registry's name,
// handed in by `client.bp`, never spelled here. It holds the component
// starters (`registerStarter`) and the per-route loaders
// (`registerRouteStarters`) onze front 68's generated entry registers.
//
// `hydrate(payloadName, tableName)` walks every `[data-jh-i]` not yet started,
// finds its `i` row in the payload (`window[payloadName].i`), and starts the
// starter registered for that component, handing it the encoded props and a
// `commit(html)` that writes the island's markup. When a loader is registered
// for the payload's matched pattern (`r`), it is called once, and when it
// resolves — having registered that route's starters — hydrate runs again, so
// a route's islands live in the route's own chunk. A started island is marked
// `data-jh-hydrated`, so a second call starts nothing: the function is
// idempotent, and it mounts no link and no form (those are `linkMount` /
// `formMount`, called by the same entry). `[data-jh-reset]` controls (front
// 31's fallback) are bound here too: a click dispatches `jh:refresh`, which the
// client router answers with `refresh()`.
//
// `islandProps(payloadName, name)` answers the encoded props of the first `i`
// row for `name`, `""` when there is none. With no `document` both answer the
// empty value; registration works without one. `sidecars/jhonstart_island.erl`
// is the BEAM twin.

let started = 0;

function tableOf(tableName) {
  let table = globalThis[tableName];
  if (!table) {
    table = { starters: {}, routes: {}, loading: {} };
    globalThis[tableName] = table;
  }
  return table;
}

function rows(payloadName) {
  const payload = globalThis[payloadName];
  return payload && Array.isArray(payload.i) ? payload.i : [];
}

function matchedPattern(payloadName) {
  const payload = globalThis[payloadName];
  return payload && typeof payload.r === "string" ? payload.r : "";
}

// The duplicate refusals are `client.bp`'s, one message on both rows; these
// cells only store.
export function registerStarter(tableName, name, start) {
  const table = tableOf(tableName);
  table.starters[name] = start;
  return Object.keys(table.starters).length;
}

export function registerRouteStarters(tableName, pattern, load) {
  const table = tableOf(tableName);
  table.routes[pattern] = load;
  return Object.keys(table.routes).length;
}

export function starterNames(tableName) {
  return Object.keys(tableOf(tableName).starters);
}

export function routeLoaders(tableName) {
  return Object.keys(tableOf(tableName).routes);
}

export function hydrate(payloadName, tableName) {
  const doc = globalThis.document;
  if (!doc) return started;
  const table = tableOf(tableName);
  const route = matchedPattern(payloadName);
  const load = table.routes[route];
  if (typeof load === "function" && !Object.prototype.hasOwnProperty.call(table.loading, route)) {
    table.loading[route] = Promise.resolve()
      .then(() => load())
      .then(() => hydrate(payloadName, tableName));
  }
  const payloadRows = rows(payloadName);
  for (const el of doc.querySelectorAll("[data-jh-i]")) {
    if (el.hasAttribute("data-jh-hydrated")) continue;
    const id = el.getAttribute("data-jh-i");
    const row = payloadRows.find((r) => r[0] === id);
    if (!row) continue;
    const start = table.starters[row[1]];
    if (typeof start !== "function") continue;
    el.setAttribute("data-jh-hydrated", "1");
    start(String(row[2]), (html) => {
      el.innerHTML = html;
      return 0;
    });
    started += 1;
  }
  for (const btn of doc.querySelectorAll("[data-jh-reset]")) {
    if (btn.hasAttribute("data-jh-bound")) continue;
    btn.setAttribute("data-jh-bound", "1");
    btn.addEventListener("click", () => globalThis.dispatchEvent(new globalThis.Event("jh:refresh")));
  }
  return started;
}

export function islandProps(payloadName, name) {
  const row = rows(payloadName).find((r) => r[1] === name);
  return row ? String(row[2]) : "";
}
