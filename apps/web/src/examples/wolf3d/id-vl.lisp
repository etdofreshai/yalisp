;;; ID_VL.C's palette, ported to YALISP.
;;;
;;; The game's 256 colours are `gamepal`, which ID_VL.C hands to VL_SetPalette
;;; and the VGA DAC. It is not one of the data files: it was assembled into the
;;; program, so the copy of it that can be read is GAMEPAL.OBJ from id's
;;; published source release. The port mounts that object file as an asset and
;;; reads the palette out of it here.
;;;
;;; Two decodings happen below, and both are decodings, so both are in Lisp.
;;;
;;; --- the object file ---------------------------------------------------------
;;;
;;; GAMEPAL.OBJ is Intel OMF, which is a flat sequence of records:
;;;
;;;   byte  type
;;;   word  length of everything after this field, checksum included
;;;   ...   contents
;;;   byte  checksum
;;;
;;; The bytes are in the one LEDATA record, type 0xA0, whose contents begin
;;; with a segment index and the offset the data is to be laid down at:
;;;
;;;   index  segment                (one byte while the index is under 128)
;;;   word   enumerated data offset
;;;   ...    the data itself
;;;
;;; So the records are walked rather than an offset being written down. The
;;; single-byte segment index is the one assumption, and it is checked: the
;;; record's own length has to leave exactly 768 bytes of data after it.
(define vl.OMF-LEDATA 160)
(define vl.PALETTE-BYTES 768)

