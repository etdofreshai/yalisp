;;; Pure Pong state probe for the current YALISP seed.
;;; Rendering, timing, and input are supplied by the browser-host reference.
(begin
  (define pong.next-x (lambda (x velocity) (+ x velocity)))
  (define pong.bounce-x
    (lambda (x velocity minimum maximum)
      (if (< x minimum)
          (- 0 velocity)
          (if (> x maximum) (- 0 velocity) velocity))))
  (list (pong.next-x 120 4)
        (pong.bounce-x 318 4 8 312)))
