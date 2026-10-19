# Decision 327 — `#[validated]`'s parse half are members of the type, named without the type's name:

The example is a `Player` record seen from rakun's side of a request: a body of JSON text, a document already read, and a set of form pairs. Every way in is a member of the type, and none is named after it. `Player.decode(text)` reads the request body and prints `ok ana 12`. `Player.parse(doc)` takes the `Json` that `json`'s `decode` already produced and reports `score:minValue` for the negative score. `Player.parseAt(doc, "players[1]")` is the same parse with each violation placed under the path it is given, so the field reads `players[1].score`. `Player.bind(pairs)` takes the `#(string, string)` pairs a query string or a posted form arrives as, coerces `"7"` to the `i32`, and prints `ok cy 7`. In the other direction, `Player.encode(p)` gives back the `Json` that `json`'s `encode` writes, `{"name":"di","score":3}`, and `Player.jsonSchema()` is the type's JSON Schema, which names `score`.

These members sit beside `validate()` and `constraints()` and travel with the type into every module that imports `Player`. There is no `parsePlayer`, `parsePlayerAt`, `decodePlayer` or `schemaOfPlayer` at module level, and `Schema<T>` stays private to validation.

Cells in this repository that prove it: none yet. The members are validation's (front 146, `signup_schema_example_test.bp`); `json` holds no code until 151 s1 moves std's `json.bp` there, and until then the example's import from `"json"` does not resolve.

[draft/main.bp](draft/main.bp)
