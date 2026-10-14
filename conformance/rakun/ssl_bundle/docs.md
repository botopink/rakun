# ssl_bundle

The reference text this cell shows (from `conformance/docs.md`, § Reading a bundle):

> `sslBoot()` resolves every configured bundle once, reads each certificate's
> fields, checks that each private key belongs to its chain, and refuses at
> **startup** — not at the first handshake — naming the bundle and what is wrong
> with it. A bundle that fails does not stop its siblings resolving; the failure is
> recorded against it and `sslBoot()` is what turns any recorded failure into the
> refusal.
>
> A reload that fails **keeps the previous material** — not by putting anything
> back, but because nothing is written until everything has been read and checked.
> Replacing a working certificate with a broken one at 3am because a deploy
> half-wrote a file is a worse outcome than serving the old one for another hour.
> The reason lands in `sslLastError(name)`, which is `""` after a good resolve.
>
> `sslPoll()` is the body of the watcher; what turns it into a timer is front 16's
> scheduler, which has not landed. With `reload-on-update=false` a poll makes no
> filesystem call for that bundle at all.

## Measured

The cell writes a self-signed certificate (validity window closed in April 2020) and its key to its working directory and points the bundle at them; nothing depends on the date the cell runs.
