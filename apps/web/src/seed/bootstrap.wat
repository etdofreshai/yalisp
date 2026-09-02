;; YALISP WebAssembly seed kernel
;; Derived from ETdoFreshAI/lispish commit c78a2be (M9 seed), then narrowly
;; hardened for bounded browser execution. This checked-in WAT is the source;
;; public/yalisp/seed.wasm is generated from it during the web build.
;; M1: tagged value model, bump allocator, symbol interning, printer.
;; M2: S-expression reader (text -> values).
;; M3: eval/apply, first-class environments, special forms, closures, primitives.
;;
;; Value encoding (i32):
;;   - low bit 1  -> fixnum, integer = value >> 1   (31-bit signed)
;;   - low bit 0  -> pointer to a heap object (4-byte aligned)
;; Heap object word[0] is a type tag:
;;   0 nil  1 true  2 pair  3 symbol  4 string  5 closure  6 macro  7 primitive  8 eof  9 false
;;   10 bytes (mutable)  11 asset (immutable, host-ingested)
;;
;; Object layouts (4-byte words):
;;   pair     [2, car, cdr]
;;   symbol   [3, name-ptr, name-len, next-in-intern-list]
;;   string   [4, bytes-ptr, len]
;;   closure  [5, params, body, env]
;;   macro    [6, params, body, env]
;;   primitive[7, id]
;;   bytes    [10, len, raw-byte...]
;;   asset    [11, len, raw-byte...]   same layout as bytes; reads share every
;;                                     accessor, writes are refused
;;
;; Environment = a pair (frame . parent), frame = alist of (sym . val) pairs.
;;   define -> prepend a (sym . val) to the frame;  set! -> mutate the val slot.
;;
;; Memory map:
;;   [0,    32)  scratch (integer formatting)
;;   [32,   64)  compact arithmetic diagnostics
;;   [64, 1024)  constant strings
;;   [1024, 131072) input buffer (host writes source here)
;;   [131072, .  )  heap (bump allocated; no GC yet)

