;;; The complete Hello World application. The browser and CLI only launch it.

(defn app.at (xs n) (if (= n 0) (car xs) (app.at (cdr xs) (- n 1))))
(defn app.input? (input name) (let ((row (assoc name input))) (if row (= (app.at row 1) 1) false)))
(defn app.mount () '(mount 640 160 Hello-world ((run press run (Enter)))))
(defn app.initial-state () 0)
(defn app.result () "Hello, world!")
(defn app.view (state)
  (list (cons 'draw (list (list 'clear 0) (list 'rect 96 68 448 24 2)))
        (list 'status (if (= state 0) 'ready 'printed))))
(defn app.frame (state input)
  (let ((next (if (app.input? input 'run) 1 state)))
    (append (append (list (list 'state next)) (app.view next))
            (if (app.input? input 'run) (list (list 'result)) nil))))
