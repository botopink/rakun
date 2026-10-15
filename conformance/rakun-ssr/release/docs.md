# The release

> Package: [`rakun-ssr`](../docs.md) · index: [`../../docs.md`](../../docs.md)

An OTP release is the standalone output — assembled by OTP's own `systools` through std's
`process.run`, not rebar3:

```text
<outDir>/release/
  releases/<buildId>/            start.boot, sys.config, vm.args, rakun-ssr.rel
  lib/<app>-<vsn>/ebin/          every compiled BEAM module, app by app
  erts-<vsn>/                    with includeErts (the default): the runtime itself
  static/<buildId>/              the client chunks and the stylesheet
  public/                        public/, copied verbatim
  prerender/                     prerendered routes and their manifest
  bin/rakun-ssr                       the boot script `rakun-ssr start` executes
  BUILD_ID                       one line, the build id
```

**The build id** is derived once — std's `contentHash` over the sorted module hashes and the client
manifest's hash, six hex digits — and must be equal in `BUILD_ID`, the release directory, the
client manifest and the payload's `b`; `verifyBuildId` names the two that disagree. A supplied id
must match `[A-Za-z0-9_-]{1,64}`.

**Configuration is read at boot.** `sys.config` holds defaults only; `vm.args` reads the cookie as
`${RELEASE_COOKIE}` (never a literal); `bin/rakun-ssr` refuses a build-id mismatch and a missing cookie,
honours `PORT` (default 3000) and `exec`s the VM, so a container's PID 1 is the VM. Packaging
refuses a manifest chunk or stylesheet the build did not produce, and a non-`ONZE_PUBLIC_`
environment value found verbatim in a packaged asset.

**The image** is two stages; the runner copies only the release, runs as the non-root `rakun-ssr` user,
reads `PORT`; with `includeErts` it is `alpine`, without it an `erlang:` image.

**Shutdown order** (data, `shutdownOrder()`):

1. readiness=false — the load balancer stops sending requests
2. stop-accepting — no new connections
3. drain-renders — in-flight renders, up to the drain timeout
4. drain-after-tasks — the request-scoped `after()` work
5. stop-supervision-tree — and exit

A drain past its timeout exits non-zero with the counts of what was still running. Readiness waits
for the route table, the client manifest and each datasource.

**Static export** writes each prerendered route as `<route>/index.html` beside the static assets and
`public/`, with no boot script and no `releases/`; a route that cannot be prerendered fails the
export naming it.
