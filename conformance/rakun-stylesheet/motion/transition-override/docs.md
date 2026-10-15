# transition-override

{src/main.bp}

#### A preset then an override

Two tokens, two rules, four declarations — and the preset's `150ms` is still in
the output with the `200ms` after it. **List order is declaration order**, so
the later one wins; reversing the two is a different class whose preset now
overrides the override.
