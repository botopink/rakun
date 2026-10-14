A component imports the builders and hooks it uses from `rakun-bpp` (`div`, `p`,
`text`, `state`, `effect`, `renderToString`), and the `html """…"""` markup DSL
from its own member, `rakun-bpp`. The cell uses both: a stateful component
written as markup, rendered inside a builder tree.
