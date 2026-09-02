# YaLisp hardening control plane

This directory is the durable control plane for continuous YaLisp hardening.
It deliberately separates facts demonstrated by the current implementation from
the language contract and from planned work. A green test suite is evidence for
only the behavior it measures; it is never treated as proof that an unimplemented
stage, collector, compiler feature, or portability target exists.

The controlling artifacts are:

- [LANGUAGE_SEMANTICS.md](LANGUAGE_SEMANTICS.md) — normative semantics and
  invariants, with current implementation gaps called out explicitly.
- [BOOTSTRAP_MAP.md](BOOTSTRAP_MAP.md) — staged self-hosting map, trust
  boundaries, dependency graph, and seed-size evidence.
- [ROADMAP.md](ROADMAP.md) — one-at-a-time milestones and measurable exits.
- [HARNESS.md](HARNESS.md) — deterministic conformance, differential,
  performance, memory, and soak protocol.
- [SCORECARD.md](SCORECARD.md) — living status by independent quality axis.
- `baselines/` — immutable dated observations. A replacement baseline must
  explain the implementation change and measurement conditions; it never
  silently overwrites history.

The non-green discovery run remains in
`baselines/2026-09-01-m0-candidate.md`; the fully green M0 exit is recorded in
`baselines/2026-09-01-m0-promotion.md`. M1's golden differential is recorded in
`baselines/2026-09-01-m1-golden.md`; M2's six atomic slices end at
`baselines/2026-09-01-m2-source-forms.md`. M3 is active; its typed-error slices
are `baselines/2026-09-01-m3-typed-unbound-error.md` and
`baselines/2026-09-01-m3-error-category-table.md`; deliberate arithmetic traps
are recorded in `baselines/2026-09-01-m3-arithmetic-errors.md`, and post-failure
state evidence in `baselines/2026-09-01-m3-error-transactionality.md`.
Host recovery policy is recorded in
`baselines/2026-09-01-m3-host-recovery.md`.

## Operating invariant

Only one writer and one active milestone may exist in this checkout. Before a
milestone starts, inspect live processes/tasks and `git status`; preserve all
unrelated dirty work. Establish a deterministic failure or missing metric where
practical, change the smallest relevant surface, validate correctness before
optimization, then update these artifacts. Commit only an atomic green
milestone. Never improve a score by reducing coverage, weakening assertions,
special-casing a benchmark, copying an expected result, or hiding a divergence.

## Status vocabulary

- **specified**: the intended stable language contract is written here.
- **implemented**: reachable in checked-in production source.
- **conformant**: covered by deterministic conformance evidence.
- **measured**: has a reproducible dated result and machine metadata.
- **absent**: intentionally recorded as not implemented, not inferred from a
  passing unrelated test.
