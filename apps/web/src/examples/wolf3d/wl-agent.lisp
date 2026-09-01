
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
(define wl.WP-KNIFE 0)
(define wl.WP-PISTOL 1)
(define wl.WP-MACHINEGUN 2)
(define wl.WP-CHAINGUN 3)
(define wl.KNIFEPIC 91)
(define wl.NOKEYPIC 95)
(define wl.GOLDKEYPIC 96)
(define wl.SILVERKEYPIC 97)
(define wl.N-BLANKPIC 98)
(define wl.N-0PIC 99)
(define wl.FACE1APIC 109)
(define wl.FACE8APIC 130)
(define wl.GOTGATLINGPIC 131)
(define wl.MUTANTBJPIC 132)

;;; AUDIOWL6.H sound identifiers reached by the currently ported WL_AGENT.C
;;; pickup paths. Playback/PCM is a generic host contract; ordering and source
;;; decisions remain Lisp-owned here.
(define wl.GETKEYSND 12)
(define wl.GETAMMOSND 31)
(define wl.BONUS1SND 35)
(define wl.BONUS2SND 36)
(define wl.BONUS3SND 37)
(define wl.BONUS1UPSND 44)
(define wl.BONUS4SND 45)
(define wl.ATKGATLINGSND 11)
(define wl.DONOTHINGSND 20)
(define wl.ATKKNIFESND 23)
(define wl.ATKPISTOLSND 24)
(define wl.ATKMACHINEGUNSND 26)
(define wl.LEVELDONESND 40)
(define wl.audio-events nil)
(define wl.audio-event-count 0)

(defn wl.reset-audio-events ()
  (begin (set! wl.audio-events nil) (set! wl.audio-event-count 0)))

(defn wl.play-sound (sound source)
  (begin
    (set! wl.audio-events (cons (list app.time-count sound source) wl.audio-events))
    (set! wl.audio-event-count (+ wl.audio-event-count 1))
    sound))

(defn wl.audio-event-log () (reverse wl.audio-events))

(defn wl.player@ (field) (i32@ wl.player field))
(defn wl.player! (field v) (u32! wl.player field v))

(define wl.facecount 0)
(define wl.faceframe 0)
(define wl.gotgatgun 0)
(define wl.last-attacker -1)
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
(define wl.playerxmove 0)
(define wl.playerymove 0)

;;; WL_AGENT.C attackinfo[4][14]. The published initializer supplies four
;;; entries per weapon; C zero-initializes the remaining ten entries.
(define wl.attackinfo
  '(((6 0 1) (6 2 2) (6 0 3) (6 -1 4)
     (0 0 0) (0 0 0) (0 0 0) (0 0 0) (0 0 0) (0 0 0)
     (0 0 0) (0 0 0) (0 0 0) (0 0 0))
    ((6 0 1) (6 1 2) (6 0 3) (6 -1 4)
     (0 0 0) (0 0 0) (0 0 0) (0 0 0) (0 0 0) (0 0 0)
     (0 0 0) (0 0 0) (0 0 0) (0 0 0))
    ((6 0 1) (6 1 2) (6 3 3) (6 -1 4)
     (0 0 0) (0 0 0) (0 0 0) (0 0 0) (0 0 0) (0 0 0)
     (0 0 0) (0 0 0) (0 0 0) (0 0 0))
    ((6 0 1) (6 1 2) (6 4 3) (6 -1 4)
     (0 0 0) (0 0 0) (0 0 0) (0 0 0) (0 0 0) (0 0 0)
     (0 0 0) (0 0 0) (0 0 0) (0 0 0))))

(defn wl.agent-at (xs index)
  (if (= index 0) (car xs) (wl.agent-at (cdr xs) (- index 1))))

(defn wl.attack-info (weapon frame)
  (wl.agent-at (wl.agent-at wl.attackinfo weapon) frame))

