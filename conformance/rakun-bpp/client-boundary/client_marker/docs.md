# client_marker

{src/main.bp}

`#[client]` marks a component as a client island; it coexists with the
`@Component<Element>` return, which is the effect. On the server the component
renders its first pass; the browser starts it from the payload. Applying the
marker requires importing it from `rakun-bpp`.
