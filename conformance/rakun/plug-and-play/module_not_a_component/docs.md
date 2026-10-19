# module_not_a_component

{src/main.bp}

`#[rakun.module]` over a plain `fn() -> Service` is refused at the annotation:
a module is a `component fn() -> Component<Service>`.
