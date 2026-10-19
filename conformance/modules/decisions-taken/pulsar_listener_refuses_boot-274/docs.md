# Decision 274 — Pulsar is not split: it stays in `rakun-messaging/src/pulsar/` and rakun keeps 16 members (a split would remove no edge)

The example is an application with one Pulsar listener, and its boot is refused. Pulsar stays
inside `rakun-messaging` (`pulsar/`), not a member of its own: the program imports the listener
marker and the admin arm's topic names from the same package as every other messaging arm.
`parseTopic("orders")` fills in what a bare name leaves out and `renderTopic` prints
`persistent://public/default/orders` — that part of the arm exists and runs.

`OrderEvents.onOrder` is a `#[pulsarListener(…)]` on that topic. When `main` calls
`startMessaging()`, the boot stops with a problem that names the topic and the missing data plane:
a `pulsar://` listener needs the binary protocol (a connection, LOOKUP, consumers), which is not
written, so the listener refuses the boot rather than starting and never receiving a message. The
expected answer is that refusal, after the topic line.

Proving cells: none in this repository yet; they come with front 91 (the admin arm, the settings
checks and this refusal cell) and the `deferred.md` row for the binary protocol.

[draft/main.bp](draft/main.bp)
