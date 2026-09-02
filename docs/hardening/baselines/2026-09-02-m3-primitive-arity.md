# M3 primitive arity contract — 2026-09-02

This immutable observation records the sixth atomic M3 slice. It replaces
lenient missing/extra primitive operands with an explicit dispatch policy.

## Failure and correction

The initial exhaustive fixture failed immediately because fixed primitives
silently read missing operands as `nil` or ignored extras. After the first
implementation, the 55-test combined gate exposed the earliest regression in
the compiler stage: `string.append expected`. The compiler correctly uses
three- and seven-part concatenation; `string.append`/`string.concat` were
therefore restored as variadic. `string.slice`/`string.substring` were also
recorded as their implemented two-or-three-operand range rather than forced to
three.

## Contract

- all fixed primitives and aliases reject one-too-few and one-too-many;
- string slicing accepts two or three and rejects outside that interval;
- `+`, `-`, `*`, `/`, `list`, `string.append`, and `string.concat` are variadic;
- failures are recoverable category-3 records with `<called-name> expected`;
- a computed primitive uses `<primitive> expected`.

Command:

```bash
node --test --test-concurrency=1 apps/web/tests/primitive-arity.test.mjs
```

## Artifact evidence

| Artifact | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `bootstrap.wat` bytes | 108,081 | 113,023 | +4,942 |
| generated `seed.wasm` bytes | 11,078 | 11,673 | +595 |
| defined seed functions | 100 | 103 | +3 |
| unfolded static instruction lines | 4,548 | 4,898 | +350 |

- WAT SHA-256: `107811503fc4ada27a20589b7db11e24ea64e7be502075260cac47236b3e3494`.
- Wasm SHA-256: `54047410be958b7cd140f8ac60fcf1dd39aee06ec7b70cc2568356e9ca7dc61e`.
- Boot/compiler/AOT artifacts are unchanged.

The final focused set passes 56/56, fresh WABT output is byte-identical, and the
15-case golden corpus reports no earliest divergence. M3 remains active for
special-form and closure/macro arity, structured payload fields, and explicit
compiler error-intersection evidence.
