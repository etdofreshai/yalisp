;;; ID_VH.C - original graphics-picture layout, ported to YALISP.
;;;
;;; STRUCTPIC is graphics chunk zero. It expands to one little-endian
;;; {width,height} word pair for each picture beginning at STARTPICS. Picture
;;; chunks expand in the four consecutive VGA planes consumed by
;;; VL_MemToScreen: plane p owns columns whose low two bits equal p.
;;;
;;; This slice exposes DrawPlayScreen's STATUSBARPIC and the original
;;; latch-picture operation used by the status window. It does not add number,
;;; key, weapon, menu, palette, or generalized screen-picture ownership.

(define vh.STRUCTPIC 0)
(define vh.STARTPICS 3)
(define vh.NUMPICS 132)
(define vh.STATUSBARPIC 86)
(define vh.STATUSBAR-WIDTH 320)
(define vh.STATUSBAR-HEIGHT 40)
(define vh.STATUSBAR-X 0)
(define vh.STATUSBAR-Y 160)
(define vh.LATCHPICS-START 91)
(define vh.LATCHPICS-END 134)
(define vh.STRUCTPIC-BYTES (* vh.NUMPICS 4))
(define vh.STATUSBAR-BYTES (* vh.STATUSBAR-WIDTH vh.STATUSBAR-HEIGHT))
(define vh.DRAW-BLOCK-PIXELS 64)
(define vh.FIZZLE-PIXELS 64000)
(define vh.FIZZLE-LFSR-XOR 73728)       ;; 0x00012000
(define vh.FIZZLE-BLOCK-PIXELS 64)
(define vh.FIZZLE-STATE-BYTES 24)
(define vh.FIZZLE-RND 0)
(define vh.FIZZLE-FRAME 4)
(define vh.FIZZLE-PIXELS-PER-FRAME 8)
(define vh.FIZZLE-WIDTH 12)
(define vh.FIZZLE-HEIGHT 14)
(define vh.FIZZLE-DONE 16)
(define vh.FIZZLE-ABORTED 17)
(define vh.FIZZLE-ABORTABLE 18)
(define vh.FIZZLE-REMAINING 20)

(defn vh.picture-entry (chunk)
  (* (- chunk vh.STARTPICS) 4))

(defn vh.picture-chunk? (chunk)
  (and (>= chunk vh.STARTPICS) (< chunk (+ vh.STARTPICS vh.NUMPICS))))

(defn vh.picture-width (structpic chunk)
  (if (vh.picture-chunk? chunk)
      (u16@ structpic (vh.picture-entry chunk))
      (ca.graphics-reject structpic)))

(defn vh.picture-height (structpic chunk)
  (if (vh.picture-chunk? chunk)
      (u16@ structpic (+ (vh.picture-entry chunk) 2))
      (ca.graphics-reject structpic)))

(defn vh.status-dimensions? (structpic)
  (and (= (bytes.length structpic) vh.STRUCTPIC-BYTES)
       (and (= (vh.picture-width structpic vh.STATUSBARPIC) vh.STATUSBAR-WIDTH)
            (= (vh.picture-height structpic vh.STATUSBARPIC) vh.STATUSBAR-HEIGHT))))

(defn vh.pictable? (structpic)
  (= (bytes.length structpic) vh.STRUCTPIC-BYTES))

(defn vh.load-pictable (head graph dictionary)
  (ca.expand-gr-chunk-exact head graph dictionary vh.STRUCTPIC vh.STRUCTPIC-BYTES))

(defn vh.latch-picture? (chunk)
  (and (>= chunk vh.LATCHPICS-START) (<= chunk vh.LATCHPICS-END)))

(defn vh.picture-bytes (width height)
  (if (and (> width 0) (and (> height 0) (= (mod width 4) 0)))
      (* width height)
      -1))

;;; Convert the exact plane order used by VL_MemToScreen into the row-major
;;; indexed surface owned by this port. `from` and `to` permit the placement
;;; check to exercise the same operation used at startup.
(defn vh.deplane-into (planar width height frame from to stride)
  (if (and (= (bytes.length planar) (* width height))
           (and (>= from 0)
                (and (<= (+ from (* width height)) (bytes.length planar))
                     (and (>= to 0)
                          (<= (+ to (* (- height 1) stride) width) (bytes.length frame))))))
      (vh.deplane-loop planar width height frame from to stride 0)
      (ca.graphics-reject planar)))

