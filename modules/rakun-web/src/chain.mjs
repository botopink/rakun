// rakun-web — the filter chain, node half: the twin of
// `src/sidecars/rakun_chain.erl`.
//
// WHAT LIVES HERE AND WHY. botopink has no top-level mutable state, so the
// chain's registries live in the host: the ordered entry table, the advice
// table, the per-controller CORS mappings, and the four per-request
// accumulators. An entry is a FUNCTION and no string store holds one.
//
// WHAT DOES *NOT* LIVE HERE. The order band, the sentinel interpretation, the
// replace-by-name rule, the `Vary` union, the `Set-Cookie` refusal, the CORS
// decision, the RFC 9457 shape and every refusal message are botopink, compiled
// to both targets. This file holds tables, a walk by index and a try/catch.
//
// THE SCOPE. On the BEAM the per-request accumulators are the serving process's
// dictionary. Node has no such scope: they are module globals, which is the
// same thing for rakun's node server, because `runtime.mjs`'s dispatcher runs
// one request to completion before it reads the next.
//
// THE MIRROR THE BEAM HALF HAS AND THIS ONE DOES NOT. `header_set/2` writes
// through to `rakun_runtime:set_reply_header/2` so a header reaches the socket.
// `runtime.mjs` is frozen and carries no `setReplyHeader`, so there is nothing
// to mirror into here — this row keeps the accumulator and the node server
// writes no reply header, exactly as it did before front 07.

const entries = []; // { order, seq, name, entry } — kept sorted by (order, seq)
const advice = []; // { tag, owner, handler }
const corsRows = []; // { prefix, origins, methods }
const problemLines = [];
let seq = 0;
let runner = null;

let headers = []; // { key, name, value }
let cookies = [];
let signals = new Map();
let terminalFn = null;

// ── the chain registry ───────────────────────────────────────────────────────

export function register(name, order, entry) {
  seq += 1;
  entries.push({ order, seq, name, entry });
  entries.sort((a, b) => (a.order - b.order) || (a.seq - b.seq));
  return seq;
}

export function count() {
  return entries.length;
}

export function names() {
  return entries.map((e) => e.name).join("\n");
}

export function orders() {
  return entries.map((e) => String(e.order)).join("\n");
}

export function invoke(i, req, chain) {
  return entries[i].entry(req, chain);
}

export function reset() {
  entries.length = 0;
  seq = 0;
  return 0;
}

// ── the terminal ─────────────────────────────────────────────────────────────

export function setTerminal(fn) {
  terminalFn = fn;
  return 0;
}

export function hasTerminal() {
  return terminalFn !== null;
}

export function terminal(method, path, headersWire, queryWire, body) {
  if (terminalFn === null) return { status: 404, body: "" };
  return terminalFn(method, path, headersWire, queryWire, body);
}

// ── the per-request signal ───────────────────────────────────────────────────

export function signal(key) {
  return signals.has(key) ? signals.get(key) : "";
}

export function putSignal(key, value) {
  signals.set(key, value);
  return 0;
}

export function clearSignals() {
  signals = new Map();
  return 0;
}

// ── reply headers ────────────────────────────────────────────────────────────

export function headerSet(name, value) {
  const key = name.toLowerCase();
  headers = headers.filter((h) => h.key !== key);
  headers.push({ key, name, value });
  return 0;
}

export function headerGet(name) {
  const key = name.toLowerCase();
  const hit = headers.find((h) => h.key === key);
  return hit === undefined ? "" : hit.value;
}

export function headerNames() {
  return headers.map((h) => h.key).join("\n");
}

export function headerLines() {
  return headers.map((h) => h.name + ": " + h.value).join("\n");
}

export function headerClear() {
  headers = [];
  return 0;
}

// ── Set-Cookie ───────────────────────────────────────────────────────────────

export function cookieAdd(line) {
  cookies.push(line);
  return cookies.length;
}

export function cookieLines() {
  return cookies.join("\n");
}

