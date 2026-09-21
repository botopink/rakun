// rakun — the file-convention route registry, node half.
//
// WHAT LIVES HERE AND WHY. botopink has no top-level mutable state, so a
// registry has to live in the host — the same reason `runtime.mjs` holds the
// scan list, the singleton cache and the decorator router. This one is separate
// from that router: it is the App-Router table, filled by the module-load `val`s
// the four markers in `file_router.bp` emit, and it holds a registered render
// function, which no string store can hold.
//
// WHAT DOES *NOT* LIVE HERE. The segment grammar, the wire format and the
// matcher are botopink (`file_router.bp`), compiled to both targets. This file
// never parses a segment and never builds a record: it is handed the finished
// `kind|pattern|slot|verb` LINE and appends it beside its function. If the node
// half and the BEAM half could each build a line, the two sides could disagree
// about which route a URL is, and every fix downstream would be a guess. They
// cannot, because neither of them knows the format.
//
// The BEAM twin is `./sidecars/rakun_file_router.erl`; the two answer the same
// cells with the same values, and `test/file_router_test.bp` is one set of
// assertions run on both rows.

const entries = []; // { record: string, render: function }

function add(record, render) {
  entries.push({ record, render });
  return entries.length;
}

// One cell per convention, so the botopink side can type each render function
// differently; the body is the same append for all five.
export function registerPage(record, render) {
  return add(record, render);
}
export function registerLayout(record, render) {
  return add(record, render);
}
export function registerTemplate(record, render) {
  return add(record, render);
}
export function registerDefault(record, render) {
  return add(record, render);
}
export function registerHandler(record, handle) {
  return add(record, handle);
}

// Where each registration was WRITTEN: `seg|fnName`, one per line. The wire
// record carries the URL pattern, not the app-relative directory, and the scan
// has to check the DIRECTORY the marker was given against the real tree and
// name the function that got it wrong. So the raw pair is kept beside the
// table rather than squeezed into it.
const declared = [];

export function registerSource(seg, fnName) {
  declared.push(seg + "|" + fnName);
  return declared.length;
}

export function sources() {
  return declared.join("\n");
}

// The table, in registration order, `\n`-separated — exactly the blob
// `parseTable` reads.
export function table() {
  return entries.map((e) => e.record).join("\n");
}

export function count() {
  return entries.length;
}

// Was a function stored beside this record? The claim "the registry holds the
// renderer" is worth an assertion rather than a comment.
export function hasRender(record) {
  return entries.some(
    (e) => e.record === record && typeof e.render === "function",
  );
}

// The stored function, or `fallback` when nothing registered that record.
// Total and typed — an optional function type is a shape neither row reads
// comfortably, and front 23 needs a value it can call either way.
export function render(record, fallback) {
  for (const e of entries) {
    if (e.record === record && typeof e.render === "function") return e.render;
  }
  return fallback;
}

// The table is process-global; a test that wants to assert over a table of its
// own empties it first.
export function reset() {
  entries.length = 0;
  declared.length = 0;
  return 0;
}
