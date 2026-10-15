# form_action

{src/main.bp}

`formAction` binds an action id (`a_` and 24 lowercase hex digits) to the current
pathname, and `actionForm` renders the bound form: the `method`, `action` and
`data-jh-a` attributes, the hidden field that routes an un-hydrated POST first,
then the fields. The wire names are installed once at boot with `setWireNames`.
