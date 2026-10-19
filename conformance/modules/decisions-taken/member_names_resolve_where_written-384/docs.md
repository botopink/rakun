# Decision 384 — A member a library's decorator writes resolves each name where it was written: the library's names in the decorator's module, the annotation's arguments in the annotated module — 112's hygiene for members.

`#[configurationProperties("app.mail")]` adds the member `MailConfig.bindProperties(prefix)` to the user's type. The member's body is rakun's: it reads each field with rakun's property readers (`rkValueOr` for the `string` host, `rkPropIntOr` for the `i32` port), and those names resolve in rakun's module, though the program imports nothing of rakun but the decorator and `rkSetProp`, which it calls itself. The program declares a `rkValueOr` of its own, and the member never captures it: `main` sets the two properties, binds them and prints `smtp.example.com` and `2525`, then the program's own `rkValueOr` answers its own text. The annotation's argument, the prefix `"app.mail"`, resolves where it was written, in the user's module.

The same holds for `validation`'s `#[check(senhasIguais, message: "…")]`, whose `validate` member names `Violation` and a private helper of `validation` while `senhasIguais` and the message are the annotated module's.

Cells of this repository that prove it: `rakun/configuration/configuration_properties` and `rakun/validation/billing_config` call a decorator-written `bindProperties`, though both still import the readers by hand.

[draft/main.bp](draft/main.bp)
