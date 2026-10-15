# validated

{src/main.bp}

The reference text this cell shows (from [`../docs.md`](../docs.md), § The record, and the two functions it gets):

> `#[validated]` splices two functions into **this** module:
>
> Every constraint on a field runs; the first failure does not stop the second,
> which is what makes a three-field form report three errors:

## Measured

`#[validated]` gives the type the members `validate()` and `constraints()` (the section above says so); the original fence called `validateCreateUserRequest(…)` and `constraintsOfCreateUserRequest()`, which do not exist, so the cell calls the members. The library is `validation` as a dependency of the cell; its modules are imported by name (`decorators.validated`, `report.ValidationReport`, …).
