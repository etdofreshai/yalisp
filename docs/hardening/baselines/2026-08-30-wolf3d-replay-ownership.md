# Wolf3D long-replay ownership evidence — 2026-08-30

This result closes the inherited R1 replay heap-exhaustion false positive
without changing canonical route inputs or expected state. It is bounded arena
evidence for one real application workload, not a claim of garbage collection
or general high-level memory safety.

## Scope and artifact identity

- Machine and toolchain: the initial 2026-08-30 baseline host and versions.
- Linear-memory cap: exactly 251,658,240 bytes (240 MiB).
- Source-manifest SHA-256:
  `becd367dbc351cdc49f727ae9a57db2bb7b3a436b9a5e0125fd05677c34f897c`.
- `app.lisp` SHA-256:
  `28f25c0167ec572e17af2488a625e52719e6965efc85648dad371211163195b7`.
- `wl-act2.lisp` SHA-256:
  `6ac724b388f0358d24ce31c61c3124f3dd10b599b5efeffedb15d1b3767011d2`.
- `wl-game.lisp` SHA-256:
  `541cce2030da22c45bae0bf41d1cb9c2fbc71dab52b96bc042deca377ccfde73`.
- `wl-sound.lisp` SHA-256:
  `6b2f01b4c9f1a35e7eb33683d5a9b7144116ddea0c4ec9f9a11dcdf425a3dafe`.

## Ownership model exercised

- A replay tick remains persistent and decodes the packed fixture buttons
  before applying gameplay mutation.
- Each 44-field trace is a transient host export. The harness takes a clean
  mark, copies/parses the result, measures the transient peak, releases to the
  exact mark, and verifies the post-release mark.
- `(heap.used)` observations undo their own pinned 12-byte seed allocation.
- Actor and static traversal scratch is released only when counters prove that
  no persistent audio or decision-log row escaped the scope.
- High-volume audio operation, native-payload, AdLib-register, and
  music-register histories use fixed mutable stores; their exported list
  projections remain transient.
- Renderer and dirty-plane hash scratch is released after all mutations have
  crossed into preallocated bytes or scalar globals.

No expected trace row is copied into the implementation, no assertion is
removed, and no synthetic loop substitutes for the real mounted E1M1 route.

## Deterministic controls

All controls used the same record-383 test and canonical fixture. Wall times
are included only to identify the runs; the host was loaded and these values do
not satisfy the performance protocol.

| Variant | Result | Wall time | Diagnostic |
| --- | --- | ---: | --- |
| Actor scratch guard plus reserve | fail | 726.062 s | `heap exhausted` |
| Packed audio stores plus actor/static bounds | fail | 1,088.471 s | `heap exhausted` |
| Add renderer and plane-hash bounds | pass | 1,120.678 s | exact record-103, 382, and 383 state assertions |

The record-148 door gate also passed under the exact cap before the final
renderer/plane additions, establishing that the earlier record-148 aggregate
failure was a resource false positive rather than a semantic divergence.

## Full 401-row result

Command:

```bash
cd /home/etgarcia/.repos/yalisp/apps/web
node --test \
  --test-name-pattern='all 401 canonical R1 actorhash records match and a changed hash fails closed' \
  tests/wolf3d-actorhash.test.mjs
```

Result: **pass**, 401/401 canonical actor hashes equal, and the deliberate
changed-hash negative control localized index 99.

| Metric | Bytes |
| --- | ---: |
| Fixed linear memory | 251,658,240 |
| Clean heap before row 1 | 37,717,448 |
| Clean heap after row 401 | 90,835,784 |
| Maximum transient heap use | 90,889,984 |
| Minimum headroom | 160,637,184 |
| Persistent clean-heap growth | 53,118,336 |
| Maximum trace-export increment over final clean use | 54,200 |

The test took 1,607.921 seconds under concurrent audit load. That duration is
not a benchmark result: it has no quiet-host gate, warmup protocol, repeated
samples, percentiles, or variance analysis.

## Focused validation

- replay ownership/helper unit tests: 4 pass;
- record-148 door/actor boundary: pass;
- record-383 diagonal boundary: pass;
- full 401-row actor-hash projection and negative control: pass;
- source-promotion manifest and provenance: 4 pass;
- browser audio-host boundary: 6 pass;
- repository typecheck: pass;
- whitespace/error check: pass.

