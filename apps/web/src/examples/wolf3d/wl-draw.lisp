
(define wl.focallength wl.FOCALLENGTH)
(define wl.facedist (+ wl.FOCALLENGTH wl.MINDIST))
(define wl.halfview (/ wl.viewwidth 2))
(define wl.centerx (- wl.halfview 1))
(define wl.shootdelta (/ wl.viewwidth 10))
(define wl.scale (/ (* wl.halfview wl.facedist) (/ wl.VIEWGLOBAL 2)))
(define wl.heightnumerator (bit.shr (* wl.TILEGLOBAL wl.scale) 6))

(define wl.pixelangle (bytes.alloc 1280))
(defn wl.pixelangle@ (i) (i32@ wl.pixelangle (* i 4)))
(defn wl.pixelangle! (i v) (u32! wl.pixelangle (* i 4) v))

(defn wl.calc-projection () (wl.pixelangle-loop 0 0))

(defn wl.pixelangle-loop (i a)
  (if (= i wl.halfview)
      i
      (wl.pixelangle-at
        i
        (wl.advance-fine a (fx.div16 (/ (* i wl.VIEWGLOBAL) wl.viewwidth) wl.facedist)))))

(defn wl.advance-fine (a tang)
  (if (< (fx.tan16 (* (+ a 1) fx.FINE)) tang)
      (wl.advance-fine (+ a 1) tang)
      a))

(defn wl.pixelangle-at (i a)
  (begin
    (wl.pixelangle! (- (- wl.halfview 1) i) a)
    (wl.pixelangle! (+ wl.halfview i) (- 0 a))
    (wl.pixelangle-loop (+ i 1) a)))

(define wl.view (bytes.alloc 80))
(define wl.VIEWX 0)
(define wl.VIEWY 4)
(define wl.VIEWANGLE 8)
(define wl.VIEWSIN 12)
(define wl.VIEWCOS 16)
(define wl.MIDANGLE 20)
(define wl.FOCALTX 24)
(define wl.FOCALTY 28)
(define wl.XPARTIALUP 32)
(define wl.XPARTIALDOWN 36)
(define wl.YPARTIALUP 40)
(define wl.YPARTIALDOWN 44)
(define wl.XINTERCEPT 48)
(define wl.YINTERCEPT 52)
(define wl.XTILESTEP 56)
(define wl.YTILESTEP 60)
(define wl.XSTEP 64)
(define wl.YSTEP 68)
(define wl.PIXX 72)

(defn wl.view@ (field) (i32@ wl.view field))
(defn wl.view! (field v) (u32! wl.view field v))

(define wl.wallheight (bytes.alloc 1280))
(define wl.wallpic (bytes.alloc 320))
(define wl.walltexture (bytes.alloc 640))
(define wl.FIZZLE-FRAMES 20)
(define wl.fizzlein 0)
(define wl.fizzle-target nil)
(define wl.fizzle-state nil)

(defn wl.wallheight@ (i) (i32@ wl.wallheight (* i 4)))
(defn wl.wallheight! (i v) (u32! wl.wallheight (* i 4) v))

(defn wl.walltexture@ (i) (u16@ wl.walltexture (* i 2)))
(defn wl.walltexture! (i v) (u16! wl.walltexture (* i 2) v))

;;; NewViewSize changes the projection and the centered play window together.
;;; The DOS renderer stores byte offsets into planar VGA pages; this port keeps
;;; the equivalent row-major byte offset into the native 320x200 indexed page.
(defn wl.new-view-size (width height)
  (let ((view-width (bit.and width -16))
        (view-height (bit.and height -2)))
    (if (and (>= view-width 64) (and (<= view-width wl.SCREENWIDTH)
            (and (>= view-height 40)
                 (<= view-height (- wl.SCREENHEIGHT wl.STATUSLINES)))))
        (begin
          (set! wl.viewwidth view-width)
          (set! wl.viewheight view-height)
          (set! wl.viewleft (/ (- wl.SCREENWIDTH view-width) 2))
          (set! wl.viewtop (/ (- (- wl.SCREENHEIGHT wl.STATUSLINES) view-height) 2))
          (set! wl.viewofs (+ wl.viewleft (* wl.viewtop wl.SCREENWIDTH)))
          (set! wl.halfview (/ view-width 2))
          (set! wl.centerx (- wl.halfview 1))
          (set! wl.shootdelta (/ view-width 10))
          (set! wl.scale (/ (* wl.halfview wl.facedist) (/ wl.VIEWGLOBAL 2)))
          (set! wl.heightnumerator (bit.shr (* wl.TILEGLOBAL wl.scale) 6))
          (wl.calc-projection)
          true)
        false)))

