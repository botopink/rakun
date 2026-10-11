# request_cookies

The reference text this cell shows (from `conformance/docs.md`, § `cookies()`):

> A cookie may be written from a server action, a route handler or middleware; a
> write in phase `Render` or `After` raises. The queued lines come back from
> `endRequest()` as a `\n`-separated blob — the dispatcher appends each as its own
> `Set-Cookie` header, because front 04's `rkSetReplyHeader` replaces by name and
> so carries only one.
>
> `cookieDefaults()` is `path="/"`, `domain=""`, `maxAge=0`, `httpOnly=true`,
> `secure=true`, `sameSite="Lax"`. **Pass your own `maxAge`**: `Max-Age=0` expires
> the cookie on arrival (RFC 6265 § 5.2.2), and `cookieDefaults()` carries it
> because the front's acceptance pins the wire literal — see `AGENTS.md` for the
> argument.
>
> A cookie value is percent-encoded on the way out and percent-decoded on the way
> in, over printable ASCII. A control character encodes (so a `Set-Cookie` line
> cannot hold a newline) and never decodes back; a character above printable ASCII
> is refused, naming the cookie — encode it yourself, base64url being the usual
> answer.
