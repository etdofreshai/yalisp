# M0 sequential promotion — 2026-09-01

This immutable observation closes M0. It records the first fully green,
sequential promotion after hierarchical TAP accounting, map-cache ownership,
and source-provenance corrections.

## Frozen identity

- Checkout: `/home/etgarcia/.repos/yalisp`, branch `main`.
- Frozen HEAD: `4182770bd116bb1d114c4d0363749c3a081162a0`.
- Ahead of `origin/main`: 18 inherited commits; no commit or dirty file was
  discarded.
- Runner schema: `yalisp-conformance-shards-v2`.
- Identity SHA-256:
  `bc3b6bb42a5850c1ab478d13d1b795650a617f7b9dc0d6239559670ec0b05d2a`.
- External manifest:
  `/home/etgarcia/.local/state/yalisp-hardening/conformance/2026-09-01T10-17-47.311Z-bc3b6bb42a58/manifest.json`.
- Started: `2026-09-01T10:17:47.312Z`; finished:
  `2026-09-01T20:06:30.389Z`.
- Machine/toolchain: `etzgt103`, AMD Ryzen 7 6800H, 16 logical CPUs, Linux
  x86_64 kernel 7.0.0-30, Node v24.19.0, npm 11.17.0.

## Result

Promotion mode completed all 35 lexicographically ordered shards in fresh,
sequential Node processes:

| Metric | Result |
| --- | ---: |
| hierarchical cases | 301 |
| pass | 301 |
| fail / skipped / cancelled / todo | 0 / 0 / 0 / 0 |
| complete shards | 35 / 35 |
| abnormal processes / policy violations | 0 / 0 |
| inherited coverage floor | 284 |
| added cases / removed cases | 17 / 0 |
| aggregate duration | 35,321,153.165 ms |

The host was under unrelated load. Duration is conformance traceability only;
it is not a publishable performance result and makes no speed claim.

## Controlling evidence

- Seed and generated artifacts rebuilt without tracked-content drift:
  `seed.wasm` 9,734 bytes, AOT example 43 bytes.
- The formerly divergent loaded-map actor case and the complete 21-case actor
  shard passed. The two returned 8,192-byte map planes retain 20,808 bytes,
  below the unchanged 32,768-byte ownership ceiling.
- The exact 240 MiB long replay gates passed with self-neutral heap probes and
  balanced transient release assertions.
- The 120-step live circuit retained 152,640 bytes with 1,272-byte maximum
  step growth; the repeated-render gate retained 21,312 bytes.
- Actorhash and door projection passed all 401 canonical records, three fresh
  byte-identical evaluators, and independent first-divergence controls.
- Mirror and promotion provenance gates passed with the corrected `id-ca.lisp`
  predecessor, byte count, source hash, and 23-module manifest hash.
- Reader/error/resource-cap, compiler subset, ABI boundary, audio, renderer,
  texture/palette, status, map, and world-hash suites all passed without a
  retry, skip, weakened assertion, or changed input.

## Disposition

M0 is complete. The next smallest evidence gap is M1: a declarative golden
observation corpus and a runner that records values, ordered effects, errors,
named state probes/hashes, explicit stage applicability, and the earliest
cross-stage divergence.
