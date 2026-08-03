;;; Pure Asteroids state probe for the current YALISP seed.
;;; Vector rendering, timing, input, and projectile storage use the browser host.
(begin
  (define asteroids.wrap
    (lambda (coordinate limit)
      (if (< coordinate 0)
          limit
          (if (>= coordinate limit) 0 coordinate))))
  (define asteroids.next-velocity (lambda (velocity thrust) (+ velocity thrust)))
  (define asteroids.hit-score (lambda (score) (+ score 100)))
  (list (asteroids.wrap -1 640)
        (asteroids.wrap 641 640)
        (asteroids.next-velocity 4 2)
        (asteroids.hit-score 200)))
