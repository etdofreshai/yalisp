
(define wl.player (bytes.alloc 32))
(define wl.PLAYER-X 0)
(define wl.PLAYER-Y 4)
(define wl.PLAYER-ANGLE 8)
(define wl.PLAYER-TILEX 12)
(define wl.PLAYER-TILEY 16)
(define wl.PLAYER-ANGLEFRAC 20)
(define wl.PLAYER-STATE 24)
(define wl.PLAYER-FLAGS 28)
(define wl.FL-NEVERMARK 4)
(define wl.WP-PISTOL 1)
(define wl.KNIFEPIC 91)
(define wl.GOLDKEYPIC 96)
(define wl.N-BLANKPIC 98)
(define wl.N-0PIC 99)
(define wl.FACE1APIC 109)

(defn wl.player@ (field) (i32@ wl.player field))
(defn wl.player! (field v) (u32! wl.player field v))

(define wl.facecount 0)
(define wl.faceframe 0)
(define wl.attack-active 0)
(define wl.attackframe 0)
(define wl.attackcount 0)
(define wl.weaponframe 0)
(define wl.ammo 8)
(define wl.health 100)
(define wl.thrustspeed 0)
(define wl.score 0)
(define wl.oldscore 0)
(define wl.nextextra 40000)
(define wl.lives 3)
(define wl.map 0)
(define wl.episode 0)
(define wl.bestweapon wl.WP-PISTOL)
(define wl.weapon wl.WP-PISTOL)
(define wl.chosenweapon wl.WP-PISTOL)

(defn wl.new-game (difficulty episode)
  (begin
    (set! wl.difficulty difficulty)
    (set! wl.map 0)
    (set! wl.episode episode)
    (set! wl.score 0)
    (set! wl.oldscore 0)
    (set! wl.nextextra 40000)
    (set! wl.lives 3)
    (set! wl.health 100)
    (set! wl.ammo 8)
    (set! wl.keys 0)
    (set! wl.bestweapon wl.WP-PISTOL)
    (set! wl.weapon wl.WP-PISTOL)
    (set! wl.chosenweapon wl.WP-PISTOL)
    (set! wl.faceframe 0)
    (set! wl.attack-active 0)
    (set! wl.attackframe 0)
    (set! wl.attackcount 0)
    (set! wl.weaponframe 0)))

(defn wl.select-map (mapnum) (set! wl.map mapnum))

(defn wl.init-player-loop ()
  (begin
    (set! wl.facecount 0)
    (set! wl.attack-active 0)
    (set! wl.thrustspeed 0)))

(defn wl.update-face ()
  (begin
    (set! wl.facecount (+ wl.facecount wl.tics))
    (if (> wl.facecount (wl.us-rndt))
        (begin
          (set! wl.faceframe (bit.shr (wl.us-rndt) 6))
          ;; The original folds the otherwise-unused fourth face back to one.
          (if (= wl.faceframe 3) (set! wl.faceframe 1) nil)
          (set! wl.facecount 0))
        nil)))

;;; DrawFace's living, non-SPEAR selector. Dead and special override faces are
;;; intentionally outside this slice and return no drawable latch picture.
(defn wl.living-face-picture ()
  (if (and (> wl.health 0)
           (and (<= wl.health 100)
                (and (>= wl.faceframe 0) (<= wl.faceframe 2))))
      (+ wl.FACE1APIC
         (+ (* 3 (/ (- 100 wl.health) 16)) wl.faceframe))
      -1))

;;; DrawWeapon's exact non-SPEAR selector arithmetic, including the original's
;;; lack of a weapon-enum range guard.
(defn wl.status-weapon-picture ()
  (+ wl.KNIFEPIC wl.weapon))

;;; LatchNumber's non-SPEAR decimal-to-latch arithmetic.  The original sends
;;; every visible character through `str[c]-'0'+N_0PIC`, including a minus
;;; sign; consequently a visible '-' selects chunk 96 (GOLDKEYPIC).  Keep the
;;; conversion numeric so over-width values can discard their leading
;;; characters before a chunk is selected.
(defn wl.decimal-digit-count (magnitude)
  (if (< magnitude 10)
      1
      (+ 1 (wl.decimal-digit-count (/ magnitude 10)))))

(defn wl.decimal-power10 (power)
  (if (= power 0) 1 (* 10 (wl.decimal-power10 (- power 1)))))

