# M2 reader and expansion resource-cap slice — 2026-09-01

This immutable observation records the third atomic M2 slice. It turns four
implicit or missing boundaries into explicit deterministic caps with adjacent
passing/failing evidence and persisted minimal witnesses. It does not complete
M2.

## Deterministic failures before implementation

Command:

```bash
node --test --test-concurrency=1 apps/web/tests/resource-cap-properties.test.mjs
```

The initial result was 0/4:

- the Node test host accepted 130,049 bytes and overwrote one byte beyond the
  fixed source region;
- nested list depth 1,024 did not yield a named depth failure;
- 32,769 empty top-level forms had no explicit work failure;
- `(expand.forever)` reproduced until `heap exhausted`, not an expansion cap.

No input, assertion, or coverage was reduced to close these failures.

## Fixed accounting contract

| Resource | Passing boundary | First failure | Diagnostic |
| --- | ---: | ---: | --- |
| UTF-8 source bytes at shipped hosts | 130,048 | 130,049 | host `RangeError` before memory write |
| combined `read1`/list-spine frames | nested list depth 511 | nested list depth 512 | `depth cap` |
| reader form/list-spine work | 32,768 empty forms | 32,769 empty forms | `work cap` |
| named outer macro applications | 1,024 | 1,025 | `macro expansion cap` |

Every source submission resets its reader counters. A final whitespace/EOF
probe is byte-bounded but is not charged as a nonexistent form, making the
65,536-unit work budget inclusive. Both the browser runtime and shared Node
harness reject oversized source before copying it to the fixed WebAssembly
input region.

`binary-min-depth-v1` searches the nested-list boundary with fresh seed
instances. It persists depth 511 as passing and 512 as the minimal named failure,
and rejects an incidental host trap as invalid shrink evidence. The work fixture
has an exact two-unit accounting per empty form. The expansion witness is the
one-form self-reproducing named macro `(expand.forever)`; a separate finite
counted chain returns `complete` on exactly application 1,024, proving the full
allowed budget is usable before the failure boundary.

## Artifact evidence

| Artifact | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `bootstrap.wat` bytes | 97,928 | 100,979 | +3,051 |
| generated `seed.wasm` bytes | 10,093 | 10,393 | +300 |
| defined seed functions | 84 | 92 | +8 |
| unfolded static instruction lines | 4,136 | 4,237 | +101 |

- WAT SHA-256:
  `82ca9cedc0792d34e5ef5d10bc5c6f1517b7dfdb71951a69bc3bf6b08764d4c4`.
- Generated seed SHA-256:
  `17bec98ce1763c8e6f9786d99e8c575585a4586c600153ec2c4604b316318a73`.
- Boot library, compiler source, and 43-byte AOT example hashes are unchanged.
- A fresh pinned WABT compilation is byte-identical to the generated seed.

## Validation

The following checks passed after implementation:

- resource cap properties: 4/4;
- combined reader, macro, cap, seed runtime, reproducibility, and golden focused
  set: 38/38;
- `npm run typecheck`;
- `npm run build`;
- `npm run hardening:golden`: 15 cases, 17 events, 30 applicable stage
  observations, 15 explicit not-applicable observations, and no earliest
  divergence, corpus SHA-256 `e50cfe934df8f48b7c20566ce4ef6d5161b94eb730ad3f9ae66855abf71b7f7d`;
- artifact inventory: 92 defined functions, nine functional exports, and 4,237
  static instruction lines.

The production build retains its pre-existing browser-externalization and
large-chunk warnings; neither is introduced by these seed/host caps.

## Disposition

M2 remains active. The next smallest semantic gap is a broader malformed-source
corpus covering nested quasiquote/unquote-splicing and malformed dotted/closing
forms, followed by broader generated source-form idempotence. Reader and named
outer-expansion resource failures now have explicit bounded evidence rather
than incidental host-stack or heap exhaustion.
