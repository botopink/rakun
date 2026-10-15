# request_draft_mode

{src/main.bp}

The reference text this cell shows (from [`../docs.md`](../docs.md), § `draftMode()` and `connection()`):

> `__rakun_draft` is a signed cookie; `enable()` needs `rakun.draft.secret` and
> raises without it rather than issuing an unsigned bypass. Enabling marks the
> request dynamic and sets the bypass flag front 60 reads. `connection()` marks
> and reads nothing — the way a route declares itself dynamic without pretending
> to need a header — and `dynamicReason()` names the first function that marked.
