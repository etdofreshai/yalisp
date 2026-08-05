
(define wl.focallength wl.FOCALLENGTH)
(define wl.facedist (+ wl.FOCALLENGTH wl.MINDIST))
(define wl.halfview (/ wl.viewwidth 2))
(define wl.scale (/ (* wl.halfview wl.facedist) (/ wl.VIEWGLOBAL 2)))
(define wl.heightnumerator (bit.shr (* wl.TILEGLOBAL wl.scale) 6))

(define wl.pixelangle (bytes.alloc 1280))     ;; int pixelangle[MAXVIEWWIDTH]
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
  (if (<= (fx.tan16 (* (+ a 1) fx.FINE)) tang)
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

(defn wl.wallheight@ (i) (i32@ wl.wallheight (* i 4)))
(defn wl.wallheight! (i v) (u32! wl.wallheight (* i 4) v))

(defn wl.walltexture@ (i) (u16@ wl.walltexture (* i 2)))
(defn wl.walltexture! (i v) (u16! wl.walltexture (* i 2) v))

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
      (wl.vert-loop (+ xtile (wl.view@ wl.XTILESTEP)) ytile
                    xintercept (+ yintercept (wl.view@ wl.YSTEP)))))

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
      (wl.horiz-loop xtile (+ ytile (wl.view@ wl.YTILESTEP))
                     (+ xintercept (wl.view@ wl.XSTEP)) yintercept)))

(defn wl.off-map? (tile intercept)
  (or (or (< tile 0) (>= tile wl.MAPSIZE))
      (or (< intercept 0) (>= intercept (* wl.MAPSIZE wl.TILEGLOBAL)))))

(defn wl.no-hit ()
  (begin
    (wl.wallheight! (wl.view@ wl.PIXX) 0)
    (wl.walltexture! (wl.view@ wl.PIXX) 0)
    (u8! wl.wallpic (wl.view@ wl.PIXX) 255)))

(defn wl.trace-vert-door (xtile ytile xintercept yintercept tilehit)
  (wl.trace-vert-door-at xtile ytile xintercept yintercept tilehit
                         (+ yintercept (/ (wl.view@ wl.YSTEP) 2))))

(defn wl.trace-vert-door-at (xtile ytile xintercept yintercept tilehit doorintercept)
  (if (or (not (= (bit.shr doorintercept wl.TILESHIFT) (bit.shr yintercept wl.TILESHIFT)))
          (< (bit.and doorintercept 65535) (wl.door-position@ (wl.door-number tilehit))))
      (wl.vert-loop (+ xtile (wl.view@ wl.XTILESTEP)) ytile
                    xintercept (+ yintercept (wl.view@ wl.YSTEP)))
      (wl.hit-vert-door xtile doorintercept (wl.door-number tilehit))))

(defn wl.trace-horiz-door (xtile ytile xintercept yintercept tilehit)
  (wl.trace-horiz-door-at xtile ytile xintercept yintercept tilehit
                          (+ xintercept (/ (wl.view@ wl.XSTEP) 2))))

(defn wl.trace-horiz-door-at (xtile ytile xintercept yintercept tilehit doorintercept)
  (if (or (not (= (bit.shr doorintercept wl.TILESHIFT) (bit.shr xintercept wl.TILESHIFT)))
          (< (bit.and doorintercept 65535) (wl.door-position@ (wl.door-number tilehit))))
      (wl.horiz-loop xtile (+ ytile (wl.view@ wl.YTILESTEP))
                     (+ xintercept (wl.view@ wl.XSTEP)) yintercept)
      (wl.hit-horiz-door ytile doorintercept (wl.door-number tilehit))))

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
(define wl.TEXTUREHIGH 4032)                  ;; 0xfc0

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

(define wl.textured 0)

(defn wl.set-textured (on) (set! wl.textured on))

(defn wl.textured? () (= wl.textured 1))

(define wl.CEILING 1)
(define wl.FLOOR 2)
(define wl.WALL-FIRST 3)
(define wl.WALL-SHADES 8)
(define wl.STATUS 11)

(define wl.VGACEILING 29)                     ;; vgaCeiling[0], 0x1d
(define wl.VGAFLOOR 25)                       ;; 0x19
(define wl.VGASTATUS 0)
(define wl.VGANOPIC 0)

(defn wl.post-colour (pic)
  (+ wl.WALL-FIRST (mod pic wl.WALL-SHADES)))

(define wl.MAXSCALE 239)                      ;; SetupScaling (viewwidth*1.5)
(define wl.STEPBYTWO 80)                      ;; viewheight/2

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
      (bytes.fill-stride frame (+ (* top wl.SCREENWIDTH) postx)
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
  (bytes.fill-stride frame (+ (* top wl.SCREENWIDTH) postx)
                     (+ (- bottom top) 1) wl.SCREENWIDTH
                     colour))

(defn wl.clear-screen (frame)
  (if (wl.textured?)
      (wl.clear-screen-with frame wl.VGACEILING wl.VGAFLOOR wl.VGASTATUS)
      (wl.clear-screen-with frame wl.CEILING wl.FLOOR wl.STATUS)))

(defn wl.clear-screen-with (frame ceiling floor status)
  (begin
    (bytes.fill frame 0 (* (/ wl.viewheight 2) wl.SCREENWIDTH) ceiling)
    (bytes.fill frame (* (/ wl.viewheight 2) wl.SCREENWIDTH)
                (* (/ wl.viewheight 2) wl.SCREENWIDTH) floor)
    (bytes.fill frame (* wl.viewheight wl.SCREENWIDTH)
                (* wl.STATUSLINES wl.SCREENWIDTH) status)))

(defn wl.three-d-refresh (frame)
  (begin
    (wl.clear-screen frame)
    (wl.calc-view)
    (wl.asm-refresh)
    (wl.scale-walls frame 0)
    frame))

(defn wl.scale-walls (frame postx)
  (if (= postx wl.viewwidth)
      frame
      (begin (wl.scale-wall frame postx (heap.used)) (wl.scale-walls frame (+ postx 1)))))

(defn wl.scale-wall (frame postx mark)
  (begin (wl.scale-post frame postx) (heap.release mark)))
