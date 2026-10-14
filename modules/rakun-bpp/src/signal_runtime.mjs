// rakun-bpp — the signal host half on the js row (front 31).
//
// One cell. A page, layout or template is a `-> @Component<…>` body and
// cannot `throw` (decision 121), so `notFound()` / `redirect(url)` are CALLS
// that raise: `@panic(reason)` in `error_boundary.bp`, an abort whose message
// is the reason. `capture(child)` calls a boundary's thunk exactly once and
// turns any raise into the `{ error }` Result value a `case` can branch on —
// botopink's own `try … catch` unwraps a `@Result` and nothing else. The
// renderer's other catches are std's `failure.attempt` / `attemptTask`
// (`render.bp`'s `attemptRender` / `attemptTask`).
//
// `src/sidecars/jhonstart_signal.erl` is the same cell on the BEAM.

function reasonOf(e) {
  if (e && typeof e.message === "string") return e.message;
  return String(e);
}

export function capture(child) {
  try {
    return child();
  } catch (e) {
    return { error: reasonOf(e) };
  }
}
