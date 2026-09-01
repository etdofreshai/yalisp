;;; WL_TEXT.C - article layout and source font rendering, ported to YALisp.
;;;
;;; DOS pointers become string offsets and expanded graphics byte buffers. The
;;; polling ShowArticle loop becomes one resumable navigation step so browser
;;; input can arrive between calls; command order and all layout measurements
;;; remain Lisp-owned.

(define wl.BACKCOLOR 17)
(define wl.WORDLIMIT 80)
(define wl.FONTHEIGHT 10)
(define wl.TOPMARGIN 16)
(define wl.BOTTOMMARGIN 32)
(define wl.LEFTMARGIN 16)
(define wl.RIGHTMARGIN 16)
(define wl.PICMARGIN 8)
(define wl.TEXTROWS 15)
(define wl.SPACEWIDTH 7)
(define wl.SCREENPIXWIDTH 320)
(define wl.SCREENMID 160)
(define wl.ARTICLE-SCAN-LIMIT 30000)
(define wl.ARTICLE-SMALL-STRING-LIMIT 1024)
(define wl.ARTICLE-MAX-PAGES 128)
(define wl.ARTICLE-MAX-PICTURES 128)
(define wl.ARTICLE-MAX-TIMED 64)
(define wl.T-HELPART 138)
(define wl.T-ENDART1 143)
(define wl.H-TOPWINDOWPIC 6)
(define wl.H-LEFTWINDOWPIC 7)
(define wl.H-RIGHTWINDOWPIC 8)
(define wl.H-BOTTOMINFOPIC 9)

