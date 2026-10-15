# router_state

{src/main.bp}

The route snapshot is a `RouterState`: the path, the dynamic `params`, the query
`search`, the matched `pattern` and the `selected` layout depth. `fill` installs
a snapshot (params and search querystring-encoded, as the payload carries them)
and `snapshot()` reads it. `pairValue` looks a name up in a list of pairs and
answers an empty string when the name is absent.
