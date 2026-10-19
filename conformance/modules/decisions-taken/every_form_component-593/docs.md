# Decision 593 — (c), and a type may be a component — every form behaves and is called as a `fn` component.

`App` renders five components, one of each form, and a reader of the markup cannot tell which form any of them is. `Menu` is a type that implements `Component<Element>`. Its fields `items` and `title` are its props, `title` with a default, and its `render` is its body, reading the theme with `use context(themeContext)` and the fields on `self`. `<Menu items={["tea", "bread"]} />` passes the fields as attributes and lets `title` take its default; the second `<Menu … title="Footer" />` overrides it. Neither call builds a `Menu` record: each answers the same lambda a `fn` component answers. `item` does not answer a component, so it is an ordinary helper, called from `render`.

`Shop.banner` is a method that answers `Component<Element>`, so `{shop.banner()}` puts a component in the tree, with its own hooks node. `badge` is a `component` lambda, typed by its annotated `val`. `credits`, in `draft/credits.bp`, is that module's anonymous `pub default component fn`, imported by its path (`import {credits};`) and called by the module's name. The program prints the page's HTML as one line: the shop's name, the two menus (`Menu`, then `Footer`), `new` and `rakun 2026`.

The props are written as the type's fields, or as a `fn`'s plain parameters (`credits(year: i32)`). Decision 737 removed 593 (2)'s "one record parameter, never a list", so both forms stand. Writing `implement Component<Element>` without a `render` is refused, located. So is calling `Menu(items: […]).render()` directly, with the fix `call the component, not its body: <X …/> or X(…)`. A `use` outside `render` is refused too.

Cells in this repository that prove it: none yet. `rakun-bpp/components/render_nested` composes `fn` components only. The type and method forms come with 144 B-17 and B-116 and front 150.

[draft/main.bp](draft/main.bp)
[draft/credits.bp](draft/credits.bp)
