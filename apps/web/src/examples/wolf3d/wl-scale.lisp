;;; WL_SCALE.C - the compressed-shape scaler used by the first proven actor
;;; rendering boundary. This slice draws the non-rotating dead guard reached at
;;; canonical R1 record 13. Rotating actors, statics, and the weapon remain
;;; separate boundaries.

(defn wl.sprite-width (step source)
  (- (bit.shr (* (+ source 1) step) 16)
     (bit.shr (* source step) 16)))

(defn wl.sprite-clear? (x rawheight)
  (< (wl.wallheight@ x) rawheight))

(defn wl.sprite-trim-right (x width rawheight)
  (if (or (= width 0) (wl.sprite-clear? (+ x width -1) rawheight))
      width
      (wl.sprite-trim-right x (- width 1) rawheight)))

(defn wl.sprite-trim-left (x width rawheight)
  (if (or (= width 0) (wl.sprite-clear? x rawheight))
      x
      (wl.sprite-trim-left (+ x 1) (- width 1) rawheight)))

(defn wl.sprite-fill-rows (frame x width colour row stop)
  (if (>= row stop)
      frame
      (begin
        (bytes.fill frame (+ wl.viewofs (+ (* row wl.SCREENWIDTH) x)) width colour)
        (wl.sprite-fill-rows frame x width colour (+ row 1) stop))))

(defn wl.sprite-source-run (frame page middle source stop x width step top)
  (if (>= source stop)
      frame
      (let ((row (+ top (bit.shr (* source step) 16)))
            (end (+ top (bit.shr (* (+ source 1) step) 16))))
        (begin
          (if (and (> end 0) (< row wl.viewheight))
              (wl.sprite-fill-rows frame x width
                (u8@ pm.file (+ page (bit.and (+ middle source) 65535)))
                (if (< row 0) 0 row)
                (if (> end wl.viewheight) wl.viewheight end))
              nil)
          (wl.sprite-source-run frame page middle (+ source 1) stop
                                x width step top)))))

(defn wl.sprite-command-run (frame page command x width step top)
  (let ((end (u16@ pm.file command)))
    (if (= end 0)
        frame
        (begin
          (wl.sprite-source-run frame page (u16@ pm.file (+ command 2))
                                (bit.shr (u16@ pm.file (+ command 4)) 1)
                                (bit.shr end 1) x width step top)
          (wl.sprite-command-run frame page (+ command 6) x width step top)))))

(defn wl.sprite-column (frame page left source x width step top)
  (wl.sprite-command-run frame page
    (+ page (u16@ pm.file (+ page (+ 4 (* (- source left) 2)))))
    x width step top))

(defn wl.scale-shape-left-draw (frame page left source x width rawheight step top)
  (let ((leftvis (wl.sprite-clear? x rawheight))
        (rightvis (wl.sprite-clear? (+ x width -1) rawheight)))
    (if leftvis
        (let ((visible (if rightvis width (wl.sprite-trim-right x width rawheight))))
          (begin
            (if (> visible 0) (wl.sprite-column frame page left source x visible step top) nil)
            (wl.scale-shape-left frame page left source x rawheight step top)))
        (if rightvis
            (let ((nextx (wl.sprite-trim-left x width rawheight)))
              (let ((visible (- (+ x width) nextx)))
                (if (> visible 0)
                    (wl.sprite-column frame page left source nextx visible step top)
                    nil)))
            (wl.scale-shape-left frame page left source x rawheight step top)))))

(defn wl.scale-shape-left-wide (frame page left source x width rawheight step top)
  (if (> x wl.viewwidth)
      (let ((nextx (- x width)))
        (let ((visible (- wl.viewwidth nextx)))
          (if (< visible 1)
              (wl.scale-shape-left frame page left source nextx rawheight step top)
              (wl.scale-shape-left-draw frame page left source nextx visible rawheight step top))))
      (let ((visible (if (> width x) x width)))
        (wl.scale-shape-left-draw frame page left source (- x visible) visible rawheight step top))))

(defn wl.scale-shape-left (frame page left source x rawheight step top)
  (let ((nextsource (- source 1)))
    (if (or (< nextsource left) (<= x 0))
        frame
        (let ((width (wl.sprite-width step nextsource)))
          (cond ((= width 0)
                 (wl.scale-shape-left frame page left nextsource x rawheight step top))
                ((= width 1)
                 (let ((nextx (- x 1)))
                   (begin
                     (if (and (< nextx wl.viewwidth) (wl.sprite-clear? nextx rawheight))
                         (wl.sprite-column frame page left nextsource nextx 1 step top) nil)
                     (wl.scale-shape-left frame page left nextsource nextx rawheight step top))))
                (true (wl.scale-shape-left-wide frame page left nextsource x width rawheight step top)))))))