(defn wl.attack-tics (info) (wl.agent-at info 0))
(defn wl.attack-action (info) (wl.agent-at info 1))
(defn wl.attack-picture (info) (wl.agent-at info 2))

(defn wl.new-game (difficulty episode)
  (begin
    (wl.reset-audio-events)
    ;; WL_MAIN.C clears the complete gamestate before restoring fresh-game
    ;; defaults.  These trailing source fields are shared with the death-camera
    ;; consumer, but their NewGame reset belongs here with the other scalars.
    (set! wl.killx 0)
    (set! wl.killy 0)
    (set! wl.victoryflag 0)
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

(defn wl.gatling-sound-active? ()
  (and (bound? 'sd.sound-playing)
       (= (sd.sound-playing) wl.GETGATLINGSND)))

(defn wl.gatling-face-active? ()
  (and (= wl.gotgatgun 1) (wl.gatling-sound-active?)))

(defn wl.update-face ()
  (if (wl.gatling-sound-active?)
      nil
      (begin
        (set! wl.facecount (+ wl.facecount wl.tics))
        (if (> wl.facecount (wl.us-rndt))
            (begin
              (set! wl.faceframe (bit.shr (wl.us-rndt) 6))
              ;; The original folds the otherwise-unused fourth face back to one.
              (if (= wl.faceframe 3) (set! wl.faceframe 1) nil)
              (set! wl.facecount 0))
            nil))))

;;; DrawFace's living, non-SPEAR selector. The gatling pickup override is
;;; applied by status-face-picture while its source sound owns the sound lane.
(defn wl.living-face-picture ()
  (if (and (> wl.health 0)
           (and (<= wl.health 100)
                (and (>= wl.faceframe 0) (<= wl.faceframe 2))))
      (+ wl.FACE1APIC
         (+ (* 3 (/ (- 100 wl.health) 16)) wl.faceframe))
      -1))

;;; DrawFace unconditionally dereferences LastAttacker when health reaches zero.
;;; Keep the unset sentinel fail-closed rather than inventing a default killer.
(defn wl.status-face-picture ()
  (if (wl.gatling-face-active?)
      wl.GOTGATLINGPIC
      (if (= wl.health 0)
          (if (= (wl.actor-class@ wl.last-attacker) wl.NEEDLEOBJ)
              wl.MUTANTBJPIC
              wl.FACE8APIC)
          (wl.living-face-picture))))

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

(defn wl.lives-latch-chunks ()
  (wl.latch-number-chunks 1 wl.lives))

(defn wl.level-latch-chunks ()
  (wl.latch-number-chunks 2 (+ wl.map 1)))

(defn wl.ammo-latch-chunks ()
  (wl.latch-number-chunks 2 wl.ammo))

;;; DrawKeys tests the two source bits independently and always selects one
;;; picture for each slot. Preserve raw signed bitwise behavior and ignore all
;;; higher bits when selecting the pictures.
(defn wl.gold-key-picture (keys)
  (if (= (bit.and keys 1) 0) wl.NOKEYPIC wl.GOLDKEYPIC))

(defn wl.silver-key-picture (keys)
  (if (= (bit.and keys 2) 0) wl.NOKEYPIC wl.SILVERKEYPIC))

(defn wl.score-latch-chunks ()
  (wl.latch-number-chunks 6 wl.score))

(defn wl.start-attack ()
  (let ((info (wl.attack-info wl.weapon 0)))
    (begin
      (u8! wl.buttonheld wl.BT-ATTACK 1)
      (set! wl.attack-active 1)
      (set! wl.attackframe 0)
      (set! wl.attackcount (wl.attack-tics info))
      (set! wl.weaponframe (wl.attack-picture info)))))

(defn wl.update-attack ()
  (begin
    (set! wl.attackcount (- wl.attackcount wl.tics))
    (wl.advance-attack-frames)))

(defn wl.advance-attack-frames ()
  (if (> wl.attackcount 0)
      nil
      (let ((info (wl.attack-info wl.weapon wl.attackframe)))
        (let ((action (wl.attack-action info)))
          (if (= action -1)
              (wl.finish-attack)
              (begin
                (wl.run-attack-action action)
                (set! wl.attackcount (+ wl.attackcount (wl.attack-tics info)))
                (set! wl.attackframe (+ wl.attackframe 1))
                (set! wl.weaponframe
                      (wl.attack-picture (wl.attack-info wl.weapon wl.attackframe)))
                (wl.advance-attack-frames)))))))

(defn wl.finish-attack ()
  (begin
    (set! wl.attack-active 0)
    (if (= wl.ammo 0)
        (set! wl.weapon wl.WP-KNIFE)
        (if (not (= wl.weapon wl.chosenweapon))
            (set! wl.weapon wl.chosenweapon) nil))
    (set! wl.attackframe 0)
    (set! wl.weaponframe 0)))

(defn wl.run-attack-action (action)
  (cond ((= action 1) (wl.fire-gun-frame))
        ((= action 2) (wl.knife-attack))
        ((= action 3)
         (if (and (> wl.ammo 0) (> (u8@ wl.buttonstate wl.BT-ATTACK) 0))
             (set! wl.attackframe (- wl.attackframe 2)) nil))
        ((= action 4)
         (if (= wl.ammo 0)
             nil
             (begin
               (if (> (u8@ wl.buttonstate wl.BT-ATTACK) 0)
                   (set! wl.attackframe (- wl.attackframe 2)) nil)
               (wl.fire-gun-frame))))
        (true nil)))

;;; The source advances an extra frame when an action-1 gun frame finds no
;;; ammo. This is reachable only for the chaingun after its preceding shot.
(defn wl.fire-gun-frame ()
  (if (= wl.ammo 0)
      (set! wl.attackframe (+ wl.attackframe 1))
      (begin
        (wl.gun-attack)
        (set! wl.ammo (- wl.ammo 1)))))

(defn wl.check-weapon-change ()
  (if (= wl.ammo 0)
      false
      (wl.check-ready-weapon wl.WP-KNIFE)))

(defn wl.check-ready-weapon (weapon)
  (if (> weapon wl.bestweapon)
      false
      (if (> (u8@ wl.buttonstate (+ wl.BT-READYKNIFE weapon)) 0)
          (begin
            (set! wl.weapon weapon)
            (set! wl.chosenweapon weapon)
            weapon)
          (wl.check-ready-weapon (+ weapon 1)))))

(defn wl.gun-attack ()
  (begin
    (wl.play-sound (wl.weapon-attack-sound wl.weapon) 'GunAttack)
    (set! wl.madenoise 1)
    (wl.gun-select-loop -1 1000000000)))

(defn wl.weapon-attack-sound (weapon)
  (cond ((= weapon wl.WP-PISTOL) wl.ATKPISTOLSND)
        ((= weapon wl.WP-MACHINEGUN) wl.ATKMACHINEGUNSND)
        ((= weapon wl.WP-CHAINGUN) wl.ATKGATLINGSND)
        (true wl.ATKPISTOLSND)))

(defn wl.knife-attack ()
  (begin
    (wl.play-sound wl.ATKKNIFESND 'KnifeAttack)
    ;; 1e9 is safely above every fixed-point view distance while remaining
    ;; representable by the tagged integer runtime (the C source uses LONG_MAX).
    (let ((selection (wl.knife-scan 0 -1 1000000000)))
      (let ((closest (car selection)) (distance (car (cdr selection))))
        (if (or (= closest -1) (> distance 98304))
            false
            (wl.damage-actor closest (bit.shr (wl.us-rndt) 4)))))))

(defn wl.knife-scan (actor closest distance)
  (if (= actor wl.actorcount)
      (list closest distance)
      (if (and (and (> (bit.and (wl.actor-flags@ actor) wl.FL-SHOOTABLE) 0)
                    (> (bit.and (wl.actor-flags@ actor) wl.FL-VISABLE) 0))
               (and (< (wl.abs (- (wl.actor-viewx@ actor) wl.centerx)) wl.shootdelta)
                    (< (wl.actor-transx@ actor) distance)))
          (wl.knife-scan (+ actor 1) actor (wl.actor-transx@ actor))
          (wl.knife-scan (+ actor 1) closest distance))))

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
          (if (and was-live (> (bit.and (wl.actor-flags@ actor) wl.FL-SHOOTABLE) 0))
              (wl.kill-actor actor) nil)
          (begin
            (if (= (bit.and (wl.actor-flags@ actor) wl.FL-ATTACKMODE) 0)
                (wl.actor-flags! actor
                  (bit.or (wl.actor-flags@ actor)
                          (bit.or wl.FL-ATTACKMODE wl.FL-FIRSTATTACK))) nil)
            (wl.start-actor-pain actor)))
      true)))

;;; WL_STATE.C KillActor: score, drop, death state, occupancy, and kill counter.
(defn wl.kill-actor (actor)
  (let ((class (wl.actor-class@ actor))
        (x (bit.shr (wl.actor-x@ actor) wl.TILESHIFT))
        (y (bit.shr (wl.actor-y@ actor) wl.TILESHIFT)))
    (begin
      (wl.actor-tilex! actor x)
      (wl.actor-tiley! actor y)
      (wl.give-points (wl.kill-points class))
      ;; WL_STATE.C orders the four boss snapshots after GivePoints and before
      ;; NewState.  Schabbs/real Hitler then scream only after NewState.
      (wl.capture-deathcam-kill actor class)
      (wl.start-actor-death actor)
      (wl.play-immediate-boss-death-scream actor class)
      ;; Every source drop arm places its item after NewState.
      (wl.kill-drop class x y)
      ;; Preserve the common KillActor tail literally: count, clear shootable,
      ;; release occupancy, then add NONMARK.
      (set! wl.killcount (+ wl.killcount 1))
      (wl.actor-flags! actor
        (bit.and (wl.actor-flags@ actor) (- 255 wl.FL-SHOOTABLE)))
      (wl.actorat-clear-owner actor)
      (wl.actor-flags! actor (bit.or (wl.actor-flags@ actor) wl.FL-NONMARK))
      true)))

;;; Bounded producer contract for WL_ACT2.C A_StartDeathCam.  The later
;;; death-camera consumer owns camera placement and reads wl.killx/wl.killy;
;;; wl-agent owns only the source KillActor-time snapshot and immediate scream
;;; decision.  New-game/reset policy intentionally remains outside this
;;; seam.  The live/shootable guard also makes a repeated direct call fail
;;; closed after kill-actor clears FL-SHOOTABLE.
(defn wl.deathcam-kill-class? (class)
  (or (= class wl.SCHABBOBJ)
      (or (= class wl.GIFTOBJ)
          (or (= class wl.FATOBJ) (= class wl.REALHITLEROBJ)))))

(defn wl.immediate-death-scream-class? (class)
  (or (= class wl.SCHABBOBJ) (= class wl.REALHITLEROBJ)))

(defn wl.capture-deathcam-kill (actor class)
  (if (or (< actor 0) (>= actor wl.actorcount))
      false
      (if (and (wl.deathcam-kill-class? class)
               (and (= class (wl.actor-class@ actor))
                    (and (<= (wl.actor-hitpoints@ actor) 0)
                         (> (bit.and (wl.actor-flags@ actor) wl.FL-SHOOTABLE) 0))))
          (begin
            (set! wl.killx (wl.player@ wl.PLAYER-X))
            (set! wl.killy (wl.player@ wl.PLAYER-Y))
            true)
          false)))

(defn wl.play-immediate-boss-death-scream (actor class)
  (if (or (< actor 0) (>= actor wl.actorcount))
      false
      (if (and (wl.immediate-death-scream-class? class)
               (and (= class (wl.actor-class@ actor))
                    (and (<= (wl.actor-hitpoints@ actor) 0)
                         (and (= (wl.actor-phase@ actor) wl.ACTOR-DYING)
                              (> (bit.and (wl.actor-flags@ actor) wl.FL-SHOOTABLE) 0)))))
          (wl.death-scream actor class)
          false)))

(defn wl.kill-points (class)
  (cond ((= class 3) 100) ((= class 4) 400) ((= class 5) 500)
        ((= class 6) 200) ((= class 11) 700) ((= class wl.FAKEOBJ) 2000)
        ((wl.boss-class? class) 5000) (true 0)))

(defn wl.kill-drop (class x y)
  (cond ((or (= class 3) (or (= class 4) (= class 11)))
         (wl.spawn-static-item x y wl.BO-CLIP2))
        ((= class 5)
         (wl.spawn-static-item x y
           (if (< wl.bestweapon 2) wl.BO-MACHINEGUN wl.BO-CLIP2)))
        ((or (= class wl.BOSSOBJ) (= class wl.GRETELOBJ))
         (wl.spawn-static-item x y wl.BO-KEY1))
        (true -1)))

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
  (if (wl.try-move-box (bit.shr (- x wl.PLAYERSIZE) wl.TILESHIFT)
                       (bit.shr (- y wl.PLAYERSIZE) wl.TILESHIFT)
                       (bit.shr (+ x wl.PLAYERSIZE) wl.TILESHIFT)
                       (bit.shr (+ y wl.PLAYERSIZE) wl.TILESHIFT))
      (wl.try-move-actors x y 0)
      false))

