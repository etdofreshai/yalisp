;;; Breakout is an executable YALISP application. State and draw decisions are
;;; all here; the browser only forwards controls and draws this protocol.
;;; State: (ball-x ball-y velocity-x velocity-y paddle-x score lives brick-flags)

(defn app.at (xs n) (if (= n 0) (car xs) (app.at (cdr xs) (- n 1))))

(defn app.clamp (value low high) (if (< value low) low (if (> value high) high value)))

(defn app.input? (input name)
  (let ((row (assoc name input))) (if row (= (app.at row 1) 1) false)))

(defn app.set-at (xs index value)
  (if (= index 0) (cons value (cdr xs))
      (cons (car xs) (app.set-at (cdr xs) (- index 1) value))))

(defn app.any-live? (flags)
  (if (nil? flags) false (if (= (car flags) 1) true (app.any-live? (cdr flags)))))

(defn app.mount ()
  '(mount 640 360 Breakout
     ((left hold move-left (ArrowLeft a))
      (right hold move-right (ArrowRight d)))))

(defn app.initial-state () (list 320 278 155 -190 272 0 3 '(1 1 1 1 1 1 1 1)))

(defn app.reset (paddle-x score lives flags) (list 320 278 155 -190 paddle-x score lives flags))

(defn app.hit-index (x y flags index)
  (if (nil? flags) -1
      (if (and (= (car flags) 1) (>= x (+ 36 (* index 72))) (<= x (+ 100 (* index 72))) (>= y 50) (<= y 68))
          index
          (app.hit-index x y (cdr flags) (+ index 1)))))

(defn app.step (state input)
  (let ((x (app.at state 0)) (y (app.at state 1)) (vx (app.at state 2)) (vy (app.at state 3))
        (paddle-x (app.at state 4)) (score (app.at state 5)) (lives (app.at state 6)) (flags (app.at state 7)))
    (let ((direction (if (app.input? input 'left) -1 (if (app.input? input 'right) 1 0))))
      (let ((next-paddle-x (app.clamp (+ paddle-x (* direction 20)) 0 544))
            (next-x (+ x (if (> vx 0) 12 -12)))
            (next-y (+ y (if (> vy 0) 14 -14))))
        (let ((wall-x (if (<= next-x 8) 8 (if (>= next-x 632) 632 next-x)))
              (wall-vx (if (or (<= next-x 8) (>= next-x 632)) (- 0 vx) vx))
              (wall-y (if (<= next-y 8) 8 next-y))
              (wall-vy (if (<= next-y 8) (- 0 vy) vy)))
          (let ((paddle-hit (and (> wall-vy 0) (>= wall-y 320) (<= wall-y 340) (>= wall-x next-paddle-x) (<= wall-x (+ next-paddle-x 96))))
                (hit (app.hit-index wall-x wall-y flags 0)))
            (let ((paddle-y (if paddle-hit 320 wall-y))
                  (paddle-vy (if paddle-hit (- 0 wall-vy) wall-vy))
                  (next-flags (if (>= hit 0) (app.set-at flags hit 0) flags))
                  (next-score (if (>= hit 0) (+ score 10) score)))
              (let ((brick-vy (if (>= hit 0) (- 0 paddle-vy) paddle-vy)))
                (if (> paddle-y 370)
                    (app.reset next-paddle-x next-score (- lives 1) next-flags)
                    (list wall-x paddle-y wall-vx brick-vy next-paddle-x next-score lives next-flags))))))))))

(defn app.draw-bricks (flags index)
  (if (nil? flags) nil
      (if (= (car flags) 1)
          (cons (list 'rect (+ 36 (* index 72)) 50 64 18 (if (= (mod index 2) 0) 2 3))
                (app.draw-bricks (cdr flags) (+ index 1)))
          (app.draw-bricks (cdr flags) (+ index 1)))))

(defn app.draw (state)
  (let ((x (app.at state 0)) (y (app.at state 1)) (paddle-x (app.at state 4)) (flags (app.at state 7)))
    (cons (list 'clear 0)
          (cons (list 'rect paddle-x 328 96 12 1)
                (cons (list 'circle x y 8 1) (app.draw-bricks flags 0))))))

(defn app.view (state)
  (list (cons 'draw (app.draw state)) (list 'status (app.at state 5) (app.at state 6))))

(defn app.frame (state input)
  (let ((next (app.step state input))) (cons (list 'state next) (app.view next))))
