# Decision 332 — Big numbers, and `Json` read like Jackson's strict configuration.

The example totals an invoice the way a rakun handler that answers JSON would. `big` is a `bigint`
literal past any fixed width, and `big * 10n + 1n` prints all 31 digits on every target. Each `Line`
holds a `Decimal`, read from its text: `0.10` plus `0.20` is exactly `0.30`, where an `f64` would
answer `0.30000000000000004`. Dividing the total by three names both the scale and the rounding
mode, `div(…, scale: 2, rounding: Rounding.HalfEven)`, and answers `0.10`; there is no `div`
without them. `Decimal(10n, 1)` and `Decimal(100n, 2)` are `1.0` and `1.00`: `==` compares the
value, `true`, while `toString()` keeps each scale. The response body writes the total as its plain
text, `{"total":0.30}`, so nothing rounds on the way out.

The decision's other two points meet rakun through its dependencies and are not run here: the
`json` library reads `0.30` as `Dec`, an exact `Decimal`, and a numeral past `i64` as `BigInt`; and
`validation`'s `#[validated]` binding, which rakun's configuration and request binding use, refuses a
fraction or an out-of-range integer for an `i64` field instead of truncating it.

Proving cells: none in this repository yet; the numbers are std's (front `01-compiler/139`), and
rakun's binding of them comes with front 150's Conformance step.

[draft/main.bp](draft/main.bp)
