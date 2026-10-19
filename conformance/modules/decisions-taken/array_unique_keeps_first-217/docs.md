# Decision 217 — † `Array.unique` removes every duplicate, keeping each value's first occurrence in order — `[1, 2, 1, 3, 2].unique()` is

The example resolves rakun's active profiles from a list that names some of them twice, for instance once on the command line and once by a profile group. `named.unique()` drops every repeat, wherever it stands, and keeps each name where it first occurred: `["prod", "eu", "metrics"]`. A repeat does not have to be next to its first occurrence to go. The list is handed to `profiles.setResolved`, `profiles.active()` reads it back unchanged, and the profile expression `prod & metrics` matches it (`true`).

The same holds for any element compared with `==`. `[1, 2, 1, 3, 2].unique()` is `[1, 2, 3]`, and an empty list stays empty (`0`). There is no consecutive-only variant.

Cells in this repository that prove it: none yet. rakun's profile cells (`rakun/configuration/config_load`, `rakun/auto-configuration/profile_component`) read `active()` over distinct names, and the deduplicated list comes into its conformance with front 165 s7, the workspace's Conformance step.

[draft/main.bp](draft/main.bp)
