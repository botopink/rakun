# autoconfig

The reference text this cell shows (from `conformance/docs.md`, § Auto-configuration):

> A `rakun-*` module ships a configuration that wires itself only when it should.
>
> The markers are conjunctive and read top to bottom; `"*"` on a property means
> "set and non-empty" and is spelled out because a decorator argument's declared
> default is not applied. A type is named by a STRING because a decorator
> argument is an ordinary value and there is no type-of-type — the same spelling
> Spring reaches with `excludeName`. There is no `anyOf` and no expression
> language: a configuration that needs a disjunction splits into two, which is
> also the form that reads correctly in the report.
>
> The application runs the pass itself, once, before `Rakun.run` — `bootstrap.bp`
> is frozen for the milestone, so the line is explicit:
>
> The application runs the pass itself, once, before `Rakun.run` — `bootstrap.bp`
> is frozen for the milestone, so the line is explicit:
>
> `autoConfigure()` sorts every registration, evaluates each in that order and
> records the decision. It is idempotent: a second call re-evaluates nothing.
> `isAutoConfigured("RakunMailAutoConfiguration")` answers whether one matched, and
> a bean factory of a configuration that did not RAISES when called, naming the
> configuration and the condition that failed — it never returns a half-built
> value, and calling one before `autoConfigure()` raises too, because "nothing
> matched" and "nobody asked" are different answers.
