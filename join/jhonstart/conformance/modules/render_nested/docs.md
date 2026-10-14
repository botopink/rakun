The builders take their children as a list and their attributes as a named
argument; `renderToString` writes the tree. Text is a node of its own, so a
sibling text after an element renders next to it: `<div><p>hi</p>!</div>`.
