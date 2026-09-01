;;; WL_PLAY.C - demo input and PlayLoop exit state, ported to YALisp.
;;;
;;; The DOS source keeps demoptr/lastdemoptr as far pointers. YALisp keeps the
;;; immutable demo byte buffer plus integer offsets instead; the byte layout,
;;; signed controls, four-tic cadence, and final-command completion order are
;;; unchanged.

(define wl.EX-STILLPLAYING 0)
(define wl.EX-COMPLETED 1)
(define wl.EX-DIED 2)
(define wl.EX-WARPED 3)
(define wl.EX-RESETGAME 4)
(define wl.EX-LOADEDGAME 5)
(define wl.EX-VICTORIOUS 6)
(define wl.EX-ABORT 7)
(define wl.EX-DEMODONE 8)
(define wl.EX-SECRETLEVEL 9)

(define wl.DEMOTICS 4)
(define wl.DEMO-HEADER-BYTES 4)
(define wl.DEMO-COMMAND-BYTES 3)
(define wl.demo-buffer nil)
(define wl.demo-ptr 0)
(define wl.last-demo-ptr 0)
(define wl.demo-playback 0)
(define wl.playstate wl.EX-STILLPLAYING)

;;; WL_PLAY.C's non-SPEAR `songs[]`, indexed by episode*10+map.  The application
;;; calls start-level-music only after SetupGameLevel and after opening any
;;; route-local audio capture boundary; control-panel MENUSONG policy does not
;;; belong to this table or entry point.
(define wl.level-songs
  '(3 11 9 12 3 11 9 12 2 0
    8 18 17 4 8 18 4 17 2 1
    6 20 22 21 6 20 22 21 19 26
    3 11 9 12 3 11 9 12 2 0
    8 18 17 4 8 18 4 17 2 1
    6 20 22 21 6 20 22 21 19 15))

(defn wl.level-song (episode map)
  (if (or (< episode 0) (or (> episode 5) (or (< map 0) (> map 9))))
      -1
      (wl.play-at wl.level-songs (+ (* episode 10) map))))

(defn wl.start-level-music ()
  (let ((song (wl.level-song wl.episode wl.map)))
    (if (< song 0)
        false
        (begin
          ;; StartMusic stops the prior IMF sequence before caching/starting
          ;; the level song.  wl.start-music remains the generic sound-manager
          ;; bridge and records accepted music with source id 4.
          (wl.stop-music)
          (wl.start-music song)))))

(defn wl.signed-char (value)
  (if (> value 127) (- value 256) value))

(defn wl.demo-record? (source)
  (if (nil? source)
      false
      (let ((length (if (>= (bytes.length source) wl.DEMO-HEADER-BYTES)
                        (u16@ source 1)
                        0)))
        (and (>= length wl.DEMO-HEADER-BYTES)
             (and (<= length (bytes.length source))
                  (= (mod (- length wl.DEMO-HEADER-BYTES)
                          wl.DEMO-COMMAND-BYTES)
                     0))))))

;;; PlayDemo's source order is NewGame(1,0), map byte, gd_hard override,
;;; length/pointer setup, then PlayLoop. Level setup remains the caller's job,
;;; matching the original boundary between PlayDemo and SetupGameLevel.
(defn wl.play-demo (source)
  (if (wl.demo-record? source)
      (begin
        (wl.new-game 1 0)
        (set! wl.map (u8@ source 0))
        (set! wl.difficulty 3)
        (set! wl.demo-buffer source)
        (set! wl.demo-ptr wl.DEMO-HEADER-BYTES)
        (set! wl.last-demo-ptr (u16@ source 1))
        (set! wl.demo-playback 1)
        (set! wl.playstate wl.EX-STILLPLAYING)
        true)
      false))