;;; CP_ChangeView uses source units 4..19. The full-screen case is 19; the
;;; remaining choices preserve the original 16-pixel width / 8-pixel height
;;; progression and centered viewport.
(defn wl.new-view-size-units (view)
  (if (or (< view 4) (> view 19))
      false
      (if (= view 19)
          (wl.new-view-size 320 160)
          (wl.new-view-size (* view 16) (* view 8)))))

(defn wl.calc-view ()
  (wl.calc-view-at (wl.player@ wl.PLAYER-ANGLE)))

(defn wl.calc-view-at (viewangle)
  (begin
    (wl.view! wl.VIEWANGLE viewangle)
    (wl.view! wl.MIDANGLE (* viewangle (/ wl.FINEANGLES wl.ANGLES)))
    (wl.view! wl.VIEWSIN (wl.sintable@ viewangle))
    (wl.view! wl.VIEWCOS (wl.costable@ viewangle))
    (wl.view! wl.VIEWX (- (wl.player@ wl.PLAYER-X)
                          (fx.by-frac wl.focallength (wl.view@ wl.VIEWCOS))))
    (wl.view! wl.VIEWY (+ (wl.player@ wl.PLAYER-Y)
                          (fx.by-frac wl.focallength (wl.view@ wl.VIEWSIN))))
    (wl.view! wl.FOCALTX (bit.shr (wl.view@ wl.VIEWX) wl.TILESHIFT))
    (wl.view! wl.FOCALTY (bit.shr (wl.view@ wl.VIEWY) wl.TILESHIFT))
    (wl.view! wl.XPARTIALDOWN (bit.and (wl.view@ wl.VIEWX) (- wl.TILEGLOBAL 1)))
    (wl.view! wl.XPARTIALUP (- wl.TILEGLOBAL (wl.view@ wl.XPARTIALDOWN)))
    (wl.view! wl.YPARTIALDOWN (bit.and (wl.view@ wl.VIEWY) (- wl.TILEGLOBAL 1)))
    (wl.view! wl.YPARTIALUP (- wl.TILEGLOBAL (wl.view@ wl.YPARTIALDOWN)))))

(defn wl.asm-refresh () (wl.cast-columns 0))

(defn wl.cast-columns (pixx)
  (if (= pixx wl.viewwidth)
      pixx
      (begin
        (wl.cast-column pixx (heap.used))
        (wl.cast-columns (+ pixx 1)))))

(defn wl.cast-column (pixx mark)
  (begin
    (wl.view! wl.PIXX pixx)
    (wl.cast-ray pixx (wl.column-angle (+ (wl.view@ wl.MIDANGLE) (wl.pixelangle@ pixx))))
    (heap.release mark)))

(defn wl.column-angle (angl)
  (if (< angl 0)
      (+ angl wl.FINEANGLES)
      (if (>= angl wl.ANG360) (- angl wl.FINEANGLES) angl)))

(defn wl.cast-ray (pixx angl)
  (cond ((< angl wl.ANG90)
         (wl.cast-setup 1 -1 (wl.finetangent@ (- 899 angl))
                             (- 0 (wl.finetangent@ angl))
                             (wl.view@ wl.XPARTIALUP) (wl.view@ wl.YPARTIALDOWN)))
        ((< angl wl.ANG180)
         (wl.cast-setup -1 -1 (- 0 (wl.finetangent@ (- angl 900)))
                              (- 0 (wl.finetangent@ (- 1799 angl)))
                              (wl.view@ wl.XPARTIALDOWN) (wl.view@ wl.YPARTIALDOWN)))
        ((< angl wl.ANG270)
         (wl.cast-setup -1 1 (- 0 (wl.finetangent@ (- 2699 angl)))
                             (wl.finetangent@ (- angl 1800))
                             (wl.view@ wl.XPARTIALDOWN) (wl.view@ wl.YPARTIALUP)))
        (true
         (wl.cast-setup 1 1 (wl.finetangent@ (- angl 2700))
                            (wl.finetangent@ (- 3599 angl))
                            (wl.view@ wl.XPARTIALUP) (wl.view@ wl.YPARTIALUP)))))