;;; ID_VL.C owns one VGA DAC palette plus two 768-byte fade work buffers.
;;; The browser cannot wait for vertical retrace inside one interpreter call,
;;; so fade-begin captures the source state and each fade-step advances one
;;; source loop iteration. Arithmetic, inclusive ranges, the i=0 frame, and the
;;; immediate final SetPalette/FillPalette remain in the original order.
(define vl.current-palette (bytes.alloc vl.PALETTE-BYTES))
(define vl.palette1 (bytes.alloc vl.PALETTE-BYTES))
(define vl.palette2 (bytes.alloc vl.PALETTE-BYTES))
(define vl.palette-ready 0)
(define vl.screenfaded false)
(define vl.fade-kind 'idle)
(define vl.fade-start 0)
(define vl.fade-end 0)
(define vl.fade-red 0)
(define vl.fade-green 0)
(define vl.fade-blue 0)
(define vl.fade-steps 0)
(define vl.fade-index 0)
(define vl.fade-target nil)
(define vl.fade-target-at 0)

(defn vl.record-length (obj at) (u16@ obj (+ at 1)))

(defn vl.next-record (obj at) (+ at (+ 3 (vl.record-length obj at))))

;;; The first LEDATA record, or -1 if the walk runs off the end of the file
;;; rather than finding one. A file that is not the palette object is a state
;;; the program can see, not a read past the end of a buffer.
(defn vl.ledata (obj at)
  (if (>= at (bytes.length obj))
      -1
      (if (= (u8@ obj at) vl.OMF-LEDATA)
          at
          (vl.ledata obj (vl.next-record obj at)))))

;;; type(1) + length(2) + segment index(1) + data offset(2) = 6 bytes of record
;;; before the data, and length counts everything after itself including the
;;; trailing checksum, so 3 + 1 + 2 + 768 + 1 is what a palette record measures.
(defn vl.palette-at (obj) (vl.palette-from obj (vl.ledata obj 0)))

(defn vl.palette-from (obj record)
  (if (< record 0)
      -1
      (if (= (vl.record-length obj record) (+ vl.PALETTE-BYTES 4))
          (+ record 6)
          -1)))

(defn vl.palette? (obj) (>= (vl.palette-at obj) 0))

(defn vl.palette-data-at (source)
  (if (= (bytes.length source) vl.PALETTE-BYTES) 0 (vl.palette-at source)))

(defn vl.palette-data? (source)
  (let ((at (vl.palette-data-at source)))
    (and (>= at 0) (<= (+ at vl.PALETTE-BYTES) (bytes.length source)))))

(defn vl.set-palette (source)
  (vl.set-palette-at source (vl.palette-data-at source)))

(defn vl.set-palette-at (source at)
  (if (and (>= at 0) (<= (+ at vl.PALETTE-BYTES) (bytes.length source)))
      (begin
        (bytes.copy vl.current-palette 0 source at vl.PALETTE-BYTES)
        (set! vl.palette-ready 1)
        vl.current-palette)
      (ca.graphics-reject source)))

(defn vl.fill-palette (red green blue)
  (begin
    (vl.fill-palette-at 0 red green blue)
    (set! vl.palette-ready 1)
    vl.current-palette))

(defn vl.fill-palette-at (colour red green blue)
  (if (= colour 256)
      vl.current-palette
      (let ((at (* colour 3)))
        (begin
          (u8! vl.current-palette at red)
          (u8! vl.current-palette (+ at 1) green)
          (u8! vl.current-palette (+ at 2) blue)
          (vl.fill-palette-at (+ colour 1) red green blue)))))

(defn vl.fade-out-vector (source dest start end red green blue steps index)
  (begin
    (bytes.copy dest 0 source 0 vl.PALETTE-BYTES)
    (vl.fade-out-colour source dest start end red green blue steps index)))

(defn vl.fade-out-colour (source dest colour end red green blue steps index)
  (if (> colour end)
      dest
      (begin
        (vl.fade-out-component source dest (* colour 3) red steps index)
        (vl.fade-out-component source dest (+ (* colour 3) 1) green steps index)
        (vl.fade-out-component source dest (+ (* colour 3) 2) blue steps index)
        (vl.fade-out-colour source dest (+ colour 1) end
                            red green blue steps index))))

(defn vl.fade-out-component (source dest at target steps index)
  (let ((original (u8@ source at)))
    (u8! dest at (+ original (/ (* (- target original) index) steps)))))

(defn vl.fade-in-vector (source target target-at dest start end steps index)
  (begin
    (bytes.copy dest 0 source 0 vl.PALETTE-BYTES)
    (vl.fade-in-component source target target-at dest
                          (* start 3) (+ (* end 3) 2) steps index)))

(defn vl.fade-in-component (source target target-at dest at end steps index)
  (if (> at end)
      dest
      (let ((original (u8@ source at)))
        (begin
          (u8! dest at
               (+ original
                  (/ (* (- (u8@ target (+ target-at at)) original) index) steps)))
          (vl.fade-in-component source target target-at dest
                                (+ at 1) end steps index)))))

(defn vl.fade-out-begin (start end red green blue steps)
  (begin
    (bytes.copy vl.palette1 0 vl.current-palette 0 vl.PALETTE-BYTES)
    (bytes.copy vl.palette2 0 vl.current-palette 0 vl.PALETTE-BYTES)
    (set! vl.fade-kind 'out)
    (set! vl.fade-start start) (set! vl.fade-end end)
    (set! vl.fade-red red) (set! vl.fade-green green) (set! vl.fade-blue blue)
    (set! vl.fade-steps steps) (set! vl.fade-index 0)
    vl.fade-kind))

(defn vl.fade-in-begin (start end palette steps)
  (let ((at (vl.palette-data-at palette)))
    (if (or (< at 0) (> (+ at vl.PALETTE-BYTES) (bytes.length palette)))
        (ca.graphics-reject palette)
        (begin
          (bytes.copy vl.palette1 0 vl.current-palette 0 vl.PALETTE-BYTES)
          (bytes.copy vl.palette2 0 vl.current-palette 0 vl.PALETTE-BYTES)
          (set! vl.fade-kind 'in)
          (set! vl.fade-start start) (set! vl.fade-end end)
          (set! vl.fade-steps steps) (set! vl.fade-index 0)
          (set! vl.fade-target palette) (set! vl.fade-target-at at)
          vl.fade-kind))))

(defn vl.fade-step ()
  (vl.fade-step-marked (heap.used)))

(defn vl.fade-step-marked (mark)
  (let ((status (vl.fade-step-run)))
    (begin (heap.release mark) status)))

(defn vl.fade-step-run ()
  (if (eq? vl.fade-kind 'idle)
      'complete
      (if (>= vl.fade-index vl.fade-steps)
          (vl.fade-final)
          (begin
            (if (eq? vl.fade-kind 'out)
                (vl.fade-out-vector vl.palette1 vl.palette2
                                    vl.fade-start vl.fade-end
                                    vl.fade-red vl.fade-green vl.fade-blue
                                    vl.fade-steps vl.fade-index)
                (vl.fade-in-vector vl.palette1 vl.fade-target vl.fade-target-at
                                   vl.palette2 vl.fade-start vl.fade-end
                                   vl.fade-steps vl.fade-index))
            (bytes.copy vl.current-palette 0 vl.palette2 0 vl.PALETTE-BYTES)
            (set! vl.palette-ready 1)
            (set! vl.fade-index (+ vl.fade-index 1))
            ;; The source performs its final palette write immediately after
            ;; the last loop iteration, without another retrace wait.
            (if (= vl.fade-index vl.fade-steps)
                (vl.fade-final)
                'running)))))

(defn vl.fade-final ()
  (if (eq? vl.fade-kind 'out)
      (begin
        (vl.fill-palette vl.fade-red vl.fade-green vl.fade-blue)
        (set! vl.screenfaded true)
        (set! vl.fade-kind 'idle)
        'complete)
      (begin
        (vl.set-palette-at vl.fade-target vl.fade-target-at)
        (set! vl.screenfaded false)
        (set! vl.fade-kind 'idle)
        'complete)))

(defn vl.fade-run ()
  (vl.fade-run-marked (heap.used)))

(defn vl.fade-run-marked (mark)
  (let ((status (vl.fade-step)))
    (if (eq? status 'running)
        (vl.fade-run-marked mark)
        (begin (heap.release mark) status))))

(defn vl.fade-out (start end red green blue steps)
  (begin (vl.fade-out-begin start end red green blue steps) (vl.fade-run)))

(defn vl.fade-in (start end palette steps)
  (begin (vl.fade-in-begin start end palette steps) (vl.fade-run)))

;;; --- six-bit VGA to eight-bit colour -----------------------------------------
;;;
;;; A VGA DAC register holds six bits per channel, so every byte in gamepal is
;;; 0 to 63 and the palette's brightest white is 63,63,63. Replicate the high
;;; two bits into the low two bits when expanding to the host's eight-bit
;;; channel: (dac << 2) | (dac >> 4). Thus the full DAC range maps exactly from
;;; 0 to 255 rather than stopping at 252.
(defn vl.channel (obj at)
  (let ((dac (u8@ obj at)))
    (bit.or (bit.shl dac 2) (bit.shr dac 4))))

(define vl.HEX "0123456789abcdef")

(defn vl.hex-digit (n) (string.substring vl.HEX n (+ n 1)))

(defn vl.hex-byte (n)
  (string.append (vl.hex-digit (bit.shr n 4)) (vl.hex-digit (bit.and n 15))))

(defn vl.colour (obj at)
  (string.append
    (string.append "#" (vl.hex-byte (vl.channel obj at)))
    (string.append (vl.hex-byte (vl.channel obj (+ at 1)))
                   (vl.hex-byte (vl.channel obj (+ at 2))))))

;;; The whole palette as the surface colours the host is declared, in palette
;;; index order, so a byte the renderer writes is an index into the game's own
;;; palette and the host does no lookup of its own.
(defn vl.palette-colours (obj)
  (if (= vl.palette-ready 1)
      (vl.palette-loop vl.current-palette 0 255 nil)
      (vl.palette-loop obj (vl.palette-at obj) 255 nil)))

(defn vl.palette-loop (obj at i acc)
  (if (< i 0)
      acc
      (vl.palette-loop obj at (- i 1) (cons (vl.colour obj (+ at (* i 3))) acc))))