(defn wl.scale-shape-right-draw (frame page left right source x width rawheight step top)
  (let ((leftvis (wl.sprite-clear? x rawheight))
        (rightvis (wl.sprite-clear? (+ x width -1) rawheight)))
    (if leftvis
        (if rightvis
            (begin (wl.sprite-column frame page left source x width step top)
                   (wl.scale-shape-right frame page left right source x width rawheight step top))
            (let ((visible (wl.sprite-trim-right x width rawheight)))
              (if (> visible 0) (wl.sprite-column frame page left source x visible step top) nil)))
        (if rightvis
            (let ((nextx (wl.sprite-trim-left x width rawheight)))
              (let ((visible (- (+ x width) nextx)))
                (begin
                  (if (> visible 0) (wl.sprite-column frame page left source nextx visible step top) nil)
                  (wl.scale-shape-right frame page left right source nextx visible rawheight step top))))
            (wl.scale-shape-right frame page left right source x width rawheight step top)))))

(defn wl.scale-shape-right-wide (frame page left right source x width rawheight step top)
  (if (< x 0)
      (if (<= width (- 0 x))
          (wl.scale-shape-right frame page left right source x width rawheight step top)
          (wl.scale-shape-right-draw frame page left right source 0 (+ width x) rawheight step top))
      (wl.scale-shape-right-draw frame page left right source x
        (if (> (+ x width) wl.viewwidth) (- wl.viewwidth x) width)
        rawheight step top)))

(defn wl.scale-shape-right (frame page left right source x previous rawheight step top)
  (let ((nextsource (+ source 1)) (nextx (+ x previous)))
    (if (or (> nextsource right) (>= nextx wl.viewwidth))
        frame
        (let ((width (wl.sprite-width step nextsource)))
          (cond ((= width 0)
                 (wl.scale-shape-right frame page left right nextsource nextx 0 rawheight step top))
                ((= width 1)
                 (begin
                   (if (and (>= nextx 0) (wl.sprite-clear? nextx rawheight))
                       (wl.sprite-column frame page left nextsource nextx 1 step top) nil)
                   (wl.scale-shape-right frame page left right nextsource nextx 1 rawheight step top)))
                (true (wl.scale-shape-right-wide frame page left right nextsource nextx width rawheight step top)))))))

(defn wl.scale-shape (frame xcenter shapenum rawheight)
  (let ((requested (bit.shr rawheight 3)))
    (if (or (= requested 0) (> requested wl.MAXSCALE))
        frame
        (let ((scale (wl.scaler-stepped requested)) (page (pm.sprite-page shapenum)))
          (let ((height (* scale 2))
                (left (u16@ pm.file page))
                (right (u16@ pm.file (+ page 2))))
            (let ((step (/ (bit.shl height 16) 64))
                  (top (/ (- wl.viewheight height) 2)))
              (begin
                (wl.scale-shape-left frame page left 32 xcenter rawheight step top)
                (wl.scale-shape-right frame page left right
                  (if (< left 31) 31 (- left 1)) xcenter 0 rawheight step top)
                frame)))))))

;;; SimpleScaleShape uses the same generated width table and compressed post
;;; stream without wall clipping. The original uses it for the foreground
;;; weapon after world sprites have been composed.
(defn wl.simple-scale-left (frame page left source x step top)
  (let ((nextsource (- source 1)))
    (if (< nextsource left)
        frame
        (let ((width (wl.sprite-width step nextsource)))
          (begin
            (if (> width 0)
                (wl.sprite-column frame page left nextsource (- x width) width step top)
                nil)
            (wl.simple-scale-left frame page left nextsource (- x width) step top))))))

(defn wl.simple-scale-right (frame page left right source x previous step top)
  (let ((nextsource (+ source 1)) (nextx (+ x previous)))
    (if (> nextsource right)
        frame
        (let ((width (wl.sprite-width step nextsource)))
          (begin
            (if (> width 0)
                (wl.sprite-column frame page left nextsource nextx width step top)
                nil)
            (wl.simple-scale-right frame page left right nextsource nextx width step top))))))

(defn wl.simple-scale-shape (frame xcenter shapenum rawheight)
  (let ((scale (wl.scaler-stepped (bit.shr rawheight 1)))
        (page (pm.sprite-page shapenum)))
    (let ((height (* scale 2))
          (left (u16@ pm.file page))
          (right (u16@ pm.file (+ page 2))))
      (let ((step (/ (bit.shl height 16) 64))
            (top (/ (- wl.viewheight height) 2)))
        (begin
          (wl.simple-scale-left frame page left 32 xcenter step top)
          (wl.simple-scale-right frame page left right
            (if (< left 31) 31 (- left 1)) xcenter 0 step top)
          frame)))))

