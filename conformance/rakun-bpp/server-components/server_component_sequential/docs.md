# server_component_sequential

{src/main.bp}

A server component awaits its loads in order: the second load may use what the
first returned. The page renders only after every `await` has answered.
