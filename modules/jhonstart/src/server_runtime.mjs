// jhonstart — the request's host half on the js row (front 28).
//
// `server.bp` reads the request through six cells; this module is what those
// cells are on node, and `src/sidecars/jhonstart_server.erl` is the same six on
// the BEAM over the calling process's dictionary.
//
// It exists on this row for one reason and it is a measured one: an
// erlang-only cell reds the **commonJS compile** at its call site, and
// `modules/jhonstart` is compiled on both rows. A `server.bp` whose cells named
// only the erlang backend would stop the whole core member from compiling on
// commonJS the moment `request()` called one. Front 26's `router_runtime.mjs`
// exists for the same reason.
//
// It is deliberately a plain module-global store and nothing else. The four
// pair-shaped values arrive already querystring-encoded exactly as front 23's
// payload carries them, so this module parses nothing and knows no header
// syntax — std's `encoding.formParse` is the one decoder on the botopink side.
//
// A render in the browser has no request of its own: the client rebuilds what
// it needs from the payload. What this half is actually for is the node row of
// the test suite and any node-hosted SSR — which is why `enter` / `leave` are
// here and are the only writers.

const store = {
  method: "",
  path: "",
  params: "",
  query: "",
  headers: "",
  cookies: "",
};

export function method() {
  return store.method;
}

export function path() {
  return store.path;
}

export function params() {
  return store.params;
}

export function query() {
  return store.query;
}

export function headers() {
  return store.headers;
}

export function cookies() {
  return store.cookies;
}

// Replace the whole request. Six values at once, never one at a time: a
// half-updated request is a component reading the previous reader's cookie
// against this reader's path.
let entered = 0;

// Enter the request for one render. Every field at once, never one at a time:
// a half-updated request is a component reading the previous reader's cookie.
export function enter(method_, path_, params_, query_, headers_, cookies_) {
  store.method = method_;
  store.path = path_;
  store.params = params_;
  store.query = query_;
  store.headers = headers_;
  store.cookies = cookies_;
  entered = 1;
  return 0;
}

// Leave it: the store is emptied and `entered()` answers 0, so a read after
// the render ends raises in `server.bp` rather than answering a stale request.
export function leave() {
  store.method = "";
  store.path = "";
  store.params = "";
  store.query = "";
  store.headers = "";
  store.cookies = "";
  entered = 0;
  return 0;
}

export function entered_() {
  return entered;
}
export { entered_ as entered };
