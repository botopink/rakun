# rakun · CHANGELOG

## Unreleased

### Two concurrent requests, two request-scoped instances (botopink front 06 step 6)

- `test/context_test.bp` spawns two requests with `async.runAll` (one process
  each on the BEAM) and asserts each resolves its own request-scoped value, the
  same one twice. `modules/rakun` 336 / 0 → **337 / 0**.

### Row 7 beats row 8, asserted (botopink front 05 step 3)

- `test/config_test.bp` "row 7 beats row 8": `rkSetProp` wins over a typed
  reader's declared default, and the default answers when nothing set the key —
  the one row of the source table without its own cell. `modules/rakun` 335 / 0
  → **336 / 0**.

### The percent codec is std's `encoding` (botopink front 62 step 7)

- `request_context.bp` no longer declares `percentEncode` / `percentDecode` /
  `hexValue`: a `Set-Cookie` value is `encoding.percentEncode`d, and a cookie
  or query component is read through `decodeComponent` — `encoding.percentDecode`,
  keeping an escape that std refuses (`%zz`, `100%`) or that would decode to a
  control character (`%0A`, `%0D`) exactly as written. `rakun-app`'s
  `splitQuery` / `encodeQuery` read the same codec. Counts unchanged
  (`modules/rakun` 335 / 0, `rakun-app` 59 / 0).

### `.json` configuration reads through std's `json.decode` (botopink front 05, decision 117 rule 7)

- `parseJson` is std's RFC 8259 reader plus a flattener (`a.b.c`, `a[0]`); the
  hand scanner (`jsonString` / `jsonUnquote` / `jsonScalar`, ~150 lines) is
  gone. `\u0041`, `\b` and `\/` decode; a trailing comma or a duplicate member
  is refused with `json.decode`'s message, prefixed by the file. A number is its
  shortest text (`8080` stays `8080`). `test/config_test.bp` +2:
  `modules/rakun` 333 / 0 → **335 / 0**.

### `#[validated]` configuration refuses the boot (botopink fronts 05 step 9 and 14 step 6)

- `#[configurationProperties]` + `#[validated]` registers a boot check
  (`__rkCheck_<Name>`, `rkConfigCheckRegister`); `bootSequenceFor` installs the
  message source and runs every check after binding and before the eager pass,
  and an invalid configuration fails the boot with every violation line naming
  its property key — no component constructed. Three cells
  (`rkConfigCheckRegister` / `rkConfigCheckRun` / `rkConfigCheckReset`) and
  `config_check.configProblemOf`. `test/config_check_test.bp` +4:
  `modules/rakun` 329 / 0 → **333 / 0** (erlang).

### rakun is erlang-only; the BEAM listener, measured (botopink front 04 steps 2, 5–7 and 10; decisions 113, 117 rule 9)

- **Every manifest is `["erlang"]`** — the workspace root, the core (`"target":
  "erlang"`), `rakun-app`, `rakun-test`, the ten scaffolds and the three examples.
  The node host halves are deleted: `runtime.mjs`, `context.mjs`,
  `request_context.mjs`, `autoconfig.mjs`, `ssl_bundle.mjs`, `rakun-app`'s
  `file_router.mjs` / `ssr.mjs`, `rakun-web`'s `chain.mjs`; no
  `#[@External.Node]` form remains in any member.
- **The two erlang reds are closed.** `request/6` built a map with data under
  `query` / `body` and no method funs, so `req.param("name")` —
  `(maps:get(param, Req))(Req, N)` on the erlang backend — found nothing. The
  map now carries `param` / `query` / `header` / `body` as funs taking the
  receiver first, and the data under `params` / `query_map` / `headers` /
  `body_bin`.
- **The acceptor answered no handler's `Response`.** `run_handler` matched a
  `#{status, body}` map, while a handler's `Response` reaches it as the record
  the backend lowers it to (`{'rakun@http@@Response', Status, Body}`), so every
  request over the socket was a `try_clause` crash. `response_parts/1` reads
  either shape. Found by the first test that spoke HTTP to the listener.
- **First construction of a singleton is serialised per name** (`?LOCKS`, an
  `insert_new/2` claim): twenty processes racing an uncached singleton build it
  once (50 racing built it 50 times before). A claimant re-entering its own
  claim is a cycle and builds again, which is where `enter/1` raises.
- **Three cells**: `rkSetReplyHeader`, `rkReplyHeaders`, `rkBoot` (front 04's
  surface, erlang-only now that the core is).
- **`test/erlang_runtime_server_test.bp`** (18 cells) boots the acceptor on port
  0 with `rakun.main.keep-alive=false` and speaks HTTP/1.1 through std's
  `io.net`: 200 / 404, a POST body holding `\r\n\r\n`, the first of a
  repeated query key, case-insensitive headers, 500 then 200, reply headers on
  the wire and not leaking across keep-alive requests, the unchanged head of a
  handler that sets none, 503 over `max-connections`, the idle timeout, a slow
  connection not holding up another, the port and pid files, headless, and the
  singleton race, and a connection process killed mid-request leaving another
  in-flight request alone. `modules/rakun`: 310 / 0 → **329 / 0**; `rakun-app`
  59 / 0, `rakun-test` 1 / 0 — erlang, the only row.
- **`modules/rakun-web/test/dispatch_seam_test.bp`** drives front 04's one hook
  from the core side: a core route dispatched with `rkDispatchHttp` while a
  runner is installed goes through `rakun_chain:run/6`, a filter can stop it,
  and an empty chain is the identity. `rakun-web`: 104 / 0 → **107 / 0**. Its
  handler reads a path parameter because `req.query(…)` on a `Request`, in a
  module that also imports `WebRequest` (which declares its own `query/2`),
  lowers to `WebRequest:query/2` on the erlang backend — a compiler defect.
- **Owed elsewhere**: a BUILT erlang program neither ships nor loads its
  sidecars, so the three examples build but do not run (the compiler's
  `00 · 10-cli-residuals`); the compiler repository's
  `scripts/restricted-targets.txt` still pins the old matrix.

### The package cut: `rakun-app` and `rakun-test` (botopink front 95)

