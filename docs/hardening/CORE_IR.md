# YaLisp core IR v1

Status: normative data and validation contract with bounded deterministic
source lowering; reference execution and compiler consumption are not yet
implemented.

Core IR is ordinary, immutable YaLisp data. It is not a hidden host AST and it
does not authorize a compiler to change language behavior. Its first purpose is
to make the boundary after macro expansion inspectable and independently
checkable. The reviewed canonical example is
`apps/web/tests/fixtures/core-ir-v1-example.lisp`.

## 1. Grammar

The grammar below uses list notation literally. `tail` is the YaLisp boolean
`true` or `false`. Every list shown is proper and has exactly the displayed
length unless followed by `...`.

```text
program ::= (yalisp-core-ir-v1 node)

node ::= (const  tail source datum)
       | (ref    tail source binding)
       | (set    tail source binding node)
       | (define tail source symbol node)
       | (if     tail source node node node)
       | (lambda tail source (binder ...) rest-binder-or-nil node)
       | (call   tail source node (node ...))
       | (begin  tail source (node ...))

binding ::= (global symbol) | (local nonnegative-integer)
binder  ::= (bind nonnegative-integer source-name-symbol)

source ::= (src unit start-byte end-byte (origin ...))
origin ::= (macro macro-name unit start-byte end-byte)
         | (generated reason-symbol)
```

`datum` is portable, acyclic YaLisp data: nil, booleans, signed 30-bit
integers, strings, symbols, proper lists, and dotted pairs composed from the
same values. Runtime closures, primitives, mutable byte buffers, assets, host
handles, and opaque pointers are not literals. The source interval is half-open
`[start-byte, end-byte)` in UTF-8 bytes. A source registry must additionally
verify that the interval lies within the named unit; the structural validator
cannot infer unavailable source-unit lengths. All structural integers—binding
IDs and byte offsets included—must also fit the nonnegative fixnum range so the
entire graph remains directly representable by the YaLisp reader.

Macro origins are ordered outermost to innermost. A generated origin names a
deterministic lowering rule. Source metadata is retained by serialization and
debugging but is never evaluated and cannot affect program results or effects.

## 2. Bindings and environments

Global identity is the symbol in `(global name)`. A local identity is the
integer in `(local id)`. Every binder ID is unique across one IR program, not
merely within a lexical frame. Source names are display/debug metadata and do
not determine identity, so source shadowing remains transparent without name
capture. A lambda body may refer to its own binders and binders in enclosing
lambdas. References outside that lexical set are invalid.

The eventual reference interpreter and compiler must represent mutable
bindings as shared cells. Captured reads and writes therefore observe the same
cell as direct interpreted evaluation. `define` creates or replaces a global
binding only after its value expression succeeds. `set` commits only after its
value expression succeeds and must reject an absent binding with the same
structured language error as direct interpretation.

## 3. Evaluation and tail positions

The semantics of a validated node are fixed:

- `const` returns its datum without evaluating it.
- `ref` reads its resolved binding cell.
- `set` evaluates its value, then commits the cell, then returns that value.
- `define` evaluates its value, then commits the global cell, then returns it.
- `if` evaluates only its test and the selected branch.
- `lambda` captures the current lexical environment and binds fixed arguments
  left-to-right; a non-nil rest binder receives the remaining proper list.
- `call` evaluates the callee first, then every argument left-to-right, then
  applies it. A failure retains exactly the earlier effects already required by
  the language specification.
- `begin` evaluates forms left-to-right and returns the last result; an empty
  form list returns nil.

The root node has `tail=true`. An `if` test is non-tail and each branch inherits
the `if` node's tail flag. A lambda body is tail regardless of the lambda
expression's position. A call callee and all arguments are non-tail. A `set` or
`define` value is non-tail. In `begin`, only the last form inherits the parent
tail flag; all earlier forms are non-tail. The validator rejects the first
incorrect annotation. A compiler may optimize a `call` only when its stored
flag is true, and must preserve semantics if it chooses not to optimize it.

## 4. Deterministic source lowering

`scripts/hardening/core-ir-lowering.mjs` is the initial independent lowering
boundary. It reads exactly one UTF-8 source submission, tracks half-open byte
spans, lowers the kernel forms `quote`, `if`, `lambda`, `define`, `set!`, and
`begin`, resolves lexical references to program-unique binder IDs, and validates
the resulting IR before returning it. Empty `begin`, omitted `if` alternates,
and multi-form lambda bodies use explicit generated provenance rather than
hidden host nodes.

The optional `expandOuter` boundary accepts and returns canonical source text.
It is called only for a proper application with a global symbol head, after
kernel-special-form precedence and lexical-head resolution. A changed result is
recorded as one expansion, reparsed, given the original call-site span plus an
ordered outermost-to-innermost macro origin, and recursively expanded before
lowering. An unchanged result is a runtime call. Macro lookup follows source
order, including test, consequent, then alternate for an `if`; produced user
code is not evaluated by the lowerer.

