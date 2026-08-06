;;; ID_PM.C - the page file, ported to YALISP.
;;;
;;; VSWAP.ext is the game's page file: wall textures, then sprites, then
;;; digitised sound, in that order, each chunk one 4096-byte page. The
;;; original's manager is an EMS/XMS pager that swaps pages in and out of a
;;; buffer; none of that is here, because the whole file is already a mounted
;;; asset the evaluator can index. What is here is the part that says where a
;;; page is, which is the part a renderer needs.
;;;
;;; PML_OpenPageFile reads the header:
;;;
;;;   read (PageFile,&ChunksInFile,sizeof(ChunksInFile));    word,  offset 0
;;;   read (PageFile,&PMSpriteStart,sizeof(PMSpriteStart));  word,  offset 2
;;;   read (PageFile,&PMSoundStart,sizeof(PMSoundStart));    word,  offset 4
;;;   ...
;;;   size = sizeof(longword) * ChunksInFile;                offsets, offset 6
;;;   ...
;;;   size = sizeof(word) * ChunksInFile;                    lengths, after
;;;
;;; so the file begins with three words, then one longword offset per chunk,
;;; then one word length per chunk. Every field is little-endian, and every
;;; offset is a byte offset from the start of the file. The host counted the
;;; file's bytes and nothing else; all of the above is read here in Lisp.
;;;
;;; #define PMPageSize 4096
(define pm.PAGE-SIZE 4096)

;;; The page file itself, and the three header words, kept as locations rather
;;; than recomputed: the raycaster asks for a page per screen column.
(define pm.file nil)
(define pm.chunks 0)
(define pm.sprite-start 0)
(define pm.sound-start 0)

(defn pm.startup (file)
  (begin
    (set! pm.file file)
    (set! pm.chunks (u16@ file 0))
    (set! pm.sprite-start (u16@ file 2))
    (set! pm.sound-start (u16@ file 4))))

(defn pm.started? () (not (nil? pm.file)))

(defn pm.page-offset (n) (i32@ pm.file (+ 6 (* n 4))))

(defn pm.page-length (n) (u16@ pm.file (+ 6 (+ (* pm.chunks 4) (* n 2)))))

;;; PM_GetPage(n) hands the original a far pointer to the page's bytes. There
;;; is one buffer here and it is the file, so what a page is known by is its
;;; byte offset inside it. Everything that reads a page reads pm.file at this
;;; offset plus a texel index, which is the same arithmetic the original does
;;; with a segment and an offset.
(defn pm.get-page (n) (pm.page-offset n))

;;; PM_GetSpritePage adds PMSpriteStart before asking the page manager for the
;;; original compressed-shape page.
(defn pm.sprite-page (n) (pm.get-page (+ pm.sprite-start n)))

;;; The wall pages are the ones before PMSpriteStart. The original never asks
;;; whether a page is a wall, because the pictures it looks up are always wall
;;; pictures; this port can be handed a picture number for a tile the original
;;; would have turned into a door first, so it asks. See wl-draw.lisp.
(defn pm.wall-page? (n) (and (>= n 0) (< n pm.sprite-start)))

;;; One texel of a page. A wall page is 64 columns of 64 texels, column major:
;;; the column is the outer index, so column c starts at c*64 and runs top to
;;; bottom. Nothing here transposes it - the raycaster's texture offset is
;;; already c*64, which is what the original's `& 0xfc0` produces.
(defn pm.texel (page at) (u8@ pm.file (+ page at)))