- **`modules/rakun-app/` is new**, the server half of the Next.js `app/` router
  `specs/1.0.10-beta/03-rakun/modules.md` § The cut splits out of the core: front
  22's `file_router.bp` (+ `file_router.mjs`, `sidecars/rakun_file_router.erl`) and
  front 23's `ssr.bp` (+ `ssr.mjs`, `sidecars/rakun_ssr.erl`) moved with their four
  suites and the `test/fixtures/{routing,conflict-both,conflict-roots,middleware}`
  trees. A relocation only: the edits are the import lines the move changes
  (`from "http"`/`"runtime"`/`"config"` → `from "rakun"`; the request context
  `from "rakun/request_context"`, because a bare `from "rakun"` finds std's
  `encoding.percentDecode` too and the compiler refuses the ambiguity). Nothing in
  the core imported either module. The member declares no `targets`, so it
  inherits the workspace's two. `modules/rakun`: 369 → 310 / 0 on commonJS,
  367 → 308 / 2 on erlang (the same two reds); `modules/rakun-app`: 59 / 0 on both
  rows. `examples/rakun-ssr` imports the pipeline `from "rakun-app"` and prints
  what it printed before.
- **`modules/rakun-test/` has its one inline test** — the core resolves from the
  test member (`toI32("42") == 42`), 1 / 1 on both rows; the `pub` surface stays
  empty until front 19.
- The pre-commit hook's front-23 greps read `modules/rakun-app/src/ssr.bp`.

### Bundled `routing` and `validation` (botopink `01-std` fronts 04 and 06; decisions 115, 116)

- **The file-convention grammar, wire and matcher left `file_router.bp`** for the
  compiler-bundled library `routing` (`segment`, `table`, `match`), imported by name
  with no dependency entry; rakun keeps the registry, the markers, `PageContext` /
  `LayoutProps` / `contextOf` and the `app/` scan. The 26 grammar/wire/matcher tests
  moved with the code (`libs/routing/test/`). `modules/rakun`: 388 → 369 / 0 on
  commonJS, 386 → 367 / 2 on erlang (−26 moved, +7 `config_check_test.bp`; the two
  erlang reds are the pinned `server_test.bp:74,80`).
- **rakun-web's two `:param` grammars are `routing`'s `pattern`**:
  `middleware.bp`'s `checkMatcher` / `matcherMatches` are `validateMatcher` /
  `matcherAdmits` over `parsePattern` / `matchPattern` (the empty matcher still runs
  everywhere — rakun-web's rule), and `filter.bp`'s `routeMatches` is `routeAdmits`;
  a refused matcher halts with `patternProblem`'s text. 104 / 0 on both rows, as before.
- **`modules/rakun-validation` is gone** — the bundled `validation` library holds its
  seven modules (54 tests, both rows). `boot.bp` is `modules/rakun/src/config_check.bp`
  with its tests; `config_check.installMessageSource()` hands `validation` a
  `MessageSource` over `rakun.validation.*`, and `Rakun.run` installs it at boot.
  `config.bp`'s placement-only `#[validated]` is removed: a same-named decorator in the
  package shadowed the imported one (the registry is keyed by name).


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

- **Effects by return type** (botopink front 24, step E7, decisions 118–128).
  `modules/rakun/src/{config,profiles,ssl_bundle,ssr,file_router,request_memo,request_context}.bp`,
  `modules/rakun/test/{file_router,file_router_markers,request_memo,ssr}_test.bp`,
  `examples/rakun-ssr/src/main.bp`, comments in `rakun-web` / `rakun-validation`
  and both sidecars, `AGENTS.md`, `docs.md`.

  Every effect annotation is gone: the return is the annotation. The nine
  `result` annotations leave their `-> @Result<…>` functions unchanged; the
  seventeen `future` annotations go and every one-argument `@Future` is `@Task` — none of
  rakun's futures carried an error (no body throws or tries, and `render`
  answers a miss as the status 404), so no `await` became `try await` and no
  return gained a `@Result`. `rkSsrAll`, the host gather, is `-> @Task<Array<T>>`:
  per decision 126 a rejection there is a fatal host failure, which is what a
  crashed thunk already was.

  The file-convention markers read `decl.returnType == "Task"` where they read
  `"Future"`: `#[page]` requires a `-> @Task<…>` return, and `#[layout]` /
  `#[template]` / `#[defaultView]` refuse one. The refusal texts name `@Task`.

  `request_context.bp` gains `RequestBase` (a field-less marker type) and
  `RequestScope` now `implement @Context<RequestBase>` — the base a request hook
  (`-> @Component<RequestBase, T>`) anchors at, decision 128 / the guide's § 4.4.
  No accessor became a hook.

  Open point 8 (the error of a failing render; whether `ChunkWriter.write` stays
  infallible) is recorded in the meta repository's
  `specs/1.0.10-beta/decisions-pending.md`; nothing here spells those types yet.

