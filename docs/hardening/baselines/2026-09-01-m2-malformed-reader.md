# M2 malformed reader boundary — 2026-09-01

This immutable observation records the fourth atomic M2 slice. It moves
malformed syntax checks to the independent reader export, fixes the earliest
silent acceptance, and preserves ordered prior output. It does not complete M2.

## Deterministic failures before implementation

Command:

```bash
node --test --test-concurrency=1 apps/web/tests/reader-printer-property.test.mjs
```

All 256 generated data round trips and fixed valid edges remained green. The
malformed group failed first because a top-level `)` was silently consumed as
EOF. Direct `read_print` probes also showed:

- `(1 . 2` was accepted as if closed;
- `(1 . 2 3)` printed `(1 . 2)` and then `3`;
- `(. 1)` was accepted as `1`;
- `(1 .)` produced an EOF sentinel as data;
- quote, quasiquote, unquote, and unquote-splicing without operands wrapped the
  EOF sentinel;
- `(1 2))` silently discarded the trailing close.

Evaluating those sources produced secondary apply, stack, memory, or unbound
failures. Those downstream symptoms were rejected as reader evidence.

## Reader contract and result

The shared Node harness now exposes the existing `read_print` export as `read`,
so tests observe parsing without evaluation. Twelve malformed cases cover:

- unterminated string and ordinary list, retaining their specific diagnostics;
- unmatched and trailing closing parentheses;
- leading, missing, unterminated, and overfull dotted tails;
- operand-less quote, quasiquote, unquote, and unquote-splicing prefixes.

The new generic category is `read error`. Valid `(1 . 2)` remains exactly
`(1 . 2)`. For `(1 2))`, the complete first form is already an observable text
effect, so the stable diagnostic stream is `(1 2)\nread error`; the correction
does not erase prior output to simplify error handling.

## Artifact evidence

| Artifact | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `bootstrap.wat` bytes | 100,979 | 101,686 | +707 |
| generated `seed.wasm` bytes | 10,393 | 10,465 | +72 |
| defined seed functions | 92 | 93 | +1 |
| unfolded static instruction lines | 4,237 | 4,264 | +27 |

- WAT SHA-256:
  `01b8ef483af1e5d7360f7e51bf401c49be2f334060eb7951ce4bdd2514f9bb10`.
- Generated seed SHA-256:
  `139e4d87328197138676818b516effc92e22d3f979bc7daeb3f7b496cf322bb6`.
- Boot library, compiler source, and 43-byte AOT example hashes are unchanged.
- A fresh pinned WABT compilation is byte-identical to the generated seed.

## Validation

The following checks passed after implementation:

- reader/printer property: 4/4 groups, including 256 generated data cases and
  all 12 malformed fixtures;
- combined reader, macro, cap, seed runtime, reproducibility, and golden focused
  set: 38/38;
- `npm run typecheck`;
- `npm run build`;
- `npm run hardening:golden`: 15 cases, 17 events, 30 applicable stage
  observations, 15 explicit not-applicable observations, and no earliest
  divergence, corpus SHA-256 `e50cfe934df8f48b7c20566ce4ef6d5161b94eb730ad3f9ae66855abf71b7f7d`;
- artifact inventory: 93 defined functions, nine functional exports, and 4,264
  static instruction lines.

The production build retains its pre-existing browser-externalization and
large-chunk warnings; neither is introduced by this reader correction.

## Disposition

M2 remains active. The next smallest semantic gap is nested quasiquote/unquote-
splicing depth and malformed splice behavior, followed by broader generated
source-form parse/print/parse idempotence. Malformed dotted and closing syntax
now fails at the reader boundary rather than through evaluation side effects.