(defn vh.deplane-loop (planar width height frame from to stride index)
  (let ((state (bytes.alloc 4)))
    (begin
      (u32! state 0 index)
      (vh.deplane-blocks planar width height frame from to stride state))))

(defn vh.deplane-blocks (planar width height frame from to stride state)
  (if (= (u32@ state 0) (* width height))
      frame
      (vh.deplane-block-marked planar width height frame from to stride state
                                (heap.used))))

(defn vh.deplane-block-marked (planar width height frame from to stride state mark)
  (begin
    (vh.deplane-block planar width height frame from to stride state
                      vh.DRAW-BLOCK-PIXELS)
    (heap.release mark)
    (vh.deplane-blocks planar width height frame from to stride state)))

(defn vh.deplane-block (planar width height frame from to stride state count)
  (if (or (= count 0) (= (u32@ state 0) (* width height)))
      state
      (let ((index (u32@ state 0)))
        (begin
          (vh.deplane-pixel planar width height frame from to stride index)
          (u32! state 0 (+ index 1))
          (vh.deplane-block planar width height frame from to stride state (- count 1))))))

(defn vh.deplane-pixel (planar width height frame from to stride index)
  (let ((x (mod index width)) (y (/ index width))
        (plane-width (/ width 4)) (plane-size (/ (* width height) 4)))
    (u8! frame (+ to (+ (* y stride) x))
         (u8@ planar
              (+ from (+ (* (mod x 4) plane-size)
                         (+ (* y plane-width) (/ x 4))))))))

(defn vh.decode-statusbar (head graph dictionary)
  (let ((dest (bytes.alloc vh.STATUSBAR-BYTES)))
    (vh.decode-statusbar-into head graph dictionary dest 0 vh.STATUSBAR-WIDTH)))

;;; Both temporary chunks are after mark, while `frame` was allocated before
;;; it. This is the startup cache/draw/uncache shape: expansion storage is
;;; released after the pixels have reached the persistent screen.
(defn vh.decode-statusbar-into (head graph dictionary frame to stride)
  (vh.decode-statusbar-marked head graph dictionary frame to stride (heap.used)))

(defn vh.decode-statusbar-marked (head graph dictionary frame to stride mark)
  (let ((structpic (ca.expand-gr-chunk-exact
                     head graph dictionary vh.STRUCTPIC vh.STRUCTPIC-BYTES)))
    (if (vh.status-dimensions? structpic)
        (vh.decode-statusbar-planar head graph dictionary frame to stride mark)
        (ca.graphics-reject structpic))))

(defn vh.decode-statusbar-planar (head graph dictionary frame to stride mark)
  (let ((planar (ca.expand-gr-chunk-exact
                  head graph dictionary vh.STATUSBARPIC vh.STATUSBAR-BYTES)))
    (begin
      (vh.deplane-into planar vh.STATUSBAR-WIDTH vh.STATUSBAR-HEIGHT
                       frame 0 to stride)
      (heap.release mark)
      frame)))

(defn vh.draw-statusbar (head graph dictionary frame)
  (vh.decode-statusbar-into head graph dictionary frame
                            (+ vh.STATUSBAR-X (* vh.STATUSBAR-Y vh.STATUSBAR-WIDTH))
                            vh.STATUSBAR-WIDTH))

;;; StatusDrawPic sets the status-window page base, then LatchDrawPic converts
;;; its character-cell x coordinate to pixels with x*8. The browser has one
;;; persistent 320x200 page, so the same operation writes at (x*8,160+y).
;;; Dimensions still come from STRUCTPIC and the chunk's explicit expanded
;;; length must equal width*height before allocation.
(defn vh.status-draw-picture (head graph dictionary pictable frame x y chunk)
  (vh.status-draw-picture-marked head graph dictionary pictable frame x y chunk
                                 (heap.used)))

