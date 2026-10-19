# Decision 160 — A cell that needs an external service is not a gate cell: the behaviour is asserted against an in-process double; no `--

The example sends mail without any mail server outside the program. rakun-mail ships a fixture SMTP server that runs inside the VM, and the program uses it as the double. `fixtureStart([])` opens it on a free port, and `deliverNow` sends a real SMTP conversation to it over `gen_tcp`, the same code path a production send takes: compose the message, then MAIL, RCPT and DATA. The send answers `""`, so the program prints `delivered`. The fixture then holds the message, and `fixtureMessages(port).length` prints `1`.

The second half asserts the failure path against the same double. `fixtureStart(["fail=RCPT:550"])` starts a fixture that refuses the recipient, so `deliverNow` answers a `permanent` outcome and the fixture holds no message. That prints `true` and `0`.

No step of the program needs a real mail host, a flag or a network, so it is a cell of the gate like any other. It never prints "skipped". Checking against a real provider is a `deferred.md` row, not a mode of this program.

Cells in this repository that prove it: none yet. rakun-mail's own tests (`modules/rakun-mail/test/queue_test.bp`) assert the queue, the retries and the dead letters against this fixture. Its conformance cells come with front 165 s7, the workspace's Conformance step.

[draft/main.bp](draft/main.bp)