(defn wl.cast-setup (xtilestep ytilestep xstep ystep xpartial ypartial)
  (begin
    (wl.view! wl.XTILESTEP xtilestep)
    (wl.view! wl.YTILESTEP ytilestep)
    (wl.view! wl.XSTEP xstep)
    (wl.view! wl.YSTEP ystep)
    (wl.vert-loop (+ (wl.view@ wl.FOCALTX) xtilestep)
                  (+ (wl.view@ wl.FOCALTY) ytilestep)
                  (+ (fx.by-frac xstep ypartial) (wl.view@ wl.VIEWX))
                  (+ (fx.by-frac ystep xpartial) (wl.view@ wl.VIEWY)))))

(defn wl.vert-loop (xtile ytile xintercept yintercept)
  (if (if (= (wl.view@ wl.YTILESTEP) -1)
          (<= (bit.shr yintercept 16) ytile)
          (>= (bit.shr yintercept 16) ytile))
      (wl.horiz-entry xtile ytile xintercept yintercept)
      (wl.vert-entry xtile ytile xintercept yintercept)))

(defn wl.horiz-loop (xtile ytile xintercept yintercept)
  (if (if (= (wl.view@ wl.XTILESTEP) -1)
          (<= (bit.shr xintercept 16) xtile)
          (>= (bit.shr xintercept 16) xtile))
      (wl.vert-entry xtile ytile xintercept yintercept)
      (wl.horiz-entry xtile ytile xintercept yintercept)))

(defn wl.vert-entry (xtile ytile xintercept yintercept)
  (if (wl.off-map? xtile yintercept)
      (wl.no-hit)
      (wl.vert-hit xtile ytile xintercept yintercept
                   (u8@ wl.tilemap (+ (bit.shl xtile wl.MAPSHIFT) (bit.shr yintercept 16))))))

(defn wl.vert-hit (xtile ytile xintercept yintercept tilehit)
  (if (> tilehit 0)
      (if (wl.door-tile? tilehit)
          (wl.trace-vert-door xtile ytile xintercept yintercept tilehit)
          (wl.hit-vert-wall xtile (bit.shl xtile wl.TILESHIFT) yintercept tilehit))
      (begin (wl.spotvis-vert! xtile yintercept)
        (wl.vert-loop (+ xtile (wl.view@ wl.XTILESTEP)) ytile
                      xintercept (+ yintercept (wl.view@ wl.YSTEP))))))

(defn wl.horiz-entry (xtile ytile xintercept yintercept)
  (if (wl.off-map? ytile xintercept)
      (wl.no-hit)
      (wl.horiz-hit xtile ytile xintercept yintercept
                    (u8@ wl.tilemap (+ (bit.shl (bit.shr xintercept 16) wl.MAPSHIFT) ytile)))))

(defn wl.horiz-hit (xtile ytile xintercept yintercept tilehit)
  (if (> tilehit 0)
      (if (wl.door-tile? tilehit)
          (wl.trace-horiz-door xtile ytile xintercept yintercept tilehit)
          (wl.hit-horiz-wall ytile xintercept (bit.shl ytile wl.TILESHIFT) tilehit))
      (begin (wl.spotvis-horiz! ytile xintercept)
        (wl.horiz-loop xtile (+ ytile (wl.view@ wl.YTILESTEP))
                       (+ xintercept (wl.view@ wl.XSTEP)) yintercept))))

(defn wl.off-map? (tile intercept)
  (or (or (< tile 0) (>= tile wl.MAPSIZE))
      (or (< intercept 0) (>= intercept (* wl.MAPSIZE wl.TILEGLOBAL)))))

