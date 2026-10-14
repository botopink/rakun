# cors

The reference text this cell shows (from `conformance/docs.md`, § CORS):

> or, per controller:
>
> With no policy nothing is allowed and no CORS header is ever set. The wildcard
> together with `allowCredentials: true` fails at boot. A preflight for a path with
> no route answers 404.

## Measured

The original fence named the provider `corsPolicy`, which shadows the constructor it calls; the cell names it `applicationCors`.
