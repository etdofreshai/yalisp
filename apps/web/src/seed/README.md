# YALISP executable seed

This directory contains the first executable YALISP language substrate. Its
implementation is derived from the verified M9 seed in
[`ETdoFreshAI/lispish` commit `c78a2be`](https://github.com/ETdoFreshAI/lispish/tree/c78a2be/boot).
The port preserves that seed's WAT semantics and gives the public YALISP docs a
small, real interpreter rather than a simulated example.

## Boundary

`bootstrap.wat` imports only `host.write(ptr, len)`. It exports a four-page
WebAssembly memory plus `init`, `eval_all`, and `eval_print`. Source is copied
into the fixed input range `[1024, 8192)` before evaluation.

The seed implements:

- tagged integers, booleans, nil, symbols, strings, pairs, closures, macros,
  primitives, and lexical environments;
- reading and printing S-expressions, including quote, quasiquote, unquote,
  dotted pairs, strings, integers, and comments;
- the special forms `quote`, `if`, `lambda`, `macro`, `define`, `set!`, and
  `begin`;
- list primitives plus integer arithmetic, comparison, type predicates, and a
  small string surface.

The checked-in `public/yalisp/boot.lisp` is evaluated by that kernel to form the
Bootstrap stage. It adds real Lisp-written macros and functions including
`cond`, `defn`, `let`, `when`, `unless`, `and`, `or`, `map`, `filter`,
`reduce`, `append`, and structural equality.

This intentionally does not claim garbage collection, recoverable errors,
modules, filesystem or DOM access, a compiler, JIT execution, or AOT execution.
Curated web examples use a fresh instance so the seed's fixed bump-allocated
heap remains bounded. The interpreter benchmark is also bounded and reports
only measured interpreter execution.

Run `npm run build-seed --workspace @yalisp/web` to assemble the WAT into the
ignored generated file `public/yalisp/seed.wasm`.