;;; PollControls reads buttons, signed controlx, signed controly, then tests
;;; demoptr == lastdemoptr. The final command is therefore returned with
;;; EX-COMPLETED already set, so its frame still executes before PlayLoop exits.
(defn wl.poll-demo-controls ()
  (if (or (= wl.demo-playback 0) (>= wl.demo-ptr wl.last-demo-ptr))
      nil
      (let ((at wl.demo-ptr))
        (begin
          (set! wl.demo-ptr (+ wl.demo-ptr wl.DEMO-COMMAND-BYTES))
          (if (= wl.demo-ptr wl.last-demo-ptr)
              (set! wl.playstate wl.EX-COMPLETED)
              nil)
          (list wl.DEMOTICS
                (* (wl.signed-char (u8@ wl.demo-buffer (+ at 1))) wl.DEMOTICS)
                (* (wl.signed-char (u8@ wl.demo-buffer (+ at 2))) wl.DEMOTICS)
                (u8@ wl.demo-buffer at)
                wl.playstate)))))

(defn wl.stop-demo ()
  (begin
    (set! wl.demo-playback 0)
    (set! wl.demo-buffer nil)
    (set! wl.demo-ptr 0)
    (set! wl.last-demo-ptr 0)))

;;; -------------------------------------------------------------------------
;;; PollControls
;;;
;;; The browser passes one immutable association list per frame. Device
;;; sampling is the unavoidable host boundary; button precedence, movement
;;; thresholds, the published progressive-joystick controlx typo, held state,
;;; and tic scaling stay in Lisp in the same order as WL_PLAY.C.

(define wl.NUMBUTTONS 8)
(define wl.BT-ATTACK 0)
(define wl.BT-STRAFE 1)
(define wl.BT-RUN 2)
(define wl.BT-USE 3)
(define wl.BT-READYKNIFE 4)
(define wl.BT-READYPISTOL 5)
(define wl.BT-READYMACHINEGUN 6)
(define wl.BT-READYCHAINGUN 7)
(define wl.BASETURN 35)
(define wl.RUNTURN 70)
(define wl.JOYSCALE 2)
(define wl.controlx 0)
(define wl.controly 0)
(define wl.buttonstate (bytes.alloc wl.NUMBUTTONS))
(define wl.buttonheld (bytes.alloc wl.NUMBUTTONS))

(defn wl.play-at (xs n)
  (if (= n 0) (car xs) (wl.play-at (cdr xs) (- n 1))))

(defn wl.play-input (input name fallback)
  (let ((row (assoc name input)))
    (if row (wl.play-at row 1) fallback)))

(defn wl.copy-button-state (button)
  (if (= button wl.NUMBUTTONS)
      nil
      (begin
        (u8! wl.buttonheld button (u8@ wl.buttonstate button))
        (u8! wl.buttonstate button 0)
        (wl.copy-button-state (+ button 1)))))

(defn wl.set-button (button down)
  (if (and (>= button 0) (and (< button wl.NUMBUTTONS) (> down 0)))
      (u8! wl.buttonstate button 1)
      nil))

(defn wl.poll-controls (input)
  (if (= wl.demo-playback 1)
      (wl.poll-demo-controls)
      (wl.poll-live-controls input)))

