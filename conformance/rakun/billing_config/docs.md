# billing_config

The reference text this cell shows (from `conformance/docs.md`, § Configuration that refuses to boot):

> `refuseInvalidConfig("BillingConfig", "app.billing", validateBillingConfig(cfg))`
> halts with one line per violation, each naming its **property key**
> (`app.billing.retryLimit: must be at most 10 (maxValue)`) rather than its field
> name — the operator reads `application.yaml`, not the record. There is no flag
> that turns the refusal into a warning.

## Measured

The cell prints the refusal text with `configProblemOf`; `refuseInvalidConfig` halts on an invalid record and returns the violation count (0) on a valid one.