- **The `std` substitutes, measured and settled** (front 74 follow-up).
  `modules/rakun/src/ssr.bp`, `modules/rakun/test/ssr_test.bp`,
  `modules/rakun/src/events.bp`, `modules/rakun/src/request_context.bp`,
  `modules/rakun-web/src/filter.bp`, `AGENTS.md`.

  Three compiler defects closed in `fecec6b4` made a `from "std"` module
  reachable from a `test/` file on the erlang row: a prelude-defaults guard on
  `comptime_module != null`, an escript sibling loader that ended its case in
  `_ -> ok` and so skipped a module `erlc` had refused in SILENCE, and — the one
  that bit rakun — the loader being emitted only when `imported_fns` /
  `imported_types` / a type module were present, which a `from "std"` import
  fills none of. rakun had written the rule down four times and built two
  substitutes around it.

  Re-measured on `4fe1747e` with one throwaway test file per module, each
  carrying an arithmetic control cell, on BOTH rows:

  | std module      | commonJS | erlang |
  | --------------- | -------- | ------ |
  | `querystring`   | 2/2      | 2/2    |
  | `time`          | 2/2      | 2/2    |
  | `unicode`       | 2/2      | 2/2    |
  | `crypto`        | 2/2      | 2/2    |
  | `base64`        | 2/2      | 2/2    |

  All five. So: `ssr.bp`'s `nowMs()` / `sinceUnder()` are DELETED and the one
  timing cell in `ssr_test.bp` calls `time.monotonicMillis()` itself — still two
  calls rather than `time.measureMillis(body)`, because the body being measured
  is an AWAIT and a `@Task` body (then `@Future`) may not await inside a closure. The dead
  rule is deleted from `AGENTS.md` and the clauses that leaned on it in
  `events.bp`, `filter.bp` and `request_context.bp`'s percent-encoding header
  (three reasons to two, the same correction `AGENTS.md` carries) are gone with
  it; `filter.bp`'s `rkFreshId` keeps its real reason (a correlation handle is
  not a token).

  **`splitQuery` / `encodeQuery` STAY, for a reason that is not loading.**
  `AGENTS.md` said they were "two bodies to delete when std is fixed"; std is
  fixed and the sentence was wrong, because std's `querystring` does LESS.
  Measured directly: `querystring.parse("a=%20b")` reads back the literal
  `%20b` — it does not percent-decode, and `route.query` is a decoded dict;
  `querystring.parse("a=b=c")` splits on EVERY `=` and loses the `=c`, where the
  form grammar cuts at the first; and `querystring.stringify([#("a b", "c;d")])`
  is `a b=c;d`, a space and a `;` straight into a URL. std says so itself — "the
  call site should pre-escape". Swapping both bodies for the std calls left
  every other cell in the repository GREEN on both rows, which is the reason the
  difference is now an assertion and not a comment: the new cell `splitQuery /
  encodeQuery percent-code, which std's querystring does not` reds on all three
  lines under that swap, verified.

  One cell added, so `modules/rakun` is 387/0 → **388/0** on commonJS and
  385/2 → **386/2** on erlang, the two reds still front 04's `server_test.bp:74,80`.
  `modules/rakun-web` 104/0 and `modules/rakun-validation` 54/0 on both rows,
  unmoved. The timing cell was planted twice to prove it can fail: an
  always-false budget reds the erlang row only and an always-true one reds the
  commonJS row only — because the cell asserts `fast == concurrentRow()`, so
  each row pins one side of the clock.

- **`absolutePath` back onto `std/path`** (front 74 follow-up).
  `modules/rakun/src/ssl_bundle.bp`, `modules/rakun/test/ssl_bundle_test.bp`.

  Front 74 measured `std`'s `path` as `{error, undef}` on the erlang row and
  wrote `absolutePath` as three lines of string work around it. The compiler
  fixed `path` (with `querystring`, `queue`, `snapshots` and `url` — three
  defects, 19 call sites) in `4fe1747e`, and the substitute turned out to carry
  a defect of its own: it tested for a leading `/`, which is not what an
  absolute path looks like on Windows, and
  `.github/workflows/test.yml:50` runs `windows-2022` commonJS with
  `allow_fail: false`. Two things broke there — a Windows absolute path was
  treated as relative and prefixed with the working directory, so
  `missingFileProblem` named the wrong path in the one refusal whose whole job
  is to name the right one; and the cell asserting it read
  `resolved.indexOf("/") == 0`, which a `C:\...` answer fails.

  `path.isAbsolute` / `path.join` are used again, verified green on both rows
  before the change was written. The assertion is now idempotence —
  `absolutePath(absolutePath(p)) == absolutePath(p)` — which is the property
  `isAbsolute` actually provides and holds on a drive letter as well as on a
  leading slash. The obvious assertion, that the answer starts with
  `process.cwd()`, stays unavailable: a TEST file that imports `std`'s `process`
  still loses every cell in it on commonJS, and the comment in the cell says so
  rather than leaving the next reader to find out.

  Counts unchanged: `modules/rakun` 387/387 commonJS and 385 passing / 2 failing
  erlang; `modules/rakun-web` 104/104 on both rows.

- **TLS: named SSL bundles, one registry for five subsystems** (front 74).
  `modules/rakun/src/ssl_bundle.bp`, `src/ssl_bundle.mjs`,
  `src/sidecars/rakun_ssl.erl`, `modules/rakun-web/src/tls.bp`, and two suites
  (`modules/rakun/test/ssl_bundle_test.bp`,
  `modules/rakun-web/test/tls_test.bp`).

  A bundle is a name, some material and a verification posture —
  `rakun.ssl.bundle.pem.<name>.*`, Spring's property names with `spring` replaced
  by `rakun` — and every consumer refers to it by name:
  `rakun.server.ssl.bundle` for the listener, `rakun.management.ssl.bundle` for
  front 76's, `rkSslClientOpts(bundle, host)` for fronts 08, 09, 13 and 15.
  Rotating a certificate is one edit.

  What landed: the property grammar and the defaults (`tlsv1.3,tlsv1.2`, `none`,
  `full`); the refusals — half a keystore, a file that is not there (naming the
  absolute path searched), a JKS (naming the exact `keytool -importkeystore
  -deststoretype PKCS12` command, with no property that lifts it), an unknown
  posture, a protocol below TLS 1.2, a path carrying a blob separator, a private
  key that does not belong to its chain (at STARTUP, not at the first
  handshake), and a listener naming a bundle nobody configured; the two
  option-list encodings, including the `client-auth` → `{verify,
  fail_if_no_peer_cert}` and `verify` → `{verify, hostname}` mappings and SNI
  appended at call time; `sslReload`/`sslPoll` with the property that a failed
  reload keeps the previous material; the `ssl` health verdicts (`UP` /
  `OUT_OF_SERVICE` / `DOWN`, and `UP` with an empty detail when no TLS is
  configured — "no TLS" and "TLS broken" must not look the same) and the info
  contribution, which carries no key material; and, in `rakun-web`, the listener
  and management bundle resolution, the verified peer subject, and an HSTS chain
  entry that is never set on a plaintext response.

  `modules/rakun`: **387/387** on commonJS (was 346/346) and **385 passing / 2
  failing** on erlang (was 344/2) — the two still front 04's
  `server_test.bp:74,80`. `modules/rakun-web`: **104/104** on BOTH rows (was
  83/83). Neither pinned row in `scripts/restricted-targets.txt` moves.

  Deviations from the spec, each measured rather than chosen. (1) Every host cell
  carries BOTH `#[@External.Node]` and `#[@External.Erlang]` forms where the spec
  said erlang only: a cell with one form is a located diagnostic at its CALL SITE
  on the other row, and one such cell behind a called wrapper takes the whole
  member off commonJS. The genuinely erlang-only work (the blob →
  `ssl:listen/2` decoder) is in the sidecar as functions no `.bp` cell names.
  (2) `sslBundleNames()` reads `rakun.ssl.bundle.pem` as a LIST rather than
  discovering names from the property tree: there is no key enumeration on either
  row and `runtime.mjs` is frozen. One cell, `rkPropKeys(prefix)`, closes it.
  (3) The suite embeds a deliberately EXPIRED self-signed certificate instead of
  generating material at setup: the generator the spec asks for is erlang-only
  (node has no X.509 issuance API), and a certificate whose window closed in 2020
  has no date to rot on.

  Not reached, none of it stubbed: the acceptor edit that would make front 04's
  listener actually terminate TLS and run the handshake in the connection process
  (`rakun_runtime.erl` is front 04's file); the `gen_server` mtime watcher (needs
  front 16's scheduler — a sidecar cannot call back into the botopink reload);
  registration with front 11's two SPIs (front 11 has not landed — the two
  contributions are produced and asserted, only the registration is missing); and
  PKCS#12.

  Three compiler shapes measured on the way, each with the smallest program.
  A test file that imports `std`'s `process` loses EVERY cell in it on commonJS:
  the run exits 1, but the file contributes no `N passed, M failed` line at all,
  so a suite read by eye is short by a file and says nothing about it. `std`'s
  `path` answered `{error, undef}` on the erlang row from rakun — since fixed in
  `4fe1747e`, one of five std modules affected. And `fs.exists` answers `true` on
  node and `false` on the BEAM for a character device such as `/dev/null`.