export function cookieClear() {
  cookies = [];
  return 0;
}

// ── controller advice ────────────────────────────────────────────────────────

export function adviceRegister(tag, owner, handler) {
  advice.push({ tag, owner, handler });
  return advice.length;
}

export function adviceOwner(tag) {
  const hit = advice.find((a) => a.tag === tag);
  return hit === undefined ? "" : hit.owner;
}

export function adviceInvoke(tag, detail) {
  const hit = advice.find((a) => a.tag === tag);
  return hit === undefined ? null : hit.handler(detail);
}

export function adviceTags() {
  return advice.map((a) => a.tag).join("\n");
}

export function adviceReset() {
  advice.length = 0;
  return 0;
}

// ── per-controller CORS mappings ─────────────────────────────────────────────

export function corsRegister(prefix, origins, methods) {
  corsRows.push({ prefix, origins, methods });
  return corsRows.length;
}

export function corsRowsWire() {
  return corsRows.map((r) => r.prefix + "\t" + r.origins + "\t" + r.methods).join("\n");
}

export function corsReset() {
  corsRows.length = 0;
  return 0;
}

// ── raises and the guard ─────────────────────────────────────────────────────

class RakunProblem extends Error {
  constructor(tag, detail) {
    super("rakun_problem");
    this.rakunTag = tag;
    this.rakunDetail = detail;
  }
}

export function raiseProblem(tag, detail) {
  throw new RakunProblem(tag, detail);
}

// A 32-bit non-cryptographic digest of the reason. The BEAM half is
// `erlang:phash2/2`; the two rows do not have to agree on the VALUE, only on
// the rule that a body carries the digest and never the reason.
function digest(text) {
  let h = 0;
  for (let i = 0; i < text.length; i += 1) {
    h = (Math.imul(h, 31) + text.charCodeAt(i)) | 0;
  }
  return (h >>> 0).toString(16);
}

export function runGuarded(work, onProblem) {
  try {
    return work();
  } catch (e) {
    if (e instanceof RakunProblem) return onProblem(e.rakunTag, e.rakunDetail);
    const reason = (e && e.stack) ? String(e.stack) : String(e);
    const d = digest(reason);
    problemLines.push(d + " " + reason.split("\n").join(" "));
    return onProblem("", d);
  }
}

export function problemLog() {
  return problemLines.join("\n");
}

export function problemLogReset() {
  problemLines.length = 0;
  return 0;
}

// The same digest the untagged path computes, for a TAGGED raise nothing
// handled: the correlation id a body may carry, over a term a body may not.
export function problemDigest(text) {
  return digest(text);
}

export function problemNote(line) {
  problemLines.push(line);
  return 0;
}

// A fresh per-request identifier. Not a UUID: the chain's request id is a
// correlation handle, not a token. Unique within a process run.
let idSeq = 0;
export function freshId() {
  idSeq += 1;
  return idSeq.toString(16);
}

// ── the ordering trace ───────────────────────────────────────────────────────

const traceLines = [];

export function trace(line) {
  traceLines.push(line);
  return 0;
}

export function traceLog() {
  return traceLines.join("|");
}

export function traceReset() {
  traceLines.length = 0;
  return 0;
}

// ── the boot-time key/value table ────────────────────────────────────────────

const meta = new Map();

export function metaPut(key, value) {
  meta.set(key, value);
  return 0;
}

export function metaGet(key) {
  return meta.has(key) ? meta.get(key) : "";
}

export function metaReset() {
  meta.clear();
  return 0;
}

// ── the seam ─────────────────────────────────────────────────────────────────
//
// There is no node counterpart of `rakun_runtime:dispatch_http/5`'s
// `function_exported` branch: `runtime.mjs` is frozen and this front does not
// unfreeze it. `setRunner` exists so the two rows carry the same cell, and the
// runner is reachable from a node embedder that wants it.

export function setRunner(fn) {
  runner = fn;
  return 0;
}

export function hasRunner() {
  return runner !== null;
}
