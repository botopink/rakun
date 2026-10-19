# Decision 144 — A `#[validated]` record (306) refuses a key it does not declare: a violation coded `unrecognizedKey`, at the key's own p

The example is a rakun handler that posts a comment. The request body carries a key `admin` that `Comment` does not declare, so `Comment.decode` answers a report holding one violation coded `unrecognizedKey` at the key's own path, `admin`. The handler turns it into `400 admin:unrecognizedKey`, and nobody can slip a field past the type by adding it to the JSON. The same comment without the extra key answers `201`.

The two other records show the only ways to accept such a key, and each is written on the type where a reader sees it. `Ping` carries `#[stripUnknown]`: the extra key is dropped and the program prints `ping ana`. `Event` declares a `#[rest]` field of `Dict<string, Json>`: the extra members land there in document order and the program prints `open admin,seat`. No setting, flag or global switch changes the default.

When a framework adds fields of its own to a form, such as rakun's action field that names the action being posted, the framework removes them before the record sees the pairs, so the default still holds for every key the user sent.

Cells in this repository that prove it: none yet. The default and the two markers are validation's (front 146, its `object_policy_example_test.bp`); rakun's action wrapper that drops its own field comes with front 150 s23 (127).

[draft/main.bp](draft/main.bp)
