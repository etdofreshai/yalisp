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

;;; --- six-bit VGA to eight-bit colour -----------------------------------------
;;;
;;; A VGA DAC register holds six bits per channel, so every byte in gamepal is
;;; 0 to 63 and the palette's brightest white is 63,63,63. Shifting left by two
;;; is the expansion every port of this game uses, and it is what is done here.
;;; It is not exact: 63 becomes 252 rather than 255, so the whole palette is
;;; about 1% darker than a DAC driving a real monitor to full scale. That is a
;;; stated approximation, not a claim about what the hardware did.
(defn vl.channel (obj at) (bit.shl (u8@ obj at) 2))

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
(defn vl.palette-colours (obj) (vl.palette-loop obj (vl.palette-at obj) 255 nil))

(defn vl.palette-loop (obj at i acc)
  (if (< i 0)
      acc
      (vl.palette-loop obj at (- i 1) (cons (vl.colour obj (+ at (* i 3))) acc))))
