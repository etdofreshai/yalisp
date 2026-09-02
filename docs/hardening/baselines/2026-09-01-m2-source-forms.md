# M2 generated source-form idempotence — 2026-09-01

This immutable observation records the sixth and final M2 slice and completes
M2. It adds a deterministic generated
source corpus without changing language semantics or weakening the distinction
between human-readable and canonical printing.

## Initial oracle divergence

The first run used the independent `read_print` export and failed generated case
0. A string such as `"say \"hi\" \\"` was printed as readable text without
canonical quotes; reparsing split it into symbols. This was not a reader defect:
the semantics already specify ordinary output as REPL-readable and DOM output as
canonical data transport.

The corrected oracle wraps each generated form in `quote`, sends it through
`eval_dom_print`, reparses that canonical output through the same quoted boundary
in an independent session, and compares the second print byte-for-byte. The form
is parsed but never evaluated.

## Deterministic corpus

Command:

```bash
node --test --test-concurrency=1 apps/web/tests/source-form-idempotence.test.mjs
```

Configuration:

- generator: `yalisp-source-forms-v1`;
- seed: `0x53524346` (`1397900102`);
- cases: 512;
- maximum depth: 5;
- shrink policy: `not-run-without-failure-v1`;
- minimal shrunk failure: `null`.

The green corpus records nonzero coverage for every required category:

| Category | Nodes/occurrences |
| --- | ---: |
| atoms | 732 |
| strings | 237 |
| proper lists | 185 |
| dotted lists | 185 |
| quote | 187 |
| quasiquote | 165 |
| unquote | 183 |
| unquote-splicing | 176 |
| comments | 359 |

Whitespace variants include spaces, tabs, LF, CRLF, and comments. All 512
canonical parse/print/parse observations are idempotent.

## M2 exit disposition

M2 now satisfies all declared exits:

- 256 generated acyclic data values plus fixed string/grammar edges;
- 512 generated source forms with persisted configuration and coverage;
- independent fresh/warmed macro-expansion hashes;
- explicit nested quasiquote and malformed splice semantics;
- 12 malformed reader cases;
- exact input, depth, work, and macro-expansion caps with minimized witnesses.

The combined focused hardening set is 43/43 and the M1 golden differential still
reports no earliest divergence. M3 structured errors and transactional failure
boundaries becomes the sole active milestone.
