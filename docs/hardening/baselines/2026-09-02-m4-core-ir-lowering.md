# M4 deterministic core-IR lowering slice — 2026-09-02

This observation records the second M4 slice: a bounded UTF-8 source reader and
deterministic lowerer from one source submission through named global outer
macro expansion into validated `yalisp-core-ir-v1` data. It does not claim a
reference executor, general computed/lexical macro expansion, current-frame
local definition, decompilation, general compilation, or M4 completion.

## Boundary and semantics

`scripts/hardening/core-ir-lowering.mjs` is 21,728 bytes with SHA-256
`d993e11c4dae649e2c59cf543ec601a5b84ef83e17aca2c781930c560d7d6652`.
The artifact inventory and conformance identity include it, and the build guard
requires it to remain byte-identical across generated-artifact rebuilds.

The reader retains half-open UTF-8 byte spans and portable YaLisp data for nil,
booleans, signed 30-bit integers, strings, symbols, proper/dotted lists, and
reader prefixes. The lowerer covers every v1 opcode, assigns lexical binders
program-unique IDs, preserves kernel-special-form precedence, lowers callee and
arguments left-to-right, and validates the produced graph before returning it.
Omitted `if` alternates and implicit lambda-body sequencing carry explicit
generated provenance.

The optional expansion callback receives and returns canonical source text. It
is consulted only for a non-special, non-lexical symbol head. Changed results
are reparsed and recursively lowered at the original call-site span with
ordered outermost-to-innermost macro origins; unchanged results remain runtime
calls. The lowerer never evaluates produced user code. A local `define` is
rejected as `unsupported-local-define`, because the seed writes its current
frame while IR v1 models only global definition. Computed and lexically passed
macro values are also outside this bounded boundary.

## Deterministic evidence

The focused suite passes 8/8 on Node v24.19.0, Linux x64, with no failures,
cancellations, skips, or todos. Eight fresh boot sessions recursively lower
`let` followed by `when` to the same canonical IR hash:

`a693116b6607ef5065104858a31b873f4d18a3de3435d95b45abc2e2be06fab4`

The `yalisp-core-source-v1` generator fixes seed `0x4c4f5745`, 256 cases,
and depth 5. Every case is lowered twice and validated. Coverage is
`const=1015`, `ref=151`, `set=237`, `define=30`, `if=236`, `lambda=234`,
`call=229`, and `begin=263`; the largest graph has 75 IR nodes. The aggregate
of the 256 canonical IR hashes is:

`2677a95639aa4aeb3b6fc2cf153eed8cc670de3ef0cc9c2ba62d81da4283004e`

Malformed fixtures cover closing delimiters, unterminated list/string,
missing prefix operand, and three dotted-tail failures. Exact last-allowed and
first-refused witnesses cover submitted source bytes, source-unit bytes,
reader nodes/depth, aggregate expansion nodes, expansion-result bytes,
changed expansion steps, and per-span origins. Wrong form counts, unresolved
macro/quasiquote runtime forms, local definition, and invalid expansion result
shapes fail with stable codes and byte locations.

The focused wall time is traceability only. The host concurrently ran unrelated
long tests, so this observation intentionally makes no performance claim and
does not replace the quiet-host warmup/sample/variance protocol in `HARNESS.md`.

## Promotion and next gap

The repository-wide `npm test` promotion gate passes 358/358 web tests in
13,778,733.446 ms and 1/1 site-content test in 61.925 ms, with zero failures,
cancellations, skips, or todos. This advances the conformance runner's inherited
non-regression floor from 350 to 358.

The golden differential remains green for corpus SHA-256
`9740b03f1e20e7694c82ee65cbd669949513798b995a57fae976b50c6ca36237`:
15 cases, 17 events, 30 applicable stage observations, 15 explicit
not-applicable stages, and no earliest divergence. Its 11-case compiler-error
profile still records the expected and observed joint language-error
intersection as 0/0 with no unexpected intersection. Typecheck, production
build, artifact inventory, generated-artifact byte comparison, focused
conformance tests, and `git diff --check` are also green.

The next smallest M4 gap is a deterministic reference executor over validated
IR with explicit shared-cell environment behavior, structured errors, effect
capture, and work limits.
