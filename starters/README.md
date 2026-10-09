# rakun starters

A starter is a package with a manifest, a `src/root.bp` that holds only a
docblock, and no code. It is a curated dependency set with a name a person can
remember: declare one and the modules it names are resolved for you. You keep
importing from the modules themselves (`from "rakun-web"`, `from
"rakun-cache"`). Nothing is importable from a starter, so a starter can drop a
module without breaking an import.

| Starter | Pulls | Spring counterpart |
|---|---|---|
| [`rakun-starter`](./rakun-starter/) | `rakun` (logging included: `rakun-logging` is the core's `logging/` since front 128) | `spring-boot-starter` |
| [`rakun-starter-web`](./rakun-starter-web/) | `rakun-starter`, `rakun-web` (validation is the library `validation`, declared by `rakun` itself) | `spring-boot-starter-webmvc` |
| [`rakun-starter-data-sql`](./rakun-starter-data-sql/) | `rakun-starter`, `rakun-data` | `spring-boot-starter-data-jpa` + `-jdbc` |
| [`rakun-starter-security`](./rakun-starter-security/) | `rakun-starter`, `rakun-security`, `rakun-session` | `spring-boot-starter-security` |
| [`rakun-starter-actuator`](./rakun-starter-actuator/) | `rakun-starter`, `rakun-actuator`, `rakun-metrics` | `spring-boot-starter-actuator` |
| [`rakun-starter-cache`](./rakun-starter-cache/) | `rakun-starter`, `rakun-cache` | `spring-boot-starter-cache` |
| [`rakun-starter-messaging`](./rakun-starter-messaging/) | `rakun-starter`, `rakun-messaging` | `spring-boot-starter-amqp` + `-kafka` |
| [`rakun-starter-test`](./rakun-starter-test/) | `rakun-starter`, `rakun-test`, `onze` | `spring-boot-starter-test` |

Starters overlap, and the resolver removes the duplicates. Every version is the
one `modules/rakun/src/version_set.bp` pins. `test/version_set_test.bp` in
`modules/rakun` fails when a manifest drifts from that table.

## Naming

Official starters are `rakun-starter-*` and live in this directory. A
third-party starter is named `<project>-rakun-starter`, for example
`acme-rakun-starter`, and lives in its own repository. The `rakun-starter`
prefix is reserved: a name that starts with it is a promise from the rakun
maintainers. The lint (`modules/rakun/test/starter_manifest_test.bp`) checks
only the directories under `starters/`, so it never sees a third-party
starter. It checks four things:

- the directory name equals the manifest `name`;
- the name starts with `rakun-starter`;
- every dependency is a module or starter in the version set, or is on the
  literal out-of-repo allow-list (`onze`);
- no dependency is declared twice.

## Resolution and conditions

`bpmp` resolves the dependencies, and `botopink.lock.json` pins them. rakun
owns neither. A starter names its sibling modules as `{ "workspace": true }`,
which is the form the toolchain requires for a member of the same workspace.
It names `onze` by `path`.

`#[conditionalOnModule(name)]` checks the resolved set, transitive entries
included. An application that declares only `rakun-starter-data-sql` therefore
has `rakun-data`, and the starter's own name counts too.

## What works today

A consumer inside a checkout of this repository, or beside one, depends on a
starter by `path`. The starter loads every module it names, and so does each
of those modules' own dependencies. An `import` is accepted only from a
package the application's manifest declares itself, though, so the
application also lists each module it imports from:

```json
"dependencies": {
  "rakun-starter-web": { "path": "../rakun/starters/rakun-starter-web" },
  "rakun":             { "path": "../rakun/modules/rakun" },
  "rakun-web":         { "path": "../rakun/modules/rakun-web" }
}
```

Once any package the build resolves can be imported (`language-gaps.md`,
*Toolchain gaps*), the starter line alone will be enough.

An out-of-tree consumer **cannot** depend on a starter or a module by `git`.
A dependency is `{ git, path, ref }` with no subdirectory field, and every
starter and module is a directory inside the one rakun repository. A `git`
dependency therefore resolves to the repository root, whose manifest is named
`rakun`. The in-tree resolution is tested. The out-of-tree one is not possible
until `DepSpec` gains a `subdir` field that `bpmp` carries through its clone
and its lockfile (`specs/1.0.10-beta/language-gaps.md`, *Toolchain gaps*).