- **Validation: `#[validated]`, one predicate for both rows, and the report**
  (front 14). `modules/rakun-validation/src/{report,table,messages,spi,constraints,binding,boot,decorators}.bp`,
  `src/validation_host.mjs`, `src/sidecars/rakun_validation.erl`, and seven
  suites under `modules/rakun-validation/test/`.

  `#[validated]` on a record-shaped `type` reflects `decl.fields`, reads each
  field's constraint annotations, and `@emit`s exactly two functions —
  `validate<TypeName>(v) -> ValidationReport` and `constraintsOf<TypeName>() ->
  string`. Thirteen markers: `#[notNull]`, `#[notBlank]`, `#[notEmpty]`,
  `#[sizeBetween(min, max)]`, `#[minValue(n)]`, `#[maxValue(n)]`, `#[positive]`,
  `#[positiveOrZero]`, `#[email]`, `#[pattern(regex)]`, `#[pastDate]`,
  `#[futureDate]`, `#[constraint(name)]`. No `#[future]`: that name collides with
  the `future` effect annotation (removed since, decision 118).

  **This is the only `both — boundary` member, and the mechanism is the reason.**
  The emitted validator is plain botopink — string comparisons, length checks and
  `std/regex` matches, no host cell in the predicate path — so ONE source
  compiles for erlang and for commonJS and the server and the client run the same
  predicate rather than two predicates that are supposed to agree.
  `test/parity_test.bp` holds that up the only way it can be held up: twenty
  inputs, one function, ONE expected digest carrying every violation's field,
  code and resolved message. A row that answered differently reds there instead
  of passing its own half of a two-test pair. `std/regex` was measured on both
  rows before anything was built on it — `matches`, `match` (value and index) and
  `replaceAll` all answer identically, and the email grammar is written in the
  intersection of PCRE and ECMAScript so it is one grammar and not two.

  **Refusal beats a constraint that could never fail** (decision 67). The failure
  mode designed out is a validator that silently passes what it cannot check, so
  a marker on a field whose type it cannot check is a LOCATED COMPILE ERROR, not
  a row that quietly always holds: `#[notBlank]` on an `i32`, `#[minValue]` on a
  `string`, `#[pastDate]` on an `i32`, `#[notNull]` on a field that can never be
  null, `#[sizeBetween(50, 2)]`, an empty `#[pattern]`. At run time,
  `#[constraint("cpf")]` with nothing registered is a violation coded
  `unknownConstraint` naming the registered list — never a pass — and
  `bindInt("age", "12x")` answers `0` AND records a `typeMismatch`, so the zero
  can never be mistaken for a value the caller meant. Deleting the trim from
  `vNotBlank` reds three cells in two files on both rows; shifting
  `#[sizeBetween]`'s upper bound by one reds two, the parity digest among them.

  **The naming contract with front 05.** Front 05's boot path builds `validate` +
  the type name and calls it after binding and before the first component is
  constructed, so the spelling breaks the BUILD rather than a test.
  `src/boot.bp` ships the other half — `configProblem`/`refuseInvalidConfig`,
  which render a refusal naming property KEYS rather than field names, one line
  per violation. The call site `modules/rakun/src/config.bp` names
  `rkConfigValidate` does not exist in the tree and `modules/rakun/**` is not this
  front's to edit; front 05 adds it. Note also that `config.bp` already declares
  a placement-only `#[validated]` of its own: an application that wants the
  emission imports `validated` from `rakun-validation` and must not import both.

  **The table is a blob, not a JSON literal.** `constraintsOf<Name>()` is emitted
  as a call to `constraintTableJson(name, blob)` (`<field>|<code>[|<arg>]*`,
  records joined with `;`) so the grammar is an ordinary function a test can call
  instead of a string literal written into source through two levels of
  escaping — front 72's condition blob for the same reason. An argument carrying
  `;`, `|` or `"` is refused by the marker that takes it, so the grammar has no
  escape and needs none. The JSON is byte-identical on both rows.

  **Two host halves, and neither decides anything.** The SPI registry maps a name
  to a closure (no string table holds one) and the binding accumulator is
  appended to by the `bind…` readers (records are immutable, so a binder record
  cannot accumulate as it goes). `validation_host.mjs` holds a Map and an array;
  `rakun_validation.erl` holds an ETS registry behind an owner process and hangs
  the accumulator off the SERVING PROCESS's dictionary. `bindingIsolated()` is
  the one answer the host gives rather than botopink: the BEAM half MEASURES it
  by spawning a child and comparing this process's count, the node half states it
  about a row whose dispatcher runs one request to completion. Making the BEAM
  `bind_drain` stop erasing reds `binding_test.bp` on erlang and leaves commonJS
  green — which is what proves the erlang row is really being exercised.

  **Three compiler defects met and reported, none worked around in library
  source.** (1) A record that `implement`s a behavior does not coerce to the
  behavior type anywhere, so the spec's `registerConstraint(name, c: Constraint)`
  is spelled `registerConstraint(name, code, check)` and the behavior stays as the
  checked shape. (2) An integer literal does not widen to `i64` in arithmetic —
  and that diagnostic carries no line or column — so `#[minValue]`/`#[maxValue]`
  are REFUSED on an `i64` field rather than emitted as something that reds.
  (3) On erlang a record method's owner module is resolved only when the type is
  imported into the calling module; without it `erlc` refuses the module, the
  runner prints no summary for it and the command exits 127. All three carry
  minimal repros in `AGENTS.md` § Validation → Language notes.

  Counts. `modules/rakun-validation` went from **0/0 on both rows** (no test
  blocks) to **54 passing / 0 failing on commonJS and 54 passing / 0 failing on
  erlang**, summed over seven modules: `binding_test` 10, `config_test` 6,
  `constraints_test` 14, `parity_test` 3, `report_test` 7, `spi_test` 8,
  `table_test` 6. `modules/rakun` is untouched and unchanged at 346/0 on commonJS
  and 344 passing / 2 failing on erlang, the two reds being front 04's own
  `server_test.bp:74,80`; re-measured after merging front 07, `modules/rakun-web`
  is likewise unchanged at 83/0 on both rows.

  **One name needs care at the import line.** `validated` now exists twice in the
  workspace: here, where it emits, and in `modules/rakun/src/config.bp` (front
  05), where it is placement-only and emits nothing. Importing that one leaves
  `validate<TypeName>` undefined and the failure lands at the CALL SITE as an
  unbound variable rather than at the annotation; importing both into one module
  is a duplicate binding. The rule is written where an application author reads
  — `docs.md` § Validation (first paragraph of the section), `modules/README.md`
  § Consuming a member, and the docblocks of `src/root.bp` and
  `src/decorators.bp` — not only in a test header. Front 05's marker is left
  alone; whether it should be deleted now that this front has landed is front
  05's call.

