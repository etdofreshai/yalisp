# M3 special-form and user-call arity — 2026-09-02

This immutable observation records the seventh atomic M3 slice. It prevents
malformed special forms and closure/macro calls from reaching lenient loads or
binding missing values as `nil`.

The initial three groups all failed: malformed special forms were accepted,
fixed calls ignored extras or bound missing arguments to `nil`, and a dotted
rest function accepted fewer than its fixed prefix.

The resulting contract is:

- exact: `quote`, `define`, `set!`, `quasiquote`;
- ranged: `if` has test/then and optional else;
- body forms: `lambda` and `macro` require parameters plus at least one body;
- variadic: `begin`;
- proper parameter lists match exactly;
- bare symbols bind the whole argument list;
- dotted symbol tails bind the remainder after their fixed prefix;
- non-symbol parameters fail before body entry.

Named calls report `<name> expected`; computed closures report
`lambda expected`. All are recoverable category-3 errors.

Artifact evidence: WAT 114,987 bytes at
`e071f4182bf3289f60e3fbd4e35a7cddda32a95138642d8ee30d62364069c712`;
Wasm 11,850 bytes at
`8aa5a795b829c8dcb13adecb5645df7a4bb1aec37654d743d2da8d0168531c79`;
103 defined functions and 4,991 unfolded static instructions. The delta from
the primitive-arity slice is +1,964 WAT bytes, +177 Wasm bytes, and +93 static
instructions.

The focused set passes 59/59, fresh WABT output is byte-identical, and the
15-case golden corpus reports no earliest divergence. M3 remains active for
structured payload fields and explicit compiler error-intersection evidence.
