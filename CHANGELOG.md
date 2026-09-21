# rakun · CHANGELOG

## Unreleased

> **On the numbers below.** The shared compiler binary was rebuilt partway
> through front 05 and closed two erlang-backend gaps (module-level `val` side
> effects, `behavior` method dispatch). The counts in front 05's first two
> entries — 39/39 and 67/67 on commonJS, 29 and 57 passing on erlang — were
> taken with the PREVIOUS binary. Against the rebuilt one, with the whole front
> in the tree: `botopink test` 87/87 and `botopink test --target erlang` 85
> passing / 2 failing, the two reds being `{badkey,param}`/`{badkey,query}` in
> front 04's `server_test.bp`.

> **The erlang baseline moved mid-front.** Front 06 opened against a compiler
> that had broken a record field read on erlang: nine rakun cells failed
> `{error, badarg}` with an empty RUN LOG, and steps 1 to 4 are reported against
> that 200/9 baseline. The fix landed in the shared checkout during step 5
> (`fix/erl-record-field-read`), and from step 5 on the erlang row is
> 250 passing / 2 failing — the two being front 04's own `request/6`
> (`{badkey,param}` / `{badkey,query}`), which AGENTS.md § Blocked already
> records.

- **Application events and the boot sequence** (front 06, step 5).
  `modules/rakun/src/events.bp`: one `Event(name, source, payload,
  timestampMillis)` record, string-named, and the listeners that observe it.
  Spring dispatches by the listener PARAMETER's type and a method-level `@Decl`
  carries no parameter list, so `decl.parameters[0].typeName` — the 1.0.6-beta
  draft's step 5 — cannot be written; `#[managed]` emits the binding and
  `#[eventListener("Name")]` checks placement. Dispatch is synchronous and in
  registration order, and a listener that raises is recorded with its owner and
  stops nothing. Eleven new assertions in `test/events_test.bp`, on both rows.

  `context.bootSequence()` publishes the eight events with the eager pass
  between `ApplicationPrepared` and `ApplicationStarted`, and `ApplicationFailed`
  REPLACES the tail on failure — which is why `rkBeanTry` and `rkLifecycleRun`
  hand the failure back as text rather than raising: the sequence has to publish
  the failure event before it stops. The order is asserted as a WHOLE, by a
  listener per name appending to an ordered log, because a per-event test would
  pass with the events in any order.

  **`Event(name: …, timestampMillis: 0)`, the front's own example, does not
  compile.** An integer literal is `i32`, there is no widening and no cast, so an
  `i64` field cannot be given a value — the same gap `config.bp`'s `Duration` and
  `DataSize` record. `event(name, source, payload)` is the writable form and
  stamps `std/time` itself.

  **A module that imports `Context` must also import `Event`**, because
  `Context.publish`'s parameter type has to resolve at the use site; without it
  the diagnostic is `unknown type 'Event'` at an unrelated line.

- **Lifecycle: `#[postConstruct]` and `#[preDestroy]`** (front 06, step 4).
  `modules/rakun/src/lifecycle.bp`. The two markers are PLACEMENT CHECKS and
  emit nothing — a method-level `@Decl` carries no owner and no parameter list,
  so it cannot name the factory whose method it is, and the 1.0.6-beta draft's
  `rkRegisterLifecycle("<decl.name>", …)` inside a `#[postConstruct]` body would
  have registered the method's name as the component's. `#[managed]` is the only
  decl that sees both a method and its owner, so it emits one registration per
  marked method — the same split `#[getMapping]`/`#[restController]` already use.
  Eight new assertions on both rows.

  `rkRegisterLifecycle` takes the METHOD as well as the owner, where the README
  writes four arguments: step 4's own acceptance requires a failing hook to be
  named "component AND method". `post` runs in registration order and `pre` in
  reverse; the post pass marks an entry done, so "exactly once for a singleton"
  is a property of the pass rather than the caller's problem; the post pass stops
  the boot at the first raise and the pre pass logs and continues.

  **A type NAME is node-global on the erlang row.** `botopink test` runs each
  test file in its own process on node and in ONE node on erlang, where
  `rkSingleton`'s cache is a node-global ETS table keyed by type name. A third
  `Clock` in `test/context_test.bp` — beside the ones
  `overlapping_routes_test.bp` and `scopes_test.bp` already declare — turned both
  of THEIR cells red with `{error, undef}`, and the node row showed nothing.
  Every type this front's tests declare is now named for its file.