(defn wl.decimal-character-chunk (negative magnitude digits index)
  (if (and (= negative 1) (= index 0))
      wl.GOLDKEYPIC
      (let ((digit-index (- index negative)))
        (+ wl.N-0PIC
           (mod (/ magnitude (wl.decimal-power10 (- digits digit-index 1))) 10)))))

(defn wl.latch-number-chunks (width number)
  (let ((negative (if (< number 0) 1 0))
        (magnitude (if (< number 0) (- 0 number) number)))
    (let ((digits (wl.decimal-digit-count magnitude)))
      (let ((length (+ digits negative)))
        (wl.latch-number-chunks-loop
          width
          (if (< length width) (- width length) 0)
          (if (> length width) (- length width) 0)
          negative magnitude digits)))))

(defn wl.latch-number-chunks-loop (remaining padding index negative magnitude digits)
  (if (= remaining 0)
      nil
      (if (> padding 0)
          (cons wl.N-BLANKPIC
                (wl.latch-number-chunks-loop (- remaining 1) (- padding 1) index
                                             negative magnitude digits))
          (cons (wl.decimal-character-chunk negative magnitude digits index)
                (wl.latch-number-chunks-loop (- remaining 1) 0 (+ index 1)
                                             negative magnitude digits)))))

(defn wl.health-latch-chunks ()
  (wl.latch-number-chunks 3 wl.health))

(defn wl.ammo-latch-chunks ()
  (wl.latch-number-chunks 2 wl.ammo))

(defn wl.score-latch-chunks ()
  (wl.latch-number-chunks 6 wl.score))

(defn wl.start-attack ()
  (begin
    (set! wl.attack-active 1)
    (set! wl.attackframe 0)
    (set! wl.attackcount 6)
    (set! wl.weaponframe 1)))

(defn wl.update-attack ()
  (begin
    (set! wl.attackcount (- wl.attackcount wl.tics))
    (wl.advance-attack-frames)))

(defn wl.advance-attack-frames ()
  (if (> wl.attackcount 0)
      nil
      (cond ((= wl.attackframe 3)
             (begin
               (set! wl.attack-active 0)
               (set! wl.attackframe 0)
               (set! wl.attackcount 0)
               (set! wl.weaponframe 0)))
            (true
             (begin
               (if (= wl.attackframe 1)
                   (if (> wl.ammo 0)
                       (begin (wl.gun-attack) (set! wl.ammo (- wl.ammo 1))) nil)
                   nil)
               (set! wl.attackcount (+ wl.attackcount 6))
               (set! wl.attackframe (+ wl.attackframe 1))
               (set! wl.weaponframe (+ wl.attackframe 1))
               (wl.advance-attack-frames))))))

(defn wl.gun-attack ()
  (begin
    (set! wl.madenoise 1)
    (wl.gun-select-loop -1 1000000000)))

(defn wl.gun-select-loop (closest viewdist)
  (let ((selection (wl.gun-scan 0 closest viewdist)))
    (let ((next (car selection)) (distance (car (cdr selection))))
      (if (= next closest)
          false
          (if (wl.check-line
                (wl.player@ wl.PLAYER-X) (wl.player@ wl.PLAYER-Y)
                (wl.actor-x@ next) (wl.actor-y@ next))
              (wl.gun-damage next)
              (wl.gun-select-loop next distance))))))

(defn wl.gun-scan (actor closest viewdist)
  (if (= actor wl.actorcount)
      (list closest viewdist)
      (if (and (and (> (bit.and (wl.actor-flags@ actor) wl.FL-SHOOTABLE) 0)
                    (> (bit.and (wl.actor-flags@ actor) wl.FL-VISABLE) 0))
               (and (< (wl.abs (- (wl.actor-viewx@ actor) wl.centerx)) wl.shootdelta)
                    (< (wl.actor-transx@ actor) viewdist)))
          (wl.gun-scan (+ actor 1) actor (wl.actor-transx@ actor))
          (wl.gun-scan (+ actor 1) closest viewdist))))

(defn wl.gun-damage (actor)
  (let ((distance
          (wl.max (wl.abs (- (wl.actor-tilex@ actor) (wl.player@ wl.PLAYER-TILEX)))
                  (wl.abs (- (wl.actor-tiley@ actor) (wl.player@ wl.PLAYER-TILEY))))))
    (cond ((< distance 2) (wl.damage-actor actor (/ (wl.us-rndt) 4)))
          ((< distance 4) (wl.damage-actor actor (/ (wl.us-rndt) 6)))
          (true
           (if (< (/ (wl.us-rndt) 12) distance)
               false
               (wl.damage-actor actor (/ (wl.us-rndt) 6)))))))

