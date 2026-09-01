;;; WL_INTER.C - intermission, victory, preload, and high scores in YALisp.
;;;
;;; Animation waits are exposed as resumable steps. The browser schedules those
;;; steps; Lisp owns score arithmetic, sound/music decisions, framebuffer art,
;;; phase order, and the exact state advanced at each step.

(define wl.VBLWAIT 30)
(define wl.PAR-AMOUNT 500)
(define wl.PERCENT100AMT 10000)
(define wl.TICKBASE 70)
(define wl.ENDBONUS1SND 42)
(define wl.ENDBONUS2SND 43)
(define wl.NOBONUSSND 47)
(define wl.PERCENT100SND 48)
(define wl.ENDLEVEL-MUS 16)
(define wl.ROSTER-MUS 23)
(define wl.URAHERO-MUS 24)

(define wl.L-GUYPIC 43)
(define wl.L-COLONPIC 44)
(define wl.L-NUM0PIC 45)
(define wl.L-PERCENTPIC 55)
(define wl.L-APIC 56)
(define wl.L-EXPOINTPIC 82)
(define wl.L-APOSTROPHEPIC 83)
(define wl.L-GUY2PIC 84)
(define wl.L-BJWINSPIC 85)
(define wl.PG13PIC 88)
(define wl.HIGHSCORESPIC 90)
(define wl.C-LEVELPIC 38)
(define wl.C-NAMEPIC 39)
(define wl.C-SCOREPIC 40)
(define wl.GETPSYCHEDPIC 134)

;;; Seconds, rather than C floats, preserve every delivered WL6 par time.
(define wl.par-times
  '(90 120 120 210 180 180 150 150 0 0
    90 210 180 120 240 360 60 180 0 0
    90 90 150 150 210 150 120 360 0 0
    120 120 90 60 270 210 120 270 0 0
    150 90 150 150 240 180 270 210 0 0
    390 240 270 360 300 330 330 510 0 0))