(defn wl.no-hit ()
  (begin
    (wl.wallheight! (wl.view@ wl.PIXX) 0)
    (wl.walltexture! (wl.view@ wl.PIXX) 0)
    (u8! wl.wallpic (wl.view@ wl.PIXX) 255)))

(defn wl.pwall-intercept (intercept step)
  (+ intercept (bit.shr (* step wl.pwallpos) 6)))

(defn wl.pwall-plane (tile step)
  (+ (bit.shl tile 16)
     (if (= step -1) (- 0 (bit.shl wl.pwallpos 10)) (bit.shl wl.pwallpos 10))))

(defn wl.trace-vert-door (xtile ytile xi yi tile)
  (if (> (bit.and tile 64) 0) (wl.trace-vert-pwall xtile ytile xi yi tile)
      (wl.trace-vert-door-at xtile ytile xi yi tile (+ yi (/ (wl.view@ wl.YSTEP) 2)))))

(defn wl.trace-vert-pwall (xtile ytile xi yi tile)
  (let ((mid (wl.pwall-intercept yi (wl.view@ wl.YSTEP))))
    (if (not (= (bit.shr mid 16) (bit.shr yi 16)))
        (begin (wl.spotvis-vert! xtile yi)
          (wl.vert-loop (+ xtile (wl.view@ wl.XTILESTEP)) ytile xi
                        (+ yi (wl.view@ wl.YSTEP))))
        (wl.hit-vert-wall xtile (wl.pwall-plane xtile (wl.view@ wl.XTILESTEP))
                          mid (bit.and tile 63)))))

(defn wl.trace-vert-door-at (xtile ytile xi yi tile mid)
  (if (or (not (= (bit.shr mid 16) (bit.shr yi 16)))
          (< (bit.and mid 65535) (wl.door-position@ (wl.door-number tile))))
      (begin (wl.spotvis-vert! xtile yi)
        (wl.vert-loop (+ xtile (wl.view@ wl.XTILESTEP)) ytile xi
                      (+ yi (wl.view@ wl.YSTEP))))
      (wl.hit-vert-door xtile mid (wl.door-number tile))))

(defn wl.trace-horiz-door (xtile ytile xi yi tile)
  (if (> (bit.and tile 64) 0) (wl.trace-horiz-pwall xtile ytile xi yi tile)
      (wl.trace-horiz-door-at xtile ytile xi yi tile (+ xi (/ (wl.view@ wl.XSTEP) 2)))))

(defn wl.trace-horiz-pwall (xtile ytile xi yi tile)
  (let ((mid (wl.pwall-intercept xi (wl.view@ wl.XSTEP))))
    (if (not (= (bit.shr mid 16) (bit.shr xi 16)))
        (begin (wl.spotvis-horiz! ytile xi)
          (wl.horiz-loop xtile (+ ytile (wl.view@ wl.YTILESTEP))
                         (+ xi (wl.view@ wl.XSTEP)) yi))
        (wl.hit-horiz-wall ytile mid (wl.pwall-plane ytile (wl.view@ wl.YTILESTEP))
                           (bit.and tile 63)))))

(defn wl.trace-horiz-door-at (xtile ytile xi yi tile mid)
  (if (or (not (= (bit.shr mid 16) (bit.shr xi 16)))
          (< (bit.and mid 65535) (wl.door-position@ (wl.door-number tile))))
      (begin (wl.spotvis-horiz! ytile xi)
        (wl.horiz-loop xtile (+ ytile (wl.view@ wl.YTILESTEP))
                       (+ xi (wl.view@ wl.XSTEP)) yi))
      (wl.hit-horiz-door ytile mid (wl.door-number tile))))

(defn wl.door-picture (door side)
  (+ side
     (+ (wl.door-wall)
        (cond ((= (wl.door-lock@ door) 0) 0)
              ((= (wl.door-lock@ door) 5) 4)
              (true 6)))))