- **The filter chain, CORS and RFC 9457 problem details** (front 07).
  `modules/rakun-web/` stops being a two-comment scaffold: it now carries one
  ordered chain between the socket and the route handler, two entry points into
  it, and the error shape everything above it produces. **83 cells, green on
  both rows** (`botopink test` on the member's own erlang target and
  `botopink test --target commonJS`), where the member had no `test/` directory
  at all before. `modules/rakun` is untouched by this front: with front 72 also
  in the tree it reads 346/346 commonJS and 344 passing / 2 failing erlang, the
  two reds still front 04's `server_test.bp:74,80`. (Front 07 was written
  against the pre-72 core, 302/300 with the same two reds.)

  **One chain, two entry points.** `#[filter]` on a component registers one
  entry ordered by `#[order]`; `#[middleware]` on a `pub fn` registers exactly
  one entry at `−50`. Two pipelines would mean two orderings and a CORS header
  set in one and overwritten in the other, so there is one list and the order
  band says who sits where. `middleware_test.bp` writes the SAME redirect both
  ways and asserts the two responses agree field for field. Ordering is asserted
  as a WHOLE string — `a>|b>|c>|handler:/x|<c|<b|<a` — rather than filter by
  filter, so a reordering cannot hide.

  **The chain's request value is a record, not `Request`, and that is a
  measurement.** A method on a host-supplied `behavior` does not dispatch on the
  erlang row — `req.header("origin")` lowers to a map field read of `header`
  followed by a call, which is the defect keeping `server_test.bp:74,80` red in
  the core. A chain that cannot read a header cannot do CORS, so the chain
  carries `WebRequest`, built from the same scalars the dispatcher already has
  and reading through front 62's wire grammar. `path` never changes; `target` is
  what the router is asked about, and `Next.rewrite` is the only thing that
  moves it.

  **`#[order]` takes a STRING because `#[order(-100)]` does not parse.**
  `#[mark(-20)]` is `error: this token cannot appear here … unexpected 20` on
  both targets while `#[mark(20)]` compiles — measured against compiler
  `2e6bb4ac` with a two-file program. Every order in the band below zero is
  unwritable as an integer, so the argument is quoted and parsed with front 05's
  `toI32`. When the parser accepts the minus sign the signature becomes
  `n: i32` and the emitted `toI32(` wrapper is deleted; nothing else moves. This
  is the one place the front's surface differs from its spec for a compiler
  reason rather than a design one.

  **`withHeader` replaces by name, and says so twice.** `Response` is frozen at
  `(status, body)`, so `withHeader(res, name, value)` writes through a
  per-request accumulator and returns the same `Response`. Case-insensitive, and
  two exceptions: `Set-Cookie` is a boot-time REFUSAL naming front 62's list API
  (a replace would set one cookie and drop the rest), and `Vary` is unioned so
  the CORS entry's `Origin` and a future compression entry's `Accept-Encoding`
  both survive. The BEAM half mirrors every write into front 04's
  `set_reply_header/2` so the line reaches the socket; the node half does not,
  because `runtime.mjs` is frozen and this front does not unfreeze it.

  **CORS denies until told otherwise.** No origin is allowed until one is named;
  the wildcard together with `allowCredentials` fails at BOOT naming the
  combination, with no property that downgrades it; and a preflight for a path
  with no route answers 404 rather than a permissive 204. The allow-origin
  header ECHOES the request origin and never answers `*`, and `Vary: Origin` is
  set on every response the policy looked at, allowed or not. A preflight from a
  disallowed origin answers 403 — the spec does not pin that case, and 204 with
  no allow-origin reads to a browser exactly like a misconfiguration.

  **A problem detail never carries a reason.** botopink has no typed raise, so
  the raise and the catch are both host cells and the tag is a STRING. A tagged
  raise with a matching `#[exceptionHandler]` answers that advice's
  `ProblemDetail` as `application/problem+json`; anything else answers 500,
  `about:blank`, and a correlation DIGEST, with the full reason in the log under
  that digest. A cell reads the digest out of the body and asserts the same
  string is in the log line. A handler's own `Response` with a body is never
  rewritten, `rakun.web.problemdetails.enabled` or not.

  **A refusal text may carry no double quote, and that cost a red.** On the
  erlang row `asserts.throwsWith` reads the `~p` RENDERING of the raised binary,
  in which a `"` is escaped to `\"`; on commonJS it reads the raw message. One
  needle cannot match both rows if either side carries a quote — measured both
  ways with a three-cell probe. Every refusal in this member is written around
  it, the way front 62's are written around the em dash.

  **Five of the spec's ten steps are NOT in, and none is stubbed:** static error
  pages (5), content negotiation (6), `WebCustomizer` (7), API versioning (8) and
  compression (9) are work with no blocker; graceful shutdown (10) is BLOCKED,
  and not on front 76 — step 2 of its sequence closes the listening socket, and
  that socket lives in `rakun_runtime.erl` under `modules/rakun/`, which front 07
  does not own. `AGENTS.md` § What front 07 did NOT reach carries the table.