(define wl.FONT-HEIGHT 0)
(define wl.FONT-LOCATIONS 2)
(define wl.FONT-WIDTHS 514)
(define wl.FONT-HEADER-BYTES 770)
(define wl.article-left-margins (bytes.alloc 30))
(define wl.article-right-margins (bytes.alloc 30))
(define wl.help-article-storage (bytes.alloc wl.ARTICLE-SCAN-LIMIT))
(define wl.end-article-storage (bytes.alloc wl.ARTICLE-SCAN-LIMIT))
(define wl.help-article-length-cell (bytes.alloc 2))
(define wl.end-article-length-cell (bytes.alloc 2))
(define wl.help-byte-article
  (list 'byte-article wl.help-article-storage wl.help-article-length-cell))
(define wl.end-byte-article
  (list 'byte-article wl.end-article-storage wl.end-article-length-cell))
(define wl.article-page-offsets (bytes.alloc (* wl.ARTICLE-MAX-PAGES 2)))
(define wl.article-picture-refs (bytes.alloc (* wl.ARTICLE-MAX-PICTURES 2)))
(define wl.article-timed-data (bytes.alloc (* wl.ARTICLE-MAX-TIMED 8)))
(define wl.article-byte-meta (bytes.alloc 16))
(define wl.article-layout-state (bytes.alloc 16))
(define wl.ARTICLE-META-PAGES 0)
(define wl.ARTICLE-META-PICTURES 2)
(define wl.ARTICLE-META-END 4)
(define wl.ARTICLE-META-FOUND-END 6)
(define wl.ARTICLE-META-TIMED 8)
(define wl.ARTICLE-META-TIMED-CURSOR 10)
(define wl.ARTICLE-LAYOUT-AT 0)
(define wl.ARTICLE-LAYOUT-X 2)
(define wl.ARTICLE-LAYOUT-Y 4)
(define wl.ARTICLE-LAYOUT-ROW 6)
(define wl.ARTICLE-LAYOUT-COLOUR 8)
(define wl.ARTICLE-LAYOUT-DONE 10)
(define wl.article-source "")
(define wl.article-scan nil)
(define wl.article-execution '(article-idle))

(defn wl.text-reject () (u8@ (bytes.alloc 0) 0))

(defn wl.framebuffer? (frame) (= (bytes.length frame) 64000))

(defn wl.bar (frame x y width height colour)
  (if (and (wl.framebuffer? frame)
           (and (>= x 0) (and (>= y 0)
             (and (>= width 0) (and (>= height 0)
               (and (<= (+ x width) 320) (<= (+ y height) 200)))))))
      (wl.bar-rows frame x y width height colour 0)
      (wl.text-reject)))

(defn wl.bar-rows (frame x y width height colour row)
  (if (= row height)
      frame
      (begin
        (bytes.fill frame (+ x (* (+ y row) 320)) width colour)
        (wl.bar-rows frame x y width height colour (+ row 1)))))

(defn wl.plot (frame x y colour)
  (if (and (>= x 0) (and (< x 320) (and (>= y 0) (< y 200))))
      (u8! frame (+ x (* y 320)) colour)
      frame))

(defn wl.outline (frame x y width height top-left bottom-right)
  (begin
    (wl.bar frame x y width 1 top-left)
    (wl.bar frame x y 1 height top-left)
    (wl.bar frame x (+ y height -1) width 1 bottom-right)
    (wl.bar frame (+ x width -1) y 1 height bottom-right)
    frame))

(defn wl.window (frame x y width height colour)
  (begin (wl.bar frame x y width height colour)
         (wl.outline frame x y width height 45 40) frame))

;;; Graphics chunks store their expanded byte count in the first dword. Bound
;;; it before allocation, then reuse the same fail-closed Huffman path as the
;;; status bar and latch pictures.
(defn wl.graphics-chunk-length (head graph chunk)
  (let ((span (ca.gr-span head graph chunk)))
    (let ((length (u32@ graph (car span))))
      (if (and (> length 0) (<= length 1048576)) length (wl.text-reject)))))

(defn wl.cache-graphics-chunk (head graph dictionary chunk)
  (ca.expand-gr-chunk-exact head graph dictionary chunk
                            (wl.graphics-chunk-length head graph chunk)))

;;; Production articles stay as their Huffman-expanded DOS byte stream. The
;;; destination is allocated with the module rather than while mounting, so a
;;; large help document never leaves a conversion tree resident in the bump
;;; heap. The explicit descriptor carries the valid prefix length.
(defn wl.cache-graphics-chunk-into (head graph dictionary chunk dest)
  (let ((length (wl.graphics-chunk-length head graph chunk)))
    (if (> length (bytes.length dest))
        (wl.text-reject)
        (let ((span (ca.gr-span head graph chunk)))
          (begin
            (ca.huff-expand-exact graph (+ (car span) 4) (car (cdr span))
                                  dictionary dest length)
            length)))))

(defn wl.byte-article (source length)
  (if (and (>= length 1)
           (and (<= length wl.ARTICLE-SCAN-LIMIT)
                (<= length (bytes.length source))))
      (list 'byte-article source length)
      (wl.text-reject)))

(defn wl.byte-article? (article)
  (and (pair? article) (eq? (car article) 'byte-article)))

(defn wl.byte-article-source (article) (wl.play-at article 1))
(defn wl.byte-article-length (article)
  (let ((length (wl.play-at article 2)))
    (if (number? length) length (u16@ length 0))))

(defn wl.cache-font (head graph dictionary fontnumber)
  (let ((font (wl.cache-graphics-chunk head graph dictionary (+ 1 fontnumber))))
    (if (and (>= (bytes.length font) wl.FONT-HEADER-BYTES)
             (> (u16@ font wl.FONT-HEIGHT) 0))
        font
        (wl.text-reject))))

(defn wl.font-height (font) (u16@ font wl.FONT-HEIGHT))
(defn wl.font-location (font code) (u16@ font (+ wl.FONT-LOCATIONS (* code 2))))
(defn wl.font-width (font code) (u8@ font (+ wl.FONT-WIDTHS code)))

(defn wl.ascii-code (character)
  (wl.ascii-code-at character 0))

(defn wl.ascii-code-at (character index)
  (if (= index (string.length ca.ASCII))
      32
      (if (string=? character (string.substring ca.ASCII index (+ index 1)))
          (+ index 32)
          (wl.ascii-code-at character (+ index 1)))))

(defn wl.measure-prop-string (font string)
  (wl.measure-prop-string-at font string 0 0))

(defn wl.measure-prop-string-at (font string at width)
  (if (= at (string.length string))
      (list width (wl.font-height font))
      (wl.measure-prop-string-at font string (+ at 1)
        (+ width (wl.font-width font
          (wl.ascii-code (string.substring string at (+ at 1))))))))

(defn wl.draw-prop-string (frame font string x y colour)
  (wl.draw-prop-string-marked frame font string x y colour (heap.used)))

(defn wl.draw-prop-string-marked (frame font string x y colour mark)
  (let ((end (wl.draw-prop-string-at frame font string 0 x y colour)))
    (begin (heap.release mark) end)))

(defn wl.draw-prop-string-at (frame font string at x y colour)
  (if (= at (string.length string))
      x
      (let ((code (wl.ascii-code (string.substring string at (+ at 1)))))
        (let ((width (wl.font-width font code)))
          (begin
            (wl.draw-font-character frame font code x y colour 0 0 width)
            (wl.draw-prop-string-at frame font string (+ at 1) (+ x width) y colour))))))

(defn wl.draw-font-character (frame font code x y colour column row width)
  (if (= column width)
      frame
      (if (= row (wl.font-height font))
          (wl.draw-font-character frame font code x y colour (+ column 1) 0 width)
          (begin
            (if (> (u8@ font (+ (wl.font-location font code)
                               (+ column (* row width)))) 0)
                (wl.plot frame (+ x column) (+ y row) colour) nil)
            (wl.draw-font-character frame font code x y colour column (+ row 1) width)))))

(defn wl.draw-picture (frame head graph dictionary pictable x y chunk)
  (wl.draw-picture-marked frame head graph dictionary pictable x y chunk
                           (heap.used)))

(defn wl.draw-picture-marked (frame head graph dictionary pictable x y chunk mark)
  (let ((aligned-x (bit.and x -8))
        (width (vh.picture-width pictable chunk))
        (height (vh.picture-height pictable chunk)))
    (let ((expected (vh.picture-bytes width height)))
      (if (and (> expected 0)
               (and (>= aligned-x 0) (and (>= y 0)
                 (and (<= (+ aligned-x width) 320) (<= (+ y height) 200)))))
          (let ((planar (ca.expand-gr-chunk-exact head graph dictionary chunk expected)))
            (begin
              ;; VWB_DrawPic clears the low three x bits before marking or
              ;; drawing the planar chunk.
              (vh.deplane-into planar width height frame 0
                               (+ aligned-x (* y 320)) 320)
              (heap.release mark)
              frame))
          (wl.text-reject)))))

;;; -------------------------------------------------------------------------
;;; CacheLayoutGraphics scanner

(defn wl.text-char (source at)
  (string.substring source at (+ at 1)))

(defn wl.digit-value (character)
  (cond ((string=? character "0") 0) ((string=? character "1") 1)
        ((string=? character "2") 2) ((string=? character "3") 3)
        ((string=? character "4") 4) ((string=? character "5") 5)
        ((string=? character "6") 6) ((string=? character "7") 7)
        ((string=? character "8") 8) ((string=? character "9") 9)
        (true -1)))

(defn wl.upper-command (character)
  (cond ((string=? character "p") "P") ((string=? character "e") "E")
        ((string=? character "g") "G") ((string=? character "t") "T")
        ((string=? character "c") "C") ((string=? character "l") "L")
        ((string=? character "b") "B") (true character)))

(defn wl.parse-number (source at)
  (wl.parse-number-seek source at (string.length source)))

(defn wl.parse-number-seek (source at length)
  (if (= at length)
      (wl.text-reject)
      (let ((digit (wl.digit-value (wl.text-char source at))))
        (if (< digit 0)
            (wl.parse-number-seek source (+ at 1) length)
            (wl.parse-number-digits source (+ at 1) length digit)))))

(defn wl.parse-number-digits (source at length value)
  (if (= at length)
      (list value at)
      (let ((digit (wl.digit-value (wl.text-char source at))))
        (if (< digit 0)
            (list value at)
            (wl.parse-number-digits source (+ at 1) length (+ (* value 10) digit))))))

(defn wl.rip-to-eol (source at)
  (if (= at (string.length source))
      (wl.text-reject)
      (if (string=? (wl.text-char source at) "\n")
          (+ at 1)
          (wl.rip-to-eol source (+ at 1)))))

(defn wl.picture-command (source at timed)
  (let ((y (wl.parse-number source at)))
    (let ((x (wl.parse-number source (car (cdr y)))))
      (let ((picture (wl.parse-number source (car (cdr x)))))
        (if timed
            (let ((delay (wl.parse-number source (car (cdr picture)))))
              (list (car y) (car x) (car picture) (car delay)
                    (wl.rip-to-eol source (car (cdr delay)))))
            (list (car y) (car x) (car picture) 0
                  (wl.rip-to-eol source (car (cdr picture)))))))))

(defn wl.scan-layout-text (source)
  (wl.scan-layout-blocks source 0
    (if (< (string.length source) wl.ARTICLE-SCAN-LIMIT)
        (string.length source) wl.ARTICLE-SCAN-LIMIT)
    nil nil))

(defn wl.scan-layout-blocks (source at limit pages pictures)
  (if (= at limit)
      (wl.text-reject)
      (let ((result (wl.scan-layout-block source at limit pages pictures 64)))
        (if (eq? (car result) 'done)
            (list (reverse (car (cdr (cdr result))))
                  (reverse (car (cdr (cdr (cdr result)))))
                  (car (cdr result)))
            (wl.scan-layout-blocks source (car (cdr result)) limit
              (car (cdr (cdr result))) (car (cdr (cdr (cdr result)))))))))

(defn wl.scan-layout-block (source at limit pages pictures count)
  (if (or (= at limit) (= count 0))
      (list 'more at pages pictures)
      (if (not (string=? (wl.text-char source at) "^"))
          (wl.scan-layout-block source (+ at 1) limit pages pictures (- count 1))
          (let ((command (wl.upper-command (wl.text-char source (+ at 1)))))
            (cond ((string=? command "P")
                   (wl.scan-layout-block source (+ at 2) limit (cons at pages) pictures (- count 1)))
                  ((string=? command "E") (list 'done at pages pictures))
                  ((or (string=? command "G") (string=? command "T"))
                   (let ((parsed (wl.picture-command source (+ at 2) (string=? command "T"))))
                     (list 'more (wl.play-at parsed 4) pages
                           (cons (wl.play-at parsed 2) pictures))))
                  (true (wl.scan-layout-block source (+ at 2) limit pages pictures (- count 1))))))))

(defn wl.article-page-count (scan) (length (car scan)))

(defn wl.article-page-start (scan page) (wl.play-at (car scan) page))

(defn wl.article-page-end (scan page)
  (if (< (+ page 1) (wl.article-page-count scan))
      (wl.article-page-start scan (+ page 1))
      (wl.play-at scan 2)))

;;; -------------------------------------------------------------------------
;;; Fixed byte-source CacheLayoutGraphics metadata

(defn wl.byte-code (source at limit)
  (if (and (>= at 0) (< at limit)) (u8@ source at) (wl.text-reject)))

(defn wl.byte-command (code)
  (cond ((= code 112) 80) ((= code 101) 69) ((= code 103) 71)
        ((= code 116) 84) ((= code 99) 67) ((= code 108) 76)
        ((= code 98) 66) (true code)))

(defn wl.byte-digit-value (code)
  (if (and (>= code 48) (<= code 57)) (- code 48) -1))

(defn wl.byte-layout-space? (code)
  (or (= code 9) (or (= code 10) (or (= code 13) (= code 32)))))

(defn wl.byte-parse-number (source at limit)
  (wl.byte-parse-number-seek source at limit))

(defn wl.byte-parse-number-seek (source at limit)
  (if (= at limit)
      (wl.text-reject)
      (let ((code (wl.byte-code source at limit)))
        (if (or (= code 10) (= code 13))
            (wl.text-reject)
            (let ((digit (wl.byte-digit-value code)))
              (if (< digit 0)
                  (wl.byte-parse-number-seek source (+ at 1) limit)
                  (wl.byte-parse-number-digits source (+ at 1) limit digit)))))))

(defn wl.byte-parse-number-digits (source at limit value)
  (if (= at limit)
      (list value at)
      (let ((digit (wl.byte-digit-value (wl.byte-code source at limit))))
        (if (< digit 0)
            (list value at)
            (wl.byte-parse-number-digits source (+ at 1) limit
              (+ (* value 10) digit))))))

(defn wl.byte-rip-to-eol (source at limit)
  (if (= at limit)
      (wl.text-reject)
      (let ((code (wl.byte-code source at limit)))
        (cond ((= code 10) (+ at 1))
              ((= code 13)
               (if (and (< (+ at 1) limit)
                        (= (wl.byte-code source (+ at 1) limit) 10))
                   (+ at 2) (+ at 1)))
              (true (wl.byte-rip-to-eol source (+ at 1) limit))))))

(defn wl.byte-picture-command (source at limit timed)
  (let ((y (wl.byte-parse-number source at limit)))
    (let ((x (wl.byte-parse-number source (wl.play-at y 1) limit)))
      (let ((picture (wl.byte-parse-number source (wl.play-at x 1) limit)))
        (if timed
            (let ((delay (wl.byte-parse-number source (wl.play-at picture 1) limit)))
              (list (car y) (car x) (car picture) (car delay)
                    (wl.byte-rip-to-eol source (wl.play-at delay 1) limit)))
            (list (car y) (car x) (car picture) 0
                  (wl.byte-rip-to-eol source (wl.play-at picture 1) limit)))))))

(defn wl.article-byte-pages () (u16@ wl.article-byte-meta wl.ARTICLE-META-PAGES))
(defn wl.article-byte-pictures () (u16@ wl.article-byte-meta wl.ARTICLE-META-PICTURES))
(defn wl.article-byte-end () (u16@ wl.article-byte-meta wl.ARTICLE-META-END))
(defn wl.article-byte-page-start (page)
  (if (and (>= page 0) (< page (wl.article-byte-pages)))
      (u16@ wl.article-page-offsets (* page 2))
      (wl.text-reject)))
(defn wl.article-byte-page-end (page)
  (if (< (+ page 1) (wl.article-byte-pages))
      (wl.article-byte-page-start (+ page 1))
      (wl.article-byte-end)))
(defn wl.article-byte-picture-ref (ordinal)
  (if (and (>= ordinal 0) (< ordinal (wl.article-byte-pictures)))
      (u16@ wl.article-picture-refs (* ordinal 2))
      (wl.text-reject)))

(defn wl.reset-byte-article-metadata ()
  (begin
    (bytes.fill wl.article-page-offsets 0 (bytes.length wl.article-page-offsets) 0)
    (bytes.fill wl.article-picture-refs 0 (bytes.length wl.article-picture-refs) 0)
    (bytes.fill wl.article-byte-meta 0 (bytes.length wl.article-byte-meta) 0)
    true))

(defn wl.record-byte-page (at)
  (let ((count (wl.article-byte-pages)))
    (if (= count wl.ARTICLE-MAX-PAGES)
        (wl.text-reject)
        (begin
          (u16! wl.article-page-offsets (* count 2) at)
          (u16! wl.article-byte-meta wl.ARTICLE-META-PAGES (+ count 1))
          true))))

(defn wl.record-byte-picture (picture)
  (let ((count (wl.article-byte-pictures)))
    (if (= count wl.ARTICLE-MAX-PICTURES)
        (wl.text-reject)
        (begin
          (u16! wl.article-picture-refs (* count 2) picture)
          (u16! wl.article-byte-meta wl.ARTICLE-META-PICTURES (+ count 1))
          true))))

(defn wl.byte-article-trailing? (source at limit)
  (if (= at limit)
      true
      (let ((code (wl.byte-code source at limit)))
        (if (or (= code 0) (or (= code 10) (or (= code 13) (= code 26))))
            (wl.byte-article-trailing? source (+ at 1) limit)
            false))))

(defn wl.scan-layout-bytes (article)
  (if (not (wl.byte-article? article))
      (wl.text-reject)
      (let ((source (wl.byte-article-source article))
            (limit (wl.byte-article-length article)))
        (begin
          (wl.reset-byte-article-metadata)
          (wl.scan-layout-byte-blocks source 0 limit)
          (if (and (= (u16@ wl.article-byte-meta wl.ARTICLE-META-FOUND-END) 1)
                   (> (wl.article-byte-pages) 0))
              article
              (wl.text-reject))))))

(defn wl.scan-layout-byte-blocks (source at limit)
  (if (= (u16@ wl.article-byte-meta wl.ARTICLE-META-FOUND-END) 1)
      true
      (if (= at limit)
          (wl.text-reject)
          (wl.scan-layout-byte-block-marked source at limit (heap.used)))))

(defn wl.scan-layout-byte-block-marked (source at limit mark)
  (let ((next (wl.scan-layout-byte-block source at limit 64)))
    (begin
      (heap.release mark)
      (wl.scan-layout-byte-blocks source next limit))))

(defn wl.scan-layout-byte-block (source at limit count)
  (if (or (= count 0) (= at limit))
      at
      (let ((code (wl.byte-code source at limit)))
        (if (not (= code 94))
            (wl.scan-layout-byte-block source (+ at 1) limit (- count 1))
            (let ((command (wl.byte-command (wl.byte-code source (+ at 1) limit))))
              (cond
                ((= command 80)
                 (begin (wl.record-byte-page at)
                        (wl.scan-layout-byte-block source (+ at 2) limit (- count 1))))
                ((= command 69)
                 (if (and (> (wl.article-byte-pages) 0)
                          (wl.byte-article-trailing? source (+ at 2) limit))
                     (begin
                       (u16! wl.article-byte-meta wl.ARTICLE-META-END at)
                       (u16! wl.article-byte-meta wl.ARTICLE-META-FOUND-END 1)
                       limit)
                     (wl.text-reject)))
                ((or (= command 71) (= command 84))
                 (let ((picture (wl.byte-picture-command source (+ at 2) limit
                                                         (= command 84))))
                   (begin
                     (wl.record-byte-picture (wl.play-at picture 2))
                     (wl.scan-layout-byte-block source (wl.play-at picture 4)
                                                limit (- count 1)))))
                (true
                 (wl.scan-layout-byte-block source (+ at 2) limit (- count 1)))))))))

(defn wl.back-page (page) (if (> page 0) (- page 1) 0))

(defn wl.navigate-article-page (page direction pages)
  (cond ((eq? direction 'escape) (list page true))
        ((or (eq? direction 'left) (or (eq? direction 'up) (eq? direction 'page-up)))
         (list (wl.back-page page) false))
        (true (list (if (< page (- pages 1)) (+ page 1) page) false))))

;;; -------------------------------------------------------------------------
;;; PageLayout raster execution
;;;
;;; Source globals become explicit arguments plus two fixed 15-row margin
;;; buffers. Timed picture waits are reported by the article execution state;
;;; page-layout rasterizes the completed source page, which is the frame DOS
;;; presents after its blocking PageLayout call returns.

(defn wl.reset-article-margins (row)
  (if (= row wl.TEXTROWS)
      true
      (begin
        (u16! wl.article-left-margins (* row 2) wl.LEFTMARGIN)
        (u16! wl.article-right-margins (* row 2) (- wl.SCREENPIXWIDTH wl.RIGHTMARGIN))
        (wl.reset-article-margins (+ row 1)))))

(defn wl.article-left (row) (u16@ wl.article-left-margins (* row 2)))
(defn wl.article-right (row) (u16@ wl.article-right-margins (* row 2)))

(defn wl.prepare-page-margins (source at end)
  (if (>= at end)
      true
      (if (and (string=? (wl.text-char source at) "^")
               (string=? (wl.upper-command (wl.text-char source (+ at 1))) "G"))
          (let ((picture (wl.picture-command source (+ at 2) false)))
            (begin
              (wl.mark-picture-margins (car picture) (wl.play-at picture 1)
                                       (wl.play-at picture 2))
              (wl.prepare-page-margins source (wl.play-at picture 4) end)))
          (wl.prepare-page-margins source (+ at 1) end))))

(defn wl.mark-picture-margins (y x picture)
  (let ((width (vh.picture-width app.pictable picture))
        (height (vh.picture-height app.pictable picture)))
    (let ((middle (+ x (/ width 2)))
          (top (if (< y wl.TOPMARGIN) 0 (/ (- y wl.TOPMARGIN) wl.FONTHEIGHT)))
          (bottom (/ (- (+ y height) wl.TOPMARGIN) wl.FONTHEIGHT)))
      (wl.mark-picture-margin-rows top
        (if (>= bottom wl.TEXTROWS) (- wl.TEXTROWS 1) bottom)
        (> middle wl.SCREENMID)
        (if (> middle wl.SCREENMID) (- x wl.PICMARGIN)
            (+ x width wl.PICMARGIN))))))

(defn wl.mark-picture-margin-rows (row bottom right-side margin)
  (if (> row bottom)
      true
      (begin
        (if right-side
            (u16! wl.article-right-margins (* row 2) margin)
            (u16! wl.article-left-margins (* row 2) margin))
        (wl.mark-picture-margin-rows (+ row 1) bottom right-side margin))))

(defn wl.hex-value (character)
  (let ((raw (wl.ascii-code character)))
    (let ((code (if (and (>= raw 97) (<= raw 102)) (- raw 32) raw)))
    (cond ((and (>= code 48) (<= code 57)) (- code 48))
          ((and (>= code 65) (<= code 70)) (+ 10 (- code 65)))
          (true 0)))))

(defn wl.article-word-end (source at end)
  (if (or (= at end) (<= (wl.ascii-code (wl.text-char source at)) 32))
      at
      (wl.article-word-end source (+ at 1) end)))

(defn wl.article-spaces (source at end x)
  (if (and (< at end) (string=? (wl.text-char source at) " "))
      (wl.article-spaces source (+ at 1) end (+ x wl.SPACEWIDTH))
      (list at x)))

(defn wl.article-new-line (cursor x y row colour)
  (if (= (+ row 1) wl.TEXTROWS)
      (list cursor x y row colour true)
      (list cursor (wl.article-left (+ row 1)) (+ y wl.FONTHEIGHT)
            (+ row 1) colour false)))

(defn wl.article-fit-word (cursor width x y row colour)
  (if (<= (+ x width) (wl.article-right row))
      (list cursor x y row colour false)
      (let ((next (wl.article-new-line cursor x y row colour)))
        (if (wl.play-at next 5) next
            (wl.article-fit-word cursor width (wl.play-at next 1)
                                 (wl.play-at next 2) (wl.play-at next 3)
                                 colour)))))

(defn wl.article-bar-command (source at)
  (let ((y (wl.parse-number source at)))
    (let ((x (wl.parse-number source (wl.play-at y 1))))
      (let ((width (wl.parse-number source (wl.play-at x 1))))
        (let ((height (wl.parse-number source (wl.play-at width 1))))
          (list (car y) (car x) (car width) (car height)
                (wl.rip-to-eol source (wl.play-at height 1))))))))

(defn wl.article-line-command (source at)
  (let ((y (wl.parse-number source at)))
    (let ((x (wl.parse-number source (wl.play-at y 1))))
      (list (car y) (car x) (wl.rip-to-eol source (wl.play-at x 1))))))

(defn wl.page-layout (frame font article scan page shownumber)
  (let ((start (wl.article-page-start scan page))
        (end (wl.article-page-end scan page)))
    (begin
      (wl.bar frame 0 0 320 200 wl.BACKCOLOR)
      (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                       0 0 wl.H-TOPWINDOWPIC)
      (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                       0 8 wl.H-LEFTWINDOWPIC)
      (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                       312 8 wl.H-RIGHTWINDOWPIC)
      (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                       8 176 wl.H-BOTTOMINFOPIC)
      (wl.reset-article-margins 0)
      (wl.prepare-page-margins article (wl.rip-to-eol article (+ start 2)) end)
      (wl.layout-page-at frame font article
        (wl.rip-to-eol article (+ start 2)) end wl.LEFTMARGIN wl.TOPMARGIN 0 0)
      (if shownumber
          (wl.draw-prop-string frame font
            (string.append "pg " (string.append (to-string (+ page 1))
              (string.append " of " (to-string (wl.article-page-count scan)))))
            213 183 79) nil)
      frame)))

(defn wl.layout-page-at (frame font source at end x y row colour)
  (if (>= at end)
      frame
      (let ((character (wl.text-char source at)))
        (cond ((string=? character "^")
               (wl.layout-page-command frame font source at end x y row colour))
              ((string=? character "\t")
               (wl.layout-page-at frame font source (+ at 1) end
                 (* (/ (+ x 8) 8) 8) y row colour))
              ((string=? character "\n")
               (let ((next (wl.article-new-line (+ at 1) x y row colour)))
                 (if (wl.play-at next 5) frame
                     (wl.layout-page-at frame font source (car next) end
                       (wl.play-at next 1) (wl.play-at next 2)
                       (wl.play-at next 3) colour))))
              ((<= (wl.ascii-code character) 32)
               (wl.layout-page-at frame font source (+ at 1) end x y row colour))
              (true
               (let ((wordend (wl.article-word-end source at end)))
                 (if (>= (- wordend at) wl.WORDLIMIT)
                     (wl.text-reject)
                     (let ((word (string.substring source at wordend)))
                       (let ((width (car (wl.measure-prop-string font word))))
                         (let ((fit (wl.article-fit-word wordend width x y row colour)))
                           (if (wl.play-at fit 5)
                               frame
                               (let ((newx
                                 (wl.draw-prop-string frame font word
                                   (wl.play-at fit 1) (wl.play-at fit 2) colour)))
                                 (let ((spaces (wl.article-spaces source wordend end newx)))
                                   (wl.layout-page-at frame font source (car spaces) end
                                     (wl.play-at spaces 1) (wl.play-at fit 2)
                                     (wl.play-at fit 3) colour))))))))))))))

(defn wl.layout-page-command (frame font source at end x y row colour)
  (let ((command (wl.upper-command (wl.text-char source (+ at 1)))))
    (cond ((or (string=? command "P") (string=? command "E")) frame)
          ((string=? command ";")
           (wl.layout-page-at frame font source (wl.rip-to-eol source (+ at 2))
                              end x y row colour))
          ((string=? command "B")
           (let ((bar (wl.article-bar-command source (+ at 2))))
             (begin
               (wl.bar frame (wl.play-at bar 1) (car bar)
                       (wl.play-at bar 2) (wl.play-at bar 3) wl.BACKCOLOR)
               (wl.layout-page-at frame font source (wl.play-at bar 4)
                                  end x y row colour))))
          ((string=? command "C")
           (wl.layout-page-at frame font source (+ at 4) end x y row
             (+ (* (wl.hex-value (wl.text-char source (+ at 2))) 16)
                (wl.hex-value (wl.text-char source (+ at 3))))))
          ((string=? command ">")
           (wl.layout-page-at frame font source (+ at 2) end 160 y row colour))
          ((string=? command "L")
           (let ((line (wl.article-line-command source (+ at 2))))
             (let ((newrow (/ (- (car line) wl.TOPMARGIN) wl.FONTHEIGHT)))
               (wl.layout-page-at frame font source (wl.play-at line 2) end
                 (wl.play-at line 1) (+ wl.TOPMARGIN (* newrow wl.FONTHEIGHT))
                 newrow colour))))
          ((or (string=? command "G") (string=? command "T"))
           (let ((picture (wl.picture-command source (+ at 2) (string=? command "T"))))
             (begin
               (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                 (* (/ (wl.play-at picture 1) 8) 8) (car picture)
                 (wl.play-at picture 2))
               (let ((newx (if (and (string=? command "G")
                                    (< x (wl.article-left row)))
                               (wl.article-left row) x)))
                 (wl.layout-page-at frame font source (wl.play-at picture 4)
                                    end newx y row colour)))))
          (true (wl.layout-page-at frame font source (+ at 2) end x y row colour)))))

;;; -------------------------------------------------------------------------
;;; Byte-source PageLayout execution

(defn wl.byte-word-end (source at end)
  (if (or (= at end) (<= (wl.byte-code source at end) 32))
      at
      (wl.byte-word-end source (+ at 1) end)))

(defn wl.byte-word-width (font source at end)
  (wl.byte-word-width-marked font source at end (heap.used)))

(defn wl.byte-word-width-marked (font source at end mark)
  (let ((width (wl.byte-word-width-at font source at end 0)))
    (begin (heap.release mark) width)))

(defn wl.byte-word-width-at (font source at end width)
  (if (= at end)
      width
      (wl.byte-word-width-at font source (+ at 1) end
        (+ width (wl.font-width font (wl.byte-code source at end))))))

(defn wl.draw-byte-word (frame font source at end x y colour)
  (wl.draw-byte-word-marked frame font source at end x y colour (heap.used)))

(defn wl.draw-byte-word-marked (frame font source at end x y colour mark)
  (let ((right (wl.draw-byte-word-at frame font source at end x y colour)))
    (begin (heap.release mark) right)))

(defn wl.draw-byte-word-at (frame font source at end x y colour)
  (if (= at end)
      x
      (let ((code (wl.byte-code source at end)))
        (let ((width (wl.font-width font code)))
          (begin
            (wl.draw-font-character frame font code x y colour 0 0 width)
            (wl.draw-byte-word-at frame font source (+ at 1) end
                                  (+ x width) y colour))))))

(defn wl.byte-prepare-page-margins (source at end)
  (if (>= at end)
      true
      (wl.byte-prepare-page-margins-marked source at end (heap.used))))

(defn wl.byte-prepare-page-margins-marked (source at end mark)
  (let ((next (wl.byte-prepare-page-margins-block source at end 64)))
    (begin
      (heap.release mark)
      (wl.byte-prepare-page-margins source next end))))

(defn wl.byte-prepare-page-margins-block (source at end count)
  (if (or (= count 0) (>= at end))
      at
      (if (and (= (wl.byte-code source at end) 94)
               (= (wl.byte-command (wl.byte-code source (+ at 1) end)) 71))
          (let ((picture (wl.byte-picture-command source (+ at 2) end false)))
            (begin
              (wl.mark-picture-margins (car picture) (wl.play-at picture 1)
                                       (wl.play-at picture 2))
              (wl.byte-prepare-page-margins-block source (wl.play-at picture 4)
                                                  end (- count 1))))
          (wl.byte-prepare-page-margins-block source (+ at 1) end (- count 1)))))

(defn wl.byte-layout-at () (u16@ wl.article-layout-state wl.ARTICLE-LAYOUT-AT))
(defn wl.byte-layout-x () (u16@ wl.article-layout-state wl.ARTICLE-LAYOUT-X))
(defn wl.byte-layout-y () (u16@ wl.article-layout-state wl.ARTICLE-LAYOUT-Y))
(defn wl.byte-layout-row () (u16@ wl.article-layout-state wl.ARTICLE-LAYOUT-ROW))
(defn wl.byte-layout-colour () (u16@ wl.article-layout-state wl.ARTICLE-LAYOUT-COLOUR))

(defn wl.byte-layout-set (at x y row colour done)
  (begin
    (u16! wl.article-layout-state wl.ARTICLE-LAYOUT-AT at)
    (u16! wl.article-layout-state wl.ARTICLE-LAYOUT-X x)
    (u16! wl.article-layout-state wl.ARTICLE-LAYOUT-Y y)
    (u16! wl.article-layout-state wl.ARTICLE-LAYOUT-ROW row)
    (u16! wl.article-layout-state wl.ARTICLE-LAYOUT-COLOUR colour)
    (u16! wl.article-layout-state wl.ARTICLE-LAYOUT-DONE done)
    true))

(defn wl.byte-layout-update (at x y row colour)
  (wl.byte-layout-set at x y row colour
    (u16@ wl.article-layout-state wl.ARTICLE-LAYOUT-DONE)))

(defn wl.byte-layout-finish ()
  (u16! wl.article-layout-state wl.ARTICLE-LAYOUT-DONE 1))

(defn wl.byte-layout-new-line (cursor)
  (let ((row (wl.byte-layout-row)))
    (if (= (+ row 1) wl.TEXTROWS)
        (begin (u16! wl.article-layout-state wl.ARTICLE-LAYOUT-AT cursor)
               (wl.byte-layout-finish))
        (wl.byte-layout-update cursor (wl.article-left (+ row 1))
                               (+ (wl.byte-layout-y) wl.FONTHEIGHT)
                               (+ row 1) (wl.byte-layout-colour)))))

(defn wl.byte-page-layout (frame font article page shownumber)
  (let ((source (wl.byte-article-source article))
        (start (wl.article-byte-page-start page))
        (end (wl.article-byte-page-end page)))
    (let ((text-start (wl.byte-rip-to-eol source (+ start 2)
                                           (wl.byte-article-length article))))
      (begin
        (wl.bar frame 0 0 320 200 wl.BACKCOLOR)
        (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                         0 0 wl.H-TOPWINDOWPIC)
        (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                         0 8 wl.H-LEFTWINDOWPIC)
        (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                         312 8 wl.H-RIGHTWINDOWPIC)
        (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
                         8 176 wl.H-BOTTOMINFOPIC)
        (wl.reset-article-margins 0)
        (wl.byte-prepare-page-margins source text-start end)
        (wl.byte-layout-set text-start wl.LEFTMARGIN wl.TOPMARGIN 0 0 0)
        (wl.byte-layout-blocks frame font source end)
        (if shownumber
            (wl.draw-prop-string frame font
              (string.append "pg " (string.append (to-string (+ page 1))
                (string.append " of " (to-string (wl.article-byte-pages)))))
              213 183 79) nil)
        frame))))

(defn wl.byte-layout-blocks (frame font source end)
  (if (or (= (u16@ wl.article-layout-state wl.ARTICLE-LAYOUT-DONE) 1)
          (>= (wl.byte-layout-at) end))
      frame
      (wl.byte-layout-block-marked frame font source end (heap.used))))

(defn wl.byte-layout-block-marked (frame font source end mark)
  (begin
    (wl.byte-layout-block frame font source end 64)
    (heap.release mark)
    (wl.byte-layout-blocks frame font source end)))

(defn wl.byte-layout-block (frame font source end count)
  (if (or (= count 0)
          (or (= (u16@ wl.article-layout-state wl.ARTICLE-LAYOUT-DONE) 1)
              (>= (wl.byte-layout-at) end)))
      frame
      (let ((at (wl.byte-layout-at)))
        (let ((code (wl.byte-code source at end)))
          (cond
            ((= code 94)
             (begin (wl.byte-layout-command frame font source end)
                    (wl.byte-layout-block frame font source end (- count 1))))
            ((= code 9)
             (begin
               (wl.byte-layout-update (+ at 1)
                 (* (/ (+ (wl.byte-layout-x) 8) 8) 8)
                 (wl.byte-layout-y) (wl.byte-layout-row) (wl.byte-layout-colour))
               (wl.byte-layout-block frame font source end (- count 1))))
            ((or (= code 10) (= code 13))
             (begin
               (wl.byte-layout-new-line
                 (if (and (= code 13) (< (+ at 1) end)
                          (= (wl.byte-code source (+ at 1) end) 10))
                     (+ at 2) (+ at 1)))
               (wl.byte-layout-block frame font source end (- count 1))))
            ((<= code 32)
             (begin
               (wl.byte-layout-update (+ at 1) (wl.byte-layout-x)
                 (wl.byte-layout-y) (wl.byte-layout-row) (wl.byte-layout-colour))
               (wl.byte-layout-block frame font source end (- count 1))))
            (true
             (begin (wl.byte-layout-word frame font source end)
                    (wl.byte-layout-block frame font source end (- count 1)))))))))

(defn wl.byte-layout-word (frame font source end)
  (let ((at (wl.byte-layout-at)))
    (let ((wordend (wl.byte-word-end source at end)))
      (if (>= (- wordend at) wl.WORDLIMIT)
          (wl.text-reject)
          (let ((width (wl.byte-word-width font source at wordend)))
            (let ((fit (wl.article-fit-word wordend width
                         (wl.byte-layout-x) (wl.byte-layout-y)
                         (wl.byte-layout-row) (wl.byte-layout-colour))))
              (if (wl.play-at fit 5)
                  (wl.byte-layout-finish)
                  (let ((newx (wl.draw-byte-word frame font source at wordend
                                      (wl.play-at fit 1) (wl.play-at fit 2)
                                      (wl.byte-layout-colour))))
                    (wl.byte-layout-spaces source wordend end newx
                      (wl.play-at fit 2) (wl.play-at fit 3))))))))))

(defn wl.byte-layout-spaces (source at end x y row)
  (if (and (< at end) (= (wl.byte-code source at end) 32))
      (wl.byte-layout-spaces source (+ at 1) end (+ x wl.SPACEWIDTH) y row)
      (wl.byte-layout-update at x y row (wl.byte-layout-colour))))

(defn wl.byte-layout-command (frame font source end)
  (let ((at (wl.byte-layout-at)))
    (let ((command (wl.byte-command (wl.byte-code source (+ at 1) end))))
      (cond
        ((or (= command 80) (= command 69)) (wl.byte-layout-finish))
        ((= command 59)
         (wl.byte-layout-update (wl.byte-rip-to-eol source (+ at 2) end)
           (wl.byte-layout-x) (wl.byte-layout-y) (wl.byte-layout-row)
           (wl.byte-layout-colour)))
        ((= command 66)
         (let ((bar (wl.byte-bar-command source (+ at 2) end)))
           (begin
             (wl.bar frame (wl.play-at bar 1) (car bar)
                     (wl.play-at bar 2) (wl.play-at bar 3) wl.BACKCOLOR)
             (wl.byte-layout-update (wl.play-at bar 4)
               (wl.byte-layout-x) (wl.byte-layout-y) (wl.byte-layout-row)
               (wl.byte-layout-colour)))))
        ((= command 67)
         (wl.byte-layout-update (+ at 4) (wl.byte-layout-x) (wl.byte-layout-y)
           (wl.byte-layout-row)
           (+ (* (wl.byte-hex-value (wl.byte-code source (+ at 2) end)) 16)
              (wl.byte-hex-value (wl.byte-code source (+ at 3) end)))))
        ((= command 62)
         (wl.byte-layout-update (+ at 2) 160 (wl.byte-layout-y)
           (wl.byte-layout-row) (wl.byte-layout-colour)))
        ((= command 76)
         (let ((line (wl.byte-line-command source (+ at 2) end)))
           (let ((newrow (/ (- (car line) wl.TOPMARGIN) wl.FONTHEIGHT)))
             (wl.byte-layout-update (wl.play-at line 2) (wl.play-at line 1)
               (+ wl.TOPMARGIN (* newrow wl.FONTHEIGHT)) newrow
               (wl.byte-layout-colour)))))
        ((or (= command 71) (= command 84))
         (let ((picture (wl.byte-picture-command source (+ at 2) end (= command 84))))
           (begin
             (wl.draw-picture frame app.vgahead app.vgagraph app.vgadict app.pictable
               (* (/ (wl.play-at picture 1) 8) 8) (car picture)
               (wl.play-at picture 2))
             (wl.byte-layout-update (wl.play-at picture 4)
               (if (and (= command 71) (< (wl.byte-layout-x)
                                           (wl.article-left (wl.byte-layout-row))))
                   (wl.article-left (wl.byte-layout-row)) (wl.byte-layout-x))
               (wl.byte-layout-y) (wl.byte-layout-row) (wl.byte-layout-colour)))))
        (true
         (wl.byte-layout-update (+ at 2) (wl.byte-layout-x) (wl.byte-layout-y)
           (wl.byte-layout-row) (wl.byte-layout-colour)))))))

(defn wl.byte-hex-value (code)
  (let ((upper (if (and (>= code 97) (<= code 102)) (- code 32) code)))
    (cond ((and (>= upper 48) (<= upper 57)) (- upper 48))
          ((and (>= upper 65) (<= upper 70)) (+ 10 (- upper 65)))
          (true 0))))

(defn wl.byte-bar-command (source at end)
  (let ((y (wl.byte-parse-number source at end)))
    (let ((x (wl.byte-parse-number source (wl.play-at y 1) end)))
      (let ((width (wl.byte-parse-number source (wl.play-at x 1) end)))
        (let ((height (wl.byte-parse-number source (wl.play-at width 1) end)))
          (list (car y) (car x) (car width) (car height)
                (wl.byte-rip-to-eol source (wl.play-at height 1) end)))))))

(defn wl.byte-line-command (source at end)
  (let ((y (wl.byte-parse-number source at end)))
    (let ((x (wl.byte-parse-number source (wl.play-at y 1) end)))
      (list (car y) (car x) (wl.byte-rip-to-eol source (wl.play-at x 1) end)))))

(defn wl.article-timed-events (article scan page)
  (wl.article-timed-events-at article
    (wl.article-page-start scan page) (wl.article-page-end scan page) nil))

(defn wl.article-timed-events-at (source at end events)
  (if (>= at end)
      (reverse events)
      (if (and (string=? (wl.text-char source at) "^")
               (string=? (wl.upper-command (wl.text-char source (+ at 1))) "T"))
          (let ((picture (wl.picture-command source (+ at 2) true)))
            (wl.article-timed-events-at source (wl.play-at picture 4) end
              (cons (list (wl.play-at picture 3) (car picture)
                          (* (/ (wl.play-at picture 1) 8) 8)
                          (wl.play-at picture 2)) events)))
          (wl.article-timed-events-at source (+ at 1) end events))))

(defn wl.reset-byte-timed-events ()
  (begin
    (bytes.fill wl.article-timed-data 0 (bytes.length wl.article-timed-data) 0)
    (u16! wl.article-byte-meta wl.ARTICLE-META-TIMED 0)
    (u16! wl.article-byte-meta wl.ARTICLE-META-TIMED-CURSOR 0)
    true))

(defn wl.record-byte-timed-event (delay y x picture)
  (let ((count (u16@ wl.article-byte-meta wl.ARTICLE-META-TIMED)))
    (if (= count wl.ARTICLE-MAX-TIMED)
        (wl.text-reject)
        (let ((at (* count 8)))
          (begin
            (u16! wl.article-timed-data at delay)
            (u16! wl.article-timed-data (+ at 2) y)
            (u16! wl.article-timed-data (+ at 4) (* (/ x 8) 8))
            (u16! wl.article-timed-data (+ at 6) picture)
            (u16! wl.article-byte-meta wl.ARTICLE-META-TIMED (+ count 1))
            true)))))

(defn wl.byte-timed-delay (ordinal)
  (u16@ wl.article-timed-data (* ordinal 8)))

(defn wl.scan-byte-timed-events (article page)
  (let ((source (wl.byte-article-source article)))
    (begin
      (wl.reset-byte-timed-events)
      (wl.scan-byte-timed-blocks source (wl.article-byte-page-start page)
                                  (wl.article-byte-page-end page)))))

(defn wl.scan-byte-timed-blocks (source at end)
  (if (>= at end)
      true
      (wl.scan-byte-timed-block-marked source at end (heap.used))))

(defn wl.scan-byte-timed-block-marked (source at end mark)
  (let ((next (wl.scan-byte-timed-block source at end 64)))
    (begin (heap.release mark) (wl.scan-byte-timed-blocks source next end))))

(defn wl.scan-byte-timed-block (source at end count)
  (if (or (= count 0) (>= at end))
      at
      (if (not (= (wl.byte-code source at end) 94))
          (wl.scan-byte-timed-block source (+ at 1) end (- count 1))
          (let ((command (wl.byte-command (wl.byte-code source (+ at 1) end))))
            (if (or (= command 71) (= command 84))
                (let ((picture (wl.byte-picture-command source (+ at 2) end
                                                        (= command 84))))
                  (begin
                    (if (= command 84)
                        (wl.record-byte-timed-event
                          (wl.play-at picture 3) (car picture)
                          (wl.play-at picture 1) (wl.play-at picture 2)) nil)
                    (wl.scan-byte-timed-block source (wl.play-at picture 4)
                                              end (- count 1))))
                (wl.scan-byte-timed-block source (+ at 2) end (- count 1)))))))

(defn wl.begin-article (article)
  (if (string? article)
      (if (> (string.length article) wl.ARTICLE-SMALL-STRING-LIMIT)
          (wl.text-reject)
          (begin
            (set! wl.article-source article)
            (set! wl.article-scan (wl.scan-layout-text article))
            (wl.article-begin-page 0)))
      (if (wl.byte-article? article)
          (begin
            (set! wl.article-source article)
            (set! wl.article-scan (wl.scan-layout-bytes article))
            (wl.article-begin-page 0))
          (wl.text-reject))))

(defn wl.article-begin-page (page)
  (if (wl.byte-article? wl.article-source)
      (begin
        (wl.scan-byte-timed-events wl.article-source page)
        (set! wl.article-execution
          (if (= (u16@ wl.article-byte-meta wl.ARTICLE-META-TIMED) 0)
              (list 'article-page page (wl.article-byte-pages))
              (list 'article-wait page (wl.article-byte-pages)
                    (wl.byte-timed-delay 0))))
        wl.article-execution)
      (let ((events (wl.article-timed-events wl.article-source wl.article-scan page))
            (pages (wl.article-page-count wl.article-scan)))
        (begin
          (set! wl.article-execution
            (if (nil? events)
                (list 'article-page page pages)
                (list 'article-wait page pages (car (car events)) events)))
          wl.article-execution))))

(defn wl.article-execution-step (direction elapsed)
  (let ((kind (car wl.article-execution)))
    (cond ((eq? kind 'article-wait) (wl.article-wait-step elapsed))
          ((eq? kind 'article-page) (wl.article-navigation-step direction))
          (true wl.article-execution))))

(defn wl.article-wait-step (elapsed)
  (if (wl.byte-article? wl.article-source)
      (wl.byte-article-wait-step elapsed)
      (let ((page (wl.play-at wl.article-execution 1))
            (pages (wl.play-at wl.article-execution 2))
            (remaining (wl.play-at wl.article-execution 3))
            (events (wl.play-at wl.article-execution 4)))
        (if (< elapsed remaining)
            (begin
              (set! wl.article-execution
                (list 'article-wait page pages (- remaining elapsed) events))
              wl.article-execution)
            (let ((rest (cdr events)))
              (begin
                (set! wl.article-execution
                  (if (nil? rest) (list 'article-page page pages)
                      (list 'article-wait page pages (car (car rest)) rest)))
                wl.article-execution))))))

(defn wl.byte-article-wait-step (elapsed)
  (let ((page (wl.play-at wl.article-execution 1))
        (pages (wl.play-at wl.article-execution 2))
        (remaining (wl.play-at wl.article-execution 3)))
    (if (< elapsed remaining)
        (begin
          (set! wl.article-execution
            (list 'article-wait page pages (- remaining elapsed)))
          wl.article-execution)
        (let ((next (+ (u16@ wl.article-byte-meta wl.ARTICLE-META-TIMED-CURSOR) 1)))
          (begin
            (u16! wl.article-byte-meta wl.ARTICLE-META-TIMED-CURSOR next)
            (set! wl.article-execution
              (if (= next (u16@ wl.article-byte-meta wl.ARTICLE-META-TIMED))
                  (list 'article-page page pages)
                  (list 'article-wait page pages (wl.byte-timed-delay next))))
            wl.article-execution)))))

(defn wl.article-navigation-step (direction)
  (let ((page (wl.play-at wl.article-execution 1))
        (pages (wl.play-at wl.article-execution 2)))
    (cond ((eq? direction 'none) wl.article-execution)
          ((eq? direction 'escape)
           (begin (set! wl.article-execution '(article-done)) wl.article-execution))
          (true
           (let ((next (wl.navigate-article-page page direction pages)))
             (if (= (car next) page) wl.article-execution
                 (wl.article-begin-page (car next))))))))

(defn wl.draw-current-article (frame font shownumber)
  (let ((kind (car wl.article-execution)))
    (if (or (eq? kind 'article-page) (eq? kind 'article-wait))
        (if (wl.byte-article? wl.article-source)
            (wl.byte-page-layout frame font wl.article-source
                                 (wl.play-at wl.article-execution 1) shownumber)
            (wl.page-layout frame font wl.article-source wl.article-scan
                            (wl.play-at wl.article-execution 1) shownumber))
        frame)))

;;; ShowArticle is represented as explicit state: (article-page page pages).
;;; PageLayout rendering uses the source font/picture functions above; the host
;;; only supplies the next input and presents the completed indexed page.
(defn wl.show-article (article)
  (if (string? article)
      (if (> (string.length article) wl.ARTICLE-SMALL-STRING-LIMIT)
          (wl.text-reject)
          (let ((scan (wl.scan-layout-text article)))
            (list 'article-page 0 (wl.article-page-count scan))))
      (if (wl.byte-article? article)
          (begin (wl.scan-layout-bytes article)
                 (list 'article-page 0 (wl.article-byte-pages)))
          (wl.text-reject))))

(defn wl.show-article-step (state direction)
  (let ((next (wl.navigate-article-page (wl.play-at state 1) direction
                                         (wl.play-at state 2))))
    (list 'article-page (car next) (wl.play-at state 2) (car (cdr next)))))

(defn wl.help-screens (article) (wl.show-article article))

(defn wl.end-text (episode article)
  (if (and (>= episode 0) (< episode 6))
      (wl.show-article article)
      (wl.text-reject)))
