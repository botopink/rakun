# Decision 400 — A cookie's hooks are nouns in cardume's family — `cookieValue`, `cookieState`, `cookieSetter`, `cookieReset`.

The hooks are rakun's, over the `Cookie<T>` declared once in `http`. The program enters a request whose `session` cookie is `s-42`. `Greeting`, a page, reads with `use cookieValue(sessionCookie)`: a `?SessionId`, `null` when the request has no `session` or its value does not decode, so the page prints `hello s-42` and falls back to `hello guest` on the second request, whose cookie is malformed. `signIn` and `signOut` are actions: one writes with `use cookieSetter(sessionCookie)`, a `fn(v: SessionId)`, the other clears with `use cookieReset(sessionCookie)`, a `fn()`; `cookieState`'s `.value` / `.set(v)` is the pair in one record. None of them names an attribute: `HttpOnly`, `Secure` and the path come from the declaration on every line written.

The four names are nouns in cardume's family — `use` is the activation, so there is no `useCookieValue`. A page reads only: writing `use cookieSetter(sessionCookie)`, `cookieState` or `cookieReset` in `Greeting` is refused at build, at the `use`.

Cells of this repository that prove it: none yet. `rakun-bpp`'s request cells (`rakun-bpp/server-components/request_data`) read raw cookie pairs; the declared `Cookie<T>` arrives with `03-bundled-libs/104` step 6 and the hooks with `05-jhonstart/26` step 12 and `08-bpp/122`.

[draft/main.bp](draft/main.bp)
