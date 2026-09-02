# M2 quasiquote depth and splice boundary — 2026-09-01

This immutable observation records the fifth atomic M2 slice. It replaces the
seed's depth-blind quasiquote walk with explicit matching-depth semantics and
turns malformed splice behavior into deterministic diagnostics. It does not
complete M2.

## Deterministic failures before implementation

Command:

```bash
node --test --test-concurrency=1 apps/web/tests/quasiquote-depth.test.mjs
```

The initial result was 1/4 groups green. Proper and empty depth-one splices
already preserved order. The other three groups exposed:

- nested unquote evaluated too early: `(outer (quasiquote (inner 42)) 42)`;
- nested splice flattened too early;
- direct splice was returned as ordinary data;
- atom and dotted-list splice values were silently accepted or truncated;
- missing and extra unquote/splice operands were not rejected.

## Contract and result

The kernel quasiquote walker now carries explicit nesting depth. Nested
quasiquote increments it; unquote and preserved unquote-splicing decrement it;
only a depth-one unquote evaluates. A depth-one splice is legal only in list
element position, has exactly one operand, and evaluates to a proper list.

Four deterministic test groups cover nested unquote, nested/outer splice,
matching-depth double unquote, proper and empty splice order, direct-splice
rejection, atom/dotted-list rejection, and missing/extra operands. All 4/4 pass.

## Artifact evidence

| Artifact | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `bootstrap.wat` bytes | 101,686 | 104,737 | +3,051 |
| generated `seed.wasm` bytes | 10,465 | 10,746 | +281 |
| defined seed functions | 93 | 97 | +4 |
| unfolded static instruction lines | 4,264 | 4,405 | +141 |

- WAT SHA-256:
  `5ef3dfc21db4212815ace283ffeb62741382f98c351009c367dc83869550f406`.
- Generated seed SHA-256:
  `0cf39513da003aa4f56e28a71fd624286a6b2c426093f8a0d9866b104f300e09`.
- Boot library, compiler source, and 43-byte AOT example hashes are unchanged.
- A fresh pinned WABT compilation is byte-identical to the generated seed.

## Validation

The focused reader, macro, cap, quasiquote, seed runtime, reproducibility, and
golden set passed 42/42. The golden corpus remains 15 cases, 17 events, 30
applicable stage observations, 15 explicit not-applicable observations, and no
earliest divergence. Repository typecheck, production build, the golden command,
and diff validation are recorded by the milestone commit.

## Disposition

M2 remains active. The next smallest evidence-backed gap is deterministic
generated source-form parse/print/parse idempotence. Nested quasiquote and splice
failures now have explicit semantics and stable regression coverage.
