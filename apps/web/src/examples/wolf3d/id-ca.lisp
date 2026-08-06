;;; ID_CA.C - map file caching, ported to YALISP.
;;;
;;; This is the original's map path, kept structurally close to the C rather
;;; than rewritten: CAL_SetupMapFile reads the map header file, CA_CacheMap
;;; pulls one level's planes out of the map data file, and the two expanders
;;; the original stacks - Carmack's back-reference compression, then RLEW -
;;; are ported as their own functions in that order.
;;;
;;; Both files arrive as generic asset handles. The host counted their bytes
;;; and nothing else; every offset, width, and tag below is read out of the
;;; original bytes here in Lisp.
;;;
;;; The original's structures, from ID_CA.H and ID_CA.C:
;;;
;;;   mapfiletype {          MAPHEAD.ext, the map header file
;;;     unsigned RLEWtag;              offset 0
;;;     long     headeroffsets[100];   offset 2, one per map, negative = sparse
;;;     byte     tileinfo[];           offset 402
;;;   }
;;;
;;;   maptype {              at headeroffsets[n] inside GAMEMAPS.ext
;;;     long     planestart[3];        offset 0
;;;     unsigned planelength[3];       offset 12
;;;     unsigned width,height;         offset 18, 20
;;;     char     name[16];             offset 22
;;;   }
;;;
;;; Every multi-byte field is little-endian, because the original ran on a
;;; little-endian 16-bit machine and these are its files unchanged.

(define ca.NUMMAPS 60)
(define ca.MAPPLANES 2)
(define ca.MAPHEADER-SIZE 38)
;;; CA_CacheMap: "WOLF: This is specialized for a 64*64 map size".
(define ca.MAPSIZE 8192)

;;; CAL_CarmackExpand's two tag bytes.
(define ca.NEARTAG 167)
(define ca.FARTAG 168)

;;; --- mapfiletype, the map header file --------------------------------------

(defn ca.rlew-tag (tinf) (u16@ tinf 0))

;;; headeroffsets[i]. A negative value is the original's sparse-map marker:
;;; "if (pos<0) continue; // $FFFFFFFF start is a sparse map".
(defn ca.header-offset (tinf i) (i32@ tinf (+ 2 (* i 4))))

(defn ca.sparse-map? (tinf i) (< (ca.header-offset tinf i) 0))

;;; --- maptype, one level's header inside the map data file ------------------

(defn ca.plane-start (maps pos plane) (i32@ maps (+ pos (* plane 4))))
(defn ca.plane-length (maps pos plane) (u16@ maps (+ pos (+ 12 (* plane 2)))))
(defn ca.map-width (maps pos) (u16@ maps (+ pos 18)))
(defn ca.map-height (maps pos) (u16@ maps (+ pos 20)))

;;; name[16] is a fixed-width, NUL-padded C string. It is returned as the
;;; character codes actually stored, so nothing has to guess where it ends.
(defn ca.map-name-codes (maps pos)
  (ca.map-name-loop maps (+ pos 22) 0 nil))

(defn ca.map-name-loop (maps at i acc)
  (if (= i 16)
      (reverse acc)
      (ca.map-name-loop maps at (+ i 1) (cons (u8@ maps (+ at i)) acc))))

;;; The same field as text, stopping at the first NUL the way every C reader of
;;; a char[16] does. The code-to-character table is spelled out here rather than
;;; asked of the host, because turning a byte of original data into something
;;; displayable is a decoding decision and decoding decisions stay in Lisp. Only
;;; the printable range is mapped; anything outside it becomes a question mark
;;; rather than being dropped, so a name carrying an unexpected byte still says
;;; so.
(define ca.ASCII " !\"#$%&'()*+,-./0123456789:;<=>?@ABCDEFGHIJKLMNOPQRSTUVWXYZ[\\]^_`abcdefghijklmnopqrstuvwxyz{|}~")

(defn ca.character (code)
  (if (and (>= code 32) (<= code 126))
      (string.substring ca.ASCII (- code 32) (- code 31))
      "?"))

(defn ca.map-name (maps pos)
  (ca.map-name-text (ca.map-name-codes maps pos) ""))

(defn ca.map-name-text (codes acc)
  (if (empty? codes)
      acc
      (if (= (car codes) 0)
          acc
          (ca.map-name-text (cdr codes) (string.append acc (ca.character (car codes)))))))

