// jhonstart-link — the browser half of `Link` (front 27 Step 4).
//
// Four cells. `mount()` installs ONE delegated click listener and one
// intersection observer over every `[data-jh-l]` anchor, however many times it
// is called (onze front 68's entry calls it once, after the islands hydrated).
// A click on a link with no modifier key and no `target` becomes a client
// navigation — `history.pushState` (or `replaceState` for `data-jh-replace`)
// followed by the `popstate` the client router listens to — and the link's
// href is the in-flight navigation `status()` answers until that `popstate`
// is handled. A link entering the viewport is prefetched unless it carries
// `data-jh-prefetch="0"`, in the mode `prefetchMode` decided. `routeKind(href)`
// reads the route-kind table front 60 puts in the payload's `k` key through
// `globalThis.__jhRouteKind`, and answers "unknown" when there is none.
//
// With no `document` (node — the test row) the cells keep only their counters,
// so the idempotence and the idle status are assertable.
// `sidecars/jhonstart_link.erl` is the BEAM twin: there is no browser there,
// and a called node-only cell would red the erlang compile of this member.

let mounts = 0;
let inFlight = "";
const prefetched = new Map();

function onClick(event) {
  const doc = globalThis.document;
  if (!doc || event.defaultPrevented || event.button !== 0) return;
  if (event.metaKey || event.ctrlKey || event.shiftKey || event.altKey) return;
  const anchor = event.target && event.target.closest ? event.target.closest("a[data-jh-l]") : null;
  if (!anchor || anchor.getAttribute("target")) return;
  const href = anchor.getAttribute("href") || "";
  event.preventDefault();
  inFlight = href;
  const history = globalThis.history;
  if (anchor.getAttribute("data-jh-replace") === "1") history.replaceState({}, "", href);
  else history.pushState({}, "", href);
  globalThis.dispatchEvent(new globalThis.PopStateEvent("popstate", { state: {} }));
  if (anchor.getAttribute("data-jh-scroll") !== "0") globalThis.scrollTo(0, 0);
}

export function mount() {
  if (mounts > 0) return mounts;
  mounts = 1;
  const doc = globalThis.document;
  if (!doc) return mounts;
  doc.addEventListener("click", onClick);
  globalThis.addEventListener("popstate", () => { inFlight = ""; });
  if (typeof globalThis.IntersectionObserver === "function") {
    const observer = new globalThis.IntersectionObserver((entries) => {
      for (const entry of entries) {
        if (!entry.isIntersecting) continue;
        const a = entry.target;
        if (a.getAttribute("data-jh-prefetch") === "0") continue;
        prefetch(a.getAttribute("href") || "", a.getAttribute("data-jh-prefetch-mode") || "full");
        observer.unobserve(a);
      }
    });
    for (const a of doc.querySelectorAll("a[data-jh-l]")) observer.observe(a);
  }
  return mounts;
}

export function prefetch(href, mode) {
  if (mode === "skip" || href === "" || prefetched.has(href)) return prefetched.size;
  prefetched.set(href, mode);
  if (typeof globalThis.fetch === "function" && globalThis.document) {
    globalThis.fetch(href, { headers: { "x-jh-prefetch": mode } }).catch(() => prefetched.delete(href));
  }
  return prefetched.size;
}

export function status() {
  return inFlight;
}

export function routeKind(href) {
  const lookup = globalThis.__jhRouteKind;
  return typeof lookup === "function" ? String(lookup(href)) : "unknown";
}
