# transform-lifted

{src/main.bp}

#### In v4 `rotate`, `scale` and `translate` are properties, not functions

That is the change the whole section rests on. Three tokens in one list are
three declarations in one rule and none overwrites another:

Three properties, so none overwrites another; the pre-1.0.10
`transform:rotate(45deg) scale(1.1)` shape is gone. Scale and translate also
write their axes into `--tw-*` variables, as upstream v4 does, so two axes of
one family compose too.