## Fixed-concurrency integration attempt

The complete 284-case manifest was rerun with Node file concurrency fixed at
four. The process stayed within the host's memory envelope and continuously
executed for approximately 3.5 hours. It received external `SIGTERM` while the
last `wolf3d-door-replay` negative-control test was still computing. There was
no kernel or user-journal OOM record, more than 16 GiB remained available near
termination, and the worker had accumulated CPU time at essentially its full
wall time. This attempt is therefore **incomplete**, not a pass or assertion
failure, and has no final aggregate TAP counts.

Valid per-test observations emitted before termination include:

- records 148, 215, 294, 348, 366, and 383: pass;
- the guard-shoot positive route and its area/line negative controls: pass;
- the full 401-row actor-hash route and changed-hash localization: pass with
  the exact 240 MiB/headroom diagnostic above;
- retained pickup, pushwall boundary/collision/use controls, and ammo cap:
  pass;
- canonical door projection through record 117 and the full 401-row route:
  pass;
- three fresh evaluators produced byte-identical full-route projections:
  pass;
- three application assertions still failed: long-circuit collision, indexed
  frame shape, and frame-allocation reclamation.

The final door negative-control case did not finish, and ordered output for
later files was not released before termination. No conclusion is promoted for
those buffered files. The next controlling action is a focused reproduction of
the earliest emitted application failure, followed by a fresh complete run
after focused corrections. The inherited 263/284 result remains the only
complete aggregate baseline until then.

## Live application and static-storage follow-up — 2026-08-31

This append-only follow-up records later focused results. It does not rewrite
the artifact identity or conclusions of the 2026-08-30 replay run above, and
loaded-host wall times remain traceability rather than benchmark baselines.

The live application path now uses bounded packed audio decision stores and
releases a top-level tick region only when no heap-owned escape owner changed.
The renderer draws into pre-mark frame/fizzle storage and releases its scratch
region. With allocation-neutral heap observation, focused results were:

| Gate | Result | Deterministic memory evidence |
| --- | --- | --- |
| 120-step collision circuit | pass | 152,640 bytes total retained; 1,272-byte maximum step growth |
| 63 held-use door advances | pass | 63 releases, 0 retains, retain mask 0; 65 SD and 65 WL decision rows |
| 12 tick/render cycles | pass | 21,312 bytes retained; below the 65,536-byte gate |
| complete `wolf3d-application.test.mjs` | 11/11 pass | 2,965.647 s loaded-host duration |

Replay helper semantics remained green: four replay unit tests passed, the
canonical world-hash replay side-read/mutation/restore gate passed, and the
repository typecheck passed. The current `app.lisp` is 124,047 bytes with
SHA-256 `c9855c4f1c00013f02cefc0713479794402a0633176088d6abc6d28f85504b65`;
the current `wl-sound.lisp` is 55,553 bytes with SHA-256
`508afe6fce4ecc3277764fd850c16395a5ee9922856b4d581b0360fccdd8a9cf`.

The source C `InitStaticList` only rewinds `laststatobj`; it does not clear the
`statobjlist` backing rows. `SpawnStatic` then intentionally leaves
`itemnumber` untouched for dressing and blocking entries. Before correction,
the focused YaLisp regression deterministically failed after 241.750 s because
the reused row held 0 rather than the seeded value 12. Removing only the five
backing-store clears while retaining `staticcount = 0` produced:

- the unchanged focused regression: pass in 229.425 s;
- complete `wolf3d-static.test.mjs`: 4/4 pass in 696.570 s;
- repository typecheck: pass.

The corrected `wl-game.lisp` is 47,679 bytes with SHA-256
`8c699d1f027bcbed6dffe77a1b98c24cc5140194c47d97ba92056be8fecbf1e1`.
Its explicit verified predecessor is source-history blob
`a3c60810ae0c59ec4e59180d64e45c43ca300521` from commit `e054ab20`,
47,885 bytes with the prior SHA-256
`541cce2030da22c45bae0bf41d1cb9c2fbc71dab52b96bc042deca377ccfde73`.
The resulting sorted 23-module promotion-manifest SHA-256 is
`47066d293248c81ea4dd14ed02600a41d646cdd02be1bec7449382c8c961d9b6`.
No expected row was copied into the implementation, and no assertion or
resource cap was weakened.

