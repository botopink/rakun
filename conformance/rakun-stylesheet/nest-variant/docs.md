# nest-variant

### Nesting runs inner-`&`-first

`nestVariant(s, v)` wraps a sheet in a variant, exactly as CSS nesting does:
the **inner** rule's `&` is what the **outer** variant's selector replaces, and
the outer variant's at-rule is prepended, so the outer modifier is outermost on
both halves.

Blocks pass through untouched — an at-rule does not wrap a keyframes rule.
