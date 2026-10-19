# Decision 706 — No test lifecycle hook: nothing implicit runs around a `test` block; a test body calls its reset helper.

The example tests rakun's configuration properties, which live in the host's property table and so
outlive any one test. Each `test` block begins by calling `freshConfig()`, the file's own reset: it
drops the container's singletons and sets `server.port` back to `8080`. The second test overrides the port to `9090`; the
third reads `8080` again only because it called the reset first. Nothing named `beforeEach`,
`afterAll` or `setUp` exists, and no function runs around a `test` block unless its body calls it —
the reset is visible in every test that relies on it. `main` calls the same reset and prints `8080`.

Proving cells: none in this repository; the rule is the language's (`botopink test`), and rakun's
own tests (`modules/rakun/test/`) call their reset helpers this way.

[draft/main.bp](draft/main.bp)
