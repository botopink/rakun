# binders

The reference text this cell shows (from `conformance/docs.md`, § Typed coercion of `Request`'s strings):

> `Request.param`/`query`/`header`/`body` all answer `string`, and `""` when
> absent. The binders make the distinction and record a violation instead of
> yielding a zero. Bind everything, then ask once:
>
> `bindInt("age", "12x")` answers `0` **and** records a `typeMismatch` naming
> `age`, so the zero can never be mistaken for a value the caller meant. The
> accumulator is request-scoped: on the BEAM it is the serving process's
> dictionary, so two concurrent requests cannot see each other's violations.

## Measured

The binders read plain strings; the cell passes them where the example read `req.query(...)`.
