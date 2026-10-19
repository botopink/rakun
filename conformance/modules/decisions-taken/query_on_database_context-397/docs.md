# Decision 397 — A database query in a method body is written on the database context — `self.db.query "select * from User where active = true"` —, and `from User` names an entity whose table and columns erika reads from the type at build.

The example writes a query on the database context, in a method body. `User` is an entity:
`#[entity("users")]` records the type's table and columns as `QueryTable` meta, which the query
template reads at build. `Report` is a service whose field `db: DbContext` is injected by type, and
its method `active` is one line, `self.db.query @`select * from User where active = true``:
`query` is a template method on every `QueryContext`, and `DbContext` is one.

At build, `from User` reads `User`'s `QueryTable`: the table `users`, the columns, the fields a
query may name. The SQL and its parameters are built then, so `where active = true` is checked
against `User.active`; `from Order`, a type with no `QueryTable`, would be an error at the query
("`Order` is not an entity — annotate it with `#[entity(…)]`"), and `where actve = true` an error
at the field. At run time the method only sends the statement through its context and answers
`Result<User[], StoreError>`; `main` boots the context, resolves `Report` and prints the names or
the error.

One context serves every entity: `Report` names no table, no repository per type.

Proving cells: none in this repository yet; `DbContext` is the persistence layer folded into
rakun-data (front 165 s3), and its cells come with `04-rakun/137` step 2 and rakun `08` step 7.

[draft/main.bp](draft/main.bp)
