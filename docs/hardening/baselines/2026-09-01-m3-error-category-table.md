# M3 seed-owned error category table — 2026-09-01

This immutable observation records the second atomic M3 slice. It extends the
typed unbound-name prototype to every intentional diagnostic class currently
emitted by the seed and removes category inference from diagnostic text. It does
not complete transactional error semantics.

## Deterministic failures before implementation

The expanded structured boundary initially passed 2/4 groups. Reader and host-
ingest protocol controls remained native Wasm errors because only unbound names
had a code. The same was true for arity, type, apply, arithmetic range, bounds,
resource, and mutation failures.

Command:

```bash
node --test --test-concurrency=1 apps/web/tests/structured-error-boundary.test.mjs
```

## Stable category table

| Code | Category | Representative diagnostic |
| ---: | --- | --- |
| 0 | unclassified runtime fault | native out-of-bounds Wasm access |
| 1 | `unbound-name` | `unbound: m3.missing` |
| 2 | `reader` | `read error` |
| 3 | `arity` | `unquote expected` |
| 4 | `type` | `string expected` |
| 5 | `apply` | `cannot apply` |
| 6 | `arithmetic` | `value exceeds fixnum range` |
| 7 | `bounds` | `byte index out of range` |
| 8 | `resource-exhausted` | `memory limit reached` |
| 9 | `mutation` | `immutable byte buffer` |
| 10 | `host-contract` | `asset ingest protocol` |

The table is seed-owned and keyed by fixed audited diagnostic constants. Error
metadata resets at `init`, every text/binary evaluator entry, reader/expander
entry, and both asset-ingest entries. Node and browser mappings are identical.
The golden runner accepts typed `SeedLanguageError` metadata and maps every
other thrown value to `runtime-trap`; it performs no string category inference.

## Artifact evidence

| Artifact | Before | After | Delta |
| --- | ---: | ---: | ---: |
| `bootstrap.wat` bytes | 105,261 | 107,481 | +2,220 |
| generated `seed.wasm` bytes | 10,774 | 10,992 | +218 |
| defined seed functions | 98 | 100 | +2 |
| functional exports | 10 | 10 | 0 |
| unfolded static instruction lines | 4,408 | 4,520 | +112 |

- WAT SHA-256:
  `17f54962225b580f696c3b441c2bdce83d04548c6750f29a7a321f164a455320`.
- Generated seed SHA-256:
  `17305d3674ef1b066c2dd10f8fad01767336cc188e678932dc684acd2b22aa3c`.
- Boot library, compiler source, and 43-byte AOT example hashes are unchanged.

## Validation and disposition

The structured boundary passes 4/4 and the combined focused hardening set passes
47/47. A fresh pinned WABT compilation is byte-identical. The golden corpus
retains 15 cases, 17 events, 30 applicable observations, 15 explicit not-
applicable observations, and no earliest divergence.

M3 remains active. The next gap is deliberate division-by-zero classification
and useful category payload data, followed by prior-effect ordering, atomic
mutation failure, host recoverability, and interpreter/compiler error parity.
