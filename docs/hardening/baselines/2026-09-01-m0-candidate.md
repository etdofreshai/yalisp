# M0 sequential promotion candidate — 2026-09-01

This append-only candidate records the first complete sequential promotion
after the conformance runner and map-cache ownership corrections. It is not a
green release baseline: two source-provenance pins were stale in the frozen
identity. Their focused correction is recorded below, and a fresh complete
promotion remains the M0 exit gate.

## Frozen identity and execution

- Checkout: `/home/etgarcia/.repos/yalisp`, branch `main`.
- HEAD: `4182770bd116bb1d114c4d0363749c3a081162a0`.
- Ahead of `origin/main`: 18 commits; all inherited dirty work preserved.
- Runner schema: `yalisp-conformance-shards-v2`.
- Identity SHA-256:
  `54597192994a7a4b2feb3318deb15a86a84920768c163c23035f63fb12819931`.
- External manifest:
  `/home/etgarcia/.local/state/yalisp-hardening/conformance/2026-09-01T00-15-29.304Z-54597192994a/manifest.json`.
- Ordering: 35 lexicographically sorted test files, one fresh Node process at
  a time, `--test-concurrency=1`, promotion mode (never fail-fast).
- Machine/toolchain: `etzgt103`, AMD Ryzen 7 6800H, 16 logical CPUs, Linux
  x86_64 kernel 7.0.0-30, Node v24.19.0, npm 11.17.0.

The run completed all 35 shards and 301 hierarchical tests in
35,897,823.373 ms: 299 pass, 2 fail, 0 skipped, and 0 cancelled. The duration
is loaded-host conformance traceability, not a performance baseline.

Both failures were release metadata, not runtime semantics:

- `wolf3d-mirror`: the locally hardened `id-ca.lisp` needed an explicit
  predecessor blob;
- `wolf3d-promotion`: the 23-module manifest still held the previous `id-ca`
  byte count and SHA-256.

All evaluator, application, replay, renderer, malformed-input, exact-cap, and
state-hash cases passed. The runner counted every nested negative control; no
shard was incomplete and coverage rose by 17 cases over the inherited
284-case floor.

## Hierarchical TAP correction

Runner v1 parsed only unindented result rows although Node's footer counts both
parent and nested tests. Seven fully green shards therefore looked incomplete.
Runner v2 retains top-level IDs unchanged, gives nested cases full stable
ordinal/name paths, compares renames by full ordinal path, and refuses v1
resume manifests.

Evidence:

- focused runner tests: 12/12 pass, including nested pass/failure ownership;
- the preceding frozen raw artifacts reparsed as 297 tests, 296 pass, 1 actor
  failure, 0 skipped/cancelled;
- the candidate promotion recorded all 301 current cases directly, including
  every nested ammo/face/health/status failure control.

## CA_CacheMap ownership correction

The sole semantic failure in the preceding frozen run was
`loaded-map scans own source kill, treasure, and secret totals`. The second map
decode trapped in the seed allocator's `ensure_space`. A minimal map-only
measurement showed that two 8,192-byte returned planes retained 4,639,928
bytes because Carmack scratch and recursive expander frames escaped the call.

`ca.cache-plane` now allocates the returned destination before a heap mark,
allocates decompression scratch after the mark, completes both expansion
stages, and releases exactly to the mark before returning the destination.

| Evidence | Before | After |
| --- | ---: | ---: |
| two returned plane payloads | 16,384 B | 16,384 B |
| observed retained heap | 4,639,928 B | 20,808 B |
| focused ownership gate | fail | pass |
| independent map corpus | not rerun | 10/10 pass |
| former actor divergence | `RuntimeError: unreachable` | pass in 276,664.964 ms |
| complete actor shard | 20/21 pass | 21/21 pass in 9,123,598.903 ms |

The 32,768-byte ownership ceiling is more than the plane payload and block/list
metadata but far below the decompression scratch footprint. No memory cap,
expected tile, state total, error assertion, or route input was changed.

## Application memory and differential evidence

- 120-step live collision circuit: 152,640 bytes retained; 1,272-byte maximum
  step growth under 62,193,664 bytes of linear memory.
- 12 live render cycles: the existing 21,312-byte retained gate remained
  green.
- 63 held-use door advances: 63 releases, 0 retains, retain mask 0; 65 SD and
  65 WL decision rows.
- actorhash: 5/5 pass, including all 401 canonical records and changed-hash
  localization.
- door projection: 12/12 pass, including the 117-record prefix, full 401-row
  projection, three fresh byte-identical evaluators, and independent first-
  divergence controls for inputs and live state fields.
- worldhash: 2/2 pass, including mutate/restore sensitivity and promotion of
  both actorhash and worldhash.

This is bounded manual arena evidence, not garbage collection or proof that
ordinary high-level programs never need ownership management.

## Provenance correction after the frozen run

The prior promoted `id-ca.lisp` is 16,532 bytes with SHA-256
`84daf428abd1593e9b5c79c847737e6fbee5c2bac5ecc687c086d94d4c831a6c`.
It is verified source-history blob
`6ad8c55d3f4870acf7541c6bb0457c2c974c0ed8` from commit `9efe6841` in the
read-only source repository. The corrected payload is 16,879 bytes with
SHA-256
`d09967cc45c5707a8800db65a6f60d87ca142d1cbd10eb01566acb0011e67295`.
The recomputed sorted 23-module manifest SHA-256 is
`31181c032aaf435482121c07647751428eaf5919e5b2077d00188c6b1f34d371`.

After pinning those exact values, source provenance plus promotion-manifest
tests pass 4/4. A fresh complete 301-case promotion is required before M0 can
be marked complete or committed.

## Build and performance disposition

- `npm run typecheck`: pass.
- deterministic seed/AOT build: 9,734-byte `seed.wasm` and 43-byte AOT module.
- production Vite build: pass after restoring Rollup's matching 4.62.4 native
  optional payload without changing `package.json` or `package-lock.json`.

The candidate's wall times came from a continuously loaded conformance host.
They do not satisfy quiet-host warmups, repeated samples, percentile, or
variance gates and must not be used for optimization claims.
