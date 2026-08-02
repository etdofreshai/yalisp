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
;;
;; Object layouts (4-byte words):
;;   pair     [2, car, cdr]
;;   symbol   [3, name-ptr, name-len, next-in-intern-list]
;;   string   [4, bytes-ptr, len]
;;   closure  [5, params, body, env]
;;   macro    [6, params, body, env]
;;   primitive[7, id]
;;
;; Environment = a pair (frame . parent), frame = alist of (sym . val) pairs.
;;   define -> prepend a (sym . val) to the frame;  set! -> mutate the val slot.
;;
;; Memory map:
;;   [0,    64)  scratch (integer formatting)
;;   [64, 1024)  constant strings
;;   [1024, 8192) input buffer (host writes source here)
;;   [8192, .  )  heap (bump allocated; no GC yet)

(module
  (import "host" "write" (func $host_write (param i32 i32)))

  (memory (export "memory") 4)

  (global $heap    (mut i32) (i32.const 8192))
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
  ;; output redirect: if $out_buf != 0, $write appends to it instead of the host
  (global $out_buf (mut i32) (i32.const 0))
  (global $out_len (mut i32) (i32.const 0))

  ;; --- constant strings, region [64, 1024) ---
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

  ;; Fail before a write crosses the fixed four-page memory boundary. Use the
  ;; host import directly because $write may itself be buffering into the full
  ;; heap for to-string.
  (func $ensure_space (param $end i32)
    (if (i32.gt_u (local.get $end) (i32.shl (memory.size) (i32.const 16)))
      (then
        (call $host_write (i32.const 448) (i32.const 14))
        (call $host_write (i32.const 104) (i32.const 1))
        (unreachable))))

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
  (func $err_unbound (param $sym i32)
    (call $write (i32.const 184) (i32.const 9))
    (call $write (i32.load offset=4 (local.get $sym)) (i32.load offset=8 (local.get $sym)))
    (call $write (i32.const 104) (i32.const 1))
    (unreachable))
  (func $err_apply
    (call $write (i32.const 193) (i32.const 12))
    (call $write (i32.const 104) (i32.const 1))
    (unreachable))
  (func $err_static (param $ptr i32) (param $len i32)
    (call $write (local.get $ptr) (local.get $len))
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
    (call $write (i32.const 93) (i32.const 11)))

  (func $println (param $v i32)
    (call $print (local.get $v))
    (call $write (i32.const 104) (i32.const 1)))

  ;; --- reader ---
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
    (local.set $i (i32.const 0)) (local.set $neg (i32.const 0)) (local.set $acc (i32.const 0))
    (local.set $c (i32.load8_u (local.get $p)))
    (if (i32.eq (local.get $c) (i32.const 45)) (then (local.set $neg (i32.const 1)) (local.set $i (i32.const 1))))
    (if (i32.eq (local.get $c) (i32.const 43)) (then (local.set $i (i32.const 1))))
    (block $d (loop $l
      (br_if $d (i32.ge_u (local.get $i) (local.get $len)))
      (local.set $acc (i32.add (i32.mul (local.get $acc) (i32.const 10))
                               (i32.sub (i32.load8_u (i32.add (local.get $p) (local.get $i))) (i32.const 48))))
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

  (func $read_string (result i32)
    (local $start i32) (local $n i32) (local $c i32) (local $s i32)
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
            (else (if (i32.eq (local.get $c) (i32.const 116)) (then (local.set $c (i32.const 9)))))))) ;; \t
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

  (func $read_list (result i32)
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
                (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
                (local.set $cdr (call $read1))
                (call $skip_ws)
                (if (i32.lt_u (global.get $rp) (global.get $rend))
                  (then (if (i32.eq (i32.load8_u (global.get $rp)) (i32.const 41))
                          (then (global.set $rp (i32.add (global.get $rp) (i32.const 1)))))))
                (return (local.get $cdr))))))
    (local.set $car (call $read1))
    (local.set $cdr (call $read_list))
    (call $cons (local.get $car) (local.get $cdr)))

  (func $read1 (result i32)
    (local $c i32) (local $x i32)
    (call $skip_ws)
    (if (i32.ge_u (global.get $rp) (global.get $rend)) (then (return (global.get $eof))))
    (local.set $c (i32.load8_u (global.get $rp)))
    (if (i32.eq (local.get $c) (i32.const 40))   ;; '('
      (then (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
            (return (call $read_list))))
    (if (i32.eq (local.get $c) (i32.const 41))   ;; ')' unexpected -> stop
      (then (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
            (return (global.get $eof))))
    (if (i32.eq (local.get $c) (i32.const 39))   ;; '\''
      (then (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
            (local.set $x (call $read1))
            (return (call $cons (call $quote_sym)
                            (call $cons (local.get $x) (global.get $nil))))))
    (if (i32.eq (local.get $c) (i32.const 96))   ;; '`' quasiquote
      (then (global.set $rp (i32.add (global.get $rp) (i32.const 1)))
            (local.set $x (call $read1))
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
                    (local.set $x (call $read1))
                    (call $cons (global.get $sym_uqs)
                          (call $cons (local.get $x) (global.get $nil))))
                  (else
                    (local.set $x (call $read1))
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

  (func $lookup (param $env i32) (param $sym i32) (result i32)
    (local $e i32) (local $frame i32) (local $entry i32)
    (local.set $e (local.get $env))
    (block $notfound (loop $l
      (br_if $notfound (i32.eq (local.get $e) (global.get $nil)))
      (local.set $frame (i32.load offset=4 (local.get $e)))
      (block $framedone (loop $fl
        (br_if $framedone (i32.eq (local.get $frame) (global.get $nil)))
        (local.set $entry (i32.load offset=4 (local.get $frame)))
        (if (i32.eq (i32.load offset=4 (local.get $entry)) (local.get $sym))
          (then (return (i32.load offset=8 (local.get $entry)))))
        (local.set $frame (i32.load offset=8 (local.get $frame)))
        (br $fl)))
      (local.set $e (i32.load offset=8 (local.get $e)))
      (br $l)))
    (call $err_unbound (local.get $sym))
    (unreachable))

  (func $set_bang (param $env i32) (param $sym i32) (param $val i32) (result i32)
    (local $e i32) (local $frame i32) (local $entry i32)
    (local.set $e (local.get $env))
    (block $notfound (loop $l
      (br_if $notfound (i32.eq (local.get $e) (global.get $nil)))
      (local.set $frame (i32.load offset=4 (local.get $e)))
      (block $framedone (loop $fl
        (br_if $framedone (i32.eq (local.get $frame) (global.get $nil)))
        (local.set $entry (i32.load offset=4 (local.get $frame)))
        (if (i32.eq (i32.load offset=4 (local.get $entry)) (local.get $sym))
          (then (i32.store offset=8 (local.get $entry) (local.get $val))
                (return (local.get $val))))
        (local.set $frame (i32.load offset=8 (local.get $frame)))
        (br $fl)))
      (local.set $e (i32.load offset=8 (local.get $e)))
      (br $l)))
    (call $err_unbound (local.get $sym))
    (unreachable))

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

  (func $eval_seq (param $forms i32) (param $env i32) (result i32)
    (local $r i32)
    (local.set $r (global.get $nil))
    (block $d (loop $l
      (br_if $d (i32.eq (local.get $forms) (global.get $nil)))
      (local.set $r (call $eval (i32.load offset=4 (local.get $forms)) (local.get $env)))
      (local.set $forms (i32.load offset=8 (local.get $forms)))
      (br $l)))
    (local.get $r))

  (func $eval_if (param $expr i32) (param $env i32) (result i32)
    (local $rest i32) (local $test i32)
    (local.set $rest (i32.load offset=8 (local.get $expr)))             ;; (test then else)
    (local.set $test (call $eval (i32.load offset=4 (local.get $rest)) (local.get $env)))
    (local.set $rest (i32.load offset=8 (local.get $rest)))             ;; (then else)
    (if (call $is_falsy (local.get $test))
      (then (local.set $rest (i32.load offset=8 (local.get $rest)))))   ;; nil/false -> (else)
    (if (result i32) (i32.eq (local.get $rest) (global.get $nil))
      (then (global.get $nil))
      (else (call $eval (i32.load offset=4 (local.get $rest)) (local.get $env)))))

  (func $eval_define (param $expr i32) (param $env i32) (result i32)
    (local $rest i32) (local $name i32) (local $val i32)
    (local.set $rest (i32.load offset=8 (local.get $expr)))             ;; (name value)
    (local.set $name (i32.load offset=4 (local.get $rest)))
    (local.set $val (call $eval (i32.load offset=4 (i32.load offset=8 (local.get $rest))) (local.get $env)))
    (call $env_define (local.get $env) (local.get $name) (local.get $val))
    (local.get $val))

  ;; Bind a closure/macro's params to args in a fresh env, then eval its body.
  ;; params may be: a proper list (fixed arity), a bare symbol (whole arg list),
  ;; or a dotted tail (a symbol reached mid-list -> bind remaining args).
  (func $apply_user (param $fn i32) (param $args i32) (result i32)
    (local $nenv i32) (local $params i32) (local $a i32)
    (local.set $nenv (call $cons (global.get $nil) (i32.load offset=12 (local.get $fn))))
    (local.set $params (i32.load offset=4 (local.get $fn)))
    (local.set $a (local.get $args))
    (block $bind (loop $bl
      (if (call $is_symbol (local.get $params))
        (then (call $env_define (local.get $nenv) (local.get $params) (local.get $a))
              (br $bind)))
      (br_if $bind (i32.eq (local.get $params) (global.get $nil)))
      (call $env_define (local.get $nenv)
            (i32.load offset=4 (local.get $params))
            (call $car (local.get $a)))
      (local.set $params (i32.load offset=8 (local.get $params)))
      (local.set $a (call $cdr (local.get $a)))
      (br $bl)))
    (call $eval_seq (i32.load offset=8 (local.get $fn)) (local.get $nenv)))

  (func $apply (param $fn i32) (param $args i32) (result i32)
    (local $t i32)
    (if (i32.and (local.get $fn) (i32.const 1)) (then (call $err_apply) (unreachable)))
    (local.set $t (i32.load (local.get $fn)))
    (if (i32.eq (local.get $t) (i32.const 7))   ;; primitive
      (then (return (call $call_prim (i32.load offset=4 (local.get $fn)) (local.get $args)))))
    (if (i32.eq (local.get $t) (i32.const 5))   ;; closure
      (then (return (call $apply_user (local.get $fn) (local.get $args)))))
    (call $err_apply)
    (unreachable))

  ;; kernel-level append: elements of list a, then b (b may be any value)
  (func $lappend (param $a i32) (param $b i32) (result i32)
    (if (result i32) (call $is_pair (local.get $a))
      (then (call $cons (i32.load offset=4 (local.get $a))
                        (call $lappend (i32.load offset=8 (local.get $a)) (local.get $b))))
      (else (local.get $b))))

  ;; quasiquote: walk template; (unquote e) -> eval e;
  ;; ((unquote-splicing e) . rest) -> append (eval e) (qq rest); else literal.
  (func $qq_eval (param $x i32) (param $env i32) (result i32)
    (local $h i32)
    (if (i32.eqz (call $is_pair (local.get $x))) (then (return (local.get $x))))
    (local.set $h (i32.load offset=4 (local.get $x)))
    (if (i32.eq (local.get $h) (global.get $sym_uq))         ;; (unquote e)
      (then (return (call $eval (i32.load offset=4 (i32.load offset=8 (local.get $x))) (local.get $env)))))
    (if (call $is_pair (local.get $h))
      (then (if (i32.eq (i32.load offset=4 (local.get $h)) (global.get $sym_uqs)) ;; ((unquote-splicing e) . rest)
              (then (return (call $lappend
                              (call $eval (i32.load offset=4 (i32.load offset=8 (local.get $h))) (local.get $env))
                              (call $qq_eval (i32.load offset=8 (local.get $x)) (local.get $env))))))))
    (call $cons (call $qq_eval (i32.load offset=4 (local.get $x)) (local.get $env))
                (call $qq_eval (i32.load offset=8 (local.get $x)) (local.get $env))))

  (func $eval (param $expr i32) (param $env i32) (result i32)
    (local $t i32) (local $head i32) (local $fn i32)
    (if (i32.and (local.get $expr) (i32.const 1)) (then (return (local.get $expr))))  ;; fixnum
    (local.set $t (i32.load (local.get $expr)))
    (if (i32.eq (local.get $t) (i32.const 3))   ;; symbol -> lookup
      (then (return (call $lookup (local.get $env) (local.get $expr)))))
    (if (i32.ne (local.get $t) (i32.const 2))   ;; non-pair self-evaluates (nil/true/string/...)
      (then (return (local.get $expr))))
    (local.set $head (i32.load offset=4 (local.get $expr)))
    (if (i32.eq (local.get $head) (global.get $sym_quote))
      (then (return (i32.load offset=4 (i32.load offset=8 (local.get $expr))))))
    (if (i32.eq (local.get $head) (global.get $sym_if))
      (then (return (call $eval_if (local.get $expr) (local.get $env)))))
    (if (i32.eq (local.get $head) (global.get $sym_lambda))
      (then (return (call $make_clo (i32.const 5)
                      (i32.load offset=4 (i32.load offset=8 (local.get $expr)))
                      (i32.load offset=8 (i32.load offset=8 (local.get $expr)))
                      (local.get $env)))))
    (if (i32.eq (local.get $head) (global.get $sym_macro))
      (then (return (call $make_clo (i32.const 6)
                      (i32.load offset=4 (i32.load offset=8 (local.get $expr)))
                      (i32.load offset=8 (i32.load offset=8 (local.get $expr)))
                      (local.get $env)))))
    (if (i32.eq (local.get $head) (global.get $sym_define))
      (then (return (call $eval_define (local.get $expr) (local.get $env)))))
    (if (i32.eq (local.get $head) (global.get $sym_set))
      (then (return (call $set_bang (local.get $env)
                      (i32.load offset=4 (i32.load offset=8 (local.get $expr)))
                      (call $eval (i32.load offset=4 (i32.load offset=8 (i32.load offset=8 (local.get $expr)))) (local.get $env))))))
    (if (i32.eq (local.get $head) (global.get $sym_begin))
      (then (return (call $eval_seq (i32.load offset=8 (local.get $expr)) (local.get $env)))))
    (if (i32.eq (local.get $head) (global.get $sym_qq))
      (then (return (call $qq_eval (i32.load offset=4 (i32.load offset=8 (local.get $expr))) (local.get $env)))))
    ;; application (a macro in head position expands against the raw forms, then re-evals)
    (local.set $fn (call $eval (local.get $head) (local.get $env)))
    (if (call $is_macro (local.get $fn))
      (then (return (call $eval
                      (call $apply_user (local.get $fn) (i32.load offset=8 (local.get $expr)))
                      (local.get $env)))))
    (call $apply (local.get $fn) (call $eval_list (i32.load offset=8 (local.get $expr)) (local.get $env))))

  ;; --- primitives ---
  (func $call_prim (param $id i32) (param $args i32) (result i32)
    (local $acc i32) (local $cur i32) (local $a i32) (local $b i32)
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
          (local.set $acc (i32.add (local.get $acc) (call $fixval (i32.load offset=4 (local.get $cur)))))
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
          (then (return (call $mkfix (i32.sub (i32.const 0) (local.get $acc))))))
        (block $d (loop $l
          (br_if $d (i32.eq (local.get $cur) (global.get $nil)))
          (local.set $acc (i32.sub (local.get $acc) (call $fixval (i32.load offset=4 (local.get $cur)))))
          (local.set $cur (i32.load offset=8 (local.get $cur)))
          (br $l)))
        (return (call $mkfix (local.get $acc)))))
    ;; *  (fold, identity 1)
    (if (i32.eq (local.get $id) (i32.const 8))
      (then
        (local.set $acc (i32.const 1)) (local.set $cur (local.get $args))
        (block $d (loop $l
          (br_if $d (i32.eq (local.get $cur) (global.get $nil)))
          (local.set $acc (i32.mul (local.get $acc) (call $fixval (i32.load offset=4 (local.get $cur)))))
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
          (local.set $acc (i32.div_s (local.get $acc) (call $fixval (i32.load offset=4 (local.get $cur)))))
          (local.set $cur (i32.load offset=8 (local.get $cur)))
          (br $l)))
        (return (call $mkfix (local.get $acc)))))
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
      (then (return (call $mkfix (i32.rem_s (call $fixval (call $car (local.get $args)))
                                            (call $fixval (call $car (call $cdr (local.get $args)))))))))
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
    (global.get $nil))

  ;; --- init ---
  (func $init
    (global.set $heap (i32.const 8192))
    (global.set $nil (call $alloc (i32.const 4)))
    (i32.store (global.get $nil) (i32.const 0))
    (global.set $true (call $alloc (i32.const 4)))
    (i32.store (global.get $true) (i32.const 1))
    (global.set $false (call $alloc (i32.const 4)))
    (i32.store (global.get $false) (i32.const 9))
    (global.set $eof (call $alloc (i32.const 4)))
    (i32.store (global.get $eof) (i32.const 8))
    (global.set $symlist (global.get $nil))
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
    (call $defprim (i32.const 439) (i32.const 9) (i32.const 35)))  ;; to-string

  ;; --- drivers (init is separate so loads accumulate without resetting) ---
  (func (export "init") (call $init))

  (func (export "read_print") (param $ptr i32) (param $len i32)
    (local $v i32)
    (global.set $rp (local.get $ptr))
    (global.set $rend (i32.add (local.get $ptr) (local.get $len)))
    (block $done (loop $l
      (local.set $v (call $read1))
      (br_if $done (i32.eq (local.get $v) (global.get $eof)))
      (call $println (local.get $v))
      (br $l))))

  ;; eval every form, discard results (used to load boot.lisp)
  (func (export "eval_all") (param $ptr i32) (param $len i32)
    (local $v i32)
    (global.set $rp (local.get $ptr))
    (global.set $rend (i32.add (local.get $ptr) (local.get $len)))
    (block $done (loop $l
      (local.set $v (call $read1))
      (br_if $done (i32.eq (local.get $v) (global.get $eof)))
      (drop (call $eval (local.get $v) (global.get $genv)))
      (br $l))))

  ;; eval every form, print each result (used to run a user program)
  (func (export "eval_print") (param $ptr i32) (param $len i32)
    (local $v i32)
    (global.set $rp (local.get $ptr))
    (global.set $rend (i32.add (local.get $ptr) (local.get $len)))
    (block $done (loop $l
      (local.set $v (call $read1))
      (br_if $done (i32.eq (local.get $v) (global.get $eof)))
      (call $println (call $eval (local.get $v) (global.get $genv)))
      (br $l)))))
