# rakun — Spring-style application framework

> Path: `repository/rakun/` (a workspace) · core: `repository/rakun/modules/rakun/`
> Sibling (AGENTS): [`./AGENTS.md`](AGENTS.md) · Members: [`./modules/README.md`](modules/README.md)
> Parent (workspace): [`../AGENTS.md`](../AGENTS.md)
> Spec: [`../../tasks/v0.beta.5/specs/rakun.md`](../../tasks/v0.beta.5/specs/rakun.md)

`rakun` is botopink's answer to Java's **Spring** / Spring Boot: a dependency-
injection container paired with a declarative web layer, plus a real bootstrap
that starts an HTTP server. It is **opt-in** — reached via `from "rakun"` and
never auto-loaded into the type environment. **The compiler core knows nothing
about rakun** — every behaviour is plain botopink (`@Decl` reflection + comptime
decorator bodies + `@emit`) over a host runtime, which also carries the HTTP
transport.

There are **two host runtimes and one contract**. `src/runtime.mjs` answers the
node row; `src/sidecars/rakun_runtime.erl` answers the erlang row with an OTP
application, a supervised table owner and ETS. Every cell in `src/runtime.bp`
carries both forms, and `test/erlang_runtime_test.bp` is one set of assertions
run on both — the port is only worth as much as that file being green twice.
See [`./AGENTS.md`](AGENTS.md) § The erlang host module for the OTP shape, the
sidecar naming rule and what is still blocked.

## What it provides

- **HTTP layer** — `Response` with builders (`Response.ok`/`json`/`created`/
  `withStatus`/`notFound`/`badRequest`), the `HttpMethod` enum-shaped `type`, the `App`
  bootstrap config, and the `Request` behavior (`param`/`query`/`header`/`body`).
- **IoC container** — components (`#[component]`/`#[service]`/`#[repository]`/
  `#[controller]`/`#[restController]`) scanned at module load; each gets an emitted
  factory `__rkMake_<Type>()`.
- **Singleton scope** — one shared instance per component type: the factory is
  `rkSingleton("Type", { -> …construct… })`, so a 3-level chain (or a diamond)
  resolves a single repo/service instance.
- **Constructor dependency injection** — declare a dependency as a field of the `type`;
  rakun resolves it by type. No setter/field injection.
- **`#[configuration]` + `#[bean]`** — a `#[bean]` method's return type becomes an
  injectable singleton (an emitted `__rkMake_<ReturnType>()` calls the bean).
- **`#[value("key")]` property injection** — a `#[value]` field is filled from the
  config source (`rkProp`/`rkPropInt`), **excluded** from the DI graph.
- **Web layer** — `#[restController, route(prefix)]` + `#[getMapping(path)]`/… emit
  a route registration per method; the dispatcher matches `(verb, path)` —
  including `:name` params — and runs the handler over `Request`/`Response`, or 404s.
- **File-convention routing** — `file_router.bp`: a URL that comes from where a
  file sits. `parseSegment` decodes `blog`, `[slug]`, `[...slug]`, `[[...slug]]`,
  `(group)`, `@slot` and `_private`; `patternOf` builds the URL pattern with
  groups and slots dropped and the bracket spelling kept, and `slotOf` names the
  slot. The table is `kind|pattern|slot|verb` lines — `parseTable` / `writeTable`
  — and `matchPath` / `layoutChain` read it, one implementation compiled to both
  targets. `#[layout]`, `#[template]`, `#[page]` and `#[defaultView]` register a
  route from the app-relative directory they are given, and a `#[page]` also
  gets an emitted `<name>Params(route)` accessor typed from its bracket
  segments. Beside the decorator router, not instead of it.
- **Cycle detection** — `__rkMake_X` brackets construction with `rkEnter`/`rkDone`;
  a cycle A→B→A raises at first construction (runtime — a single decorator has no
  whole-graph view).
- **The BEAM server** — on the erlang row the same `rkServe` is a `gen_tcp`
  acceptor with `{packet, http_bin}` (no HTTP parser, no dependency outside
  `kernel`), one supervised process per connection, per-request reply headers,
  the `rakun.main.*` / `rakun.server.*` boot and tuning keys, and a
  startup-failure table that names the port, the transport or the construction
  stack before the node halts. See [`./AGENTS.md`](AGENTS.md) § The server half.
- **Bootstrap** — `Rakun.run(App(port: 8080, basePath: "/api"))` reads the host
  router and starts the node `http` server (`rkServe`), dispatching every live
  request to the handler.

