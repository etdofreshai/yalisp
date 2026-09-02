# M3 deliberate arithmetic errors — 2026-09-01

This immutable observation records the third atomic M3 slice. It replaces the
seed's remaining raw zero-divisor traps and closes a tagged-fixnum division edge.
It does not complete M3 transactional semantics.

## Deterministic failures before implementation

Command:

```bash
node --test --test-concurrency=1 apps/web/tests/arithmetic-errors.test.mjs
```

Both groups failed initially:

- `(/ 10 0)` reached `i32.div_s` and produced an unclassified native Wasm trap;
- `(mod 10 0)` reached `i32.rem_s` with the same result;
- `(/ -1073741824 -1)` returned without error even though its mathematical
  result cannot be represented by the seed's 31-bit tagged fixnum.

## Contract and result

The unused memory interval `[32,64)` now holds `division by zero` and
`modulo by zero`; integer-format scratch remains `[0,32)`, and the fixed input
boundary is unchanged. Both divisor checks run before the Wasm arithmetic
instruction and report seed category `6`.

Division remains a signed left fold truncating toward zero. Its final value now
passes through the checked fixnum constructor. The minimum fixnum divided by
`-1` therefore reports `value exceeds fixnum range`; ordinary
`-1073741824 / 2` still yields `-536870912`.

## Artifact evidence

| Artifact | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `bootstrap.wat` bytes | 107,481 | 108,081 | +600 |
| generated `seed.wasm` bytes | 10,992 | 11,078 | +86 |
| defined seed functions | 100 | 100 | 0 |
| unfolded static instruction lines | 4,520 | 4,548 | +28 |

- WAT SHA-256:
  `82db6ab1cbe20d76f694736b99ba36d87a1b7cd8ae1d0b031412f719f4002961`.
- Generated seed SHA-256:
  `6fb7036ebd07d1645a794e9a219e3bdb72d25b60c390abc62ccbf45f2c617731`.
- Boot library, compiler source, and 43-byte AOT example hashes are unchanged.

## Validation and disposition

Arithmetic errors pass 2/2 and the combined focused hardening set passes 49/49.
A fresh pinned WABT compilation is byte-identical. The golden corpus retains 15
cases, 17 events, 30 applicable observations, 15 explicit not-applicable
observations, and no earliest divergence.

M3 remains active. The next gap is useful structured payload data, then exact
prior-effect order and atomic mutation behavior across failing operations.
