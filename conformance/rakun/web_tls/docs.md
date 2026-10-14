# web_tls

The reference text this cell shows (from `conformance/docs.md`, § The web layer's side (`from "rakun-web"`)):

> - `rakun.server.ssl.bundle` names the listener's bundle and
>   `rakun.management.ssl.bundle` front 76's. A key naming a bundle nobody
>   configured is a **refusal**, never a quiet fall back to plaintext.
> - `peerSubject()` is the verified peer's distinguished name under mutual TLS,
>   and `""` when there was no certificate. It is never read from an unverified
>   one: under `want`, a peer the trust store does not verify is a rejected
>   connection, not a request with an empty subject.
> - `registerTls()` adds one chain entry in the late band (+300) that writes
>   `Strict-Transport-Security` — off until `rakun.server.ssl.hsts.enabled=true`,
>   and **never on a plaintext response** whatever that property says. A `preload`
>   without a year of `max-age` and `includeSubDomains` is refused at boot, because
>   the preload list rejects it anyway and the header would promise a year of HTTPS
>   in the meantime.

## Measured

No bundle is configured, so the listener is plaintext.
