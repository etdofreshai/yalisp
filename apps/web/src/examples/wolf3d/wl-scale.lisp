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

(define wl.SPR-PISTOLREADY 421)

(defn wl.draw-r1-ready-pistol (frame)
  (if (and (= wl.weapon wl.WP-PISTOL) (= wl.weaponframe 0))
      (wl.simple-scale-shape frame (/ wl.viewwidth 2)
                             wl.SPR-PISTOLREADY (+ wl.viewheight 1))
      frame))

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