(define wl.SPR-KNIFEREADY 416)
(define wl.SPR-PISTOLREADY 421)
(define wl.SPR-MACHINEGUNREADY 426)
(define wl.SPR-CHAINREADY 431)
(define wl.SPR-DEMO 0)
(define wl.SPR-DEATHCAM 1)
(define wl.HROCKETOBJ 27)

(defn wl.weapon-shape-base (weapon)
  (cond ((= weapon 0) wl.SPR-KNIFEREADY)
        ((= weapon 1) wl.SPR-PISTOLREADY)
        ((= weapon 2) wl.SPR-MACHINEGUNREADY)
        ((= weapon 3) wl.SPR-CHAINREADY)
        (true -1)))

;;; A missing or truncated VSWAP must not turn an optional foreground overlay
;;; into an out-of-range page read. The original assets place sprite ordinals
;;; in [PMSpriteStart, PMSoundStart); the page itself must also be non-empty.
(defn wl.sprite-present? (shapenum)
  (if (or (< shapenum 0) (not (pm.started?)))
      false
      (let ((page (+ pm.sprite-start shapenum)))
        (if (or (< page pm.sprite-start) (>= page pm.sound-start))
            false
            (let ((offset (pm.page-offset page)) (length (pm.page-length page)))
              (and (> length 0)
                   (and (>= offset 0)
                        (<= (+ offset length) (bytes.length pm.file)))))))))

(defn wl.demo-overlay-active? ()
  (or (> wl.demo-recording 0) (> wl.demo-playback 0)))

;;; DrawPlayerWeapon's exact source decision order. Victory returns before the
;;; weapon and demo badge; only the blinking s_deathcam frame survives it.
(defn wl.player-overlay-shapes ()
  (if (> wl.victoryflag 0)
      (if (and (> wl.deathcam-active 0)
               (> (bit.and app.time-count 32) 0))
          (list wl.SPR-DEATHCAM)
          nil)
      (let ((base (wl.weapon-shape-base wl.weapon)))
        (let ((demo (if (wl.demo-overlay-active?) (list wl.SPR-DEMO) nil)))
          (if (< base 0)
              demo
              (cons (+ base wl.weaponframe) demo))))))

(defn wl.draw-player-overlays (frame shapes)
  (if (nil? shapes)
      frame
      (begin
        (if (wl.sprite-present? (car shapes))
            (wl.simple-scale-shape frame (/ wl.viewwidth 2)
                                   (car shapes) (+ wl.viewheight 1))
            nil)
        (wl.draw-player-overlays frame (cdr shapes)))))

;;; Foreground shapes compose after world sprites and are not wall clipped.
(defn wl.draw-player-weapon (frame)
  (wl.draw-player-overlays frame (wl.player-overlay-shapes)))

(defn wl.draw-r1-ready-pistol (frame) (wl.draw-player-weapon frame))

(defn wl.draw-r1-inert-actor (frame actor)
  (if (and (= (wl.actor-class@ actor) 2)
           (> (bit.and (wl.actor-flags@ actor) wl.FL-VISABLE) 0))
      (wl.scale-shape frame (wl.actor-viewx@ actor)
                      (wl.actor-shapenum actor) (wl.actor-viewheight@ actor))
      frame))

(defn wl.draw-r1-inert-actors-from (frame actor)
  (if (= actor wl.actorcount)
      frame
      (begin (wl.draw-r1-inert-actor frame actor)
             (wl.draw-r1-inert-actors-from frame (+ actor 1)))))

(defn wl.draw-r1-inert-actors (frame)
  (wl.draw-r1-inert-actors-from frame 0))

;;; State rotate values retained by the compact actor representation. Source
;;; pain states use rotate==2; rockets use rotate==true and their own angle.
(defn wl.actor-state-rotate (actor)
  (let ((class (wl.actor-class@ actor)) (phase (wl.actor-phase@ actor)))
    (cond ((and (= phase wl.ACTOR-PAIN)
                (or (= class wl.GUARDOBJ)
                    (or (= class wl.OFFICEROBJ)
                        (or (= class wl.SSOBJ) (= class wl.MUTANTOBJ))))) 2)
          ((and (= phase wl.ACTOR-PROJECTILE)
                (or (= class wl.ROCKETOBJ) (= class wl.HROCKETOBJ))) 1)
          ((and (not (= class 2)) (< phase wl.ACTOR-SHOOT)) 1)
          (true 0))))