## Spring → rakun mapping

| Spring | rakun |
|---|---|
| `@Component` / `@Service` / `@Repository` | `#[component]` / `#[service]` / `#[repository]` |
| `@RestController` + `@RequestMapping("/api")` | `#[restController, route("/api")]` |
| `@GetMapping("/x")` … | `#[getMapping("/x")]`, `#[postMapping]`, `#[putMapping]`, `#[patchMapping]`, `#[deleteMapping]` |
| `@Autowired` (constructor) | a field of the `type` — injected by type |
| `@Configuration` + `@Bean` | `#[configuration]` + `#[bean]` |
| `@Value("server.port")` | `#[value("server.port")]` |
| `SpringApplication.run(App.class)` | `Rakun.run(App(port: 8080, basePath: "/api"))` |
| `ApplicationContext` | `Context` (`ctx.resolve<T>()`) — future, declaration-only |
| `ResponseEntity` | `Response` (`Response.ok(...)`, `Response.json(...)`) |

The decorators (`service`, `restController`, `route`, `getMapping`, …) are
symbols **exported by rakun** — import them at the call site before applying them
in a `#[ … ]` block. Route decorators use Spring's names (`getMapping`, …)
because `get`/`set`/`new` are reserved keyword tokens.

## Usage

```bp
import {Rakun, App, Request, Response} from "rakun";
import {service, restController, route, getMapping} from "rakun";
import {rkScan, rkSingleton, rkEnter, rkDone, rkRegisterRoute} from "rakun";

#[service]
pub type GreetingService {
    pub fn greet(self: Self, name: string) -> string {
        return "Hello, " + name + "!";
    }
}

#[restController]
#[route("/api")]
pub type GreetingController(
    // injected by type
    greeting: GreetingService,
) {
    #[getMapping("/hello/:name")]
    pub fn hello(self: Self, req: Request) -> Response {
        return Response.ok(self.greeting.greet(req.param("name")));
    }
}

fn main() {
    Rakun.run(App(port: 8080, basePath: "/api"));
}
```

