;;; WL_MAIN.C CONFIG.WL6 codec for the R5 host boundary.
;;;
;;; The released file has no magic, version, or checksum.  Its first 462 bytes
;;; are seven opaque HighScore records; callers that require byte identity must
;;; pin the complete seed externally.  This codec copies that prefix verbatim
;;; and owns only the source-ordered 60-byte configuration tail.

(define wl.R5-CONFIG-BYTES 522)
(define wl.R5-CONFIG-TAIL 462)

(defn wl.r5-config-at (values index)
  (if (= index 0) (car values) (wl.r5-config-at (cdr values) (- index 1))))

(defn wl.r5-config-exact-length? (value remaining)
  (if (= remaining 0)
      (nil? value)
      (if (not (pair? value))
          false
          (wl.r5-config-exact-length? (cdr value) (- remaining 1)))))

(defn wl.r5-config-integer? (value)
  (if (not (number? value)) false (= (mod value 1) 0)))

(defn wl.r5-config-range? (value low high)
  (if (not (wl.r5-config-integer? value))
      false
      (and (>= value low) (<= value high))))

(defn wl.r5-config-boolean? (value) (or (eq? value true) (eq? value false)))

(defn wl.r5-config-list-range? (values count low high)
  (if (= count 0)
      (nil? values)
      (if (not (pair? values))
          false
          (if (not (wl.r5-config-range? (car values) low high))
              false
              (wl.r5-config-list-range? (cdr values) (- count 1) low high)))))

(defn wl.r5-config-row? (row name)
  (if (not (wl.r5-config-exact-length? row 2)) false (eq? (car row) name)))

(define wl.r5-config-field-names
  '(sound-mode music-mode digi-mode view-size dirscan buttonscan mouse-enabled
    joystick-enabled joypad-enabled joystick-progressive joystick-port
    button-mouse button-joy mouse-adjustment))

(defn wl.r5-config-shape-rows? (config names)
  (if (nil? names)
      (nil? config)
      (if (not (pair? config))
          false
          (if (not (wl.r5-config-row? (car config) (car names)))
              false
              (wl.r5-config-shape-rows? (cdr config) (cdr names))))))

(defn wl.r5-config-shape? (config)
  (wl.r5-config-shape-rows? config wl.r5-config-field-names))

(defn wl.r5-config-value (config index) (car (cdr (wl.r5-config-at config index))))

(defn wl.r5-config-valid? (config)
  (if (not (wl.r5-config-shape? config))
      false
    (and (wl.r5-config-range? (wl.r5-config-value config 0) 0 2)
    (and (wl.r5-config-range? (wl.r5-config-value config 1) 0 1)
    (and (wl.r5-config-range? (wl.r5-config-value config 2) 0 3)
    (and (wl.r5-config-range? (wl.r5-config-value config 3) 4 19)
    (and (wl.r5-config-list-range? (wl.r5-config-value config 4) 4 0 127)
    (and (wl.r5-config-list-range? (wl.r5-config-value config 5) 8 0 127)
    (and (wl.r5-config-boolean? (wl.r5-config-value config 6))
    (and (wl.r5-config-boolean? (wl.r5-config-value config 7))
    (and (wl.r5-config-boolean? (wl.r5-config-value config 8))
    (and (wl.r5-config-boolean? (wl.r5-config-value config 9))
    (and (wl.r5-config-range? (wl.r5-config-value config 10) 0 1)
    (and (wl.r5-config-list-range? (wl.r5-config-value config 11) 4 -1 7)
    (and (wl.r5-config-list-range? (wl.r5-config-value config 12) 4 -1 7)
         (wl.r5-config-range? (wl.r5-config-value config 13) 0 9))))))))))))))))

(defn wl.r5-config-i16@ (source at)
  (let ((value (u16@ source at))) (if (>= value 32768) (- value 65536) value)))

(defn wl.r5-config-i16! (target at value)
  (u16! target at (if (< value 0) (+ value 65536) value)))

