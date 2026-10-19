# Decision 351 — A native tag's attributes are typed the way React types its intrinsic elements, in botopink's own shapes, and `prelude.bp` is the intrinsic table.

Every native tag in `Header` is a call of the `rakun-bpp` builder of that name, and its attributes are that builder's props record, checked as a component's attributes are. `href`, `id` and `class` are `string` fields. `tabIndex={2}` is an `i32` and is written camelCase as React writes it; the renderer writes HTML's `tabindex`. `type={.Email}` on `input` and `target: .Blank` on the anchor are enum cases. `required` is a `bool`, written bare and absent when false. `ariaLabel="Main"` is a typed field of `AriaAttrs` and renders as `aria-label`. `data-track="home"` belongs to the one open family, any suffix with a `string` value.

`docsLink` is a value of `AnchorProps`, the anchor's own props, layered with `Type.merge` from the global attributes, the ARIA ones and the anchor's. `<a {..docsLink} class="external">` spreads it onto the element and adds a class. The program prints the header's HTML as one line.

Each of these is refused at build, located: `<a hreff="/x">` at `hreff`, `tabIndex="abc"` at the value, content inside a void element such as `<input>…</input>` at the tag, a tag the prelude does not name (`<my-widget>`) at the tag, and an event attribute such as `onClick` at its name.

Cells in this repository that prove it: none yet. The builders are still `(children, attrs: Array<#(string, string)>)`. The props form, `GlobalAttrs` / `AriaAttrs` / `AnchorProps` and the refusals arrive with front 150 s36 step 13 (decision 362) and s39.

[draft/main.bp](draft/main.bp)
