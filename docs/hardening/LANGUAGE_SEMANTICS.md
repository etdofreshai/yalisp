# YaLisp language semantics and invariants

Status: initial normative contract and implementation audit, 2026-08-30.

This document defines the behavior that every YaLisp execution engine must
share. Where the present seed is narrower, a **Current state** note records the
gap. Future implementations may add representations, optimizations, and
execution tiers, but may not silently change observable behavior.

## 1. Observational equivalence

For a program, initial module graph, input/event stream, resource caps, and host
capability set, every supported execution route must yield the same ordered
observation record:

1. returned values in canonical printed form;
2. writes to every declared effect channel, including text and byte output;
3. mutations visible through subsequent evaluation;
4. error category, diagnostic data, and point of failure;
5. deterministic state hash at each declared safe point.

The relevant routes are seed-only interpretation, bootstrapped interpretation,
incrementally compiled execution, AOT execution, and later self-hosting stages.
The differential harness reports the earliest record index that differs. A
faster route is not conformant if any of these observations differ.

Current state: seed and bootstrap interpretation exist. Compilation supports
only one-parameter integer expressions using binary `+`, `-`, and `*`; it has no
shared session state or hot-switch mechanism. Equivalence is therefore proven
only for the explicitly bounded compiler corpus. M1 records 15 reviewed cases,
17 events, and 30 applicable stage observations with no divergence; three cases
are in the compiler intersection and all unsupported stage slots are explicit.

## 2. Values and representation

The source language currently exposes:

- `nil`, `true`, and `false` as distinct singleton objects;
- fixnums;
- interned symbols;
- strings;
- mutable byte buffers and immutable host-ingested assets;
- pairs, including proper and dotted lists;
- closures, macros, and primitives.

The seed representation is an `i32`. Values with low bit one are fixnums and
decode by arithmetic shift right one. Other values are aligned pointers to
tagged heap objects. The exact tags and layouts are documented in
`apps/web/src/seed/bootstrap.wat`; they are an audited bootstrap ABI, not a
license for high-level code to depend on raw addresses.

Fixnums cover `[-2^30, 2^30-1]`. Arithmetic that cannot be represented must not
silently become a different YaLisp value. The present primitive operations use
WebAssembly `i32` arithmetic and the current compiler is equivalent only while
inputs and intermediate results remain within the documented fixnum range.
Checked overflow semantics are unresolved and must be specified before the
numeric surface expands.

Strings are byte-backed UTF-8 values at the host boundary. Mutable bytes and
assets have the same read surface; assets reject mutation. Wider byte reads and
writes are little-endian. `u32@` and `i32@` reject results outside the fixnum
range instead of truncating them.

## 3. Reader and printer

The reader accepts whitespace and comments, integers, symbols, strings, proper
and dotted lists, quote, quasiquote, unquote, and unquote-splicing. Reading is
deterministic for a fixed byte sequence and resource cap. Malformed input must
either produce a stable structured error or a documented trap; it must never
read beyond the input or heap boundary.

The canonical printer must preserve enough structure that every printable data
value satisfies `read(print(value))` structural equality. Symbols and numbers
must not be confused, strings must escape control and delimiter bytes, and
dotted structure must remain dotted. Non-data runtime values use stable opaque
forms such as `<closure>`; round-trip equality is not claimed for opaque values.

Current state: ordinary printing favors REPL readability, while DOM printing is
the canonical data transport. The seed reader decodes that printer's `\\n`,
`\\t`, `\\r`, `\\b`, `\\f`, and lower-case `\\u00xx` control escapes. A
versioned, fixed-seed M2 property covers 256 generated acyclic values plus fixed
string, dotted-pair, comment, numeric, symbol, and Unicode cases. General
source-form generation and generated-value shrinking remain open; opaque runtime
values still have no round-trip claim. The current fixed
host input cap is 130,048 UTF-8 bytes. A submission may enter at most 1,024
combined form/list-spine reader frames and 65,536 reader work entries; the next
entry fails as `depth cap` or `work cap` before an incidental host-stack trap.

The independent reader boundary now rejects unmatched closing parentheses;
leading, missing, unterminated, and overfull dotted tails; and operand-less
quote, quasiquote, unquote, or unquote-splicing prefixes. These use stable
`read error`; unterminated strings/lists retain their specific diagnostics.
Output from complete earlier forms precedes a later reader diagnostic in the
ordered text-effect stream.