A fresh standalone full-route door negative-control rerun wrote durable TAP to
external state and completed under the exact cap: 1/1 pass, 0 fail, 0 skipped,
and 0 cancelled. The test took 4,911,062.192 ms; aggregate process duration was
4,911,182.384 ms (81m51.182s). It proved that independent perturbations still
localize the intended first divergent field for control input, use input, RNG,
health, ammo, and plane-0 hash observations. The durable TAP artifact is
`/tmp/yalisp-door-negative-20260831T123845Z.tap`; it remains external evidence,
not a tracked repository artifact. A complete sequential aggregate is still
required before M0 promotes a new complete-suite baseline.

### Palette-oracle correction

The production palette decoder already expanded each 6-bit VGA DAC channel
with high-bit replication, `(dac << 2) | (dac >> 4)`, so 63 maps to the full
8-bit value 255. The independent texture test instead used only `dac << 2`,
expected a maximum of 252, and required every host channel to be divisible by
four. Its focused failure was deterministic after 227.177 s: for example the
runtime produced `#0000aa` where the stale oracle expected `#0000a8`, and
`#ffffff` where it expected `#fcfcfc`.

The test oracle now validates every source byte is within 0..63, applies the
documented replication formula, requires black at palette index 0 and full
white at index 15, and proves at least one expanded channel populates the low
two host bits. Production Lisp was unchanged. Results:

- unchanged focused palette gate before correction: fail in 227.177 s;
- corrected focused gate: pass in 224.171 s;
- complete `wolf3d-texture.test.mjs`: 17/17 pass in 2,436.251 s.

Those wall times came from the loaded audit host and are conformance
traceability only. They do not satisfy the benchmark warmup, sampling,
percentile, quiet-host, or variance protocol.

### ThreeDRefresh order-oracle correction

Original `WL_DRAW.C` calls `DrawScaleds()` before `DrawPlayerWeapon()` in
`ThreeDRefresh`, and production `wl.render-three-d` already called
`wl.draw-scaleds` before `wl.draw-player-weapon`. The status-bar test instead
searched `wl-draw.lisp` for retired R1-only aliases. Both absent lookups
returned -1, so its order comparison failed even though the live frame/status
hash assertions passed. The unchanged focused test deterministically failed at
that final assertion after 237.207 s.

The test now requires both production calls to be present and compares their
source order directly. No production Lisp, expected pixel hash, repeated-frame
equality, status cache, or malformed-input assertion changed. Results:

- corrected focused refresh/status gate: pass in 254.430 s;
- complete `wolf3d-statusbar.test.mjs`: 9/9 pass in 338.319 s, including five
  malformed graphics-boundary controls and missing-asset fail-closed behavior.

These loaded-host durations are conformance traceability only and are not
promoted as performance measurements.

### Hermetic capacity and source-provenance correction

The final `wolf3d-remaining-status` case combined stable local gates with a
duplicate byte comparison against the mutable external source checkout. It
deterministically failed in 0.202 s because the external `wl-agent.lisp` had
advanced independently. Exact runnable payload identity is already pinned by
the promotion manifest, while `wolf3d-mirror.test.mjs` verifies every local
payload is either an exact Git blob in source history or declares a verified
predecessor blob.

The duplicate live-checkout comparison was removed. The test still enforces
the 130,048-byte evaluator input ceiling for all 23 modules and the exact
2,097,152-byte graphics heap reserve. The local `wl-game` hardening exposed a
real provenance gap at the dedicated gate, which was closed by pinning verified
predecessor blob `a3c60810ae0c59ec4e59180d64e45c43ca300521`; no provenance assertion
was removed or weakened. Results:

- focused capacity/reserve gate: pass in 0.111 s;
- source provenance plus promotion manifest: 4/4 pass in 0.184 s;
- complete `wolf3d-remaining-status.test.mjs`: 13/13 pass in 780.401 s,
  retaining exact chunks, five malformed-input controls, status order/hashes,
  partial-write/cache-commit behavior, and the 65,536-byte redraw-retention
  ceiling.

The external checkout remains a read-only provenance repository, not a mutable
test oracle. No application source or expected output was changed for this
correction.
