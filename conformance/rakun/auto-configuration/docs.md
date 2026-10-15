# Auto-configuration

> Package: [`rakun`](../docs.md) · index: [`../../docs.md`](../../docs.md)

A `rakun-*` module ships a configuration that wires itself only when it should.

{autoconfig/src/main.bp}

The markers are conjunctive and read top to bottom; `"*"` on a property means
"set and non-empty" and is spelled out because a decorator argument's declared
default is not applied. A type is named by a STRING because a decorator
argument is an ordinary value and there is no type-of-type — the same spelling
Spring reaches with `excludeName`. There is no `anyOf` and no expression
language: a configuration that needs a disjunction splits into two, which is
also the form that reads correctly in the report.

The application runs the pass itself, once, before `Rakun.run` — `bootstrap.bp`
is frozen for the milestone, so the line is explicit:

{autoconfig/src/main.bp}

`autoConfigure()` sorts every registration, evaluates each in that order and
records the decision. It is idempotent: a second call re-evaluates nothing.
`isAutoConfigured("RakunMailAutoConfiguration")` answers whether one matched, and
a bean factory of a configuration that did not RAISES when called, naming the
configuration and the condition that failed — it never returns a half-built
value, and calling one before `autoConfigure()` raises too, because "nothing
matched" and "nobody asked" are different answers.

## Excluding a configuration

Two channels, one list: the property `rakun.autoconfigure.exclude` (comma
separated, read through the configuration table) and
`autoConfigureExcept(["RakunMailAutoConfiguration"])`. Their union is what is
excluded. A name that matches no registered configuration HALTS the startup and
lists the registered names — a typo in an exclusion otherwise disables nothing
and leaves you believing you turned something off.

## The report

```text
rakun auto-configuration

Applied (2):
  RakunCoreAutoConfiguration
  RakunCoreAutoConfiguration.demoClock

Not applied (2):
  RakunMailAutoConfiguration: did not match: P|rakun.mail.host|* - the property is empty
  RakunMailAutoConfiguration.mailSender: the configuration 'RakunMailAutoConfiguration' it belongs to was not applied

Excluded (0):
```

`autoConfigurationReport()` returns it; `printConditionReport()` writes it at
boot when `rakun.main.debug=true` and writes nothing when it is not — the switch
is over the printing, never over the data. Only the FIRST failing condition of a
configuration is reported, because evaluation short-circuits there.

## `#[profile]` on an ordinary component

{profile_component/src/main.bp}

Same machinery, same report: off its profile the component is left unbuilt and
appears in the "not applied" block with `F|prod` and the active set as the value
observed. The profile SET itself is the configuration layer's
(`rakun.profiles.active`, `.include`, `.default`, groups); this reads it. Two
`#[profile]` markers on one declaration are conjunctive and therefore
unsatisfiable, and are refused at compile time.

Because the stereotypes' `__rkMake_<Type>()` is frozen for this milestone, a
profile-gated component is reached through the emitted `__rkAutoGated_<Type>()`
when you want the refusal rather than the value.
