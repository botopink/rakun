// jhonstart — the client runtime: hook semantics behind `client_runtime.bp`.
//
// `use f(x)` lowers to `f(x)` on every backend (decision 88 of 1.0.10-beta), so
// a component's `state(0)` is a plain call into whatever module `hooks` resolves
// to. The server pass runs `hooks.bp` — pure first-render bodies. The client
// build resolves `jhonstart/hooks` to `jhonstart/client_runtime`, whose cells
// are these exports: the same five nouns, the same shapes (`State{value, set}`,
// `[]`, the memoized value, `[current]`, `[state, dispatch]`), over jhonstart's
// own minimal render loop — no React, nothing to install. The compiler core
// learns nothing about jhonstart.
//
// The loop: `render(component, commit)` runs the component with a cursor over
// its cells (the language's static-prefix rule is what keeps the cursor order
// stable — every `use` precedes every branch); `set`/`dispatch` schedule one
// re-render per microtask, which re-runs the component, commits the new tree,
// then runs the effects whose `deps` changed. Outside a render every hook
// yields its first-render value, so the module is a drop-in for `hooks.js`
// even when called plainly (a test, a server-only path).

// The cell a `state` hook yields — the shape `hooks.bp` emits.
class State {
  constructor(value, set) {
    this.value = value;
    this.set = set;
  }
}
State.prototype.__bp = "State";

let current = null; // the instance being rendered, or null

function cell(init) {
  if (current === null) return null;
  const inst = current;
  const i = inst.cursor++;
  if (i >= inst.cells.length) inst.cells.push(init(inst));
  return inst.cells[i];
}

function depsChanged(prev, next) {
  if (prev === undefined) return true;
  if (prev.length !== next.length) return true;
  for (let i = 0; i < prev.length; i++) if (!Object.is(prev[i], next[i])) return true;
  return false;
}

export function state(initial) {
  const c = cell((inst) => {
    const s = new State(initial, null);
    s.set = (next) => {
      if (Object.is(s.value, next)) return;
      s.value = next;
      inst.schedule();
    };
    return s;
  });
  return c === null ? new State(initial, () => {}) : c;
}

export function effect(run, deps) {
  const c = cell(() => ({ deps: undefined, cleanup: undefined }));
  if (c !== null && depsChanged(c.deps, deps)) {
    c.deps = deps;
    current.pending.push(() => {
      if (typeof c.cleanup === "function") c.cleanup();
      c.cleanup = run();
    });
  }
  return [];
}

export function memo(compute, deps) {
  const c = cell(() => ({ deps: undefined, value: undefined }));
  if (c === null) return compute();
  if (depsChanged(c.deps, deps)) {
    c.deps = deps;
    c.value = compute();
  }
  return c.value;
}

export function ref(initial) {
  const c = cell(() => [initial]);
  return c === null ? [initial] : c;
}

export function reducer(reduce, initial) {
  const c = cell((inst) => {
    const r = { state: initial, dispatch: null };
    r.dispatch = (action) => {
      const next = reduce(r.state, action);
      if (Object.is(r.state, next)) return;
      r.state = next;
      inst.schedule();
    };
    return r;
  });
  return c === null ? [initial, () => {}] : [c.state, c.dispatch];
}

// Runs `component` under the loop and hands every committed tree to `commit`.
// Returns a handle: `cells` are the component's hook cells in activation order
// (a driver's seam — `cells[0].set(3)` is the first `use state` of the body),
// `flush()` renders a pending update now instead of on the next microtask,
// `dispose()` runs the outstanding effect cleanups and stops the loop.
export function render(component, commit) {
  const inst = {
    cells: [],
    cursor: 0,
    pending: [],
    scheduled: false,
    disposed: false,
    schedule: null,
  };
  const run = () => {
    inst.scheduled = false;
    if (inst.disposed) return;
    inst.cursor = 0;
    inst.pending = [];
    const prev = current;
    current = inst;
    let tree;
    try {
      tree = component();
    } finally {
      current = prev;
    }
    commit(tree);
    for (const fx of inst.pending) fx();
  };
  inst.schedule = () => {
    if (inst.scheduled || inst.disposed) return;
    inst.scheduled = true;
    queueMicrotask(run);
  };
  run();
  return {
    cells: inst.cells,
    flush() {
      if (inst.scheduled) run();
    },
    dispose() {
      inst.disposed = true;
      for (const c of inst.cells) if (c && typeof c.cleanup === "function") c.cleanup();
    },
  };
}
