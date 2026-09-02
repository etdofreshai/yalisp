# M3 ordered effects and atomic failure — 2026-09-01

This immutable observation records the fourth atomic M3 slice. It establishes
post-failure state evidence for evaluation order, binding commit timing, and
block-memory atomicity. It changes no runtime code and does not make trapped
sessions supported for continued execution.

## Observation boundary

Production Node and browser hosts discard a trapped seed instance. The focused
conformance harness deliberately reuses one only as a low-level microscope: it
catches the native trap, records `error_kind`, then invokes the same instance to
inspect bindings and bytes. That inspection is evidence about the moment of
failure, not authorization for application-level recovery.

Command:

```bash
node --test --test-concurrency=1 apps/web/tests/error-transactionality.test.mjs
```

## Ordered effect evidence

- operator expression sets the counter to `1`, then fails unbound; no argument
  runs and the retained counter is `1`;
- the first argument sets `1`, the second fails unbound, and the third would set
  `3`; the retained counter is `1`;
- three division arguments set `1`, `2`, and `3` left-to-right before the
  primitive sees a zero divisor; the category is arithmetic and the retained
  counter is `3`.

The distinction is intentional: ordinary argument expressions finish before
primitive application begins, while operator and argument failures stop the
evaluation walk at their exact position.

## Commit and atomicity evidence

- failed `(set! target (/ 1 0))` leaves the previous value `11`;
- failed `(define target (/ 1 0))` leaves the previous value `22`;
- an out-of-range `bytes.fill` leaves `(7 7 7 7)` unchanged;
- an out-of-range `bytes.copy` leaves destination `(1 1 1 1)` unchanged;
- an out-of-range `bytes.fill-stride` leaves `(7 7 7 7)` unchanged.

Every block operation validates its complete range before its first write.

## Validation and disposition

The focused transactionality file passes 3/3 and the combined hardening set
passes 52/52. The seed remains 11,078 bytes with WAT hash
`82db6ab1cbe20d76f694736b99ba36d87a1b7cd8ae1d0b031412f719f4002961`
and Wasm hash
`6fb7036ebd07d1645a794e9a219e3bdb72d25b60c390abc62ccbf45f2c617731`.
The golden corpus reports no earliest divergence.

M3's prior-effect-order and documented atomic-operation exits are now met. M3
remains active for structured payload data, host recovery semantics, and error
equivalence across jointly supported interpreter/compiler cases.