- **`#[provides]`, qualifiers and primary** (front 06, step 3). A factory
  FUNCTION whose return value enters the registry under its type, spelled
  `#[provides]` because `#[bean]` already exists and is frozen at a method.
  Exactly one provider of a type owns `__rkMake_<Type>` — the unqualified one or
  the `#[primary]` one — and the others get `__rkProvide_<fn>`, so the
  registration line has one shape and needs no conditional `@emit` (a bare `if`
  may only be a comptime block's last statement). Five new assertions on both
  rows.

  **Two unqualified providers do not fail the BUILD, as the README expects.**
  Measured: two emitted `pub fn __rkMake_Ledger` definitions compile. The
  duplicate check in `rkRegisterBeanAt` catches it at MODULE LOAD instead, and
  names both functions — the acceptance's wording met at boot rather than at
  compile time, and the reason `owner` is a field of the bean record. Two
  QUALIFIED providers with no `#[primary]` own the name neither time, so a field
  of that type is a genuine build failure at its injection site.

  **`beanNames()` is not `rkScannedNames()` filtered**, which step 2's acceptance
  says it is. True of `#[managed]`, false of `#[provides]`: a provided bean's
  type is never scanned, because the scan registers component declarations and
  `Clock` is not one.

- **`Context`, and the parent/child chain** (front 06, step 2).
  `pub type Context(scopePath)` carries `resolve` / `resolveNamed` / `has` /
  `beanNames` / `child` / `path`, and `__rkMake_Context()` makes it injectable by
  type with no extra step — the factory is exempt from the cycle guard (it is
  constructed before the scan runs and depends on nothing) and registers no bean,
  so `Context` does not appear in its own `beanNames()`. `ctx.child("request")`
  is a real chain rather than a label: it looks in its own registry first and
  delegates upward on a miss, which is what front 62 builds the per-request scope
  on. Six new assertions, green on both rows.

  **The receiver has to be an annotated local.** `__rkMake_Context().resolve(…)`
  and `val ctx = __rkMake_Context();` both lose the optional's payload type, so
  every call site writes `val ctx: Context = __rkMake_Context();`. That is the
  `§ Language notes` row about a record method's optional and an unannotated
  receiver, met again.

- **The bean registry, and why it holds factories** (front 06, step 1).
  `modules/rakun/src/context.bp` is the first of the container's doors:
  `#[managed]` stacks under a stereotype and `@emit`s one
  `rkRegisterBean(type, qualifier, scope, primary, lazy, owner, factory)` line,
  and the registry stores the FACTORY beside the record. `rkScan` stores a
  string and nothing turns a string back into a constructor, which is why
  "resolve by name" could not be built on the scan; a table of factories is what
  makes resolution, eager initialization and the shutdown pass all reachable
  from one place. `rkResolve` / `rkResolveNamed` / `rkHasBean` / `rkBeanNames`
  are the doors; a tie between two candidates with no `#[primary]` RAISES naming
  both owners rather than picking first-wins, and `rkHasBean` never raises
  because an ambiguous type is still registered.

  **This front ships both host files, and the measurement is its own.** Front
  05's config readers were pure, so one botopink implementation answered both
  rows; what this registry stores is a bean factory, a lifecycle thunk, a
  listener closure and an exit-code generator — four funs, and no string
  property table holds a fun. (The 1.0.6-beta sketch that resolved through
  `list_to_existing_atom("__rkMake_" ++ Name)` could not have run either: an
  atom is not callable.) So `src/context.mjs` and
  `src/sidecars/rakun_context.erl` exist, and front 05's three conditions are
  satisfied rather than waived — every cell carries BOTH forms, `runtime.mjs` is
  untouched, and the atom was verified by READING
  `.botopinkbuild/test-out/rakun_context.erl`, not by trusting exit 0.

  **Seven scalars, not the README's five.** The front's Mechanism writes a
  five-argument `rkRegisterBean` and its step 1 an ETS row of
  `{Primary, Lazy, Scope, Factory}`; five arguments have no room for the scope,
  and neither has room for the owner the front's own ambiguity message spells
  (`two beans of type 'Clock' ('systemClock', 'fixedClock')`). Both are carried
  rather than dropped.

  **A bean record carries its context path**, so `ctx.child(name)` is a real
  parent/child chain and not a label: a bean is visible from a path when it was
  registered at that path or an ancestor, and the nearest registration wins.
  Front 62's per-request scope and front 72's conditional layer are what will
  register into a child; nothing in rakun registers anywhere but the root today.

  13 new assertions, green on both rows: `botopink test` 222/222 and
  `botopink test --target erlang` 213 passing / 9 failing, the nine being a
  compiler regression in a record field read on erlang that predates this front
  (`router_test.bp`, `server_test.bp`, `erlang_runtime_test.bp`,
  `file_router_test.bp`, `overlapping_routes_test.bp` — `{error, badarg}` with an
  empty RUN LOG), measured at 200/9 on this branch's fork point.

- **The request frame, its epoch and the five phases** (front 62, step 1).
  `modules/rakun/src/request_context.bp` opens the scope every server-side read
  of a cookie or a header goes through: `beginRequest(RequestScope(…))` writes
  one key and answers a monotonic epoch, `setPhase`/`requestPhase` store the one
  phase front 12's `rkCachePhase()` is to read, and `endRequest()` erases the
  key. A nested `beginRequest` raises naming the outer scope's path, an
  `endRequest` with no frame raises, and after `endRequest` the key is ERASED
  rather than blanked — `requestEpoch()` raises rather than answering zero.

  **The scope is a frame, not a process.** A keep-alive connection process
  serves many requests in sequence, so process identity is not request identity,
  and a scope implicit in the process leaks the previous request's cookies into
  the next one. Every handle carries the epoch it was minted with; a handle used
  after `endRequest`, or from the next request on the same connection, raises.
  That assertion is the first test in the file, deliberately.

  **This front ships both host files, and the argument is front 22's, not front
  05's.** The test is whether the thing being stored is PURE. Front 05's config
  readers were, so one implementation over `std` answered both rows. This frame
  is not: it carries a queue of deferred thunks and a memo table of arbitrary
  typed values, and no string table holds either — the same sentence front 22
  wrote about a registered renderer. `request_context.mjs` and
  `sidecars/rakun_request_context.erl` hold a slot store and nothing else; the
  phase table, both wire grammars, the cookie serialization, the draft signature
  and every refusal message are botopink, compiled twice. Front 05's three
  measurements are each satisfied rather than waived: every cell carries both
  forms, `runtime.mjs` is untouched, and the atom `rakun_request_context` is
  named in emitted output, verified in `.botopinkbuild/test-out/`.

  One new compiler shape is recorded in `AGENTS.md` rather than worked around:
  **a `@panic` message must be pure ASCII**, because `asserts.throwsWith`
  catches through `io_lib:format("~p:~p", …)` and `~p` renders a binary holding
  a non-Latin-1 byte as a list of numbers — an em dash in a refusal makes the
  message match no needle at all. Measured: `botopink test` 148/148 (was
  136/136); `botopink test --target erlang` 146 passing / 2 failing (was 134/2),
  the same two front-04 `request/6` reds.

- **`headers()`, and the dynamic marker every accessor goes through** (front
  62, step 2). `headerNames` / `headerLookup` / `headerPresent` read the
  `name\tvalue` wire with the wire as a PARAMETER, so the grammar is asserted
  with no frame and no socket; `headers()` is the frame-bound face of the same
  three and answers a `Headers` handle carrying the epoch it was minted with.
  A name is case-folded on both sides, a header sent twice answers both values
  joined with `", "` (RFC 9110 § 5.3), and an absent header answers `null`
  rather than `""` — the one place this front deliberately differs from
  `Request.header`, which is frozen at plain `string`. A read in phase `Render`
  or `Handler` marks the render dynamic and records the FIRST reason; in a
  `strict` frame it raises instead, naming the function and the route.

  A second compiler shape, recorded rather than worked around: **the optional a
  record method answers loses its type when the receiver is a call or an
  unannotated local**, so `headers().get(n).unwrapOr(d)` is `unwrapOr is not a
  function` on node and `function unwrapOr/2 undefined` on erlang. The typed
  form is `headerOf(h, name, fallback)` — the same shape `paramOf` already
  exists for in `file_router.bp`, one type further out. Measured:
  `botopink test` 159/159; `botopink test --target erlang` 157 passing / 2
  failing, the same two front-04 reds.

- **`cookies()`, the `Set-Cookie` queue and the cookie wire** (front 62, step
  3). `serializeCookie(name, value, attrs)` is the one place a cookie becomes a
  wire line and is pure, so it is asserted as a literal string with no socket
  near it; `cookieNames` / `cookieLookup` / `cookiePresent` read the request
  header the same way. A chunk with no `=` contributes nothing, a trailing `;`
  and spaces around the separators parse without inventing entries, the first
  occurrence of a repeated name wins, and a cookie name is case-sensitive where
  a header name is not. `set` and `delete` raise in phase `Render` and phase
  `After` — by the time a render runs the response head may already be on the
  wire, which is why `§ 10` puts cookie writes in server actions. Front 04's
  `rkSetReplyHeader/2` replaces by name and so carries one `Set-Cookie` and no
  more; the lines are therefore queued on the frame and handed back from
  `endRequest()` as a `\n`-separated blob, two names producing two lines and one
  name producing the later value in its original position.

  **`cookieDefaults()`'s `maxAge: 0` is a defect of the front's text, honoured
  rather than silently corrected.** RFC 6265 § 5.2.2 expires a cookie whose
  `Max-Age` is at or below zero, so the specified default writes a line the user
  agent deletes on arrival: `maxAge: 0` is the deleting end of the lifetime
  axis, not the restrictive end, and the restrictive-and-correct default omits
  `Max-Age` entirely (a session cookie). The literal
  `s=a%20b; Path=/; Max-Age=0; HttpOnly; Secure; SameSite=Lax` is an acceptance
  eleven fronts cite, so it is implemented as written and the argument is
  recorded in `AGENTS.md` for the front that owns sessions.

  Three more compiler shapes recorded rather than worked around: **`i32 / i32`
  is float division on commonJS and integer division on erlang** (`233 / 16` is
  `14.5625` against `14`), so every quotient here goes through
  `idiv(a, b) = (a - a % b) / b`; **`std`'s `unicode` module is `undef` on the
  erlang row from rakun**, so no UTF-8 round trip is available; and **a
  non-ASCII string literal raises `{badarg, …}` on the erlang row**, so the
  positive case of the non-ASCII cookie refusal is not expressible as a cell and
  the guard, its text and the negative case are asserted instead.

  Measured: `botopink test` 174/174. On the erlang row the LIBRARY baseline
  moved under this front mid-step — the shared compiler binary was rebuilt by
  another thread (`botopink-lang` `98ad7cb1` → `a8087490`, C-01 half 3's
  identity-in-the-value work) and seven cells in `router_test.bp`,
  `server_test.bp`, `erlang_runtime_test.bp` and `file_router_test.bp` went red
  with `{error, badarg}` on a record field read. `botopink test --target erlang`
  is 165 passing / 9 failing: front 04's two `request/6` reds, those seven, and
  none of this front's. Verified by checking this front's tree out at its step-2
  commit against the same binary: the same nine.

- **`draftMode()`, `connection()` and the first-reason rule** (front 62, step
  4). `__rakun_draft` is a signed cookie, `token + "." + signature`, verified
  with `equalsConstantTime` — no early exit and the same comparison count
  whatever the inputs — so a forged cookie, a cookie signed with another secret
  and a signature one character short each answer false without raising. An
  empty `rakun.draft.secret` makes `enable()` raise naming the property rather
  than issue an unsigned bypass, which would be a public preview of every
  unpublished draft on the site. `enable()` queues the cookie with `HttpOnly`,
  `Secure` and `SameSite=Lax`, marks the request dynamic and sets the one
  boolean front 60 reads; the cookie it issues verifies on the next request,
  asserted end to end. `connection()` reads nothing and marks, which is its
  whole purpose, and `dynamicReason()` names the FIRST function to mark, not
  the last.

  **Two deviations from the front's text, both because front 01 has not
  landed**: `libs/std` has no `hmac`, `clock` or `encoding` module today, so the
  signature is `crypto.hmacSha256` (hex, not base64url) and the token is
  `crypto.randomBytes(16)`. Both carry both host forms and answer identically on
  the two rows — the property that matters — and `draftSign` is the one function
  to change when front 01 arrives. The draft cookie deliberately does not use
  `cookieDefaults()`: its `maxAge: 0` would delete the cookie on arrival, so
  `draftAttrs()` gives the bypass a day.

  A fourth compiler shape recorded rather than worked around: **a `from "std"`
  module imported by a `test/` file is `undef` on the erlang row**, while the
  same call reached through a `pub fn` in `src/` works. `std/crypto`,
  `std/base64`, `std/time` and `std/unicode` all behave this way; `std@dict` and
  `std@fs`, which rakun's own sources pull in, do not. Measured:
  `botopink test` 187/187; `botopink test --target erlang` 178 passing / 9
  failing, the same nine that are not this front's.

- **`after()` — work that runs once the response is sent** (front 62, step 5).
  `after(work)` pushes a thunk on the frame; `endRequest()` freezes a copy of
  the frame under phase `After` and starts the work, and the dispatcher writes
  the response and then calls `drainAfter(budget)`, which reaps. The child reads
  the headers and the cookies of the request it belongs to — asserted through an
  ETS scratch, because on the BEAM it is a different process — and answers
  `RequestPhase.After`; a cookie write and a second `after()` both raise there.
  A thunk that raises is counted and logged with the REQUEST ID and never
  reaches the client, the response being already written; a thunk that outlives
  `rakun.request.after.timeout` is counted and logged as killed. The frame is
  gone before the work runs: `requestEpoch()` in the parent raises while a
  sleeping child is still outstanding.

  **One place the two rows are not the same mechanism, stated rather than
  papered over.** On the BEAM each thunk is a `spawn_monitor` child and an
  overrunning child is KILLED. Node has no process and cannot interrupt a
  synchronous function: it runs each thunk in a try/catch with the same frozen
  copy installed and counts a thunk that OVERRAN in the slot the BEAM kills
  into. The counters and the log agree; the interruption is real on one row and
  after the fact on the other, and no assertion claims otherwise. Measured:
  `botopink test` 195/195; `botopink test --target erlang` 186 passing / 9
  failing, the same nine that are not this front's.

- **`request_memo.bp` — the `React.cache` analogue** (front 62, step 6).
  `memoize(key, load)` is `rkSingleton` one scope down: two calls with one key
  run the loader once, `memoHits()` is 1 and `memoMisses()` is 1, and the hit
  does not evaluate the loader at all — asserted with an ETS counter, because a
  local would be captured by the closure and prove nothing. Two requests with
  the same key run the loader twice; a loader that raises stores nothing, so the
  next call runs it again. `preload(k, load)` then `memoize(k, load)` runs the
  loader once and answers the preloaded value, a second `preload` for one key
  starts nothing, and a `memoize` over a preload that is still running waits for
  the child — asserted with a loader that sleeps. The `#[@future]` row holds
  too: the eager erlang lowering means the first call stores a value, so the
  second is the resolved-value row.

  `preload` is not built on `@Future` and cannot be: on erlang `@Future<T>`
  lowers eagerly, so `await` is identity and there is no third state in which
  the frame holds an unresolved future. It spawns a monitored child and stores a
  pending marker instead. Node has no process, so `preload` there runs the
  loader immediately — the pending row is a BEAM shape, and every assertion the
  front makes holds on both rows. `memoKey` joins with `|`, prefixes the name,
  does not hash, and refuses a part carrying the separator: a key two argument
  lists can produce is a memo that answers the wrong record. Measured:
  `botopink test` 205/205; `botopink test --target erlang` 196 passing / 9
  failing, the same nine that are not this front's.

- **The dispatcher contract, written down once** (front 62, step 7). This front
  owns no dispatcher; it owns the contract four of them must honour.
  `endRequest()` runs on the failure path too — asserted by raising a handler,
  tearing down and checking the next request on the same process sees a clean
  frame, since otherwise a keep-alive connection starts request N+1 inside
  request N's scope. The `Set-Cookie` blob splits on `\n` into whole header
  values and a cookie value can never split it, asserted with a value carrying a
  literal `Set-Cookie:` injection that comes out as `%0ASet-Cookie`. The
  phase-to-permission table is five literals in `permissionRow` — `yyyyn`,
  `yynyy`, `yyyyn`, `yyyyy`, `yynnn` — so fronts 12, 23, 24, 25, 60, 63, 64, 65
  and 66 inherit it rather than re-deriving it.

  **`targets` still reads `["commonJS"]`**, the call front 04, front 05 and
  front 22 each made for the same reason: the member's erlang row carries reds
  that are not this front's, and widening now would move a known red into
  `botopink-lib-test` rather than fix anything. All 73 of this front's
  assertions are green on BOTH rows.

  The spec's two example programs live under its own `examples/` directory in
  the meta repository's `specs/` tree, which this worktree may not write; the
  developer's view is in `docs.md` instead, and an example MEMBER exercising a
  layout or a server action would need fronts 23 and 24, neither of which has
  landed. Measured: `botopink test` 209/209 (was 136/136 at this front's
  baseline); `botopink test --target erlang` 200 passing / 9 failing, the same
  nine that are not this front's.

- **The route table crosses the boundary, and one matcher reads it on both
  rows** (front 22, steps 3 and 4). `RouteEntry(kind, pattern, slot, verb)`
  writes as `kind|pattern|slot|verb`, one record per line in registration order,
  with trailing empty fields dropped so no line ends in a bar; `parseTable` reads
  a short line back as empty fields and the round trip is asserted field by
  field over one entry of each of the eight kinds, on both targets.
  `matchPath` applies the precedence segment by segment — static, dynamic,
  catch-all, optional catch-all — so `/blog/new` beats `/blog/[slug]` and
  `/shop/[id]` beats `/shop/[...rest]`, with registration order deciding a tie.
  `/shop/[...slug]` does not match `/shop`; `/docs/[[...slug]]` matches `/docs`
  with an empty `rest`; a pattern carrying only an `L` entry is not public and
  answers `null`; a slot entry is not a candidate. `layoutChain` walks the
  pattern's ancestors root-first, and a group never reaches it because
  `patternOf` dropped it. `paramOf(m, name)` is how a bound parameter is read —
  the optional binder loses the match's type, so `m.params.at(name).unwrapOr(…)`
  is a run-time `unwrapOr is not a function` on the node row. Measured:
  `botopink test` 113/113; `botopink test --target erlang` 111 passing / 2
  failing, the same two front-04 reds.

- **The four markers, the registry and the emitted parameter accessors**
  (front 22, steps 2 and 6). `#[layout(seg)]`, `#[template(seg)]`,
  `#[page(seg)]` and `#[defaultView(seg)]` take the app-relative directory of the
  file they sit in and `@emit` a module-load registration plus, for a page, an
  accessor `<name>Params(route) -> #(slug: string)` whose fields come from the
  bracket segments (`string[]` for a catch-all, `#()` for a route with none).
  They live in `file_router.bp` because `decorators.bp` is frozen — the same
  reason `#[configurationProperties]` lives in `config.bp` — and `default` is a
  reserved keyword, so the `default.bp` marker is `#[defaultView]`.

  **This front ships a `.mjs` AND an `.erl` where front 05 refused to, and the
  difference is that front 05's work was pure.** A registry is not: botopink has
  no top-level mutable state, and a registered render function is a closure no
  string table can hold. Front 05's three measurements still hold and none of
  them is violated — every cell here carries BOTH host forms, so neither row has
  a call with no binding; `runtime.mjs` is frozen but `file_router.mjs` is this
  front's own file; and the atom `rakun_file_router` is named in emitted output,
  so `shipErlSidecars` copies it, verified by looking in
  `.botopinkbuild/test-out/`. What the two hosts do NOT hold is the part front
  05's argument was really about: each is handed the finished
  `kind|pattern|slot|verb` line and appends it beside its function, so neither
  knows the grammar, the format or the matcher, and the browser and the BEAM
  cannot disagree about which route a URL is. "The same matcher compiled twice"
  is one botopink matcher on two targets, not two matchers.

  Two new measurements are recorded in `AGENTS.md` rather than worked around: a
  named function used as a VALUE is `variable 'BlogPostPage' is unbound` on the
  erlang row, so a marker emits `{ route -> blogPostPage(route) }`; and
  `decl.returnType` carries no type argument (`"Future"`, not
  `"@Future<Element>"`), so a page is checked to BE a future and the required
  spelling lives in the message. A third is why there are two test files: an
  `@emit`ted module-load `val` lands at the END of the emitted module, so a
  registration cannot be snapshotted in its own module, and `botopink test` runs
  each test file in its own process. Measured: `botopink test` 123/123;
  `botopink test --target erlang` 121 passing / 2 failing, the same two front-04
  reds.

- **The scan, in botopink, over real trees** (front 22, step 5).
  `scanAppDir(root, appDir)` walks the directory tree under `appDir`, skipping
  `_`-prefixed folders entirely, and answers the entries it implies, the
  project-root `middleware.bp` (front 07's, discovered by this scan with no
  `pub mod` line naming it) and the problems: a segment holding both `page.bp`
  and `route.bp`, two root layouts whose subtrees claim one URL — named with the
  URL and both groups — a registered segment with no directory, named with the
  function that registered it, and a directory holding a convention file that
  registered nothing. `appDirOf()` reads `onze.appDir` from front 05's table and
  defaults to `app`; scanning the same fixture as `app` and as `src/app`
  produces the same table, asserted. `rkAppRegisterSource(seg, fnName)` keeps
  the raw pair each marker was written with beside the table, because the wire
  record carries the URL pattern and the check needs the DIRECTORY.

  The front's text puts the scan in the two host files. It is botopink instead,
  for front 05's reasons one level up: a scan written twice can disagree twice,
  and an erlang-only cell cannot be asserted from a `.bp` test, so every rule
  above would have been taken on trust. The directory walk is rakun's rather
  than std's — `libs/std` has no `walk` today — and a name is a directory when
  `fs.list` succeeds, because `fs.stat`'s `FileStat` carries an `i64` field and
  an integer literal is `i32` with no widening, so a `catch` value for it cannot
  be written. Measured: `botopink test` 136/136; `botopink test --target erlang`
  134 passing / 2 failing, the same two front-04 reds.

- **`targets` still reads `["commonJS"]`** (front 22, a deliberate refusal
  repeating front 04's and front 05's). All 48 of front 22's assertions are
  green on both rows, and the member's erlang row is 134 passing / 2 failing —
  the two reds being front 04's `request/6` `{badkey,param}` / `{badkey,query}`.
  Widening now would move a known red into `botopink-lib-test`.
  `src/sidecars/rakun_file_router.erl` also inherits the toolchain gap front 04
  recorded: it ships and loads under `botopink test --target erlang`, and a
  `botopink build --target erlang` copies no sidecar at all.

- **The file-convention segment grammar** (front 22, step 1).
  `modules/rakun/src/file_router.bp` decodes a folder name into one of the seven
  `SegmentKind`s — static, `[dynamic]`, `[...catchAll]`, `[[...optionalCatchAll]]`,
  `(group)`, `@slot` and `_private` — in `parseSegment`, the only place either
  spelling is read. `patternOf` drops groups and slots and keeps the bracket
  spelling (`(marketing)/about` is `/about`; `dashboard/@team/settings` is
  `/dashboard/settings` with `slotOf` answering `team`), and `parsePath` halts on
  a path that may not be registered — a `_`-prefixed folder, an empty segment, or
  a segment holding the wire format's `|` or newline — with `pathProblem` naming
  the offending segment. The refusal text is its own function, as
  `durationProblem` is, so a test reads it without the halt taking the test down.
  Nine assertions, identical on both rows. Measured: `botopink test` 96/96 (was
  87/87); `botopink test --target erlang` 94 passing / 2 failing (was 85/2, the
  same two front-04 reds).

- **`#[configurationProperties]` binds a record, and every key it declares lands
  in a catalogue** (front 05, steps 7 and 9). The decorator emits
  `__rkBind_<Name>(prefix)`, the ordinary DI factory `__rkMake_<Name>()` and a
  module-load `val __rkCat_<Name> = rkRegisterConfigKeys(…)`. The prefix is a
  PARAMETER, which is what makes `#[nested]` compose without either decorator
  knowing the other — two levels are asserted — and the ordinary factory name is
  what makes a bound record injectable by type into a `#[service]` with no extra
  wiring, also asserted. `#[unit]`, `#[defaultValue]`, `#[validated]` and
  `#[enableConfigurationProperties]` come with it. `rkConfigLoad` registers
  rakun's own `rakun.main.*`, `rakun.server.*`, `rakun.config.*` and
  `rakun.profiles.*` keys beside the application's. Two departures from the
  spec, both recorded in `AGENTS.md`: relaxed binding is in the reader rather
  than the emitter (three spellings instead of one, and a decorator body cannot
  call a helper), and a list field is recognised by an EMPTY `@Decl` `typeName`,
  which is the only signal the reflection offers for a generic type.

- **Placeholders, random values and the typed readers** (front 05, steps 4 and
  8). `${key}` and `${key:default}` resolve at load time, recursively; an
  unresolvable reference with no default and a reference cycle each refuse the
  boot naming the keys. `${random.value|int|long|uuid|int(n)|int[lo,hi]}`
  resolves at REFERENCE time through `rkValue`, so two reads answer differently
  and nothing is cached — asserted with a thousand draws inside the range and a
  v4 UUID whose version and variant nibbles are checked. `Duration` and
  `DataSize` parse the Spring forms including ISO-8601, and an unparsable value
  halts naming the key, the value and the accepted forms. `rkPropBool`,
  `rkPropIntOr`, `rkPropFloat`, `rkPropList`, `rkPropDuration` and `rkPropSize`
  carry the declared default as their second argument (row 8) and do relaxed
  binding in the reader, so `remoteAddress` binds from `remote-address`,
  `remoteAddress` or `REMOTE_ADDRESS`.

- **Configuration resolves, in order, with profiles** (front 05, steps 2, 3, 5
  and 6). `rkConfigLoad()` merges the eight sources — command line,
  `RAKUN_APPLICATION_JSON`, `RAKUN_*` environment variables, profile documents,
  base documents, configuration trees, `rkSetProp`, declared defaults — each row
  with a test asserting it beats the row below, plus a full-stack test setting
  one key in six of them. `rakun.config.name`/`rakun.config.location` choose the
  documents, a location without `optional:` that does not exist refuses the boot
  naming the path, and `rakun.config.import` resolves after its importer with a
  cycle refused naming the chain. `src/profiles.bp` owns the profile set:
  `active`, `default`, `include[i]` and transitive `group.<name>[i]` (the group
  name activated beside its members, a self-reference refused), read back in
  activation order through `profiles.active()`. A document may carry
  `rakun.config.activate.on-profile` (names, `|`, `&`, `!`, parentheses) and
  `on-cloud-platform`, both of which must hold, and a document whose conditions
  do not hold contributes nothing. Measured: `botopink test` 67/67 (was 39/39);
  `botopink test --target erlang` 57 passing (was 29), the same six
  pre-existing reds.

- **Configuration documents load** (1.0.10-beta front 05, step 1).
  `modules/rakun/src/config.bp` reads `.properties` (comments, `\`
  continuations, `#---` document separators), `.json` (a flattening scanner that
  emits `server.port` and `a[0]` as it walks, written here because std's `json`
  answers a string with nothing to walk) and a documented YAML SUBSET (block
  mappings, block sequences, plain and quoted scalars, `#` comments, `---`
  separators) plus `configtree:` directories, and writes every entry through
  front 04's `rkSetProp` — two modules, one table. An anchor, an alias, flow
  style, a block scalar or a tag is a located refusal naming the file and the
  line. The readers are botopink rather than the spec's
  `sidecars/rakun_config.erl`: an erlang-only cell is a located node-row
  diagnostic at its call site, so it could not be asserted from `test/*.bp` at
  all (see `AGENTS.md` § Externalized configuration). Measured:
  `botopink test` 39/39 (was 31/31); `botopink test --target erlang` 29 passing
  (was 21), the same six pre-existing reds.

- **The host runtime runs on the BEAM** (1.0.10-beta front 04, steps 1-4).
  `modules/rakun/src/sidecars/rakun_runtime.erl` is the erlang twin of
  `runtime.mjs`: an `application` whose `rakun_sup` supervises the
  `rakun_registry` `gen_server` that owns five `named_table, public,
  {read_concurrency, true}` ETS tables (scan list, singleton cache, build
  counts, property map, route table), with the dependency-cycle guard in the
  process dictionary. There is no `rakun.app` file — a sidecar is compiled at
  run time by `__bp_load_siblings/0` — so the spec is loaded from a term, which
  is what makes `application:start(rakun)` available in a plain
  `botopink test --target erlang` run. Fifteen of the sixteen cells in
  `src/runtime.bp` gained an `@External.Erlang("rakun_runtime", "<snake_case>")`
  form beside their node one; `rkServe` was paired with the acceptor, below.
  The module atom is `rakun_runtime`, never `runtime`: `shipErlSidecars` skips
  an atom matching a module the build emitted, rakun emits `rakun/runtime`, and
  the skip is SILENT. Measured: `botopink test` 31/31 (was 17/17);
  `botopink test --target erlang` 21 passing (was 1) and
  `.botopinkbuild/test-out/rakun_runtime.erl` present. The six erlang reds that
  remain are two erlang-BACKEND gaps, recorded in `AGENTS.md` § Blocked;
  `botopink.json` keeps `targets: ["commonJS"]` until they close.

- **The BEAM serves HTTP** (front 04, steps 5-9). `rakun_runtime` gained the
  `gen_tcp` acceptor (`{packet, http_bin}`, so OTP parses the request line and
  the headers and rakun writes no HTTP parser and depends on nothing outside
  `kernel`), one process per connection under `rakun_conn_sup`, per-request
  reply headers in the process dictionary, `boot/1` (banner, PID file, port
  file, headless, keep-alive), a startup-failure table consulted before the node
  halts, and the transport seam that delegates to `rakun_<name>:serve/2` — an
  unloadable named transport is a failure naming the module, never a silent fall
  back to the acceptor. `rkServe` is paired, so all sixteen cells now carry both
  forms. Cowboy is deliberately NOT a dependency: a sidecar is compiled by
  `compile:file/2` at run time with no rebar and no code path, so
  `cowboy:start_clear/3` would compile and then die with `undefined function`.
  `runtime.mjs` is frozen, so `set_reply_header/2`, `reply_headers_json/0`,
  `boot/1` and `add_failure/3` have no `rk*` cell — a cell with no node form
  reddens the commonJS row, which compiles every `test/*.bp` with no per-target
  gate. They are exercised from erlang instead; the key set is in `AGENTS.md`.

- **`targets` stays `["commonJS"]`** (front 04 step 10, a deliberate refusal).
  The erlang host module is complete and 21 of rakun's tests run on the BEAM,
  but `botopink test --target erlang` is not green: six registration assertions
  fail and `server_test.bp` does not compile, and every one of those reds is an
  erlang-BACKEND gap (`AGENTS.md` § Blocked), not rakun's. Widening `targets`
  now would move a known red into `botopink-lib-test` rather than fix anything;
  `erlang` joins in the change that closes the gaps. rakun has no line in
  `botopink-lang/scripts/known-red-libs.txt` — that file lives in the compiler
  repository and holds only its header — so nothing is deleted there either.
  The core manifest's description now names both host runtimes.

- **`test/erlang_runtime_test.bp`** names the host cells directly instead of
  reaching them through the decorators, so it covers what the older five cannot:
  declaration order in the scan registry, the `parseInt` rule behind
  `#[value("key")]` (`"12abc"` is `12` on BOTH rows), registration order between
  two matching routes, and the shape `Response` lowers to when it round-trips
  through a host call. Fourteen assertions, identical on commonJS and erlang.

- **The repository is a workspace** (`02-packaging` step 2; decisions 75 and 76 of
  1.0.10-beta). `botopink.json` at the root is `{ name, version, description, targets
  [commonJS, erlang], workspaces ["modules/*", "examples/*"] }` — no `src`, `files`, `target` or
  `dependencies`; `botopink build/test` there is the located refusal naming the members. The
  core moved with `git mv` to `modules/rakun/` (`src/**` incl. `runtime.mjs`, the five
  `test/*_test.bp`) and its manifest lists `files: [root, http, runtime, decorators, bootstrap,
  rakun.d]`, `targets: [commonJS]` (a restriction of the workspace's; front 04 adds erlang).
  The thirteen scaffolds gain `files: ["root.bp"]` (a library member without `files` is
  `✗ ships nothing`), `targets` per `03-rakun/modules.md` § Targets (erlang, except
  `rakun-validation` and `rakun-test`: both), and `{ "rakun": { "workspace": true } }` in place
  of the refused `{ "path": "../../" }`; none is renamed (every scaffold is a KEEP of the
  reconciliation table). `examples/rakun` is the member `rakun-example` (renamed from
  `rakun-app`, the name front 22's submodule takes — duplicate member names are refused),
  depending on `rakun` via `{ "workspace": true }` instead of the git form. The pre-commit
  runner is workspace-aware: `botopink test` in every `modules/*/` member, then the examples
  gate. Measured: core 17/17 commonJS at its new path; the example builds and answers the
  documented routes; `botopink-lib-test` prints 15 member rows and no umbrella row.

- **The 1.0.3 surface** (botopink-lang front 12): records and the enum are `type`s, `Request`
  and `Context` are `behavior`s, and the sources are `botopink format`ted. The component
  markers check `decl.kind != DeclKind.Type` plus `decl.variants.length > 0` (an enum-shaped
  `type` is rejected: "#[service] must annotate a type with fields, not an enum"). commonJS
  17/17; the example server answers every baseline route identically.
- The examples gate no longer aborts silently on a `scripts/known-broken-examples.txt`
  holding only comments or blank lines: the runner reads the list with `awk`, whose
  "no entry" is not a failure under `set -euo pipefail`.

- **MIT license.** `LICENSE` (`Copyright (c) 2026 Eric Fillipe and botopink
  contributors`) backs the README's License section, which now points at it.

- The gate builds the examples: after `botopink test`, the pre-commit hook
  and CI run `botopink build` in every `examples/*/` with a `botopink.json`;
  `scripts/known-broken-examples.txt` lists the ones allowed to fail, and a
  listed example that builds fails the gate.
- The pre-commit hook is self-contained: the dead delegation to a meta
  workspace runner is gone, and `AGENTS.md` documents the install
  (`git config core.hooksPath scripts/git-hooks`) instead of a
  `scripts/install-hooks.sh` that exists in no repository.
- Promoted from workspace subdir to standalone repository under
  `botopink/rakun`. Tracked from `botopink/projects` as a git submodule on the
  `feat` branch.
- Dropped the `server` dependency, which named a library that exists in no
  repository (`botopink check` failed with `LibNotFound`). The node `http`
  transport `Rakun.run` starts is now rakun's own `serve` in `runtime.mjs`,
  bound as `rkServe` in `runtime.bp`. `botopink.json` gains `"target": "commonJS"`
  (the key the CLI reads) beside the lib-test `"targets"` whitelist.

## 0.0.1 — v0.beta.9

- **Scopes** (F2): `singleton` (default), `value` (config-bound), `bean` (factory).
- **Real HTTP server** (F5): `Rakun.run()` + node `http` module.
- Generic core: `commonJS` `require("../"×depth)` resolution + `libs.zig`
  sidecar shipping for `.mjs` files.
- Unit-test suite green + example serving over real HTTP.

## 0.0.0 — v0.beta.5

- Initial spec and framework scaffold; DI container core + `#[restController]`.