;;; WL_AGENT.C TryMove expands the tile box by one and rejects shootable actors
;;; whose centers are within MINACTORDIST (one TILEGLOBAL) on both axes.
(defn wl.try-move-actors (x y actor)
  (if (= actor wl.actorcount)
      true
      (if (and (> (bit.and (wl.actor-flags@ actor) wl.FL-SHOOTABLE) 0)
               (and (<= (wl.abs (- x (wl.actor-x@ actor))) wl.TILEGLOBAL)
                    (<= (wl.abs (- y (wl.actor-y@ actor))) wl.TILEGLOBAL)))
          false
          (wl.try-move-actors x y (+ actor 1)))))

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
      (if (or (> (wl.actorat-wall@ x y) 0)
              (wl.solid-for-player? (wl.tilemap@ x y)))
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
  (let ((oldx (wl.player@ wl.PLAYER-X)) (oldy (wl.player@ wl.PLAYER-Y)))
    (begin
      (set! wl.thrustspeed 0)
      ;; Source order: lateral strafe or turn first, then forward/back motion.
      (if (> (u8@ wl.buttonstate wl.BT-STRAFE) 0)
          (wl.strafe controlx)
          (wl.turn controlx))
      (wl.move controly)
      (set! wl.playerxmove (- (wl.player@ wl.PLAYER-X) oldx))
      (set! wl.playerymove (- (wl.player@ wl.PLAYER-Y) oldy)))))