(defn wl.r5-config-write-list (target at values)
  (if (nil? values)
      target
      (begin
        (wl.r5-config-i16! target at (car values))
        (wl.r5-config-write-list target (+ at 2) (cdr values)))))

(defn wl.r5-config-read-list (source at count values)
  (if (= count 0)
      (reverse values)
      (wl.r5-config-read-list source (+ at 2) (- count 1)
                              (cons (wl.r5-config-i16@ source at) values))))

(defn wl.r5-config-bool-int (value) (if value 1 0))

(defn wl.r5-config-encode (seed config)
  (if (nil? seed)
      false
      (if (not (= (bytes.length seed) wl.R5-CONFIG-BYTES))
          false
          (if (not (wl.r5-config-valid? config))
              false
              (let ((output (bytes.alloc wl.R5-CONFIG-BYTES)))
            (begin
              (bytes.copy output 0 seed 0 wl.R5-CONFIG-BYTES)
              (wl.r5-config-i16! output 462 (wl.r5-config-value config 0))
              (wl.r5-config-i16! output 464 (wl.r5-config-value config 1))
              (wl.r5-config-i16! output 466 (wl.r5-config-value config 2))
              (wl.r5-config-i16! output 468 (wl.r5-config-bool-int (wl.r5-config-value config 6)))
              (wl.r5-config-i16! output 470 (wl.r5-config-bool-int (wl.r5-config-value config 7)))
              (wl.r5-config-i16! output 472 (wl.r5-config-bool-int (wl.r5-config-value config 8)))
              (wl.r5-config-i16! output 474 (wl.r5-config-bool-int (wl.r5-config-value config 9)))
              (wl.r5-config-i16! output 476 (wl.r5-config-value config 10))
              (wl.r5-config-write-list output 478 (wl.r5-config-value config 4))
              (wl.r5-config-write-list output 486 (wl.r5-config-value config 5))
              (wl.r5-config-write-list output 502 (wl.r5-config-value config 11))
              (wl.r5-config-write-list output 510 (wl.r5-config-value config 12))
              (wl.r5-config-i16! output 518 (wl.r5-config-value config 3))
              (wl.r5-config-i16! output 520 (wl.r5-config-value config 13))
              output))))))

(defn wl.r5-config-decode (source)
  (if (nil? source)
      false
      (if (not (= (bytes.length source) wl.R5-CONFIG-BYTES))
          false
          (let ((mouse (wl.r5-config-i16@ source 468))
            (joystick (wl.r5-config-i16@ source 470))
            (joypad (wl.r5-config-i16@ source 472))
            (progressive (wl.r5-config-i16@ source 474)))
        (if (not (and (or (= mouse 0) (= mouse 1))
                      (and (or (= joystick 0) (= joystick 1))
                           (and (or (= joypad 0) (= joypad 1))
                                (or (= progressive 0) (= progressive 1))))))
            false
            (let ((config
              (list
                (list 'sound-mode (wl.r5-config-i16@ source 462))
                (list 'music-mode (wl.r5-config-i16@ source 464))
                (list 'digi-mode (wl.r5-config-i16@ source 466))
                (list 'view-size (wl.r5-config-i16@ source 518))
                (list 'dirscan (wl.r5-config-read-list source 478 4 nil))
                (list 'buttonscan (wl.r5-config-read-list source 486 8 nil))
                (list 'mouse-enabled (= mouse 1))
                (list 'joystick-enabled (= joystick 1))
                (list 'joypad-enabled (= joypad 1))
                (list 'joystick-progressive (= progressive 1))
                (list 'joystick-port (wl.r5-config-i16@ source 476))
                (list 'button-mouse (wl.r5-config-read-list source 502 4 nil))
                (list 'button-joy (wl.r5-config-read-list source 510 4 nil))
                (list 'mouse-adjustment (wl.r5-config-i16@ source 520)))))
              (if (wl.r5-config-valid? config) config false)))))))
