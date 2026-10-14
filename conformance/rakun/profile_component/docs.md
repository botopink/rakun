# profile_component

The reference text this cell shows (from `conformance/docs.md`, § `#[profile]` on an ordinary component):

> Same machinery, same report: off its profile the component is left unbuilt and
> appears in the "not applied" block with `F|prod` and the active set as the value
> observed. The profile SET itself is the configuration layer's
> (`rakun.profiles.active`, `.include`, `.default`, groups); this reads it. Two
> `#[profile]` markers on one declaration are conjunctive and therefore
> unsatisfiable, and are refused at compile time.
>
> Because the stereotypes' `__rkMake_<Type>()` is frozen for this milestone, a
> profile-gated component is reached through the emitted `__rkAutoGated_<Type>()`
> when you want the refusal rather than the value.
