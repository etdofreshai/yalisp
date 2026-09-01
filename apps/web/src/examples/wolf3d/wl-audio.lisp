;;; ID_SD.C / ID_SD_A.ASM deterministic PCM translation for YALisp.
;;;
;;; The original writes an 8253 PC-speaker divisor, unsigned bytes to a Sound
;;; Blaster DAC, and register/value pairs to an OPL2.  A native YALisp runtime
;;; has byte buffers rather than those devices.  This module therefore renders
;;; the first two paths to the repository's normalized 49,716 Hz mono PCM16
;;; comparison format.  AdLib remains a register stream owned by wl-sound.lisp;
;;; an OPL host must synthesize that stream.  Returning nil for unsupported OPL
;;; PCM is intentional: silence would be fabricated equality.

(define audio.NORMALIZED-SAMPLE-RATE 49716)
(define audio.PCM-CHANNELS 1)
(define audio.PCM-BITS 16)

;;; ID_SD_A.ASM DOFX runs PC effects at TickBase*2 = 140 Hz. SD_Startup fills
;;; pcSoundLookup[i] with i*60 and programs 8253 mode 3. The exact phase unit
;;; constants are the reduced ratio (105000000/88) / 49716.
(define audio.PC-SERVICE-RATE 140)
(define audio.PC-MAX-SOUND-BYTE 254)
(define audio.PC-SOUND-LOOKUP-SCALE 60)
(define audio.PC-PCM-LEVEL 4587)
(define audio.PC-PHASE-STEP 1093750)
(define audio.PC-PHASE-UNITS-PER-COUNT 45573)

;;; SDL_StartSB asks for 7000 Hz using integer division. The DSP receives time
;;; constant 114, hence one unsigned DAC byte lasts exactly 142 microseconds.
(define audio.SB-REQUESTED-HZ 7000)
(define audio.SB-TIME-CONSTANT 114)
(define audio.SB-SAMPLE-PERIOD-US 142)
(define audio.SB-RESAMPLE-STEP 7059672) ; 142 * 49716
(define audio.DIGITIZED-DAC-CENTER 128)

(defn audio.reject (source) (u8@ source (bytes.length source)))

(defn audio.write-i16 (target at value)
  (u16! target at (if (< value 0) (+ value 65536) value)))

(defn audio.pcm-samples (pcm) (/ (bytes.length pcm) 2))

(defn audio.service-boundary (services rate)
  (/ (* services audio.NORMALIZED-SAMPLE-RATE) rate))

;;; Mutable render state avoids allocating a list for every output sample.
(define audio.pc-last -1)
(define audio.pc-period 0)
(define audio.pc-phase 0)
(define audio.pc-gated 0)

(defn audio.pc-pcm-source (source start length)
  (if (and (>= start 0)
           (and (>= length 1)
                (<= (+ start length) (bytes.length source))))
      (let ((pcm (bytes.alloc (* (audio.service-boundary length audio.PC-SERVICE-RATE) 2))))
        (begin
          (set! audio.pc-last -1)
          (set! audio.pc-period 0)
          (set! audio.pc-phase 0)
          (set! audio.pc-gated 0)
          (audio.pc-services source start length pcm 0)
          pcm))
      (audio.reject source)))

(defn audio.pc-chunk-pcm (chunk)
  (if (>= (bytes.length chunk) 6)
      (let ((length (u32@ chunk 0)))
        (if (and (>= length 1) (<= length (- (bytes.length chunk) 6)))
            (audio.pc-pcm-source chunk 6 length)
            (audio.reject chunk)))
      (audio.reject chunk)))

(defn audio.pc-services (source start length pcm service)
  (if (= service length)
      pcm
      (audio.pc-service source start length pcm service
                        (u8@ source (+ start service)))))

(defn audio.pc-service (source start length pcm service sample)
  (begin
    (if (= sample audio.pc-last)
        nil
        (begin
          (set! audio.pc-last sample)
          (if (= sample 0)
              (set! audio.pc-gated 0)
              (begin
                (if (> sample audio.PC-MAX-SOUND-BYTE) (audio.reject source) nil)
                (set! audio.pc-period
                      (* (* sample audio.PC-SOUND-LOOKUP-SCALE)
                         audio.PC-PHASE-UNITS-PER-COUNT))
                (set! audio.pc-phase 0)
                (set! audio.pc-gated 1)))))
    (audio.pc-service-samples
      pcm
      (audio.service-boundary service audio.PC-SERVICE-RATE)
      (audio.service-boundary (+ service 1) audio.PC-SERVICE-RATE)
      (if (and (= audio.pc-gated 1) (< service (- length 1))) 1 0))
    (audio.pc-services source start length pcm (+ service 1))))

(defn audio.pc-service-samples (pcm at until audible)
  (if (= at until)
      pcm
      (begin
        (audio.write-i16 pcm (* at 2)
          (if (= audible 1)
              (if (< (* audio.pc-phase 2) audio.pc-period)
                  audio.PC-PCM-LEVEL
                  (- 0 audio.PC-PCM-LEVEL))
              0))
        (if (= audio.pc-gated 1)
            (set! audio.pc-phase
                  (mod (+ audio.pc-phase audio.PC-PHASE-STEP) audio.pc-period))
            nil)
        (audio.pc-service-samples pcm (+ at 1) until audible))))

