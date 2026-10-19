# hook_noun_custom

{src/main.bp}

Hooks are nouns (`state`, `router`, never `useState`) and the keyword `use` is the
activation. A custom hook is an ordinary function returning the capability
(`Component<State<i32>>`) and is activated the same way: `use counter(5)`, never
`use useCounter()`.
