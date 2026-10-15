# SSL bundles

> Package: [`rakun`](../docs.md) · index: [`../../docs.md`](../../docs.md)

Every transport rakun opens was plaintext, and every subsystem that wanted a
certificate would have invented its own three properties for it. Spring solved
this by naming the **material** instead of the consumer, and rakun does the same
with `spring` replaced by `rakun`, so the reference's examples transliterate
without a lookup table.

## Configuring a bundle

```yaml
rakun:
  ssl:
    bundle:
      # The names, as a list. See "One deviation" below.
      pem: mybundle,internal-ca
      # `pem` is also the prefix each bundle hangs off.
  server:
    ssl:
      bundle: mybundle
```

```properties
rakun.ssl.bundle.pem=mybundle,internal-ca

rakun.ssl.bundle.pem.mybundle.keystore.certificate=/etc/rakun/server.pem
rakun.ssl.bundle.pem.mybundle.keystore.private-key=/etc/rakun/server.key
rakun.ssl.bundle.pem.mybundle.keystore.private-key-password=
rakun.ssl.bundle.pem.mybundle.truststore.certificate=/etc/rakun/ca.pem
rakun.ssl.bundle.pem.mybundle.protocols=tlsv1.3,tlsv1.2
rakun.ssl.bundle.pem.mybundle.ciphers=
rakun.ssl.bundle.pem.mybundle.client-auth=need
rakun.ssl.bundle.pem.mybundle.verify=full
rakun.ssl.bundle.pem.mybundle.reload-on-update=true

rakun.ssl.handshake-timeout=5000
rakun.ssl.reload-interval=60000
rakun.ssl.health.warn-threshold=14
```

**PEM is the format.** A **JKS is refused**, with a message naming the exact
`keytool -importkeystore -deststoretype PKCS12` command that converts it. There
is no property that lifts the restriction: a Java keystore is a JVM container
format and accepting it would mean shipping a parser for it.

## The two postures, and why they are separate properties

`client-auth` is what a **server** demands of a connecting client — `none` (ask
for nothing), `want` (ask, accept a connection without one), `need` (refuse a
connection without one). `verify` is what a **client** demands of the server it
reaches — `full` (the chain and the hostname) or `none` (nothing). A single
property could not spell `want`, and `full` is the default because `none` is only
ever correct in a test. Resolving `verify: none` logs a warning naming the
bundle, every time.

## Reading a bundle

{ssl_bundle/src/main.bp}

`sslBoot()` resolves every configured bundle once, reads each certificate's
fields, checks that each private key belongs to its chain, and refuses at
**startup** — not at the first handshake — naming the bundle and what is wrong
with it. A bundle that fails does not stop its siblings resolving; the failure is
recorded against it and `sslBoot()` is what turns any recorded failure into the
refusal.

## Rotation without a restart

{ssl_bundle/src/main.bp}

A reload that fails **keeps the previous material** — not by putting anything
back, but because nothing is written until everything has been read and checked.
Replacing a working certificate with a broken one at 3am because a deploy
half-wrote a file is a worse outcome than serving the old one for another hour.
The reason lands in `sslLastError(name)`, which is `""` after a good resolve.

`sslPoll()` is the body of the watcher; what turns it into a timer is front 16's
scheduler, which has not landed. With `reload-on-update=false` a poll makes no
filesystem call for that bundle at all.

## Health and info

`sslHealth()` answers the `ssl` indicator's contribution as the milestone's blob:

| Situation | Status |
|---|---|
| No bundles configured | `UP`, empty detail — never absent |
| Every certificate outside the warn threshold | `UP` |
| A certificate inside `rakun.ssl.health.warn-threshold` days | `OUT_OF_SERVICE` |
| A certificate already expired | `DOWN` |
| A bundle that failed to resolve, or whose last reload failed | `DOWN`, with the reason |

The detail names the bundle, its subject and the days remaining, because a health
check that says `DOWN` without naming which certificate is a page nobody can act
on. `sslInfo()` adds the issuer and the two instants. Neither carries key
material, a password, or a fingerprint of the private key — the whole
contribution is what the certificate already tells anyone who connects.

## One deviation from the reference, and exactly what would close it

Spring discovers bundle names by walking the property tree for
`spring.ssl.bundle.pem.*`. rakun's property table has no key enumeration on
either row — front 04's ETS table could be folded over, but `runtime.mjs`'s
`props` is a module-private `Map` with no export and `runtime.mjs` is frozen for
the milestone. So the names are read as a **list** from `rakun.ssl.bundle.pem`
itself, the same idiom front 05 uses for its own key catalogue. Closing it needs
one cell with two halves, `rkPropKeys(prefix)`; nothing else about the surface
above changes when it lands.