(defn wl.hit-vert-door (xtile yintercept door)
  (wl.record-picture-post (wl.door-picture door 1)
                          (+ (bit.shl xtile wl.TILESHIFT) (/ wl.TILEGLOBAL 2))
                          yintercept
                          (wl.texture-column (- yintercept (wl.door-position@ door)))))

(defn wl.hit-horiz-door (ytile xintercept door)
  (wl.record-picture-post (wl.door-picture door 0)
                          xintercept
                          (+ (bit.shl ytile wl.TILESHIFT) (/ wl.TILEGLOBAL 2))
                          (wl.texture-column (- xintercept (wl.door-position@ door)))))

(define wl.TEXTUREHEIGHT 64)
(define wl.TEXTUREHIGH 4032)

(defn wl.door-wall () (- pm.sprite-start 8))

(defn wl.texture-column (intercept)
  (bit.and (bit.shr intercept 4) wl.TEXTUREHIGH))

(defn wl.hit-vert-wall (xtile xintercept yintercept tilehit)
  (wl.record-picture-post (wl.vert-wall-picture xtile yintercept tilehit)
                  (if (= (wl.view@ wl.XTILESTEP) -1) (+ xintercept wl.TILEGLOBAL) xintercept)
                  yintercept
                  (if (= (wl.view@ wl.XTILESTEP) -1)
                      (- wl.TEXTUREHIGH (wl.texture-column yintercept))
                      (wl.texture-column yintercept))))

(defn wl.hit-horiz-wall (ytile xintercept yintercept tilehit)
  (wl.record-picture-post (wl.horiz-wall-picture ytile xintercept tilehit)
                  xintercept
                  (if (= (wl.view@ wl.YTILESTEP) -1) (+ yintercept wl.TILEGLOBAL) yintercept)
                  (if (= (wl.view@ wl.YTILESTEP) -1)
                      (wl.texture-column xintercept)
                      (- wl.TEXTUREHIGH (wl.texture-column xintercept)))))

(defn wl.vert-wall-picture (xtile yintercept tilehit)
  (if (> (bit.and tilehit wl.DOOR-SIDE) 0)
      (if (wl.door-tile? (wl.tilemap@ (- xtile (wl.view@ wl.XTILESTEP))
                                      (bit.shr yintercept wl.TILESHIFT)))
          (+ (wl.door-wall) 3)
          (+ (* (- (bit.and tilehit 63) 1) 2) 1))
      (+ (* (- tilehit 1) 2) 1)))

(defn wl.horiz-wall-picture (ytile xintercept tilehit)
  (if (> (bit.and tilehit wl.DOOR-SIDE) 0)
      (if (wl.door-tile? (wl.tilemap@ (bit.shr xintercept wl.TILESHIFT)
                                      (- ytile (wl.view@ wl.YTILESTEP))))
          (+ (wl.door-wall) 2)
          (* (- (bit.and tilehit 63) 1) 2))
      (* (- tilehit 1) 2)))

(defn wl.record-picture-post (picture xintercept yintercept texture)
  (begin
    (wl.view! wl.XINTERCEPT xintercept)
    (wl.view! wl.YINTERCEPT yintercept)
    (wl.wallheight! (wl.view@ wl.PIXX) (wl.calc-height))
    (wl.walltexture! (wl.view@ wl.PIXX) texture)
    (u8! wl.wallpic (wl.view@ wl.PIXX) picture)))

(defn wl.calc-height ()
  (wl.calc-height-z (- (fx.by-frac (- (wl.view@ wl.XINTERCEPT) (wl.view@ wl.VIEWX))
                                   (wl.view@ wl.VIEWCOS))
                       (fx.by-frac (- (wl.view@ wl.YINTERCEPT) (wl.view@ wl.VIEWY))
                                   (wl.view@ wl.VIEWSIN)))))

(defn wl.calc-height-z (z)
  (/ wl.heightnumerator (bit.shr (if (< z wl.MINDIST) wl.MINDIST z) 8)))

