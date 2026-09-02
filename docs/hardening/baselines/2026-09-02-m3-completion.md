# M3 structured-error completion — 2026-09-02

This immutable observation closes M3 with explicit compiler/error-boundary
evidence. Earlier M3 slices established ten category codes plus UTF-8 data,
transactional prior effects, fail-before-write atomic operations, recoverable
session policy, deliberate division errors, and exhaustive primitive, special-
form, closure, and macro arity.

The final reviewed fixture is `yalisp-compiler-error-intersection-v1`: 4,243
bytes with SHA-256
`8d2f5357612def9a5d42286721dd25db1f13dd805fad8269b04a39c05eb333ae`.
Its eleven cases cover all ten seed error categories. Eight error-producing
forms return `nil` from `cc.compile` before code generation. Reader and host-
contract failures occur before a valid compiler form exists. Expected and
observed jointly supported language-error cases are therefore both zero, and
the earliest unexpected intersection is `null`.

The profile also prevented that empty intersection from hiding numeric semantic
drift. Its first run caught `(+ 1073741823 1)` wrapping to `-1073741824` in the
seed while raw compiled i32 execution yielded `1073741824`. The seed now reports
category-6 `value exceeds fixnum range`; compilation still yields the raw value,
so the case remains an explicit outside-profile error/value divergence. Decimal
literals, all `+`/`-`/`*` fold intermediates, unary negation, division results,
and `fx.mul-shift` results now share the checked boundary. A full-suite
pushwall witness then exposed one intended 32-bit product wrap. The generic
`bit.mul-shr` escape hatch now names that exact low-level contract without
weakening ordinary multiplication; positive, negative, wrap, and unrepresentable
post-shift cases are deterministic tests.

On Node v24.19.0, Linux x64, the M3 completion set passes 69/69 in 1.757 s,
including the reviewed profile, all existing compiler tests, fresh-WABT byte
identity, and the precompiled-session controls.
Typecheck and production build pass. The golden report remains green with
corpus SHA-256
`9740b03f1e20e7694c82ee65cbd669949513798b995a57fae976b50c6ca36237`,
15 cases, 17 events, 30 observed stages, 15 explicit not-applicable stages, 11
compiler-error profile cases, no earliest value/effect/error/output/state
divergence, and no unexpected compiler error intersection.

The repository-wide validation then passes 343/343 web tests with zero skips in
14,217,829.603 ms and the site-content suite passes 1/1 in 49.654 ms. Its final
four-replay negative control independently perturbs live input and reviewed
state fields and reports the intended earliest field each time; that control
alone completes in 4,782,350.513 ms. The command exits zero without reducing
the 401-record real-application workload or weakening any assertion.

Final seed artifacts are WAT 118,851 bytes at
`abca01af5f0e981f37fa7d91311b86ca011d404d6f6760dd9fd7b23f513170a7`;
Wasm 12,244 bytes at
`dbab8a04778ba61dd71c2892c62d8d6da1fbf1ee3fe563db560708fe5f32cda8`;
110 defined functions and 5,132 unfolded static instructions. Relative to the
payload slice, checked arithmetic plus the explicit wrapped multiply/shift add
2,448 WAT bytes, 216 Wasm bytes, four functions, and 90 instructions.
Bootstrap, compiler, and AOT hashes are unchanged.

M3 is complete. M4 is active, beginning with a normative, data-representable
core IR contract and validator before any general compiler rewrite.
