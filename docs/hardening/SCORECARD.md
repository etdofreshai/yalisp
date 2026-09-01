# YaLisp living hardening scorecard

Updated: 2026-09-01 M0 complete, active M1. Scale: 0 absent, 1 prototype, 2 bounded and
partly evidenced, 3 broadly conformant, 4 production-hardened, 5 independently
reproduced across supported targets. Scores are independent; speed cannot raise
a correctness score and a small binary cannot raise bootstrap purity if work is
hidden in the host.

| Axis | Score | Current evidence | Next exit gate |
| --- | ---: | --- | --- |
| Semantic correctness | 2 | Frozen M0 promotion accounts for 301/301 cases over 35/35 shards with no skip/cancellation; no full normative cross-stage corpus | M1 golden observations plus M2 reader/macro properties |
| Interpreter/compiler parity | 1 | Differential checks cover three arithmetic expressions and six inputs within a one-parameter subset | Corpus-driven stage runner and earliest-divergence report |
| Bootstrap purity | 2 | Checked-in WAT seed and YaLisp bootstrap with provenance and reproducible binary | Separate core IR/evaluator policy, then reduce audited seed with ledger |
| Performance | 1 | Cold precompiled setup diagnostic and single-shot feasibility measurements exist | Quiet-host warmups, raw samples, p50/p95/p99, variance/confidence gates |
| Memory / GC | 0 | Bump allocation and explicit arenas; exact 240 MiB replay plus live circuit/render gates and a 20,808-byte two-plane cache ownership gate are measured, but no collector exists | Automatic managed memory, root-map proofs, pause/throughput/leak/soak evidence |
| Code size / instructions | 2 | Seed and layers have byte/hash evidence; initial static seed instruction count recorded | Automated per-stage size/static count and representative dynamic counts |
| Portability | 1 | WebAssembly/Node/browser path on x86_64 Linux; no matrix | Two engines plus declared OS/architecture targets and deterministic builds |
| Developer ergonomics | 1 | Persistent REPL and macros; errors trap, no modules/debug tier switching | Structured errors, modules, live source/IR inspection, safe hot switching |
| Documentation | 2 | Extensive web docs and seed boundary notes; initial hierarchical hardening specs | Normative reference linked to conformance cases and cost tables per layer |
| Library completeness | 1 | Small boot list/control library and several real Lisp applications | Versioned standard-library surface, module packaging, broader high-level suites |

## Required metric ledger

| Metric family | Current status | Controlling evidence |
| --- | --- | --- |
| Values/effects/errors/output/state hash by stage | Partial values only; no general state hash | M1 |
| Earliest divergence | Not implemented | M1 |
| Reader/printer round trip | Fixed examples only | M2 |
| Macro expansion determinism | Indirect behavior tests only | M2 |
| IR/decompile invariants | No IR | M4 |
| Property/fuzz and malformed caps | Selected cap tests; no seeded property suite | M2 |
| Cold start / parse / expand / eval / compile | Partial cold setup; phases not fully separated | M1/M7 |
| Throughput and latency percentiles | Absent | M7 |
| Generated code bytes / instructions | One 43-byte AOT artifact; seed static count | M0/M7 |
| RSS / heap / allocations / live / retained / fragmentation | Fixed pages plus clean used/peak/headroom for replay, circuit/render retention, and 4,639,928 -> 20,808 byte map-cache ownership evidence; no object census or fragmentation metric | M0, then M6 |
| GC throughput / pause distribution / leak slope / soak | No collector | M6 |
| High-level no-manual-memory acceptance | Fails by design today | M6 |
| Hot switching / invalidation / debug / rollback | Absent | M5 |
| Seed size / graph / hash / auditability | Initial map complete | M0, then every M9 step |
| ABI/FFI | Minimal two-import Wasm boundary only | M8 |
| Deterministic builds | Seed byte identity tested on current toolchain | M8 cross-target expansion |
| Real application workloads | Hello/Pong/Breakout/Asteroids/Wolf3D tests | Preserve and integrate into M1/M7/M6 |

## Current first gap

M0 is complete. Frozen identity `bc3b6bb4...` passed all 301 hierarchical cases
and 35 shards with no skip, cancellation, retry, abnormal process, or policy
violation. The earliest cross-cutting gap is now the absence of a runner capable
of observing and localizing semantic divergence across stages; M1 is active,
not a compiler rewrite or speculative optimization.