;;; Count output frames without multiplying the source length by 7,059,672;
;;; a shipped digitized sample can be large enough for that product to exceed
;;; the evaluator's signed 32-bit integer domain.
(defn audio.digitized-sample-count (length)
  (audio.digitized-count-at length 0 0 0))

(defn audio.digitized-count-at (length index remainder total)
  (if (= index length)
      total
      (let ((sum (+ remainder audio.SB-RESAMPLE-STEP)))
        (audio.digitized-count-at length (+ index 1)
          (mod sum 1000000) (+ total (/ sum 1000000))))))

(defn audio.digitized-level (sample)
  (let ((delta (- sample audio.DIGITIZED-DAC-CENTER)))
    (if (< delta 0)
        (* delta 256)
        (/ (+ (* delta 32767) 64) 128))))

(defn audio.digitized-pcm-source (source start length)
  (if (and (>= start 0)
           (and (>= length 1)
                (<= (+ start length) (bytes.length source))))
      (let ((pcm (bytes.alloc (* (audio.digitized-sample-count length) 2))))
        (begin (audio.digitized-bytes source start length pcm 0 0 0) pcm))
      (audio.reject source)))

(defn audio.digitized-pcm (source)
  (audio.digitized-pcm-source source 0 (bytes.length source)))

(defn audio.digitized-bytes (source start length pcm index remainder write-at)
  (if (= index length)
      pcm
      (let ((sum (+ remainder audio.SB-RESAMPLE-STEP)))
        (let ((count (/ sum 1000000)))
          (begin
            (audio.digitized-hold pcm write-at count
                                  (audio.digitized-level (u8@ source (+ start index))))
            (audio.digitized-bytes source start length pcm (+ index 1)
              (mod sum 1000000) (+ write-at count)))))))

(defn audio.digitized-hold (pcm at count value)
  (if (= count 0)
      pcm
      (begin
        ;; Each DAC byte expands to only seven or eight PCM frames. Two native
        ;; strided fills write the little-endian word without one evaluator
        ;; call frame per output sample.
        (bytes.fill-stride pcm (* at 2) count 2 (bit.and value 255))
        (bytes.fill-stride pcm (+ (* at 2) 1) count 2
                           (bit.and (bit.shr value 8) 255))
        pcm)))

(defn audio.wav-u32 (wav at value)
  (begin
    (u16! wav at (bit.and value 65535))
    (u16! wav (+ at 2) (/ value 65536))))

(defn audio.pcm-to-wav (pcm)
  (let ((data-length (bytes.length pcm)))
    (let ((wav (bytes.alloc (+ 44 data-length))))
      (begin
        ;; RIFF size WAVE fmt_ PCM mono 49716 Hz 16-bit data size.
        (u8! wav 0 82) (u8! wav 1 73) (u8! wav 2 70) (u8! wav 3 70)
        (audio.wav-u32 wav 4 (+ 36 data-length))
        (u8! wav 8 87) (u8! wav 9 65) (u8! wav 10 86) (u8! wav 11 69)
        (u8! wav 12 102) (u8! wav 13 109) (u8! wav 14 116) (u8! wav 15 32)
        (audio.wav-u32 wav 16 16)
        (u16! wav 20 1) (u16! wav 22 audio.PCM-CHANNELS)
        (audio.wav-u32 wav 24 audio.NORMALIZED-SAMPLE-RATE)
        (audio.wav-u32 wav 28 (* audio.NORMALIZED-SAMPLE-RATE 2))
        (u16! wav 32 2) (u16! wav 34 audio.PCM-BITS)
        (u8! wav 36 100) (u8! wav 37 97) (u8! wav 38 116) (u8! wav 39 97)
        (audio.wav-u32 wav 40 data-length)
        (bytes.copy wav 44 pcm 0 data-length)
        wav))))

(defn audio.pc-chunk-wav (chunk) (audio.pcm-to-wav (audio.pc-chunk-pcm chunk)))
(defn audio.digitized-wav (source) (audio.pcm-to-wav (audio.digitized-pcm source)))

(defn audio.mix-pcm! (target source start-sample)
  (audio.mix-pcm-at target source start-sample 0))

(defn audio.mix-pcm-at (target source start-sample index)
  (if (or (= index (audio.pcm-samples source))
          (>= (+ start-sample index) (audio.pcm-samples target)))
      target
      (let ((mixed (+ (i16@ target (* (+ start-sample index) 2))
                      (i16@ source (* index 2)))))
        (begin
          (audio.write-i16 target (* (+ start-sample index) 2)
            (cond ((> mixed 32767) 32767) ((< mixed -32768) -32768) (true mixed)))
          (audio.mix-pcm-at target source start-sample (+ index 1))))))
