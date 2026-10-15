# client_props_whitelist

{src/main.bp}

`#[clientProps]` checks the record a client component's props travel in: every
field must be one of `string`, `i32`, `f64` or `bool`. The server contributes an
`Island` carrying the component's name and its props encoded as pairs.
