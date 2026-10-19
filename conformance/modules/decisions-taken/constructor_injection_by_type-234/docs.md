# Decision 234 — Constructor injection resolves a field by its type (Spring's model, 281): a stereotyped type's factory is its member `T.

The example wires an `InvoiceService` without naming any bean in text. The service declares two
fields, `invoices: InvoiceRepository` and `clock: Clock`, and nothing else: the field's type is
the whole request. `InvoiceRepository` is a `#[repository]`, so its factory is its own member
`InvoiceRepository.make()`; `Clock` is a plain record that a `#[provides]` function returns, so
`systemClock()` is the factory registered under `Clock`. When `InvoiceService.make()` builds the
service it asks for each field by that type and gets a value of that type back, which is why
`self.clock.stamp()` needs no cast.

`beans()` is the registry. It is computed at build: `compiler.find(with: [service, repository],
member: "make")` reads the catalogue of every declaration the two stereotypes annotated, and each
entry's `value` is the type's `make()`. Nothing in the program spells a generated function name;
the only contract is the member `make()` on the type. `main` installs the registry and prints `2 open
at <now@UTC>`.

A field whose type has no provider — say a `mailer: Mailer` added to `InvoiceService` with no
`#[provides]` returning `Mailer` and no stereotyped `Mailer` — stops the boot naming `Mailer`;
two providers of `Clock` are told apart by a label (decision 321).

Proving cells: `conformance/rakun/container/resolve` (a stereotyped type resolved by its type, the
registry built from the catalogue), `conformance/rakun/container/managed` (`OrderCache.make()`
injecting `OrderRepository`), `conformance/rakun/container/provides` (a `#[provides]` function
registered under its return type), `conformance/rakun/web/usage` (a controller's field injected by
type).

[draft/main.bp](draft/main.bp)
