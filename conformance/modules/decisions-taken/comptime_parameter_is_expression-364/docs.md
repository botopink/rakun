# Decision 364 — Every `comptime` parameter is an expression: `comptime x: @Expr<T>` — a decorator's, a tag annotation's, a template function's, any function's, a builtin's.

The example is a decorator with both kinds of build-time parameter, as the parameter modifiers
read today (decision 616). `#[bounded(10, "a cart holds at most ten lines", { n -> n <= 10 })]`
annotates rakun's `CartService`. `limit` and `message` are `comptime`: the decorator receives
their values, `10` and the text, and reads them directly — `limit < 1` is checked while the
program is compiled, and a bad limit is reported at that argument. `rule` is `syntax`: the
decorator receives the lambda as written, typed against `fn(v: i32) -> bool` at the argument, and
never runs it. It hands the code on: the executor registers it with the program, and the program
evaluates it at run time, when `main` asks each check about the cart's twelve lines and prints
`CartService: a cart holds at most ten lines (limit 10)`.

An argument written where a `comptime` parameter stands must be known at build; a run-time value
there (a function's parameter, a value read from the request) is an error at that argument. No user
code runs at build through `rule`: had the decorator called it, the call would be refused.

The row reads the parameter as `comptime x: @Expr<T>` with `.value`; that spelling is overtaken —
`syntax` now receives the code and `comptime` the value (decisions 575 (4), 616) — and the example is
written in the spelling in force.

Proving cells: none in this repository; rakun's decorators take their `comptime` arguments as
values today (`#[value("key")]`, `#[getMapping(path)]`, under `conformance/rakun/web/usage`), and the
rest of the rule is botopink-lang's (`01-checker` s24 box 2, s35).

[draft/main.bp](draft/main.bp)