(defn vh.status-draw-picture-marked (head graph dictionary pictable frame x y chunk mark)
  (if (vh.pictable? pictable)
      (if (vh.latch-picture? chunk)
          (vh.status-draw-picture-sized head graph dictionary pictable frame x y chunk mark
                                        (vh.picture-width pictable chunk)
                                        (vh.picture-height pictable chunk))
          (ca.graphics-reject pictable))
      (ca.graphics-reject pictable)))

(defn vh.status-draw-picture-sized (head graph dictionary pictable frame x y chunk mark width height)
  (let ((expected (vh.picture-bytes width height))
        (left (* x 8)) (top (+ vh.STATUSBAR-Y y)))
    (if (and (> expected 0)
             (and (>= x 0) (and (>= y 0)
               (and (<= (+ left width) vh.STATUSBAR-WIDTH)
                    (<= (+ top height) (+ vh.STATUSBAR-Y vh.STATUSBAR-HEIGHT))))))
        (vh.status-draw-picture-planar head graph dictionary frame chunk mark
                                       expected width height left top)
        (ca.graphics-reject frame))))

(defn vh.status-draw-picture-planar (head graph dictionary frame chunk mark expected width height left top)
  (let ((planar (ca.expand-gr-chunk-exact head graph dictionary chunk expected)))
    (begin
      (vh.deplane-into planar width height frame 0
                       (+ left (* top vh.STATUSBAR-WIDTH)) vh.STATUSBAR-WIDTH)
      (heap.release mark)
      frame)))

;;; ID_VH.C's FizzleFade walks a maximal 17-bit LFSR beginning at one. The
;;; released source derives x/y before advancing the register, checks abort
;;; once per outer frame, advances even rejected coordinates, uses inclusive
;;; width/height comparisons, copies the pixel, and only then tests rndval==1.
;;; A browser must not busy-wait on TimeCount, so one fizzle-step is exactly one
;;; source outer-frame iteration; the host schedules the next call.
(defn vh.fizzle-next (rnd)
  (if (= (bit.and rnd 1) 0)
      (bit.shr rnd 1)
      (bit.xor (bit.shr rnd 1) vh.FIZZLE-LFSR-XOR)))

(defn vh.fizzle-x (rnd)
  (+ (bit.and (bit.shr rnd 8) 255)
     (bit.shl (bit.and (bit.shr rnd 16) 255) 8)))

(defn vh.fizzle-y (rnd) (bit.and (- (bit.and rnd 255) 1) 255))

(defn vh.fizzle-begin (width height frames abortable)
  (if (<= frames 0)
      (ca.graphics-reject (bytes.alloc 0))
      (let ((state (bytes.alloc vh.FIZZLE-STATE-BYTES)))
        (vh.fizzle-reset state width height frames abortable))))

(defn vh.fizzle-reset (state width height frames abortable)
  (if (<= frames 0)
      (ca.graphics-reject state)
      (begin
        (u32! state vh.FIZZLE-RND 1)
        (u32! state vh.FIZZLE-FRAME 0)
        (u32! state vh.FIZZLE-PIXELS-PER-FRAME (/ vh.FIZZLE-PIXELS frames))
        (u16! state vh.FIZZLE-WIDTH width)
        (u16! state vh.FIZZLE-HEIGHT height)
        (u8! state vh.FIZZLE-DONE 0)
        (u8! state vh.FIZZLE-ABORTED 0)
        (u8! state vh.FIZZLE-ABORTABLE (if abortable 1 0))
        (u32! state vh.FIZZLE-REMAINING 0)
        state)))

(defn vh.fizzle-status (state)
  (if (= (u8@ state vh.FIZZLE-ABORTED) 1)
      'aborted
      (if (= (u8@ state vh.FIZZLE-DONE) 1) 'complete 'running)))

