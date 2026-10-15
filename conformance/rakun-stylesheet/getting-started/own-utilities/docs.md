# own-utilities

{src/main.bp}

## Your own utilities and variants

A bundle is a function; `@apply` is `append`; a custom variant is a function
over the inner list; a class whose NAME is part of your API is `named`:

`named` refuses a name starting with `e_`, a name outside `[A-Za-z0-9-_]`, and a
second registration of the same name with different tokens. A utility on the
same element beats it, because `components` is layered before `utilities`.
