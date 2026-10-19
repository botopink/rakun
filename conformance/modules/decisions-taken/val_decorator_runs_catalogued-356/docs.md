# Decision 356 — A decorator on a `val` runs, and the `val` is catalogued.

`#[rakun.config]` is a decorator on a `val`, and it runs: over the handle of `mail`, `compiler.kind(decl)` is `DeclKind.Val` and `compiler.returnType(decl)` is the declared type as written, `"MailConfig"`. The decorator records the value under that type's name with `compiler.init`, before `main`, and the package reads it back by `configOf("MailConfig", MailConfig())`, its own defaults when the program declares none. So the program prints `smtp.example.com 587` and `true`. A `val` with no written type gives `returnType` `""`, and `#[rakun.config]` refuses it at the annotation (`#[config] needs the val's type written`); `compiler.setMeta` is legal on a `val`, while `compiler.addMember` and `compiler.addType` are refused there. What 356 called the catalogue (`@TypeInfo.all`) is gone (576 (7), 665): a decorated `val` reaches the program through what its decorator's executor registers, as here.

Cells in this repository that prove it: `rakun/plug-and-play/boot_modules` (a `#[rakun.config]` override read by its package) and `rakun/plug-and-play/config_wrong_field` (the override is a typed record).

[draft/main.bp](draft/main.bp)