(defn wl.strafe (controlx)
  (cond ((> controlx 0)
         (wl.thrust (wl.normalize-angle (- (wl.player@ wl.PLAYER-ANGLE) wl.ANGLEQUAD))
                    (* controlx wl.MOVESCALE)))
        ((< controlx 0)
         (wl.thrust (wl.normalize-angle (+ (wl.player@ wl.PLAYER-ANGLE) wl.ANGLEQUAD))
                    (* (- 0 controlx) wl.MOVESCALE)))
        (true nil)))

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

;;; T_Player/T_Attack source-order entry points. app.player-tick remains the
;;; resumable browser scheduler, while these own the complete per-player rules
;;; and are suitable for direct ticks and parity fixtures.
(defn wl.t-player (controlx controly)
  (begin
    (wl.update-face)
    (wl.check-weapon-change)
    (set! wl.buttonheld-use (u8@ wl.buttonheld wl.BT-USE))
    (if (> (u8@ wl.buttonstate wl.BT-USE) 0) (wl.cmd-use) nil)
    (if (and (> (u8@ wl.buttonstate wl.BT-ATTACK) 0)
             (= (u8@ wl.buttonheld wl.BT-ATTACK) 0))
        (wl.start-attack) nil)
    (wl.control-movement controlx controly)))