The lowering profile has independent exact work caps:

| Cap | Default | Counted unit |
| --- | ---: | --- |
| `maxSourceBytes` | 130,048 | UTF-8 bytes in the submitted source |
| `maxSourceUnitBytes` | 65,536 | UTF-8 bytes in the source-unit identifier |
| `maxSyntaxNodes` | 4,096 | original nodes plus every reparsed expansion node |
| `maxSyntaxDepth` | 256 | maximum reader nesting, root depth 1 |
| `maxMacroExpansions` | 1,024 | changed outer-expansion results |
| `maxMacroExpansionBytes` | 1,048,576 | every callback result, including unchanged results |
| `maxOriginsPerSpan` | 64 | macro and generated origins on one span |

The last allowed unit succeeds and the next fails before it is charged. The
fixed-seed `yalisp-core-source-v1` profile uses seed `0x4c4f5745`, 256 forms,
and generator depth 5. It reaches every IR opcode, lowers every form twice,
validates the output, and pins aggregate hash
`2677a95639aa4aeb3b6fc2cf153eed8cc670de3ef0cc9c2ba62d81da4283004e`.
Eight fresh boot sessions lower nested `let`/`when` expansion to hash
`a693116b6607ef5065104858a31b873f4d18a3de3435d95b45abc2e2be06fab4`.

This boundary is deliberately narrower than evaluator semantics. It observes
only named global outer macros through the callback, not computed or lexically
passed macro values. `macro` and unresolved quasiquote forms must be expanded
before core lowering. A `define` inside a closure is rejected as
`unsupported-local-define`: the current seed defines in its current frame,
whereas IR v1 intentionally models only global definition. These are explicit
gaps, not silent rewrites.

## 5. Deterministic validation

`scripts/hardening/core-ir-v1.mjs` is the initial independent tooling
validator. It walks depth-first in grammar field order and returns exactly one
report. A valid report contains metrics and `error: null`; an invalid report
contains the first `{code, path, detail}`. It never mutates the supplied graph.
Fresh and warmed runs must serialize to identical report bytes.

Default caps are part of the v1 validation profile:

| Cap | Default | Counted unit |
| --- | ---: | --- |
| `maxNodes` | 4,096 | each entered IR node |
| `maxDepth` | 256 | nested IR nodes, root depth 1 |
| `maxLiteralNodes` | 8,192 | each atom, list, or pair in literal data |
| `maxLiteralBytes` | 1,048,576 | UTF-8 bytes in literal strings and symbols |
| `maxSourceBytes` | 65,536 | UTF-8 bytes in one source-unit identifier |
| `maxOriginsPerSpan` | 64 | provenance entries on one source span |

Caps are positive safe integers supplied by the trusted harness. At a boundary,
the last allowed unit succeeds and the next unit fails before being charged.
Unknown cap names and non-object cap configurations are rejected rather than
silently falling back to a default.
Cycles fail explicitly. Exact list shapes, opcode arities, source ranges,
origin shapes, portable symbol spellings, literal representation, binding
uniqueness, lexical resolution, and tail rules are all validated.

The property profile `yalisp-core-ir-v1-graphs` fixes seed `0x49525631`, 256
graphs, and generated nesting depth 6. It covers every opcode, validates each
graph, compares serialization after a structural clone, and requires a root-tail
mutation to fail at the same path. The aggregate of the 256 canonical IR hashes
is `c7e849d3916c957c1f2d8a6c43209cdd11c432ea6d1d750aa28db2087cebc342`.

The validator and lowerer are presently conformance-tool trust boundaries, not
part of the seed or a claim of self-hosting. M4 remains incomplete until a
reference interpreter executes this data, the golden corpus compares direct
and IR execution, and canonical
serialization/decompilation round trips preserve every semantic and source-map
field.

## 6. Canonical identity and future consumers

Canonical IR serialization uses the seed reader/printer spelling for portable
data. SHA-256 is computed over those UTF-8 bytes with no trailing newline. The
reviewed v1 example is 1,252 bytes with SHA-256
`12e1ba6d916787d5fcde58bce0ff722342040dee6a58527d9f1fc97787c1424b`.
The checked-in text file is 1,253 bytes and hashes to
`578e6bf97332ad4e90ded418c43ee2e0647d053cfe49626d7d6f383e2d381f9d`
because repository text convention adds one trailing newline; that terminator
is excluded from canonical IR identity.
Cache keys must eventually include this identity plus the language semantics
version, numeric profile, capabilities, and dependency versions. A consumer
must validate before execution, compilation, caching, or decompilation.

Decompilation is semantic, not byte-for-byte source recovery. It must reconstruct
a core source form whose expansion lowers to equivalent IR, while separately
returning the exact stored source maps, binder IDs/names, and tail annotations.
No consumer may drop those fields merely because they do not change an
immediate value.
