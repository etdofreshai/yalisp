;;; YALISP M1 compiler - a deliberately bounded compiler written in YALISP.
;;;
;;; Derived from the integer compiler in ETdoFreshAI/lispish
;;; apps/shared/level1/compile.lisp at commit b7214f1. Lispish lowers a function
;;; to a WebAssembly text payload and lets its host assemble that payload. This
;;; first YALISP milestone keeps the same honest boundary.
;;;
;;; Supported input to cc.compile:
;;;   - exactly one distinct parameter
;;;   - exactly one body form
;;;   - integer literals and that parameter
;;;   - nested, binary +, -, and * expressions
;;; Everything else returns nil and remains interpreted. Semantic equivalence is
;;; guaranteed only while inputs and intermediate results stay in the seed's
;;; signed 30-bit fixnum range.

(defn cc.index (sym params i)
  (cond ((nil? params) nil)
        ((eq? (car params) sym) i)
        (true (cc.index sym (cdr params) (+ i 1)))))

(defn cc.binary? (form)
  (and (pair? form)
       (pair? (cdr form))
       (pair? (cdr (cdr form)))
       (nil? (cdr (cdr (cdr form))))))

(defn cc.wop (op)
  (cond ((eq? op '+) "i32.add")
        ((eq? op '-) "i32.sub")
        ((eq? op '*) "i32.mul")
        (true nil)))

(defn cc.expr (form params)
  (cond ((number? form)
         (string.append "(i32.const " (to-string form) ")"))
        ((symbol? form)
         (let ((i (cc.index form params 0)))
           (if (nil? i) nil
               (string.append "(local.get " (to-string i) ")"))))
        ((pair? form) (cc.op form params))
        (true nil)))

(defn cc.op (form params)
  (if (cc.binary? form)
      (let ((wop (cc.wop (car form))))
        (if (nil? wop) nil
            (let ((a (cc.expr (car (cdr form)) params))
                  (b (cc.expr (car (cdr (cdr form))) params)))
              (if (or (nil? a) (nil? b)) nil
                  (string.append "(" wop " " a " " b ")")))))
      nil))

(defn cc.proper-list? (xs)
  (cond ((nil? xs) true)
        ((pair? xs) (cc.proper-list? (cdr xs)))
        (true false)))

(defn cc.distinct? (xs)
  (cond ((nil? xs) true)
        ((member? (car xs) (cdr xs)) false)
        (true (cc.distinct? (cdr xs)))))

(defn cc.params (params)
  (if (= (length params) 1) "(param i32)" nil))

(defn cc.compile (params body-forms)
  (if (and (cc.proper-list? params)
           (cc.distinct? params)
           (= (length params) 1)
           (pair? body-forms)
           (nil? (cdr body-forms)))
      (let ((body (cc.expr (car body-forms) params)))
        (if (nil? body) nil
            (string.append (cc.params params) " (result i32) " body)))
      nil))