(defn wl.actor-rotation-bearing (actor)
  (if (or (= (wl.actor-class@ actor) wl.ROCKETOBJ)
          (= (wl.actor-class@ actor) wl.HROCKETOBJ))
      (wl.actor-angle@ actor)
      (* (wl.actor-dir@ actor) 45)))

;;; CalcRotate is the original cheap selection: apparent view angle is nudged
;;; by screen x, then rocket/hrocket subtract actor angle while ordinary states
;;; subtract dirangle[dir]. rotate==2 selects only pain-frame offsets 0 or 4.
(defn wl.calc-rotate (actor)
  (let ((angle (wl.rotate-normalize-angle
                 (+ (+ (- (+ (wl.player@ wl.PLAYER-ANGLE)
                             (/ (- wl.centerx (wl.actor-viewx@ actor)) 8)) 180)
                       (- 0 (wl.actor-rotation-bearing actor)))
                    22))))
    (if (= (wl.actor-state-rotate actor) 2)
        (* 4 (/ angle 180))
        (/ angle 45))))

(defn wl.rotate-normalize-angle (angle)
  (if (< angle 0)
      (wl.rotate-normalize-angle (+ angle wl.ANGLES))
      (if (>= angle wl.ANGLES)
          (wl.rotate-normalize-angle (- angle wl.ANGLES))
          angle)))

(defn wl.calc-rotate-angle (angle)
  (/ (wl.rotate-normalize-angle angle) 45))

(defn wl.visible-insert (sprite visible)
  (if (nil? visible)
      (list sprite)
      (if (< (car sprite) (car (car visible)))
          (cons sprite visible)
          (cons (car visible) (wl.visible-insert sprite (cdr visible))))))

(defn wl.collect-visible-statics (index visible count)
  (if (or (= index wl.staticcount) (= count 49))
      (list visible count)
      (if (or (= (wl.static-shapenum@ index) -1)
              (not (wl.static-spot-visible? index)))
          (wl.collect-visible-statics (+ index 1) visible count)
          (let ((projection (wl.transform-tile (u8@ wl.staticx index)
                                               (u8@ wl.staticy index))))
            (if (<= (car (cdr projection)) 0)
                (wl.collect-visible-statics (+ index 1) visible count)
                (wl.collect-visible-statics
                  (+ index 1)
                  (wl.visible-insert
                    (list (car (cdr projection)) (car projection)
                          (wl.static-shapenum@ index)) visible)
                  (+ count 1)))))))

(defn wl.actor-render-shape (actor)
  (let ((shape (wl.actor-shapenum actor))
        (rotate (wl.actor-state-rotate actor)))
    (if (= rotate 0)
        shape
        ;; The compact projectile animator retains temp1 for smoke cadence;
        ;; s_rocket itself is SPR_ROCKET_1 and receives only CalcRotate here.
        (+ (if (and (= (wl.actor-class@ actor) wl.ROCKETOBJ)
                    (= (wl.actor-phase@ actor) wl.ACTOR-PROJECTILE))
               (- shape (mod (wl.actor-temp1@ actor) 8))
               shape)
           (wl.calc-rotate actor)))))

(defn wl.collect-visible-actors (actor visible count)
  (if (or (= actor wl.actorcount) (= count 49))
      visible
      (if (or (= (wl.actor-viewheight@ actor) 0)
              (= (bit.and (wl.actor-flags@ actor) wl.FL-VISABLE) 0))
          (wl.collect-visible-actors (+ actor 1) visible count)
          (wl.collect-visible-actors
            (+ actor 1)
            (wl.visible-insert
              (list (wl.actor-viewheight@ actor) (wl.actor-viewx@ actor)
                    (wl.actor-render-shape actor)) visible)
            (+ count 1)))))

(defn wl.draw-visible-list (frame visible)
  (if (nil? visible)
      frame
      (begin
        (wl.scale-shape frame (car (cdr (car visible)))
                        (car (cdr (cdr (car visible)))) (car (car visible)))
        (wl.draw-visible-list frame (cdr visible)))))

;;; DrawScaleds preserves the MAXVISABLE-1 cap and selects the smallest
;;; projected height first, which is the source's back-to-front selection sort.
(defn wl.draw-scaleds (frame)
  (let ((statics (wl.collect-visible-statics 0 nil 0)))
    (wl.draw-visible-list
      frame
      (wl.collect-visible-actors 0 (car statics) (car (cdr statics))))))
