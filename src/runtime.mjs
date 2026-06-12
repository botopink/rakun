// rakun — host runtime: the mutable seams behind `#[@external]`.
//
// botopink is immutable-first and has no top-level mutable globals, so the
// framework's runtime state — the component scan registry, the dependency-cycle
// guard, the config properties, and the router table — lives here, reached from
// `runtime.bp` through `#[@external(node, …)]` declarations. The decorators
// (`decorators.bp`) emit self-registering `val`s and factory fns that call into
// these; `Rakun.run` reads the router back. The compiler core learns nothing
// about rakun.
//
// State is module-global (one node process per run / per `botopink test`
// module). The Erlang/BEAM equivalent is a recorded follow-up.

// ── component scan ──────────────────────────────────────────────────────────
// Every component decorator emits `rkScan(name)` at module load, so the set of
// managed component types is known without cross-decorator compile-time state.

const scanned = []; // component type names, in declaration order

export function scan(name) {
  scanned.push(name);
  return 0;
}
export function scannedNames() {
  return scanned.join(",");
}
export function scannedCount() {
  return scanned.length;
}

// ── dependency-cycle guard ──────────────────────────────────────────────────
// A component factory (`__rkMake_X`) brackets its construction with
// `enter(X)`/`done(X)`. Constructor injection has no whole-graph compile-time
// view (each decorator sees only its own record), so a cycle A→B→A is caught
// here at first construction — `enter` throws when a type is already mid-build —
// instead of recursing until the stack overflows.

const building = new Set();
const builds = new Map(); // name -> how many times its factory actually constructed

export function enter(name) {
  if (building.has(name)) {
    throw new Error(
      "rakun dependency cycle: component '" + name +
        "' depends (transitively) on itself — constructor injection requires an acyclic graph",
    );
  }
  building.add(name);
  builds.set(name, (builds.get(name) || 0) + 1);
  return 0;
}
export function done(name) {
  building.delete(name);
  return 0;
}
// How many times `name`'s factory ran its constructor — `1` for a singleton no
// matter how many sites resolve it (tests assert this proves the scope).
export function buildCount(name) {
  return builds.get(name) || 0;
}

// ── singleton scope ─────────────────────────────────────────────────────────
// A component factory (`__rkMake_X`) is `rkSingleton("X", { -> …construct… })`.
// The first resolve runs the thunk (which brackets construction with
// `enter`/`done`) and caches the instance; every later resolve returns that same
// instance, so a 3-level chain — or a diamond — shares ONE instance per type.
// (The thunk is lazy, so an unresolved component is never built; the cache miss
// is what makes the `enter`/`done` cycle guard fire only on real construction.)
const singletons = new Map();

export function singleton(name, build) {
  if (singletons.has(name)) return singletons.get(name);
  const v = build();
  singletons.set(name, v);
  return v;
}

// ── property injection (`#[value("key")]`) ──────────────────────────────────
// A `#[value("key")]` field is filled from this config source instead of the DI
// graph (property injection, not a constructor edge). The app seeds it (env,
// file, literal); `prop`/`propInt` read it back, typed to the field.
const props = new Map(); // key -> string

export function setProp(key, value) {
  props.set(key, value);
  return 0;
}
export function prop(key) {
  return props.has(key) ? props.get(key) : "";
}
export function propInt(key) {
  const v = props.has(key) ? props.get(key) : "";
  const n = parseInt(v, 10);
  return Number.isNaN(n) ? 0 : n;
}

// ── router ──────────────────────────────────────────────────────────────────
// A controller decorator emits one `registerRoute` per mapped method, each with
// a handler closure that builds the controller via its factory and calls the
// method. `dispatch` matches an incoming (verb, path) — supporting `:name` path
// params — runs the handler with a request, and returns its Response; an
// unmatched path returns a 404 Response (a plain {status, body}, the shape
// botopink's `Response` record lowers to).

const routes = []; // { verb, path, segs, handler }

function split(path) {
  return path.split("/").filter((s) => s.length > 0);
}

export function registerRoute(verb, path, handler) {
  routes.push({ verb, path, segs: split(path), handler });
  return 0;
}
export function routeCount() {
  return routes.length;
}
export function routePaths() {
  return routes.map((r) => r.verb + " " + r.path).join(", ");
}

function match(verb, path) {
  const want = split(path);
  for (const r of routes) {
    if (r.verb !== verb) continue;
    if (r.segs.length !== want.length) continue;
    const params = {};
    let ok = true;
    for (let i = 0; i < r.segs.length; i++) {
      const seg = r.segs[i];
      if (seg.startsWith(":")) params[seg.slice(1)] = want[i];
      else if (seg !== want[i]) { ok = false; break; }
    }
    if (ok) return { route: r, params };
  }
  return null;
}

// A request handed to a handler. `params` are the bound path segments; `query`
// and `headers` are plain string maps (empty for the in-process `dispatch`, real
// for `dispatchHttp` from `libs/server`); `body` is the raw request body. This is
// the concrete value behind rakun's `Request` interface — its `param`/`query`/
// `header` return the botopink `?string` (a present value or `undefined`).
function makeRequest(verb, path, params, query, headers, body) {
  return {
    method: verb,
    path: path,
    // `param`/`query`/`header` return "" when absent (Request's contract is a
    // plain `string`, not `?string`): a matched route's path params are always
    // present, and "" is the natural default for a missing query/header.
    param: (n) => (Object.prototype.hasOwnProperty.call(params, n) ? params[n] : ""),
    query: (n) => (Object.prototype.hasOwnProperty.call(query, n) ? query[n] : ""),
    header: (n) => {
      const k = String(n).toLowerCase();
      return Object.prototype.hasOwnProperty.call(headers, k) ? headers[k] : "";
    },
    body: () => body,
  };
}

// In-process dispatch: match (verb, path), run the handler with a request that
// has the path params bound and everything else empty. Returns the handler's
// Response, or a 404 Response on no match. Used by the lib's own router tests.
export function dispatch(verb, path) {
  const m = match(verb, path);
  if (m === null) return { status: 404, body: "" };
  const req = makeRequest(verb, path, m.params, {}, {}, "");
  return m.route.handler(req);
}

// The real-server dispatch seam (`Rakun.run` hands this to `libs/server`):
// `libs/server` accepts a socket request and calls back here with the raw pieces
// (headers/query encoded as JSON strings so the framework boundary stays scalar).
// We match the route, build a LIVE `Request` (query/header/body all populated),
// run the handler, and return its `{status, body}` for the server to write back.
function parseObj(json) {
  if (!json) return {};
  try {
    const o = JSON.parse(json);
    return o && typeof o === "object" ? o : {};
  } catch {
    return {};
  }
}

export function dispatchHttp(verb, path, headersJson, queryJson, body) {
  const m = match(verb, path);
  if (m === null) return { status: 404, body: "" };
  const headers = parseObj(headersJson);
  const lower = {};
  for (const k of Object.keys(headers)) lower[k.toLowerCase()] = String(headers[k]);
  const req = makeRequest(verb, path, m.params, parseObj(queryJson), lower, body || "");
  return m.route.handler(req);
}
