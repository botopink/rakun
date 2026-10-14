An `ErrorBoundary` renders its child inside `<div data-jh-e="…">`; when the child
answers an error the fallback renders instead. The fallback receives `infoFor`'s
record — an empty message and the digest — so nothing the server knew leaks into
the HTML; `serverInfoFor` carries the message and the same digest, for the logger.