;;; --- CA_RLEWexpand ---------------------------------------------------------
;;;
;;;   do {
;;;     value = *source++;
;;;     if (value != rlewtag) *dest++ = value;
;;;     else { count = *source++; value = *source++;
;;;            for (i=1;i<=count;i++) *dest++ = value; }
;;;   } while (dest<end);
;;;
;;; length is the EXPANDED length in bytes, and end is dest + length/2 words.
;;; The test is at the bottom, so a zero-length expansion still writes one
;;; word, exactly as the original does.
;;;
;;; Note the original's own warning above this routine: "A repeat count that
;;; produces 0xfff0 bytes can blow this!". There is no bound on the run inside
;;; the loop there and none is added here; a run that overshoots the plane runs
;;; past the end of dest. Here that meets the evaluator's bounds check and
;;; becomes a diagnostic instead of silent corruption, but the decision to let
;;; a run overshoot is the original's and is left in place.

(defn ca.rlew-expand (source at dest length rlewtag)
  (ca.rlew-expand-loop source at dest 0 (/ length 2) rlewtag))

(defn ca.rlew-expand-loop (source at dest di end rlewtag)
  (if (= (u16@ source at) rlewtag)
      (ca.rlew-expand-run source at dest
                          (ca.rlew-fill dest di (u16@ source (+ at 2)) (u16@ source (+ at 4)))
                          end rlewtag)
      (begin
        (u16! dest (* di 2) (u16@ source at))
        (ca.rlew-expand-step source (+ at 2) dest (+ di 1) end rlewtag))))

(defn ca.rlew-expand-run (source at dest di end rlewtag)
  (ca.rlew-expand-step source (+ at 6) dest di end rlewtag))

;;; while (dest<end)
(defn ca.rlew-expand-step (source at dest di end rlewtag)
  (if (< di end)
      (ca.rlew-expand-loop source at dest di end rlewtag)
      di))

;;; for (i=1;i<=count;i++) *dest++ = value
(defn ca.rlew-fill (dest di count value)
  (if (= count 0)
      di
      (begin
        (u16! dest (* di 2) value)
        (ca.rlew-fill dest (+ di 1) (- count 1) value))))

;;; --- CAL_CarmackExpand -----------------------------------------------------
;;;
;;; length is the EXPANDED length in bytes; the original halves it to words and
;;; counts down. The source pointer is a word pointer that the tag branches
;;; advance by single bytes, so it is carried here as a byte offset.
;;;
;;; Two original behaviours are kept rather than repaired. A near copy takes
;;; its source as `outptr - offset`, so it may read output words this call has
;;; not written yet when offset exceeds what has been produced. And `length` is
;;; a 16-bit `unsigned` there, so `length -= count` with a count larger than the
;;; words remaining wraps to just under 65536 and the loop runs on instead of
;;; stopping; `while (length)` is ported as the equality test the original
;;; wrote, and ca.u16 supplies the wrap that makes that test mean what it means
;;; in C. Without the wrap the counter would go negative and the same stream
;;; would loop forever rather than reproducing the original's behaviour.
(defn ca.u16 (n) (bit.and n 65535))

(defn ca.carmack-expand (source at dest length)
  (ca.carmack-loop source at dest 0 (/ length 2)))

(defn ca.carmack-loop (source at dest di length)
  (if (= length 0)
      di
      (ca.carmack-word source at dest di length (u16@ source at))))

(defn ca.carmack-word (source at dest di length ch)
  (if (= (bit.shr ch 8) ca.NEARTAG)
      (ca.carmack-near source at dest di length ch (bit.and ch 255))
      (if (= (bit.shr ch 8) ca.FARTAG)
          (ca.carmack-far source at dest di length ch (bit.and ch 255))
          (begin
            (u16! dest (* di 2) ch)
            (ca.carmack-loop source (+ at 2) dest (+ di 1) (- length 1))))))

;;; count == 0 means the next byte completes a literal word whose high byte
;;; happens to equal the tag: "have to insert a word containing the tag byte".
(defn ca.carmack-near (source at dest di length ch count)
  (if (= count 0)
      (begin
        (u16! dest (* di 2) (bit.or ch (u8@ source (+ at 2))))
        (ca.carmack-loop source (+ at 3) dest (+ di 1) (- length 1)))
      (ca.carmack-loop source (+ at 3) dest
                       (ca.carmack-copy dest (- di (u8@ source (+ at 2))) di count)
                       (ca.u16 (- length count)))))

;;; The far offset is a whole word and is measured from the start of dest,
;;; not from the current output position.
(defn ca.carmack-far (source at dest di length ch count)
  (if (= count 0)
      (begin
        (u16! dest (* di 2) (bit.or ch (u8@ source (+ at 2))))
        (ca.carmack-loop source (+ at 3) dest (+ di 1) (- length 1)))
      (ca.carmack-loop source (+ at 4) dest
                       (ca.carmack-copy dest (u16@ source (+ at 2)) di count)
                       (ca.u16 (- length count)))))