- **Auto-configuration: conditional registration, ordered, with a report**
  (front 72). `src/autoconfig.bp`, `src/conditions.bp`, `src/condition_report.bp`,
  `src/autoconfig_registry.bp`, `src/autoconfig.mjs`,
  `src/sidecars/rakun_autoconfig.erl`, `test/conditions_test.bp`,
  `test/autoconfig_test.bp`, fixtures under `test/fixtures/autoconfig/`.

  `#[autoConfiguration]` plus five condition markers — `#[conditionalOnModule]`,
  `#[conditionalOnProperty]`, `#[conditionalOnBean]`, `#[conditionalOnMissingBean]`,
  `#[profile]` — and the two ordering markers `#[autoConfigureBefore]`/`After`.
  The conditions compile to a `;`-joined blob of `M|P|B|X|F` records, one
  registration per annotated declaration (`Type` for a configuration,
  `Type.method` for a `#[bean]` method), and the application runs the pass with
  `autoConfigure()` before `Rakun.run` — `bootstrap.bp` is frozen, so the line is
  explicit and the report says plainly when it was never called.

  **The pass sorts before it evaluates**, and that is the whole point rather than
  a detail: an ordering annotation names a configuration AND the beans it owns,
  so `#[conditionalOnMissingBean("DataSource")]` sees the state as of its own
  position instead of as of module load order. Kahn's walk with ties broken by
  registration order, an edge naming an unregistered configuration dropped (as
  Spring's does), a cycle a startup failure naming its members. Deleting the sort
  reds ten cells.

  **Two exclusion channels, one resolution path.**
  `rakun.autoconfigure.exclude` through front 05's table and
  `autoConfigureExcept(names)` union into one argument; an exclusion naming no
  registered configuration HALTS and lists the registered names, because a typo
  in an exclusion disables nothing and leaves the developer believing they turned
  something off. An excluded entry's conditions are not evaluated at all.

  **The report is a value, not a log line.** Three blocks — applied, not applied,
  excluded — walked in the sorted order, each failed row naming the FIRST failing
  record and the value observed ("did not match: `P|rakun.mail.host|*` - the
  property is empty"), because a restatement of the source is not a diagnosis.
  `rakun.main.debug` gates the printing and never the data, and front 11 serves
  the same string at `/actuator/conditions` with no further work here.

  **`#[profile]` on an ordinary `#[service]` is the same machinery, with one
  narrowing.** `decorators.bp` is frozen and its stereotypes emit
  `__rkMake_<Type>()` unconditionally, so the marker cannot gate the factory: it
  leaves the component unbuilt (`rkBuildCount` stays 0) and emits
  `__rkAutoGated_<Type>()`, which raises with the diagnosis. It goes away when
  `decorators.bp` unfreezes.

  **The host is a table and nothing else.** Front 06's measurement, applied: it
  stores four kinds of FUN, so its grammar stayed in botopink; here nothing is a
  fun, so the blob grammar, the sort, the evaluator, every refusal and the
  renderer are botopink compiled twice, and the two host files append a row and
  answer a lookup. The manifest read behind `#[conditionalOnModule]` is botopink
  too — `std`'s `fs.readText` plus a scanner that normalises both on-disk shapes
  of `dependencies`; a manifest that cannot be read is a refusal, not a `false`.

  **Deviation from the front's README, reported rather than hidden.** The spec
  declares the host cells `@External.Erlang`-only and the tests "erlang-only,
  and the lib test runner is told so". There is no per-file target gate:
  `botopink test` compiles every `test/*.bp` on both rows
  (`compiler-cli/src/cli/test_cmd.zig`) and the only whitelist is per-LIB
  (`botopink.json` `targets`, `lib-test-runner/src/discovery.zig`), which for
  rakun core is `["commonJS"]` — so erlang-only tests would red the node row and
  never run in the gate. Both host halves ship, front 06's precedent.

  **Two compiler defects met and NOT worked around in library source.**
  (1) `from` is a reserved word and may not name a field or a parameter —
  `pub type Edge(from: string, to: string)` is `error[field-needs-name]`.
  (2) `println`/`print` (`libs/std/src/builtins.d.bp:12-16`) have no erlang
  lowering: the emitted module calls a bare local `println/1`, `erlc` refuses it,
  and the test runner's `__bp_load_siblings/0` skips a module that fails to
  compile SILENTLY — so every function of that module answers `{error,undef}`,
  pointing at the caller rather than at the print. Smallest program and both rows
  in AGENTS.md § The auto-configuration pass. The report prints through
  `rkAutoPrint`, a cell of this front's own carrying both forms.

  **Counts** (pinned compiler `2e6bb4ac`, summed over every module summary):
  before 302 / 0 on commonJS and 300 passing / 2 failing on erlang; after
  **346 / 0** and **344 passing / 2 failing**. The two erlang reds are front 04's
  own `server_test.bp:74,80` (`{badkey,param}` / `{badkey,query}`) and the
  restricted-targets ledger's count is unchanged in both directions.

- **The consumer proof** (front 23). `examples/rakun-ssr/` is a new workspace
  member that reaches the whole front through `from "rakun"` — the
  `ElementView` adapter, a root layout and a page registered through the
  file-convention cells, one render inside a request scope, and the escaping
  assertion. `botopink run` prints the document and the program halts with a
  named refusal if a title carrying `<script>` reaches the browser as an
  element or the payload is not `v1`. It is what proves both host files ship
  with a consumer's build.

- **The chunk protocol and the two entry points** (front 23, steps 5 and 6).

  `render(v, pathname, query)` opens phase `Render`, matches, awaits the page,
  composes it into its layouts, writes the document and answers a
  `RenderedPage`; a URL no page claims answers **404** with the `not-found`
  boundary's markup inside the layouts that would have wrapped it, not an empty
  body. The previous phase is restored afterwards, and a `cookies().set(…)` from
  a render raises — the phase table of `contracts.md § 5` is enforced, not
  described.

  **Concurrency is processes, not `@Task`** (then `@Future`). `renderAll` takes an
  `Array<fn() -> @Task<T>>` — unstarted THUNKS — and gathers them in one
  await, one spawned BEAM process per thunk. Two 50 ms loaders finish under
  100 ms on the row that spawns and take 100 ms on the row that cannot, and the
  cell asserts `fast == concurrentRow()` rather than claiming one shape for
  both. The parameter type is what makes "no call site passes an already-started
  future" checkable.

  **The streaming entry is three calls and not one, and it is a compiler gap
  rather than a design choice.** A parameter typed `Array<fn() -> @Task<El>>`
  in a function that also takes an `ElementView<El>` is refused with
  `generic-arg-skip-forbidden`; each half compiles alone. So the gather keeps
  its own function and `streamChunks` — where nothing is generic — keeps the
  protocol: shell, one fill per boundary in RESOLUTION order, tail. Ids stay in
  shell order, fills go out in settle order, every id in `h` is filled exactly
  once, and a boundary that resolved before the flush is no hole at all.

  **Four more measurements, each of which cost a red:** `await` inside an
  `if`/`else` block of a `@Task` body is emitted in a non-async arrow IIFE
  on commonJS and takes the whole test FILE down at load; the optional binder is
  a closure and may not await; `xs.at(i).unwrapOr(…)` reads the element back
  unwrapped when the array came off a record field or the function is generic;
  and **`std/querystring` does not compile on the erlang row** (`function
  slice/3 undefined` at `stripPrefix`), so `splitQuery` / `encodeQuery` are here
  over front 62's percent codec. (The loading half of that last one was fixed in
  `4fe1747e`; the two bodies stay for a different, measured reason — see the
  std-substitutes entry at the top of Unreleased.)

  The gate gained stage 1b — front 23's own three greps: no `renderToString` in
  `ssr.bp`, no module of onze reachable from `modules/rakun/src/`, and no void
  tag spelled in `ssr.bp`.

  20 new assertions, every one on both rows: 292 → **302** on commonJS,
  290/2 → **300/2** on erlang. The whole front is 35 cells, all running on both.

- **The document, the payload and `RenderHooks`** (front 23, step 4 and decision
  77).

  One `<script id="__onze" type="application/json">`, the last thing in
  `<body>`, carrying `contracts.md § 2`'s key table — `v` first and `1` as its
  value — plus `k` and `z`, which this front allocates and fronts 60 and 61
  write. `<`, `>` and `&` are written as `\u003c`, `\u003e`, `\u0026`, so
  `</script` is unrepresentable inside the block rather than filtered out of it;
  a param carrying `</script><img src=x onerror=alert(1)>` yields a document
  with no `<img` in it and exactly one script closer.

  **The round trip is one test.** `rkSsrPayloadKeys` / `rkSsrPayloadText` parse
  the emitted block with a parser this front did not write — `JSON.parse` on
  node, OTP's own `json:decode/1` on the BEAM — so a payload that is not valid
  JSON fails on BOTH rows, and the field set comes back sorted from both.

  **`RenderHooks` is this front's record, with a no-op default** (decision 77).
  Seven function fields, each replaceable on its own; `Onze.run` fills them and
  `islandAttr` is jhonstart front 29's. `repository/rakun/src/` names no module
  of onze — the only `onze` in it is the `data-onze-*` marker strings. One
  consequence is written down rather than smoothed over: with the sheet moved
  into the hooks, a document rendered through `defaultHooks()` carries **no**
  `<style>`, where the front's own text (written before 77) says "exactly one".

  **U+2028 / U+2029 are escaped by CODE POINT, never by a literal** — a
  non-ASCII string literal raises `badarg` on the erlang row before any of this
  front's code runs, so the needle could not be written and the positive case is
  not expressible as a cell. The same gap front 62 recorded for a non-ASCII
  cookie.

  10 new assertions, every one on both rows: 282 → **292** on commonJS,
  280/2 → **290/2** on erlang.

- **The escaping walker, the composition order and the rendered page** (front 23,
  steps 1 to 3).

  `modules/rakun/src/ssr.bp` is new, with `modules/rakun/src/ssr.mjs` and
  `modules/rakun/src/sidecars/rakun_ssr.erl` beside it. `renderNode` escapes
  text and attribute values, emits no closing tag for a void element, emits a
  raw-text body verbatim, and REFUSES a `script` or `style` body that closes its
  own element in any case rather than rewriting it into something that no longer
  runs. `compose` wraps a page from the inside out — `layout > template > error >
  loading > not-found > page` — and a convention nobody registered contributes no
  wrapper at all.

  **`Element` is generic, and the tag predicates are values.** rakun declares no
  dependency on jhonstart and gains none: the six things a walker must be able to
  do to a tree arrive as an `ElementView<El>` record of function values, and
  front 94's `isVoidTag` / `isRawTextTag` are two of its fields. This module
  keeps no void set and no raw-text set — the grep its own gate runs finds one
  tag name in the whole file, the `div` a template wrapper is.

  **Front 01's `escape` module does not exist on this binary**, so `escapeHtml`
  and `escapeAttribute` are here in pure botopink, spelled as front 01 specifies
  them, and are two bodies to delete when it lands.

  **Two erlang-only call-site rules, measured rather than inherited.** A
  function-valued record FIELD must be read into a local before it is called —
  `v.tagOf(e)` lowers to a method call and reds with `function tagOf/2
  undefined`, while the commonJS row is perfectly happy. And a local `val` may
  shadow a module-level `pub fn` of the same name *for an importer*: a test
  importing `raw` was told `expected Node, got bool`, the type of a local inside
  another function.

  15 new assertions, every one of them running on both rows: 267 → **282** on
  commonJS and 265/2 → **280/2** on erlang, the two reds being front 04's own
  `request/6`.

- **`#[imports]`, the retired stub and the consumer proof** (front 06, step 9 and
  the Mechanism's last marker).

  `#[imports("A,B")]` on a `#[configuration]` registers a bean per named type —
  Spring's `@Import`. Spring's `@ComponentScan(basePackages=…)` has NO analogue
  and needs none: an additional scan root in botopink is a `pub mod` line,
  because module resolution is already explicit.

  `src/rakun.d.bp`'s declaration-only `behavior Context` is GONE and its docblock
  says where the concrete one lives. The file is loaded for consumers through
  `botopink.json`'s `files`, so leaving the stub would have put two `Context`
  declarations into every consumer's namespace; it keeps its place in the list as
  the library's declaration module, now declaring nothing.

  **The consumer half is proved by a build, not by a claim.**
  `examples/rakun-container/` is a new workspace member that reaches the whole
  front through `from "rakun"` — `#[managed]`, `#[provides]` with two qualifiers
  and a `#[primary]`, `#[postConstruct]`/`#[preDestroy]`, `#[eventListener]`,
  `ctx.resolve`/`ctx.resolveNamed`/`ctx.publish` from a controller, `#[exitCode]`
  and `bootSequence()` in `main`. It builds in the examples gate, which is what
  "resolves to the concrete record with no ambiguity diagnostic" means in
  practice.

  **What front 23 consumes** is written down in `AGENTS.md` § What front 23
  consumes from this front — the entry points, the three wire records
  (`path|type|qualifier|scope|primary|lazy|owner`, `owner|method|phase|order`,
  `event|owner`) and the boot-event name list — because the front's own
  `contracts.md` lives in the meta repository and is not this worktree's to
  write.

- **Shutdown, the pre-destroy pass and `#[exitCode]`** (front 06, step 8).
  `lifecycle.shutdown()` runs the pre pass in reverse registration order and
  answers the process status — the highest value any `#[exitCode]` generator
  returns, 0 with none. `#[exitCode]` is the one marker in `lifecycle.bp` that
  EMITS, because a module-level function has its own name and return type where a
  method `@Decl` has neither an owner nor a parameter list. Four new assertions
  on both rows.

  **No `rakun_context:terminate/2` was written**, though the README names one:
  this sidecar is not an `application` callback module and is in no supervision
  tree (`rakun_file_router`'s shape, for `rakun_file_router`'s reason), so a
  `terminate/2` nothing calls would be dead code. Front 07 owns the signal path
  and reaches the pass through `lifecycle:shutdown/0`. A failed boot never
  reaches shutdown at all: `bootSequence` halts, and a halt is a non-zero status
  on both hosts without anybody choosing a number.

- **Eager initialization, and `rakun.main.lazy-initialization`** (front 06,
  step 7). `rkSingleton` takes a thunk, so rakun was already lazy and what was
  missing is the EAGERNESS: `bootSequence()` constructs every non-`#[lazy]`
  singleton of the ROOT registry and runs the `#[postConstruct]` pass before it
  returns, and the key turns both off — the pass with the construction, because a
  hook runs ON an instance. Five new assertions on both rows, including a real
  two-type cycle reported through front 04's guard.

  **"A component whose `#[value]` key is missing fails the boot" cannot
  happen**, and the acceptance is answered rather than skipped. `rkProp` answers
  `""` for an absent key and `rkPropInt` answers `0` — front 04's rule, on both
  rows, in the FROZEN `runtime.mjs` — so a missing `#[value]` key is not an error
  at boot, at the first request, or ever. What the eager pass does turn into a
  boot failure is a construction that RAISES, and that is what the two new cells
  assert.

  The cycle diagnostic is worded differently on the two rows (`rakun dependency
  cycle: component 'X' …` on node, `{rakun_cycle, X}` on the BEAM), so the
  assertion is on what both carry: the component name and the word `cycle`.

- **Scopes: `singleton`, `prototype` and `request`** (front 06, step 6).
  `#[scope("prototype")]` and `#[scope("request")]` change what `#[managed]`
  registers: a FRESH `__rkNew_<Type>()` it emits itself (same per-field injection
  rule as the stereotypes), `request` wrapped in `rkRequestScoped` — the process
  dictionary on the BEAM, an explicit bracket on node. Five new assertions on
  both rows.

  **The refusal the README asks for is not writable; its reason is.** "A type
  whose factory is constructor-injected somewhere fails at comptime" needs a
  whole-graph view no decorator has. The STEREOTYPE is what emits the singleton
  `__rkMake_<Type>()` a field resolves through, so `#[managed]` refuses a
  non-singleton scope beside a stereotype — and without one there is no
  `__rkMake_<Type>`, so a field of that type fails the build at its own injection
  site. Same guarantee, from the half reflection can see. A non-singleton bean
  also may not carry `#[postConstruct]`/`#[preDestroy]`: both passes run once,
  over an instance nobody kept.

  "Two concurrent requests each get their own instance" is true by construction
  on the BEAM and **not assertable from a `.bp` test**, which cannot spawn a
  process; the within-request/next-request bracket is asserted instead, and it is
  the same statement on both rows.

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
  erlang row from rakun** — since fixed in `4fe1747e`, though the byte type and
  the `charCodeAt` disagreement still rule out a UTF-8 round trip; and **a
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
  `std@fs`, which rakun's own sources pull in, do not. (Fixed in `4fe1747e` —
  all four re-measured green from a test file on both rows; see the
  std-substitutes entry at the top of Unreleased.) Measured:
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
  the child — asserted with a loader that sleeps. The task-returning loader row holds
  too: the eager erlang lowering means the first call stores a value, so the
  second is the resolved-value row.

  `preload` is not built on `@Task` (then `@Future`) and cannot be: on erlang `@Task<T>`
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
  `decl.returnType` carries no type argument (`"Future"` then, `"Task"` now, not
  `"@Task<Element>"`), so a page is checked to BE a task and the required
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