(defn vh.fizzle-running? (state)
  (and (not (nil? state)) (eq? (vh.fizzle-status state) 'running)))

(defn vh.fizzle-step (source source-at dest dest-at stride state acknowledged)
  (vh.fizzle-step-marked source source-at dest dest-at stride state acknowledged
                          (heap.used)))

(defn vh.fizzle-step-marked (source source-at dest dest-at stride state acknowledged mark)
  (let ((status
          (vh.fizzle-step-run source source-at dest dest-at stride state acknowledged)))
    (begin (heap.release mark) status)))

(defn vh.fizzle-step-run (source source-at dest dest-at stride state acknowledged)
  (if (not (vh.fizzle-running? state))
      (vh.fizzle-status state)
      (if (and (= (u8@ state vh.FIZZLE-ABORTABLE) 1) acknowledged)
          (begin
            (u8! state vh.FIZZLE-ABORTED 1)
            (u8! state vh.FIZZLE-DONE 1)
            'aborted)
          (begin
            (u32! state vh.FIZZLE-REMAINING
                  (u32@ state vh.FIZZLE-PIXELS-PER-FRAME))
            (vh.fizzle-blocks source source-at dest dest-at stride state)
            (if (= (u8@ state vh.FIZZLE-DONE) 0)
                (u32! state vh.FIZZLE-FRAME
                      (+ (u32@ state vh.FIZZLE-FRAME) 1))
                nil)
            (vh.fizzle-status state)))))

(defn vh.fizzle-blocks (source source-at dest dest-at stride state)
  (if (or (= (u32@ state vh.FIZZLE-REMAINING) 0)
          (= (u8@ state vh.FIZZLE-DONE) 1))
      state
      (vh.fizzle-block-marked source source-at dest dest-at stride state
                               (heap.used))))

(defn vh.fizzle-block-marked (source source-at dest dest-at stride state mark)
  (begin
    (vh.fizzle-block source source-at dest dest-at stride state
                     vh.FIZZLE-BLOCK-PIXELS)
    (heap.release mark)
    (vh.fizzle-blocks source source-at dest dest-at stride state)))

(defn vh.fizzle-block (source source-at dest dest-at stride state count)
  (if (or (= count 0)
          (or (= (u32@ state vh.FIZZLE-REMAINING) 0)
              (= (u8@ state vh.FIZZLE-DONE) 1)))
      state
      (begin
        (vh.fizzle-pixel source source-at dest dest-at stride state)
        (vh.fizzle-block source source-at dest dest-at stride state (- count 1)))))

(defn vh.fizzle-pixel (source source-at dest dest-at stride state)
  (let ((rnd (u32@ state vh.FIZZLE-RND)))
    (let ((x (vh.fizzle-x rnd)) (y (vh.fizzle-y rnd))
          (next (vh.fizzle-next rnd)))
      (begin
        (u32! state vh.FIZZLE-RND next)
        (u32! state vh.FIZZLE-REMAINING
              (- (u32@ state vh.FIZZLE-REMAINING) 1))
        (if (and (<= x (u16@ state vh.FIZZLE-WIDTH))
                 (<= y (u16@ state vh.FIZZLE-HEIGHT)))
            (vh.fizzle-copy source (+ source-at (+ (* y stride) x))
                            dest (+ dest-at (+ (* y stride) x)))
            nil)
        (if (= next 1) (u8! state vh.FIZZLE-DONE 1) nil)
        state))))

;;; VGA pages have spare address space beyond the visible 320x200 raster. A
;;; bounded host byte array simply omits writes outside the supplied page; the
;;; inclusive coordinate decision and LFSR advance above are still preserved.
(defn vh.fizzle-copy (source from dest to)
  (if (and (>= from 0)
           (and (< from (bytes.length source))
                (and (>= to 0) (< to (bytes.length dest)))))
      (u8! dest to (u8@ source from))
      nil))

(defn vh.fizzle-fade (source source-at dest dest-at stride
                       width height frames abortable acknowledged)
  (vh.fizzle-fade-state source source-at dest dest-at stride
                         (vh.fizzle-begin width height frames abortable)
                         acknowledged))

(defn vh.fizzle-fade-state (source source-at dest dest-at stride state acknowledged)
  (let ((status (vh.fizzle-step source source-at dest dest-at stride state acknowledged)))
    (if (eq? status 'running)
        (vh.fizzle-fade-state source source-at dest dest-at stride state acknowledged)
        (eq? status 'aborted))))