## 4. Evaluation order and calls

YaLisp is eagerly evaluated except for special forms and macros.

- In a call, the operator is evaluated first.
- Ordinary arguments are then evaluated exactly once, from left to right.
- A primitive or closure is applied only after all ordinary arguments succeed.
- `begin` evaluates forms from left to right and yields the last value; an empty
  `begin` must have one specified result before it becomes portable.
- `if` evaluates its test first and exactly one branch. Only `nil` and `false`
  are false; every other value is true.
- The final expression of a closure body, selected `if` branch, `begin`, and a
  macro-expanded form is a tail position. Tail calls in these positions must
  not consume unbounded host stack.

Argument arity and malformed special-form shape must eventually produce stable
language errors. Incidental WebAssembly loads or host exceptions are not the
long-term error contract.

## 5. Environments, scope, and mutation

Scope is lexical. A closure captures the environment in which its `lambda` is
evaluated. Applying it creates a child frame, binds parameters to argument
values, and evaluates the body in that environment. Rest parameters are
supported by the seed parameter binder.

`define` adds or shadows a binding in the current frame and yields the defined
value. `set!` searches from the current frame through lexical parents, mutates
the first matching cell, and yields the assigned value. Mutating an unbound
name is an error. Symbol identity is stable within a session because symbols
are interned.

Bindings and reachable mutable objects are shared across interpreted and
compiled execution. Compiling a definition must not copy or fork its cells.
Invalidating compiled code may discard code, but may not discard language
state.

## 6. Macros

Macros are YaLisp values that capture lexical definition environments. A macro
receives its call operands as unevaluated data, runs in its captured environment,
and returns an expansion. That expansion is evaluated in the caller's
environment. Expansion must be deterministic for a fixed macro environment,
input syntax, resource cap, and explicitly supplied entropy/time capabilities.

Quasiquote constructs data recursively and increments a depth counter for each
nested quasiquote. An unquote decrements that counter and remains literal syntax
until it reaches depth one, where its sole operand is evaluated. At depth one,
unquote-splicing is valid only as a list element; its sole operand is evaluated
and must be a proper list, whose elements replace the splice form in order. A
direct splice reports `unquote-splicing expected`; missing or extra operands
report `unquote expected` or `unquote-splicing expected`; atom and dotted-list
splice values report `list expected`. No partial splice is returned on failure.

Macro hygiene is not currently general. Library macros must avoid capture by
construction, as the bootstrapped `or` does. If hygienic identifiers are added,
their marks/scopes must remain inspectable data rather than becoming an opaque
host-only mechanism.

Current inspection boundary: `expand_dom_print` reads forms, repeatedly expands
only a macro bound to a named outer head in the global environment, and prints
the resulting data canonically. It does not evaluate a computed operator or the
form produced by the macro. Macro bodies use the same closure application and
captured definition environment as evaluator-driven expansion. Eight authored
boot expansions hash to `34214d55...` in four fresh sessions and 16 repetitions
in one long-lived session; a stateful produced form is proven not to execute.
Computed-head expansion remains outside the current inspection boundary.
Nested quasiquote depth and malformed splice behavior are covered by four M2
test groups, including matching-depth double unquote and proper-list checks.
Named outer expansion stops before application 1,025 with `macro expansion
cap`; the one-form self-reproducing witness is persisted by the M2 harness.

## 7. Equality

`eq?` is value equality for fixnums and identity equality for interned/singleton
or heap objects. `string=?` compares string contents. `equal?`, defined in the
bootstrap, recursively compares pairs and uses atomic equality at leaves.
Cycles are not currently constructible through the public pair API; when
general object mutation is added, structural equality must specify cycle
handling and resource bounds.

## 8. Control and continuations

The current control core is `if`, sequencing, calls, and proper tail calls.
First-class continuations, dynamic wind, exceptions, handlers, cancellation,
and delimited control are absent. Before any is implemented, the contract must
define captured dynamic state, effect replay, FFI frames, safe points, and
interpreter/compiler equivalence. No compiler may assume continuations are
absent once the feature is admitted by a module's declared language profile.

## 9. Errors and resource caps