;;; while (count--) *outptr++ = *copyptr++
(defn ca.carmack-copy (dest from to count)
  (if (= count 0)
      to
      (begin
        (u16! dest (* to 2) (u16@ dest (* from 2)))
        (ca.carmack-copy dest (+ from 1) (+ to 1) (- count 1)))))

;;; --- CA_CacheMap -----------------------------------------------------------
;;;
;;; The original reads the compressed plane, then:
;;;
;;;   expanded = *source; source++;
;;;   CAL_CarmackExpand (source, buffer2seg, expanded);
;;;   CA_RLEWexpand (((unsigned far *)buffer2seg)+1, *dest, size, RLEWtag);
;;;
;;; Both stages are prefixed by their own expanded length word. The Carmack
;;; one is used; the RLEW one is skipped, which is why the second call starts
;;; a word in - "The resulting RLEW chunk also does, even though it's not
;;; really needed".
;;;
;;; This is the CARMACIZED path, which is the one GAMEMAPS.ext takes.

(defn ca.cache-plane (maps start rlewtag)
  (ca.cache-plane-into maps start rlewtag (bytes.alloc (u16@ maps start)) (bytes.alloc ca.MAPSIZE)))

(defn ca.cache-plane-into (maps start rlewtag buffer2 dest)
  (begin
    (ca.carmack-expand maps (+ start 2) buffer2 (u16@ maps start))
    (ca.rlew-expand buffer2 2 dest ca.MAPSIZE rlewtag)
    dest))

;;; for (plane = 0; plane<MAPPLANES; plane++). The original caches two planes
;;; even though maptype describes three, so the third stays on disk.
(defn ca.cache-map (tinf maps mapnum)
  (ca.cache-map-planes tinf maps (ca.header-offset tinf mapnum)))

(defn ca.cache-map-planes (tinf maps pos)
  (list (ca.cache-plane maps (ca.plane-start maps pos 0) (ca.rlew-tag tinf))
        (ca.cache-plane maps (ca.plane-start maps pos 1) (ca.rlew-tag tinf))))

;;; A tile is one word of a plane, addressed the way the original addresses
;;; mapsegs: tilemap[y*64+x], y major.
(defn ca.plane-tile (plane x y) (u16@ plane (* (+ (* y 64) x) 2)))

;;; --- CAL_SetupGrFile / CAL_HuffExpand ------------------------------------
;;;
;;; VGAHEAD.ext is not an array of C longs. IGRAB stores one original
;;; FILEPOSSIZE=3 little-endian offset per graphics chunk. 0xffffff is the
;;; sparse marker. VGAGRAPH.ext stores an explicit expanded-length longword at
;;; the start of ordinary chunks, followed by the bit stream. VGADICT.ext is
;;; the original 255-node table; each node is two little-endian words, with
;;; values below 256 denoting literal bytes and values 256..510 denoting nodes.
;;;
;;; These readers are deliberately bounded rather than tolerant. The original
;;; trusted its generated files and would run out of their buffers if one were
;;; truncated; here the evaluator's ordinary byte-bounds diagnostic is the
;;; fail-closed equivalent. No host code interprets any of these bytes.

(define ca.GRFILEPOS-SIZE 3)
(define ca.GR-SPARSE 16777215)
(define ca.HUFF-NODES 255)
(define ca.HUFF-ROOT 254)
(define ca.HUFF-DICT-BYTES 1024)
(define ca.HUFF-BLOCK-BYTES 64)
(define ca.HUFF-AT 0)
(define ca.HUFF-DI 4)
(define ca.HUFF-NODE 8)

;;; Ask the evaluator for the first byte past a real buffer. Keeping the
;;; rejected buffer as the single argument preserves the ordinary, precise
;;; byte-index diagnostic for every malformed graphics path.
(defn ca.graphics-reject (source) (u8@ source (bytes.length source)))

(defn ca.gr-offset-raw (head chunk)
  (+ (u8@ head (* chunk ca.GRFILEPOS-SIZE))
     (+ (bit.shl (u8@ head (+ (* chunk ca.GRFILEPOS-SIZE) 1)) 8)
        (bit.shl (u8@ head (+ (* chunk ca.GRFILEPOS-SIZE) 2)) 16))))

(defn ca.gr-offset (head chunk)
  (if (and (>= chunk 0)
           (< (+ (* chunk ca.GRFILEPOS-SIZE) 2) (bytes.length head)))
      (ca.gr-offset-raw head chunk)
      (ca.graphics-reject head)))

(defn ca.gr-chunks (head)
  (if (= (mod (bytes.length head) ca.GRFILEPOS-SIZE) 0)
      (/ (bytes.length head) ca.GRFILEPOS-SIZE)
      (ca.graphics-reject head)))