;;; TransformTile is the static-object counterpart of TransformActor. Its
;;; 0x2000 focal adjustment and asymmetric pickup box are intentional source
;;; behavior and are observable before DrawScaleds chooses a sprite.
(defn wl.transform-tile (tilex tiley)
  (let ((gx (- (+ (bit.shl tilex wl.TILESHIFT) (/ wl.TILEGLOBAL 2))
               (wl.view@ wl.VIEWX)))
        (gy (- (+ (bit.shl tiley wl.TILESHIFT) (/ wl.TILEGLOBAL 2))
               (wl.view@ wl.VIEWY))))
    (let ((nx (- (- (fx.by-frac gx (wl.view@ wl.VIEWCOS))
                       (fx.by-frac gy (wl.view@ wl.VIEWSIN))) 8192))
          (ny (+ (fx.by-frac gy (wl.view@ wl.VIEWCOS))
                 (fx.by-frac gx (wl.view@ wl.VIEWSIN)))))
      (if (< nx wl.MINDIST)
          '(0 0 false)
          (list (+ wl.centerx (/ (* ny wl.scale) nx))
                (/ wl.heightnumerator (bit.shr nx 8))
                (and (< nx wl.TILEGLOBAL)
                     (and (> ny (- 0 (/ wl.TILEGLOBAL 2)))
                          (< ny (/ wl.TILEGLOBAL 2)))))))))

(defn wl.static-spot-visible? (index)
  (> (u8@ wl.spotvis (+ (bit.shl (u8@ wl.staticx index) wl.MAPSHIFT)
                         (u8@ wl.staticy index))) 0))

(define wl.textured 0)

(defn wl.set-textured (on) (set! wl.textured on))

(defn wl.textured? () (= wl.textured 1))

(define wl.CEILING 1)
(define wl.FLOOR 2)
(define wl.WALL-FIRST 3)
(define wl.WALL-SHADES 8)
(define wl.STATUS 11)

(define wl.VGAFLOOR 25)
(define wl.VGASTATUS 0)
(define wl.VGANOPIC 0)

;;; VGAClearScreen indexes the non-SPEAR compile-time table with
;;; gamestate.episode*10+mapon. The repeated source words hold one VGA palette
;;; byte twice for stosw, so the indexed framebuffer retains their low bytes.
(define wl.vga-ceiling-wl6 (bytes.alloc 60))

(defn wl.load-vga-ceiling-wl6 (values index)
  (if (= index 60)
      index
      (begin
        (u8! wl.vga-ceiling-wl6 index (car values))
        (wl.load-vga-ceiling-wl6 (cdr values) (+ index 1)))))

(wl.load-vga-ceiling-wl6
  '(29 29 29 29 29 29 29 29 29 191
    78 78 78 29 141 78 29 45 29 141
    29 29 29 29 29 45 221 29 29 152
    29 157 45 221 221 157 45 77 29 221
    125 29 45 45 221 215 29 29 29 45
    29 29 29 29 221 221 125 221 221 221)
  0)

;;; The original demo byte may carry a global WL6 map ordinal while episode is
;;; zero. Normal campaign state uses episode 0..5 and map 0..9. Any address
;;; outside the 60-entry WL6 table traps through its exact upper bound; Spear's
;;; separate 21-entry compile-time table is intentionally unavailable here.
(defn wl.vga-ceiling-index-wl6 (episode map)
  (if (> map 9)
      (if (= episode 0) map 60)
      (if (and (>= episode 0) (and (< episode 6) (>= map 0)))
          (+ (* episode 10) map)
          60)))

