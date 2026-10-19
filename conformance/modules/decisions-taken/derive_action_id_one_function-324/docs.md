# Decision 324 — One function derives an action id: `actions.id.deriveActionId(secret, module, name, buildId)`; rakun-app keeps no wrapper.

The example derives the id of one server action the way rakun-app does, through the one function
that derives it. `createPost` is a `#[serverAction]`; the secret is the `secret` field of the typed
`#[config("rakun.actions")]` record `ActionsConfig`, read as a value, never through `rkProp`.
`deriveActionId(secret, "app@posts", "createPost", "build-1")` answers the id a form carries: the
same arguments answer the same id (`true`), another build id answers another (`false`), so an id
is stable for a build and changes with it.

`actionIdOf("createPost")` is rakun-app's lookup of a registered action's id; it calls
`deriveActionId` itself with the configured secret, the action's module and the build — there is
no `actionId(module, name, buildId)` wrapper in rakun-app to call instead. The last line checks
an id's grammar with the package's `isActionId`: `a_` and 24 lowercase hex digits pass, a name
written by hand does not.

Proving cells: `conformance/rakun-bpp/forms/form_action` binds an id of that grammar to a form;
none of this repository derives one yet. The derivation's cells come with `03-bundled-libs/103`
step 2 and `04-rakun/22`.

[draft/main.bp](draft/main.bp)
