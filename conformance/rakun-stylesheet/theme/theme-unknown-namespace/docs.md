# theme-unknown-namespace

{src/main.bp}

### `extendTheme` refuses an unknown namespace

An entry whose name starts with none of the nineteen prefixes is **refused**,
loudly, naming the offending name. There is no permissive mode and no argument
that relaxes it: an unknown prefix is a typo or a namespace this library does
not have, and both are errors. A variable that is silently absent is debugged as
a cascade bug days later, in a browser.
