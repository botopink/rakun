# Decision 294 — A cookie is declared once, typed:

The example declares the session cookie once, at module level: `sessionCookie` is a
`Cookie<SessionId>` named `session` — the browser's name, the one string in the declaration —
with `httpOnly`, `secure` and a thirty-day `maxAge` beside it. Every other line refers to the
declaration, never to the name or the attributes again.

`signIn` is a route handler: it writes the cookie with `use cookieSetter(sessionCookie)`, handing
it a `SessionId`, and the `Set-Cookie` line it produces carries the declared attributes because
they live with the cookie, not with the call. `Greeting` is a page: `use cookieValue(sessionCookie)`
answers `?SessionId` — typed, already decoded, `null` when the request sent none — and the page
only reads; a render writes no cookie. `main` enters a request that carries `session=s-42`,
renders the greeting (`hello s-42`), then one without the cookie (`hello guest`).

The value type is one the cookie can encode: `SessionId` is a one-field record. No page reads a
pair jar or calls `pairValue(jar, "session")`.

Proving cells: `conformance/rakun/request-context/request_cookies` reads and writes cookies through
the request context by name, the untyped form this decision replaces; none of this repository
proves the typed declaration yet. It comes with `http` 104 step 6 and `05-jhonstart/26` step 12.

[draft/main.bp](draft/main.bp)
