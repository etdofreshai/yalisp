# YALISP executable seed

This directory contains the first executable YALISP language substrate. Its
implementation is derived from the verified M9 seed in
[`ETdoFreshAI/lispish` commit `c78a2be`](https://github.com/ETdoFreshAI/lispish/tree/c78a2be/boot).
The port preserves that seed's WAT semantics and gives the public YALISP docs a
small, real interpreter rather than a simulated example.

## Boundary

The checked-in `bootstrap.wat` imports `host.write(ptr, len)` for text and
`host.bytes_write(ptr, len)` for raw byte buffers. The build assembles it into
the generated, ignored `public/yalisp/seed.wasm`, which exports a sixteen-page
WebAssembly memory plus `init`, `eval_all`, `eval_print`, `eval_dom_print`,
`expand_dom_print`, `eval_bytes`, `asset_begin`, `asset_commit`, and the
read-only `error_kind` failure-metadata export. Source is
copied into the fixed input range `[1024, 131072)` before evaluation.

`expand_dom_print` is an inspection boundary, not a second evaluator. It reads
forms, repeatedly applies only macros bound to a named outer head in the global
environment, and prints the resulting data canonically. It does not evaluate a
computed operator or the produced user form. Macro bodies run through the same
captured closure application as ordinary evaluation.

Both shipped hosts reject source beyond the fixed 130,048-byte input region
before writing WebAssembly memory. Each accepted submission resets two seed
reader budgets: 1,024 combined `read1`/list-spine frames and 65,536 corresponding
work entries. An EOF probe is not charged as a form. Named outer expansion is
separately capped at 1,024 macro applications. Crossing a boundary writes
`depth cap`, `work cap`, or `macro expansion cap` and traps; the host discards
that failed instance.

The reader rejects unmatched closing parentheses, a dotted tail before any list
element, a missing dotted value or closing parenthesis, extra forms after a
dotted value, and quote/quasiquote/unquote prefixes without an operand. These
fail as `read error` before evaluation. Unterminated strings and ordinary lists
retain their more specific diagnostics. If complete forms preceded a trailing
syntax error, their already-written `read_print` output remains an ordered prior
effect rather than being erased.

Quasiquote tracks lexical nesting depth. `unquote` evaluates only at its
matching depth, while a deeper occurrence remains inspectable syntax until its
own quasiquote is evaluated. `unquote-splicing` is accepted only in list-element
position at the matching depth, requires exactly one operand, and requires that
operand to evaluate to a proper list. Malformed unquote arity, direct splicing,
and atom or dotted-list splice values produce stable diagnostics before any
partial splice is constructed.

The seed implements:

- tagged integers, booleans, nil, symbols, strings, mutable byte buffers,
  immutable host-ingested assets, pairs,
  closures, macros, primitives, and lexical environments;
- reading and printing S-expressions, including quote, quasiquote, unquote,
  dotted pairs, strings, integers, and comments;
- the special forms `quote`, `if`, `lambda`, `macro`, `define`, `set!`, and
  `begin`, with tail positions evaluated iteratively so a tail-recursive
  program's depth is bounded by the heap rather than by the host stack;
- list primitives plus integer arithmetic, comparison, type predicates, bit and
  fixed-point operations, byte-buffer access, and a small string surface;
- fixed-width little-endian accessors — `u8@`, `u8!`, `u16@`, `i16@`, `u16!`,
  `u32@`, `i32@`, `u32!` — and the bounded block operations `bytes.fill`,
  `bytes.fill-stride`, and `bytes.copy`, so decoding a binary format and moving
  a frame do not cost one interpreted call per byte;
- `bound?`, `heap.used`, `heap.capacity`, `heap.reserve`, and `heap.release`, so
  a program can ask what it has, declare the memory it needs, and hand back a
  region it has finished with;
- `asset.reserve`, `asset.used`, `asset.count`, `asset.ref`, and `asset?`, so a
  program can declare capacity for host-supplied bytes and address them.

Memory past the initial sixteen pages is never taken implicitly. `heap.reserve`
grows it on request up to a ceiling of 4096 pages; exceeding that ceiling
writes a diagnostic and traps rather than allocating without limit. Because the
underlying memory is 4096 pages (256 MiB) in total and the heap begins at 131072, the
largest satisfiable `heap.reserve` is the ceiling less the bytes already used.

## Fixed-width access and block operations

A program decoding a file written by a little-endian machine needs to read
wider values than a byte, and a program presenting a frame needs to move a page
of them at once. Both are generic: the kernel still knows only a length of
bytes, and every format, palette, and blit policy stays in Lisp.

All eight accessors are little-endian and bounds-checked through the same
address helper `u8@` uses, so an index past the end is a diagnostic rather than
a read elsewhere in linear memory. The signed reads `i16@` and `i32@` sign-
extend where `u16@` and `u32@` do not. There is no `i16!` or `i32!`, because
two's complement makes a signed store and an unsigned store of the same value
the same bytes; `u16!` and `u32!` write the low sixteen or thirty-two bits.

`bytes.fill` takes a buffer, an index, a count, and a byte; `bytes.copy` takes a
destination, its index, a source, its index, and a count. Both check the whole
run as a single access width before moving anything, so a negative or
overlong count fails before a partial write, and both return the count. A copy
moves as if through a temporary, so overlapping ranges shift correctly in
place. Only the destination must be mutable: an ingested asset is a legal copy
source. Both are single bulk-memory instructions, so a 64KB clear or present
is bounded work that allocates no heap.

`bytes.fill-stride` takes a buffer, an index, a count, a stride, and a byte, and
writes the byte every `stride` bytes for `count` writes. It is `bytes.fill` for
a run that is not contiguous, and it exists for the same reason: a program that
has already worked out which bytes to write should not pay an interpreted call
for each of them. A column of a framebuffer is the obvious case, and the kernel
decides nothing about it — index, count, stride, and value all arrive computed.
The stride must not be negative, and the first and last bytes of the run are
both checked before any of it moves.

## Releasing a region

The allocator is a bump pointer and does not collect. That is fine for a program
that builds a structure once, and fatal for one that recomputes something every
frame: the intermediates are spent for good and the declared session ceiling
arrives. The seed starts at 16 pages and has a type-level maximum of 4096 pages;
programs still grow only through explicit `heap.reserve`. So `heap.used` has an
inverse. `heap.release` takes a value `heap.used` returned
earlier and winds the bump pointer back to it, which turns a computation into an
arena.

It is a truthful primitive and a sharp one. Everything allocated after the mark
is gone, so a release is sound only when nothing allocated inside the region is
still reachable: no value stored into a global with `set!`, no symbol interned
by reading new source, and nothing held by a caller further up. A mark below an
ingested asset is refused outright rather than left to the caller, because an
asset handle is permanent by contract; so is a mark above the current position.
Both write `heap mark out of range` and trap.

A fixnum carries a one-bit tag, so it holds 31 signed bits and cannot represent
every 32-bit word. `u32@` accepts `[0, 2^30)` and `i32@` accepts
`[-2^30, 2^30)`; a word outside its accessor's range writes
`value exceeds fixnum range` and traps rather than returning a truncated number
a decoder would have no way to notice. `u32!` is bounded the same way by what a
fixnum argument can carry, though a negative value reaches the top of the
unsigned range through two's complement. A program needing the full 32-bit
range must still split the word, reading it as two `u16@` halves.

## Host-ingested assets

A program may be handed bytes the host obtained elsewhere, which is the only
way data larger than the 127KB source input region enters the runtime. The
kernel treats such a buffer as a length of bytes and nothing more: container
formats, chunk tables, palettes, and codecs are decided entirely in Lisp.

Capacity is declared before it is used, as it is for the heap. `asset.reserve`
states how many further asset bytes the program is prepared to hold and returns
what is then available; `asset.used` and `asset.count` report the running
totals. A fresh instance has been granted nothing, so a host ingest before any
reserve is refused.

Ingestion is two host calls so a multi-megabyte buffer crosses the boundary
once. `asset_begin(len)` checks the request against the declared allowance and
returns an address; the host writes the bytes into linear memory itself; and
`asset_commit()` publishes the result and returns a handle. `asset_begin` may
grow memory, so a host holding a view over the buffer must re-read it before
writing. An ingest that is refused or abandoned leaves nothing behind.

`asset.ref` maps a handle to the buffer, returning the same object every time,
and `asset?` distinguishes ingested bytes from allocated ones. Assets are read
through the ordinary bounds-checked accessors — `bytes.length`, `u8@`, `u16@` —
so a Lisp decoder needs no separate vocabulary for host-supplied data. They are
immutable: `u8!` refuses them, and says so, rather than reporting a type error.

Assets are kept alive by a kernel registry rather than by whatever Lisp value
happens to reference them. The registry and any in-flight ingest are collector
roots, so once a non-moving collector reclaims the rest of the heap a committed
asset keeps both its address and its `asset.ref` identity for the whole
session.

The checked-in `public/yalisp/boot.lisp` is evaluated by that kernel to form the
Bootstrap stage. It adds real Lisp-written macros and functions including
`cond`, `defn`, `let`, `when`, `unless`, `and`, `or`, `map`, `filter`,
`reduce`, `append`, and structural equality.

There is still no collector, so everything a session allocates stays allocated
for the life of that session. `heap.used` reports the running total, and
`npm run measure:wolf3d-feasibility --workspace @yalisp/web` reports the
per-tick allocation rate that this implies for a long-lived application.

This intentionally does not claim garbage collection, language-level
recoverable errors, modules, or filesystem or DOM access. The separate
Lisp-written M1 compiler supports only the documented one-parameter integer
arithmetic subset; it is not part of the seed itself.
Curated web examples use a fresh instance so the seed's fixed bump-allocated
heap remains bounded. The interpreter benchmark is also bounded and reports
only measured interpreter execution. Heap, reader, and primitive type guards
write a truthful diagnostic before trapping; the Playground preserves that
diagnostic and discards the failed instance.

M3 begins the migration away from treating every failure as the same Wasm
trap. An unbound-name path records seed-owned error category `1` before writing
its diagnostic and trapping. Node and browser hosts expose that path as a typed
`SeedLanguageError`; an unclassified Wasm fault keeps its native runtime-error
identity and `error_kind` remains zero. The instance is still discarded in both
cases. Other language diagnostics are not yet categorized and remain part of
the active M3 work.

Run `npm run build-seed --workspace @yalisp/web` to assemble the WAT into the
ignored generated file `public/yalisp/seed.wasm`.
