# M3 host recovery policy — 2026-09-01

This immutable observation records the fifth atomic M3 slice. It turns the
transactionality evidence into an enforced Node/browser recovery policy and
updates the reviewed golden error observation. It changes no seed bytes.

## Deterministic failure before implementation

The structured boundary expected an unbound-name error to retain a definition
and report `recoverable: true`. It instead reported `false` and
`sessionDiscarded: true`. Conversely, the Node wrapper did not enforce its
discard declaration after resource exhaustion; callers still held a callable
object.

## Recovery contract

Codes 1–7 and 9 are recoverable because their reader/evaluator/mutation
boundaries are transactionally evidenced. `SeedLanguageError` reports
`recoverable: true` and `sessionDiscarded: false`, and the same session retains
its definitions. The browser REPL presents the diagnostic without replacing the
session.

Resource exhaustion (8), host contract (10), and unclassified raw faults are
unsafe to reuse. Their wrapper becomes invalid immediately; every later call
throws `SeedSessionDiscardedError`. Host input validation still occurs before a
Wasm invocation.

The deterministic control defines `m3.saved = 41`, catches an unbound error,
and evaluates `(+ m3.saved 1)` to `42` in the same session. A separate session
hits `memory limit reached`, then proves the next evaluation is rejected by the
wrapper.

## Golden evidence

The reviewed `unbound-error` observation changes only `recoverable` from false
to true. The corpus remains 15 cases, 17 events, 30 applicable stage
observations, and 15 explicit not-applicable observations. Its new SHA-256 is
`8aa06e80b2f73504c39e62e041ed822bd25415f390f11a0e7848be753d17f944`;
seed and bootstrap agree and there is no earliest divergence.

## Validation and disposition

The expanded structured boundary passes 5/5 and the combined focused set passes
53/53. Typecheck, production build, and golden differential are green. The seed
remains 11,078 bytes with WAT hash
`82db6ab1cbe20d76f694736b99ba36d87a1b7cd8ae1d0b031412f719f4002961`
and Wasm hash
`6fb7036ebd07d1645a794e9a219e3bdb72d25b60c390abc62ccbf45f2c617731`.

M3's host-distinction exit is now met. M3 remains active for complete
primitive/special-form arity and payload data plus explicit proof that the
compiler's jointly supported error intersection is empty or equivalent.
