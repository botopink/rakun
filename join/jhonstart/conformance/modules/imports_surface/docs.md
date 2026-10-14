A component imports the builders and hooks it uses from `jhonstart` (`div`, `p`,
`text`, `state`, `effect`, `renderToString`), and the `html """…"""` markup DSL
from its own member, `jhonstart-html`. The cell uses both: a stateful component
written as markup, rendered inside a builder tree.
