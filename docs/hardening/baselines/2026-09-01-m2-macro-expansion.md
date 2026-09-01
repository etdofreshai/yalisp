# M2 macro-expansion determinism slice — 2026-09-01

This immutable observation records the second atomic M2 slice. It introduces a
canonical expansion boundary independent from evaluation, pins reviewed boot
macro expansions, and proves repeatability across fresh and long-lived
sessions. It does not complete M2.

## Deterministic missing boundary

Command:

```bash
node --test --test-concurrency=1 apps/web/tests/macro-expansion-determinism.test.mjs
```

Before implementation, all three test groups failed at the same boundary:
`createSeedSession()` had no `expandCanonical` method. Macro behavior could be
tested only through final evaluation, so expansion drift could not be observed
or hashed independently.

The implemented `expand_dom_print` export reads source forms, repeatedly
expands a macro bound to a named outer head in the global environment, and
prints the resulting data canonically. It never evaluates a computed operator
or the produced user form. Macro bodies still use the evaluator's existing
closure application and their captured lexical definition environment.

## Fixture and result

Fixture version: `yalisp-macro-expansion-v1`.

| Metric | Result |
| --- | ---: |
| authored boot macro cases | 8 |
| fresh sessions | 4 |
| long-lived corpus rounds | 16 |
| pinned corpus SHA-256 | `34214d55363aa0dc4a219434fffab85ab00cc10a9cc5e4b6842ddcbc61df6818` |
| custom macro repetitions | 16 |
| custom repetition SHA-256 | `457871727fca5559890b2a55b91fce9ea8d1107b3e66a7b92375dda0e3d83064` |
| test groups | 3/3 pass |

The authored cases cover `when`, `unless`, recursive-boundary `and`, the
single-evaluation/capture-avoidance shape of `or`, `defn`, `do`, `let`, and
outer `cond`. At first execution, the only expectation correction was reviewable
data: YaLisp canonically prints the empty list as `nil`, so the zero-argument
thunk inside `or` is `(lambda nil ...)`, not `(lambda () ...)`.

A long-lived two-macro chain expands through the first named macro into the
second, which produces two counter mutations. Its canonical expansion is
identical for all 16 calls, and the counter remains exactly zero afterward.
This separates expansion from evaluation rather than inferring that separation
from matching final values. Atoms, unknown operators, computed
operators, `quote`, `if`, and `lambda` remain unchanged by the outer inspection
contract.

## Artifact evidence

| Artifact | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `bootstrap.wat` bytes | 96,029 | 97,928 | +1,899 |
| generated `seed.wasm` bytes | 9,935 | 10,093 | +158 |
| defined seed functions | 82 | 84 | +2 |
| functional exports | 8 | 9 | +1 |
| unfolded static instruction lines | 4,066 | 4,136 | +70 |

- WAT SHA-256:
  `0f7b3a87fadfcfa5ca203f959b6cd55e95ccda8a23e65e038093e02f6ef8eefc`.
- Generated seed SHA-256:
  `ab767a39785bd249b73fe3cbfa14739b9a92cbd178d94eb0863d24c5ac917edb`.
- Boot library, compiler source, and 43-byte AOT example hashes are unchanged.
- A fresh pinned WABT compilation is byte-identical to the generated seed.

## Validation

The following checks passed after implementation:

- macro expansion determinism: 3/3 groups;
- seed runtime, precompiled/reproducibility, and golden focused set: combined
  30/30 including the macro groups;
- `npm run typecheck`;
- `npm run build`;
- `npm run hardening:golden`: 15 cases, 17 events, 30 applicable stage
  observations, 15 explicit not-applicable observations, and no earliest
  divergence, corpus SHA-256 `e50cfe934df8f48b7c20566ce4ef6d5161b94eb730ad3f9ae66855abf71b7f7d`;
- artifact inventory: 84 defined functions, nine functional exports, and 4,136
  static instruction lines.

The production build retains its pre-existing browser-externalization and
large-chunk warnings; neither is introduced by this seed/runtime inspection
boundary.

## Disposition

M2 remains active. Persisted shrinking, broader generated source forms, nested
quasiquote/splice cases, and explicit reader/expansion depth and work caps are
still required. The next smallest high-value gap is a deterministic malformed
depth/work corpus with a bounded failure contract.
