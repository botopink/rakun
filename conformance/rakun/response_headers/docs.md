# response_headers

The reference text this cell shows (from `conformance/docs.md`, § Response headers):

> `withHeader` returns the `Response` it was given and **replaces by name**,
> case-insensitively. Two names are special: `Set-Cookie` is refused (queue cookies
> with front 62's `cookies().set` and hand `endRequest()`'s blob to
> `writeCookies`), and `Vary` is unioned rather than replaced.
