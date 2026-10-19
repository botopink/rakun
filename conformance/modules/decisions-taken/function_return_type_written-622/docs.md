# Decision 622 — Every function writes its return type, `-> void` included: `fn m(self: Self) -> void { … }`, `pub fn main() -> void { … }`; a `fn` with no `->` is refused at its name, `fn-return-missing`, `write -> void, or the type it answers`.

Every function of the program says what it answers where it is written. `Greeter.greet` answers `-> string`; `Greeter.announce` answers nothing and writes `-> void`; the rakun handler `hello` answers `-> Response`; the typed lambda `shout` writes `-> string` too; and `main` is `pub fn main() -> void`. The program prints `Hi, ana!`, `Hello, bob!` and `HELLO, BOB!`. No type is read off a body: a tail or a `return` in a `-> T` body is checked against `T`, and a valued tail or `return` in a `-> void` body is refused at it.

Leaving the arrow out — `fn announce(self: Self, name: string) { … }`, or `pub fn main() { … }` — is refused at the function's name, `fn-return-missing`, with the fix `write -> void, or the type it answers`. That holds for every form: a method, a `default fn`, a `declare fn`, a static, a typed lambda.

Cells of this repository that prove it: none yet. rakun's sources and cells gain their arrows with `machine-1/165` s10's codemod; `rakun/web/usage` still writes `fn main()`.

[draft/main.bp](draft/main.bp)