Errors are observable results of execution even when represented by a trap.
They have a stable category, diagnostic payload, source location when known,
and ordered prior effects. Evaluation stops at the failing operation; no later
argument, branch, mutation, or output may occur.

Current seed failures write a diagnostic and trap. A trapped instance is not a
recoverable language session and callers should discard it. The M3 seed-owned
category table is:

| Code | Category |
| ---: | --- |
| 0 | unclassified runtime fault |
| 1 | unbound name |
| 2 | reader |
| 3 | arity |
| 4 | type |
| 5 | apply |
| 6 | arithmetic range |
| 7 | bounds |
| 8 | resource exhaustion |
| 9 | mutation |
| 10 | host contract |

Metadata resets at every host entry. Node and browser hosts expose classified
failures with category code/name, diagnostic, native cause, `recoverable:
false`, and `sessionDiscarded: true` as a typed `SeedLanguageError`. An
unclassified Wasm fault retains native `WebAssembly.RuntimeError` identity and
category zero. `/` is a signed left fold that truncates toward zero; `mod` uses
the matching signed remainder. A zero divisor reports `division by zero` or
`modulo by zero` with category 6. Division uses checked fixnum construction, so
`-1073741824 / -1` reports `value exceeds fixnum range` rather than creating an
invalid tagged value. This is an honest bootstrap boundary, not the final high-
level error model.

All readers, expanders, evaluators, compilers, printers, equality operations,
FFI calls, and allocators must honor explicit depth, work, output, and memory
caps. Exceeding a cap is deterministic and fails without partial memory writes
where the operation is documented as atomic.

## 10. Memory and lifetime

Ordinary high-level YaLisp code owns reachability, not storage reclamation.
Reachable values remain valid; unreachable managed values may be reclaimed
without observable relocation or finalization effects unless those effects are
explicitly specified. Low-level arenas, pinned assets, foreign memory, and
manual release are opt-in capabilities with testable lifetime rules.

Current state: the seed is a bump allocator with no collector. `heap.reserve`
declares capacity and `heap.release` rewinds to a caller-managed mark. This is a
sharp arena escape hatch and does not satisfy the high-level memory invariant.
Assets are permanent session roots and may not be released through a lower
mark.

## 11. Modules and packages

Each module has declared imports, exports, language profile, required host
capabilities, and a stable content identity. Module initialization is ordered
by the resolved dependency graph and runs at most once per module instance.
Cycles, reloading, and version selection must have deterministic rules.
Private bindings remain introspectable through authorized debugging interfaces
but are not ambiently imported.

Current state: modules/packages do not exist. Loading source files sequentially
mutates one global environment; load order is observable and tested.

## 12. Interop and ABI

Foreign interaction is capability-based and explicit. An ABI specification must
define scalar widths, signedness, byte order, aggregate layout, ownership,
pinning, callbacks, reentrancy, errors, and effect ordering. A foreign call may
not retain a managed pointer without an explicit stable handle or pin.

The current seed imports `host.write(ptr,len)` and
`host.bytes_write(ptr,len)`, and exports memory plus initialization, evaluation,
printing, and asset-ingestion entry points. Source is copied into
`[1024,131072)`. These functions form the current WebAssembly bootstrap ABI;
filesystem, network, clock, entropy, DOM, and general native FFI are absent.

## 13. Interpreted/compiled switching

Compilation is an execution choice, not a semantic mode. At a defined safe
point the runtime may replace an interpreted callable with compiled code when:

- its source/expanded form, referenced binding generations, module content IDs,
  numeric profile, and capability profile still match the cache key;
- live bindings and mutable objects remain shared;
- deoptimization metadata can reconstruct an interpreter frame at every
  permitted rollback point;
- debug/source maps preserve source-level stepping and introspection;
- invalidation is transitive and deterministic.

Switching, cache invalidation, compilation failure, and rollback must be
included in the observation record. A failed speculative compilation resumes
the interpreter without duplicating effects. Current state: absent.

## 14. Cost transparency

Source-level abstraction must not hide a different semantic result, and
documentation must disclose material cost classes: allocation, traversal,
copying, compilation, pinning, foreign transition, and worst-case control
growth. Implementations may optimize any operation when observational
equivalence and declared resource behavior remain intact.
