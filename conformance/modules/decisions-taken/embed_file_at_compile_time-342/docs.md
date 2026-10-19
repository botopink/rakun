# Decision 342 — `@embedFile(comptime path: @Expr<string>) -> string` reads a file at compile time, in any context

The program embeds `banner.txt`, a file of its own package, as rakun-ssr embeds a font or an Open Graph template. `compiler.embed("src/banner.txt")` resolves the path against the package's `botopink.json` and answers the link under `comptime`, and `Asset` holds it. The text is read twice: the `comptime { … }` block opens the asset and reads its text at build, so the string is a constant of the compiled program; the second read opens it when the program runs. The program prints the banner, `rakun — embedded at build`, then `true`: one text either way.

An absolute path or one leaving the package (`../secrets.txt`) would be refused at the argument, a path not known at build at the argument too, and a missing file at the call. A decorator of a library reading `#[wsdl("schemas/billing.wsdl")]` resolves the path against the application's manifest, not the library's. `io.fs` stays refused in a comptime body otherwise.

Cells of this repository that prove it: none yet — rakun 88 and 93 (rakun-ssr's fonts and social cards) bring the code.

[draft/banner.txt](draft/banner.txt)

[draft/main.bp](draft/main.bp)
