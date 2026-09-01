;;; WL_MENU.C - control-panel state decisions, ported to YALisp.
;;;
;;; Drawing, sound-device calls, and host persistence are intentionally not in
;;; this module. It owns the source menu values and transitions; a generic host
;;; may later present them and implement the requested device contracts.

(define wl.APP-STARTUP 0)
(define wl.APP-INTRO 1)
(define wl.APP-MENU 2)
(define wl.APP-PLAYING 3)
(define wl.APP-INTERMISSION 4)
(define wl.APP-VICTORY 5)
(define wl.APP-SHUTDOWN 6)

(define wl.application-phase wl.APP-STARTUP)
(define wl.ingame 0)
(define wl.startgame 0)
(define wl.loadedgame 0)

(define wl.SDM-OFF 0)
(define wl.SDM-PC 1)
(define wl.SDM-ADLIB 2)
(define wl.SDS-OFF 0)
(define wl.SDS-SOUNDSOURCE 1)
(define wl.SDS-SOUNDBLASTER 2)
(define wl.SMM-OFF 0)
(define wl.SMM-ADLIB 1)

(define wl.sound-mode wl.SDM-ADLIB)
(define wl.digi-mode wl.SDS-SOUNDBLASTER)
(define wl.music-mode wl.SMM-ADLIB)
(define wl.mouse-enabled 0)
(define wl.joystick-enabled 0)
(define wl.joystick-port 0)
(define wl.joypad-enabled 0)
(define wl.joystick-progressive 0)
(define wl.view-size 15)
(define wl.pending-view-size 15)

(defn wl.application-startup ()
  (begin
    (set! wl.application-phase wl.APP-INTRO)
    (set! wl.ingame 0)
    (set! wl.startgame 0)
    (set! wl.loadedgame 0)
    wl.application-phase))

(defn wl.setup-control-panel ()
  (begin (set! wl.application-phase wl.APP-MENU) wl.application-phase))

(defn wl.cp-new-game (difficulty episode)
  (begin
    (wl.new-game difficulty episode)
    (set! wl.startgame 1)
    (set! wl.ingame 1)
    (set! wl.loadedgame 0)
    (set! wl.application-phase wl.APP-PLAYING)
    true))

(defn wl.cp-quit (confirmed)
  (if confirmed
      (begin
        (set! wl.ingame 0)
        (set! wl.startgame 0)
        (set! wl.application-phase wl.APP-SHUTDOWN)
        true)
      false))

(defn wl.cp-sound (mode)
  (if (and (>= mode wl.SDM-OFF) (<= mode wl.SDM-ADLIB))
      (begin (set! wl.sound-mode mode) true)
      false))

(defn wl.cp-digitized-sound (mode)
  (if (and (>= mode wl.SDS-OFF) (<= mode wl.SDS-SOUNDBLASTER))
      (begin (set! wl.digi-mode mode) true)
      false))

(defn wl.cp-music (mode)
  (if (and (>= mode wl.SMM-OFF) (<= mode wl.SMM-ADLIB))
      (begin (set! wl.music-mode mode) true)
      false))

(defn wl.cp-toggle-mouse ()
  (begin (set! wl.mouse-enabled (bit.xor wl.mouse-enabled 1)) wl.mouse-enabled))

(defn wl.cp-toggle-joystick (calibrated)
  (if (= wl.joystick-enabled 1)
      (begin (set! wl.joystick-enabled 0) 0)
      (if calibrated (begin (set! wl.joystick-enabled 1) 1) 0)))

(defn wl.cp-toggle-joystick-port ()
  (begin (set! wl.joystick-port (bit.xor wl.joystick-port 1)) wl.joystick-port))

(defn wl.cp-toggle-joypad ()
  (begin (set! wl.joypad-enabled (bit.xor wl.joypad-enabled 1)) wl.joypad-enabled))

(defn wl.change-view-begin ()
  (begin (set! wl.pending-view-size wl.view-size) wl.pending-view-size))

;;; CP_ChangeView clamps the source selection to 4..19 on every directional
;;; input. NewViewSize's renderer reconfiguration is a later port boundary;
;;; this function owns and commits the selected source view unit.
(defn wl.change-view-step (delta)
  (begin
    (set! wl.pending-view-size (+ wl.pending-view-size delta))
    (if (< wl.pending-view-size 4) (set! wl.pending-view-size 4) nil)
    (if (> wl.pending-view-size 19) (set! wl.pending-view-size 19) nil)
    wl.pending-view-size))

(defn wl.change-view-finish (accepted)
  (if accepted
      (begin (set! wl.view-size wl.pending-view-size) wl.view-size)
      (begin (set! wl.pending-view-size wl.view-size) wl.view-size)))

;;; -------------------------------------------------------------------------
;;; Source control-panel state machine
;;;
;;; DOS HandleMenu and the CP_* routines poll until a choice is made. Each
;;; browser call below consumes one deterministic input sample and returns the
;;; next screen. Rendering and choices remain Lisp-owned; filesystem dialogs,
;;; persistence, and audio execution are emitted as ordered action records.

(define wl.SC-F1 59)
(define wl.SC-F2 60)
(define wl.SC-F3 61)
(define wl.SC-F4 62)
(define wl.SC-F5 63)
(define wl.SC-F6 64)
(define wl.SC-F7 65)
(define wl.SC-F8 66)
(define wl.SC-F9 67)
(define wl.SC-F10 68)

(define wl.MENU-CLOSED 0)
(define wl.MENU-MAIN 1)
(define wl.MENU-EPISODE 2)
(define wl.MENU-DIFFICULTY 3)
(define wl.MENU-SOUND 4)
(define wl.MENU-CONTROL 5)
(define wl.MENU-LOAD 6)
(define wl.MENU-SAVE 7)
(define wl.MENU-SAVE-CONFIRM 8)
(define wl.MENU-SAVE-NAME 9)
(define wl.MENU-VIEW 10)
(define wl.MENU-MESSAGE 11)
(define wl.MENU-ENDGAME-CONFIRM 12)
(define wl.MENU-QUIT-CONFIRM 13)
(define wl.MENU-QUICKLOAD-CONFIRM 14)
(define wl.MENU-CUSTOM-CONTROLS 15)
(define wl.MENU-MOUSE-SENSITIVITY 16)
(define wl.MENU-ARTICLE 17)
(define wl.MENU-SCORES 18)
(define wl.CORNER-MUS 0)
(define wl.MENUSONG 14)
(define wl.C-OPTIONSPIC 10)
(define wl.C-CURSOR1PIC 11)
(define wl.C-CURSOR2PIC 12)
(define wl.C-MOUSELBACKPIC 18)
(define wl.C-BABYMODEPIC 19)
(define wl.C-EPISODE1PIC 30)
(define wl.R0-BKGDCOLOR 45)
(define wl.R0-DEACTIVE 43)
(define wl.R0-BORD2COLOR 35)
(define wl.R0-READHCOLOR 71)
(define wl.r0-color-hilite '(43 19 71 103))
(define wl.r0-color-normal '(43 23 74 107))

(define wl.menu-screen wl.MENU-CLOSED)
(define wl.menu-previous-screen wl.MENU-MAIN)
(define wl.menu-cursor 0)
(define wl.difficulty-cursor 2)
(define wl.menu-episode 0)
(define wl.menu-message "")
(define wl.menu-edit-name "")
(define wl.menu-edit-slot 0)
(define wl.menu-pickquick 0)
(define wl.menu-quick-slot-flow 0)
(define wl.menu-control-cursor 0)
(define wl.control-binding-pending 0)
(define wl.mouse-adjustment 5)
(define wl.menu-help-article "^P\nREAD THIS!\n^E\n")
(define wl.menu-actions nil)
(define wl.menu-save-names '("" "" "" "" "" "" "" "" "" ""))
(define wl.menu-save-available (bytes.alloc 10))
(define wl.buttonmouse (bytes.alloc 4))
(define wl.buttonjoy (bytes.alloc 4))
(define wl.buttonscan (bytes.alloc 8))
(define wl.dirscan (bytes.alloc 4))

(defn wl.init-control-bindings ()
  (begin
    (u8! wl.buttonmouse 0 wl.BT-ATTACK) (u8! wl.buttonmouse 1 wl.BT-STRAFE)
    (u8! wl.buttonmouse 2 wl.BT-USE) (u8! wl.buttonmouse 3 255)
    (u8! wl.buttonjoy 0 wl.BT-ATTACK) (u8! wl.buttonjoy 1 wl.BT-STRAFE)
    (u8! wl.buttonjoy 2 wl.BT-USE) (u8! wl.buttonjoy 3 wl.BT-RUN)
    ;; IN_Startup's source defaults.  R5 edits Forward (dirscan row zero),
    ;; then restores it before the configuration is committed.
    (u8! wl.dirscan 0 72) (u8! wl.dirscan 1 77)
    (u8! wl.dirscan 2 80) (u8! wl.dirscan 3 75)
    (u8! wl.buttonscan 0 29) (u8! wl.buttonscan 1 56)
    (u8! wl.buttonscan 2 54) (u8! wl.buttonscan 3 57)
    (u8! wl.buttonscan 4 2) (u8! wl.buttonscan 5 3)
    (u8! wl.buttonscan 6 4) (u8! wl.buttonscan 7 5)
    true))

(define wl.main-menu
  '((1 "New Game" new-game) (1 "Sound" sound) (1 "Control" control)
    (1 "Load Game" load) (0 "Save Game" save) (1 "Change View" view)
    (2 "Read This!" read-this) (1 "View Scores" scores)
    (1 "Back to Demo" back) (1 "Quit" quit)))

;;; VERSION.H enables GOODTIMES in the pinned WL6 build. Keep the retail
;;; Read This row above for the shared control-panel state machine, while R0's
;;; captured product menu uses the released nine-row physical profile.
(define wl.r0-main-menu
  '((1 "New Game" new-game) (1 "Sound" sound) (1 "Control" control)
    (1 "Load Game" load) (0 "Save Game" save) (1 "Change View" view)
    (1 "View Scores" scores) (1 "Back to Demo" back) (1 "Quit" quit)))

(define wl.episode-menu
  '((1 "Episode 1\nEscape from Wolfenstein" episode) (0 "" none)
    (1 "Episode 2\nOperation: Eisenfaust" episode) (0 "" none)
    (1 "Episode 3\nDie, Fuhrer, Die!" episode) (0 "" none)
    (1 "Episode 4\nA Dark Secret" episode) (0 "" none)
    (1 "Episode 5\nTrail of the Madman" episode) (0 "" none)
    (1 "Episode 6\nConfrontation" episode)))
