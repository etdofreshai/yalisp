# YaLisp bootstrap and self-hosting map

Status: measured initial map, 2026-08-30.

## Current dependency graph

```text
host Node/browser + WebAssembly engine
            |
            | assemble (build-time WABT)
            v
bootstrap.wat -------------------------> seed.wasm
            |                               |
            | defines reader/eval/apply     | instantiate
            v                               v
         seed-only session ----load----> boot.lisp
                                            |
                                            v
                                  bootstrapped interpreter
                                            |
                                            | load
                                            v
                                      compiler.lisp
                                            |
                                            | emits WAT function payload
                                            v
                                      host WABT assembler
                                            |
                                            v
                                narrow standalone AOT Wasm
```

No arrow in this diagram is implied to be self-hosted. In particular, the host
currently supplies file loading, WAT assembly, WebAssembly instantiation, input
copying, and output collection.

## Stages and trust boundaries

### S0 — host and build tools

Trusted components: Node.js, the WebAssembly engine, npm dependency resolution,
and WABT. The host provides two effect imports and directly copies input and
asset bytes into exported memory. Reproducibility requires pinned source bytes,
the same WABT semantics, and byte comparison of the generated module.

Exit toward a smaller trust base: record exact tool versions; build twice in
clean environments; compare hashes; add at least one independent Wasm validator
or engine; eliminate host policy from evaluation semantics.

### S1 — assembly seed

Source: `apps/web/src/seed/bootstrap.wat`.

Responsibilities: tagged object model, bump allocation, symbol interning,
reader, canonical runtime objects, lexical environments, mutation, eval/apply,
macro application, primitive dispatch, printing, explicit heap/asset capacity,
and the minimal host ABI.

Measured evidence at the audited working tree:

| Artifact | Bytes | SHA-256 |
| --- | ---: | --- |
| `bootstrap.wat` | 107,481 | `17f54962225b580f696c3b441c2bdce83d04548c6750f29a7a321f164a455320` |
| generated `seed.wasm` | 10,992 | `17305d3674ef1b066c2dd10f8fad01767336cc188e678932dc684acd2b22aa3c` |

The binary contains 100 defined functions plus two function imports and ten
functional exports (memory is also exported). WABT's unfolded disassembly has
4,520 static instruction lines under the harness counting rule: numeric,
local/global, memory, call, branch, control, return/drop, and trap operators,
including structural `else`/`end`. This is a reproducible static code-size
metric, not a dynamic instruction count.

Current purity gaps: the source is WAT rather than a documented target-specific
assembly seed; reader, printer, allocator, a broad primitive set, and host asset
policy all live in the same binary; there is no collector; errors trap; the host
still assembles and instantiates the module.

### S2 — Lisp bootstrap

Source: `apps/web/public/yalisp/boot.lisp`.

Measured size: 4,486 bytes; SHA-256
`ac6f82a8a5709181eaf56fc62ecc2311b84f9672940a24e6ccd149d091382dd2`.

Responsibilities: `cond`, `when`, `unless`, `and`, `or`, `defn`, `do`, `let`,
structural equality, and basic list/higher-order functions. It is evaluated by
S1 and therefore demonstrates code-as-data macro construction, but does not yet
replace S1's evaluator or reader.

### S3 — Lisp compiler prototype

Source: `apps/web/public/yalisp/compiler.lisp`.

Measured size: 2,575 bytes; SHA-256
`9d708e880b8cfe03c8214942d250051e19aec09e7655b2e5290e12a9553cadec`.

It accepts exactly one distinct parameter, one body form, integer literals and
the parameter, and nested binary `+`, `-`, and `*`. It emits a WAT function
payload. A host WABT call still assembles that payload. The checked-in example
module is 43 bytes with SHA-256
`105c061efadfcdc5742c533bc9fe0c7297b7b5411b98b624885e3cc8436068ff`.

This stage does not compile general YaLisp, share interpreter state, deoptimize,
or bootstrap itself. Calling it a JIT or self-hosted compiler would be false.

## Target stages

### S4 — explicit core IR and general compiler

Introduce a documented, data-representable core IR after deterministic macro
expansion. The interpreter can execute this IR and the compiler can lower it,
making the first differential boundary explicit. Required evidence includes IR
validation, round trips where applicable, source maps, environment-cell ABI,
and corpus-wide observation equivalence.

### S5 — shared-state tiering

Add incremental compilation, generation-keyed caches, safe points,
invalidation, deoptimization, debugging, and rollback. Interpreted and compiled
calls operate on the same binding cells and object heap. The hot-switch corpus
must alternate modes inside long-lived sessions and compare state hashes after
every switch.

### S6 — managed runtime

Add a collector whose root map includes global environments, active interpreter
and compiled frames, compiler metadata, asset handles, host handles, and
in-flight foreign calls. High-level programs require no manual release.
Non-moving or pinned regions remain an explicit low-level facility. Prove live
object preservation, unreachable reclamation, pause distributions, throughput,
fragmentation, leak slope, and multi-hour soak stability.

### S7 — self-hosted evaluator/compiler/runtime libraries

Move policy and high-level mechanisms from the seed into inspectable YaLisp in
small verified steps. Each move requires differential equality across the old
and new stage plus a smaller audited seed. Keep the prior stage available as an
oracle until the next stage is independently reproducible.

### S8 — minimal assembly apply/eval seed

The terminal seed is documented assembly with a minimal object/ABI substrate
and a pure, inspectable apply/eval loop. Its dependency graph, source and binary
hashes, static and representative dynamic instruction counts, and audited host
imports are checked in. “Minimal” is measured against functionality moved to
self-hosted layers, not achieved by deleting assertions or hiding work in the
host.

## Bootstrap reduction ledger

Every reduction milestone records:

- bytes and static instructions removed from the seed;
- bytes/instructions added to self-hosted layers;
- changed trust dependencies and host imports;
- golden-corpus parity, earliest-divergence result, and build hashes;
- cold-start and steady-state effect;
- memory/allocation impact;
- the source-level replacement for every removed seed responsibility.

The seed may grow temporarily when a measurable invariant such as GC safety or
deoptimization requires it. The scorecard must show the tradeoff explicitly.
