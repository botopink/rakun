# Decision 343 — Each decorator invocation is independent:

The example has two `#[provides]` functions, one per type, and reads the catalogue of providers at
its entry point. Each decorator invocation sees only the function it annotates: `systemClock`'s
`#[provides]` registers a `Clock` provider and has no way to learn that `smtpMailer` exists,
because a decorator body writes no module-level `var` — such a write is refused — and keeps no
state between invocations.

The question a single invocation cannot answer — is this type provided twice? — is asked where the
whole catalogue is visible. `providedTypes` reads `compiler.find(with: provides)` in a `comptime`
block, at build, and fails when a return type repeats. With the program as written it answers
`Clock,Mailer` and `main` prints it. Add a third provider `backupClock() -> Clock` and the build
stops at this block with `two #[provides] of Clock: systemClock and backupClock` — at compile time,
naming both declarations. Two commands of one name or two handlers of one route are refused the
same way, by the entry point that reads their catalogue.

Proving cells: `conformance/rakun/container/provides` registers providers one invocation each; the
duplicate is still a boot-time raise there (at module load, naming both functions), which rakun 04
(R06-2) moves to the entry point's build-time read. No cell of this repository refuses it at build
yet.

[draft/main.bp](draft/main.bp)
