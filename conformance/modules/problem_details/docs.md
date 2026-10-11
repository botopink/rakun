# problem_details

The reference text this cell shows (from `conformance/docs.md`, § Problem details):

> The tag is a **string**, not a type name: botopink has no typed raise and
> `try … catch` works over `@Result` alone. A raise nothing handles answers 500
> with `about:blank` and a correlation digest; the reason goes to the log under
> that digest and never into the body.

## Measured

The cell renders the problem with `renderProblem`; `raiseProblem` from a handler reaches the same advice through the chain.
