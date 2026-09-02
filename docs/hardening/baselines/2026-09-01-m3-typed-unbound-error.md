# M3 typed unbound-name error boundary — 2026-09-01

This immutable observation records the first atomic M3 slice. It gives one
intentional language failure seed-owned category metadata and proves that the
host no longer conflates that path with an accidental Wasm fault. It does not
complete the M3 taxonomy or make a trapped session resumable.

## Deterministic failures before implementation

Command:

```bash
node --test --test-concurrency=1 apps/web/tests/structured-error-boundary.test.mjs
```

Both groups failed. The shared Node harness exported neither a typed language
error nor a trap classifier, and the seed exported no category metadata. An
unbound name and an out-of-bounds Wasm access were both native
`WebAssembly.RuntimeError` instances; callers could distinguish them only by
parsing diagnostic text when text happened to exist.

## Contract and result

The seed now exports read-only `error_kind()`. Zero means that a trap did not
pass through a classified language-error helper. The unbound-name helper stores
code `1` before writing `unbound: <symbol>` and trapping.

Node and browser hosts map code `1` to a typed `SeedLanguageError` with:

- `categoryCode: 1`;
- `category: "unbound-name"`;
- the exact diagnostic;
- `recoverable: false`;
- `sessionDiscarded: true`;
- the native `WebAssembly.RuntimeError` as `cause`.

The raw-fault control invokes `eval_print` with an out-of-bounds source pointer.
It remains a native runtime error and leaves `error_kind()` at zero. The golden
runner consumes the typed category directly; it no longer recognizes unbound
errors by matching the `unbound:` prefix.

## Artifact evidence

| Artifact | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `bootstrap.wat` bytes | 104,737 | 105,261 | +524 |
| generated `seed.wasm` bytes | 10,746 | 10,774 | +28 |
| defined seed functions | 97 | 98 | +1 |
| functional exports | 9 | 10 | +1 |
| unfolded static instruction lines | 4,405 | 4,408 | +3 |

- WAT SHA-256:
  `95deb4180b7fa8ebfdd33f81b637b5a03bdceb11b2c1d236ade7c2c0011fc371`.
- Generated seed SHA-256:
  `ae8dc34690587b178f0930a79eac87361a0ea142f87cb3cc4ef7c8b0ead7f386`.
- Boot library, compiler source, and 43-byte AOT example hashes are unchanged.
- A fresh pinned WABT compilation is byte-identical to the generated seed.

## Validation and disposition

The structured boundary passes 2/2 and the combined focused hardening set passes
45/45. The M1 corpus retains 15 cases, 17 events, 30 applicable observations,
15 explicit not-applicable observations, and no earliest divergence.

M3 remains active. The next gap is to assign seed-owned categories to the
remaining reader, arity, type, apply, arithmetic, bounds, resource, mutation,
and host failures, then verify prior effects and atomic operations per category.