(defn wl.t-attack (controlx controly)
  (begin
    (wl.update-face)
    (if (and (> (u8@ wl.buttonstate wl.BT-USE) 0)
             (= (u8@ wl.buttonheld wl.BT-USE) 0))
        (u8! wl.buttonstate wl.BT-USE 0) nil)
    (if (and (> (u8@ wl.buttonstate wl.BT-ATTACK) 0)
             (= (u8@ wl.buttonheld wl.BT-ATTACK) 0))
        (u8! wl.buttonstate wl.BT-ATTACK 0) nil)
    (wl.control-movement controlx controly)
    (wl.update-attack)))

(defn wl.cmd-use ()
  (wl.cmd-use-facing (wl.player@ wl.PLAYER-ANGLE)
                     (wl.player@ wl.PLAYER-TILEX)
                     (wl.player@ wl.PLAYER-TILEY)))

(defn wl.cmd-use-facing (angle tilex tiley)
  (cond ((or (< angle 45) (> angle 315)) (wl.cmd-use-tile (+ tilex 1) tiley wl.EAST 1))
        ((< angle 135) (wl.cmd-use-tile tilex (- tiley 1) wl.NORTH 0))
        ((< angle 225) (wl.cmd-use-tile (- tilex 1) tiley wl.WEST 1))
        (true (wl.cmd-use-tile tilex (+ tiley 1) wl.SOUTH 0))))

