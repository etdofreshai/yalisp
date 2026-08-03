;;; Pong is an executable YALISP application. The browser only launches this
;;; source, passes the current controls, and renders the returned draw protocol.
;;; State: (ball-x ball-y velocity-x velocity-y player-y opponent-y player-score opponent-score)

(defn app.at (xs n)
  (if (= n 0) (car xs) (app.at (cdr xs) (- n 1))))

(defn app.clamp (value low high)
  (if (< value low) low (if (> value high) high value)))

(defn app.input? (input name)
  (let ((row (assoc name input)))
    (if row (= (app.at row 1) 1) false)))

(defn app.mount ()
  '(mount 640 360 Pong
     ((up hold move-up (ArrowUp w))
      (down hold move-down (ArrowDown s)))))

(defn app.initial-state () (list 320 180 230 145 142 142 0 0))

(defn app.reset (direction player-score opponent-score)
  (list 320 180 (* 230 direction) 145 142 142 player-score opponent-score))

(defn app.step (state input)
  (let ((x (app.at state 0)) (y (app.at state 1))
        (vx (app.at state 2)) (vy (app.at state 3))
        (player-y (app.at state 4)) (opponent-y (app.at state 5))
        (player-score (app.at state 6)) (opponent-score (app.at state 7)))
    (let ((direction (if (app.input? input 'up) -1 (if (app.input? input 'down) 1 0))))
      (let ((next-player-y (app.clamp (+ player-y (* direction 18)) 0 284))
            (next-opponent-y (app.clamp (+ opponent-y (if (< opponent-y (- y 38)) -12 (if (> opponent-y (- y 38)) 12 0))) 0 284))
            (next-x (+ x (if (> vx 0) 16 -16)))
            (next-y (+ y (if (> vy 0) 10 -10))))
        (let ((bounce-y (if (<= next-y 8) 8 (if (>= next-y 352) 352 next-y)))
              (bounce-vy (if (or (<= next-y 8) (>= next-y 352)) (- 0 vy) vy)))
          (let ((player-hit (and (< vx 0) (<= next-x 40) (> next-x 20) (>= bounce-y next-player-y) (<= bounce-y (+ next-player-y 76))))
                (opponent-hit (and (> vx 0) (>= next-x 600) (< next-x 620) (>= bounce-y next-opponent-y) (<= bounce-y (+ next-opponent-y 76)))))
            (let ((bounce-x (if player-hit 48 (if opponent-hit 592 next-x)))
                  (bounce-vx (if player-hit 230 (if opponent-hit -230 vx))))
              (if (< bounce-x 0)
                  (app.reset 1 player-score (+ opponent-score 1))
                  (if (> bounce-x 640)
                      (app.reset -1 (+ player-score 1) opponent-score)
                      (list bounce-x bounce-y bounce-vx bounce-vy next-player-y next-opponent-y player-score opponent-score))))))))))

(defn app.draw (state)
  (let ((x (app.at state 0)) (y (app.at state 1))
        (player-y (app.at state 4)) (opponent-y (app.at state 5))
        (player-score (app.at state 6)) (opponent-score (app.at state 7)))
    (list (list 'clear 0)
          (list 'line 320 0 320 360 1 1)
          (list 'rect 28 player-y 12 76 1)
          (list 'rect 600 opponent-y 12 76 1)
          (list 'circle x y 8 2)
          (list 'rect (+ 282 (* player-score 8)) 22 12 18 1)
          (list 'rect (+ 342 (* opponent-score 8)) 22 12 18 1))))

(defn app.view (state)
  (list (cons 'draw (app.draw state))
        (list 'status (app.at state 6) (app.at state 7))))

(defn app.frame (state input)
  (let ((next (app.step state input)))
    (cons (list 'state next) (app.view next))))
