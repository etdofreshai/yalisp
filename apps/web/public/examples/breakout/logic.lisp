;;; Pure Breakout state probe for the current YALISP seed.
;;; Brick rendering, timing, and input are supplied by the browser-host reference.
(begin
  (define breakout.next-x (lambda (x velocity) (+ x velocity)))
  (define breakout.bounce-y
    (lambda (hit velocity) (if hit (- 0 velocity) velocity)))
  (define breakout.hit-score (lambda (score) (+ score 10)))
  (list (breakout.next-x 150 4)
        (breakout.bounce-y true 5)
        (breakout.hit-score 20)))
