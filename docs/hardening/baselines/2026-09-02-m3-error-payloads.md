# M3 structured error payloads — 2026-09-02

This immutable observation records the eighth atomic M3 slice. Before the
change, every typed error had a stable category and diagnostic but no distinct
machine-readable data field. The deterministic fixture failed four of five
groups: `error.data` was absent and the raw seed had no payload-length export.

The seed now resets and exposes a `(pointer, length)` UTF-8 data span alongside
`error_kind`. Unbound and named-arity failures carry the offending name; cap
failures carry `depth`, `work`, or `expansion`; other classified paths carry
their exact fixed diagnostic token. Node and browser hosts bounds-check and
decode the span into `SeedLanguageError.data`. An exported entry resets both
kind and span, so a deliberately induced raw out-of-bounds Wasm load proves
category zero, length zero, and native `WebAssembly.RuntimeError` identity.

The structured boundary passes 5/5 and the combined focused hardening set
passes 59/59. Typecheck, production build, fresh-WABT byte identity, and the
15-case/17-event golden differential are green. The reviewed corpus now includes
data in both error cases and has SHA-256
`d6a57946b45dc1a7fd88a398007e2b6bb37d1edea2a5ba8ad431f98667c77080`;
30 stage observations match, 15 stage slots are explicit not-applicable, and
the earliest divergence is `null`.

On Node v24.19.0, Linux x64, artifact inventory records WAT 116,403 bytes at
`a2192105e7edb6af1b78eb85a09deaf3c06f010876526894ecb158e2702d9af8`;
Wasm 12,028 bytes at
`504083c9a42e3ad5dee2f2a9feba50ffd00a35a13fb3b8369ef01768db2671e7`;
106 defined functions, twelve functional exports, and 5,042 unfolded static
instructions. Relative to the user-arity slice this is +1,416 WAT bytes, +178
Wasm bytes, three functions, two functional exports, and 51 static instructions.
Bootstrap, compiler, and AOT artifact hashes are unchanged.

M3 remains active for one exit only: explicit evidence describing and testing
the interpreter/compiler error intersection.
