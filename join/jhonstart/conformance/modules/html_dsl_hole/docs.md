`html """…"""` takes the markup unevaluated and expands it at comptime into the
builder pipeline. Each `${expr}` hole is spliced as a text child, and the
lowercase tags resolve to the builders the module imports. The expansion renders
byte-equal to the hand-written builder calls.