(defn wl.max (a b) (if (> a b) a b))

(defn wl.damage-actor (actor damage)
  (let ((points (if (= (bit.and (wl.actor-flags@ actor) wl.FL-ATTACKMODE) 0)
                    (* damage 2) damage))
        (was-live (> (wl.actor-hitpoints@ actor) 0)))
    (begin
      (wl.actor-hitpoints! actor (- (wl.actor-hitpoints@ actor) points))
      (if (<= (wl.actor-hitpoints@ actor) 0)
          (begin
            (if (and was-live (> (bit.and (wl.actor-flags@ actor) wl.FL-SHOOTABLE) 0))
                (set! wl.killcount (+ wl.killcount 1)) nil)
            (wl.actor-flags! actor
              (bit.and (wl.actor-flags@ actor) (- 255 wl.FL-SHOOTABLE))))
          (if (= (bit.and (wl.actor-flags@ actor) wl.FL-ATTACKMODE) 0)
              (wl.actor-flags! actor
                (bit.or (wl.actor-flags@ actor)
                        (bit.or wl.FL-ATTACKMODE wl.FL-FIRSTATTACK))) nil))
      true)))

(defn wl.spawn-player (tilex tiley dir)
  (begin
    (wl.player! wl.PLAYER-TILEX tilex)
    (wl.player! wl.PLAYER-TILEY tiley)
    (wl.player! wl.PLAYER-X (+ (bit.shl tilex wl.TILESHIFT) (/ wl.TILEGLOBAL 2)))
    (wl.player! wl.PLAYER-Y (+ (bit.shl tiley wl.TILESHIFT) (/ wl.TILEGLOBAL 2)))
    (wl.player! wl.PLAYER-ANGLE (wl.normalize-angle (* (- 1 dir) wl.ANGLEQUAD)))
    (wl.player! wl.PLAYER-ANGLEFRAC 0)
    (wl.player! wl.PLAYER-STATE 0)
    (wl.player! wl.PLAYER-FLAGS wl.FL-NEVERMARK)))

(defn wl.normalize-angle (angle)
  (if (>= angle wl.ANGLES)
      (- angle wl.ANGLES)
      (if (< angle 0) (+ angle wl.ANGLES) angle)))

(defn wl.try-move (x y)
  (wl.try-move-box (bit.shr (- x wl.PLAYERSIZE) wl.TILESHIFT)
                   (bit.shr (- y wl.PLAYERSIZE) wl.TILESHIFT)
                   (bit.shr (+ x wl.PLAYERSIZE) wl.TILESHIFT)
                   (bit.shr (+ y wl.PLAYERSIZE) wl.TILESHIFT)))

(defn wl.try-move-box (xl yl xh yh)
  (if (and (and (>= xl 0) (>= yl 0)) (and (< xh wl.MAPSIZE) (< yh wl.MAPSIZE)))
      (wl.try-move-rows xl yl xh yh yl)
      false))

(defn wl.try-move-rows (xl yl xh yh y)
  (if (> y yh)
      true
      (if (wl.try-move-row xl xh y xl)
          (wl.try-move-rows xl yl xh yh (+ y 1))
          false)))

(defn wl.try-move-row (xl xh y x)
  (if (> x xh)
      true
      (if (wl.solid-for-player? (wl.tilemap@ x y))
          false
          (wl.try-move-row xl xh y (+ x 1)))))

(defn wl.solid-for-player? (tile)
  (if (wl.door-tile? tile)
      (wl.door-solid? (wl.door-number tile))
      (> tile 0)))

(defn wl.clip-move (xmove ymove)
  (wl.clip-move-from (wl.player@ wl.PLAYER-X) (wl.player@ wl.PLAYER-Y) xmove ymove))

(defn wl.clip-move-from (basex basey xmove ymove)
  (if (wl.try-move (+ basex xmove) (+ basey ymove))
      (wl.place basex basey xmove ymove)
      (if (wl.try-move (+ basex xmove) basey)
          (wl.place basex basey xmove 0)
          (if (wl.try-move basex (+ basey ymove))
              (wl.place basex basey 0 ymove)
              (wl.place basex basey 0 0)))))