(defn wl.poll-live-controls (input)
  (begin
    (set! wl.tics (wl.play-input input 'tics wl.tics))
    (if (< wl.tics 1) (set! wl.tics 1) nil)
    (set! wl.controlx 0)
    (set! wl.controly 0)
    (wl.copy-button-state 0)
    (wl.poll-keyboard-buttons input)
    (if (> (wl.play-input input 'mouse-enabled wl.mouse-enabled) 0)
        (wl.poll-mouse-buttons input) nil)
    (if (> (wl.play-input input 'joystick-enabled wl.joystick-enabled) 0)
        (wl.poll-joystick-buttons input) nil)
    (wl.poll-keyboard-move input)
    (if (> (wl.play-input input 'mouse-enabled wl.mouse-enabled) 0)
        (wl.poll-mouse-move input) nil)
    (if (> (wl.play-input input 'joystick-enabled wl.joystick-enabled) 0)
        (wl.poll-joystick-move input) nil)
    (list wl.tics wl.controlx wl.controly (wl.button-bits 0 0))))

(defn wl.poll-keyboard-buttons (input)
  (begin
    (wl.set-button wl.BT-ATTACK (wl.play-input input 'attack 0))
    (wl.set-button wl.BT-STRAFE (wl.play-input input 'strafe 0))
    (wl.set-button wl.BT-RUN (wl.play-input input 'run 0))
    (wl.set-button wl.BT-USE (wl.play-input input 'use 0))
    (wl.set-button wl.BT-READYKNIFE (wl.play-input input 'ready-knife 0))
    (wl.set-button wl.BT-READYPISTOL (wl.play-input input 'ready-pistol 0))
    (wl.set-button wl.BT-READYMACHINEGUN (wl.play-input input 'ready-machinegun 0))
    (wl.set-button wl.BT-READYCHAINGUN (wl.play-input input 'ready-chaingun 0))))

(defn wl.poll-mouse-buttons (input)
  (begin
    (wl.set-button wl.BT-ATTACK (bit.and (wl.play-input input 'mouse-buttons 0) 1))
    (wl.set-button wl.BT-STRAFE (bit.and (wl.play-input input 'mouse-buttons 0) 2))
    (wl.set-button wl.BT-USE (bit.and (wl.play-input input 'mouse-buttons 0) 4))))

(defn wl.poll-joystick-buttons (input)
  (begin
    (wl.set-button wl.BT-ATTACK (bit.and (wl.play-input input 'joystick-buttons 0) 1))
    (wl.set-button wl.BT-STRAFE (bit.and (wl.play-input input 'joystick-buttons 0) 2))
    (wl.set-button wl.BT-USE (bit.and (wl.play-input input 'joystick-buttons 0) 4))
    (wl.set-button wl.BT-RUN (bit.and (wl.play-input input 'joystick-buttons 0) 8))))

(defn wl.poll-keyboard-move (input)
  (let ((move (* (if (> (u8@ wl.buttonstate wl.BT-RUN) 0)
                       wl.RUNMOVE wl.BASEMOVE) wl.tics)))
    (begin
      (if (> (wl.play-input input 'forward 0) 0)
          (set! wl.controly (- wl.controly move)) nil)
      (if (> (wl.play-input input 'backward 0) 0)
          (set! wl.controly (+ wl.controly move)) nil)
      (if (> (wl.play-input input 'turn-left 0) 0)
          (set! wl.controlx (- wl.controlx move)) nil)
      (if (> (wl.play-input input 'turn-right 0) 0)
          (set! wl.controlx (+ wl.controlx move)) nil))))

(defn wl.poll-mouse-move (input)
  (let ((divisor (- 13 (wl.play-input input 'mouse-adjustment 5))))
    (begin
      (set! wl.controlx (+ wl.controlx (/ (* (wl.play-input input 'mouse-x 0) 10) divisor)))
      (set! wl.controly (+ wl.controly (/ (* (wl.play-input input 'mouse-y 0) 20) divisor))))))

(defn wl.poll-joystick-move (input)
  (let ((joyx (wl.play-input input 'joystick-x 0))
        (joyy (wl.play-input input 'joystick-y 0))
        (progressive (wl.play-input input 'joypad-enabled wl.joypad-enabled)))
    (if (> progressive 0)
        (begin
          (if (> joyx 64) (set! wl.controlx (+ wl.controlx (* (- joyx 64) wl.JOYSCALE wl.tics))) nil)
          (if (< joyx -64) (set! wl.controlx (- wl.controlx (* (- 0 (+ joyx 64)) wl.JOYSCALE wl.tics))) nil)
          ;; Published WL_PLAY.C assigns positive joy-y to controlx.
          (if (> joyy 64) (set! wl.controlx (+ wl.controlx (* (- joyy 64) wl.JOYSCALE wl.tics))) nil)
          (if (< joyy -64) (set! wl.controly (- wl.controly (* (- 0 (+ joyy 64)) wl.JOYSCALE wl.tics))) nil))
        (let ((move (* (if (> (u8@ wl.buttonstate wl.BT-RUN) 0)
                           wl.RUNMOVE wl.BASEMOVE) wl.tics)))
          (begin
            (if (> joyx 64) (set! wl.controlx (+ wl.controlx move)) nil)
            (if (< joyx -64) (set! wl.controlx (- wl.controlx move)) nil)
            (if (> joyy 64) (set! wl.controly (+ wl.controly move)) nil)
            (if (< joyy -64) (set! wl.controly (- wl.controly move)) nil))))))

(defn wl.button-bits (button bits)
  (if (= button wl.NUMBUTTONS)
      bits
      (wl.button-bits (+ button 1)
        (if (> (u8@ wl.buttonstate button) 0)
            (bit.or bits (bit.shl 1 button)) bits))))

;;; -------------------------------------------------------------------------
;;; Palette shifts and music sequencing

(define wl.NUMREDSHIFTS 6)
(define wl.NUMWHITESHIFTS 3)
(define wl.REDSTEPS 8)
(define wl.WHITESTEPS 20)
(define wl.WHITETICS 6)
(define wl.damagecount 0)
(define wl.bonuscount 0)
(define wl.palshifted 0)
(define wl.music-events nil)

(defn wl.clear-palette-shifts ()
  (begin (set! wl.damagecount 0) (set! wl.bonuscount 0) (set! wl.palshifted 0)))

(defn wl.start-bonus-flash ()
  (set! wl.bonuscount (* wl.NUMWHITESHIFTS wl.WHITETICS)))

(defn wl.start-damage-flash (damage)
  (set! wl.damagecount (+ wl.damagecount damage)))

(defn wl.update-palette-shifts ()
  (let ((white (/ wl.bonuscount wl.WHITETICS))
        (red (/ wl.damagecount wl.REDSTEPS)))
    (begin
      (if (> white (- wl.NUMWHITESHIFTS 1)) (set! white (- wl.NUMWHITESHIFTS 1)) nil)
      (if (> red (- wl.NUMREDSHIFTS 1)) (set! red (- wl.NUMREDSHIFTS 1)) nil)
      (if (> wl.bonuscount 0) (set! wl.bonuscount (- wl.bonuscount wl.tics)) nil)
      (if (< wl.bonuscount 0) (set! wl.bonuscount 0) nil)
      (if (> wl.damagecount 0) (set! wl.damagecount (- wl.damagecount wl.tics)) nil)
      (if (< wl.damagecount 0) (set! wl.damagecount 0) nil)
      (set! wl.palshifted (if (or (> white 0) (> red 0)) 1 0))
      (if (> white 0) (list 'white white)
          (if (> red 0) (list 'red red) '(normal 0))))))

(defn wl.finish-palette-shifts ()
  (begin (set! wl.palshifted 0) '(normal 0)))

(defn wl.start-music (song)
  (begin (set! wl.music-events (cons (list 'music-start song) wl.music-events)) song))

(defn wl.stop-music ()
  (begin (set! wl.music-events (cons '(music-stop) wl.music-events)) true))

(defn wl.music-event-log () (reverse wl.music-events))

;;; One non-blocking PlayLoop iteration. The host schedules the next 70 Hz
;;; frame and calls this again; the source update/render order remains here.
(defn wl.play-loop-step (input frame)
  (let ((controls (wl.poll-controls input)))
    (if (nil? controls)
        nil
        (begin
          (set! wl.madenoise 0)
          (wl.move-doors)
          (wl.move-pwalls)
          (wl.update-palette-shifts)
          (wl.three-d-refresh frame)
          controls))))
