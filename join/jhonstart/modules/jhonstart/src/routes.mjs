// jhonstart — the UI file-convention registry, node half (front 30 Step 10).
//
// botopink has no top-level mutable state, so the registry lives in the host:
// the module-load `val`s the four markers in `routes.bp` emit append one
// finished `kind|pattern|slot|verb` line and its render FUNCTION here. This
// file parses no segment and builds no line — the grammar is `routing`'s,
// compiled into `routes.bp`. `sidecars/jhonstart_routes.erl` is the BEAM twin.

const entries = []; // { record, render }

function add(record, render) {
  entries.push({ record, render });
  return entries.length;
}

export function registerPage(record, render) { return add(record, render); }
export function registerLayout(record, render) { return add(record, render); }
export function registerTemplate(record, render) { return add(record, render); }
export function registerDefault(record, render) { return add(record, render); }
export function registerLoading(record, render) { return add(record, render); }
export function registerError(record, render) { return add(record, render); }
export function registerNotFound(record, render) { return add(record, render); }

// The table, in registration order, `\n`-separated — the blob `parseTable` reads.
export function table() {
  return entries.map((e) => e.record).join("\n");
}

export function has(record) {
  return entries.some((e) => e.record === record);
}

// The FIRST function registered for the record, or `fallback`.
export function lookup(record, fallback) {
  const hit = entries.find((e) => e.record === record);
  return hit === undefined ? fallback : hit.render;
}
