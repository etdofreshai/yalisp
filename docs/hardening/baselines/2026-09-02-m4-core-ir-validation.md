# M4 core-IR validation slice — 2026-09-02

This observation records the first M4 slice. It defines an inspectable
`yalisp-core-ir-v1` representation and an independent deterministic validator;
it does not claim lowering, IR execution, general compilation, decompilation,
or M4 completion.

The normative grammar is `docs/hardening/CORE_IR.md`. Its eight node opcodes
cover constants, resolved references, mutation, global definition,
conditionals, closures, calls, and sequencing. Every node carries a checked
tail flag and a half-open UTF-8 source range plus macro/generated provenance.
Lexical binders use program-unique nonnegative fixnum IDs and source names only
as debug metadata. The contract fixes left-to-right effect order and shared-cell
mutation semantics for future executors.

The reviewed canonical program is 1,252 bytes with SHA-256
`12e1ba6d916787d5fcde58bce0ff722342040dee6a58527d9f1fc97787c1424b`.
The text fixture includes one repository newline, so its file identity is 1,253
bytes with SHA-256
`578e6bf97332ad4e90ded418c43ee2e0647d053cfe49626d7d6f383e2d381f9d`.
The seed reader/printer reproduces the canonical payload exactly. The initial
validator is 15,042 bytes with SHA-256
`da07d1f6c17281f1c1e98757e07912b77209c59569f368b0f3c275f29e747880`.

On Node v24.19.0, Linux x64, the focused suite passes 7/7 in 142.121 ms.
It executes every opcode and records 14 nodes, depth 5, 14 source spans, 14
macro origins, one binder, three literal nodes, and zero literal bytes for the
reviewed numeric example. Thirty-two cloned fresh/warmed validations produce
byte-identical reports without mutating input.

The repository-wide `npm test` gate passes 350/350 web tests in
14,465,750.221 ms and 1/1 site-content test in 61.316 ms, with zero failures,
cancellations, skips, or todos. The reviewed golden corpus reports no expected
or cross-stage divergence before promotion of this slice.

The seeded `yalisp-core-ir-v1-graphs` property profile uses seed `0x49525631`,
256 cases, and generator depth 6. It covers `const=660`, `ref=681`, `set=297`,
`define=297`, `if=304`, `lambda=288`, `call=307`, and `begin=291`; the largest
case has 70 IR nodes. Each valid graph survives deterministic clone/serialization
comparison, and each root-tail mutation reports the same earliest path. The
aggregate canonical hash is
`c7e849d3916c957c1f2d8a6c43209cdd11c432ea6d1d750aa28db2087cebc342`.

Exact cap witnesses cover 14/13 nodes, depth 5/4, three/two literal nodes,
three/two UTF-8 literal bytes, the exact source-unit byte length, one/two
origins, and both node and literal cycles. Reviewed malformed cases also cover
program shape, opcode, node arity, tail placement, source range/origin shape,
unbound locals, duplicate binder IDs, nonportable host objects, malformed
symbols, out-of-range literal values, and out-of-range structural integers.
Validation returns the first deterministic `{code, path, detail}` and never
partially charges a refused literal.

The artifact inventory and conformance runner now include and build-protect the
IR fixture and validator. The runner's inherited non-regression floor advances
from the historical 284 cases, through M3's 343, to this slice's fully green
350 web cases. The next M4 gap is deterministic lowering from macro-
expanded source into this representation, followed by reference execution and
golden observation parity.
