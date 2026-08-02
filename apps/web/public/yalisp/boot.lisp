;;; Derived from ETdoFreshAI/lispish commit c78a2be (M9 bootstrap).
;;; boot.lisp - the standard-tier of YALISP, written in YALISP.
;;;
;;; Loaded onto the WebAssembly seed generated from src/seed/bootstrap.wat.
;;; The WAT and this file are checked-in sources; public/yalisp/seed.wasm is a
;;; build artifact. Together they demonstrate the intended bootstrapping
;;; direction: the seed provides 7 special forms (quote if lambda macro define
;;; set! begin) plus a small primitive set; everything below is evaluated from
;;; this YALISP source.
;;;
;;; Reference provenance: the boot/core.lisp [defined] section at Lispish
;;; commit c78a2be. Adapted to this checked-in YALISP seed, with these gaps:
;;;   - names are unqualified (no core.* prefix yet; needs namespaces/`using`)
;;;   - nil stands in for the boolean `false` (kernel has no distinct false yet)
;;;   - cond/let/and/or are macros here (core.lisp lists them as special forms,
;;;     but the kernel keeps only 7 - metacircular-first)

;;; --- control: cond (a recursively-expanding macro over `if`) ---
;;; Macro bodies use quasiquote (`, ,@) - the kernel's M7 feature - to build
;;; the expansion as a template instead of hand-cons'ing it.
(define cond
  (macro clauses
    (if (eq clauses nil)
        nil
        `(if ,(car (car clauses))
             (begin ,@(cdr (car clauses)))
             (cond ,@(cdr clauses))))))

;;; --- boolean / equality (functions) ---
;; nil? symbol? pair? list? number? string? boolean? function? primitive?
;; closure? macro? atom? eq? are kernel primitives (M8); not/equal? are defined.
(define not
  (lambda (x) (if x false true)))

;; structural equality: pairs compared element-wise, atoms by identity
(define equal?
  (lambda (a b)
    (cond ((atom? a) (if (atom? b) (eq? a b) false))
          ((atom? b) false)
          ((equal? (car a) (car b)) (equal? (cdr a) (cdr b)))
          (true false))))

;;; --- more control sugar (macros) ---
(define when
  (macro (test . body)
    `(if ,test (begin ,@body) nil)))

(define unless
  (macro (test . body)
    `(if ,test nil (begin ,@body))))

(define and
  (macro args
    (cond ((nil? args) true)
          ((nil? (cdr args)) (car args))
          (true `(if ,(car args) (and ,@(cdr args)) false)))))

(define or
  (macro args
    (cond ((nil? args) false)
          ((nil? (cdr args)) (car args))
          ;; Evaluate the first operand once. The remaining operands live in a
          ;; zero-argument thunk created in the caller's environment, so the
          ;; macro's internal bindings cannot capture identifiers in user code.
          (true `((lambda (or--once-value or--rest-thunk)
                    (if or--once-value or--once-value (or--rest-thunk)))
                  ,(car args)
                  (lambda () (or ,@(cdr args))))))))

;; (defn name param-spec body...) -> (define name (lambda param-spec body...))
(define defn
  (macro (name params . body)
    `(define ,name (lambda ,params ,@body))))

;; (do a b c) -> (begin a b c)
(define do
  (macro forms `(begin ,@forms)))

;;; --- list library (mirrors docs/core.lisp section 8) ---
(define empty?
  (lambda (xs) (nil? xs)))

(define length
  (lambda (xs)
    (if (nil? xs) 0 (+ 1 (length (cdr xs))))))

(define append
  (lambda (xs ys)
    (if (nil? xs) ys (cons (car xs) (append (cdr xs) ys)))))

(define foldl
  (lambda (f acc xs)
    (if (nil? xs) acc (foldl f (f acc (car xs)) (cdr xs)))))

(define foldr
  (lambda (f acc xs)
    (if (nil? xs) acc (f (car xs) (foldr f acc (cdr xs))))))

(define reduce
  (lambda (f init xs) (foldl f init xs)))

(define reverse
  (lambda (xs)
    (foldl (lambda (acc x) (cons x acc)) nil xs)))

(define map
  (lambda (f xs)
    (if (nil? xs) nil (cons (f (car xs)) (map f (cdr xs))))))

(define filter
  (lambda (pred xs)
    (cond ((nil? xs) nil)
          ((pred (car xs)) (cons (car xs) (filter pred (cdr xs))))
          (true (filter pred (cdr xs))))))

(define member?
  (lambda (x xs)
    (cond ((nil? xs) false)
          ((equal? x (car xs)) true)
          (true (member? x (cdr xs))))))

(define assoc
  (lambda (key alist)
    (cond ((nil? alist) nil)
          ((equal? key (car (car alist))) (car alist))
          (true (assoc key (cdr alist))))))

(define compose
  (lambda (f g) (lambda (x) (f (g x)))))

;; (let ((a 1) (b 2)) body...) -> ((lambda (a b) body...) 1 2)
(define let
  (macro (bindings . body)
    `((lambda ,(map car bindings) ,@body)
      ,@(map (lambda (b) (car (cdr b))) bindings))))