(module
  (import "host" "write" (func $host_write (param i32 i32)))
  ;; Generic binary output path. The consumer decides how to present the
  ;; bytes; this seed kernel intentionally has no game, image, or audio type.
  (import "host" "bytes_write" (func $host_bytes_write (param i32 i32)))

  ;; Sixteen pages leave the fixed input region intact and provide enough
  ;; bounded bump-heap space for the complete Assembly reference DOM tree.
  (memory (export "memory") 16 4096)

  ;; Memory past the initial sixteen pages is never taken implicitly. A program
  ;; asks for it with (heap.reserve n), so exhaustion stays a declared limit
  ;; instead of silent unbounded growth, and small sessions keep their small
  ;; footprint. The ceiling is generic capacity, not any application's budget.
  (global $max_pages i32 (i32.const 4096))

  (global $heap    (mut i32) (i32.const 131072))
  (global $nil     (mut i32) (i32.const 0))
  (global $true    (mut i32) (i32.const 0))
  (global $false   (mut i32) (i32.const 0))
  (global $eof     (mut i32) (i32.const 0))
  (global $symlist (mut i32) (i32.const 0))
  (global $genv    (mut i32) (i32.const 0))
  ;; interned special-form symbols (filled in $init)
  (global $sym_quote  (mut i32) (i32.const 0))
  (global $sym_if     (mut i32) (i32.const 0))
  (global $sym_lambda (mut i32) (i32.const 0))
  (global $sym_macro  (mut i32) (i32.const 0))
  (global $sym_define (mut i32) (i32.const 0))
  (global $sym_set    (mut i32) (i32.const 0))
  (global $sym_begin  (mut i32) (i32.const 0))
  (global $sym_qq     (mut i32) (i32.const 0))
  (global $sym_uq     (mut i32) (i32.const 0))
  (global $sym_uqs    (mut i32) (i32.const 0))
  ;; reader cursor
  (global $rp      (mut i32) (i32.const 0))
  (global $rend    (mut i32) (i32.const 0))
  ;; A source submission gets fixed reader budgets. Both read1 frames and list
  ;; spine frames count toward depth/work so flat lists cannot move unbounded
  ;; recursion out of sight inside $read_list.
  (global $read_depth (mut i32) (i32.const 0))
  (global $read_work  (mut i32) (i32.const 0))
  (global $read_depth_limit i32 (i32.const 1024))
  (global $read_work_limit  i32 (i32.const 65536))
  ;; --- host-ingested asset registry ---
  ;; Assets are ordinary heap objects, so nothing here assumes a particular
  ;; allocator. They are kept alive by this registry rather than by whatever
  ;; Lisp value happens to reference them, which is what "pinned" means for a
  ;; non-moving collector: $assets and $asset_pending are collector roots, and
  ;; because such a collector never relocates an object, a committed asset's
  ;; address and its (asset.ref h) identity stay valid for the whole session.
  (global $assets        (mut i32) (i32.const 0))  ;; list, newest first  [ROOT]
  (global $asset_count   (mut i32) (i32.const 0))
  (global $asset_used    (mut i32) (i32.const 0))
  (global $asset_limit   (mut i32) (i32.const 0))
  ;; The object between asset_begin and asset_commit, reachable from nowhere
  ;; else while the host fills it.                                     [ROOT]
  (global $asset_pending (mut i32) (i32.const 0))
  ;; The lowest address the bump pointer may be wound back to. It advances past
  ;; every published asset, so releasing a region can never expose memory an
  ;; asset handle still names.                                          [ROOT]
  (global $heap_floor    (mut i32) (i32.const 131072))
  ;; output redirect: if $out_buf != 0, $write appends to it instead of the host
  (global $out_buf (mut i32) (i32.const 0))
  (global $out_len (mut i32) (i32.const 0))
  ;; Seed-owned failure metadata. A zero kind and empty data span mean that a
  ;; host-observed Wasm trap was not raised through a classified language-error
  ;; path. The span is valid until the next exported operation resets it.
  (global $error_kind (mut i32) (i32.const 0))
  (global $error_data_ptr (mut i32) (i32.const 0))
  (global $error_data_len (mut i32) (i32.const 0))

  ;; --- constant strings, region [64, 1024) ---
  (data (i32.const 32)  "division by zero") ;; 32 len 16
  (data (i32.const 48)  "modulo by zero")   ;; 48 len 14
  (data (i32.const 64)  "nil")          ;; 64  len 3
  (data (i32.const 67)  "true")         ;; 67  len 4
  (data (i32.const 71)  "(")            ;; 71  len 1
  (data (i32.const 72)  ")")            ;; 72  len 1
  (data (i32.const 73)  " ")            ;; 73  len 1
  (data (i32.const 74)  " . ")          ;; 74  len 3
  (data (i32.const 77)  "<closure>")    ;; 77  len 9
  (data (i32.const 86)  "<macro>")      ;; 86  len 7
  (data (i32.const 93)  "<primitive>")  ;; 93  len 11
  (data (i32.const 104) "\n")           ;; 104 len 1
  ;; Resource diagnostics assembled from these compact pieces:
  ;; "depth cap", "work cap", and "macro expansion cap".
  (data (i32.const 105) "depth")         ;; 105 len 5
  (data (i32.const 110) "work")          ;; 110 len 4
  (data (i32.const 114) "expansion")     ;; 114 len 9
  (data (i32.const 123) " cap")          ;; 123 len 4
  (data (i32.const 128) "quote")        ;; 128 len 5
  (data (i32.const 133) "cons")         ;; 133 len 4
  (data (i32.const 137) "car")          ;; 137 len 3
  (data (i32.const 140) "cdr")          ;; 140 len 3
  (data (i32.const 143) "atom")         ;; 143 len 4
  (data (i32.const 147) "eq")           ;; 147 len 2
  (data (i32.const 149) "+")            ;; 149 len 1
  (data (i32.const 150) "-")            ;; 150 len 1
  (data (i32.const 151) "*")            ;; 151 len 1
  (data (i32.const 152) "/")            ;; 152 len 1
  (data (i32.const 153) "=")            ;; 153 len 1
  (data (i32.const 154) "<")            ;; 154 len 1
  (data (i32.const 155) "if")           ;; 155 len 2
  (data (i32.const 157) "lambda")       ;; 157 len 6
  (data (i32.const 163) "macro")        ;; 163 len 5
  (data (i32.const 168) "define")       ;; 168 len 6
  (data (i32.const 174) "set!")         ;; 174 len 4
  (data (i32.const 178) "begin")        ;; 178 len 5
  (data (i32.const 184) "unbound: ")    ;; 184 len 9
  (data (i32.const 193) "cannot apply") ;; 193 len 12
  (data (i32.const 205) "list")              ;; 205 len 4
  (data (i32.const 209) "quasiquote")        ;; 209 len 10
  (data (i32.const 219) "unquote")           ;; 219 len 7
  (data (i32.const 226) "unquote-splicing")  ;; 226 len 16
  (data (i32.const 250) "false")        ;; 250 len 5
  (data (i32.const 255) "nil?")         ;; 255 len 4
  (data (i32.const 259) "symbol?")      ;; 259 len 7
  (data (i32.const 266) "pair?")        ;; 266 len 5
  (data (i32.const 271) "list?")        ;; 271 len 5
  (data (i32.const 276) "number?")      ;; 276 len 7
  (data (i32.const 283) "string?")      ;; 283 len 7
  (data (i32.const 290) "boolean?")     ;; 290 len 8
  (data (i32.const 298) "function?")    ;; 298 len 9
  (data (i32.const 307) "primitive?")   ;; 307 len 10
  (data (i32.const 317) "closure?")     ;; 317 len 8
  (data (i32.const 325) "macro?")       ;; 325 len 6
  (data (i32.const 331) "atom?")        ;; 331 len 5
  (data (i32.const 336) "eq?")          ;; 336 len 3
  (data (i32.const 340) "mod")               ;; 340 len 3
  (data (i32.const 343) "<=")                ;; 343 len 2
  (data (i32.const 345) ">")                 ;; 345 len 1
  (data (i32.const 346) ">=")                ;; 346 len 2
  (data (i32.const 348) "string.length")     ;; 348 len 13
  (data (i32.const 361) "string.append")     ;; 361 len 13
  (data (i32.const 374) "string.concat")     ;; 374 len 13
  (data (i32.const 387) "string.slice")      ;; 387 len 12
  (data (i32.const 399) "string.substring")  ;; 399 len 16
  (data (i32.const 415) "string.contains?")  ;; 415 len 16
  (data (i32.const 431) "string=?")          ;; 431 len 8
  (data (i32.const 439) "to-string")         ;; 439 len 9
  (data (i32.const 448) "heap exhausted")    ;; 448 len 14
  (data (i32.const 462) "string expected")   ;; 462 len 15
  (data (i32.const 477) "unterminated string") ;; 477 len 19
  (data (i32.const 496) "unterminated list") ;; 496 len 17
  (data (i32.const 513) "number expected")   ;; 513 len 15
  ;; Generic byte-buffer / fixed-point primitives. These are intentionally
  ;; not Wolf3D-specific; the Lisp layer owns all asset and renderer policy.
  (data (i32.const 530) "bytes.alloc")        ;; 530 len 11
  (data (i32.const 541) "bytes.length")       ;; 541 len 12
  (data (i32.const 553) "u8@")                ;; 553 len 3
  (data (i32.const 556) "u8!")                ;; 556 len 3
  (data (i32.const 559) "u16@")               ;; 559 len 4
  (data (i32.const 563) "bit.and")            ;; 563 len 7
  (data (i32.const 570) "bit.or")             ;; 570 len 6
  (data (i32.const 576) "bit.xor")            ;; 576 len 7
  (data (i32.const 583) "bit.shl")            ;; 583 len 7
  (data (i32.const 590) "bit.shr")            ;; 590 len 7
  (data (i32.const 597) "fx.mul-shift")       ;; 597 len 12
  (data (i32.const 609) "bit.mul-shr")        ;; 609 len 11
  (data (i32.const 620) "byte buffer expected") ;; 620 len 20
  (data (i32.const 640) "byte index out of range") ;; 640 len 23
  (data (i32.const 664) "<bytes>")           ;; 664 len 7
  ;; Generic environment and memory introspection. Neither knows anything about
  ;; applications; they exist so a program can negotiate its own capacity.
  (data (i32.const 672) "bound?")            ;; 672 len 6
  (data (i32.const 678) "heap.reserve")      ;; 678 len 12
  (data (i32.const 690) "heap.used")         ;; 690 len 9
  (data (i32.const 699) "heap.capacity")     ;; 699 len 13
  (data (i32.const 712) "memory limit reached") ;; 712 len 20
  (data (i32.const 732) "symbol expected")   ;; 732 len 15
  ;; Host-ingested immutable assets. The kernel knows only "a length of bytes
  ;; the host supplied"; every file format, chunk table, and codec is Lisp.
  (data (i32.const 747) "asset.reserve")           ;; 747 len 13
  (data (i32.const 760) "asset.used")              ;; 760 len 10
  (data (i32.const 770) "asset.count")             ;; 770 len 11
  (data (i32.const 781) "asset.ref")               ;; 781 len 9
  (data (i32.const 790) "asset?")                  ;; 790 len 6
  (data (i32.const 796) "<asset>")                 ;; 796 len 7
  (data (i32.const 803) "asset capacity exceeded") ;; 803 len 23
  (data (i32.const 826) "asset handle out of range") ;; 826 len 25
  (data (i32.const 851) "immutable byte buffer")   ;; 851 len 21
  (data (i32.const 872) "asset ingest protocol")   ;; 872 len 21
  ;; Fixed-width accessors and bounded block operations. Sixteen- and
  ;; thirty-two-bit values are read and written little-endian, which is what a
  ;; program decoding a file written by a little-endian machine needs; the
  ;; kernel still knows nothing about any particular file.
  (data (i32.const 896) "u16!")                    ;; 896 len 4
  (data (i32.const 900) "i16@")                    ;; 900 len 4
  (data (i32.const 904) "u32@")                    ;; 904 len 4
  (data (i32.const 908) "i32@")                    ;; 908 len 4
  (data (i32.const 912) "u32!")                    ;; 912 len 4
  (data (i32.const 916) "bytes.fill")              ;; 916 len 10
  (data (i32.const 926) "bytes.copy")              ;; 926 len 10
  (data (i32.const 936) "value exceeds fixnum range") ;; 936 len 26
  ;; Region reclamation and strided fills. Both are generic memory facilities:
  ;; neither knows what a program stores, only where and how far apart.
  (data (i32.const 962) "heap.release")             ;; 962 len 12
  (data (i32.const 974) "bytes.fill-stride")        ;; 974 len 17
  (data (i32.const 991) "heap mark out of range")   ;; 991 len 22
  (data (i32.const 1013) "read error")               ;; 1013 len 10

  ;; Fail before a write crosses the current declared memory boundary. Use the
  ;; host import directly because $write may itself be buffering into the full
  ;; heap for to-string. Explicit growth remains capped at 4096 pages by both
  ;; the memory type and $max_pages.
  (func $ensure_space (param $end i32)
    (if (i32.gt_u (local.get $end) (i32.shl (memory.size) (i32.const 16)))
      (then
        (global.set $error_kind (i32.const 8))
        (global.set $error_data_ptr (i32.const 448))
        (global.set $error_data_len (i32.const 14))
        (call $host_write (i32.const 448) (i32.const 14))
        (call $host_write (i32.const 104) (i32.const 1))
        (unreachable))))

  ;; Unallocated bytes between the bump pointer and the end of memory.
  (func $heap_capacity (result i32)
    (i32.sub (i32.shl (memory.size) (i32.const 16)) (global.get $heap)))

  ;; Grow memory until at least $bytes remain allocatable, or fail truthfully.
  (func $heap_reserve (param $bytes i32) (result i32)
    (local $pages i32)
    (if (i32.lt_s (local.get $bytes) (i32.const 0))
      (then (call $err_static (i32.const 712) (i32.const 20)) (unreachable)))
    (if (i32.lt_u (call $heap_capacity) (local.get $bytes))
      (then
        (local.set $pages (i32.shr_u
          (i32.add (i32.sub (local.get $bytes) (call $heap_capacity)) (i32.const 65535))
          (i32.const 16)))
        (if (i32.gt_u (i32.add (memory.size) (local.get $pages)) (global.get $max_pages))
          (then (call $err_static (i32.const 712) (i32.const 20)) (unreachable)))
        (if (i32.eq (memory.grow (local.get $pages)) (i32.const -1))
          (then (call $err_static (i32.const 712) (i32.const 20)) (unreachable)))))
    (call $heap_capacity))

  ;; --- host-ingested assets ------------------------------------------------
  ;; Capacity is declared, never taken: a program states how many asset bytes
  ;; it is prepared to hold before the host may hand it any, exactly as it does
  ;; for heap memory. Backing memory is reserved at declaration time so the
  ;; allowance is not a promise the kernel cannot keep.
  (func $asset_reserve (param $bytes i32) (result i32)
    (local $need i32)
    (if (i32.lt_s (local.get $bytes) (i32.const 0))
      (then (call $err_static (i32.const 803) (i32.const 23)) (unreachable)))
    (local.set $need (i32.sub (local.get $bytes)
                              (i32.sub (global.get $asset_limit) (global.get $asset_used))))
    (if (i32.gt_s (local.get $need) (i32.const 0))
      (then
        (drop (call $heap_reserve (local.get $need)))
        (global.set $asset_limit (i32.add (global.get $asset_limit) (local.get $need)))))
    (i32.sub (global.get $asset_limit) (global.get $asset_used)))

  ;; Committed assets are addressed by a small integer handle rather than by a
  ;; raw pointer, so the identity a program holds survives any future change in
  ;; how the kernel stores them. The list is newest first.
  (func $asset_ref (param $handle i32) (result i32)
    (local $cur i32) (local $skip i32)
    (if (i32.or (i32.lt_s (local.get $handle) (i32.const 0))
                (i32.ge_s (local.get $handle) (global.get $asset_count)))
      (then (call $err_static (i32.const 826) (i32.const 25)) (unreachable)))
    (local.set $skip (i32.sub (i32.sub (global.get $asset_count) (i32.const 1)) (local.get $handle)))
    (local.set $cur (global.get $assets))
    (block $d (loop $l
      (br_if $d (i32.eqz (local.get $skip)))
      (local.set $cur (i32.load offset=8 (local.get $cur)))
      (local.set $skip (i32.sub (local.get $skip) (i32.const 1)))
      (br $l)))
    (i32.load offset=4 (local.get $cur)))

  ;; --- allocator: returns a 4-byte-aligned pointer ---
  (func $alloc (param $size i32) (result i32)
    (local $p i32) (local $end i32)
    (local.set $size (i32.and (i32.add (local.get $size) (i32.const 3)) (i32.const -4)))
    (local.set $p (global.get $heap))
    (local.set $end (i32.add (local.get $p) (local.get $size)))
    (if (i32.lt_u (local.get $end) (local.get $p))
      (then (call $ensure_space (i32.const -1))))
    (call $ensure_space (local.get $end))
    (global.set $heap (local.get $end))
    (local.get $p))

  (func $copy (param $dst i32) (param $src i32) (param $len i32)
    (local $i i32)
    (local.set $i (i32.const 0))
    (block $b (loop $l
      (br_if $b (i32.ge_u (local.get $i) (local.get $len)))
      (i32.store8 (i32.add (local.get $dst) (local.get $i))
                  (i32.load8_u (i32.add (local.get $src) (local.get $i))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $l))))

  ;; All output goes through $write; it either calls the host or, when
  ;; $out_buf is set, appends into that buffer (used by to-string).
  (func $write (param $ptr i32) (param $len i32)
    (if (global.get $out_buf)
      (then
        (call $ensure_space (i32.add (i32.add (global.get $out_buf) (global.get $out_len)) (local.get $len)))
        (call $copy (i32.add (global.get $out_buf) (global.get $out_len)) (local.get $ptr) (local.get $len))
        (global.set $out_len (i32.add (global.get $out_len) (local.get $len))))
      (else (call $host_write (local.get $ptr) (local.get $len)))))

  ;; --- constructors / accessors ---
  (func $mkfix (param $n i32) (result i32)
    (i32.or (i32.shl (local.get $n) (i32.const 1)) (i32.const 1)))

  (func $fixval (param $v i32) (result i32)
    (i32.shr_s (local.get $v) (i32.const 1)))

  ;; A fixnum carries a one-bit tag, so it holds 31 signed bits and cannot
  ;; represent every 32-bit word a file may contain. Reads that would lose the
  ;; top bit say so and trap instead of handing back a silently truncated
  ;; number, which is the failure a decoder would never notice.
  (func $mkfix_checked (param $n i32) (result i32)
    (if (i32.ne (i32.shr_s (i32.shl (local.get $n) (i32.const 1)) (i32.const 1))
                (local.get $n))
      (then (call $err_static (i32.const 936) (i32.const 26)) (unreachable)))
    (call $mkfix (local.get $n)))

  ;; Arithmetic folds check every intermediate in i64 space. Checking only the
  ;; final wrapped i32 would let a later operand disguise an earlier overflow.
  (func $fix_i64_checked (param $n i64) (result i32)
    (if (i32.or
          (i64.lt_s (local.get $n) (i64.const -1073741824))
          (i64.gt_s (local.get $n) (i64.const 1073741823)))
      (then (call $err_static (i32.const 936) (i32.const 26)) (unreachable)))
    (i32.wrap_i64 (local.get $n)))
  (func $fix_add_checked (param $a i32) (param $b i32) (result i32)
    (call $fix_i64_checked
      (i64.add (i64.extend_i32_s (local.get $a)) (i64.extend_i32_s (local.get $b)))))
  (func $fix_sub_checked (param $a i32) (param $b i32) (result i32)
    (call $fix_i64_checked
      (i64.sub (i64.extend_i32_s (local.get $a)) (i64.extend_i32_s (local.get $b)))))
  (func $fix_mul_checked (param $a i32) (param $b i32) (result i32)
    (call $fix_i64_checked
      (i64.mul (i64.extend_i32_s (local.get $a)) (i64.extend_i32_s (local.get $b)))))

  ;; The unsigned reading of the same word. A word whose top bits are set is a
  ;; large positive number here, not a small negative one, so it is rejected
  ;; where the signed check would have accepted it.
  (func $mkfix_unsigned (param $n i32) (result i32)
    (if (i32.gt_u (local.get $n) (i32.const 0x3FFFFFFF))
      (then (call $err_static (i32.const 936) (i32.const 26)) (unreachable)))
    (call $mkfix (local.get $n)))

  (func $cons (param $a i32) (param $d i32) (result i32)
    (local $p i32)
    (local.set $p (call $alloc (i32.const 12)))
    (i32.store          (local.get $p) (i32.const 2))
    (i32.store offset=4 (local.get $p) (local.get $a))
    (i32.store offset=8 (local.get $p) (local.get $d))
    (local.get $p))

  (func $is_pair (param $v i32) (result i32)
    (if (result i32) (i32.and (local.get $v) (i32.const 1))
      (then (i32.const 0))
      (else (i32.eq (i32.load (local.get $v)) (i32.const 2)))))

  ;; lenient car/cdr: of a non-pair -> nil
  (func $car (param $v i32) (result i32)
    (if (result i32) (call $is_pair (local.get $v))
      (then (i32.load offset=4 (local.get $v))) (else (global.get $nil))))
  (func $cdr (param $v i32) (result i32)
    (if (result i32) (call $is_pair (local.get $v))
      (then (i32.load offset=8 (local.get $v))) (else (global.get $nil))))

  (func $is_symbol (param $v i32) (result i32)
    (if (result i32) (i32.and (local.get $v) (i32.const 1))
      (then (i32.const 0))
      (else (i32.eq (i32.load (local.get $v)) (i32.const 3)))))
  (func $is_macro (param $v i32) (result i32)
    (if (result i32) (i32.and (local.get $v) (i32.const 1))
      (then (i32.const 0))
      (else (i32.eq (i32.load (local.get $v)) (i32.const 6)))))
  (func $has_tag (param $v i32) (param $t i32) (result i32)
    (if (result i32) (i32.and (local.get $v) (i32.const 1))
      (then (i32.const 0))
      (else (i32.eq (i32.load (local.get $v)) (local.get $t)))))
  (func $is_falsy (param $v i32) (result i32)
    (i32.or (i32.eq (local.get $v) (global.get $nil))
            (i32.eq (local.get $v) (global.get $false))))
  (func $bool (param $c i32) (result i32)
    (if (result i32) (local.get $c) (then (global.get $true)) (else (global.get $false))))
  (func $is_list (param $v i32) (result i32)
    (loop $l
      (if (i32.eq (local.get $v) (global.get $nil)) (then (return (i32.const 1))))
      (if (i32.eqz (call $is_pair (local.get $v))) (then (return (i32.const 0))))
      (local.set $v (i32.load offset=8 (local.get $v)))
      (br $l))
    (i32.const 0))

  ;; string [4, bytes-ptr, len] header over bytes already at $ptr
  (func $mkstr_hdr (param $ptr i32) (param $len i32) (result i32)
    (local $s i32)
    (local.set $s (call $alloc (i32.const 12)))
    (i32.store          (local.get $s) (i32.const 4))
    (i32.store offset=4 (local.get $s) (local.get $ptr))
    (i32.store offset=8 (local.get $s) (local.get $len))
    (local.get $s))
  ;; string from a copy of len bytes at $ptr
  (func $mkstr_copy (param $ptr i32) (param $len i32) (result i32)
    (local $b i32)
    (local.set $b (call $alloc (local.get $len)))
    (call $copy (local.get $b) (local.get $ptr) (local.get $len))
    (call $mkstr_hdr (local.get $b) (local.get $len)))
  ;; 1 if the bytes [subp,subl) occur within [sp,sl)
  (func $str_contains (param $sp i32) (param $sl i32) (param $subp i32) (param $subl i32) (result i32)
    (local $i i32)
    (if (i32.eqz (local.get $subl)) (then (return (i32.const 1))))
    (if (i32.gt_u (local.get $subl) (local.get $sl)) (then (return (i32.const 0))))
    (local.set $i (i32.const 0))
    (block $d (loop $l
      (br_if $d (i32.gt_u (local.get $i) (i32.sub (local.get $sl) (local.get $subl))))
      (if (call $bytes_eq (i32.add (local.get $sp) (local.get $i)) (local.get $subl) (local.get $subp) (local.get $subl))
        (then (return (i32.const 1))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $l)))
    (i32.const 0))

  ;; --- byte helpers ---
  (func $bytes_eq (param $a i32) (param $alen i32) (param $b i32) (param $blen i32) (result i32)
    (local $i i32)
    (if (i32.ne (local.get $alen) (local.get $blen)) (then (return (i32.const 0))))
    (local.set $i (i32.const 0))
    (block $d (loop $l
      (br_if $d (i32.ge_u (local.get $i) (local.get $alen)))
      (if (i32.ne (i32.load8_u (i32.add (local.get $a) (local.get $i)))
                  (i32.load8_u (i32.add (local.get $b) (local.get $i))))
        (then (return (i32.const 0))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $l)))
    (i32.const 1))

  ;; --- symbol interning ---
  (func $intern (param $ptr i32) (param $len i32) (result i32)
    (local $cur i32) (local $sym i32) (local $nptr i32)
    (local.set $cur (global.get $symlist))
    (block $end (loop $l
      (br_if $end (i32.eq (local.get $cur) (global.get $nil)))
      (if (call $bytes_eq (i32.load offset=4 (local.get $cur)) (i32.load offset=8 (local.get $cur))
                          (local.get $ptr) (local.get $len))
        (then (return (local.get $cur))))
      (local.set $cur (i32.load offset=12 (local.get $cur)))
      (br $l)))
    (local.set $nptr (call $alloc (local.get $len)))
    (call $copy (local.get $nptr) (local.get $ptr) (local.get $len))
    (local.set $sym (call $alloc (i32.const 16)))
    (i32.store           (local.get $sym) (i32.const 3))
    (i32.store offset=4  (local.get $sym) (local.get $nptr))
    (i32.store offset=8  (local.get $sym) (local.get $len))
    (i32.store offset=12 (local.get $sym) (global.get $symlist))
    (global.set $symlist (local.get $sym))
    (local.get $sym))

  (func $quote_sym (result i32) (call $intern (i32.const 128) (i32.const 5)))

  ;; --- errors (write message, then trap) ---
  (func $error_reset
    (global.set $error_kind (i32.const 0))
    (global.set $error_data_ptr (i32.const 0))
    (global.set $error_data_len (i32.const 0)))
  (func $error_data_set (param $ptr i32) (param $len i32)
    (global.set $error_data_ptr (local.get $ptr))
    (global.set $error_data_len (local.get $len)))
  ;; Compact category table for fixed diagnostics. The pointer names a static
  ;; seed-owned diagnostic, so it is also a stable, auditable dispatch key.
  (func $classify_static_error (param $ptr i32)
    (global.set $error_kind (i32.const 0))
    (if (i32.or
          (i32.eq (local.get $ptr) (i32.const 1013))
          (i32.or (i32.eq (local.get $ptr) (i32.const 477))
                  (i32.eq (local.get $ptr) (i32.const 496))))
      (then (global.set $error_kind (i32.const 2))))
    (if (i32.or
          (i32.eq (local.get $ptr) (i32.const 462))
          (i32.or
            (i32.eq (local.get $ptr) (i32.const 513))
            (i32.or (i32.eq (local.get $ptr) (i32.const 620))
                    (i32.eq (local.get $ptr) (i32.const 732)))))
      (then (global.set $error_kind (i32.const 4))))
    (if (i32.or
          (i32.eq (local.get $ptr) (i32.const 936))
          (i32.or (i32.eq (local.get $ptr) (i32.const 32))
                  (i32.eq (local.get $ptr) (i32.const 48))))
      (then (global.set $error_kind (i32.const 6))))
    (if (i32.or
          (i32.eq (local.get $ptr) (i32.const 826))
          (i32.or (i32.eq (local.get $ptr) (i32.const 640))
                  (i32.eq (local.get $ptr) (i32.const 991))))
      (then (global.set $error_kind (i32.const 7))))
    (if (i32.or (i32.eq (local.get $ptr) (i32.const 712))
                (i32.eq (local.get $ptr) (i32.const 803)))
      (then (global.set $error_kind (i32.const 8))))
    (if (i32.eq (local.get $ptr) (i32.const 851))
      (then (global.set $error_kind (i32.const 9))))
    (if (i32.eq (local.get $ptr) (i32.const 872))
      (then (global.set $error_kind (i32.const 10))))
  )
  (func $err_unbound (param $sym i32)
    (global.set $error_kind (i32.const 1))
    (call $error_data_set
      (i32.load offset=4 (local.get $sym))
      (i32.load offset=8 (local.get $sym)))
    (call $write (i32.const 184) (i32.const 9))
    (call $write (i32.load offset=4 (local.get $sym)) (i32.load offset=8 (local.get $sym)))
    (call $write (i32.const 104) (i32.const 1))
    (unreachable))
  (func $err_apply
    (global.set $error_kind (i32.const 5))
    (call $error_data_set (i32.const 193) (i32.const 12))
    (call $write (i32.const 193) (i32.const 12))
    (call $write (i32.const 104) (i32.const 1))
    (unreachable))
  (func $err_static (param $ptr i32) (param $len i32)
    (call $classify_static_error (local.get $ptr))
    (call $error_data_set (local.get $ptr) (local.get $len))
    (call $write (local.get $ptr) (local.get $len))
    (call $write (i32.const 104) (i32.const 1))
    (unreachable))
  (func $err_depth_cap
    (global.set $error_kind (i32.const 8))
    (call $error_data_set (i32.const 105) (i32.const 5))
    (call $write (i32.const 105) (i32.const 5))
    (call $write (i32.const 123) (i32.const 4))
    (call $write (i32.const 104) (i32.const 1))
    (unreachable))
  (func $err_work_cap
    (global.set $error_kind (i32.const 8))
    (call $error_data_set (i32.const 110) (i32.const 4))
    (call $write (i32.const 110) (i32.const 4))
    (call $write (i32.const 123) (i32.const 4))
    (call $write (i32.const 104) (i32.const 1))
    (unreachable))
  (func $err_macro_expansion_cap
    (global.set $error_kind (i32.const 8))
    (call $error_data_set (i32.const 114) (i32.const 9))
    (call $write (i32.const 163) (i32.const 5))
    (call $write (i32.const 73) (i32.const 1))
    (call $write (i32.const 114) (i32.const 9))
    (call $write (i32.const 123) (i32.const 4))
    (call $write (i32.const 104) (i32.const 1))
    (unreachable))
  (func $err_unquote_expected
    (global.set $error_kind (i32.const 3))
    (call $error_data_set (i32.const 219) (i32.const 7))
    (call $write (i32.const 219) (i32.const 7))
    (call $write (i32.const 73) (i32.const 1))
    (call $write (i32.const 469) (i32.const 8))
    (call $write (i32.const 104) (i32.const 1))
    (unreachable))
  (func $err_unquote_splicing_expected
    (global.set $error_kind (i32.const 3))
    (call $error_data_set (i32.const 226) (i32.const 16))
    (call $write (i32.const 226) (i32.const 16))
    (call $write (i32.const 73) (i32.const 1))
    (call $write (i32.const 469) (i32.const 8))
    (call $write (i32.const 104) (i32.const 1))
    (unreachable))
  (func $err_list_expected
    (global.set $error_kind (i32.const 4))
    (call $error_data_set (i32.const 205) (i32.const 4))
    (call $write (i32.const 205) (i32.const 4))
    (call $write (i32.const 73) (i32.const 1))
    (call $write (i32.const 469) (i32.const 8))
    (call $write (i32.const 104) (i32.const 1))
    (unreachable))
  (func $err_named_expected (param $name i32)
    (global.set $error_kind (i32.const 3))
    (if (call $is_symbol (local.get $name))
      (then
        (call $error_data_set
          (i32.load offset=4 (local.get $name))
          (i32.load offset=8 (local.get $name)))
        (call $write (i32.load offset=4 (local.get $name))
                     (i32.load offset=8 (local.get $name))))
      (else
        (call $error_data_set (i32.const 93) (i32.const 11))
        (call $write (i32.const 93) (i32.const 11))))
    (call $write (i32.const 73) (i32.const 1))
    (call $write (i32.const 469) (i32.const 8))
    (call $write (i32.const 104) (i32.const 1))
    (unreachable))
  (func $require_string (param $v i32) (result i32)
    (if (i32.eqz (call $has_tag (local.get $v) (i32.const 4)))
      (then (call $err_static (i32.const 462) (i32.const 15)) (unreachable)))
    (local.get $v))
  (func $require_number (param $v i32) (result i32)
    (if (i32.eqz (i32.and (local.get $v) (i32.const 1)))
      (then (call $err_static (i32.const 513) (i32.const 15)) (unreachable)))
    (local.get $v))
  ;; Every read path accepts both byte tags: an ingested asset is addressed by
  ;; exactly the accessors an allocated buffer is, so Lisp decoders need no
  ;; separate vocabulary for host-supplied data.
  (func $require_bytes (param $v i32) (result i32)
    (if (i32.and (i32.eqz (call $has_tag (local.get $v) (i32.const 10)))
                 (i32.eqz (call $has_tag (local.get $v) (i32.const 11))))
      (then (call $err_static (i32.const 620) (i32.const 20)) (unreachable)))
    (local.get $v))
  ;; Write paths refuse assets by name rather than by a generic type message,
  ;; so an attempt to mutate ingested data reads as the contract violation it
  ;; is instead of looking like a wrong argument.
  (func $require_mutable_bytes (param $v i32) (result i32)
    (if (call $has_tag (local.get $v) (i32.const 11))
      (then (call $err_static (i32.const 851) (i32.const 21)) (unreachable)))
    (call $require_bytes (local.get $v)))
  ;; The width is checked against the buffer before the index is, so neither
  ;; comparison can be made on an underflowed length. Subtracting the index
  ;; from the length first would wrap for any index past the end and let the
  ;; unsigned test pass, admitting an access well outside the buffer.
  (func $bytes_address (param $bytes i32) (param $index i32) (param $width i32) (result i32)
    (local $len i32)
    (local.set $bytes (call $require_bytes (local.get $bytes)))
    (local.set $len (i32.load offset=4 (local.get $bytes)))
    (if (i32.or (i32.lt_s (local.get $index) (i32.const 0))
        (i32.or (i32.gt_u (local.get $width) (local.get $len))
                (i32.gt_u (local.get $index) (i32.sub (local.get $len) (local.get $width)))))
      (then (call $err_static (i32.const 640) (i32.const 23)) (unreachable)))
    (i32.add (i32.add (local.get $bytes) (i32.const 8)) (local.get $index)))
  ;; Same bounds rule, but the immutability check comes first so mutating an
  ;; asset reports immutability rather than whichever index happened to be out
  ;; of range.
  (func $bytes_write_address (param $bytes i32) (param $index i32) (param $width i32) (result i32)
    (call $bytes_address (call $require_mutable_bytes (local.get $bytes))
                         (local.get $index) (local.get $width)))
  ;; Positional argument access. A chained car/cdr spelling stops being legible
  ;; somewhere around the third argument, and the block operations take five.
  (func $arg (param $args i32) (param $n i32) (result i32)
    (block $done (loop $l
      (br_if $done (i32.eqz (local.get $n)))
      (local.set $args (call $cdr (local.get $args)))
      (local.set $n (i32.sub (local.get $n) (i32.const 1)))
      (br $l)))
    (call $car (local.get $args)))
  (func $arg_num (param $args i32) (param $n i32) (result i32)
    (call $fixval (call $require_number (call $arg (local.get $args) (local.get $n)))))

  ;; --- printer ---
  (func $print_int (param $n i32)
    (local $i i32) (local $neg i32)
    (if (i32.eqz (local.get $n))
      (then
        (i32.store8 (i32.const 0) (i32.const 48))
        (call $write (i32.const 0) (i32.const 1))
        (return)))
    (local.set $neg (i32.lt_s (local.get $n) (i32.const 0)))
    (if (local.get $neg)
      (then (local.set $n (i32.sub (i32.const 0) (local.get $n)))))
    (local.set $i (i32.const 32))
    (block $b (loop $l
      (br_if $b (i32.eqz (local.get $n)))
      (local.set $i (i32.sub (local.get $i) (i32.const 1)))
      (i32.store8 (local.get $i)
                  (i32.add (i32.rem_u (local.get $n) (i32.const 10)) (i32.const 48)))
      (local.set $n (i32.div_u (local.get $n) (i32.const 10)))
      (br $l)))
    (if (local.get $neg)
      (then
        (local.set $i (i32.sub (local.get $i) (i32.const 1)))
        (i32.store8 (local.get $i) (i32.const 45))))
    (call $write (local.get $i) (i32.sub (i32.const 32) (local.get $i))))

  (func $print_pair (param $v i32)
    (local $cur i32)
    (call $write (i32.const 71) (i32.const 1))     ;; "("
    (local.set $cur (local.get $v))
    (block $end (loop $l
      (call $print (i32.load offset=4 (local.get $cur)))
      (local.set $cur (i32.load offset=8 (local.get $cur)))
      (br_if $end (i32.eq (local.get $cur) (global.get $nil)))
      (if (call $is_pair (local.get $cur))
        (then (call $write (i32.const 73) (i32.const 1)) (br $l))   ;; " "
        (else
          (call $write (i32.const 74) (i32.const 3))                ;; " . "
          (call $print (local.get $cur))
          (br $end)))))
    (call $write (i32.const 72) (i32.const 1)))     ;; ")"

  ;; DOM values cross a machine-readable boundary. Keep normal REPL output
  ;; compact and human-readable, but quote/escape string values here so the
  ;; browser can faithfully rebuild a tree from Lisp-owned text and attributes.
  (func $write_byte (param $c i32)
    (i32.store8 (i32.const 0) (local.get $c))
    (call $write (i32.const 0) (i32.const 1)))

  (func $write_hex_digit (param $n i32)
    (local $c i32)
    (local.set $c (i32.add (local.get $n) (i32.const 48)))
    (if (i32.gt_u (local.get $n) (i32.const 9))
      (then (local.set $c (i32.add (local.get $c) (i32.const 39)))))
    (call $write_byte (local.get $c)))

  (func $print_dom_string (param $ptr i32) (param $len i32)
    (local $i i32) (local $c i32)
    (call $write_byte (i32.const 34)) ;; "
    (local.set $i (i32.const 0))
    (block $done (loop $l
      (br_if $done (i32.ge_u (local.get $i) (local.get $len)))
      (local.set $c (i32.load8_u (i32.add (local.get $ptr) (local.get $i))))
      (if (i32.or (i32.eq (local.get $c) (i32.const 34)) (i32.eq (local.get $c) (i32.const 92)))
        (then (call $write_byte (i32.const 92)) (call $write_byte (local.get $c)))
        (else (if (i32.eq (local.get $c) (i32.const 10))
                (then (call $write_byte (i32.const 92)) (call $write_byte (i32.const 110)))
                (else (if (i32.eq (local.get $c) (i32.const 13))
                        (then (call $write_byte (i32.const 92)) (call $write_byte (i32.const 114)))
                        (else (if (i32.eq (local.get $c) (i32.const 9))
                                (then (call $write_byte (i32.const 92)) (call $write_byte (i32.const 116)))
                                (else (if (i32.eq (local.get $c) (i32.const 8))
                                        (then (call $write_byte (i32.const 92)) (call $write_byte (i32.const 98)))
                                        (else (if (i32.eq (local.get $c) (i32.const 12))
                                                (then (call $write_byte (i32.const 92)) (call $write_byte (i32.const 102)))
                                                (else (if (i32.lt_u (local.get $c) (i32.const 32))
                                                        (then
                                                          (call $write_byte (i32.const 92))
                                                          (call $write_byte (i32.const 117))
                                                          (call $write_byte (i32.const 48))
                                                          (call $write_byte (i32.const 48))
                                                          (call $write_hex_digit (i32.shr_u (local.get $c) (i32.const 4)))
                                                          (call $write_hex_digit (i32.and (local.get $c) (i32.const 15))))
                                                        (else (call $write_byte (local.get $c))))))))))))))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $l)))
    (call $write_byte (i32.const 34)))

  (func $print_dom_pair (param $v i32)
    (local $cur i32)
    (call $write (i32.const 71) (i32.const 1))
    (local.set $cur (local.get $v))
    (block $end (loop $l
      (call $print_dom (i32.load offset=4 (local.get $cur)))
      (local.set $cur (i32.load offset=8 (local.get $cur)))
      (br_if $end (i32.eq (local.get $cur) (global.get $nil)))
      (if (call $is_pair (local.get $cur))
        (then (call $write (i32.const 73) (i32.const 1)) (br $l))
        (else
          (call $write (i32.const 74) (i32.const 3))
          (call $print_dom (local.get $cur))
          (br $end)))))
    (call $write (i32.const 72) (i32.const 1)))

  (func $print_dom (param $v i32)
    (local $t i32)
    (if (i32.and (local.get $v) (i32.const 1))
      (then (call $print_int (i32.shr_s (local.get $v) (i32.const 1))) (return)))
    (local.set $t (i32.load (local.get $v)))
    (if (i32.eq (local.get $t) (i32.const 0))
      (then (call $write (i32.const 64) (i32.const 3)) (return)))
    (if (i32.eq (local.get $t) (i32.const 1))
      (then (call $write (i32.const 67) (i32.const 4)) (return)))
    (if (i32.eq (local.get $t) (i32.const 2))
      (then (call $print_dom_pair (local.get $v)) (return)))
    (if (i32.eq (local.get $t) (i32.const 3))
      (then (call $write (i32.load offset=4 (local.get $v))
                         (i32.load offset=8 (local.get $v))) (return)))
    (if (i32.eq (local.get $t) (i32.const 4))
      (then (call $print_dom_string (i32.load offset=4 (local.get $v))
                                    (i32.load offset=8 (local.get $v))) (return)))
    (call $print (local.get $v)))

  (func $print (param $v i32)
    (local $t i32)
    (if (i32.and (local.get $v) (i32.const 1))
      (then (call $print_int (i32.shr_s (local.get $v) (i32.const 1))) (return)))
    (local.set $t (i32.load (local.get $v)))
    (if (i32.eq (local.get $t) (i32.const 0))
      (then (call $write (i32.const 64) (i32.const 3)) (return)))
    (if (i32.eq (local.get $t) (i32.const 1))
      (then (call $write (i32.const 67) (i32.const 4)) (return)))
    (if (i32.eq (local.get $t) (i32.const 2))
      (then (call $print_pair (local.get $v)) (return)))
    (if (i32.eq (local.get $t) (i32.const 3))
      (then (call $write (i32.load offset=4 (local.get $v))
                         (i32.load offset=8 (local.get $v))) (return)))
    (if (i32.eq (local.get $t) (i32.const 4))
      (then (call $write (i32.load offset=4 (local.get $v))
                         (i32.load offset=8 (local.get $v))) (return)))
    (if (i32.eq (local.get $t) (i32.const 5))
      (then (call $write (i32.const 77) (i32.const 9)) (return)))
    (if (i32.eq (local.get $t) (i32.const 6))
      (then (call $write (i32.const 86) (i32.const 7)) (return)))
    (if (i32.eq (local.get $t) (i32.const 9))
      (then (call $write (i32.const 250) (i32.const 5)) (return)))   ;; "false"
    (if (i32.eq (local.get $t) (i32.const 10))
      (then (call $write (i32.const 664) (i32.const 7)) (return)))
    (if (i32.eq (local.get $t) (i32.const 11))
      (then (call $write (i32.const 796) (i32.const 7)) (return)))
    (call $write (i32.const 93) (i32.const 11)))

  (func $println (param $v i32)
    (call $print (local.get $v))
    (call $write (i32.const 104) (i32.const 1)))

  ;; --- reader ---
  (func $reader_reset
    (global.set $read_depth (i32.const 0))
    (global.set $read_work (i32.const 0)))

  (func $reader_enter
    (if (i32.ge_u (global.get $read_depth) (global.get $read_depth_limit))
      (then (call $err_depth_cap) (unreachable)))
    (if (i32.ge_u (global.get $read_work) (global.get $read_work_limit))
      (then (call $err_work_cap) (unreachable)))
    (global.set $read_depth (i32.add (global.get $read_depth) (i32.const 1)))
    (global.set $read_work (i32.add (global.get $read_work) (i32.const 1))))

  (func $reader_leave
    (global.set $read_depth (i32.sub (global.get $read_depth) (i32.const 1))))

  (func $require_read_value (param $value i32) (result i32)
    (if (i32.eq (local.get $value) (global.get $eof))
      (then (call $err_static (i32.const 1013) (i32.const 10)) (unreachable)))
    (local.get $value))

  (func $is_delim (param $c i32) (result i32)
    (i32.or (i32.le_u (local.get $c) (i32.const 32))
     (i32.or (i32.eq (local.get $c) (i32.const 40))   ;; (
      (i32.or (i32.eq (local.get $c) (i32.const 41))  ;; )
       (i32.or (i32.eq (local.get $c) (i32.const 39)) ;; '
        (i32.or (i32.eq (local.get $c) (i32.const 34)) ;; "
         (i32.or (i32.eq (local.get $c) (i32.const 59)) ;; ;
          (i32.or (i32.eq (local.get $c) (i32.const 96))  ;; `
                  (i32.eq (local.get $c) (i32.const 44)))))))))) ;; ,

  (func $skip_ws
    (local $c i32)
    (block $done (loop $l
      (br_if $done (i32.ge_u (global.get $rp) (global.get $rend)))
      (local.set $c (i32.load8_u (global.get $rp)))
      (if (i32.le_u (local.get $c) (i32.const 32))
        (then (global.set $rp (i32.add (global.get $rp) (i32.const 1))) (br $l)))
      (if (i32.eq (local.get $c) (i32.const 59))   ;; ';' comment to end of line
        (then
          (block $eol (loop $l2
            (br_if $done (i32.ge_u (global.get $rp) (global.get $rend)))
            (br_if $eol (i32.eq (i32.load8_u (global.get $rp)) (i32.const 10)))
            (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
            (br $l2)))
          (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
          (br $l)))
      (br $done))))

  (func $is_integer (param $p i32) (param $len i32) (result i32)
    (local $i i32) (local $c i32)
    (if (i32.eqz (local.get $len)) (then (return (i32.const 0))))
    (local.set $i (i32.const 0))
    (local.set $c (i32.load8_u (local.get $p)))
    (if (i32.or (i32.eq (local.get $c) (i32.const 43)) (i32.eq (local.get $c) (i32.const 45)))
      (then
        (if (i32.eq (local.get $len) (i32.const 1)) (then (return (i32.const 0))))
        (local.set $i (i32.const 1))))
    (block $d (loop $l
      (br_if $d (i32.ge_u (local.get $i) (local.get $len)))
      (local.set $c (i32.load8_u (i32.add (local.get $p) (local.get $i))))
      (if (i32.or (i32.lt_u (local.get $c) (i32.const 48)) (i32.gt_u (local.get $c) (i32.const 57)))
        (then (return (i32.const 0))))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $l)))
    (i32.const 1))

  (func $parse_int (param $p i32) (param $len i32) (result i32)
    (local $i i32) (local $neg i32) (local $acc i32) (local $c i32)
    (local $digit i32) (local $limit i32)
    (local.set $i (i32.const 0)) (local.set $neg (i32.const 0)) (local.set $acc (i32.const 0))
    (local.set $c (i32.load8_u (local.get $p)))
    (if (i32.eq (local.get $c) (i32.const 45)) (then (local.set $neg (i32.const 1)) (local.set $i (i32.const 1))))
    (if (i32.eq (local.get $c) (i32.const 43)) (then (local.set $i (i32.const 1))))
    (local.set $limit
      (if (result i32) (local.get $neg)
        (then (i32.const 1073741824))
        (else (i32.const 1073741823))))
    (block $d (loop $l
      (br_if $d (i32.ge_u (local.get $i) (local.get $len)))
      (local.set $digit
        (i32.sub (i32.load8_u (i32.add (local.get $p) (local.get $i))) (i32.const 48)))
      (if (i32.gt_u
            (local.get $acc)
            (i32.div_u (i32.sub (local.get $limit) (local.get $digit)) (i32.const 10)))
        (then (call $err_static (i32.const 936) (i32.const 26)) (unreachable)))
      (local.set $acc (i32.add (i32.mul (local.get $acc) (i32.const 10)) (local.get $digit)))
      (local.set $i (i32.add (local.get $i) (i32.const 1)))
      (br $l)))
    (if (local.get $neg) (then (local.set $acc (i32.sub (i32.const 0) (local.get $acc)))))
    (local.get $acc))

  (func $read_atom (result i32)
    (local $start i32) (local $len i32)
    (local.set $start (global.get $rp))
    (block $done (loop $l
      (br_if $done (i32.ge_u (global.get $rp) (global.get $rend)))
      (br_if $done (call $is_delim (i32.load8_u (global.get $rp))))
      (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
      (br $l)))
    (local.set $len (i32.sub (global.get $rp) (local.get $start)))
    (if (call $bytes_eq (local.get $start) (local.get $len) (i32.const 64) (i32.const 3))
      (then (return (global.get $nil))))
    (if (call $bytes_eq (local.get $start) (local.get $len) (i32.const 67) (i32.const 4))
      (then (return (global.get $true))))
    (if (call $bytes_eq (local.get $start) (local.get $len) (i32.const 250) (i32.const 5))
      (then (return (global.get $false))))
    (if (call $is_integer (local.get $start) (local.get $len))
      (then (return (call $mkfix (call $parse_int (local.get $start) (local.get $len))))))
    (call $intern (local.get $start) (local.get $len)))

  ;; Canonical DOM strings emit lower-case \u00xx for control bytes. Return a
  ;; nibble for either hex case, or -1 when the byte is not hexadecimal.
  (func $hex_value (param $c i32) (result i32)
    (if (result i32)
      (i32.and (i32.ge_u (local.get $c) (i32.const 48))
               (i32.le_u (local.get $c) (i32.const 57)))
      (then (i32.sub (local.get $c) (i32.const 48)))
      (else (if (result i32)
        (i32.and (i32.ge_u (local.get $c) (i32.const 97))
                 (i32.le_u (local.get $c) (i32.const 102)))
        (then (i32.sub (local.get $c) (i32.const 87)))
        (else (if (result i32)
          (i32.and (i32.ge_u (local.get $c) (i32.const 65))
                   (i32.le_u (local.get $c) (i32.const 70)))
          (then (i32.sub (local.get $c) (i32.const 55)))
          (else (i32.const -1))))))))

  (func $read_string (result i32)
    (local $start i32) (local $n i32) (local $c i32) (local $s i32)
    (local $hi i32) (local $lo i32)
    (global.set $rp (i32.add (global.get $rp) (i32.const 1)))   ;; skip opening "
    (local.set $start (global.get $heap))
    (local.set $n (i32.const 0))
    (block $done (loop $l
      (br_if $done (i32.ge_u (global.get $rp) (global.get $rend)))
      (local.set $c (i32.load8_u (global.get $rp)))
      (br_if $done (i32.eq (local.get $c) (i32.const 34)))      ;; closing "
      (if (i32.eq (local.get $c) (i32.const 92))                ;; backslash
        (then
          (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
          (br_if $done (i32.ge_u (global.get $rp) (global.get $rend)))
          (local.set $c (i32.load8_u (global.get $rp)))
          (if (i32.eq (local.get $c) (i32.const 110)) (then (local.set $c (i32.const 10)))      ;; \n
            (else (if (i32.eq (local.get $c) (i32.const 116)) (then (local.set $c (i32.const 9))) ;; \t
              (else (if (i32.eq (local.get $c) (i32.const 114)) (then (local.set $c (i32.const 13))) ;; \r
                (else (if (i32.eq (local.get $c) (i32.const 98)) (then (local.set $c (i32.const 8))) ;; \b
                  (else (if (i32.eq (local.get $c) (i32.const 102)) (then (local.set $c (i32.const 12))) ;; \f
                    (else (if (i32.and (i32.eq (local.get $c) (i32.const 117)) ;; \u00xx
                                           (i32.lt_u (i32.add (global.get $rp) (i32.const 4))
                                                     (global.get $rend)))
                      (then
                        (if (i32.and
                              (i32.eq (i32.load8_u offset=1 (global.get $rp)) (i32.const 48))
                              (i32.eq (i32.load8_u offset=2 (global.get $rp)) (i32.const 48)))
                          (then
                            (local.set $hi (call $hex_value (i32.load8_u offset=3 (global.get $rp))))
                            (local.set $lo (call $hex_value (i32.load8_u offset=4 (global.get $rp))))
                            (if (i32.and (i32.ge_s (local.get $hi) (i32.const 0))
                                         (i32.ge_s (local.get $lo) (i32.const 0)))
                              (then
                                (local.set $c (i32.or (i32.shl (local.get $hi) (i32.const 4))
                                                      (local.get $lo)))
                                (global.set $rp (i32.add (global.get $rp) (i32.const 4)))))))))))))))))))))
      (call $ensure_space (i32.add (i32.add (local.get $start) (local.get $n)) (i32.const 1)))
      (i32.store8 (i32.add (local.get $start) (local.get $n)) (local.get $c))
      (local.set $n (i32.add (local.get $n) (i32.const 1)))
      (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
      (br $l)))
    (if (i32.ge_u (global.get $rp) (global.get $rend))
      (then (call $err_static (i32.const 477) (i32.const 19)) (unreachable)))
    (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
    (global.set $heap (i32.and (i32.add (i32.add (local.get $start) (local.get $n)) (i32.const 3)) (i32.const -4)))
    (local.set $s (call $alloc (i32.const 12)))
    (i32.store          (local.get $s) (i32.const 4))
    (i32.store offset=4 (local.get $s) (local.get $start))
    (i32.store offset=8 (local.get $s) (local.get $n))
    (local.get $s))

  (func $read_list (param $can_dot i32) (result i32)
    (local $value i32)
    (call $reader_enter)
    (local.set $value (call $read_list_inner (local.get $can_dot)))
    (call $reader_leave)
    (local.get $value))

  (func $read_list_inner (param $can_dot i32) (result i32)
    (local $car i32) (local $cdr i32)
    (call $skip_ws)
    (if (i32.ge_u (global.get $rp) (global.get $rend))
      (then (call $err_static (i32.const 496) (i32.const 17)) (unreachable)))
    (if (i32.eq (i32.load8_u (global.get $rp)) (i32.const 41))  ;; ')'
      (then (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
            (return (global.get $nil))))
    ;; dotted tail: a standalone '.' -> read the cdr directly, then expect ')'
    (if (i32.eq (i32.load8_u (global.get $rp)) (i32.const 46))  ;; '.'
      (then (if (i32.or (i32.ge_u (i32.add (global.get $rp) (i32.const 1)) (global.get $rend))
                        (call $is_delim (i32.load8_u (i32.add (global.get $rp) (i32.const 1)))))
              (then
                (if (i32.eqz (local.get $can_dot))
                  (then (call $err_static (i32.const 1013) (i32.const 10)) (unreachable)))
                (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
                (local.set $cdr (call $require_read_value (call $read1)))
                (call $skip_ws)
                (if (i32.or (i32.ge_u (global.get $rp) (global.get $rend))
                            (i32.ne (i32.load8_u (global.get $rp)) (i32.const 41)))
                  (then (call $err_static (i32.const 1013) (i32.const 10)) (unreachable)))
                (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
                (return (local.get $cdr))))))
    (local.set $car (call $read1))
    (local.set $cdr (call $read_list (i32.const 1)))
    (call $cons (local.get $car) (local.get $cdr)))

  (func $read1 (result i32)
    (local $value i32)
    ;; An export probes once after the final form to discover EOF. Whitespace
    ;; scanning is byte-bounded already; do not charge a nonexistent form as a
    ;; reader frame/work unit.
    (call $skip_ws)
    (if (i32.ge_u (global.get $rp) (global.get $rend))
      (then (return (global.get $eof))))
    (call $reader_enter)
    (local.set $value (call $read1_inner))
    (call $reader_leave)
    (local.get $value))

  (func $read1_inner (result i32)
    (local $c i32) (local $x i32)
    (call $skip_ws)
    (if (i32.ge_u (global.get $rp) (global.get $rend)) (then (return (global.get $eof))))
    (local.set $c (i32.load8_u (global.get $rp)))
    (if (i32.eq (local.get $c) (i32.const 40))   ;; '('
      (then (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
            (return (call $read_list (i32.const 0)))))
    (if (i32.eq (local.get $c) (i32.const 41))   ;; ')' outside its owning list
      (then (call $err_static (i32.const 1013) (i32.const 10)) (unreachable)))
    (if (i32.eq (local.get $c) (i32.const 39))   ;; '\''
      (then (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
            (local.set $x (call $require_read_value (call $read1)))
            (return (call $cons (call $quote_sym)
                            (call $cons (local.get $x) (global.get $nil))))))
    (if (i32.eq (local.get $c) (i32.const 96))   ;; '`' quasiquote
      (then (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
            (local.set $x (call $require_read_value (call $read1)))
            (return (call $cons (global.get $sym_qq)
                            (call $cons (local.get $x) (global.get $nil))))))
    (if (i32.eq (local.get $c) (i32.const 44))   ;; ',' unquote / ',@' splice
      (then
        (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
        (return (if (result i32)
                    (i32.and (i32.lt_u (global.get $rp) (global.get $rend))
                             (i32.eq (i32.load8_u (global.get $rp)) (i32.const 64))) ;; '@'
                  (then
                    (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
                    (local.set $x (call $require_read_value (call $read1)))
                    (call $cons (global.get $sym_uqs)
                          (call $cons (local.get $x) (global.get $nil))))
                  (else
                    (local.set $x (call $require_read_value (call $read1)))
                    (call $cons (global.get $sym_uq)
                          (call $cons (local.get $x) (global.get $nil))))))))
    (if (i32.eq (local.get $c) (i32.const 34))   ;; '"'
      (then (return (call $read_string))))
    (call $read_atom))

  ;; --- environments ---
  (func $env_define (param $env i32) (param $sym i32) (param $val i32)
    (i32.store offset=4 (local.get $env)
      (call $cons (call $cons (local.get $sym) (local.get $val))
                  (i32.load offset=4 (local.get $env)))))

  ;; Return the binding cell for $sym, or 0 when it is unbound. Zero can never
  ;; be a live object because the heap starts above the fixed input region.
  (func $lookup_cell (param $env i32) (param $sym i32) (result i32)
    (local $e i32) (local $frame i32) (local $entry i32)
    (local.set $e (local.get $env))
    (block $notfound (loop $l
      (br_if $notfound (i32.eq (local.get $e) (global.get $nil)))
      (local.set $frame (i32.load offset=4 (local.get $e)))
      (block $framedone (loop $fl
        (br_if $framedone (i32.eq (local.get $frame) (global.get $nil)))
        (local.set $entry (i32.load offset=4 (local.get $frame)))
        (if (i32.eq (i32.load offset=4 (local.get $entry)) (local.get $sym))
          (then (return (local.get $entry))))
        (local.set $frame (i32.load offset=8 (local.get $frame)))
        (br $fl)))
      (local.set $e (i32.load offset=8 (local.get $e)))
      (br $l)))
    (i32.const 0))

  (func $lookup (param $env i32) (param $sym i32) (result i32)
    (local $entry i32)
    (local.set $entry (call $lookup_cell (local.get $env) (local.get $sym)))
    (if (i32.eqz (local.get $entry))
      (then (call $err_unbound (local.get $sym)) (unreachable)))
    (i32.load offset=8 (local.get $entry)))

  (func $set_bang (param $env i32) (param $sym i32) (param $val i32) (result i32)
    (local $entry i32)
    (local.set $entry (call $lookup_cell (local.get $env) (local.get $sym)))
    (if (i32.eqz (local.get $entry))
      (then (call $err_unbound (local.get $sym)) (unreachable)))
    (i32.store offset=8 (local.get $entry) (local.get $val))
    (local.get $val))

  (func $defprim (param $nameptr i32) (param $namelen i32) (param $id i32)
    (local $p i32)
    (local.set $p (call $alloc (i32.const 8)))
    (i32.store          (local.get $p) (i32.const 7))
    (i32.store offset=4 (local.get $p) (local.get $id))
    (call $env_define (global.get $genv)
          (call $intern (local.get $nameptr) (local.get $namelen))
          (local.get $p)))

  ;; --- eval / apply ---
  (func $make_clo (param $tag i32) (param $params i32) (param $body i32) (param $env i32) (result i32)
    (local $c i32)
    (local.set $c (call $alloc (i32.const 16)))
    (i32.store           (local.get $c) (local.get $tag))
    (i32.store offset=4  (local.get $c) (local.get $params))
    (i32.store offset=8  (local.get $c) (local.get $body))
    (i32.store offset=12 (local.get $c) (local.get $env))
    (local.get $c))

  (func $eval_list (param $forms i32) (param $env i32) (result i32)
    (local $h i32)
    (if (i32.eq (local.get $forms) (global.get $nil)) (then (return (global.get $nil))))
    (local.set $h (call $eval (i32.load offset=4 (local.get $forms)) (local.get $env)))
    (call $cons (local.get $h) (call $eval_list (i32.load offset=8 (local.get $forms)) (local.get $env))))

  ;; Evaluate every form of a non-empty body except the last, then hand the
  ;; last one back unevaluated so the caller can treat it as a tail position.
  (func $eval_but_last (param $forms i32) (param $env i32) (result i32)
    (block $d (loop $l
      (br_if $d (i32.eq (i32.load offset=8 (local.get $forms)) (global.get $nil)))
      (drop (call $eval (i32.load offset=4 (local.get $forms)) (local.get $env)))
      (local.set $forms (i32.load offset=8 (local.get $forms)))
      (br $l)))
    (i32.load offset=4 (local.get $forms)))

  (func $eval_seq (param $forms i32) (param $env i32) (result i32)
    (local $r i32)
    (local.set $r (global.get $nil))
    (block $d (loop $l
      (br_if $d (i32.eq (local.get $forms) (global.get $nil)))
      (local.set $r (call $eval (i32.load offset=4 (local.get $forms)) (local.get $env)))
      (local.set $forms (i32.load offset=8 (local.get $forms)))
      (br $l)))
    (local.get $r))

  (func $eval_define (param $expr i32) (param $env i32) (result i32)
    (local $rest i32) (local $name i32) (local $val i32)
    (local.set $rest (i32.load offset=8 (local.get $expr)))             ;; (name value)
    (local.set $name (i32.load offset=4 (local.get $rest)))
    (local.set $val (call $eval (i32.load offset=4 (i32.load offset=8 (local.get $rest))) (local.get $env)))
    (call $env_define (local.get $env) (local.get $name) (local.get $val))
    (local.get $val))

  ;; Bind a closure/macro's params to args in a fresh env and return that env.
  ;; params may be: a proper list (fixed arity), a bare symbol (whole arg list),
  ;; or a dotted tail (a symbol reached mid-list -> bind remaining args).
  (func $bind_params (param $fn i32) (param $args i32) (param $name i32) (result i32)
    (local $nenv i32) (local $params i32) (local $a i32) (local $param i32)
    (local.set $nenv (call $cons (global.get $nil) (i32.load offset=12 (local.get $fn))))
    (local.set $params (i32.load offset=4 (local.get $fn)))
    (local.set $a (local.get $args))
    (block $bind (loop $bl
      (if (call $is_symbol (local.get $params))
        (then (call $env_define (local.get $nenv) (local.get $params) (local.get $a))
              (br $bind)))
      (if (i32.eq (local.get $params) (global.get $nil))
        (then
          (if (i32.ne (local.get $a) (global.get $nil))
            (then (call $err_named_expected (local.get $name)) (unreachable)))
          (br $bind)))
      (if (i32.or (i32.eqz (call $is_pair (local.get $params)))
                  (i32.eqz (call $is_pair (local.get $a))))
        (then (call $err_named_expected (local.get $name)) (unreachable)))
      (local.set $param (i32.load offset=4 (local.get $params)))
      (if (i32.eqz (call $is_symbol (local.get $param)))
        (then (call $err_named_expected (local.get $name)) (unreachable)))
      (call $env_define (local.get $nenv)
            (local.get $param)
            (call $car (local.get $a)))
      (local.set $params (i32.load offset=8 (local.get $params)))
      (local.set $a (call $cdr (local.get $a)))
      (br $bl)))
    (local.get $nenv))

  ;; Macro expansion is not a tail position, so it keeps a plain recursive
  ;; body evaluation; tail calls in ordinary code are handled inside $eval.
  (func $apply_user (param $fn i32) (param $args i32) (param $name i32) (result i32)
    (call $eval_seq (i32.load offset=8 (local.get $fn))
                    (call $bind_params (local.get $fn) (local.get $args) (local.get $name))))

  ;; Expand named macros at the outermost position until the head is no longer
  ;; a macro. Unlike evaluation, this inspection path never evaluates a
  ;; computed operator or the form produced by a macro. Macro bodies still run
  ;; through the same closure application used by $eval, including their
  ;; captured lexical environment.
  (func $macroexpand_outer (param $expr i32) (param $env i32) (result i32)
    (local $head i32) (local $entry i32) (local $fn i32) (local $steps i32)
    (loop $again
      (if (i32.eqz (call $is_pair (local.get $expr)))
        (then (return (local.get $expr))))
      (local.set $head (i32.load offset=4 (local.get $expr)))
      (if (i32.eqz (call $is_symbol (local.get $head)))
        (then (return (local.get $expr))))
      (local.set $entry (call $lookup_cell (local.get $env) (local.get $head)))
      (if (i32.eqz (local.get $entry))
        (then (return (local.get $expr))))
      (local.set $fn (i32.load offset=8 (local.get $entry)))
      (if (i32.eqz (call $is_macro (local.get $fn)))
        (then (return (local.get $expr))))
      (if (i32.ge_u (local.get $steps) (i32.const 1024))
        (then (call $err_macro_expansion_cap) (unreachable)))
      (local.set $steps (i32.add (local.get $steps) (i32.const 1)))
      (local.set $expr
        (call $apply_user (local.get $fn) (i32.load offset=8 (local.get $expr)) (local.get $head)))
      (br $again))
    (unreachable))

  ;; kernel-level append: elements of list a, then b (b may be any value)
  (func $lappend (param $a i32) (param $b i32) (result i32)
    (if (result i32) (call $is_pair (local.get $a))
      (then (call $cons (i32.load offset=4 (local.get $a))
                        (call $lappend (i32.load offset=8 (local.get $a)) (local.get $b))))
      (else (local.get $b))))

  ;; Return the sole operand of an unquote form, rejecting malformed arity.
  (func $qq_arg (param $form i32) (param $splice i32) (result i32)
    (local $rest i32)
    (local.set $rest (i32.load offset=8 (local.get $form)))
    (if (i32.or
          (i32.eqz (call $is_pair (local.get $rest)))
          (i32.ne (call $cdr (local.get $rest)) (global.get $nil)))
      (then
        (if (local.get $splice)
          (then (call $err_unquote_splicing_expected) (unreachable))
          (else (call $err_unquote_expected) (unreachable)))))
    (i32.load offset=4 (local.get $rest)))

  ;; Quasiquote walks with explicit nesting depth. An unquote is active only
  ;; at its matching depth; splicing is valid only in list-element position
  ;; and its evaluated value must be a proper list.
  (func $qq_eval (param $x i32) (param $env i32) (param $depth i32) (result i32)
    (local $h i32) (local $arg i32) (local $spliced i32)
    (if (i32.eqz (call $is_pair (local.get $x))) (then (return (local.get $x))))
    (local.set $h (i32.load offset=4 (local.get $x)))
    (if (i32.eq (local.get $h) (global.get $sym_qq))
      (then (return (call $cons (local.get $h)
                      (call $qq_eval (i32.load offset=8 (local.get $x))
                                     (local.get $env)
                                     (i32.add (local.get $depth) (i32.const 1)))))))
    (if (i32.eq (local.get $h) (global.get $sym_uq))
      (then
        (local.set $arg (call $qq_arg (local.get $x) (i32.const 0)))
        (if (i32.eq (local.get $depth) (i32.const 1))
          (then (return (call $eval (local.get $arg) (local.get $env)))))
        (return (call $cons (local.get $h)
                  (call $cons
                    (call $qq_eval (local.get $arg) (local.get $env)
                                   (i32.sub (local.get $depth) (i32.const 1)))
                    (global.get $nil))))))
    (if (i32.eq (local.get $h) (global.get $sym_uqs))
      (then
        (local.set $arg (call $qq_arg (local.get $x) (i32.const 1)))
        (if (i32.eq (local.get $depth) (i32.const 1))
          (then (call $err_unquote_splicing_expected) (unreachable)))
        (return (call $cons (local.get $h)
                  (call $cons
                    (call $qq_eval (local.get $arg) (local.get $env)
                                   (i32.sub (local.get $depth) (i32.const 1)))
                    (global.get $nil))))))
    (if (call $is_pair (local.get $h))
      (then (if (i32.and
                  (i32.eq (local.get $depth) (i32.const 1))
                  (i32.eq (i32.load offset=4 (local.get $h)) (global.get $sym_uqs)))
              (then
                (local.set $arg (call $qq_arg (local.get $h) (i32.const 1)))
                (local.set $spliced (call $eval (local.get $arg) (local.get $env)))
                (if (i32.eqz (call $is_list (local.get $spliced)))
                  (then (call $err_list_expected) (unreachable)))
                (return (call $lappend
                          (local.get $spliced)
                          (call $qq_eval (i32.load offset=8 (local.get $x))
                                         (local.get $env) (local.get $depth))))))))
    (call $cons
      (call $qq_eval (i32.load offset=4 (local.get $x)) (local.get $env) (local.get $depth))
      (call $qq_eval (i32.load offset=8 (local.get $x)) (local.get $env) (local.get $depth))))

  ;; Evaluation is a trampoline rather than a recursion over tail positions.
  ;; `if` branches, the final form of `begin` and of a closure body, and a
  ;; macro expansion all rewrite $expr/$env and continue this loop, so a Lisp
  ;; program that recurses in tail position runs in constant host stack space
  ;; and its step count is bounded by the heap, not by the JS/Wasm stack.
  ;; Non-tail positions (arguments, `define` values, macro bodies, quasiquote)
  ;; still recurse, which is what gives the language its ordinary call depth.
  (func $eval (param $expr i32) (param $env i32) (result i32)
    (local $t i32) (local $head i32) (local $fn i32) (local $rest i32) (local $body i32) (local $call_name i32)
    (loop $tail
      (if (i32.and (local.get $expr) (i32.const 1)) (then (return (local.get $expr))))  ;; fixnum
      (local.set $t (i32.load (local.get $expr)))
      (if (i32.eq (local.get $t) (i32.const 3))   ;; symbol -> lookup
        (then (return (call $lookup (local.get $env) (local.get $expr)))))
      (if (i32.ne (local.get $t) (i32.const 2))   ;; non-pair self-evaluates (nil/true/string/...)
        (then (return (local.get $expr))))
      (local.set $head (i32.load offset=4 (local.get $expr)))
      (if (i32.eq (local.get $head) (global.get $sym_quote))
        (then
          (call $require_primitive_arity (i32.load offset=8 (local.get $expr)) (i32.const 1) (i32.const 1) (local.get $head))
          (return (i32.load offset=4 (i32.load offset=8 (local.get $expr))))))
      (if (i32.eq (local.get $head) (global.get $sym_if))
        (then
          (local.set $rest (i32.load offset=8 (local.get $expr)))            ;; (test then else)
          (call $require_primitive_arity (local.get $rest) (i32.const 2) (i32.const 3) (local.get $head))
          (local.set $t (call $eval (i32.load offset=4 (local.get $rest)) (local.get $env)))
          (local.set $rest (i32.load offset=8 (local.get $rest)))            ;; (then else)
          (if (call $is_falsy (local.get $t))
            (then (local.set $rest (i32.load offset=8 (local.get $rest)))))  ;; nil/false -> (else)
          (if (i32.eq (local.get $rest) (global.get $nil))
            (then (return (global.get $nil))))
          (local.set $expr (i32.load offset=4 (local.get $rest)))
          (br $tail)))
      (if (i32.eq (local.get $head) (global.get $sym_lambda))
        (then
          (call $require_primitive_arity (i32.load offset=8 (local.get $expr)) (i32.const 2) (i32.const -1) (local.get $head))
          (return (call $make_clo (i32.const 5)
                        (i32.load offset=4 (i32.load offset=8 (local.get $expr)))
                        (i32.load offset=8 (i32.load offset=8 (local.get $expr)))
                        (local.get $env)))))
      (if (i32.eq (local.get $head) (global.get $sym_macro))
        (then
          (call $require_primitive_arity (i32.load offset=8 (local.get $expr)) (i32.const 2) (i32.const -1) (local.get $head))
          (return (call $make_clo (i32.const 6)
                        (i32.load offset=4 (i32.load offset=8 (local.get $expr)))
                        (i32.load offset=8 (i32.load offset=8 (local.get $expr)))
                        (local.get $env)))))
      (if (i32.eq (local.get $head) (global.get $sym_define))
        (then
          (call $require_primitive_arity (i32.load offset=8 (local.get $expr)) (i32.const 2) (i32.const 2) (local.get $head))
          (return (call $eval_define (local.get $expr) (local.get $env)))))
      (if (i32.eq (local.get $head) (global.get $sym_set))
        (then
          (call $require_primitive_arity (i32.load offset=8 (local.get $expr)) (i32.const 2) (i32.const 2) (local.get $head))
          (return (call $set_bang (local.get $env)
                        (i32.load offset=4 (i32.load offset=8 (local.get $expr)))
                        (call $eval (i32.load offset=4 (i32.load offset=8 (i32.load offset=8 (local.get $expr)))) (local.get $env))))))
      (if (i32.eq (local.get $head) (global.get $sym_begin))
        (then
          (local.set $body (i32.load offset=8 (local.get $expr)))
          (if (i32.eq (local.get $body) (global.get $nil)) (then (return (global.get $nil))))
          (local.set $expr (call $eval_but_last (local.get $body) (local.get $env)))
          (br $tail)))
      (if (i32.eq (local.get $head) (global.get $sym_qq))
        (then
          (call $require_primitive_arity (i32.load offset=8 (local.get $expr)) (i32.const 1) (i32.const 1) (local.get $head))
          (return (call $qq_eval (i32.load offset=4 (i32.load offset=8 (local.get $expr)))
                                (local.get $env) (i32.const 1)))))
      ;; application (a macro in head position expands against the raw forms, then re-evals)
      (local.set $fn (call $eval (local.get $head) (local.get $env)))
      (if (call $is_macro (local.get $fn))
        (then
          (local.set $call_name (if (result i32) (call $is_symbol (local.get $head))
                                  (then (local.get $head)) (else (global.get $sym_macro))))
          (local.set $expr (call $apply_user (local.get $fn) (i32.load offset=8 (local.get $expr)) (local.get $call_name)))
          (br $tail)))
      (local.set $rest (call $eval_list (i32.load offset=8 (local.get $expr)) (local.get $env)))
      (if (i32.and (local.get $fn) (i32.const 1)) (then (call $err_apply) (unreachable)))
      (local.set $t (i32.load (local.get $fn)))
      (if (i32.eq (local.get $t) (i32.const 7))   ;; primitive
        (then (return (call $call_prim (i32.load offset=4 (local.get $fn))
                                      (local.get $rest) (local.get $head)))))
      (if (i32.ne (local.get $t) (i32.const 5))   ;; only closures are applicable
        (then (call $err_apply) (unreachable)))
      (local.set $body (i32.load offset=8 (local.get $fn)))
      (local.set $call_name (if (result i32) (call $is_symbol (local.get $head))
                              (then (local.get $head)) (else (global.get $sym_lambda))))
      (local.set $env (call $bind_params (local.get $fn) (local.get $rest) (local.get $call_name)))
      (if (i32.eq (local.get $body) (global.get $nil)) (then (return (global.get $nil))))
      (local.set $expr (call $eval_but_last (local.get $body) (local.get $env)))
      (br $tail))
    (unreachable))

  ;; --- primitives ---
  ;; Exact arity by primitive id. -1 marks the five existing variadic forms.
  (func $primitive_arity (param $id i32) (result i32)
    (if (i32.eq (local.get $id) (i32.const 1)) (then (return (i32.const 2))))
    (if (i32.and (i32.ge_u (local.get $id) (i32.const 2)) (i32.le_u (local.get $id) (i32.const 4))) (then (return (i32.const 1))))
    (if (i32.eq (local.get $id) (i32.const 5)) (then (return (i32.const 2))))
    (if (i32.and (i32.ge_u (local.get $id) (i32.const 6)) (i32.le_u (local.get $id) (i32.const 9))) (then (return (i32.const -1))))
    (if (i32.or (i32.eq (local.get $id) (i32.const 10)) (i32.eq (local.get $id) (i32.const 11))) (then (return (i32.const 2))))
    (if (i32.eq (local.get $id) (i32.const 12)) (then (return (i32.const -1))))
    (if (i32.and (i32.ge_u (local.get $id) (i32.const 13)) (i32.le_u (local.get $id) (i32.const 23))) (then (return (i32.const 1))))
    (if (i32.and (i32.ge_u (local.get $id) (i32.const 26)) (i32.le_u (local.get $id) (i32.const 29))) (then (return (i32.const 2))))
    (if (i32.eq (local.get $id) (i32.const 30)) (then (return (i32.const 1))))
    (if (i32.eq (local.get $id) (i32.const 31)) (then (return (i32.const -1))))
    (if (i32.eq (local.get $id) (i32.const 32)) (then (return (i32.const -2))))
    (if (i32.or (i32.eq (local.get $id) (i32.const 33)) (i32.eq (local.get $id) (i32.const 34))) (then (return (i32.const 2))))
    (if (i32.and (i32.ge_u (local.get $id) (i32.const 35)) (i32.le_u (local.get $id) (i32.const 37))) (then (return (i32.const 1))))
    (if (i32.eq (local.get $id) (i32.const 38)) (then (return (i32.const 2))))
    (if (i32.eq (local.get $id) (i32.const 39)) (then (return (i32.const 3))))
    (if (i32.eq (local.get $id) (i32.const 40)) (then (return (i32.const 2))))
    (if (i32.and (i32.ge_u (local.get $id) (i32.const 41)) (i32.le_u (local.get $id) (i32.const 45))) (then (return (i32.const 2))))
    (if (i32.eq (local.get $id) (i32.const 46)) (then (return (i32.const 3))))
    (if (i32.or (i32.eq (local.get $id) (i32.const 47)) (i32.eq (local.get $id) (i32.const 48))) (then (return (i32.const 1))))
    (if (i32.or (i32.eq (local.get $id) (i32.const 49)) (i32.eq (local.get $id) (i32.const 50))) (then (return (i32.const 0))))
    (if (i32.eq (local.get $id) (i32.const 51)) (then (return (i32.const 1))))
    (if (i32.or (i32.eq (local.get $id) (i32.const 52)) (i32.eq (local.get $id) (i32.const 53))) (then (return (i32.const 0))))
    (if (i32.or (i32.eq (local.get $id) (i32.const 54)) (i32.eq (local.get $id) (i32.const 55))) (then (return (i32.const 1))))
    (if (i32.eq (local.get $id) (i32.const 56)) (then (return (i32.const 3))))
    (if (i32.and (i32.ge_u (local.get $id) (i32.const 57)) (i32.le_u (local.get $id) (i32.const 59))) (then (return (i32.const 2))))
    (if (i32.eq (local.get $id) (i32.const 60)) (then (return (i32.const 3))))
    (if (i32.eq (local.get $id) (i32.const 61)) (then (return (i32.const 4))))
    (if (i32.eq (local.get $id) (i32.const 62)) (then (return (i32.const 5))))
    (if (i32.eq (local.get $id) (i32.const 63)) (then (return (i32.const 1))))
    (if (i32.eq (local.get $id) (i32.const 64)) (then (return (i32.const 5))))
    (if (i32.eq (local.get $id) (i32.const 65)) (then (return (i32.const 3))))
    (i32.const -1))

  (func $require_primitive_arity (param $args i32) (param $minimum i32) (param $maximum i32) (param $name i32)
    (local $cur i32) (local $count i32)
    (local.set $cur (local.get $args))
    (block $done (loop $count_args
      (br_if $done (i32.eq (local.get $cur) (global.get $nil)))
      (if (i32.eqz (call $is_pair (local.get $cur)))
        (then (call $err_named_expected (local.get $name)) (unreachable)))
      (local.set $count (i32.add (local.get $count) (i32.const 1)))
      (local.set $cur (i32.load offset=8 (local.get $cur)))
      (br $count_args)))
    (if (i32.or (i32.lt_u (local.get $count) (local.get $minimum))
                (i32.gt_u (local.get $count) (local.get $maximum)))
      (then (call $err_named_expected (local.get $name)) (unreachable))))

  (func $call_prim (param $id i32) (param $args i32) (param $name i32) (result i32)
    (local $acc i32) (local $cur i32) (local $a i32) (local $b i32) (local $cur2 i32) (local $arity i32)
    (local.set $arity (call $primitive_arity (local.get $id)))
    (if (i32.ge_s (local.get $arity) (i32.const 0))
      (then (call $require_primitive_arity (local.get $args) (local.get $arity) (local.get $arity) (local.get $name))))
    (if (i32.eq (local.get $arity) (i32.const -2))
      (then (call $require_primitive_arity (local.get $args) (i32.const 2) (i32.const 3) (local.get $name))))
    ;; cons
    (if (i32.eq (local.get $id) (i32.const 1))
      (then (return (call $cons (call $car (local.get $args)) (call $car (call $cdr (local.get $args)))))))
    ;; car
    (if (i32.eq (local.get $id) (i32.const 2))
      (then (return (call $car (call $car (local.get $args))))))
    ;; cdr
    (if (i32.eq (local.get $id) (i32.const 3))
      (then (return (call $cdr (call $car (local.get $args))))))
    ;; atom (atom?)
    (if (i32.eq (local.get $id) (i32.const 4))
      (then (return (call $bool (i32.eqz (call $is_pair (call $car (local.get $args))))))))
    ;; eq (eq?)
    (if (i32.eq (local.get $id) (i32.const 5))
      (then (return (call $bool (i32.eq (call $car (local.get $args)) (call $car (call $cdr (local.get $args))))))))
    ;; +  (fold, identity 0)
    (if (i32.eq (local.get $id) (i32.const 6))
      (then
        (local.set $acc (i32.const 0)) (local.set $cur (local.get $args))
        (block $d (loop $l
          (br_if $d (i32.eq (local.get $cur) (global.get $nil)))
          (local.set $acc (call $fix_add_checked
            (local.get $acc) (call $fixval (i32.load offset=4 (local.get $cur)))))
          (local.set $cur (i32.load offset=8 (local.get $cur)))
          (br $l)))
        (return (call $mkfix (local.get $acc)))))
    ;; -  (unary negates; n-ary left folds)
    (if (i32.eq (local.get $id) (i32.const 7))
      (then
        (if (i32.eq (local.get $args) (global.get $nil)) (then (return (call $mkfix (i32.const 0)))))
        (local.set $acc (call $fixval (i32.load offset=4 (local.get $args))))
        (local.set $cur (i32.load offset=8 (local.get $args)))
        (if (i32.eq (local.get $cur) (global.get $nil))
          (then (return (call $mkfix (call $fix_sub_checked (i32.const 0) (local.get $acc))))))
        (block $d (loop $l
          (br_if $d (i32.eq (local.get $cur) (global.get $nil)))
          (local.set $acc (call $fix_sub_checked
            (local.get $acc) (call $fixval (i32.load offset=4 (local.get $cur)))))
          (local.set $cur (i32.load offset=8 (local.get $cur)))
          (br $l)))
        (return (call $mkfix (local.get $acc)))))
    ;; *  (fold, identity 1)
    (if (i32.eq (local.get $id) (i32.const 8))
      (then
        (local.set $acc (i32.const 1)) (local.set $cur (local.get $args))
        (block $d (loop $l
          (br_if $d (i32.eq (local.get $cur) (global.get $nil)))
          (local.set $acc (call $fix_mul_checked
            (local.get $acc) (call $fixval (i32.load offset=4 (local.get $cur)))))
          (local.set $cur (i32.load offset=8 (local.get $cur)))
          (br $l)))
        (return (call $mkfix (local.get $acc)))))
    ;; /  (left fold, signed integer division)
    (if (i32.eq (local.get $id) (i32.const 9))
      (then
        (if (i32.eq (local.get $args) (global.get $nil)) (then (return (call $mkfix (i32.const 0)))))
        (local.set $acc (call $fixval (i32.load offset=4 (local.get $args))))
        (local.set $cur (i32.load offset=8 (local.get $args)))
        (block $d (loop $l
          (br_if $d (i32.eq (local.get $cur) (global.get $nil)))
          (local.set $a (call $fixval (i32.load offset=4 (local.get $cur))))
          (if (i32.eqz (local.get $a))
            (then (call $err_static (i32.const 32) (i32.const 16)) (unreachable)))
          (local.set $acc (i32.div_s (local.get $acc) (local.get $a)))
          (local.set $cur (i32.load offset=8 (local.get $cur)))
          (br $l)))
        (return (call $mkfix_checked (local.get $acc)))))
    ;; =
    (if (i32.eq (local.get $id) (i32.const 10))
      (then (return (call $bool (i32.eq (call $fixval (call $car (local.get $args)))
                                        (call $fixval (call $car (call $cdr (local.get $args)))))))))
    ;; <
    (if (i32.eq (local.get $id) (i32.const 11))
      (then (return (call $bool (i32.lt_s (call $fixval (call $car (local.get $args)))
                                          (call $fixval (call $car (call $cdr (local.get $args)))))))))
    ;; list  (args is already the evaluated argument list)
    (if (i32.eq (local.get $id) (i32.const 12)) (then (return (local.get $args))))
    ;; type predicates (M8); atom?/eq? reuse ids 4/5
    (if (i32.eq (local.get $id) (i32.const 13))   ;; nil?
      (then (return (call $bool (i32.eq (call $car (local.get $args)) (global.get $nil))))))
    (if (i32.eq (local.get $id) (i32.const 14))   ;; symbol?
      (then (return (call $bool (call $is_symbol (call $car (local.get $args)))))))
    (if (i32.eq (local.get $id) (i32.const 15))   ;; pair?
      (then (return (call $bool (call $is_pair (call $car (local.get $args)))))))
    (if (i32.eq (local.get $id) (i32.const 16))   ;; list?
      (then (return (call $bool (call $is_list (call $car (local.get $args)))))))
    (if (i32.eq (local.get $id) (i32.const 17))   ;; number?
      (then (return (call $bool (i32.and (call $car (local.get $args)) (i32.const 1))))))
    (if (i32.eq (local.get $id) (i32.const 18))   ;; string?
      (then (return (call $bool (call $has_tag (call $car (local.get $args)) (i32.const 4))))))
    (if (i32.eq (local.get $id) (i32.const 19))   ;; boolean?
      (then (return (call $bool (i32.or (i32.eq (call $car (local.get $args)) (global.get $true))
                                        (i32.eq (call $car (local.get $args)) (global.get $false)))))))
    (if (i32.eq (local.get $id) (i32.const 20))   ;; function?
      (then (return (call $bool (i32.or (call $has_tag (call $car (local.get $args)) (i32.const 5))
                                        (call $has_tag (call $car (local.get $args)) (i32.const 7)))))))
    (if (i32.eq (local.get $id) (i32.const 21))   ;; primitive?
      (then (return (call $bool (call $has_tag (call $car (local.get $args)) (i32.const 7))))))
    (if (i32.eq (local.get $id) (i32.const 22))   ;; closure?
      (then (return (call $bool (call $has_tag (call $car (local.get $args)) (i32.const 5))))))
    (if (i32.eq (local.get $id) (i32.const 23))   ;; macro?
      (then (return (call $bool (call $has_tag (call $car (local.get $args)) (i32.const 6))))))
    ;; --- arithmetic (M9) ---
    (if (i32.eq (local.get $id) (i32.const 26))   ;; mod
      (then
        (local.set $a (call $fixval (call $car (call $cdr (local.get $args)))))
        (if (i32.eqz (local.get $a))
          (then (call $err_static (i32.const 48) (i32.const 14)) (unreachable)))
        (return (call $mkfix (i32.rem_s
          (call $fixval (call $car (local.get $args))) (local.get $a))))))
    (if (i32.eq (local.get $id) (i32.const 27))   ;; <=
      (then (return (call $bool (i32.le_s (call $fixval (call $car (local.get $args)))
                                          (call $fixval (call $car (call $cdr (local.get $args)))))))))
    (if (i32.eq (local.get $id) (i32.const 28))   ;; >
      (then (return (call $bool (i32.gt_s (call $fixval (call $car (local.get $args)))
                                          (call $fixval (call $car (call $cdr (local.get $args)))))))))
    (if (i32.eq (local.get $id) (i32.const 29))   ;; >=
      (then (return (call $bool (i32.ge_s (call $fixval (call $car (local.get $args)))
                                          (call $fixval (call $car (call $cdr (local.get $args)))))))))
    ;; --- strings (M9) ---
    (if (i32.eq (local.get $id) (i32.const 30))   ;; string.length
      (then (return (call $mkfix (i32.load offset=8 (call $require_string (call $car (local.get $args))))))))
    (if (i32.eq (local.get $id) (i32.const 31))   ;; string.append / string.concat
      (then
        (local.set $acc (global.get $heap))       ;; buffer start
        (local.set $a (i32.const 0))              ;; length so far
        (local.set $cur (local.get $args))
        (block $d (loop $l
          (br_if $d (i32.eq (local.get $cur) (global.get $nil)))
          (drop (call $require_string (call $car (local.get $cur))))
          (call $ensure_space (i32.add (i32.add (local.get $acc) (local.get $a))
                                      (i32.load offset=8 (call $car (local.get $cur)))))
          (call $copy (i32.add (local.get $acc) (local.get $a))
                      (i32.load offset=4 (call $car (local.get $cur)))
                      (i32.load offset=8 (call $car (local.get $cur))))
          (local.set $a (i32.add (local.get $a) (i32.load offset=8 (call $car (local.get $cur)))))
          (local.set $cur (i32.load offset=8 (local.get $cur)))
          (br $l)))
        (global.set $heap (i32.and (i32.add (i32.add (local.get $acc) (local.get $a)) (i32.const 3)) (i32.const -4)))
        (return (call $mkstr_hdr (local.get $acc) (local.get $a)))))
    (if (i32.eq (local.get $id) (i32.const 32))   ;; string.slice / string.substring
      (then
        (local.set $acc (call $require_string (call $car (local.get $args))))
        (local.set $b (i32.load offset=8 (local.get $acc)))                  ;; length
        (local.set $acc (i32.load offset=4 (local.get $acc)))                ;; bytes ptr
        (local.set $cur (call $fixval (call $require_number (call $car (call $cdr (local.get $args))))))  ;; start
        (local.set $a (if (result i32) (i32.eq (call $cdr (call $cdr (local.get $args))) (global.get $nil))
                          (then (local.get $b))
                          (else (call $fixval (call $require_number (call $car (call $cdr (call $cdr (local.get $args)))))))))  ;; end
        (if (i32.gt_s (local.get $a) (local.get $b)) (then (local.set $a (local.get $b))))
        (if (i32.lt_s (local.get $a) (i32.const 0)) (then (local.set $a (i32.const 0))))
        (if (i32.gt_s (local.get $cur) (local.get $a)) (then (local.set $cur (local.get $a))))
        (if (i32.lt_s (local.get $cur) (i32.const 0)) (then (local.set $cur (i32.const 0))))
        (return (call $mkstr_copy (i32.add (local.get $acc) (local.get $cur))
                                  (i32.sub (local.get $a) (local.get $cur))))))
    (if (i32.eq (local.get $id) (i32.const 33))   ;; string.contains?
      (then (return (call $bool (call $str_contains
              (i32.load offset=4 (call $require_string (call $car (local.get $args)))) (i32.load offset=8 (call $require_string (call $car (local.get $args))))
              (i32.load offset=4 (call $require_string (call $car (call $cdr (local.get $args))))) (i32.load offset=8 (call $require_string (call $car (call $cdr (local.get $args))))))))))
    (if (i32.eq (local.get $id) (i32.const 34))   ;; string=?
      (then (return (call $bool (call $bytes_eq
              (i32.load offset=4 (call $require_string (call $car (local.get $args)))) (i32.load offset=8 (call $require_string (call $car (local.get $args))))
              (i32.load offset=4 (call $require_string (call $car (call $cdr (local.get $args))))) (i32.load offset=8 (call $require_string (call $car (call $cdr (local.get $args))))))))))
    (if (i32.eq (local.get $id) (i32.const 35))   ;; to-string
      (then
        (local.set $acc (global.get $heap))
        (global.set $out_buf (local.get $acc))
        (global.set $out_len (i32.const 0))
        (call $print (call $car (local.get $args)))
        (global.set $out_buf (i32.const 0))
        (local.set $a (global.get $out_len))
        (global.set $heap (i32.and (i32.add (i32.add (local.get $acc) (local.get $a)) (i32.const 3)) (i32.const -4)))
        (return (call $mkstr_hdr (local.get $acc) (local.get $a)))))
    ;; --- generic byte buffers and fixed-point support (S4.1) ---
    (if (i32.eq (local.get $id) (i32.const 36))   ;; bytes.alloc
      (then
        (local.set $a (call $fixval (call $require_number (call $car (local.get $args)))))
        (if (i32.lt_s (local.get $a) (i32.const 0))
          (then (call $err_static (i32.const 640) (i32.const 23)) (unreachable)))
        (local.set $acc (call $alloc (i32.add (i32.const 8) (local.get $a))))
        (i32.store (local.get $acc) (i32.const 10))
        (i32.store offset=4 (local.get $acc) (local.get $a))
        (return (local.get $acc))))
    (if (i32.eq (local.get $id) (i32.const 37))   ;; bytes.length
      (then
        (local.set $acc (call $require_bytes (call $car (local.get $args))))
        (return (call $mkfix (i32.load offset=4 (local.get $acc))))))
    (if (i32.eq (local.get $id) (i32.const 38))   ;; u8@
      (then
        (local.set $acc (call $car (local.get $args)))
        (local.set $a (call $fixval (call $require_number (call $car (call $cdr (local.get $args))))))
        (return (call $mkfix (i32.load8_u (call $bytes_address (local.get $acc) (local.get $a) (i32.const 1)))))))
    (if (i32.eq (local.get $id) (i32.const 39))   ;; u8!
      (then
        (local.set $acc (call $car (local.get $args)))
        (local.set $a (call $fixval (call $require_number (call $car (call $cdr (local.get $args))))))
        (local.set $b (call $fixval (call $require_number (call $car (call $cdr (call $cdr (local.get $args)))))))
        (i32.store8 (call $bytes_write_address (local.get $acc) (local.get $a) (i32.const 1)) (local.get $b))
        (return (call $mkfix (local.get $b)))))
    (if (i32.eq (local.get $id) (i32.const 40))   ;; u16@, little-endian
      (then
        (local.set $acc (call $car (local.get $args)))
        (local.set $a (call $fixval (call $require_number (call $car (call $cdr (local.get $args))))))
        (return (call $mkfix (i32.load16_u (call $bytes_address (local.get $acc) (local.get $a) (i32.const 2)))))))
    (if (i32.eq (local.get $id) (i32.const 41))   ;; bit.and
      (then (return (call $mkfix (i32.and (call $fixval (call $car (local.get $args))) (call $fixval (call $car (call $cdr (local.get $args)))))))))
    (if (i32.eq (local.get $id) (i32.const 42))   ;; bit.or
      (then (return (call $mkfix (i32.or (call $fixval (call $car (local.get $args))) (call $fixval (call $car (call $cdr (local.get $args)))))))))
    (if (i32.eq (local.get $id) (i32.const 43))   ;; bit.xor
      (then (return (call $mkfix (i32.xor (call $fixval (call $car (local.get $args))) (call $fixval (call $car (call $cdr (local.get $args)))))))))
    (if (i32.eq (local.get $id) (i32.const 44))   ;; bit.shl
      (then (return (call $mkfix (i32.shl (call $fixval (call $car (local.get $args))) (call $fixval (call $car (call $cdr (local.get $args)))))))))
    (if (i32.eq (local.get $id) (i32.const 45))   ;; bit.shr, arithmetic
      (then (return (call $mkfix (i32.shr_s (call $fixval (call $car (local.get $args))) (call $fixval (call $car (call $cdr (local.get $args)))))))))
    (if (i32.eq (local.get $id) (i32.const 46))   ;; fx.mul-shift with i64 intermediate
      (then
        (local.set $acc (call $fixval (call $car (local.get $args))))
        (local.set $a (call $fixval (call $car (call $cdr (local.get $args)))))
        (local.set $b (call $fixval (call $car (call $cdr (call $cdr (local.get $args))))))
        (return (call $mkfix (call $fix_i64_checked (i64.shr_s
          (i64.mul (i64.extend_i32_s (local.get $acc)) (i64.extend_i32_s (local.get $a)))
          (i64.extend_i32_s (local.get $b))))))))
    ;; bit.mul-shr deliberately models a wrapped 32-bit multiply followed by
    ;; an arithmetic right shift. It is the explicit escape hatch for source
    ;; algorithms whose machine-word overflow is part of their semantics;
    ;; ordinary * remains checked. The shifted result must still fit a fixnum.
    (if (i32.eq (local.get $id) (i32.const 65))
      (then
        (local.set $acc (call $arg_num (local.get $args) (i32.const 0)))
        (local.set $a (call $arg_num (local.get $args) (i32.const 1)))
        (local.set $b (call $arg_num (local.get $args) (i32.const 2)))
        (return (call $mkfix_checked
          (i32.shr_s (i32.mul (local.get $acc) (local.get $a)) (local.get $b))))))
    ;; --- environment and capacity introspection ---
    (if (i32.eq (local.get $id) (i32.const 47))   ;; (bound? 'name) against the global environment
      (then
        (local.set $acc (call $car (local.get $args)))
        (if (i32.eqz (call $is_symbol (local.get $acc)))
          (then (call $err_static (i32.const 732) (i32.const 15)) (unreachable)))
        (return (call $bool (call $lookup_cell (global.get $genv) (local.get $acc))))))
    (if (i32.eq (local.get $id) (i32.const 48))   ;; heap.reserve
      (then (return (call $mkfix (call $heap_reserve
        (call $fixval (call $require_number (call $car (local.get $args)))))))))
    (if (i32.eq (local.get $id) (i32.const 49))   ;; heap.used
      (then (return (call $mkfix (i32.sub (global.get $heap) (i32.const 131072))))))
    (if (i32.eq (local.get $id) (i32.const 50))   ;; heap.capacity
      (then (return (call $mkfix (call $heap_capacity)))))
    ;; --- host-ingested assets ---
    (if (i32.eq (local.get $id) (i32.const 51))   ;; asset.reserve
      (then (return (call $mkfix (call $asset_reserve
        (call $fixval (call $require_number (call $car (local.get $args)))))))))
    (if (i32.eq (local.get $id) (i32.const 52))   ;; asset.used
      (then (return (call $mkfix (global.get $asset_used)))))
    (if (i32.eq (local.get $id) (i32.const 53))   ;; asset.count
      (then (return (call $mkfix (global.get $asset_count)))))
    (if (i32.eq (local.get $id) (i32.const 54))   ;; asset.ref
      (then (return (call $asset_ref
        (call $fixval (call $require_number (call $car (local.get $args))))))))
    (if (i32.eq (local.get $id) (i32.const 55))   ;; asset?
      (then (return (call $bool (call $has_tag (call $car (local.get $args)) (i32.const 11))))))
    ;; --- fixed-width accessors and bounded block operations ---
    ;; Every one of these is bounds-checked through the same address helpers the
    ;; byte accessors use, so an out-of-range index is a diagnostic rather than
    ;; a read or write somewhere else in linear memory.
    (if (i32.eq (local.get $id) (i32.const 56))   ;; u16!, little-endian
      (then
        (local.set $b (call $arg_num (local.get $args) (i32.const 2)))
        (i32.store16 (call $bytes_write_address (call $arg (local.get $args) (i32.const 0))
                                                (call $arg_num (local.get $args) (i32.const 1))
                                                (i32.const 2))
                     (local.get $b))
        (return (call $mkfix (local.get $b)))))
    (if (i32.eq (local.get $id) (i32.const 57))   ;; i16@, little-endian signed
      (then (return (call $mkfix (i32.load16_s
        (call $bytes_address (call $arg (local.get $args) (i32.const 0))
                             (call $arg_num (local.get $args) (i32.const 1))
                             (i32.const 2)))))))
    (if (i32.eq (local.get $id) (i32.const 58))   ;; u32@, little-endian unsigned
      (then (return (call $mkfix_unsigned (i32.load
        (call $bytes_address (call $arg (local.get $args) (i32.const 0))
                             (call $arg_num (local.get $args) (i32.const 1))
                             (i32.const 4)))))))
    (if (i32.eq (local.get $id) (i32.const 59))   ;; i32@, little-endian signed
      (then (return (call $mkfix_checked (i32.load
        (call $bytes_address (call $arg (local.get $args) (i32.const 0))
                             (call $arg_num (local.get $args) (i32.const 1))
                             (i32.const 4)))))))
    ;; One store covers both signednesses: two's complement means writing -1 and
    ;; writing 4294967295 lay down the same four bytes, so a separate i32! would
    ;; be a second name for an identical operation.
    (if (i32.eq (local.get $id) (i32.const 60))   ;; u32!, little-endian
      (then
        (local.set $b (call $arg_num (local.get $args) (i32.const 2)))
        (i32.store (call $bytes_write_address (call $arg (local.get $args) (i32.const 0))
                                              (call $arg_num (local.get $args) (i32.const 1))
                                              (i32.const 4))
                   (local.get $b))
        (return (call $mkfix (local.get $b)))))
    ;; The run length is passed to the address helper as the access width, so
    ;; the whole span is checked once before a single byte moves. A negative
    ;; count fails that unsigned check rather than becoming an enormous run.
    (if (i32.eq (local.get $id) (i32.const 61))   ;; (bytes.fill buf index count byte)
      (then
        (local.set $b (call $arg_num (local.get $args) (i32.const 2)))
        (local.set $a (call $arg_num (local.get $args) (i32.const 3)))
        (memory.fill (call $bytes_write_address (call $arg (local.get $args) (i32.const 0))
                                                (call $arg_num (local.get $args) (i32.const 1))
                                                (local.get $b))
                     (i32.and (local.get $a) (i32.const 255))
                     (local.get $b))
        (return (call $mkfix (local.get $b)))))
    ;; Overlapping ranges move as if through a temporary, so a program may
    ;; scroll or shift a buffer in place. The source may be an ingested asset;
    ;; only the destination has to be mutable.
    (if (i32.eq (local.get $id) (i32.const 62))   ;; (bytes.copy dest at src from count)
      (then
        (local.set $b (call $arg_num (local.get $args) (i32.const 4)))
        (local.set $acc (call $bytes_write_address (call $arg (local.get $args) (i32.const 0))
                                                   (call $arg_num (local.get $args) (i32.const 1))
                                                   (local.get $b)))
        (local.set $cur (call $bytes_address (call $arg (local.get $args) (i32.const 2))
                                             (call $arg_num (local.get $args) (i32.const 3))
                                             (local.get $b)))
        (memory.copy (local.get $acc) (local.get $cur) (local.get $b))
        (return (call $mkfix (local.get $b)))))
    ;; (heap.release used) winds the bump pointer back to where (heap.used)
    ;; read `used`, which is how a program reclaims a region it has finished
    ;; with. The allocator here never collects, so without this a computation
    ;; that runs every frame spends the declared session ceiling and stops;
    ;; with it, a frame is an arena.
    ;;
    ;; This is a truthful primitive and a sharp one. Everything allocated after
    ;; the mark is gone, so a release is only sound when nothing allocated
    ;; inside the region is still reachable when it happens: no value stored
    ;; into a global with set!, no symbol interned by reading new source, no
    ;; asset committed. Committed assets are refused outright rather than left
    ;; to the caller, because an asset handle is permanent by contract.
    (if (i32.eq (local.get $id) (i32.const 63))   ;; (heap.release used)
      (then
        (local.set $a (i32.add (i32.const 131072)
                               (call $fixval (call $require_number (call $car (local.get $args))))))
        (if (i32.or (i32.gt_u (local.get $a) (global.get $heap))
                    (i32.lt_u (local.get $a) (global.get $heap_floor)))
          (then (call $err_static (i32.const 991) (i32.const 22)) (unreachable)))
        (global.set $heap (local.get $a))
        (return (call $mkfix (i32.sub (global.get $heap) (i32.const 131072))))))
    ;; (bytes.fill-stride buf index count stride byte) writes one byte every
    ;; `stride` bytes, `count` times. It is bytes.fill for a non-contiguous
    ;; run, and it exists for the same reason bytes.fill does: a program that
    ;; has already decided which bytes to write should not pay an interpreted
    ;; call for each of them. The kernel decides nothing about them - index,
    ;; count, stride, and value all arrive computed.
    (if (i32.eq (local.get $id) (i32.const 64))   ;; (bytes.fill-stride buf index count stride byte)
      (then
        (local.set $acc (call $arg (local.get $args) (i32.const 0)))
        (local.set $a (call $arg_num (local.get $args) (i32.const 1)))
        (local.set $b (call $arg_num (local.get $args) (i32.const 2)))
        (local.set $cur (call $arg_num (local.get $args) (i32.const 3)))
        (if (i32.lt_s (local.get $cur) (i32.const 0))
          (then (call $err_static (i32.const 640) (i32.const 23)) (unreachable)))
        (if (i32.gt_s (local.get $b) (i32.const 0))
          (then
            ;; The first and last bytes bracket the whole run, so checking both
            ;; through the ordinary write helper checks all of it.
            (drop (call $bytes_write_address (local.get $acc) (local.get $a) (i32.const 1)))
            (local.set $cur2 (call $bytes_write_address
              (local.get $acc)
              (i32.add (local.get $a) (i32.mul (i32.sub (local.get $b) (i32.const 1)) (local.get $cur)))
              (i32.const 1)))
            (local.set $cur2 (call $bytes_write_address (local.get $acc) (local.get $a) (i32.const 1)))
            (local.set $a (i32.and (call $arg_num (local.get $args) (i32.const 4)) (i32.const 255)))
            (block $done (loop $l
              (br_if $done (i32.eqz (local.get $b)))
              (i32.store8 (local.get $cur2) (local.get $a))
              (local.set $cur2 (i32.add (local.get $cur2) (local.get $cur)))
              (local.set $b (i32.sub (local.get $b) (i32.const 1)))
              (br $l)))))
        (return (call $mkfix (call $arg_num (local.get $args) (i32.const 2))))))
    (global.get $nil))

  ;; --- init ---
  (func $init
    (global.set $heap (i32.const 131072))
    (global.set $heap_floor (i32.const 131072))
    (global.set $nil (call $alloc (i32.const 4)))
    (i32.store (global.get $nil) (i32.const 0))
    (global.set $true (call $alloc (i32.const 4)))
    (i32.store (global.get $true) (i32.const 1))
    (global.set $false (call $alloc (i32.const 4)))
    (i32.store (global.get $false) (i32.const 9))
    (global.set $eof (call $alloc (i32.const 4)))
    (i32.store (global.get $eof) (i32.const 8))
    (global.set $symlist (global.get $nil))
    ;; A fresh instance holds no assets and has been granted no asset capacity.
    (global.set $assets (global.get $nil))
    (global.set $asset_count (i32.const 0))
    (global.set $asset_used (i32.const 0))
    (global.set $asset_limit (i32.const 0))
    (global.set $asset_pending (i32.const 0))
    (global.set $sym_quote  (call $intern (i32.const 128) (i32.const 5)))
    (global.set $sym_if     (call $intern (i32.const 155) (i32.const 2)))
    (global.set $sym_lambda (call $intern (i32.const 157) (i32.const 6)))
    (global.set $sym_macro  (call $intern (i32.const 163) (i32.const 5)))
    (global.set $sym_define (call $intern (i32.const 168) (i32.const 6)))
    (global.set $sym_set    (call $intern (i32.const 174) (i32.const 4)))
    (global.set $sym_begin  (call $intern (i32.const 178) (i32.const 5)))
    (global.set $sym_qq     (call $intern (i32.const 209) (i32.const 10)))
    (global.set $sym_uq     (call $intern (i32.const 219) (i32.const 7)))
    (global.set $sym_uqs    (call $intern (i32.const 226) (i32.const 16)))
    (global.set $genv (call $cons (global.get $nil) (global.get $nil)))
    (call $defprim (i32.const 133) (i32.const 4) (i32.const 1))   ;; cons
    (call $defprim (i32.const 137) (i32.const 3) (i32.const 2))   ;; car
    (call $defprim (i32.const 140) (i32.const 3) (i32.const 3))   ;; cdr
    (call $defprim (i32.const 143) (i32.const 4) (i32.const 4))   ;; atom
    (call $defprim (i32.const 147) (i32.const 2) (i32.const 5))   ;; eq
    (call $defprim (i32.const 149) (i32.const 1) (i32.const 6))   ;; +
    (call $defprim (i32.const 150) (i32.const 1) (i32.const 7))   ;; -
    (call $defprim (i32.const 151) (i32.const 1) (i32.const 8))   ;; *
    (call $defprim (i32.const 152) (i32.const 1) (i32.const 9))   ;; /
    (call $defprim (i32.const 153) (i32.const 1) (i32.const 10))  ;; =
    (call $defprim (i32.const 154) (i32.const 1) (i32.const 11))   ;; <
    (call $defprim (i32.const 205) (i32.const 4) (i32.const 12))   ;; list
    (call $defprim (i32.const 255) (i32.const 4) (i32.const 13))   ;; nil?
    (call $defprim (i32.const 259) (i32.const 7) (i32.const 14))   ;; symbol?
    (call $defprim (i32.const 266) (i32.const 5) (i32.const 15))   ;; pair?
    (call $defprim (i32.const 271) (i32.const 5) (i32.const 16))   ;; list?
    (call $defprim (i32.const 276) (i32.const 7) (i32.const 17))   ;; number?
    (call $defprim (i32.const 283) (i32.const 7) (i32.const 18))   ;; string?
    (call $defprim (i32.const 290) (i32.const 8) (i32.const 19))   ;; boolean?
    (call $defprim (i32.const 298) (i32.const 9) (i32.const 20))   ;; function?
    (call $defprim (i32.const 307) (i32.const 10) (i32.const 21))  ;; primitive?
    (call $defprim (i32.const 317) (i32.const 8) (i32.const 22))   ;; closure?
    (call $defprim (i32.const 325) (i32.const 6) (i32.const 23))   ;; macro?
    (call $defprim (i32.const 331) (i32.const 5) (i32.const 4))    ;; atom?  (alias of atom)
    (call $defprim (i32.const 336) (i32.const 3) (i32.const 5))    ;; eq?    (alias of eq)
    (call $defprim (i32.const 340) (i32.const 3) (i32.const 26))   ;; mod
    (call $defprim (i32.const 343) (i32.const 2) (i32.const 27))   ;; <=
    (call $defprim (i32.const 345) (i32.const 1) (i32.const 28))   ;; >
    (call $defprim (i32.const 346) (i32.const 2) (i32.const 29))   ;; >=
    (call $defprim (i32.const 348) (i32.const 13) (i32.const 30))  ;; string.length
    (call $defprim (i32.const 361) (i32.const 13) (i32.const 31))  ;; string.append
    (call $defprim (i32.const 374) (i32.const 13) (i32.const 31))  ;; string.concat (alias)
    (call $defprim (i32.const 387) (i32.const 12) (i32.const 32))  ;; string.slice
    (call $defprim (i32.const 399) (i32.const 16) (i32.const 32))  ;; string.substring (alias)
    (call $defprim (i32.const 415) (i32.const 16) (i32.const 33))  ;; string.contains?
    (call $defprim (i32.const 431) (i32.const 8) (i32.const 34))   ;; string=?
    (call $defprim (i32.const 439) (i32.const 9) (i32.const 35))   ;; to-string
    (call $defprim (i32.const 530) (i32.const 11) (i32.const 36))  ;; bytes.alloc
    (call $defprim (i32.const 541) (i32.const 12) (i32.const 37))  ;; bytes.length
    (call $defprim (i32.const 553) (i32.const 3) (i32.const 38))   ;; u8@
    (call $defprim (i32.const 556) (i32.const 3) (i32.const 39))   ;; u8!
    (call $defprim (i32.const 559) (i32.const 4) (i32.const 40))   ;; u16@
    (call $defprim (i32.const 563) (i32.const 7) (i32.const 41))   ;; bit.and
    (call $defprim (i32.const 570) (i32.const 6) (i32.const 42))   ;; bit.or
    (call $defprim (i32.const 576) (i32.const 7) (i32.const 43))   ;; bit.xor
    (call $defprim (i32.const 583) (i32.const 7) (i32.const 44))   ;; bit.shl
    (call $defprim (i32.const 590) (i32.const 7) (i32.const 45))   ;; bit.shr
    (call $defprim (i32.const 597) (i32.const 12) (i32.const 46))  ;; fx.mul-shift
    (call $defprim (i32.const 672) (i32.const 6) (i32.const 47))   ;; bound?
    (call $defprim (i32.const 678) (i32.const 12) (i32.const 48))  ;; heap.reserve
    (call $defprim (i32.const 690) (i32.const 9) (i32.const 49))   ;; heap.used
    (call $defprim (i32.const 699) (i32.const 13) (i32.const 50))  ;; heap.capacity
    (call $defprim (i32.const 747) (i32.const 13) (i32.const 51))  ;; asset.reserve
    (call $defprim (i32.const 760) (i32.const 10) (i32.const 52))  ;; asset.used
    (call $defprim (i32.const 770) (i32.const 11) (i32.const 53))  ;; asset.count
    (call $defprim (i32.const 781) (i32.const 9)  (i32.const 54))  ;; asset.ref
    (call $defprim (i32.const 790) (i32.const 6)  (i32.const 55))  ;; asset?
    (call $defprim (i32.const 896) (i32.const 4)  (i32.const 56))  ;; u16!
    (call $defprim (i32.const 900) (i32.const 4)  (i32.const 57))  ;; i16@
    (call $defprim (i32.const 904) (i32.const 4)  (i32.const 58))  ;; u32@
    (call $defprim (i32.const 908) (i32.const 4)  (i32.const 59))  ;; i32@
    (call $defprim (i32.const 912) (i32.const 4)  (i32.const 60))  ;; u32!
    (call $defprim (i32.const 916) (i32.const 10) (i32.const 61))  ;; bytes.fill
    (call $defprim (i32.const 926) (i32.const 10) (i32.const 62))  ;; bytes.copy
    (call $defprim (i32.const 962) (i32.const 12) (i32.const 63))  ;; heap.release
    (call $defprim (i32.const 974) (i32.const 17) (i32.const 64))  ;; bytes.fill-stride
    (call $defprim (i32.const 609) (i32.const 11) (i32.const 65))) ;; bit.mul-shr

  ;; --- drivers (init is separate so loads accumulate without resetting) ---
  (func (export "init")
    (call $error_reset)
    (call $init))

  ;; --- host asset ingestion API --------------------------------------------
  ;; Two calls rather than one so a multi-megabyte asset crosses the boundary
  ;; exactly once: the kernel hands back a destination, the host writes the
  ;; bytes into linear memory itself, and the commit publishes the result. No
  ;; copy, and no route through the 127KB source input region.
  ;;
  ;; The kernel never inspects an asset's contents. It knows a length and
  ;; nothing else; container formats, chunk tables, palettes, and codecs are
  ;; entirely the Lisp program's business.
  ;;
  ;; asset_begin may grow memory, so a host holding a view over the buffer must
  ;; re-read memory.buffer after it returns or it will write into a detached
  ;; ArrayBuffer.
  (func (export "asset_begin") (param $len i32) (result i32)
    (local $p i32)
    (call $error_reset)
    (if (global.get $asset_pending)
      (then (call $err_static (i32.const 872) (i32.const 21)) (unreachable)))
    (if (i32.lt_s (local.get $len) (i32.const 0))
      (then (call $err_static (i32.const 803) (i32.const 23)) (unreachable)))
    (if (i32.gt_s (local.get $len) (i32.sub (global.get $asset_limit) (global.get $asset_used)))
      (then (call $err_static (i32.const 803) (i32.const 23)) (unreachable)))
    (drop (call $heap_reserve (i32.add (local.get $len) (i32.const 8))))
    (local.set $p (call $alloc (i32.add (i32.const 8) (local.get $len))))
    (i32.store          (local.get $p) (i32.const 11))
    (i32.store offset=4 (local.get $p) (local.get $len))
    (global.set $asset_pending (local.get $p))
    (i32.add (local.get $p) (i32.const 8)))

  ;; Publishing is what makes an asset reachable and permanent. Until this
  ;; call the object is held only by $asset_pending, and a failed or abandoned
  ;; ingest therefore contributes nothing to asset.count or asset.used.
  (func (export "asset_commit") (result i32)
    (local $p i32)
    (call $error_reset)
    (local.set $p (global.get $asset_pending))
    (if (i32.eqz (local.get $p))
      (then (call $err_static (i32.const 872) (i32.const 21)) (unreachable)))
    (global.set $assets (call $cons (local.get $p) (global.get $assets)))
    (global.set $asset_used (i32.add (global.get $asset_used) (i32.load offset=4 (local.get $p))))
    (global.set $asset_count (i32.add (global.get $asset_count) (i32.const 1)))
    (global.set $asset_pending (i32.const 0))
    ;; A published asset is permanent, so nothing may wind the heap back over
    ;; it afterwards.
    (global.set $heap_floor (global.get $heap))
    (i32.sub (global.get $asset_count) (i32.const 1)))

  (func (export "read_print") (param $ptr i32) (param $len i32)
    (local $v i32)
    (call $error_reset)
    (global.set $rp (local.get $ptr))
    (global.set $rend (i32.add (local.get $ptr) (local.get $len)))
    (call $reader_reset)
    (block $done (loop $l
      (local.set $v (call $read1))
      (br_if $done (i32.eq (local.get $v) (global.get $eof)))
      (call $println (local.get $v))
      (br $l))))

  ;; The host reads this only after a trap. A zero value proves that the trap
  ;; did not pass through a classified language-error helper.
  (func (export "error_kind") (result i32)
    (global.get $error_kind))
  (func (export "error_data_pointer") (result i32)
    (global.get $error_data_ptr))
  (func (export "error_data_length") (result i32)
    (global.get $error_data_len))

  ;; eval every form, discard results (used to load boot.lisp)
  (func (export "eval_all") (param $ptr i32) (param $len i32)
    (local $v i32)
    (call $error_reset)
    (global.set $rp (local.get $ptr))
    (global.set $rend (i32.add (local.get $ptr) (local.get $len)))
    (call $reader_reset)
    (block $done (loop $l
      (local.set $v (call $read1))
      (br_if $done (i32.eq (local.get $v) (global.get $eof)))
      (drop (call $eval (local.get $v) (global.get $genv)))
      (br $l))))

  ;; eval every form, print each result (used to run a user program)
  (func (export "eval_print") (param $ptr i32) (param $len i32)
    (local $v i32)
    (call $error_reset)
    (global.set $rp (local.get $ptr))
    (global.set $rend (i32.add (local.get $ptr) (local.get $len)))
    (call $reader_reset)
    (block $done (loop $l
      (local.set $v (call $read1))
      (br_if $done (i32.eq (local.get $v) (global.get $eof)))
      (call $println (call $eval (local.get $v) (global.get $genv)))
      (br $l))))

  ;; eval every form with DOM-safe string serialization
  (func (export "eval_dom_print") (param $ptr i32) (param $len i32)
    (local $v i32)
    (call $error_reset)
    (global.set $rp (local.get $ptr))
    (global.set $rend (i32.add (local.get $ptr) (local.get $len)))
    (call $reader_reset)
    (block $done (loop $l
      (local.set $v (call $read1))
      (br_if $done (i32.eq (local.get $v) (global.get $eof)))
      (call $print_dom (call $eval (local.get $v) (global.get $genv)))
      (call $write (i32.const 104) (i32.const 1))
      (br $l))))

  ;; Read source forms and print their repeated outer named-macro expansion
  ;; without evaluating the expanded forms. This is the independent code-as-
  ;; data observation boundary used by the deterministic M2 harness.
  (func (export "expand_dom_print") (param $ptr i32) (param $len i32)
    (local $v i32)
    (call $error_reset)
    (global.set $rp (local.get $ptr))
    (global.set $rend (i32.add (local.get $ptr) (local.get $len)))
    (call $reader_reset)
    (block $done (loop $l
      (local.set $v (call $read1))
      (br_if $done (i32.eq (local.get $v) (global.get $eof)))
      (call $print_dom (call $macroexpand_outer (local.get $v) (global.get $genv)))
      (call $write (i32.const 104) (i32.const 1))
      (br $l))))

  ;; Evaluate one or more forms and transfer the final byte-buffer result to
  ;; the generic host sink. Binary data must not pass through DOM text output.
  (func (export "eval_bytes") (param $ptr i32) (param $len i32)
    (local $form i32) (local $v i32)
    (call $error_reset)
    (global.set $rp (local.get $ptr))
    (global.set $rend (i32.add (local.get $ptr) (local.get $len)))
    (call $reader_reset)
    (local.set $v (global.get $nil))
    (block $done (loop $l
      (local.set $form (call $read1))
      (br_if $done (i32.eq (local.get $form) (global.get $eof)))
      (local.set $v (call $eval (local.get $form) (global.get $genv)))
      (br $l)))
    (local.set $v (call $require_bytes (local.get $v)))
    (call $host_bytes_write
      (i32.add (local.get $v) (i32.const 8))
      (i32.load offset=4 (local.get $v)))))