(defn ca.gr-next-offset (head graph chunk)
  (ca.gr-next-offset-loop head graph (+ chunk 1) (ca.gr-chunks head)))

(defn ca.gr-next-offset-loop (head graph chunk chunks)
  (if (= chunk chunks)
      (bytes.length graph)
      (let ((offset (ca.gr-offset head chunk)))
        (if (= offset ca.GR-SPARSE)
            (ca.gr-next-offset-loop head graph (+ chunk 1) chunks)
            offset))))

(defn ca.gr-span (head graph chunk)
  (let ((start (ca.gr-offset head chunk)) (end (ca.gr-next-offset head graph chunk)))
    (if (and (not (= start ca.GR-SPARSE))
             (and (<= (+ start 4) end) (<= end (bytes.length graph))))
        (list start end)
        (ca.graphics-reject graph))))

(defn ca.huff-code (dictionary node bit)
  (u16@ dictionary (+ (* node 4) (if (= bit 0) 0 2))))

(defn ca.huff-expand-exact (source start end dictionary dest length)
  (if (and (= (bytes.length dictionary) ca.HUFF-DICT-BYTES)
           (and (>= start 0) (and (<= start end) (<= end (bytes.length source)))))
      (let ((state (bytes.alloc 12)))
        (begin
          (u32! state ca.HUFF-AT start)
          (u32! state ca.HUFF-DI 0)
          (u16! state ca.HUFF-NODE ca.HUFF-ROOT)
          (ca.huff-expand-blocks source end dictionary dest length state)))
      (ca.graphics-reject dictionary)))

(defn ca.huff-expand-blocks (source end dictionary dest length state)
  (if (= (u32@ state ca.HUFF-DI) length)
      dest
      (ca.huff-expand-block-marked source end dictionary dest length state
                                   (heap.used))))

(defn ca.huff-expand-block-marked (source end dictionary dest length state mark)
  (begin
    (ca.huff-expand-block source end dictionary dest length state
                          ca.HUFF-BLOCK-BYTES)
    (heap.release mark)
    (ca.huff-expand-blocks source end dictionary dest length state)))

(defn ca.huff-expand-block (source end dictionary dest length state count)
  (if (or (= count 0) (= (u32@ state ca.HUFF-DI) length))
      state
      (if (< (u32@ state ca.HUFF-AT) end)
        (begin
          (ca.huff-expand-byte source dictionary dest length state 0)
          (u32! state ca.HUFF-AT (+ (u32@ state ca.HUFF-AT) 1))
          (ca.huff-expand-block source end dictionary dest length state (- count 1)))
        (ca.graphics-reject source))))

(defn ca.huff-expand-byte (source dictionary dest length state bit)
  (if (or (= bit 8) (= (u32@ state ca.HUFF-DI) length))
      state
      (ca.huff-expand-bit source dictionary dest length state bit
                          (ca.huff-code dictionary (u16@ state ca.HUFF-NODE)
                            (if (= (bit.and (u8@ source (u32@ state ca.HUFF-AT))
                                            (bit.shl 1 bit)) 0) 0 1)))))

(defn ca.huff-expand-bit (source dictionary dest length state bit code)
  (if (< code 256)
      (begin
        (u8! dest (u32@ state ca.HUFF-DI) code)
        (u32! state ca.HUFF-DI (+ (u32@ state ca.HUFF-DI) 1))
        (u16! state ca.HUFF-NODE ca.HUFF-ROOT)
        (ca.huff-expand-byte source dictionary dest length state (+ bit 1)))
      (if (< code (+ 256 ca.HUFF-NODES))
          (begin
            (u16! state ca.HUFF-NODE (- code 256))
            (ca.huff-expand-byte source dictionary dest length state (+ bit 1)))
          (ca.graphics-reject dictionary))))

;;; Ordinary graphics chunks begin with their explicit expanded length. The
;;; caller supplies the only accepted length before allocation, so a corrupt
;;; longword cannot turn into an allocator request or an adjacent picture.
(defn ca.expand-gr-chunk-exact (head graph dictionary chunk expected)
  (let ((dest (bytes.alloc expected)))
    (ca.expand-gr-chunk-into head graph dictionary chunk dest expected)))

(defn ca.expand-gr-chunk-into (head graph dictionary chunk dest expected)
  (ca.expand-gr-chunk-span head graph dictionary dest expected
                           (ca.gr-span head graph chunk)))

(defn ca.expand-gr-chunk-span (head graph dictionary dest expected span)
  (let ((start (car span)) (end (car (cdr span))))
    (if (and (= (bytes.length dest) expected) (= (u32@ graph start) expected))
        (ca.huff-expand-exact graph (+ start 4) end dictionary dest expected)
        (ca.graphics-reject graph))))