(define wl.level-ratios nil)
(define wl.window-x 0)
(define wl.window-y 0)
(define wl.window-w 320)
(define wl.window-h 160)
(define wl.intermission-state '(idle))
(define wl.intermission-execution '(idle))
(define wl.intermission-events nil)
(define wl.victory-execution '(idle))
(define wl.bj-breathe-which 0)
(define wl.bj-breathe-max 10)
(define wl.presentation-font nil)

(defn wl.cache-presentation-font ()
  (if (nil? wl.presentation-font)
      (set! wl.presentation-font
        (wl.cache-font app.vgahead app.vgagraph app.vgadict 1))
      wl.presentation-font))

(defn wl.clear-split-vwb ()
  (begin
    (set! wl.window-x 0) (set! wl.window-y 0)
    (set! wl.window-w 320) (set! wl.window-h 160)
    (list wl.window-x wl.window-y wl.window-w wl.window-h)))

(defn wl.percent (count total)
  (if (= total 0) 0 (/ (* count 100) total)))

(defn wl.calculate-level-completed ()
  (let ((seconds (if (> (/ app.time-count wl.TICKBASE) 5940)
                     5940 (/ app.time-count wl.TICKBASE))))
    (if (>= wl.map 8)
        (list 0 0 0 seconds 15000)
        (let ((kill (wl.percent wl.killcount wl.killtotal))
              (secret (wl.percent wl.secretcount wl.secrettotal))
              (treasure (wl.percent wl.treasurecount wl.treasuretotal))
              (par (wl.play-at wl.par-times (+ (* wl.episode 10) wl.map))))
          (let ((timeleft (if (< app.time-count (* par wl.TICKBASE))
                              (- par seconds) 0)))
            (list kill secret treasure seconds
                  (+ (* timeleft wl.PAR-AMOUNT)
                     (+ (if (= kill 100) wl.PERCENT100AMT 0)
                        (+ (if (= secret 100) wl.PERCENT100AMT 0)
                           (if (= treasure 100) wl.PERCENT100AMT 0))))))))))

(defn wl.replace-at (values index value)
  (if (= index 0)
      (cons value (if (nil? values) nil (cdr values)))
      (cons (if (nil? values) nil (car values))
            (wl.replace-at (if (nil? values) nil (cdr values)) (- index 1) value))))

(defn wl.level-completed ()
  (let ((result (wl.calculate-level-completed)))
    (begin
      (if (< wl.map 8)
          (set! wl.level-ratios (wl.replace-at wl.level-ratios wl.map result)) nil)
      (wl.give-points (wl.play-at result 4))
      (set! wl.intermission-state (list 'level 0 result))
      (set! wl.intermission-events nil)
      (set! wl.intermission-execution (wl.level-count-start result))
      result)))

;;; The DOS implementation blocks inside its time/ratio loops and sound waits.
;;; The browser adaptation below exposes one source loop iteration per call and
;;; represents every VBL/ack wait in data. app.intermission-advance retains its
;;; older phase wrapper below; hosts that need source-ticked execution call
;;; wl.intermission-tick and schedule the returned wait states.
(defn wl.intermission-event (event)
  (begin
    (set! wl.intermission-events
      (cons (list app.time-count event) wl.intermission-events))
    event))

(defn wl.intermission-event-log () (reverse wl.intermission-events))

(defn wl.level-time-left (result)
  (/ (- (wl.play-at result 4)
        (+ (if (= (wl.play-at result 0) 100) wl.PERCENT100AMT 0)
           (+ (if (= (wl.play-at result 1) 100) wl.PERCENT100AMT 0)
              (if (= (wl.play-at result 2) 100) wl.PERCENT100AMT 0))))
     wl.PAR-AMOUNT))

(defn wl.level-count-start (result)
  (if (>= wl.map 8)
      (list 'level-wait result)
      (let ((timeleft (wl.level-time-left result)))
        (if (> timeleft 0)
            (list 'level-time 0 timeleft result)
            (list 'level-ratio 0 0 (wl.play-at result 0) 0 result)))))

(defn wl.intermission-sound (sound)
  (begin
    (wl.intermission-event (list 'sound sound))
    (wl.play-sound sound 'intermission)))

(defn wl.intermission-tick (acknowledged elapsed)
  (let ((kind (car wl.intermission-execution)))
    (cond ((or (eq? kind 'level-time) (eq? kind 'level-time-finish))
           (if acknowledged (wl.intermission-skip) (wl.intermission-time-tick)))
          ((or (eq? kind 'level-ratio) (eq? kind 'level-ratio-finish))
           (if acknowledged (wl.intermission-skip) (wl.intermission-ratio-tick)))
          ((eq? kind 'level-ratio-delay)
           (if acknowledged (wl.intermission-skip)
               (wl.intermission-delay-tick elapsed)))
          ((eq? kind 'level-wait)
           (if acknowledged
               (begin
                 (wl.intermission-event '(ack final))
                 (set! wl.intermission-execution '(level-done))
                 wl.intermission-execution)
               wl.intermission-execution))
          (true wl.intermission-execution))))

(defn wl.intermission-skip ()
  (begin
    (wl.intermission-event '(ack skip-counts))
    (set! wl.intermission-execution
      (list 'level-wait (wl.intermission-result wl.intermission-execution)))
    wl.intermission-execution))

(defn wl.intermission-result (state)
  (let ((kind (car state)))
    (cond ((eq? kind 'level-time) (wl.play-at state 3))
          ((eq? kind 'level-time-finish) (wl.play-at state 1))
          ((eq? kind 'level-ratio) (wl.play-at state 5))
          ((eq? kind 'level-ratio-finish) (wl.play-at state 3))
          ((eq? kind 'level-ratio-delay) (wl.play-at state 4))
          ((eq? kind 'level-wait) (wl.play-at state 1))
          (true '(0 0 0 0 0)))))

(defn wl.intermission-time-tick ()
  (if (eq? (car wl.intermission-execution) 'level-time-finish)
      (let ((result (wl.play-at wl.intermission-execution 1)))
        (begin
          (wl.intermission-sound wl.ENDBONUS2SND)
          (set! wl.intermission-execution
            (list 'level-ratio 0 0 (wl.play-at result 0)
                  (* (wl.level-time-left result) wl.PAR-AMOUNT) result))
          wl.intermission-execution))
      (let ((count (wl.play-at wl.intermission-execution 1))
            (timeleft (wl.play-at wl.intermission-execution 2))
            (result (wl.play-at wl.intermission-execution 3)))
        (begin
          (wl.intermission-event (list 'time-bonus (* count wl.PAR-AMOUNT)))
          (if (= (mod count (/ wl.PAR-AMOUNT 10)) 0)
              (wl.intermission-sound wl.ENDBONUS1SND) nil)
          (set! wl.intermission-execution
            (if (= count timeleft)
                (list 'level-time-finish result)
                (list 'level-time (+ count 1) timeleft result)))
          wl.intermission-execution))))

(defn wl.intermission-ratio-tick ()
  (if (eq? (car wl.intermission-execution) 'level-ratio-finish)
      (wl.intermission-finish-ratio)
      (let ((which (wl.play-at wl.intermission-execution 1))
            (count (wl.play-at wl.intermission-execution 2))
            (target (wl.play-at wl.intermission-execution 3))
            (bonus (wl.play-at wl.intermission-execution 4))
            (result (wl.play-at wl.intermission-execution 5)))
        (begin
          (wl.intermission-event (list 'ratio which count))
          (if (= (mod count 10) 0) (wl.intermission-sound wl.ENDBONUS1SND) nil)
          (set! wl.intermission-execution
            (if (= count target)
                (list 'level-ratio-finish which bonus result)
                (list 'level-ratio which (+ count 1) target bonus result)))
          wl.intermission-execution))))

(defn wl.intermission-finish-ratio ()
  (let ((which (wl.play-at wl.intermission-execution 1))
        (bonus (wl.play-at wl.intermission-execution 2))
        (result (wl.play-at wl.intermission-execution 3)))
    (let ((ratio (wl.play-at result which)))
      (cond ((= ratio 100)
             (begin
               (wl.intermission-event (list 'wait-vbl wl.VBLWAIT which))
               (set! wl.intermission-execution
                 (list 'level-ratio-delay which wl.VBLWAIT
                       (+ bonus wl.PERCENT100AMT) result))
               wl.intermission-execution))
            ((= ratio 0)
             (begin
               (wl.intermission-event (list 'wait-vbl wl.VBLWAIT which))
               (set! wl.intermission-execution
                 (list 'level-ratio-delay which wl.VBLWAIT bonus result))
               wl.intermission-execution))
            (true
             (begin
               (wl.intermission-sound wl.ENDBONUS2SND)
               (wl.intermission-next-ratio which bonus result)))))))

(defn wl.intermission-delay-tick (elapsed)
  (let ((which (wl.play-at wl.intermission-execution 1))
        (remaining (wl.play-at wl.intermission-execution 2))
        (bonus (wl.play-at wl.intermission-execution 3))
        (result (wl.play-at wl.intermission-execution 4)))
    (if (< elapsed remaining)
        (begin
          (set! wl.intermission-execution
            (list 'level-ratio-delay which (- remaining elapsed) bonus result))
          wl.intermission-execution)
        (begin
          (if (= (wl.play-at result which) 100)
              (begin
                (wl.intermission-event (list 'bonus bonus))
                (wl.intermission-sound wl.PERCENT100SND))
              (wl.intermission-sound wl.NOBONUSSND))
          (wl.intermission-next-ratio which bonus result)))))

(defn wl.intermission-next-ratio (which bonus result)
  (if (= which 2)
      (begin
        (set! wl.intermission-execution (list 'level-wait result))
        wl.intermission-execution)
      (let ((next (+ which 1)))
        (begin
          (set! wl.intermission-execution
            (list 'level-ratio next 0 (wl.play-at result next) bonus result))
          wl.intermission-execution))))

(defn wl.ratio-or-zero (index)
  (let ((ratio (wl.play-at-safe wl.level-ratios index)))
    (if (nil? ratio) '(0 0 0 0 0) ratio)))

(defn wl.play-at-safe (values index)
  (if (nil? values) nil
      (if (= index 0) (car values) (wl.play-at-safe (cdr values) (- index 1)))))

(defn wl.victory-summary ()
  (wl.victory-summary-at 0 0 0 0 0))

(defn wl.victory-summary-at (index seconds kill secret treasure)
  (if (= index 8)
      (let ((minutes (/ seconds 60)) (remaining (mod seconds 60)))
        (if (> minutes 99)
            (list 99 99 (/ kill 8) (/ secret 8) (/ treasure 8))
            (list minutes remaining (/ kill 8) (/ secret 8) (/ treasure 8))))
      (let ((ratio (wl.ratio-or-zero index)))
        (wl.victory-summary-at (+ index 1)
          (+ seconds (wl.play-at ratio 3))
          (+ kill (wl.play-at ratio 0))
          (+ secret (wl.play-at ratio 1))
          (+ treasure (wl.play-at ratio 2))))))

(defn wl.victory ()
  (begin
    (wl.start-music wl.URAHERO-MUS)
    (let ((summary (wl.victory-summary)))
      (begin
        (set! wl.intermission-state (list 'victory 0 summary))
        (set! wl.victory-execution (list 'victory-wait summary))
        summary))))

(defn wl.victory-tick (acknowledged)
  (if (eq? (car wl.victory-execution) 'victory-wait)
      (if acknowledged
          (begin
            ;; Non-SPEAR Victory fades after IN_Ack, then transfers to EndText.
            (set! wl.victory-execution
              (list 'victory-end-text wl.episode (wl.play-at wl.victory-execution 1)))
            wl.victory-execution)
          wl.victory-execution)
      wl.victory-execution))

(defn wl.level-char-picture (character)
  (let ((code (wl.ascii-code character)))
    (cond ((and (>= code 48) (<= code 57)) (+ wl.L-NUM0PIC (- code 48)))
          ((and (>= code 65) (<= code 90)) (+ wl.L-APIC (- code 65)))
          ((and (>= code 97) (<= code 122)) (+ wl.L-APIC (- code 97)))
          ((= code 58) wl.L-COLONPIC)
          ((= code 37) wl.L-PERCENTPIC)
          ((= code 33) wl.L-EXPOINTPIC)
          ((= code 39) wl.L-APOSTROPHEPIC)
          (true -1))))

(defn wl.write (frame x y string)
  (wl.write-marked frame x y string (heap.used)))

(defn wl.write-marked (frame x y string mark)
  (begin
    (wl.write-at frame (* x 8) (* y 8) (* x 8) string 0)
    (heap.release mark)
    frame))

(defn wl.write-at (frame origin x y string at)
  (if (= at (string.length string))
      frame
      (let ((character (wl.text-char string at)))
        (if (string=? character "\n")
            (wl.write-at frame origin origin (+ y 16) string (+ at 1))
            (let ((picture (wl.level-char-picture character)))
              (begin
                (if (>= picture 0)
                    (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict
                                     app.pictable x y picture) nil)
                (wl.write-at frame origin
                  (+ x (if (or (string=? character ":")
                               (or (string=? character "!")
                                   (string=? character "'"))) 8 16))
                  y string (+ at 1))))))))

(defn wl.two-digits (value)
  (if (< value 10) (string.append "0" (to-string value)) (to-string value)))

(defn wl.draw-level-completed (frame result)
  (let ((font (wl.cache-presentation-font)))
    (begin
      (wl.bar frame 0 0 320 160 127)
      (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                       0 16 wl.L-GUYPIC)
      ;; YALisp's seed has no retained graphics-chunk cache. Re-expanding one
      ;; 16x16 level alphabet chunk per character consumes the bounded
      ;; interpreter heap, so labels use the game's own proportional font.
      ;; Panel pictures, geometry, values, sequencing, and indexed output stay
      ;; source-owned; a future generic retained-cache primitive can remove
      ;; this documented browser-host difference without changing these APIs.
      (if (>= wl.map 8)
          (begin (wl.inter-text frame font 112 32 "SECRET FLOOR")
                 (wl.inter-text frame font 112 48 "COMPLETED!")
                 (wl.inter-text frame font 80 128 "15000 BONUS!"))
          (let ((seconds (wl.play-at result 3)))
            (begin
              (wl.inter-text frame font 112 16 "FLOOR COMPLETED")
              (wl.inter-text frame font 208 32 (to-string (+ wl.map 1)))
              (wl.inter-text frame font 112 56 "BONUS")
              (wl.inter-text frame font 224 56 (to-string (wl.play-at result 4)))
              (wl.inter-text frame font 128 80 "TIME")
              (wl.inter-text frame font 208 80
                (string.append (wl.two-digits (/ seconds 60))
                               (string.append ":" (wl.two-digits (mod seconds 60)))))
              (wl.inter-text frame font 72 112 "KILL RATIO")
              (wl.inter-text frame font 40 128 "SECRET RATIO")
              (wl.inter-text frame font 8 144 "TREASURE RATIO")
              (wl.inter-text frame font 280 112 (to-string (wl.play-at result 0)))
              (wl.inter-text frame font 280 128 (to-string (wl.play-at result 1)))
              (wl.inter-text frame font 280 144 (to-string (wl.play-at result 2))))))
      frame)))

(defn wl.inter-text (frame font x y string)
  (begin (wl.draw-prop-string frame font string x y 15) frame))

(defn wl.write-ratio (frame y ratio)
  (wl.write frame (- 37 (* (string.length (to-string ratio)) 2)) y (to-string ratio)))

(defn wl.draw-victory (frame summary)
  (let ((font (wl.cache-presentation-font)))
    (begin
      (wl.bar frame 0 0 320 160 127)
      (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                       8 4 wl.L-BJWINSPIC)
      (wl.inter-text frame font 144 16 "YOU WIN!")
      (wl.inter-text frame font 112 48 "TOTAL TIME")
      (wl.inter-text frame font 96 96 "AVERAGES")
      (wl.inter-text frame font 112 112 "KILL")
      (wl.inter-text frame font 80 128 "SECRET")
      (wl.inter-text frame font 48 144 "TREASURE")
      (wl.inter-text frame font 208 64
        (string.append (wl.two-digits (wl.play-at summary 0))
                       (string.append ":" (wl.two-digits (wl.play-at summary 1)))))
      (wl.inter-text frame font 240 112 (to-string (wl.play-at summary 2)))
      (wl.inter-text frame font 240 128 (to-string (wl.play-at summary 3)))
      (wl.inter-text frame font 240 144 (to-string (wl.play-at summary 4)))
      frame)))

;;; The source count-up can be skipped by acknowledgement. One call performs
;;; one observable phase, allowing deterministic replay without a busy wait.
(defn wl.intermission-step (acknowledged)
  (cond ((eq? (car wl.intermission-state) 'level)
         (if acknowledged
             (begin (set! wl.intermission-state '(level-done)) '(level-done))
             (wl.intermission-level-step)))
        ((eq? (car wl.intermission-state) 'victory)
         (begin (set! wl.intermission-state '(victory-done)) '(victory-done)))
        (true wl.intermission-state)))

(defn wl.intermission-level-step ()
  (let ((phase (wl.play-at wl.intermission-state 1))
        (result (wl.play-at wl.intermission-state 2)))
    (if (= phase 4)
        (begin (set! wl.intermission-state '(level-done)) '(level-done))
        (begin
          (wl.play-sound
            (if (and (> phase 0) (= (wl.play-at result (- phase 1)) 100))
                wl.PERCENT100SND wl.ENDBONUS2SND) 'intermission)
          (set! wl.intermission-state (list 'level (+ phase 1) result))
          wl.intermission-state))))

(defn wl.bj-breathe (time-count)
  (if (> time-count wl.bj-breathe-max)
      (begin
        (set! wl.bj-breathe-which (bit.xor wl.bj-breathe-which 1))
        (set! wl.bj-breathe-max 35)
        (list wl.bj-breathe-which
              (if (= wl.bj-breathe-which 0) wl.L-GUYPIC wl.L-GUY2PIC)))
      (list wl.bj-breathe-which 0)))

(defn wl.pg13 (frame)
  (begin
    (wl.bar frame 0 0 320 200 130)
    (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                     216 110 wl.PG13PIC)
    (set! wl.intermission-state '(pg13 490))
    frame))

(defn wl.preload-update (frame current total)
  (if (or (<= total 0) (or (< current 0) (> current total)))
      false
      (begin
        (wl.bar frame 32 170 256 8 0)
        (wl.bar frame 33 171 (/ (* current 254) total) 6 79)
        (list current total))))

(defn wl.preload-graphics (frame)
  (begin
    (wl.bar frame 0 0 320 200 0)
    (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                     80 48 wl.GETPSYCHEDPIC)
    (set! wl.intermission-state '(preload 0 4))
    frame))

(defn wl.end-screen (frame palette screen)
  (begin
    (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                     0 0 screen)
    (set! wl.intermission-state (list 'end-screen palette screen))
    frame))

;;; HighScore insertion: score first, completed floor second, episode never a
;;; tie breaker. Entries are (name score completed episode).
(define wl.MAXSCORES 7)
(define wl.scores
  '(("id software-'" 10000 1 0) ("Adrian Carmack" 10000 1 0)
    ("John Carmack" 10000 1 0) ("Tom Hall" 10000 1 0)
    ("Kevin Cloud" 10000 1 0) ("Jay Wilbur" 10000 1 0)
    ("BJ Blazkowicz" 10000 1 0)))

(defn wl.high-score-better? (entry score completed)
  (or (> score (wl.play-at entry 1))
      (and (= score (wl.play-at entry 1)) (> completed (wl.play-at entry 2)))))

(defn wl.check-high-score (score completed episode)
  (let ((insert (wl.high-score-index wl.scores score completed 0)))
    (if (< insert 0)
        -1
        (begin
          (set! wl.scores
            (wl.high-score-insert wl.scores insert (list "" score completed episode) 0))
          insert))))

(defn wl.high-score-index (scores score completed index)
  (if (nil? scores) -1
      (if (wl.high-score-better? (car scores) score completed) index
          (wl.high-score-index (cdr scores) score completed (+ index 1)))))

(defn wl.high-score-insert (scores target entry index)
  (if (= index wl.MAXSCORES)
      nil
      (if (= index target)
          (cons entry (wl.high-score-take scores (- wl.MAXSCORES index 1)))
          (cons (car scores)
                (wl.high-score-insert (cdr scores) target entry (+ index 1))))))

(defn wl.high-score-take (scores count)
  (if (or (= count 0) (nil? scores)) nil
      (cons (car scores) (wl.high-score-take (cdr scores) (- count 1)))))

;;; DrawHighScores uses font-0 for names and its 129..138 fixed-width digit
;;; glyphs for the level/score columns. Keeping those extended glyph codes
;;; numeric avoids lossy host Unicode conversion.
(defn wl.fixed-number-width (font string)
  (wl.fixed-number-width-at font string 0 0))

(defn wl.fixed-number-width-at (font string at width)
  (if (= at (string.length string))
      width
      (let ((digit (wl.digit-value (wl.text-char string at))))
        (wl.fixed-number-width-at font string (+ at 1)
          (+ width (wl.font-width font (+ 129 digit)))))))

(defn wl.draw-fixed-number (frame font string x y colour)
  (wl.draw-fixed-number-at frame font string 0 x y colour))

(defn wl.draw-fixed-number-at (frame font string at x y colour)
  (if (= at (string.length string))
      x
      (let ((code (+ 129 (wl.digit-value (wl.text-char string at)))))
        (let ((width (wl.font-width font code)))
          (begin
            (wl.draw-font-character frame font code x y colour 0 0 width)
            (wl.draw-fixed-number-at frame font string (+ at 1) (+ x width) y colour))))))

(defn wl.draw-high-scores (frame)
  (let ((font (wl.cache-font app.vgahead app.vgagraph app.vgadict 0)))
    (begin
      (wl.bar frame 0 0 320 200 41)
      (wl.bar frame 0 10 320 24 0)
      (wl.bar frame 0 32 320 1 44)
      (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                       48 0 wl.HIGHSCORESPIC)
      (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                       32 68 wl.C-NAMEPIC)
      (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                       160 68 wl.C-LEVELPIC)
      (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                       224 68 wl.C-SCOREPIC)
      (wl.draw-high-score-rows frame font wl.scores 0)
      frame)))

(defn wl.draw-high-score-rows (frame font scores index)
  (if (or (= index wl.MAXSCORES) (nil? scores))
      frame
      (let ((entry (car scores)) (y (+ 76 (* 16 index))))
        (let ((completed (to-string (wl.play-at entry 2)))
              (score (to-string (wl.play-at entry 1))))
          (begin
            (wl.draw-prop-string frame font (car entry) 32 y 15)
            (let ((levelx (- 176 (wl.fixed-number-width font completed))))
              (let ((digitsx
                (wl.draw-prop-string frame font
                  (string.append "E" (string.append (to-string (+ (wl.play-at entry 3) 1)) "/L"))
                  (- levelx 6) y 15)))
                (wl.draw-fixed-number frame font completed digitsx y 15)))
            (wl.draw-fixed-number frame font score
              (- 264 (wl.fixed-number-width font score)) y 15)
            (wl.draw-high-score-rows frame font (cdr scores) (+ index 1)))))))

(defn wl.set-high-score-name (index name)
  (if (or (< index 0) (or (>= index wl.MAXSCORES) (> (string.length name) 57)))
      false
      (let ((entry (wl.play-at wl.scores index)))
        (begin
          (set! wl.scores
            (wl.replace-at wl.scores index
              (list name (wl.play-at entry 1) (wl.play-at entry 2) (wl.play-at entry 3))))
          true))))