(defn wl.vga-ceiling-color-for (variant episode map)
  (if (eq? variant 'wolf3d)
      (u8@ wl.vga-ceiling-wl6 (wl.vga-ceiling-index-wl6 episode map))
      (u8@ wl.vga-ceiling-wl6 60)))

(defn wl.vga-ceiling-color ()
  (wl.vga-ceiling-color-for 'wolf3d wl.episode wl.map))

(defn wl.post-colour (pic)
  (+ wl.WALL-FIRST (mod pic wl.WALL-SHADES)))

(define wl.MAXSCALE 179)
(define wl.STEPBYTWO 60)

(defn wl.scaler-height (h)
  (wl.scaler-stepped (if (> h wl.MAXSCALE) wl.MAXSCALE h)))

(defn wl.scaler-stepped (h)
  (if (< h wl.STEPBYTWO)
      h
      (+ wl.STEPBYTWO (* 3 (/ (- h wl.STEPBYTWO) 3)))))

(defn wl.scale-post (frame postx)
  (if (= (u8@ wl.wallpic postx) 255)
      nil
      (wl.scale-post-pic frame postx (u8@ wl.wallpic postx))))

(defn wl.scale-post-pic (frame postx pic)
  (if (wl.textured?)
      (if (pm.wall-page? pic)
          (wl.scale-post-texture frame postx (+ (pm.get-page pic) (wl.walltexture@ postx))
                                 (wl.scaler-height (bit.shr (wl.wallheight@ postx) 3)))
          (wl.scale-post-flat frame postx wl.VGANOPIC))
      (wl.scale-post-flat frame postx (wl.post-colour pic))))

(defn wl.scale-post-texture (frame postx source h)
  (if (<= h 0)
      nil
      (wl.compiled-scale frame postx source (* h 2))))

(defn wl.compiled-scale (frame postx source height)
  (wl.scale-texel frame postx source
                  (/ (bit.shl height 16) wl.TEXTUREHEIGHT)
                  (/ (- wl.viewheight height) 2)
                  0))

(defn wl.scale-texel (frame postx source step toppix src)
  (if (= src wl.TEXTUREHEIGHT)
      nil
      (begin
        (wl.scale-run frame postx source src
                      (+ toppix (bit.shr (* src step) 16))
                      (+ toppix (bit.shr (* (+ src 1) step) 16)))
        (wl.scale-texel frame postx source step toppix (+ src 1)))))

(defn wl.scale-run (frame postx source src startpix endpix)
  (wl.scale-run-span frame postx source src
                     (if (< startpix 0) 0 startpix)
                     (if (> endpix wl.viewheight) wl.viewheight endpix)))

(defn wl.scale-run-span (frame postx source src top bottom)
  (if (>= top bottom)
      nil
      (bytes.fill-stride frame (+ wl.viewofs (+ (* top wl.SCREENWIDTH) postx))
                         (- bottom top) wl.SCREENWIDTH
                         (pm.texel source src))))

(defn wl.scale-post-flat (frame postx colour)
  (wl.scale-post-flat-height frame postx colour (bit.shr (wl.wallheight@ postx) 3)))

(defn wl.scale-post-flat-height (frame postx colour height)
  (if (<= height 0)
      nil
      (wl.scale-post-span frame postx colour
                          (wl.clamp-row (- (/ wl.viewheight 2) height))
                          (wl.clamp-row (- (+ (/ wl.viewheight 2) height) 1)))))

(defn wl.clamp-row (row)
  (if (< row 0) 0 (if (> row (- wl.viewheight 1)) (- wl.viewheight 1) row)))

(defn wl.scale-post-span (frame postx colour top bottom)
  (bytes.fill-stride frame (+ wl.viewofs (+ (* top wl.SCREENWIDTH) postx))
                     (+ (- bottom top) 1) wl.SCREENWIDTH
                     colour))

(defn wl.clear-screen (frame)
  (if (wl.textured?)
      (wl.clear-screen-with frame (wl.vga-ceiling-color) wl.VGAFLOOR)
      (wl.clear-screen-with frame wl.CEILING wl.FLOOR)))

(defn wl.clear-screen-with (frame ceiling floor)
  (begin
    (bytes.fill frame 0 (* (- wl.SCREENHEIGHT wl.STATUSLINES) wl.SCREENWIDTH) 127)
    (wl.fill-view frame 0 (/ wl.viewheight 2) ceiling)
    (wl.fill-view frame (/ wl.viewheight 2) wl.viewheight floor)))

(defn wl.fill-view (frame row stop colour)
  (if (= row stop)
      frame
      (begin
        (bytes.fill frame (+ wl.viewofs (* row wl.SCREENWIDTH))
                    wl.viewwidth colour)
        (wl.fill-view frame (+ row 1) stop colour))))

(defn wl.draw-play-border (frame)
  (if (and (= wl.viewwidth wl.SCREENWIDTH)
           (= wl.viewheight (- wl.SCREENHEIGHT wl.STATUSLINES)))
      frame
      (let ((left (- wl.viewleft 1)) (top (- wl.viewtop 1))
            (right (+ wl.viewleft wl.viewwidth))
            (bottom (+ wl.viewtop wl.viewheight)))
        (begin
          (bytes.fill frame (+ (* top wl.SCREENWIDTH) left)
                      (+ (- right left) 1) 0)
          (bytes.fill frame (+ (* bottom wl.SCREENWIDTH) left)
                      (+ (- right left) 1) 125)
          (bytes.fill-stride frame (+ (* top wl.SCREENWIDTH) left)
                             (+ (- bottom top) 1) wl.SCREENWIDTH 0)
          (bytes.fill-stride frame (+ (* top wl.SCREENWIDTH) right)
                             (+ (- bottom top) 1) wl.SCREENWIDTH 125)
          (u8! frame (+ (* bottom wl.SCREENWIDTH) left) 124)))))

(defn wl.render-three-d (frame)
  (begin
    (wl.clear-screen frame)
    (wl.draw-play-border frame)
    (bytes.fill wl.spotvis 0 4096 0)
    (wl.calc-view)
    (wl.asm-refresh)
    (wl.scale-walls frame 0)
    (wl.refresh-actor-projection 0)
    (wl.draw-scaleds frame)
    (wl.draw-player-weapon frame)
    frame))

;;; ThreeDRefresh passes 20 and false to FizzleFade, clears fizzlein only after
;;; the LFSR cycle completes, then resets the DOS frame timer. The browser has
;;; one visible page and cannot block its event loop, so the newly rendered page
;;; is retained and one source FizzleFade outer frame is copied per refresh.
;;; Host scheduling owns the corresponding timer-baseline reset.
(defn wl.request-fizzle-in ()
  (begin
    ;; Allocate retained pages/state before app.render's transient heap mark.
    (wl.ensure-fizzle-target)
    (if (nil? wl.fizzle-state)
        (set! wl.fizzle-state
              (vh.fizzle-begin wl.viewwidth wl.viewheight wl.FIZZLE-FRAMES false))
        (vh.fizzle-reset wl.fizzle-state wl.viewwidth wl.viewheight
                         wl.FIZZLE-FRAMES false))
    (set! wl.fizzlein 1)
    true))

(defn wl.fizzle-running? () (vh.fizzle-running? wl.fizzle-state))

(defn wl.ensure-fizzle-target ()
  (if (nil? wl.fizzle-target)
      (set! wl.fizzle-target (bytes.alloc (* wl.SCREENWIDTH wl.SCREENHEIGHT)))
      wl.fizzle-target))

(defn wl.begin-render-fizzle (frame)
  (begin
    (wl.ensure-fizzle-target)
    (bytes.copy wl.fizzle-target 0 frame 0 (* wl.SCREENWIDTH wl.SCREENHEIGHT))
    (wl.render-three-d wl.fizzle-target)
    (vh.fizzle-reset wl.fizzle-state wl.viewwidth wl.viewheight
                     wl.FIZZLE-FRAMES false)
    (wl.fizzle-refresh-step frame false)))

(defn wl.fizzle-refresh-step (frame acknowledged)
  (let ((status
          (vh.fizzle-step wl.fizzle-target wl.viewofs
                          frame wl.viewofs wl.SCREENWIDTH
                          wl.fizzle-state acknowledged)))
    (begin
      (if (or (eq? status 'complete) (eq? status 'aborted))
          (set! wl.fizzlein 0) nil)
      frame)))

(defn wl.three-d-refresh (frame)
  (if (wl.fizzle-running?)
      (wl.fizzle-refresh-step frame false)
      (if (= wl.fizzlein 1)
          (wl.begin-render-fizzle frame)
          (wl.render-three-d frame))))

(defn wl.scale-walls (frame postx)
  (if (= postx wl.viewwidth)
      frame
      (begin (wl.scale-wall frame postx (heap.used)) (wl.scale-walls frame (+ postx 1)))))

(defn wl.scale-wall (frame postx mark)
  (begin (wl.scale-post frame postx) (heap.release mark)))