(defn wl.place (basex basey xmove ymove)
  (begin
    (wl.player! wl.PLAYER-X (+ basex xmove))
    (wl.player! wl.PLAYER-Y (+ basey ymove))))

(defn wl.thrust (angle speed)
  (begin
    (set! wl.thrustspeed (+ wl.thrustspeed speed))
    (wl.thrust-clamped angle (if (>= speed (* wl.MINDIST 2)) (- (* wl.MINDIST 2) 1) speed))))

(defn wl.thrust-clamped (angle speed)
  (begin
    (wl.clip-move (fx.by-frac speed (wl.costable@ angle))
                  (- 0 (fx.by-frac speed (wl.sintable@ angle))))
    (wl.player! wl.PLAYER-TILEX (bit.shr (wl.player@ wl.PLAYER-X) wl.TILESHIFT))
    (wl.player! wl.PLAYER-TILEY (bit.shr (wl.player@ wl.PLAYER-Y) wl.TILESHIFT))))

(defn wl.control-movement (controlx controly)
  (begin
    (set! wl.thrustspeed 0)
    (wl.turn controlx)
    (wl.move controly)))

(defn wl.turn (controlx)
  (wl.turn-by (+ (wl.player@ wl.PLAYER-ANGLEFRAC) controlx)))

(defn wl.turn-by (anglefrac)
  (wl.turn-units anglefrac (/ anglefrac wl.ANGLESCALE)))

(defn wl.turn-units (anglefrac angleunits)
  (begin
    (wl.player! wl.PLAYER-ANGLEFRAC (- anglefrac (* angleunits wl.ANGLESCALE)))
    (wl.player! wl.PLAYER-ANGLE
                (wl.normalize-angle (- (wl.player@ wl.PLAYER-ANGLE) angleunits)))))

(defn wl.move (controly)
  (cond ((< controly 0) (wl.thrust (wl.player@ wl.PLAYER-ANGLE) (* (- 0 controly) wl.MOVESCALE)))
        ((> controly 0) (wl.thrust (wl.normalize-angle (+ (wl.player@ wl.PLAYER-ANGLE) 180))
                                   (* controly wl.BACKMOVESCALE)))
        (true nil)))

(defn wl.poll-keyboard-move (forward backward left right)
  (wl.control-movement
    (* (- right left) (* wl.BASEMOVE wl.tics))
    (* (- backward forward) (* wl.BASEMOVE wl.tics))))

;; PollControls copies the previous frame's buttonstate into buttonheld before
;; T_Player runs, so buttonheld[bt_use] is "use was down last tic".
(define wl.buttonheld-use 0)

(defn wl.cmd-use ()
  (wl.cmd-use-facing (wl.player@ wl.PLAYER-ANGLE)
                     (wl.player@ wl.PLAYER-TILEX)
                     (wl.player@ wl.PLAYER-TILEY)))

(defn wl.cmd-use-facing (angle tilex tiley)
  (cond ((or (< angle 45) (> angle 315)) (wl.cmd-use-tile (+ tilex 1) tiley wl.EAST))
        ((< angle 135) (wl.cmd-use-tile tilex (- tiley 1) wl.NORTH))
        ((< angle 225) (wl.cmd-use-tile (- tilex 1) tiley wl.WEST))
        (true (wl.cmd-use-tile tilex (+ tiley 1) wl.SOUTH))))

;; The pushable-wall test comes before the buttonheld gate, so a held use tic
;; keeps reaching PushWall and it is PushWall's own pwallstate guard, not the
;; button edge, that refuses the second one.
(defn wl.cmd-use-tile (checkx checky dir)
  (let ((doornum (wl.tilemap@ checkx checky)))
    (if (= (u16@ wl.level-objects (* (+ (* checky wl.MAPSIZE) checkx) 2)) wl.PUSHABLETILE)
        (wl.push-wall checkx checky dir)
        (wl.cmd-use-door doornum))))

;; The elevator arm between these two owns playstate and the secret exit and is
;; not part of this slice, so ELEVATORTILE falls through to the do-nothing arm
;; the same way every other non-door tile does.
(defn wl.cmd-use-door (doornum)
  (if (and (= wl.buttonheld-use 0) (wl.door-tile? doornum))
      (begin
        (set! wl.buttonheld-use 1)
        (wl.operate-door (wl.door-number doornum)))
      false))
