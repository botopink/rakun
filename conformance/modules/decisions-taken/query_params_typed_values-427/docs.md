# Decision 427 — A query's bound parameters are typed values — erika's `QueryParam` —, each built by the template from the type of the column its hole meets, checked at build.

In force under 724's names: erika's `QueryParam` and `QueryContext` are the `query` library's, and the driver and the context are `rakun-data`'s.

The example sends three queries through a driver that prints the parameters it receives. In `find`, each `${…}` hole meets a column of `User`, and the template builds the parameter from that column's type: `${id}` meets `User.id: i32` and becomes `QueryParam.Int`, `${active}` meets a `bool` and becomes `Bool`, and `${name}` meets a `string` and becomes `Text`. The driver prints `Int(7) Bool(true) Text(ana)`. In `byNickname`, the hole meets the optional column `nickname: ?string`, so an absent value goes out as a real `Null` and a present one as `Text`, and the hole after `limit` is always an `Int`. The two calls print `Null Int(10)` and `Text(bo) Int(1)`. No value is turned into text on the way: the driver gets a real NULL, a real boolean, and bytes it can send undecoded.

Since the code the template builds is typed, a hole of the wrong type is an error at the hole, at build. A method `byId(self: Self, id: string)` with `where id = ${id}` does not compile, and the message reads `expected i64 (User.id: i32), got string`. `QueryContext`'s runners take `QueryParam[]`; the older `run(sql, params: Array<string>)` is gone.

Cells in this repository that prove it: none yet. `QueryParam` and the two runners come with front 145 s1 in `query`; rakun-data's `Driver`, `DbContext` and drivers taking `QueryParam[]` with front 150 s48 and s50. Until then the example does not build: `query` still declares `run(sql, params: Array<string>)`.

[draft/main.bp](draft/main.bp)
