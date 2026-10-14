A server component reads the request through `RequestData` — method, path,
the parameters the route matched, the query, the headers and the cookies.
`enterRequest` installs it for the render that follows, `request()`, `cookies()`
and `headers()` read it, and `leaveRequest()` ends it.
