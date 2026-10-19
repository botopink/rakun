# counter_ssr

{src/main.bp}

A component is a function returning `Component<Element>`; its body activates a
hook with `use`. `renderToString` renders the tree the server pass produces — a
pure string — so a counter at 0 renders `count: 0`.
