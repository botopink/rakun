# Container queries

> Package: [`rakun-stylesheet`](../docs.md) · index: [`../../docs.md`](../../docs.md)

A parent becomes a container; a descendant asks about the container's width,
not the viewport's:

{container-queries/src/main.bp}

The thirteen builders `containerAt3xs` … `containerAt7xl` read `--container-*`
from the theme (16rem … 80rem by default), so overriding `--container-md` moves
every `md` query. `containerNamed(ContainerSize.Sm, "main", inner)` is `@sm/main:`
— `@container main (width >= 24rem)`. A size the theme does not define panics.
Do not import `ContainerSize` into a module that writes `Token.Sm(…)` (see the
maintainer notes).
