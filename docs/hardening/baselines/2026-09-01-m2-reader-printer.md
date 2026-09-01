# M2 reader/printer property slice — 2026-09-01

This immutable observation records the first atomic M2 slice. It establishes a
deterministic canonical reader/printer property, preserves the first failing
cases, corrects the smallest seed divergence, and revalidates the existing
golden observation boundary. It does not complete M2.

## Deterministic failure

Command:

```bash
node --test --test-concurrency=1 apps/web/tests/reader-printer-property.test.mjs
```

Before the correction, two of four test groups failed reproducibly:

1. Fixed `carriage return`: source contained raw byte `0x0d`, the canonical
   printer emitted `"left\\rright"`, and rereading produced `"leftrright"`.
2. Generated case 1: source contained raw control byte `0x04`, the printer
   emitted `\\u0004`, and rereading retained the literal characters `u0004`.

The reader decoded only `\\n` and `\\t`; the canonical printer also emitted
`\\r`, `\\b`, `\\f`, and lower-case `\\u00xx`. The correction adds those
canonical decodings, including validated hexadecimal nibbles, while preserving
the existing behavior for unknown escapes.

## Property definition and result

| Field | Value |
| --- | --- |
| generator | `yalisp-acyclic-data-v1` |
| seed | `0x59414c49` (`1497451593`) |
| generated cases | 256 |
| maximum generated depth | 4 |
| fixed canonical string cases | 9 |
| fixed grammar cases | 14 |
| stable malformed diagnostics | 2 |
| test groups | 4/4 pass |
| earliest remaining divergence | none in this property domain |

Generated values include nil, booleans, bounded integers, symbols, UTF-8 and
control-byte strings, proper lists, and dotted acyclic structures. Each case is
quoted, printed by the canonical DOM transport, reread in the same fresh seed
session, and required to print identically. Fixed cases cover delimiter escapes,
all canonical control escapes, Unicode, comments, numeric bounds, symbols, and
proper/dotted nesting. Malformed string and list inputs retain stable reader
diagnostics.

## Artifact evidence

| Artifact | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `bootstrap.wat` bytes | 93,616 | 96,029 | +2,413 |
| generated `seed.wasm` bytes | 9,734 | 9,935 | +201 |
| defined seed functions | 81 | 82 | +1 |
| unfolded static instruction lines | 3,952 | 4,066 | +114 |

- WAT SHA-256:
  `0a760e92fc6cabfd41d7652c374b918aa82452ad4f3ab72324f97d7473120e74`.
- Generated seed SHA-256:
  `7946e1ecefd3f9c90987e8d02d48fce3f706e74b3dcc213ba3a4cc55b6df20d7`.
- Boot library and 43-byte AOT example hashes are unchanged.
- A fresh pinned WABT compilation is byte-identical to the generated seed.

## Validation

The following checks passed after the correction:

- reader/printer property: 4/4 groups, including all 256 generated cases;
- seed runtime, precompiled/reproducibility, and golden focused tests: 27/27;
- `npm run typecheck`;
- `npm run build`;
- `npm run hardening:golden`: 15 cases, 17 events, 30 applicable stage
  observations, 15 explicit not-applicable observations, no earliest
  divergence, corpus SHA-256 `e50cfe934df8f48b7c20566ce4ef6d5161b94eb730ad3f9ae66855abf71b7f7d`;
- artifact inventory: 82 defined functions and 4,066 static instruction lines.

The production build retains its pre-existing browser-externalization and
large-chunk warnings; neither is introduced by this seed-only correction.

## Disposition

M2 remains active. The next smallest high-value gap is to expose macro
expansion independently from evaluation and prove identical canonical hashes
across repeated fresh and long-lived sessions. Persisted minimal shrinking,
broader generated source forms, and explicit malformed reader depth/work caps
also remain exit requirements.