;; The pushable-wall test comes before the buttonheld gate, so a held use tic
;; keeps reaching PushWall and it is PushWall's own pwallstate guard, not the
;; button edge, that refuses the second one.
(defn wl.cmd-use-tile (checkx checky dir elevatorok)
  (let ((doornum (wl.tilemap@ checkx checky)))
    (if (= (u16@ wl.level-objects (* (+ (* checky wl.MAPSIZE) checkx) 2)) wl.PUSHABLETILE)
        (wl.push-wall checkx checky dir)
        (wl.cmd-use-dispatch doornum checkx checky elevatorok))))

(defn wl.cmd-use-door (doornum)
  (wl.cmd-use-dispatch doornum 0 0 0))

(defn wl.cmd-use-dispatch (doornum checkx checky elevatorok)
  (cond ((and (and (= wl.buttonheld-use 0) (= doornum wl.ELEVATORTILE))
              (= elevatorok 1))
         (begin
           (set! wl.buttonheld-use 1)
           (u8! wl.buttonheld wl.BT-USE 1)
           (wl.tilemap! checkx checky (+ doornum 1))
           (if (= (u16@ wl.level-walls
                        (* (+ (* (wl.player@ wl.PLAYER-TILEY) wl.MAPSIZE)
                              (wl.player@ wl.PLAYER-TILEX)) 2))
                  wl.ALTELEVATORTILE)
               (set! wl.playstate wl.EX-SECRETLEVEL)
               (set! wl.playstate wl.EX-COMPLETED))
           (wl.play-sound wl.LEVELDONESND 'Cmd_Use)
           (sd.wait-sound-done)
           true))
        ((and (= wl.buttonheld-use 0) (wl.door-tile? doornum))
         (begin
           (set! wl.buttonheld-use 1)
           (u8! wl.buttonheld wl.BT-USE 1)
           (wl.operate-door (wl.door-number doornum))))
        (true
         (begin (wl.play-sound wl.DONOTHINGSND 'Cmd_Use) false))))
