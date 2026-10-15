# Forms

> Package: [`rakun-bpp`](../docs.md) · index: [`../../docs.md`](../../docs.md)

Front 67, `import {…} from "rakun-bpp"`. A form is bound to front 24's
action id (a string — this front echoes it and never constructs one) and its
markup is contract 3's exactly, so it submits before the bundle arrives:

{form_action/src/main.bp}

| Function | What |
|---|---|
| `formAction(id, pathname, actionField)` · `formAttrs` · `hiddenActionField` · `actionForm` | the binding and contract 3's markup; an id that is not `actions`' `isActionId` (`a_` + 24 lowercase hex) is refused |
| `submitForm(binding, fields)` · `invokeAction(id, args, actionHeader)` | the POST / the JSON-RPC call; the answer read by `actions`' `parseActionState`; a redirect in `n` is the router's `push`; `ok: false` is DATA, returned as the state |
| `formMount(actionHeader)` | one delegated submit listener over `[data-jh-a]`, called once by rakun-ssr front 68's entry |
| `actionState(id, initial)` | the hook — `#(state, binding, pending)`, read positionally; server pass: `initial`, `false` |
| `formStatus()` · `formStatusOf(id)` | idle on the server pass and outside any form, never an error |
| `optimistic(base, apply)` · `applyOptimistic(base, actions, apply)` | server pass `#(base, no-op)`; the fold is pure |
| `searchFormProps` · `searchFormAttrs` · `searchHref` · `prefetchSearch` | § 25's GET `<Form>`: `method="get"`, `data-jh-sf="1"`, never `data-jh-a` |
| `setWireNames(actionField, actionHeader)` | rakun-ssr installs the two wire names once; this member spells neither |

`formStatus` and `optimistic` are specified from upstream React
(<https://react.dev/reference/react-dom/hooks/useFormStatus>,
<https://react.dev/reference/react/useOptimistic>), not from `NEXTJS-DOCS.md`,
which does not carry them.