`Request.param`/`query`/`header` return a plain `string` (`""` when absent) — a
matched route's path params are always present, and `""` is the natural default
for a missing query/header (Spring's `@RequestParam(defaultValue = "")`).

The emitted DI/router wiring calls the host runtime by name, so a module
declaring components imports those fns too (`rkScan`/`rkSingleton`/`rkEnter`/
`rkDone`/`rkRegisterRoute`; add `rkProp`/`rkPropInt` when it has a `#[value]`
field). See the runnable end-to-end app under
[`./examples/rakun/`](examples/rakun/).

## Configuration

`#[value("key")]` reads the property table; `config.bp` fills it. A whole record
binds at once with `#[configurationProperties]`:

```bp
#[configurationProperties("my.service")]
pub type MyService(
    enabled: bool,
    remoteAddress: string,                       // binds from remote-address too
    #[unit("seconds")] sessionTimeout: Duration,
    #[nested] security: Security,
)
```

The record is then injectable by type into any `#[service]`, and every key it
declares lands in the run-time catalogue.

```bp
import {readDocument, rkConfigApply, entryAt} from "rakun";

val docs = try readDocument("application.yaml");
loop (docs) { d -> val _ = rkConfigApply(d.entries); };
```

`rkConfigLoad()` is the whole load: eight sources in order (command line,
`RAKUN_APPLICATION_JSON`, environment, profile documents, base documents,
configuration trees, `rkSetProp`, declared defaults), profiles resolved and
written to `rakun.profiles.resolved`, and one refusal naming the input when a
location, an import, a document or a profile group is wrong.

```bp
import {rkConfigLoad} from "rakun";
import {active} from "rakun";

fn main() {
    try rkConfigLoad();
    @print(active().join(","));
}
```

`${key}` and `${key:default}` resolve at load time; `${random.uuid}`,
`${random.int[1024,65536]}` and friends resolve per REFERENCE through
`rkValue(key)`. Typed readers — `rkPropBool`, `rkPropIntOr`, `rkPropFloat`,
`rkPropList`, `rkPropDuration`, `rkPropSize` — carry the declared default as
their second argument and try the kebab, camel and `SCREAMING_SNAKE` spellings
of a key before giving up.

Three formats are read — `.properties`, `.json` and a documented YAML subset —
plus `configtree:` directories (one file per key). A nested JSON object flattens
to dot keys (`server.port`) and an array to indexed keys (`a[0]`). A YAML
construct outside the subset (anchor, alias, flow style, block scalar, tag) is a
located refusal naming the file and the line, never a silent mis-parse. See
[`AGENTS.md`](AGENTS.md) § Externalized configuration for the table.

## File-convention routing

`#[restController]` routes by decorator and is untouched. `file_router.bp` is
the other model — a URL that comes from where a file sits:

```bp
import {layout, page, PageContext, LayoutProps, ctxParam, rkAppLayout, rkAppPage} from "rakun";

#[layout("")]
pub fn rootLayout(props: LayoutProps<Element>) -> Element { … }

#[page("blog/[slug]")]
#[@future]
pub fn blogPostPage(route: PageContext) -> @Future<Element> {
    return post(blogPostPageParams(route).slug);
}
```

The argument is the APP-RELATIVE DIRECTORY of the file, not its URL: `@Decl`
carries no source location, so a decorator cannot learn which file it was
written in, and the CLI (front 50) checks the argument against the real tree
under `onze.appDir`. `blogPostPageParams` is emitted by `#[page]` — one field
per bracket segment, `string[]` for a catch-all, `#()` for none.

The registered table crosses the boundary as `kind|pattern|slot|verb` lines in
registration order — `L` layout, `T` template, `P` page, `D` default, `R` route
handler, `S` loading, `E` error, `N` not-found. `parseTable`, `matchPath` and
`layoutChain` read it, one implementation compiled to both targets; the host
halves (`file_router.mjs`, `sidecars/rakun_file_router.erl`) hold only the
lines and the render functions and know nothing about the format. Read a bound
parameter with `paramOf(match, name)`.

`scanAppDir(root, appDir)` is the other half: it walks the real tree, skips
`_`-prefixed folders, discovers a project-root `middleware.bp`, and refuses a
segment that holds both `page.bp` and `route.bp`, two root layouts meeting at
one URL, a registered segment with no directory and a directory that registered
nothing. `appDirOf()` reads `onze.appDir` (front 05) and defaults to `app`, so
moving between `app/` and `src/app/` is one config line.

## The request context

`request_context.bp` is the server-side scope. Nothing else on the server can
reach the in-flight request: a `Request` lives only inside the function the
router dispatched to.

```bp
import {RequestPhase, RequestScope, beginRequest, endRequest, requestPhase} from "rakun";

val epoch = beginRequest(RequestScope(
    id: "req-77",
    phase: RequestPhase.Handler,
    method: "GET",
    path: "/api/posts",
    query: "page=2",
    headersWire: wire,
    strict: false,
));
val body = runHandler();
val setCookies = endRequest();
```

`headersWire` is `name\tvalue` lines, `\n`-separated, names already lowercased
by the dispatcher. `endRequest()` must run on the failure path too, or the next
request on a keep-alive connection starts inside the previous one's frame.

The scope is a FRAME with an EPOCH, not a process: a connection process serves
many requests in sequence, so every handle minted from the frame carries the
epoch it was minted with and raises if it is used after `endRequest` or from the
next request. Reading outside a request is a hard failure — `requestPhase()`
with no frame raises `request context is not established`, and there is no
lenient mode, no `…Or(default)` and no predicate to branch around it. A library
that has to work both inside and outside a request takes the values as
parameters.

The five phases are `Middleware`, `Render`, `Action`, `Handler` and `After`, and
the phase is stored once: front 12's `rkCachePhase()` reads this slot rather
than keeping a second one.

### The dispatcher contract

```bp
val epoch = beginRequest(RequestScope(
    id: newRequestId(),
    phase: RequestPhase.Handler,
    method: "GET",
    path: "/api/posts",
    query: "page=2",
    headersWire: wire,
    strict: false,
));
val body = runHandler();       // wrapped: a raise must still reach the line below
val setCookies = endRequest(); // the queued `Set-Cookie` lines, `\n`-separated
// … write the response …
val _ = drainAfter(30000);     // reap the deferred work
```

`endRequest()` must run on the failure path too. The blob splits on `\n` into
whole header values and a cookie value can never split it — `serializeCookie`
percent-encodes a newline.

| Phase | `headers()` | `cookies()` | `.set`/`.delete` | `after()` | marks dynamic |
|---|---|---|---|---|---|
| `Middleware` | yes | yes | yes | yes | no |
| `Render` | yes | yes | **raises** | yes | yes |
| `Action` | yes | yes | yes | yes | no |
| `Handler` | yes | yes | yes | yes | yes |
| `After` | yes | yes | **raises** | **raises** | no |

### A scenario, end to end

```bp
// a layout's auth guard — front 23 renders this in phase Render
fn requireSession() -> string {
    val sid = cookieOf(cookies(), "session", "");
    if (sid == "") return "" else return sid;
}

// a server action — front 24 dispatches this in phase Action
fn setTheme(theme: string) -> i32 {
    val jar: Cookies = cookies();
    val _ = jar.set("theme", theme, CookieAttrs(
        path: "/", domain: "", maxAge: 31536000,
        httpOnly: false, secure: true, sameSite: "Lax",
    ));
    return after({ ->
        writeAnalytics(requestId(), "theme:" + theme);
        0;
    });
}

// a route handler — front 25 dispatches this in phase Handler
fn whoAmI() -> string {
    return headerOf(headers(), "user-agent", "unknown");
}

// one loader shared by generateMetadata and the page — loads once per request
fn getPost(id: string) -> string {
    return memoize(memoKey("post", [id]), { -> loadPost(id) });
}
```

### `headers()`

```bp
import {headers, headerOf, isDynamic, dynamicReason} from "rakun";

val ua = headerOf(headers(), "User-Agent", "");
```

`get` answers `?string` — `null` for an absent header, not `""`. Read it with
`headerOf(h, name, fallback)` or bind the handle with its annotation
(`val h: Headers = headers();`): the optional a record method answers loses its
type when the receiver is itself a call, exactly as `paramOf` exists for in the
file router. A name is case-folded, and a header sent twice answers both values
joined with `", "`.

Reading a header in phase `Render` or `Handler` marks the render dynamic;
`dynamicReason()` names the first function that did it, and in a `strict` frame
(front 60's prerenderer) the read raises instead, naming the function and the
route.

### `cookies()`

```bp
import {cookies, cookieOf, cookieDefaults, Cookies} from "rakun";

val theme = cookieOf(cookies(), "theme", "light");

val jar: Cookies = cookies();
val _ = jar.set("theme", "dark", cookieDefaults());
```

A cookie may be written from a server action, a route handler or middleware; a
write in phase `Render` or `After` raises. The queued lines come back from
`endRequest()` as a `\n`-separated blob — the dispatcher appends each as its own
`Set-Cookie` header, because front 04's `rkSetReplyHeader` replaces by name and
so carries only one.

`cookieDefaults()` is `path="/"`, `domain=""`, `maxAge=0`, `httpOnly=true`,
`secure=true`, `sameSite="Lax"`. **Pass your own `maxAge`**: `Max-Age=0` expires
the cookie on arrival (RFC 6265 § 5.2.2), and `cookieDefaults()` carries it
because the front's acceptance pins the wire literal — see `AGENTS.md` for the
argument.

A cookie value is percent-encoded on the way out and percent-decoded on the way
in, over printable ASCII. A control character encodes (so a `Set-Cookie` line
cannot hold a newline) and never decodes back; a character above printable ASCII
is refused, naming the cookie — encode it yourself, base64url being the usual
answer.

### `draftMode()` and `connection()`

```bp
import {draftMode, connection, isDynamic, dynamicReason, DraftMode} from "rakun";

val draft: DraftMode = draftMode();
if (draft.isEnabled()) { … } else { … };
```

`__rakun_draft` is a signed cookie; `enable()` needs `rakun.draft.secret` and
raises without it rather than issuing an unsigned bypass. Enabling marks the
request dynamic and sets the bypass flag front 60 reads. `connection()` marks
and reads nothing — the way a route declares itself dynamic without pretending
to need a header — and `dynamicReason()` names the first function that marked.

### `after()`

```bp
import {after, drainAfter} from "rakun";

val _ = after({ ->
    writeAnalytics(requestId());
    0;
});
```

The work runs once the response is sent, against a FROZEN copy of the frame
under phase `After`: it can read the request's headers and cookies and can write
nothing — a cookie write and a second `after()` both raise there. The dispatcher
calls `endRequest()`, writes the response, then `drainAfter(budget)`;
`rakun.request.after.timeout` (default 30 000 ms) bounds each thunk, and
`afterLog()` carries one line per failure or kill, each with the request id.

On the BEAM a thunk is a `spawn_monitor` child and an overrunning one is killed.
Node cannot interrupt a synchronous function, so it counts a thunk that overran
in the same slot — same counters, same log, one interruption real and one after
the fact.

### Per-request memoization

```bp
import {memoKey, memoize, preload} from "rakun";

fn getPost(id: string) -> string {
    return memoize(memoKey("post", [id]), { -> loadPost(id) });
}
```

One table per request. A miss runs the loader and stores; a hit answers the
stored value and does not evaluate the loader at all; two requests with the same
key run it twice — a memo that survives a request is a cache, and caches belong
to front 12. `preload(key, load)` starts the load early (a spawned child on the
BEAM, an eager load on node) and a later `memoize` with that key waits for it
rather than starting a second one. `memoKey` does not hash and refuses a part
carrying its `|` separator.

## Server-side rendering

`from "rakun"` gives you the render pipeline: a URL in, an ordered list of HTML
chunks out, with every string that came from a request, a database or a file
escaped on the way.

### The element view — one adapter, written once

rakun does not know what an element is. It declares no dependency on a UI
library, so the six things a walker needs are handed to it as a record:

```bp
import {ElementView, renderNode} from "rakun";
import {Element, isVoidTag, isRawTextTag} from "jhonstart";

pub fn jhonstartView() -> ElementView<Element> {
    return ElementView(
        make: { t, v, a, c -> Element(tag: t, value: v, children: c, attrs: a) },
        tagOf: { e -> elementTag(e) },
        valueOf: { e -> elementValue(e) },
        attrsOf: { e -> elementAttrs(e) },
        childrenOf: { e -> elementChildren(e) },
        isVoid: { t -> isVoidTag(t) },
        isRawText: { t -> isRawTextTag(t) },
    );
}
```

Two rules, both of which cost an hour if you learn them from an erlang
diagnostic instead of from here:

- **Wrap every function in a lambda.** `isVoid: isVoidTag` compiles on node and
  is `variable 'IsVoidTag' is unbound` on erlang. `{ t -> isVoidTag(t) }` is the
  same value and lowers on both.
- **Read a field before you call it.** `v.tagOf(e)` is a METHOD call to the
  compiler and reds with `function tagOf/2 undefined` on erlang. Write
  `val tagOf = v.tagOf; tagOf(e)`. The same holds for every field of
  `RenderHooks`.

The four readers are named functions taking a typed parameter — a field read
inside a lambda loses the parameter's type on the erlang row.

An application that ships no UI library can use rakun's own `Node` through
`nodeView(isVoid, isRawText)`.

### Rendering a tree

```bp
val v: ElementView<Element> = jhonstartView();
val html = renderNode(v, tree);
```

`renderNode` escapes `&`, `<` and `>` in a text node and adds `"` and `'` in an
attribute value; it emits `<input>` with no closing tag; it emits a `script` or
`style` body verbatim, because escaping CSS or JavaScript changes the program;
and it REFUSES a `script`/`style` body containing `</script` or `</style`, in
any case, naming the tag. There is no option that turns that refusal into
escaping.

`raw(v, "<b>x</b>")` is the one escape hatch and it renders verbatim. Every use
of it is a place a reviewer must look at.

### Composing a page with its layouts

```bp
val table = appTable();
if (matchPath(table, "/blog/hello")) { hit ->
    val ctx = contextOf(hit, "/blog/hello", emptyParams());
    val tree = compose(v, hit.chain, ctx, nav, page);
};
```

`hit.chain` is already the root-first layout list — do not call `layoutChain`
again for a match you already hold. `compose` wraps the page from the inside
out, so the rendered nesting is
`layout > template > error > loading > not-found > page`, and a convention your
app does not define contributes no wrapper.

A layout learns how deep it sits with `selected()` — `0` for the root layout,
`1` for the next one down. It is a call rather than a field of `LayoutProps`
because that record is the router's and carries three fields.

## The container: beans, `Context`, lifecycle and events

Constructor injection resolves a field by type and needs no help. Everything
below is for the value that is *not* a field of something: resolving a bean
programmatically, running code at startup and shutdown, and publishing or
observing an application event.

### `#[managed]` — registering a bean

```bp
import {service, repository} from "rakun";
import {managed, rkRegisterBean} from "rakun";

#[repository]
#[managed]
pub type OrderRepository {
    pub fn ids(self: Self) -> string[] {
        return ["o-1", "o-2"];
    }
}

#[service]
#[managed]
pub type OrderCache(repo: OrderRepository) {
    pub fn size(self: Self) -> i32 {
        return self.repo.ids().length;
    }
}
```

`#[managed]` STACKS under a stereotype rather than replacing it — the way
`#[route]` stacks under `#[restController]` — because the six stereotype
decorators are frozen for this milestone. A type that carries a stereotype and no
`#[managed]` is still scanned and still injectable as a field; it is simply not
in the registry, so `ctx.resolve` will not find it.

The module that declares a `#[managed]` type imports `rkRegisterBean` alongside
the marker, the same way a `#[service]` module already imports `rkScan`,
`rkSingleton`, `rkEnter` and `rkDone`: the wiring is `@emit`ted into the
application's own module and calls those names there.

### Resolving

```bp
import {rkResolve, rkResolveNamed, rkHasBean, rkBeanNames} from "rakun";

val cache: ?OrderCache = rkResolve("OrderCache");
val fixed: ?Clock = rkResolveNamed("Clock", "fixed");
val known = rkHasBean("OrderCache");
val every = rkBeanNames();
```

The registry key is a STRING and the type comes from the annotated binding.
`ctx.resolve<OrderCache>()` is not writable: explicit generic arguments do not
parse at a call site, and there is no `@typeName<T>()` to recover the name from
`T`. So `resolve<Foo>("Bar")` type-checks and answers `null` — the two halves are
not checked against each other, and both are recorded language gaps.

An unregistered type answers `null` and `rkHasBean` answers `false`; neither
raises. Two beans of one type raise only when an UNQUALIFIED `resolve` cannot
choose between them:

```
rakun: two beans of type 'Clock' ('systemClock', 'fixedClock') and neither is
       #[primary]; resolve by qualifier, or mark one #[primary]
```

Mark one `#[primary]`, or reach for the one you meant with
`rkResolveNamed("Clock", "fixed")`.

### `Context`

```bp
import {Context, __rkMake_Context} from "rakun";

#[service]
#[managed]
pub type OrderReader(ctx: Context) {
    pub fn size(self: Self) -> i32 {
        val cache: ?OrderCache = self.ctx.resolve("OrderCache");
        var n = 0;
        if (cache != null) n = cache.size();
        return n;
    }
}
```

`Context` is injectable BY TYPE: a field of it wires with no extra declaration,
because rakun emits the `__rkMake_Context()` factory the component decorator
already reaches for. The consumer's module names that factory in its `import`
list, the same way it already names `rkScan` and `rkSingleton` — the emitted
wiring calls those by name at the application site.

`Context` is not a bean of its own registry: it does not appear in
`ctx.beanNames()`, the eager pass does not construct it, and it is exempt from
the cycle guard because it is constructed before the scan runs and depends on
nothing.

`ctx.child("request")` returns a context whose lookup starts in its own registry
and delegates upward on a miss — Spring's parent/child contexts. A bean
registered at the root is visible from every child; one registered into a child
is not visible from the root. `ctx.path()` is the scope path and `""` is the
root.

**Bind the receiver to an ANNOTATED local.** `__rkMake_Context().resolve(…)` and
`val ctx = __rkMake_Context();` both lose the optional's payload type — the
optional a record method answers loses its type when the receiver is a call or an
unannotated local. `val ctx: Context = __rkMake_Context();` is the spelling that
keeps `?OrderCache` an `?OrderCache`.

### `#[provides]` — a factory function

```bp
import {provides, qualifier, primary} from "rakun";

pub type Clock(zone: string) {
    pub fn stamp(self: Self) -> string {
        return "<now@" + self.zone + ">";
    }
}

#[provides]
#[qualifier("system")]
#[primary]
pub fn systemClock() -> Clock {
    return Clock(zone: "UTC");
}

#[provides]
#[qualifier("fixed")]
pub fn fixedClock() -> Clock {
    return Clock(zone: "fixed");
}
```

`Clock` is now injectable by type — a `clock: Clock` field gets the `#[primary]`
one — and `ctx.resolveNamed("Clock", "fixed")` reaches the other. It is not
spelled `#[bean]` because `#[bean]` already exists and is frozen at a METHOD of a
`#[configuration]`; `#[provides]` is the function form.

Exactly one provider of a type may own the `__rkMake_<Type>()` name constructor
injection reaches for: the unqualified one, or the `#[primary]` one. So:

- **Two unqualified providers of one type** both register and the second raises
  at module load, naming both functions.
- **Two qualified providers with no `#[primary]`** own the name neither time, so
  a FIELD of that type does not compile (`unbound variable '__rkMake_Dye'`) and
  an unqualified `ctx.resolve` raises the ambiguity. `resolveNamed` still works —
  which is the point of having qualified two beans in the first place.

`#[provides]` on a function returning nothing is refused at comptime: a bean is
what the function returns.

### Lifecycle hooks

```bp
import {managed, postConstruct, preDestroy, rkRegisterLifecycle} from "rakun";

#[service]
#[managed]
pub type OrderCache(repo: OrderRepository) {
    #[postConstruct]
    pub fn warm(self: Self) {
        @print("warming " + self.repo.ids().length.toString() + " entries");
    }

    #[preDestroy]
    pub fn close(self: Self) {
        @print("order cache released");
    }
}
```

A hook may use every injected dependency — it runs on the constructed instance.
`#[postConstruct]` runs once per singleton however many sites resolve it, in
registration order, and the pass is part of the eager initialization
`context.bootSequence()` performs. `#[preDestroy]` runs on shutdown in REVERSE
registration order, which is reverse dependency order.

A `#[postConstruct]` that raises fails the boot, naming the component and the
method — a half-built component is worse than a refused boot. A `#[preDestroy]`
that raises is logged and the remaining hooks still run.

The two markers are placement checks and emit nothing: a method-level `@Decl`
carries no owner, so it cannot name the factory whose method it is. `#[managed]`
sees both and emits the registration.

### Application events

```bp
import {Context, Event, event, eventListener, rkRegisterListener} from "rakun";

#[service]
#[managed]
pub type AuditListener {
    #[eventListener("OrderPlaced")]
    pub fn onOrderPlaced(self: Self, ev: Event) {
        @print("order placed: " + ev.payload);
    }

    #[eventListener("ApplicationReady")]
    pub fn onReady(self: Self, ev: Event) {
        @print("ready");
    }
}

#[restController]
#[route("/api/orders")]
pub type OrderController(ctx: Context) {
    #[postMapping("/")]
    pub fn place(self: Self, req: Request) -> Response {
        val _p = self.ctx.publish(event("OrderPlaced", "OrderController", req.body()));
        return Response.created("accepted");
    }
}
```

One `Event` record and a STRING name: Spring dispatches by the listener
parameter's type, and a method-level `@Decl` carries no parameter list, so the
event type cannot be read from the listener. Dispatch is synchronous and in
registration order; a listener that raises is recorded and the others still run.
An event nobody listens for delivers to zero listeners and is not an error.

Build an event with `event(name, source, payload)`. `Event(name: …,
timestampMillis: 0)` does not compile — an integer literal is `i32` and there is
no widening to the `i64` field — and `event` stamps the clock itself.

A module that imports `Context` must also import `Event`, because
`Context.publish`'s parameter type has to resolve at the use site.

### The boot sequence

```bp
import {context} from "rakun";

fn main() {
    context.bootSequence();
    Rakun.run(App(port: 8080, basePath: "/api"));
}
```

`bootSequence()` publishes Spring's eight events, with the eager construction of
every registered bean and the `#[postConstruct]` pass between the fourth and the
fifth:

`ApplicationStarting` → `ApplicationEnvironmentPrepared` →
`ApplicationContextInitialized` → `ApplicationPrepared` → *[eager pass]* →
`ApplicationStarted` → `AvailabilityChanged(LivenessCorrect)` →
`ApplicationReady` → `AvailabilityChanged(ReadinessAcceptingTraffic)`

A missing property or a dependency cycle fails HERE, not on the first request
that touches it. When it does, `ApplicationFailed` is published in place of
everything after the point of failure and then the boot stops.

`main` calls it rather than `Rakun.run`, because `bootstrap.bp` is frozen.

### Scopes

```bp
import {managed, scope, rkScan, rkRequestScoped} from "rakun";

#[managed]
#[scope("prototype")]
pub type TicketMachine(repo: OrderRepository) { … }

#[managed]
#[scope("request")]
pub type RequestBasket(repo: OrderRepository) { … }
```

`singleton` (the default) is what constructor injection always gets.
`prototype` constructs on every `resolve`. `request` caches in the request
process's dictionary, so two resolves inside one request share an instance and
two requests do not — nearly free on the BEAM, where a request IS a process.

**A prototype or request bean carries no stereotype, and that is enforced.** The
stereotype is what emits the singleton `__rkMake_<Type>()` a FIELD is injected
through, so the pair would register a prototype and inject a singleton;
`#[managed]` refuses it at comptime. Without a stereotype there is no
`__rkMake_<Type>` at all, so a field of that type does not compile and the bean
is reached through `ctx.resolve`, which is the point. Such a type also may not
carry `#[postConstruct]` or `#[preDestroy]`: both passes run once, over an
instance nobody kept.

Front 62 owns the per-request accessors (`cookies()`, `headers()`, `after()`,
per-request memoization). Front 06 ships the scope kind and its storage and
defines no accessor.

### Eager initialization

With defaults, `context.bootSequence()` constructs every registered singleton
bean and runs every `#[postConstruct]` before it returns, so a dependency cycle
or a configuration reader that halts fails the BOOT rather than the first request
that happens to touch it.

```properties
rakun.main.lazy-initialization=true
```

turns it off — the `#[postConstruct]` pass with it, because a hook runs on an
instance. `#[lazy]` on one component excludes only that one. A `prototype` or
`request` bean is never eagerly built: it has no instance to warm.

A missing `#[value]` key is **not** a boot failure. `rkProp` answers `""` for an
absent key and `rkPropInt` answers `0`, by design and on both rows, so a missing
key is a default rather than an error — at boot or at any other time. Use front
05's typed configuration readers when a key is required.

### Shutdown and the exit code

```bp
import {exitCode, shutdown, rkRegisterExitCode} from "rakun";

#[exitCode]
pub fn drainExitCode() -> i32 {
    return 0;
}
```

`shutdown()` runs every `#[preDestroy]` in reverse registration order — reverse
dependency order, because a component is registered after the components it was
constructed from — and answers the process status: the highest value any
`#[exitCode]` function returns, or 0 with none registered. A hook that raises is
logged and the remaining ones still run.

Stopping accepting, flipping readiness false and draining the in-flight requests
are front 07's graceful shutdown, which calls `shutdown()` after the drain. A
failed boot never reaches it: the boot halts, and a halt is a non-zero process
status on both hosts.

### `#[imports]`

```bp
#[configuration]
#[managed]
#[imports("Wallet")]
pub type WalletConfig {
    #[bean]
    pub fn wallet(self: Self) -> Wallet {
        return Wallet(owner: "treasury");
    }
}
```

Spring's `@Import`: a bean is registered for each named type, so a configuration
record in a module the application does not otherwise reference is still wired.
Each named type must already have a factory — from a stereotype, a `#[bean]`
method or a `#[provides]` function — and a name with none does not compile,
naming both the type and the configuration that asked for it.

Spring's `@ComponentScan(basePackages=…)` has no analogue and needs none: an
additional scan root in botopink is a `pub mod` line.

### Qualifiers, primary and lazy

`#[qualifier("name")]` distinguishes two beans of one type, `#[primary]` marks
the default for the unqualified lookup, and `#[lazy]` keeps a bean out of the
eager pass. All three are read off the declaration by `#[managed]` and
`#[provides]`; on their own they are placement checks, the same split
`#[getMapping]` and `#[restController]` already use.

## Loading notes

Unlike `libs/std`, this package is **not** `@embedFile`'d into a `prelude.zig`
and is **not** wired into `build.zig`. It is an **application-level** lib reached
via `from "rakun"`, opted into per project. `repository/rakun/botopink.json` is a
**workspace** (decision 75): `from "rakun"` resolves to the member
`modules/rakun/` — whose `files` (`root`, `http`, `runtime`, `decorators`,
`bootstrap`, `rakun.d`) is exactly what a consumer sees — and never to the
umbrella, which ships nothing. A sibling member or an example inside the
workspace depends on it with `{ "rakun": { "workspace": true } }`; a project
elsewhere in the ecosystem with `{ "path": "…/modules/rakun" }`; a consumer
outside it with the git form (`{ "git": …, "branch": "feat" }`) — the object
form is the only one (decision 76). rakun has no library dependencies:
the HTTP transport `Rakun.run` starts is its own `runtime.mjs` `serve`, over node's
`http` module (commonJS only). The runtime `.mjs` files are shipped
next to the emitted modules by the CLI (**G2**), so a consumer build resolves
every `#[@External.Node]` require.

## See also

- The embedded standard library → [`../botopink-lang/libs/std/docs.md`](../botopink-lang/libs/std/docs.md).
- The runnable end-to-end app → [`./examples/rakun/`](examples/rakun/).
- The `.bp` libraries group contract → [`../AGENTS.md`](../AGENTS.md).