(define wl.episode-select '(1 1 1 1 1 1))

(define wl.difficulty-menu
  '((1 "Can I play, Daddy?" difficulty) (1 "Don't hurt me." difficulty)
    (1 "Bring 'em on!" difficulty) (1 "I am Death incarnate!" difficulty)))

(defn wl.menu-action (action)
  (begin (set! wl.menu-actions (cons action wl.menu-actions)) action))

(defn wl.menu-action-log () (reverse wl.menu-actions))

(defn wl.read-any-control (input)
  (let ((keyboard (wl.read-keyboard-direction input))
        (mousex (wl.play-input input 'mouse-x 0))
        (mousey (wl.play-input input 'mouse-y 0))
        (joyx (wl.play-input input 'joystick-x 0))
        (joyy (wl.play-input input 'joystick-y 0)))
    (let ((mouseactive (and (> wl.mouse-enabled 0)
                            (or (> mousex 60) (or (< mousex -60)
                              (or (> mousey 60) (< mousey -60)))))))
      (list
        (if mouseactive
            (wl.axis-direction mousex mousey)
            (if (and (> wl.joystick-enabled 0)
                     (not (eq? (wl.axis-direction joyx joyy) 'none)))
                (wl.axis-direction joyx joyy) keyboard))
        (if (> (bit.and (wl.play-input input 'mouse-buttons 0) 1) 0) true
            (> (wl.play-input input 'confirm 0) 0))
        (if (> (bit.and (wl.play-input input 'mouse-buttons 0) 2) 0) true
            (> (wl.play-input input 'cancel 0) 0))
        (> (bit.and (wl.play-input input 'mouse-buttons 0) 4) 0)
        (wl.play-input input 'ascii "")))))

(defn wl.read-keyboard-direction (input)
  (cond ((> (wl.play-input input 'up 0) 0) 'north)
        ((> (wl.play-input input 'down 0) 0) 'south)
        ((> (wl.play-input input 'left 0) 0) 'west)
        ((> (wl.play-input input 'right 0) 0) 'east)
        (true 'none)))

(defn wl.axis-direction (x y)
  ;; ReadAnyControl tests vertical, then horizontal; horizontal wins.
  (let ((vertical (if (> y 60) 'south (if (< y -60) 'north 'none))))
    (if (> x 60) 'east (if (< x -60) 'west vertical))))

(defn wl.menu-item-active? (items index)
  (> (car (wl.play-at items index)) 0))

(defn wl.menu-next-active (items current delta)
  (wl.menu-next-active-from items current delta (length items)))

(defn wl.menu-next-active-from (items current delta remaining)
  (if (= remaining 0)
      current
      (let ((next (mod (+ (+ current delta) (length items)) (length items))))
        (if (wl.menu-item-active? items next)
            next
            (wl.menu-next-active-from items next delta (- remaining 1))))))

(defn wl.upper-alpha (character)
  (let ((code (wl.ascii-code character)))
    (if (and (>= code 97) (<= code 122)) (ca.character (- code 32)) character)))

(defn wl.menu-first-letter (items current character)
  (wl.menu-first-letter-from items current (wl.upper-alpha character) (length items)))

(defn wl.menu-first-letter-from (items current character remaining)
  (if (= remaining 0)
      current
      (let ((next (mod (+ current 1) (length items))))
        (let ((item (wl.play-at items next)))
          (if (and (> (car item) 0)
                   (string=? character
                     (wl.upper-alpha (string.substring (wl.play-at item 1) 0 1))))
              next
              (wl.menu-first-letter-from items next character (- remaining 1)))))))

;;; Return (cursor selected), where selected is -2 while browsing, -1 on
;;; cancel, or the accepted active row. The callback dispatch happens only
;;; after this source-equivalent HandleMenu decision.
(defn wl.handle-menu (items current input)
  (let ((control (wl.read-any-control input)))
    (cond ((car (cdr (cdr control))) (list current -1))
          ((car (cdr control)) (list current current))
          ((eq? (car control) 'north)
           (list (wl.menu-next-active items current -1) -2))
          ((eq? (car control) 'south)
           (list (wl.menu-next-active items current 1) -2))
          ((> (string.length (wl.play-at control 4)) 0)
           (list (wl.menu-first-letter items current (wl.play-at control 4)) -2))
          (true (list current -2)))))

(defn wl.setup-control-panel-machine ()
  (begin
    (wl.setup-control-panel)
    (wl.init-control-bindings)
    (set! wl.menu-screen wl.MENU-MAIN)
    (set! wl.menu-cursor 0)
    (set! wl.menu-quick-slot-flow 0)
    (set! wl.menu-actions nil)
    (wl.start-music wl.MENUSONG)
    wl.menu-screen))

(defn wl.cleanup-control-panel ()
  (begin (wl.menu-action '(cleanup-control-panel)) true))

(defn wl.us-control-panel (scancode)
  (if (and (> wl.ingame 0) (wl.cp-check-quick scancode))
      wl.menu-screen
      (begin
        (wl.setup-control-panel-machine)
        (cond ((= scancode wl.SC-F1) (wl.cp-read-this))
              ((= scancode wl.SC-F2) (set! wl.menu-screen wl.MENU-SAVE))
              ((= scancode wl.SC-F3) (set! wl.menu-screen wl.MENU-LOAD))
              ((= scancode wl.SC-F4) (set! wl.menu-screen wl.MENU-SOUND))
              ((= scancode wl.SC-F5) (begin (wl.change-view-begin)
                                             (set! wl.menu-screen wl.MENU-VIEW)))
              ((= scancode wl.SC-F6) (set! wl.menu-screen wl.MENU-CONTROL))
              (true nil))
        wl.menu-screen)))

(defn wl.cp-check-quick (scancode)
  (cond ((= scancode wl.SC-F7) (begin (set! wl.menu-screen wl.MENU-ENDGAME-CONFIRM) true))
        ((= scancode wl.SC-F8)
         (if (and (> wl.menu-pickquick 0) (> (u8@ wl.menu-save-available wl.menu-edit-slot) 0))
             (begin (wl.menu-action (list 'save wl.menu-edit-slot
                                          (wl.play-at wl.menu-save-names wl.menu-edit-slot) true)) true)
             (begin (wl.begin-quick-slot-flow wl.MENU-SAVE) true)))
        ((= scancode wl.SC-F9)
         (if (and (> wl.menu-pickquick 0) (> (u8@ wl.menu-save-available wl.menu-edit-slot) 0))
             (begin (set! wl.menu-screen wl.MENU-QUICKLOAD-CONFIRM) true)
             (begin (wl.begin-quick-slot-flow wl.MENU-LOAD) true)))
        ((= scancode wl.SC-F10) (begin (set! wl.menu-screen wl.MENU-QUIT-CONFIRM) true))
        (true false)))

;;; CP_CheckQuick handles F8/F9 even when the remembered slot cannot take the
;;; one-step path. The released source enters CP_SaveGame(0)/CP_LoadGame(0)
;;; and returns to play when that full slot picker finishes or is cancelled.
;;; Reuse the normal resumable save/load handlers while retaining that return
;;; destination and the source's remembered LSItems.curpos equivalent.
(defn wl.begin-quick-slot-flow (screen)
  (let ((slot wl.menu-edit-slot))
    (begin
      (wl.setup-control-panel-machine)
      (set! wl.menu-cursor slot)
      ;; CP_CheckQuick assigns the full CP_SaveGame/CP_LoadGame result back to
      ;; pickquick. Until a slot action succeeds that result is zero.
      (set! wl.menu-pickquick 0)
      (set! wl.menu-quick-slot-flow 1)
      (set! wl.menu-screen screen)
      wl.menu-screen)))

(defn wl.finish-slot-flow (normal-screen)
  (if (> wl.menu-quick-slot-flow 0)
      (begin
        (set! wl.menu-quick-slot-flow 0)
        (set! wl.menu-screen wl.MENU-CLOSED))
      (set! wl.menu-screen normal-screen)))

(defn wl.control-panel-step (input)
  (cond ((= wl.menu-screen wl.MENU-MAIN) (wl.main-menu-step input))
        ((= wl.menu-screen wl.MENU-EPISODE) (wl.episode-menu-step input))
        ((= wl.menu-screen wl.MENU-DIFFICULTY) (wl.difficulty-menu-step input))
        ((= wl.menu-screen wl.MENU-SOUND) (wl.sound-menu-step input))
        ((= wl.menu-screen wl.MENU-CONTROL) (wl.control-menu-step input))
        ((= wl.menu-screen wl.MENU-CUSTOM-CONTROLS) (wl.custom-controls-step input))
        ((= wl.menu-screen wl.MENU-MOUSE-SENSITIVITY) (wl.mouse-sensitivity-step input))
        ((= wl.menu-screen wl.MENU-LOAD) (wl.load-menu-step input))
        ((= wl.menu-screen wl.MENU-SAVE) (wl.save-menu-step input))
        ((= wl.menu-screen wl.MENU-SAVE-CONFIRM) (wl.confirm-save-step input))
        ((= wl.menu-screen wl.MENU-SAVE-NAME) (wl.save-name-step input))
        ((= wl.menu-screen wl.MENU-VIEW) (wl.view-menu-step input))
        ((= wl.menu-screen wl.MENU-MESSAGE) (wl.message-step input))
        ((= wl.menu-screen wl.MENU-ENDGAME-CONFIRM) (wl.endgame-step input))
        ((= wl.menu-screen wl.MENU-QUIT-CONFIRM) (wl.quit-step input))
        ((= wl.menu-screen wl.MENU-QUICKLOAD-CONFIRM) (wl.quickload-step input))
        ((= wl.menu-screen wl.MENU-ARTICLE) (wl.menu-article-step input))
        ((= wl.menu-screen wl.MENU-SCORES) (wl.menu-scores-step input))
        (true wl.menu-screen)))

(defn wl.main-menu-step (input)
  (let ((handled (wl.handle-menu wl.main-menu wl.menu-cursor input)))
    (begin
      (set! wl.menu-cursor (car handled))
      (if (>= (car (cdr handled)) 0)
          (wl.main-menu-select (wl.play-at (wl.play-at wl.main-menu wl.menu-cursor) 2)) nil)
      (if (= (car (cdr handled)) -1) (set! wl.menu-screen wl.MENU-CLOSED) nil)
      wl.menu-screen)))

(defn wl.main-menu-select (action)
  (cond ((eq? action 'new-game) (begin (set! wl.menu-screen wl.MENU-EPISODE)
                                       (set! wl.menu-cursor 0)))
        ((eq? action 'sound) (begin (set! wl.menu-screen wl.MENU-SOUND) (set! wl.menu-cursor 0)))
        ((eq? action 'control) (set! wl.menu-screen wl.MENU-CONTROL))
        ((eq? action 'load) (begin (set! wl.menu-screen wl.MENU-LOAD) (set! wl.menu-cursor 0)))
        ((eq? action 'save) (begin (set! wl.menu-screen wl.MENU-SAVE) (set! wl.menu-cursor 0)))
        ((eq? action 'view) (begin (wl.change-view-begin) (set! wl.menu-screen wl.MENU-VIEW)))
        ((eq? action 'read-this) (wl.cp-read-this))
        ((eq? action 'scores) (wl.cp-view-scores))
        ((eq? action 'back) (set! wl.menu-screen wl.MENU-CLOSED))
        ((eq? action 'quit) (set! wl.menu-screen wl.MENU-QUIT-CONFIRM))
        (true nil)))

(defn wl.episode-menu-step (input)
  (let ((handled (wl.handle-menu wl.episode-menu wl.menu-cursor input)))
    (begin
      (set! wl.menu-cursor (car handled))
      (if (= (car (cdr handled)) -1) (set! wl.menu-screen wl.MENU-MAIN) nil)
      (if (>= (car (cdr handled)) 0)
          (if (> (wl.play-at wl.episode-select (/ wl.menu-cursor 2)) 0)
              (begin (set! wl.menu-episode (/ wl.menu-cursor 2))
                     (set! wl.menu-screen wl.MENU-DIFFICULTY))
              (begin (set! wl.menu-previous-screen wl.MENU-EPISODE)
                     (set! wl.menu-message "PLEASE SELECT READ THIS!")
                     (set! wl.menu-screen wl.MENU-MESSAGE))) nil)
      wl.menu-screen)))

(defn wl.difficulty-menu-step (input)
  (let ((handled (wl.handle-menu wl.difficulty-menu wl.difficulty-cursor input)))
    (begin
      (set! wl.difficulty-cursor (car handled))
      (if (= (car (cdr handled)) -1) (set! wl.menu-screen wl.MENU-EPISODE) nil)
      (if (>= (car (cdr handled)) 0)
          (begin
            (wl.cp-new-game wl.difficulty-cursor wl.menu-episode)
            (wl.menu-action (list 'new-game wl.difficulty-cursor wl.menu-episode))
            (set! wl.menu-screen wl.MENU-CLOSED)) nil)
      wl.menu-screen)))

(defn wl.sound-menu-step (input)
  (begin
    (if (> (wl.play-input input 'up 0) 0)
        (set! wl.menu-cursor (mod (+ wl.menu-cursor 6) 7)) nil)
    (if (> (wl.play-input input 'down 0) 0)
        (set! wl.menu-cursor (mod (+ wl.menu-cursor 1) 7)) nil)
    (if (> (wl.play-input input 'confirm 0) 0)
        (cond ((= wl.menu-cursor 0) (wl.cp-sound wl.SDM-OFF))
              ((= wl.menu-cursor 1) (wl.cp-sound wl.SDM-PC))
              ((= wl.menu-cursor 2) (wl.cp-sound wl.SDM-ADLIB))
              ((= wl.menu-cursor 3) (wl.cp-digitized-sound wl.SDS-OFF))
              ((= wl.menu-cursor 4) (wl.cp-digitized-sound wl.SDS-SOUNDSOURCE))
              ((= wl.menu-cursor 5) (wl.cp-digitized-sound wl.SDS-SOUNDBLASTER))
              ((= wl.menu-cursor 6) (wl.cp-music wl.SMM-OFF))
              (true nil)) nil)
    (if (> (wl.play-input input 'cancel 0) 0) (set! wl.menu-screen wl.MENU-MAIN) nil)
    (if (> (wl.play-input input 'sound-next 0) 0)
        (wl.cp-sound (mod (+ wl.sound-mode 1) 3)) nil)
    (if (> (wl.play-input input 'digi-next 0) 0)
        (wl.cp-digitized-sound (mod (+ wl.digi-mode 1) 3)) nil)
    (if (> (wl.play-input input 'music-next 0) 0)
        (wl.cp-music (mod (+ wl.music-mode 1) 2)) nil)
    wl.menu-screen))

(defn wl.cp-control ()
  (begin (set! wl.menu-control-cursor 0) (set! wl.menu-screen wl.MENU-CONTROL)))

(defn wl.custom-controls ()
  (begin (set! wl.menu-control-cursor 0) (set! wl.control-binding-pending 0)
         (set! wl.menu-screen wl.MENU-CUSTOM-CONTROLS)))

(defn wl.mouse-sensitivity ()
  (begin (set! wl.menu-screen wl.MENU-MOUSE-SENSITIVITY) wl.mouse-adjustment))

(defn wl.control-menu-step (input)
  (begin
    (if (> (wl.play-input input 'up 0) 0)
        (set! wl.menu-control-cursor (mod (+ wl.menu-control-cursor 5) 6)) nil)
    (if (> (wl.play-input input 'down 0) 0)
        (set! wl.menu-control-cursor (mod (+ wl.menu-control-cursor 1) 6)) nil)
    (if (> (wl.play-input input 'cancel 0) 0) (set! wl.menu-screen wl.MENU-MAIN) nil)
    (if (> (wl.play-input input 'confirm 0) 0)
        (cond ((= wl.menu-control-cursor 0) (wl.cp-toggle-mouse))
              ((= wl.menu-control-cursor 1) (wl.cp-toggle-joystick true))
              ((= wl.menu-control-cursor 2) (wl.cp-toggle-joystick-port))
              ((= wl.menu-control-cursor 3) (wl.cp-toggle-joypad))
              ((= wl.menu-control-cursor 4) (wl.mouse-sensitivity))
              ((= wl.menu-control-cursor 5) (wl.custom-controls))
              (true nil)) nil)
    wl.menu-screen))

(defn wl.mouse-sensitivity-step (input)
  (begin
    (if (> (wl.play-input input 'left 0) 0)
        (set! wl.mouse-adjustment (if (> wl.mouse-adjustment 0) (- wl.mouse-adjustment 1) 0)) nil)
    (if (> (wl.play-input input 'right 0) 0)
        (set! wl.mouse-adjustment (if (< wl.mouse-adjustment 9) (+ wl.mouse-adjustment 1) 9)) nil)
    (if (or (> (wl.play-input input 'confirm 0) 0)
            (> (wl.play-input input 'cancel 0) 0))
        (begin (wl.menu-action (list 'mouse-adjustment wl.mouse-adjustment))
               (set! wl.menu-screen wl.MENU-CONTROL)) nil)
    wl.menu-screen))

(defn wl.custom-controls-step (input)
  (begin
    (if (> (wl.play-input input 'up 0) 0)
        (set! wl.menu-control-cursor (mod (+ wl.menu-control-cursor 7) 8)) nil)
    (if (> (wl.play-input input 'down 0) 0)
        (set! wl.menu-control-cursor (mod (+ wl.menu-control-cursor 1) 8)) nil)
    (if (> (wl.play-input input 'cancel 0) 0)
        (begin (set! wl.control-binding-pending 0)
               (set! wl.menu-screen wl.MENU-CONTROL)) nil)
    (if (> (wl.play-input input 'confirm 0) 0)
        (set! wl.control-binding-pending 1) nil)
    (let ((binding (let ((scan (wl.play-input input 'scan -1)))
                     (if (>= scan 0) scan (wl.play-input input 'binding -1)))))
      (if (and (= wl.control-binding-pending 1) (>= binding 0))
          (begin (wl.enter-ctrl-data wl.menu-control-cursor binding)
                 (set! wl.control-binding-pending 0)) nil))
    wl.menu-screen))

;;; EnterCtrlData removes duplicate physical bindings before assigning the new
;;; one, matching the source's FixupCustom pass.
(defn wl.enter-ctrl-data (logical physical)
  (if (or (< logical 0) (> logical 7))
      false
      (begin
        (wl.clear-duplicate-binding physical 0)
        (if (< logical 4)
            (u8! wl.buttonscan logical physical)
            (u8! wl.dirscan (- logical 4) physical))
        (wl.menu-action (list 'binding logical physical))
        true)))

(defn wl.clear-duplicate-binding (physical index)
  (if (= index 8)
      nil
      (begin
        (if (< index 4)
            (if (= (u8@ wl.buttonscan index) physical) (u8! wl.buttonscan index 255) nil)
            (if (= (u8@ wl.dirscan (- index 4)) physical) (u8! wl.dirscan (- index 4) 255) nil))
        (wl.clear-duplicate-binding physical (+ index 1)))))

(defn wl.load-menu-step (input)
  (begin
    (wl.slot-cursor-step input)
    (if (> (wl.play-input input 'cancel 0) 0) (wl.finish-slot-flow wl.MENU-MAIN) nil)
    (if (and (> (wl.play-input input 'confirm 0) 0)
             (> (u8@ wl.menu-save-available wl.menu-cursor) 0))
        (begin
          (set! wl.menu-edit-slot wl.menu-cursor)
          (set! wl.loadedgame 1)
          (if (> wl.menu-quick-slot-flow 0) (set! wl.menu-pickquick 1) nil)
          (wl.menu-action (list 'load wl.menu-edit-slot false))
          (wl.finish-slot-flow wl.MENU-CLOSED)) nil)
    wl.menu-screen))

(defn wl.save-menu-step (input)
  (begin
    (wl.slot-cursor-step input)
    (if (> (wl.play-input input 'cancel 0) 0) (wl.finish-slot-flow wl.MENU-MAIN) nil)
    (if (> (wl.play-input input 'confirm 0) 0)
        (begin
          (set! wl.menu-edit-slot wl.menu-cursor)
          (set! wl.menu-edit-name (wl.play-at wl.menu-save-names wl.menu-cursor))
          (set! wl.menu-screen
            (if (> (u8@ wl.menu-save-available wl.menu-cursor) 0)
                wl.MENU-SAVE-CONFIRM wl.MENU-SAVE-NAME))) nil)
    wl.menu-screen))

(defn wl.slot-cursor-step (input)
  (cond ((> (wl.play-input input 'up 0) 0)
         (set! wl.menu-cursor (mod (+ wl.menu-cursor 9) 10)))
        ((> (wl.play-input input 'down 0) 0)
         (set! wl.menu-cursor (mod (+ wl.menu-cursor 1) 10)))
        (true wl.menu-cursor)))

(defn wl.confirm-save-step (input)
  (cond ((or (> (wl.play-input input 'yes 0) 0) (> (wl.play-input input 'confirm 0) 0))
         (set! wl.menu-screen wl.MENU-SAVE-NAME))
        ((or (> (wl.play-input input 'no 0) 0) (> (wl.play-input input 'cancel 0) 0))
         (set! wl.menu-screen wl.MENU-SAVE))
        (true wl.menu-screen)))

(defn wl.save-name-step (input)
  (let ((ascii (wl.play-input input 'ascii "")))
    (begin
      (if (> (wl.play-input input 'backspace 0) 0)
          (set! wl.menu-edit-name
            (string.slice wl.menu-edit-name 0 (- (string.length wl.menu-edit-name) 1))) nil)
      (if (and (> (string.length ascii) 0) (< (string.length wl.menu-edit-name) 31))
          (set! wl.menu-edit-name (string.append wl.menu-edit-name ascii)) nil)
      (if (> (wl.play-input input 'cancel 0) 0) (set! wl.menu-screen wl.MENU-SAVE) nil)
      (if (> (wl.play-input input 'confirm 0) 0)
          (begin
            (set! wl.menu-save-names
              (wl.replace-at wl.menu-save-names wl.menu-edit-slot wl.menu-edit-name))
            (u8! wl.menu-save-available wl.menu-edit-slot 1)
            (set! wl.menu-pickquick 1)
            (wl.menu-action (list 'save wl.menu-edit-slot wl.menu-edit-name false))
            (set! wl.menu-quick-slot-flow 0)
            (set! wl.menu-screen wl.MENU-CLOSED)) nil)
      wl.menu-screen)))

(defn wl.view-menu-step (input)
  (begin
    (if (or (> (wl.play-input input 'up 0) 0) (> (wl.play-input input 'right 0) 0))
        (wl.change-view-step 1) nil)
    (if (or (> (wl.play-input input 'down 0) 0) (> (wl.play-input input 'left 0) 0))
        (wl.change-view-step -1) nil)
    (if (> (wl.play-input input 'cancel 0) 0)
        (begin (wl.change-view-finish false) (set! wl.menu-screen wl.MENU-MAIN)) nil)
    (if (> (wl.play-input input 'confirm 0) 0)
        (begin
          (wl.change-view-finish true)
          (wl.menu-action (list 'set-view-size wl.view-size))
          (set! wl.menu-screen wl.MENU-MAIN)) nil)
    wl.menu-screen))

(defn wl.message-step (input)
  (if (or (> (wl.play-input input 'confirm 0) 0)
          (> (wl.play-input input 'cancel 0) 0))
      (begin (set! wl.menu-screen wl.menu-previous-screen) wl.menu-screen)
      wl.menu-screen))

;;; CP_ReadThis / CP_ViewScores are real resumable screens. The help article
;;; defaults to a valid one-page document for asset-free sessions; a mounted
;;; host supplies the decoded T_HELPART text through configure-help-article.
(defn wl.configure-help-article (article)
  (begin
    (set! wl.menu-help-article article)
    true))

(defn wl.cp-read-this ()
  (begin
    (set! wl.menu-previous-screen wl.MENU-MAIN)
    (wl.start-music wl.CORNER-MUS)
    (wl.menu-action '(read-this begin))
    (wl.begin-article wl.menu-help-article)
    (set! wl.menu-screen wl.MENU-ARTICLE)
    wl.menu-screen))

(defn wl.cp-view-scores ()
  (begin
    (set! wl.menu-previous-screen wl.MENU-MAIN)
    (wl.start-music wl.ROSTER-MUS)
    (wl.menu-action '(view-scores begin))
    (set! wl.menu-screen wl.MENU-SCORES)
    wl.menu-screen))

(defn wl.article-input-direction (input)
  (cond ((> (wl.play-input input 'cancel 0) 0) 'escape)
        ((or (> (wl.play-input input 'up 0) 0)
             (or (> (wl.play-input input 'left 0) 0)
                 (> (wl.play-input input 'page-up 0) 0))) 'left)
        ((or (> (wl.play-input input 'confirm 0) 0)
             (or (> (wl.play-input input 'down 0) 0)
                 (or (> (wl.play-input input 'right 0) 0)
                     (> (wl.play-input input 'page-down 0) 0)))) 'right)
        (true 'none)))

(defn wl.menu-article-step (input)
  (let ((state (wl.article-execution-step
                 (wl.article-input-direction input)
                 (wl.play-input input 'tics 0))))
    (begin
      (if (eq? (car state) 'article-done)
          (begin
            (wl.start-music wl.MENUSONG)
            (wl.menu-action '(read-this end))
            (set! wl.menu-screen wl.MENU-MAIN)) nil)
      wl.menu-screen)))

(defn wl.menu-scores-step (input)
  (if (or (> (wl.play-input input 'ack 0) 0)
          (or (> (wl.play-input input 'confirm 0) 0)
              (> (wl.play-input input 'cancel 0) 0)))
      (begin
        (wl.start-music wl.MENUSONG)
        (wl.menu-action '(view-scores end))
        (set! wl.menu-screen wl.MENU-MAIN)
        wl.menu-screen)
      wl.menu-screen))

(defn wl.endgame-step (input)
  (if (> (wl.play-input input 'yes 0) 0)
      (begin
        (set! wl.lives 0) (set! wl.playstate wl.EX-DIED)
        (set! wl.menu-pickquick 0) (wl.menu-action '(end-game))
        (set! wl.menu-screen wl.MENU-CLOSED))
      (if (> (wl.play-input input 'no 0) 0) (set! wl.menu-screen wl.MENU-CLOSED) nil)))

(defn wl.quit-step (input)
  (if (> (wl.play-input input 'yes 0) 0)
      (begin (wl.cp-quit true) (wl.menu-action '(quit))
             (set! wl.menu-screen wl.MENU-CLOSED))
      (if (> (wl.play-input input 'no 0) 0) (set! wl.menu-screen wl.MENU-CLOSED) nil)))

(defn wl.quickload-step (input)
  (if (> (wl.play-input input 'yes 0) 0)
      (begin
        (set! wl.loadedgame 1)
        (wl.menu-action (list 'load wl.menu-edit-slot true))
        (set! wl.menu-screen wl.MENU-CLOSED))
      (if (> (wl.play-input input 'no 0) 0) (set! wl.menu-screen wl.MENU-CLOSED) nil)))

;;; -------------------------------------------------------------------------
;;; R5 source menu boundary
;;;
;;; The browser/CLI producer supplies one authored input at a time, but the
;;; route, source ReadAnyControl ordinals, option decisions, and sound calls
;;; remain Lisp-owned.  This is intentionally only a producer seam: CONFIG.WL6
;;; persistence and whole-mixer capture belong to later host lanes.

(define wl.R5-SHOOTSND 32)
(define wl.R5-ESCPRESSEDSND 39)
(define wl.R5-MOVEGUN2SND 4)
(define wl.R5-DRAWSND 5)
(define wl.r5-route-index 0)
(define wl.r5-terminal 0)
(define wl.r5-binding-pending 0)
(define wl.r5-attempts nil)
(define wl.r5-attempt-tail nil)
(define wl.r5-frames nil)

(define wl.r5-source-ordinals
  '(0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20
    22 23 28 29 30 31 33 34 35 36 37 38 39 40 41 42 43 44))

;;; Keep the complete authored sample beside the source ordinal. Capture names
;;; are part of the contract even though wl.r5-frame performs the actual draw;
;;; this prevents a host from advancing the route with an empty or mislabeled
;;; sample after taking an unrelated screenshot.
(define wl.r5-action-inputs
  '(((panel main) (down 1) (capture main-initial))
    ((panel main) (confirm 1))
    ((panel sound) (capture sound-initial))
    ((panel sound) (confirm 1))
    ((panel sound) (down 1))
    ((panel sound) (confirm 1))
    ((panel sound) (down 1))
    ((panel sound) (confirm 1))
    ((panel sound) (down 1))
    ((panel sound) (confirm 1))
    ((panel sound) (down 1))
    ((panel sound) (confirm 1))
    ((panel sound) (down 1))
    ((panel sound) (confirm 1))
    ((panel sound) (down 1))
    ((panel sound) (confirm 1))
    ((panel sound) (cancel 1))
    ((panel main) (down 1))
    ((panel main) (confirm 1))
    ((panel controls) (capture control-panel-initial))
    ((panel controls) (confirm 1))
    ((panel custom-controls) (capture custom-controls-initial))
    ((panel custom-controls) (confirm 1))
    ((panel custom-controls) (scan 17))
    ((panel custom-controls) (confirm 1))
    ((panel custom-controls) (scan 72))
    ((panel custom-controls) (cancel 1))
    ((panel controls) (cancel 1))
    ((panel main) (down 1))
    ((panel main) (down 1))
    ((panel main) (confirm 1))
    ((panel view) (up 1) (capture view-initial))
    ((panel view) (down 1))
    ((panel view) (confirm 1))
    ((panel main) (capture main-final))
    ((panel main) (down 1))
    ((panel main) (down 1))
    ((panel main) (down 1))
    ((panel main) (confirm 1))))

;;; TRACE.ATT's exact 48 SD_PlaySound attempts.  Music starts are separate
;;; accepted manager records at source tick zero.
(define wl.r5-sound-attempt-table
  '((1 5) (1 4) (2 32) (5 5) (5 4) (6 32) (7 5) (7 4)
    (8 32) (9 4) (11 5) (11 4) (12 32) (13 5) (13 4) (14 32)
    (15 4) (16 32) (17 39) (18 5) (18 4) (19 32) (21 4) (22 32)
    (24 4) (25 32) (26 5) (27 5) (29 32) (31 32) (32 39) (33 39)
    (34 39) (35 5) (35 4) (36 4) (37 32) (38 0) (39 0) (40 32)
    (42 5) (42 4) (43 5) (43 4) (44 5) (44 4) (45 32) (45 32)))

(defn wl.r5-bytes-list (source count)
  (wl.r5-bytes-list-at source count 0 nil))

(defn wl.r5-bytes-list-at (source count index values)
  (if (= index count) (reverse values)
      (wl.r5-bytes-list-at source count (+ index 1)
        (cons (let ((value (u8@ source index))) (if (= value 255) -1 value)) values))))

(defn wl.r5-snapshot ()
  (list (list 'sound-mode wl.sound-mode)
        (list 'music-mode wl.music-mode)
        ;; Menu rows are Off/Sound Source/Sound Blaster (0/1/2), while the
        ;; complete ID_SD/CONFIG enum inserts PC at one (0/2/3 here).
        (list 'digi-mode (sd.menu-digi-mode wl.digi-mode))
        (list 'view-size wl.view-size)
        (list 'dirscan (wl.r5-bytes-list wl.dirscan 4))
        (list 'buttonscan (wl.r5-bytes-list wl.buttonscan 8))
        (list 'mouse-enabled (= wl.mouse-enabled 1))
        (list 'joystick-enabled (= wl.joystick-enabled 1))
        (list 'joypad-enabled (= wl.joypad-enabled 1))
        (list 'joystick-progressive (= wl.joystick-progressive 1))
        (list 'joystick-port wl.joystick-port)
        (list 'button-mouse (wl.r5-bytes-list wl.buttonmouse 4))
        (list 'button-joy (wl.r5-bytes-list wl.buttonjoy 4))
        (list 'mouse-adjustment wl.mouse-adjustment)))

(defn wl.r5-set-sound-mode (mode)
  (begin
    ;; CP_Sound waits for the current synthesized menu effect before changing
    ;; the device. The timer ISR, not the source-action ordinal, completes it.
    (sd.wait-sound-done)
    (if (sd.set-sound-mode mode) (wl.cp-sound mode) false)))

(defn wl.r5-set-digi-mode (mode)
  (if (sd.set-menu-digi-device mode) (wl.cp-digitized-sound mode) false))

(defn wl.r5-set-music-mode (mode)
  (if (sd.set-music-mode mode) (wl.cp-music mode) false))

(defn wl.r5-record-attempt (tick sound)
  (let ((priority sd.SoundPriority))
    (begin
      ;; tick is source-call provenance only. Elapsed sound time is advanced by
      ;; explicit, source-proven waits below or by the future application host.
      (wl.play-sound sound 'R5Menu)
      (set! wl.r5-attempts
        (cons (list tick sound sd.SoundMode priority sd.last-accepted)
              wl.r5-attempts))
      sd.last-accepted)))

(defn wl.r5-adjacent-movement-pair (attempt next)
  (and next
       (= (car (cdr attempt)) wl.R5-DRAWSND)
       (= (car (car next)) (car attempt))
       (= (car (cdr (car next))) wl.R5-MOVEGUN2SND)))

(defn wl.r5-consume-attempts-through (tick)
  (if (nil? wl.r5-attempt-tail)
      true
      (let ((attempt (car wl.r5-attempt-tail)))
        (if (> (car attempt) tick)
            true
            (begin
              (set! wl.r5-attempt-tail (cdr wl.r5-attempt-tail))
              (wl.r5-record-attempt (car attempt) (car (cdr attempt)))
              ;; HandleMenu's adjacent movement feedback is DRAWSND, a reset
              ;; of the public TimeCount wait, eight source tics, then
              ;; MOVEGUN2SND. A lone MOVEGUN2SND from an inactive-row skip has
              ;; no such delay; neither does the equal-priority tick-45 pair.
              (if (wl.r5-adjacent-movement-pair attempt wl.r5-attempt-tail)
                  (begin (sd.reset-time-count) (sd.advance-source-tics 8)) nil)
              (wl.r5-consume-attempts-through tick))))))

(defn wl.r5-attempt-log () (reverse wl.r5-attempts))
(defn wl.r5-frame-log () (reverse wl.r5-frames))

(defn wl.r5-begin ()
  (begin
    (set! wl.sound-mode wl.SDM-ADLIB) (set! wl.digi-mode wl.SDS-SOUNDBLASTER)
    (set! wl.music-mode wl.SMM-ADLIB) (set! wl.view-size 15)
    (set! wl.pending-view-size 15) (set! wl.mouse-enabled 1)
    (set! wl.joystick-enabled 0) (set! wl.joypad-enabled 0)
    (set! wl.joystick-progressive 0) (set! wl.joystick-port 0)
    (set! wl.mouse-adjustment 5)
    (wl.init-control-bindings)
    (sd.set-sound-mode sd.sdm-AdLib)
    (sd.set-menu-digi-device wl.SDS-SOUNDBLASTER)
    (sd.set-music-mode sd.smm-AdLib)
    (sd.begin-audio-trace 0)
    (sd.start-music 7 'R5StartupMusic)
    (wl.setup-control-panel-machine)
    (set! wl.menu-cursor 0) (set! wl.menu-control-cursor 0)
    (set! wl.r5-route-index 0) (set! wl.r5-terminal 0)
    (set! wl.r5-binding-pending 0) (set! wl.r5-attempts nil)
    (set! wl.r5-attempt-tail wl.r5-sound-attempt-table)
    (set! wl.r5-frames nil)
    (wl.r5-snapshot)))

(defn wl.r5-capture (name)
  (begin (set! wl.r5-frames (cons name wl.r5-frames)) name))

(defn wl.r5-capture-name ()
  (cond ((= wl.r5-route-index 0) 'main-initial)
        ((= wl.r5-route-index 2) 'sound-initial)
        ((= wl.r5-route-index 19) 'control-panel-initial)
        ((= wl.r5-route-index 21) 'custom-controls-initial)
        ((= wl.r5-route-index 31) 'view-initial)
        ((= wl.r5-route-index 34) 'main-final)
        (true nil)))

(defn wl.r5-frame (name frame font)
  (if (not (eq? name (wl.r5-capture-name)))
      false
      (begin (wl.r5-capture name) (wl.draw-control-panel frame font))))

(defn wl.r5-apply (index input)
  (cond
    ((= index 0) (set! wl.menu-cursor 1))
    ((= index 1) (begin (set! wl.menu-screen wl.MENU-SOUND) (set! wl.menu-cursor 0)))
    ((= index 2) true)
    ((= index 3) (wl.r5-set-sound-mode wl.SDM-OFF))
    ((= index 4) (set! wl.menu-cursor 1))
    ((= index 5) (wl.r5-set-sound-mode wl.SDM-PC))
    ((= index 6) (set! wl.menu-cursor 2))
    ((= index 7) (wl.r5-set-sound-mode wl.SDM-ADLIB))
    ((= index 8) (set! wl.menu-cursor 3))
    ((= index 9) (wl.r5-set-digi-mode wl.SDS-OFF))
    ((= index 10) (set! wl.menu-cursor 4))
    ((= index 11) (wl.r5-set-digi-mode wl.SDS-SOUNDSOURCE))
    ((= index 12) (set! wl.menu-cursor 5))
    ((= index 13) (wl.r5-set-digi-mode wl.SDS-SOUNDBLASTER))
    ((= index 14) (set! wl.menu-cursor 6))
    ((= index 15) (wl.r5-set-music-mode wl.SMM-OFF))
    ((= index 16) (begin (set! wl.menu-screen wl.MENU-MAIN) (set! wl.menu-cursor 1)))
    ((= index 17) (set! wl.menu-cursor 2))
    ((= index 18) (begin (set! wl.menu-screen wl.MENU-CONTROL)
                         (set! wl.menu-control-cursor 5)))
    ((= index 19) true)
    ((= index 20) (begin (set! wl.menu-screen wl.MENU-CUSTOM-CONTROLS)
                         (set! wl.menu-control-cursor 4)))
    ((= index 21) true)
    ((or (= index 22) (= index 24)) (set! wl.r5-binding-pending 1))
    ((or (= index 23) (= index 25))
     (if (= wl.r5-binding-pending 1)
         (begin (wl.enter-ctrl-data 4 (wl.play-input input 'scan -1))
                (set! wl.r5-binding-pending 0)) false))
    ((= index 26) (set! wl.menu-screen wl.MENU-CONTROL))
    ((= index 27) (begin (set! wl.menu-screen wl.MENU-MAIN) (set! wl.menu-cursor 2)))
    ((= index 28) (set! wl.menu-cursor 3))
    ;; Save is inactive outside a game, so HandleMenu skips row four.
    ((= index 29) (set! wl.menu-cursor 5))
    ((= index 30) (begin (wl.change-view-begin) (set! wl.menu-screen wl.MENU-VIEW)))
    ((= index 31) (wl.change-view-step 1))
    ((= index 32) (wl.change-view-step -1))
    ((= index 33) (begin (wl.change-view-finish true) (set! wl.menu-screen wl.MENU-MAIN)))
    ((= index 34) true)
    ((= index 35) (set! wl.menu-cursor 6))
    ((= index 36) (set! wl.menu-cursor 7))
    ;; BACK TO DEMO is inactive for this out-of-game route.
    ((= index 37) (set! wl.menu-cursor 9))
    ((= index 38) (begin (wl.cp-quit true) (set! wl.menu-screen wl.MENU-CLOSED)
                         (set! wl.r5-terminal 1)))
    (true false)))

(defn wl.r5-action (source-ordinal input)
  (if (= wl.r5-terminal 1)
      false
      (let ((expected-ordinal (wl.play-at wl.r5-source-ordinals wl.r5-route-index))
            (expected-input (wl.play-at wl.r5-action-inputs wl.r5-route-index)))
        (if (or (not (= source-ordinal expected-ordinal))
                (not (equal? input expected-input)))
            false
            (begin
              ;; Source effects at a boundary observe state before that
              ;; boundary's authored input mutates the selected option.
              (wl.r5-consume-attempts-through source-ordinal)
              (wl.r5-apply wl.r5-route-index input)
              (set! wl.r5-route-index (+ wl.r5-route-index 1))
              (if (= source-ordinal 44)
                  (wl.r5-consume-attempts-through 45) nil)
              true)))))

(defn wl.r5-status ()
  (list 'r5-status wl.r5-route-index wl.menu-screen wl.menu-cursor
        wl.menu-control-cursor wl.r5-terminal (wl.r5-snapshot)))

;;; Drawing surfaces mirror ClearMScreen / DrawWindow / DrawMenu. Source
;;; font pixels are decoded by wl-text; no host text or DOM overlay is used.
(defn wl.clear-m-screen (frame) (wl.bar frame 0 0 320 200 41))

(defn wl.draw-stripes (frame y)
  (begin (wl.bar frame 0 y 320 24 0) (wl.bar frame 0 (+ y 22) 320 1 44) frame))

(defn wl.draw-menu (frame font items x y cursor)
  (wl.draw-menu-at frame font items x y cursor 0))

(defn wl.draw-menu-at (frame font items x y cursor index)
  (if (nil? items)
      frame
      (let ((item (car items)))
        (begin
          (wl.draw-prop-string frame font (wl.play-at item 1) x (+ y (* index 13))
            (if (= index cursor) 15 (if (> (car item) 0) 14 40)))
          (if (= index cursor) (wl.bar frame (- x 12) (+ y (* index 13) 3) 6 6 15) nil)
          (wl.draw-menu-at frame font (cdr items) x y cursor (+ index 1))))))

(defn wl.draw-centered-menu-heading (frame font text y colour)
  (let ((width (car (wl.measure-prop-string font text))))
    (wl.draw-prop-string frame font text (bit.shr (- 320 width) 1) y colour)))

;;; R0 uses DrawWindow's released outside-edge outline rather than the port's
;;; shared inset window helper. DrawOutline's line endpoints are inclusive.
(defn wl.r0-draw-window (frame x y width height)
  (begin
    (wl.bar frame x y width height wl.R0-BKGDCOLOR)
    (wl.bar frame x y (+ width 1) 1 wl.R0-DEACTIVE)
    (wl.bar frame x y 1 (+ height 1) wl.R0-DEACTIVE)
    (wl.bar frame x (+ y height) (+ width 1) 1 wl.R0-BORD2COLOR)
    (wl.bar frame (+ x width) y 1 (+ height 1) wl.R0-BORD2COLOR)
    frame))

(defn wl.r0-menu-colour (active highlighted)
  (wl.play-at (if highlighted wl.r0-color-hilite wl.r0-color-normal) active))

(defn wl.r0-draw-menu (frame font items x y indent cursor)
  (wl.r0-draw-menu-at frame font items x y indent cursor 0))

;;; US_Print resets PrintX to WindowX and advances by the measured font height
;;; at embedded newlines. Episode names depend on that behavior.
(defn wl.r0-draw-menu-string (frame font string x y colour)
  (wl.r0-draw-menu-string-at frame font string x y colour 0 0))

(defn wl.r0-draw-menu-string-at (frame font string x y colour start at)
  (if (= at (string.length string))
      (wl.draw-prop-string frame font (string.substring string start at) x y colour)
      (if (string=? (string.substring string at (+ at 1)) "\n")
          (begin
            (wl.draw-prop-string frame font (string.substring string start at) x y colour)
            (wl.r0-draw-menu-string-at frame font string x
              (+ y (wl.font-height font)) colour (+ at 1) (+ at 1)))
          (wl.r0-draw-menu-string-at frame font string x y colour start (+ at 1)))))

(defn wl.r0-draw-menu-at (frame font items x y indent cursor index)
  (if (nil? items)
      frame
      (let ((item (car items)))
        (begin
          ;; HandleMenu owns cursor graphic animation. DrawMenu only changes
          ;; the selected row's class-indexed text colour at this checkpoint.
          (wl.r0-draw-menu-string frame font (wl.play-at item 1) (+ x indent)
                                  (+ y (* index 13))
                                  (wl.r0-menu-colour (car item) (= index cursor)))
          (wl.r0-draw-menu-at frame font (cdr items) x y indent cursor (+ index 1))))))

;;; Released HandleMenu draws the gun, redraws the selected row with its class
;;; highlight, then invokes the optional selection callback before the first
;;; checkpoint. Keep this separate from DrawMenu so lower-level drawing stays
;;; cursor-free.
(defn wl.r0-handle-menu-entry (frame font items x y indent cursor redraw-selected redraw-difficulty)
  (let ((item (wl.play-at items cursor)))
    (begin
      (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                       (bit.and x -8) (+ (- y 2) (* cursor 13)) wl.C-CURSOR1PIC)
      (if redraw-selected
          (wl.r0-draw-menu-string frame font (wl.play-at item 1) (+ x indent)
                                  (+ y (* cursor 13))
                                  (wl.r0-menu-colour (car item) true)) nil)
      (if redraw-difficulty
          (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                           235 107 (+ wl.C-BABYMODEPIC cursor)) nil)
      frame)))

;;; The retained native checkpoint lands after HandleMenu's first eight-tic
;;; cursor animation. Entry still draws CURSOR1 and redraws the selected row;
;;; this step replaces it with CURSOR2 and repeats only the optional routine.
(defn wl.r0-handle-menu-checkpoint (frame x y cursor redraw-difficulty)
  (begin
    (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                     (bit.and x -8) (+ (- y 2) (* cursor 13)) wl.C-CURSOR2PIC)
    (if redraw-difficulty
        (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                         235 107 (+ wl.C-BABYMODEPIC cursor)) nil)
    frame))

;;; Released DrawMainMenu order and MainItems geometry.
(defn wl.draw-main-menu (frame font)
  (begin
    (wl.clear-m-screen frame)
    (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                     112 184 wl.C-MOUSELBACKPIC)
    (wl.draw-stripes frame 10)
    (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                     84 0 wl.C-OPTIONSPIC)
    (wl.r0-draw-window frame 68 52 178 136)
    (wl.r0-draw-menu frame font wl.r0-main-menu 76 55 24 wl.menu-cursor)
    frame))

(defn wl.draw-episode-pictures (frame index)
  (if (= index 6)
      frame
      (begin
        (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                         42 (+ 23 (* index 26)) (+ wl.C-EPISODE1PIC index))
        (wl.draw-episode-pictures frame (+ index 1)))))

;;; DrawNewEpisode source order: background, mouse legend, framed menu,
;;; centered heading, NewEitems (NE_X/NE_Y/indent), then its six episode art
;;; chunks.  The item list retains the source's inactive spacer rows.
(defn wl.draw-episode-menu (frame font)
  (begin
    (wl.clear-m-screen frame)
    (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                     112 184 wl.C-MOUSELBACKPIC)
    (wl.r0-draw-window frame 6 19 308 162)
    (wl.draw-centered-menu-heading frame font "Which episode to play?" 2
                                   wl.R0-READHCOLOR)
    (wl.r0-draw-menu frame font wl.episode-menu 10 23 88 wl.menu-cursor)
    (wl.draw-episode-pictures frame 0)
    frame))

;;; DrawNewGame source order and released NM_X/NM_Y geometry.  The selected
;;; difficulty art is drawn after NewItems, matching DrawNewGameDiff.
(defn wl.draw-difficulty-menu (frame font)
  (begin
    (wl.clear-m-screen frame)
    (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                     112 184 wl.C-MOUSELBACKPIC)
    (wl.draw-prop-string frame font "How tough are you?" 70 68 wl.R0-READHCOLOR)
    (wl.r0-draw-window frame 45 90 225 67)
    (wl.r0-draw-menu frame font wl.difficulty-menu 50 100 24 wl.difficulty-cursor)
    (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                     235 107 (+ wl.C-BABYMODEPIC wl.difficulty-cursor))
    frame))

(define wl.sound-menu
  '((1 "NONE" sound-off) (1 "PC SPEAKER" sound-pc)
    (1 "ADLIB/SOUNDBLASTER" sound-adlib) (1 "NONE" digi-off)
    (1 "SOUND SOURCE" digi-source) (1 "SOUNDBLASTER" digi-blaster)
    (1 "ADLIB/SOUNDBLASTER" music-adlib)))

(define wl.control-menu
  '((1 "MOUSE ENABLED" mouse) (1 "JOYSTICK ENABLED" joystick)
    (1 "JOYSTICK PORT" joystick-port) (1 "GRAVIS GAMEPAD" joypad)
    (1 "MOUSE SENSITIVITY" sensitivity) (1 "CUSTOMIZE CONTROLS" custom)))

(define wl.custom-control-menu
  '((1 "FIRE" fire) (1 "STRAFE" strafe) (1 "RUN" run) (1 "OPEN" open)
    (1 "FORWARD" forward) (1 "RIGHT" right) (1 "BACKWARD" backward)
    (1 "LEFT" left)))

(defn wl.draw-option-screen (frame font title items cursor)
  (begin
    (wl.clear-m-screen frame)
    (wl.draw-stripes frame 10)
    (wl.window frame 44 28 232 158 41)
    (wl.draw-prop-string frame font title 72 17 15)
    (wl.draw-menu frame font items 68 44 cursor)
    frame))

(defn wl.draw-sound-menu (frame font)
  (wl.draw-option-screen frame font "SOUND SETTINGS" wl.sound-menu wl.menu-cursor))

(defn wl.draw-control-menu (frame font)
  (wl.draw-option-screen frame font "CONTROL" wl.control-menu wl.menu-control-cursor))

(defn wl.draw-custom-controls (frame font)
  (wl.draw-option-screen frame font "CUSTOMIZE" wl.custom-control-menu wl.menu-control-cursor))

(defn wl.draw-load-save-screen (frame font save)
  (begin
    (wl.clear-m-screen frame)
    (wl.draw-stripes frame 10)
    (wl.window frame 48 32 224 152 41)
    (wl.draw-prop-string frame font (if save "SAVE GAME" "LOAD GAME") 112 18 15)
    (wl.draw-save-slots frame font 0)
    frame))

(defn wl.draw-save-slots (frame font slot)
  (if (= slot 10) frame
      (begin
        (wl.draw-prop-string frame font
          (if (> (u8@ wl.menu-save-available slot) 0)
              (wl.play-at wl.menu-save-names slot) "- EMPTY -")
          64 (+ 40 (* slot 13)) (if (= slot wl.menu-cursor) 15 14))
        (wl.draw-save-slots frame font (+ slot 1)))))

(defn wl.draw-change-view (frame)
  (let ((width (if (= wl.pending-view-size 19) 320 (* wl.pending-view-size 16)))
        (height (if (= wl.pending-view-size 19) 160 (* wl.pending-view-size 8))))
    (begin
      (wl.bar frame 0 0 320 160 127)
      (wl.outline frame (/ (- 320 width) 2) (/ (- 160 height) 2)
                  width height 0 125)
      frame)))

(defn wl.draw-control-panel (frame font)
  (cond ((= wl.menu-screen wl.MENU-MAIN) (wl.draw-main-menu frame font))
        ((= wl.menu-screen wl.MENU-EPISODE) (wl.draw-episode-menu frame font))
        ((= wl.menu-screen wl.MENU-DIFFICULTY) (wl.draw-difficulty-menu frame font))
        ((= wl.menu-screen wl.MENU-SOUND) (wl.draw-sound-menu frame font))
        ((= wl.menu-screen wl.MENU-CONTROL) (wl.draw-control-menu frame font))
        ((= wl.menu-screen wl.MENU-CUSTOM-CONTROLS)
         (wl.draw-custom-controls frame font))
        ((= wl.menu-screen wl.MENU-LOAD) (wl.draw-load-save-screen frame font false))
        ((or (= wl.menu-screen wl.MENU-SAVE) (= wl.menu-screen wl.MENU-SAVE-NAME))
         (wl.draw-load-save-screen frame font true))
        ((= wl.menu-screen wl.MENU-VIEW) (wl.draw-change-view frame))
        ((= wl.menu-screen wl.MENU-ARTICLE) (wl.draw-current-article frame font true))
        ((= wl.menu-screen wl.MENU-SCORES) (wl.draw-high-scores frame))
        (true (begin (wl.clear-m-screen frame)
                     (wl.draw-prop-string frame font wl.menu-message 32 80 15)
                     frame))))
