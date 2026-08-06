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
