# Decision 175 — † `hash.pbkdf2Sha256(password, salt, iterations, length)` derives over the salt's UTF-8 bytes, the same on node and erla

`hash.pbkdf2Sha256("password", "salt", 1, 32)` derives over the salt's UTF-8 bytes and prints `Eg-2z_z4syxD5yJSVsT4N6hlSMkszDVICAWYfLcL4Xs` on node and erlang alike. rakun-security's `pbkdf2Encoder()` stores a password in the form `{pbkdf2}<iterations>$<salt>$<hash>` with a fresh salt, so the program prints `true` for the prefix, `true` for the right password and `false` for a guess: the salt in the stored form is matched as the characters it holds, never as the bytes it encodes.

Cells of this repository that prove it: none yet — rakun's "consume std" step changes the base64url-salt cell; rakun-security's own tests derive through std.

[draft/main.bp](draft/main.bp)
