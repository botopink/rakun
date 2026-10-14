// jhonstart-forms — the browser half of a form (front 67).
//
// Six cells. `submit` / `invoke` POST to the current pathname with the action
// header onze named (`actionHeader`) and answer the response body AS IT
// ARRIVED — no `JSON.parse`: the envelope has one reader, the bundled library
// `actions`' `parseActionState`. `pending(id)` is "1" while a submit for that
// id is in flight; `state(id)` the last envelope received for it; `mount`
// installs ONE delegated submit listener over `[data-jh-a]` (idempotent);
// `optimistic(id)` the actions recorded against the in-flight submit.
//
// With no `document` / `fetch` (node — the test row) `submit` and `invoke`
// record the call and answer the stubbed body `stub(text)` set, so the
// boundary on either side of the cell is assertable: the string handed in and
// the `ActionState` decoded from what came back.
// `sidecars/jhonstart_forms.erl` is the BEAM twin over the same test store.

let mounts = 0;
const inFlight = new Map();
const lastEnvelope = new Map();
const store = { last: "", response: "" };

function post(actionId, body, actionHeader, contentType) {
  store.last = actionId + "|" + actionHeader + "|" + body;
  const doc = globalThis.document;
  if (!doc || typeof globalThis.fetch !== "function") return Promise.resolve(store.response);
  inFlight.set(actionId, "1");
  const headers = { "content-type": contentType };
  headers[actionHeader] = actionId;
  return globalThis
    .fetch(globalThis.location.pathname, { method: "POST", headers, body })
    .then((r) => r.text())
    .then((text) => {
      inFlight.delete(actionId);
      lastEnvelope.set(actionId, text);
      return text;
    });
}

export function submit(actionId, encodedBody, actionHeader) {
  return post(actionId, encodedBody, actionHeader, "application/x-www-form-urlencoded");
}

export function invoke(actionId, rpcBody, actionHeader) {
  return post(actionId, rpcBody, actionHeader, "application/json");
}

export function pending(actionId) {
  return inFlight.get(actionId) || "";
}

export function state(actionId) {
  return lastEnvelope.get(actionId) || "";
}

export function mount(actionHeader) {
  if (mounts > 0) return mounts;
  mounts = 1;
  const doc = globalThis.document;
  if (!doc) return mounts;
  doc.addEventListener("submit", (event) => {
    const formEl = event.target && event.target.closest ? event.target.closest("form[data-jh-a]") : null;
    if (!formEl) return;
    event.preventDefault();
    const id = formEl.getAttribute("data-jh-a");
    const body = new globalThis.URLSearchParams(new globalThis.FormData(formEl)).toString();
    submit(id, body, actionHeader).then(() => globalThis.dispatchEvent(new globalThis.Event("jh:action")));
  });
  return mounts;
}

export function stub(text) {
  store.response = text;
  return 0;
}

export function lastCall() {
  return store.last;
}
