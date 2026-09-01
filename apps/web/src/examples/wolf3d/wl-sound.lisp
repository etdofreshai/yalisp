;;; ID_SD.C / ID_SD.H / ID_SD_A.ASM sound manager, ported to YALisp.
;;;
;;; Wolf owns asset decoding, mode fallback, priority, one-shot positioning,
;;; 70/140/700 Hz timing, VSWAP page streaming, and IMF register sequencing.
;;; The host may consume normalized PCM/WAV bytes or the OPL register log; it
;;; must not reinterpret Wolf asset formats or silently substitute silence for
;;; AdLib synthesis.

(define sd.TickBase 70)
(define sd.sdm-Off 0)
(define sd.sdm-PC 1)
(define sd.sdm-AdLib 2)
(define sd.smm-Off 0)
(define sd.smm-AdLib 1)
(define sd.sds-Off 0)
(define sd.sds-PC 1)
(define sd.sds-SoundSource 2)
(define sd.sds-SoundBlaster 3)
(define sd.LASTSOUND 87)
(define sd.STARTPCSOUNDS 0)
(define sd.STARTADLIBSOUNDS 87)
(define sd.STARTDIGISOUNDS 174)
(define sd.STARTMUSIC 261)
(define sd.PMPageSize 4096)

(define sd.AdLibPresent 1)
(define sd.SoundSourcePresent 0)
(define sd.SoundBlasterPresent 1)
(define sd.SBProPresent 1)
(define sd.NeedsDigitized 0)
(define sd.NeedsMusic 0)
(define sd.SoundPositioned 0)
(define sd.SoundMode sd.sdm-Off)
(define sd.MusicMode sd.smm-Off)
(define sd.DigiMode sd.sds-Off)
(define sd.SoundNumber 0)
(define sd.DigiNumber 0)
(define sd.SoundPriority 0)
(define sd.DigiPriority 0)
(define sd.DigiPlaying 0)
(define sd.TimeCount 0)
(define sd.HackCount 0)
(define sd.cumulative-interrupts 0)
(define sd.TimerRate 140)
(define sd.count-time 0)
(define sd.count-fx 0)
(define sd.extreme-count 0)
(define sd.LeftPosition 0)
(define sd.RightPosition 0)
(define sd.AppliedLeftPosition 0)
(define sd.AppliedRightPosition 0)
(define sd.nextsoundpos 0)
(define sd.started 0)
(define sd.current-tick 0)
(define sd.sound-expires 0)
(define sd.sound-service-left 0)
(define sd.digi-expires 0)
(define sd.digi-uses-sound-lane 0)
(define sd.last-accepted 0)

(define sd.audiohed nil)
(define sd.audiot nil)
(define sd.vswap nil)
(define sd.vswap-chunks 0)
(define sd.vswap-sound-start 0)
(define sd.vswap-lengths-offset 0)
(define sd.digi-list-offset 0)
(define sd.digi-list-length 0)
(define sd.NumDigi 0)
(define sd.DigiMap (bytes.alloc 174))

(define sd.DigiLeft 0)
(define sd.DigiPage 0)
(define sd.DigiLength 0)
(define sd.DigiPlayed 0)
(define sd.DigiNextOffset 0)
(define sd.DigiNextLen 0)
(define sd.DigiMissed 0)
(define sd.DigiLastSegment 0)

(define sd.sqActive 0)
(define sd.sqHackStart 0)
(define sd.sqHackPtr 0)
(define sd.sqHackLen 0)
(define sd.sqHackSeqLen 0)
(define sd.sqHackTime 0)
(define sd.alTimeCount 0)
(define sd.music-number 0)
(define sd.music-register-events nil)
(define sd.music-register-event-count 0)
(define sd.music-service-count 0)

;;; SDL_ALPlaySound owns channel zero.  Keep its register traffic separate from
;;; IMF writes: effects run at 140 Hz while music runs at 700 Hz, and merging
;;; the two without an explicit rate would throw away source timing.
(define sd.al-sound-ptr 0)
(define sd.al-length-left 0)
(define sd.al-block 0)
(define sd.fx-service-count 0)
(define sd.adlib-register-events nil)
(define sd.adlib-register-event-count 0)
;;; Packed register-log storage ceilings, mirroring the audio-operation
;;; stores above: exactly 524,288 rows per stream, allocated lazily once
;;; and reused as-is across every later reset.  Adlib rows are 8 bytes
;;; (u32 140Hz-service, u8 register, u8 value); music rows are 12 bytes
;;; (u32 sequence-time, u8 register, u8 value, u32 host-service).
(define sd.ADLIB-REGISTER-ROW-BYTES 8)
(define sd.ADLIB-REGISTER-ROW-CAPACITY 524288)
(define sd.MUSIC-REGISTER-ROW-BYTES 12)
(define sd.MUSIC-REGISTER-ROW-CAPACITY 524288)
(define sd.adlib-register-store nil)
(define sd.music-register-store nil)

(define sd.audio-events nil)
(define sd.audio-event-count 0)
(define sd.AUDIO-EVENT-ROW-BYTES 16)
(define sd.AUDIO-EVENT-ROW-CAPACITY 65536)
(define sd.audio-event-store
  (bytes.alloc (* sd.AUDIO-EVENT-ROW-BYTES sd.AUDIO-EVENT-ROW-CAPACITY)))
;;; Every game-facing sound decision reaches SD through one of these explicit
;;; source boundaries. Packed logs store the ordinal and rebuild the symbol on
;;; export, avoiding one retained cons tree per live tick without making the
;;; diagnostic vocabulary implicit.
(define sd.audio-callsites
  '(GunAttack KnifeAttack Cmd_Use FirstSighting A_Slurpie A_DeathScream
    PlaySoundLocGlobal GetBonus GiveExtraMan R5Menu R0Menu intermission))
(define wl.AUDIO-EVENT-ROW-BYTES 8)
(define wl.AUDIO-EVENT-ROW-CAPACITY 65536)
(define wl.audio-event-store
  (bytes.alloc (* wl.AUDIO-EVENT-ROW-BYTES wl.AUDIO-EVENT-ROW-CAPACITY)))
(define sd.trace-start-tick 0)
(define sd.render-status 'idle)

;;; A single absolute host timeline spans every timer mode exactly: one 7000 Hz
;;; unit at 7000 Hz, ten at 700 Hz, and fifty at 140 Hz.  It is deliberately
;;; independent of the source-visible TimeCount lvalue, which menus may reset.
(define sd.AUDIO-TIMELINE-RATE 7000)
;;; YALisp exposes signed 31-bit immediate integers, so 2^30-1 is the largest
;;; positive counter value representable without wrapping through the ABI.
(define sd.AUDIO-OP-MAX 1073741823)
;;; Packed storage ceilings for the uniform audio-operation program: exactly
;;; 524,288 operation rows at 32 bytes and 65,536 native payload rows at
;;; 12 bytes.  The byte stores are allocated lazily once, then reused as-is
;;; across every later reset; allocation failures propagate unchanged.
(define sd.AUDIO-OP-ROW-BYTES 32)
(define sd.AUDIO-OP-ROW-CAPACITY 524288)
(define sd.AUDIO-NATIVE-ROW-BYTES 12)
(define sd.AUDIO-NATIVE-ROW-CAPACITY 65536)
(define sd.audio-timeline-units 0)
(define sd.audio-timeline-order 0)
(define sd.audio-operation-events nil)
(define sd.audio-operation-count 0)
(define sd.audio-native-payload-references nil)
(define sd.audio-native-payload-count 0)
(define sd.audio-native-next-id 0)
(define sd.audio-op-store nil)
(define sd.audio-native-store nil)

(defn sd.at (xs n) (if (= n 0) (car xs) (sd.at (cdr xs) (- n 1))))
(defn sd.min (a b) (if (< a b) a b))
(defn sd.max (a b) (if (> a b) a b))
(defn sd.ceil-div (n d) (/ (+ n (- d 1)) d))
(defn sd.reject (source) (u8@ source (bytes.length source)))

(defn sd.ensure-audio-stores ()
  (begin
    (if (nil? sd.audio-op-store)
        (set! sd.audio-op-store
          (bytes.alloc (* sd.AUDIO-OP-ROW-BYTES sd.AUDIO-OP-ROW-CAPACITY))))
    (if (nil? sd.audio-native-store)
        (set! sd.audio-native-store
          (bytes.alloc (* sd.AUDIO-NATIVE-ROW-BYTES
                         sd.AUDIO-NATIVE-ROW-CAPACITY))))
    true))

;;; Field-aware packed access into the 32-byte audio-operation rows shared
;;; by the audio operation program.  Widths follow each field's domain:
;;; f0/f1/f4 round-trip through u32!/i32@ (units, order, payload id), f2/f3
;;; and f11 are byte flags (kind, source, positioned), f5..f10 plus f12
;;; round-trip through u16!/i16@ (register, value, device modes, stereo
;;; positions, sound index); bytes 28..31 pad the row to the stride.  Any
;;; unknown field rejects through the shared out-of-bounds byte read.
(defn sd.audio-op-field! (row field value)
  (let ((base (* row sd.AUDIO-OP-ROW-BYTES)))
    (cond ((= field 0) (u32! sd.audio-op-store base value))
          ((= field 1) (u32! sd.audio-op-store (+ base 4) value))
          ((= field 2) (u8! sd.audio-op-store (+ base 8) value))
          ((= field 3) (u8! sd.audio-op-store (+ base 9) value))
          ((= field 4) (u32! sd.audio-op-store (+ base 10) value))
          ((= field 5) (u16! sd.audio-op-store (+ base 14) value))
          ((= field 6) (u16! sd.audio-op-store (+ base 16) value))
          ((= field 7) (u16! sd.audio-op-store (+ base 18) value))
          ((= field 8) (u16! sd.audio-op-store (+ base 20) value))
          ((= field 9) (u16! sd.audio-op-store (+ base 22) value))
          ((= field 10) (u16! sd.audio-op-store (+ base 24) value))
          ((= field 11) (u8! sd.audio-op-store (+ base 26) value))
          ((= field 12) (u16! sd.audio-op-store (+ base 27) value))
          (true (sd.reject sd.audio-op-store)))))
(defn sd.audio-op-field@ (row field)
  (let ((base (* row sd.AUDIO-OP-ROW-BYTES)))
    (cond ((= field 0) (i32@ sd.audio-op-store base))
          ((= field 1) (i32@ sd.audio-op-store (+ base 4)))
          ((= field 2) (u8@ sd.audio-op-store (+ base 8)))
          ((= field 3) (u8@ sd.audio-op-store (+ base 9)))
          ((= field 4) (i32@ sd.audio-op-store (+ base 10)))
          ((= field 5) (i16@ sd.audio-op-store (+ base 14)))
          ((= field 6) (i16@ sd.audio-op-store (+ base 16)))
          ((= field 7) (i16@ sd.audio-op-store (+ base 18)))
          ((= field 8) (i16@ sd.audio-op-store (+ base 20)))
          ((= field 9) (i16@ sd.audio-op-store (+ base 22)))
          ((= field 10) (i16@ sd.audio-op-store (+ base 24)))
          ((= field 11) (u8@ sd.audio-op-store (+ base 26)))
          ((= field 12) (i16@ sd.audio-op-store (+ base 27)))
          (true (sd.reject sd.audio-op-store)))))
(defn sd.audio-native-field! (row field value)
  (u32! sd.audio-native-store
        (+ (* row sd.AUDIO-NATIVE-ROW-BYTES) (* field 4)) value))
(defn sd.audio-native-field@ (row field)
  (i32@ sd.audio-native-store
        (+ (* row sd.AUDIO-NATIVE-ROW-BYTES) (* field 4))))

(defn sd.reset-audio-operation-log ()
  (begin
    (sd.ensure-audio-stores)
    (set! sd.audio-timeline-units 0) (set! sd.audio-timeline-order 0)
    (set! sd.audio-operation-events nil) (set! sd.audio-operation-count 0)
    (set! sd.audio-native-payload-references nil)
    (set! sd.audio-native-payload-count 0) (set! sd.audio-native-next-id 0)
    true))

;;; Rebuild oldest-to-newest rows directly from the packed stores and
;;; counts.  Both accumulators walk descending indices (count-1 down to 0)
;;; and cons each completed row onto the newer tail, so a single pass yields
;;; oldest-first order, matching the reverse of the former newest-first cons
;;; logs without retaining any list state between calls.
(defn sd.audio-op-row-fields (row field output)
  (if (< field 0) output
      (sd.audio-op-row-fields row (- field 1)
        (cons (sd.audio-op-field@ row field) output))))
(defn sd.audio-op-row (row) (sd.audio-op-row-fields row 12 nil))
(defn sd.audio-op-rows-accumulate (index output)
  (if (< index 0) output
      (sd.audio-op-rows-accumulate (- index 1)
        (cons (sd.audio-op-row index) output))))
(defn sd.audio-native-row-fields (row field output)
  (if (< field 0) output
      (sd.audio-native-row-fields row (- field 1)
        (cons (sd.audio-native-field@ row field) output))))
(defn sd.audio-native-row (row) (sd.audio-native-row-fields row 2 nil))
(defn sd.audio-native-rows-accumulate (index output)
  (if (< index 0) output
      (sd.audio-native-rows-accumulate (- index 1)
        (cons (sd.audio-native-row index) output))))
(defn sd.audio-operation-log ()
  (sd.audio-op-rows-accumulate (- sd.audio-operation-count 1) nil))
(defn sd.audio-native-payload-log ()
  (sd.audio-native-rows-accumulate (- sd.audio-native-payload-count 1) nil))
(defn sd.audio-operation-program ()
  (list sd.audio-timeline-units (sd.audio-operation-log)
        (sd.audio-native-payload-log)))

;;; Uniform operation rows are:
;;; (unit order kind source payload-id register value digi sbpro left right positioned sound)
;;; kind 1 is an OPL write; kind 2 is a native start. Native payload rows are
;;; (payload-id source reference), where reference is a PC sound or digi index.
(defn sd.record-opl-operation (source register value)
  (if (or (or (>= sd.audio-operation-count sd.AUDIO-OP-MAX)
              (>= sd.audio-operation-count sd.AUDIO-OP-ROW-CAPACITY))
          (>= sd.audio-timeline-order sd.AUDIO-OP-MAX))
      (sd.reject sd.audiot)
      (let ((row sd.audio-operation-count))
        (begin
          (sd.audio-op-field! row 0 sd.audio-timeline-units)
          (sd.audio-op-field! row 1 sd.audio-timeline-order)
          (sd.audio-op-field! row 2 1)
          (sd.audio-op-field! row 3 source)
          (sd.audio-op-field! row 4 -1)
          (sd.audio-op-field! row 5 register)
          (sd.audio-op-field! row 6 value)
          (sd.audio-op-field! row 7 -1)
          (sd.audio-op-field! row 8 -1)
          (sd.audio-op-field! row 9 -1)
          (sd.audio-op-field! row 10 -1)
          (sd.audio-op-field! row 11 0)
          (sd.audio-op-field! row 12 -1)
          (set! sd.audio-operation-count (+ sd.audio-operation-count 1))
          (set! sd.audio-timeline-order (+ sd.audio-timeline-order 1))
          true))))

(defn sd.record-native-operation (source reference sound left right positioned)
  (if (or (or (>= sd.audio-operation-count sd.AUDIO-OP-MAX)
              (>= sd.audio-operation-count sd.AUDIO-OP-ROW-CAPACITY))
          (or (>= sd.audio-timeline-order sd.AUDIO-OP-MAX)
              (or (or (>= sd.audio-native-payload-count sd.AUDIO-OP-MAX)
                      (>= sd.audio-native-payload-count sd.AUDIO-NATIVE-ROW-CAPACITY))
                  (>= sd.audio-native-next-id sd.AUDIO-OP-MAX))))
      (sd.reject sd.audiot)
      (let ((payload-id sd.audio-native-next-id))
        (begin
          (sd.audio-native-field! sd.audio-native-payload-count 0 payload-id)
          (sd.audio-native-field! sd.audio-native-payload-count 1 source)
          (sd.audio-native-field! sd.audio-native-payload-count 2 reference)
          (sd.audio-op-field! sd.audio-operation-count 0 sd.audio-timeline-units)
          (sd.audio-op-field! sd.audio-operation-count 1 sd.audio-timeline-order)
          (sd.audio-op-field! sd.audio-operation-count 2 2)
          (sd.audio-op-field! sd.audio-operation-count 3 source)
          (sd.audio-op-field! sd.audio-operation-count 4 payload-id)
          (sd.audio-op-field! sd.audio-operation-count 5 -1)
          (sd.audio-op-field! sd.audio-operation-count 6 -1)
          (sd.audio-op-field! sd.audio-operation-count 7 sd.DigiMode)
          (sd.audio-op-field! sd.audio-operation-count 8 sd.SBProPresent)
          (sd.audio-op-field! sd.audio-operation-count 9 left)
          (sd.audio-op-field! sd.audio-operation-count 10 right)
          (sd.audio-op-field! sd.audio-operation-count 11 positioned)
          (sd.audio-op-field! sd.audio-operation-count 12 sound)
          (set! sd.audio-native-next-id (+ sd.audio-native-next-id 1))
          (set! sd.audio-native-payload-count (+ sd.audio-native-payload-count 1))
          (set! sd.audio-operation-count (+ sd.audio-operation-count 1))
          (set! sd.audio-timeline-order (+ sd.audio-timeline-order 1))
          payload-id))))

(defn sd.ensure-native-operation-capacity ()
  (if (or (>= sd.audio-operation-count sd.AUDIO-OP-MAX)
          (or (>= sd.audio-timeline-order sd.AUDIO-OP-MAX)
              (or (>= sd.audio-native-payload-count sd.AUDIO-OP-MAX)
                  (>= sd.audio-native-next-id sd.AUDIO-OP-MAX))))
      (sd.reject sd.audiot)
      true))

(defn sd.advance-audio-timeline (rate)
  (let ((units (cond ((= rate 7000) 1) ((= rate 700) 10)
                     ((= rate 140) 50) (true -1))))
    (if (or (= units -1) (> sd.audio-timeline-units (- sd.AUDIO-OP-MAX units)))
        (sd.reject sd.audiot)
        (begin (set! sd.audio-timeline-units (+ sd.audio-timeline-units units))
               (set! sd.audio-timeline-order 0) true))))

(defn sd.configure-device-presence (adlib soundsource soundblaster sbpro)
  (begin
    (set! sd.AdLibPresent (if adlib 1 0))
    (set! sd.SoundSourcePresent (if soundsource 1 0))
    (set! sd.SoundBlasterPresent (if soundblaster 1 0))
    (set! sd.SBProPresent (if sbpro 1 0))
    true))

(defn sd.audio-offset (chunk)
  (if (and (>= chunk 0) (<= (+ (* chunk 4) 4) (bytes.length sd.audiohed)))
      (u32@ sd.audiohed (* chunk 4))
      (sd.reject sd.audiohed)))

(defn sd.chunk-start (chunk)
  (let ((start (sd.audio-offset chunk)) (end (sd.audio-offset (+ chunk 1))))
    (if (and (<= start end) (<= end (bytes.length sd.audiot))) start
        (sd.reject sd.audiot))))

(defn sd.chunk-end (chunk)
  (begin (sd.chunk-start chunk) (sd.audio-offset (+ chunk 1))))

(defn sd.vswap-page-offset (page)
  (if (and (>= page 0) (< page sd.vswap-chunks))
      (u32@ sd.vswap (+ 6 (* page 4)))
      (sd.reject sd.vswap)))

(defn sd.vswap-page-length (page)
  (if (and (>= page 0) (< page sd.vswap-chunks))
      (u16@ sd.vswap (+ sd.vswap-lengths-offset (* page 2)))
      (sd.reject sd.vswap)))

(defn sd.setup-digi-list ()
  (let ((page (- sd.vswap-chunks 1)))
    (let ((offset (sd.vswap-page-offset page)) (length (sd.vswap-page-length page)))
      (if (and (> length 0) (<= (+ offset length) (bytes.length sd.vswap)))
          (begin
            (set! sd.digi-list-offset offset)
            (set! sd.digi-list-length length)
            (set! sd.NumDigi (sd.count-digi 0 sd.vswap-sound-start 0))
            sd.NumDigi)
          (sd.reject sd.vswap)))))

(defn sd.count-digi (at page count)
  (if (or (> (+ at 4) sd.digi-list-length) (>= page (- sd.vswap-chunks 1)))
      count
      (let ((length (u16@ sd.vswap (+ sd.digi-list-offset (+ at 2)))))
        (if (= length 0)
            count
            (sd.count-digi (+ at 4) (+ page (sd.ceil-div length sd.PMPageSize))
                           (+ count 1))))))

(defn sd.digi-page (which)
  (if (and (>= which 0) (< which sd.NumDigi))
      (u16@ sd.vswap (+ sd.digi-list-offset (* which 4)))
      (sd.reject sd.vswap)))

(defn sd.digi-length (which)
  (if (and (>= which 0) (< which sd.NumDigi))
      (u16@ sd.vswap (+ sd.digi-list-offset (+ (* which 4) 2)))
      (sd.reject sd.vswap)))

(defn sd.digi-map! (sound sample) (u16! sd.DigiMap (* sound 2) sample))
(defn sd.digi-map@ (sound)
  (let ((value (u16@ sd.DigiMap (* sound 2)))) (if (= value 65535) -1 value)))

(defn sd.init-digi-map ()
  (begin
    (bytes.fill sd.DigiMap 0 174 255)
    (sd.digi-map! 21 0) (sd.digi-map! 41 1) (sd.digi-map! 19 2)
    (sd.digi-map! 18 3) (sd.digi-map! 26 4) (sd.digi-map! 24 5)
    (sd.digi-map! 11 6) (sd.digi-map! 51 7) (sd.digi-map! 55 8)
    (sd.digi-map! 50 9) (sd.digi-map! 59 10) (sd.digi-map! 60 11)
    (sd.digi-map! 29 12) (sd.digi-map! 22 13) (sd.digi-map! 25 13)
    (sd.digi-map! 16 14) (sd.digi-map! 46 15) (sd.digi-map! 56 20)
    (sd.digi-map! 58 21) (sd.digi-map! 61 22) (sd.digi-map! 72 32)
    (sd.digi-map! 10 16) (sd.digi-map! 52 17) (sd.digi-map! 53 18)
    (sd.digi-map! 54 19) (sd.digi-map! 62 23) (sd.digi-map! 63 24)
    (sd.digi-map! 64 25) (sd.digi-map! 65 26) (sd.digi-map! 66 27)
    (sd.digi-map! 67 28) (sd.digi-map! 68 29) (sd.digi-map! 40 30)
    (sd.digi-map! 70 31) (sd.digi-map! 57 33) (sd.digi-map! 73 34)
    (sd.digi-map! 74 35) (sd.digi-map! 79 36) (sd.digi-map! 80 37)
    (sd.digi-map! 81 38) (sd.digi-map! 75 39) (sd.digi-map! 76 40)
    (sd.digi-map! 77 41) (sd.digi-map! 78 42) (sd.digi-map! 82 43)
    (sd.digi-map! 83 44) (sd.digi-map! 84 45)
    true))

(defn sd.startup (audiohed audiot vswap)
  (if (or (nil? audiohed) (or (nil? audiot) (nil? vswap)))
      false
      (begin
        (set! sd.audiohed audiohed) (set! sd.audiot audiot) (set! sd.vswap vswap)
        (if (or (< (bytes.length audiohed) 8) (not (= (mod (bytes.length audiohed) 4) 0)))
            (sd.reject audiohed) nil)
        (if (< (bytes.length vswap) 12) (sd.reject vswap) nil)
        (set! sd.vswap-chunks (u16@ vswap 0))
        (set! sd.vswap-sound-start (u16@ vswap 4))
        (set! sd.vswap-lengths-offset (+ 6 (* sd.vswap-chunks 4)))
        (if (> (+ sd.vswap-lengths-offset (* sd.vswap-chunks 2)) (bytes.length vswap))
            (sd.reject vswap) nil)
        (sd.setup-digi-list)
        (sd.init-digi-map)
        (set! sd.TimeCount 0) (set! sd.HackCount 0) (set! sd.current-tick 0)
        (set! sd.cumulative-interrupts 0)
        (set! sd.count-time 0) (set! sd.count-fx 0) (set! sd.extreme-count 0)
        (set! sd.fx-service-count 0) (set! sd.al-sound-ptr 0)
        (set! sd.al-length-left 0) (set! sd.sound-service-left 0)
        (set! sd.al-block 0)
        (set! sd.SoundMode sd.sdm-Off) (set! sd.MusicMode sd.smm-Off)
        (set! sd.DigiMode sd.sds-Off) (set! sd.started 1)
        (sd.begin-audio-trace 0)
        true)))

(defn sd.shutdown ()
  (if (= sd.started 0) false
      (begin (sd.music-off) (sd.stop-sound) (sd.stop-digitized)
             (set! sd.SoundMode sd.sdm-Off) (set! sd.MusicMode sd.smm-Off)
             (set! sd.DigiMode sd.sds-Off) (set! sd.started 0) true)))

(defn sd.default (gotit sound music)
  (let ((use-sound (if (or (not gotit)
                            (and (= sound sd.sdm-AdLib) (= sd.AdLibPresent 0)))
                        (if (= sd.AdLibPresent 1) sd.sdm-AdLib sd.sdm-PC) sound)))
    (let ((use-music (if (or (not gotit)
                              (and (= music sd.smm-AdLib) (= sd.AdLibPresent 0)))
                          (if (= sd.AdLibPresent 1) sd.smm-AdLib sd.smm-Off) music)))
      (begin (sd.set-sound-mode use-sound) (sd.set-music-mode use-music) true))))

(defn sd.set-sound-mode (requested)
  (begin
    ;; Source order: every request first stops active sound, even invalid ones.
    (sd.stop-sound)
    (let ((mode (if (and (= requested sd.sdm-AdLib) (= sd.AdLibPresent 0))
                    sd.sdm-PC requested)))
      (if (or (= mode sd.sdm-Off) (or (= mode sd.sdm-PC)
                                      (and (= mode sd.sdm-AdLib) (= sd.AdLibPresent 1))))
          (begin (set! sd.SoundMode mode) (set! sd.NeedsDigitized 0)
                 (set! sd.TimerRate (sd.timer-rate)) true)
          false))))

(defn sd.set-music-mode (mode)
  (begin
    (sd.fade-out-music)
    (if (= mode sd.smm-Off)
        (begin (set! sd.NeedsMusic 0) (set! sd.MusicMode mode)
               (set! sd.TimerRate (sd.timer-rate)) true)
        (if (and (= mode sd.smm-AdLib) (= sd.AdLibPresent 1))
            (begin (set! sd.NeedsMusic 1) (set! sd.MusicMode mode)
                   (set! sd.TimerRate (sd.timer-rate)) true)
            false))))

(defn sd.set-digi-device (requested)
  (if (= requested sd.DigiMode)
      true
      (begin
        (sd.stop-digitized)
        (let ((mode (if (and (= requested sd.sds-SoundBlaster)
                             (= sd.SoundBlasterPresent 0))
                        (if (= sd.SoundSourcePresent 1) sd.sds-SoundSource -1)
                        requested)))
          (if (or (= mode sd.sds-Off) (or (= mode sd.sds-PC)
                    (or (and (= mode sd.sds-SoundSource) (= sd.SoundSourcePresent 1))
                        (and (= mode sd.sds-SoundBlaster) (= sd.SoundBlasterPresent 1)))))
              (begin (set! sd.DigiMode mode) (set! sd.TimerRate (sd.timer-rate)) true)
              false)))))

;;; WL_MENU.C exposes only Off/Sound Source/Sound Blaster as rows 0/1/2; the
;;; complete ID_SD.H device enum also contains sds_PC at 1. Keep the source
;;; enum intact and make that UI-to-manager translation explicit.
(defn sd.menu-digi-mode (menu-mode)
  (cond ((= menu-mode 0) sd.sds-Off)
        ((= menu-mode 1) sd.sds-SoundSource)
        ((= menu-mode 2) sd.sds-SoundBlaster)
        (true -1)))

(defn sd.set-menu-digi-device (menu-mode)
  (let ((mode (sd.menu-digi-mode menu-mode)))
    (if (= mode -1) false (sd.set-digi-device mode))))

(defn sd.timer-rate ()
  (if (and (= sd.DigiMode sd.sds-PC) (= sd.DigiPlaying 1))
      7000
      (if (or (= sd.MusicMode sd.smm-AdLib)
              (and (= sd.DigiMode sd.sds-SoundSource) (= sd.DigiPlaying 1)))
          700 140)))

(defn sd.position-sound (left right)
  (begin (set! sd.LeftPosition left) (set! sd.RightPosition right)
         (set! sd.nextsoundpos 1) true))

(defn sd.set-position (left right)
  (if (or (< left 0) (or (> left 15) (or (< right 0)
      (or (> right 15) (and (= left 15) (= right 15))))))
      (sd.reject sd.DigiMap)
      (begin (set! sd.AppliedLeftPosition left)
             (set! sd.AppliedRightPosition right) true)))

(defn sd.position-state ()
  (list sd.AppliedLeftPosition sd.AppliedRightPosition sd.SoundPositioned))

(defn sd.sound-chunk (sound)
  (+ (if (= sd.SoundMode sd.sdm-AdLib) sd.STARTADLIBSOUNDS sd.STARTPCSOUNDS) sound))

(defn sd.sound-common (sound field)
  (if (and (>= sound 0) (< sound sd.LASTSOUND))
      (let ((start (sd.chunk-start (sd.sound-chunk sound)))
            (end (sd.chunk-end (sd.sound-chunk sound))))
        (if (>= (- end start) 6)
            (if (= field 0) (u32@ sd.audiot start) (u16@ sd.audiot (+ start 4)))
            (sd.reject sd.audiot)))
      (sd.reject sd.audiot)))

(defn sd.sound-length (sound) (sd.sound-common sound 0))
(defn sd.sound-priority (sound) (sd.sound-common sound 1))

(defn sd.begin-audio-trace (tick)
  (begin
    (sd.stop-sound) (sd.stop-digitized)
    (set! sd.audio-events nil) (set! sd.audio-event-count 0)
    (sd.reset-adlib-register-events) (sd.reset-music-register-events)
    (sd.reset-audio-operation-log)
    (set! sd.trace-start-tick tick) (set! sd.current-tick tick)
    (set! sd.TimeCount tick) true))

(defn sd.audio-callsite-code-at (callsite names code)
  (if (nil? names)
      -1
      (if (eq? callsite (car names))
          code
          (sd.audio-callsite-code-at callsite (cdr names) (+ code 1)))))

(defn sd.audio-callsite-code (callsite)
  (let ((code (sd.audio-callsite-code-at callsite sd.audio-callsites 0)))
    (if (< code 0) (sd.reject sd.audiot) code)))

(defn sd.audio-callsite-name-at (code names)
  (if (or (< code 0) (nil? names))
      (sd.reject sd.audio-event-store)
      (if (= code 0)
          (car names)
          (sd.audio-callsite-name-at (- code 1) (cdr names)))))

(defn sd.audio-callsite-name (code)
  (sd.audio-callsite-name-at code sd.audio-callsites))

(defn sd.audio-event-offset (row)
  (* row sd.AUDIO-EVENT-ROW-BYTES))

(defn sd.record-event (sound source left right positioned callsite)
  (if (>= sd.audio-event-count sd.AUDIO-EVENT-ROW-CAPACITY)
      (sd.reject sd.audio-event-store)
      (let ((at (sd.audio-event-offset sd.audio-event-count))
            (callsite-code (sd.audio-callsite-code callsite)))
        (begin
          (u32! sd.audio-event-store at sd.current-tick)
          (u16! sd.audio-event-store (+ at 4) sound)
          (u8! sd.audio-event-store (+ at 6) sd.SoundMode)
          (u8! sd.audio-event-store (+ at 7) sd.DigiMode)
          (u8! sd.audio-event-store (+ at 8) source)
          (u8! sd.audio-event-store (+ at 9) left)
          (u8! sd.audio-event-store (+ at 10) right)
          (u8! sd.audio-event-store (+ at 11) positioned)
          (u8! sd.audio-event-store (+ at 12) sd.SBProPresent)
          (u16! sd.audio-event-store (+ at 14) callsite-code)
          (set! sd.audio-event-count (+ sd.audio-event-count 1))
          true))))

(defn sd.audio-host-event-row (row)
  (let ((at (sd.audio-event-offset row)))
    (list (i32@ sd.audio-event-store at)
          (u16@ sd.audio-event-store (+ at 4))
          (u8@ sd.audio-event-store (+ at 6))
          (u8@ sd.audio-event-store (+ at 7))
          (u8@ sd.audio-event-store (+ at 8))
          (u8@ sd.audio-event-store (+ at 9))
          (u8@ sd.audio-event-store (+ at 10))
          (u8@ sd.audio-event-store (+ at 11))
          (u8@ sd.audio-event-store (+ at 12))
          (sd.audio-callsite-name (u16@ sd.audio-event-store (+ at 14))))))

(defn sd.audio-event-row (row)
  (let ((at (sd.audio-event-offset row)))
    (list (i32@ sd.audio-event-store at)
          (u16@ sd.audio-event-store (+ at 4))
          (u8@ sd.audio-event-store (+ at 6))
          (u8@ sd.audio-event-store (+ at 8))
          (u8@ sd.audio-event-store (+ at 9))
          (u8@ sd.audio-event-store (+ at 10))
          (u8@ sd.audio-event-store (+ at 11))
          (sd.audio-callsite-name (u16@ sd.audio-event-store (+ at 14))))))

(defn sd.audio-host-event-rows (index output)
  (if (< index 0)
      output
      (sd.audio-host-event-rows (- index 1)
        (cons (sd.audio-host-event-row index) output))))

(defn sd.audio-event-rows (index output)
  (if (< index 0)
      output
      (sd.audio-event-rows (- index 1)
        (cons (sd.audio-event-row index) output))))

;;; The internal record stores host-only device metadata once. Preserve the
;;; established eight-field comparison API through a projection at export.
(defn sd.audio-event-log ()
  (sd.audio-event-rows (- sd.audio-event-count 1) nil))
(defn sd.audio-host-event-log ()
  (sd.audio-host-event-rows (- sd.audio-event-count 1) nil))

;;; Lazy one-time allocation of the packed register stores, mirroring
;;; sd.ensure-audio-stores: each byte store is allocated only while nil,
;;; so later resets reuse it as-is and allocation failures propagate
;;; unchanged.
(defn sd.ensure-register-stores ()
  (begin
    (if (nil? sd.adlib-register-store)
        (set! sd.adlib-register-store
          (bytes.alloc (* sd.ADLIB-REGISTER-ROW-BYTES
                          sd.ADLIB-REGISTER-ROW-CAPACITY))))
    (if (nil? sd.music-register-store)
        (set! sd.music-register-store
          (bytes.alloc (* sd.MUSIC-REGISTER-ROW-BYTES
                          sd.MUSIC-REGISTER-ROW-CAPACITY))))
    true))

;;; Packed field access for the adlib register store (stride 8):
;;; u32 140Hz-service at +0, u8 register at +4, u8 value at +5.  The u32
;;; service field round-trips signed via u32!/i32@ like the op-store fields.
(defn sd.adlib-register-service! (row value)
  (u32! sd.adlib-register-store
        (* row sd.ADLIB-REGISTER-ROW-BYTES) value))
(defn sd.adlib-register-service@ (row)
  (i32@ sd.adlib-register-store
        (* row sd.ADLIB-REGISTER-ROW-BYTES)))
(defn sd.adlib-register-reg! (row value)
  (u8! sd.adlib-register-store
       (+ (* row sd.ADLIB-REGISTER-ROW-BYTES) 4) value))
(defn sd.adlib-register-reg@ (row)
  (u8@ sd.adlib-register-store
       (+ (* row sd.ADLIB-REGISTER-ROW-BYTES) 4)))
(defn sd.adlib-register-value! (row value)
  (u8! sd.adlib-register-store
       (+ (* row sd.ADLIB-REGISTER-ROW-BYTES) 5) value))
(defn sd.adlib-register-value@ (row)
  (u8@ sd.adlib-register-store
       (+ (* row sd.ADLIB-REGISTER-ROW-BYTES) 5)))

;;; Packed field access for the music register store (stride 12): u32
;;; sequence-time at +0, u8 register at +4, u8 value at +5, u32 host-service
;;; at +8.  Both u32 fields round-trip signed via u32!/i32@.
(defn sd.music-register-time! (row value)
  (u32! sd.music-register-store
        (* row sd.MUSIC-REGISTER-ROW-BYTES) value))
(defn sd.music-register-time@ (row)
  (i32@ sd.music-register-store
        (* row sd.MUSIC-REGISTER-ROW-BYTES)))
(defn sd.music-register-reg! (row value)
  (u8! sd.music-register-store
       (+ (* row sd.MUSIC-REGISTER-ROW-BYTES) 4) value))
(defn sd.music-register-reg@ (row)
  (u8@ sd.music-register-store
       (+ (* row sd.MUSIC-REGISTER-ROW-BYTES) 4)))
(defn sd.music-register-value! (row value)
  (u8! sd.music-register-store
       (+ (* row sd.MUSIC-REGISTER-ROW-BYTES) 5) value))
(defn sd.music-register-value@ (row)
  (u8@ sd.music-register-store
       (+ (* row sd.MUSIC-REGISTER-ROW-BYTES) 5)))
(defn sd.music-register-host-service! (row value)
  (u32! sd.music-register-store
        (+ (* row sd.MUSIC-REGISTER-ROW-BYTES) 8) value))
(defn sd.music-register-host-service@ (row)
  (i32@ sd.music-register-store
        (+ (* row sd.MUSIC-REGISTER-ROW-BYTES) 8)))

(defn sd.reset-adlib-register-events ()
  (begin (sd.ensure-register-stores)
         (set! sd.adlib-register-events nil)
         (set! sd.adlib-register-event-count 0) true))

(defn sd.adlib-register-log-rows (index output)
  (if (< index 0) output
      (sd.adlib-register-log-rows (- index 1)
        (cons (list (sd.adlib-register-service@ index)
                    (sd.adlib-register-reg@ index)
                    (sd.adlib-register-value@ index))
              output))))

;;; Rows are rebuilt oldest-to-newest from the packed store via descending
;;; tail-recursive accumulation, mirroring sd.audio-op-rows-accumulate.
(defn sd.adlib-register-log ()
  (sd.adlib-register-log-rows (- sd.adlib-register-event-count 1) nil))

;;; Each entry is (140Hz-service register value). Writes made by Play/Stop occur
;;; at the current service boundary; row order preserves multiple writes there.
(defn sd.adlib-out (register value)
  (if (>= sd.adlib-register-event-count sd.ADLIB-REGISTER-ROW-CAPACITY)
      (sd.reject sd.audiot)
      (let ((row sd.adlib-register-event-count))
        (begin
          (sd.record-opl-operation 2 register value)
          (sd.adlib-register-service! row sd.fx-service-count)
          (sd.adlib-register-reg! row register)
          (sd.adlib-register-value! row value)
          (set! sd.adlib-register-event-count (+ sd.adlib-register-event-count 1))
          true))))

(defn sd.adlib-set-fx-inst (start)
  (begin
    ;; SDL_AlSetFXInst writes all modifier fields, then all carrier fields.
    ;; alZeroInst is represented by start=-1; alFeedCon is always zero because
    ;; the original MUSE-compatibility build comments out inst->nConn.
    (sd.adlib-out 32  (if (= start -1) 0 (u8@ sd.audiot (+ start 6))))
    (sd.adlib-out 64  (if (= start -1) 0 (u8@ sd.audiot (+ start 8))))
    (sd.adlib-out 96  (if (= start -1) 0 (u8@ sd.audiot (+ start 10))))
    (sd.adlib-out 128 (if (= start -1) 0 (u8@ sd.audiot (+ start 12))))
    (sd.adlib-out 224 (if (= start -1) 0 (u8@ sd.audiot (+ start 14))))
    (sd.adlib-out 35  (if (= start -1) 0 (u8@ sd.audiot (+ start 7))))
    (sd.adlib-out 67  (if (= start -1) 0 (u8@ sd.audiot (+ start 9))))
    (sd.adlib-out 99  (if (= start -1) 0 (u8@ sd.audiot (+ start 11))))
    (sd.adlib-out 131 (if (= start -1) 0 (u8@ sd.audiot (+ start 13))))
    (sd.adlib-out 227 (if (= start -1) 0 (u8@ sd.audiot (+ start 15))))
    (sd.adlib-out 192 0)
    true))

(defn sd.stop-adlib-sound ()
  (begin
    (set! sd.al-sound-ptr 0) (set! sd.al-length-left 0)
    (sd.adlib-out 176 0) true))

(defn sd.start-adlib-sound (sound)
  (let ((start (sd.chunk-start (+ sd.STARTADLIBSOUNDS sound)))
        (end (sd.chunk-end (+ sd.STARTADLIBSOUNDS sound))))
    (let ((length (u32@ sd.audiot start)))
      (if (or (< (- end start) 23) (> (+ start 23 length) end))
          (sd.reject sd.audiot)
          (begin
            (sd.stop-adlib-sound)
            ;; SDL_ALPlaySound rejects instruments with no sustain on either cell.
            (if (= (bit.or (u8@ sd.audiot (+ start 12))
                           (u8@ sd.audiot (+ start 13))) 0)
                (sd.reject sd.audiot) nil)
            (set! sd.al-length-left length)
            (set! sd.al-sound-ptr (+ start 23))
            (set! sd.al-block (+ (* (bit.and (u8@ sd.audiot (+ start 22)) 7) 4) 32))
            (sd.adlib-set-fx-inst -1)
            (sd.adlib-set-fx-inst start)
            true)))))

(defn sd.play-sound (sound callsite)
  (let ((left sd.LeftPosition) (right sd.RightPosition) (positioned sd.nextsoundpos))
    (begin
      ;; Source consumes the queued position before all rejection paths.
      (set! sd.LeftPosition 0) (set! sd.RightPosition 0) (set! sd.nextsoundpos 0)
      (set! sd.last-accepted 0)
      (if (= sound -1)
          false
          (let ((priority (sd.sound-priority sound)) (digi (sd.digi-map@ sound)))
            (if (and (not (= sd.DigiMode sd.sds-Off)) (not (= digi -1)))
                (sd.play-mapped-digitized sound digi priority left right positioned callsite)
                (sd.play-synthesized sound priority left right positioned callsite)))))))

(defn sd.play-mapped-digitized (sound which priority left right positioned callsite)
  (let ((shared (and (= sd.DigiMode sd.sds-PC) (= sd.SoundMode sd.sdm-PC))))
    (if (< priority (if shared sd.SoundPriority sd.DigiPriority))
        false
        (begin
          (sd.ensure-native-operation-capacity)
          (if shared (sd.stop-sound) nil)
          (sd.play-digitized which left right)
          (set! sd.SoundPositioned positioned)
          (if shared
              (begin (set! sd.digi-uses-sound-lane 1) (set! sd.SoundNumber sound)
                     (set! sd.SoundPriority priority))
              (begin (set! sd.digi-uses-sound-lane 0) (set! sd.DigiNumber sound)
                     (set! sd.DigiPriority priority)))
          (set! sd.last-accepted 1)
          (sd.record-native-operation 3 which sound left right positioned)
          (sd.record-event sound 3 left right positioned callsite)
          true))))

(defn sd.play-synthesized (sound priority left right positioned callsite)
  (if (= sd.SoundMode sd.sdm-Off)
      false
      (let ((length (sd.sound-length sound)))
        (if (= length 0)
            (sd.reject sd.audiot)
            (if (< priority sd.SoundPriority)
                false
                (begin
                  (if (= sd.SoundMode sd.sdm-PC)
                      (sd.ensure-native-operation-capacity) nil)
                  (if (= sd.SoundMode sd.sdm-AdLib)
                      (sd.start-adlib-sound sound) nil)
                  (set! sd.SoundNumber sound) (set! sd.SoundPriority priority)
                  (set! sd.sound-service-left length)
                  (set! sd.sound-expires (+ sd.current-tick (sd.ceil-div length 2)))
                  (set! sd.SoundPositioned 0) (set! sd.last-accepted 1)
                  (if (= sd.SoundMode sd.sdm-PC)
                      (sd.record-native-operation 1 sound sound left right positioned) nil)
                  (sd.record-event sound
                    (if (= sd.SoundMode sd.sdm-PC) 1 2) left right positioned callsite)
                  ;; ID_SD.C returns false for synthesized playback; retain it.
                  false))))))

(defn sd.sound-playing ()
  (if (> sd.SoundPriority 0) sd.SoundNumber 0))

(defn sd.stop-sound ()
  (begin
    (if (= sd.DigiPlaying 1) (sd.stop-digitized) nil)
    (if (= sd.SoundMode sd.sdm-AdLib) (sd.stop-adlib-sound) nil)
    (set! sd.SoundNumber 0) (set! sd.SoundPriority 0) (set! sd.sound-expires 0)
    (set! sd.sound-service-left 0)
    (set! sd.SoundPositioned 0) true))

(defn sd.wait-sound-done ()
  ;; The DOS busy loop never manufactures a completion or lowers priority: the
  ;; timer ISR keeps running until its synthesized sound lane clears itself.
  (if (> sd.SoundPriority 0)
      (begin (sd.service-timer-interrupt) (sd.wait-sound-done))
      true))

(defn sd.play-digitized (which left right)
  (if (= sd.DigiMode sd.sds-Off)
      false
      (begin
        (sd.stop-digitized)
        (sd.set-position left right)
        (set! sd.DigiPage (sd.digi-page which))
        (set! sd.DigiLength (sd.digi-length which))
        (set! sd.DigiLeft sd.DigiLength)
        (set! sd.DigiPlayed (sd.min sd.DigiLeft sd.PMPageSize))
        (set! sd.DigiLeft (- sd.DigiLeft sd.DigiPlayed))
        (set! sd.DigiPage (+ sd.DigiPage 1))
        (set! sd.DigiPlaying 1) (set! sd.DigiLastSegment (if (= sd.DigiLeft 0) 1 0))
        (set! sd.digi-expires (+ sd.current-tick
          (sd.max 1 (sd.ceil-div (* sd.DigiLength 9940) 1000000))))
        (sd.poll)
        true)))

(defn sd.poll ()
  (begin
    (if (and (> sd.DigiLeft 0) (= sd.DigiNextLen 0))
        (begin
          (set! sd.DigiNextOffset sd.DigiPlayed)
          (set! sd.DigiNextLen (sd.min sd.DigiLeft sd.PMPageSize))
          (set! sd.DigiLeft (- sd.DigiLeft sd.DigiNextLen))
          (set! sd.DigiPage (+ sd.DigiPage 1))
          (if (= sd.DigiLeft 0) (set! sd.DigiLastSegment 1) nil))
        nil)
    (if (and (= sd.DigiMissed 1) (> sd.DigiNextLen 0))
        (begin
          (set! sd.DigiPlayed (+ sd.DigiPlayed sd.DigiNextLen))
          (set! sd.DigiNextLen 0) (set! sd.DigiMissed 0)
          (if (= sd.DigiLastSegment 1) (set! sd.DigiPlaying 0) nil))
        nil)
    (set! sd.TimerRate (sd.timer-rate))
    true))

(defn sd.digitized-done ()
  (if (> sd.DigiNextLen 0)
      (begin (set! sd.DigiPlayed (+ sd.DigiPlayed sd.DigiNextLen))
             (set! sd.DigiNextLen 0) (set! sd.DigiMissed 0) true)
      (if (= sd.DigiLastSegment 1)
          (begin (sd.finish-digitized) true)
          (begin (set! sd.DigiMissed 1) false))))

(defn sd.finish-digitized ()
  (begin
    (set! sd.DigiPlaying 0) (set! sd.DigiNumber 0) (set! sd.DigiPriority 0)
    (set! sd.digi-expires 0) (set! sd.DigiLastSegment 0)
    (set! sd.DigiNextLen 0) (set! sd.DigiLeft 0)
    (if (= sd.digi-uses-sound-lane 1)
        (begin (set! sd.SoundNumber 0) (set! sd.SoundPriority 0)
               (set! sd.sound-expires 0) (set! sd.sound-service-left 0)) nil)
    (set! sd.digi-uses-sound-lane 0) (set! sd.SoundPositioned 0) true))

(defn sd.stop-digitized ()
  (begin
    (set! sd.DigiLeft 0) (set! sd.DigiNextLen 0) (set! sd.DigiMissed 0)
    (set! sd.DigiLastSegment 0) (sd.finish-digitized) true))

(defn sd.digi-stream-state ()
  (if (= sd.DigiPlaying 0) nil
      (list sd.DigiNumber sd.DigiLength sd.DigiPlayed sd.DigiNextOffset
            sd.DigiNextLen sd.DigiMissed sd.DigiLastSegment)))

(defn sd.expire-digitized-deadline ()
  (begin
    (if (and (> sd.digi-expires 0) (>= sd.current-tick sd.digi-expires))
        (sd.finish-digitized) nil)
    true))

(defn sd.set-tick (tick)
  (if (< tick sd.current-tick)
      false
      (begin
        (set! sd.current-tick tick) (set! sd.TimeCount tick)
        true)))

;;; Menu waits reset the original public TimeCount lvalue, but that must not
;;; rewind sound lifetime or the interrupt history.  Those remain monotonic.
(defn sd.reset-time-count () (begin (set! sd.TimeCount 0) true))

(defn sd.service-source-tick ()
  (begin
    (set! sd.current-tick (+ sd.current-tick 1))
    (set! sd.TimeCount (+ sd.TimeCount 1))
    ;; Synthesized priority is cleared only by service-sound-effects.  This
    ;; derived deadline belongs solely to the separately streamed digi lane.
    (sd.expire-digitized-deadline)))

(defn sd.music-off () (begin (set! sd.sqActive 0) true))
(defn sd.music-on ()
  (if (= sd.MusicMode sd.smm-AdLib) (begin (set! sd.sqActive 1) true) false))
(defn sd.fade-out-music () (sd.music-off))
(defn sd.music-playing () (= sd.sqActive 1))

(defn sd.start-music (music callsite)
  (begin
    (sd.music-off)
    (if (or (< music 0) (>= (+ sd.STARTMUSIC music 1)
                            (/ (bytes.length sd.audiohed) 4)))
        (sd.reject sd.audiohed)
        (let ((start (sd.chunk-start (+ sd.STARTMUSIC music)))
              (end (sd.chunk-end (+ sd.STARTMUSIC music))))
          (let ((length (u16@ sd.audiot start)))
            (if (or (not (= (mod length 4) 0)) (> (+ start 2 length) end))
                (sd.reject sd.audiot)
                (begin
                  (set! sd.music-number music) (set! sd.sqHackStart (+ start 2))
                  (set! sd.sqHackPtr (+ start 2)) (set! sd.sqHackSeqLen length)
                  (set! sd.sqHackLen length) (set! sd.sqHackTime 0)
                  (set! sd.alTimeCount 0)
                  (if (= sd.MusicMode sd.smm-AdLib)
                      (begin (sd.music-on) (sd.record-event music 4 0 0 0 callsite) true)
                      false))))))))

(defn sd.reset-music-register-events ()
  (begin (sd.ensure-register-stores)
         (set! sd.music-register-events nil)
         (set! sd.music-register-event-count 0)
         (set! sd.music-service-count 0) true))

(defn sd.music-register-log-rows (index output)
  (if (< index 0) output
      (sd.music-register-log-rows (- index 1)
        (cons (list (sd.music-register-time@ index)
                    (sd.music-register-reg@ index)
                    (sd.music-register-value@ index))
              output))))

(defn sd.music-host-register-log-rows (index output)
  (if (< index 0) output
      (sd.music-host-register-log-rows (- index 1)
        (cons (list (sd.music-register-host-service@ index)
                    (sd.music-register-reg@ index)
                    (sd.music-register-value@ index))
              output))))

;;; Existing IMF comparisons use the sequence-relative clock in field zero.
;;; The host projection uses a monotonic service clock in field three so a
;;; persistent OPL sink crosses IMF loops without resetting chip state.
;;; Both logs rebuild oldest-to-newest as exact three-field rows from the
;;; packed store via descending tail-recursive accumulation, mirroring
;;; sd.adlib-register-log-rows.
(defn sd.music-register-log ()
  (sd.music-register-log-rows (- sd.music-register-event-count 1) nil))
(defn sd.music-host-register-log ()
  (sd.music-host-register-log-rows (- sd.music-register-event-count 1) nil))

(defn sd.service-music ()
  (if (= sd.sqActive 0)
      false
      (begin
        (sd.service-music-due)
        (set! sd.alTimeCount (+ sd.alTimeCount 1))
        (set! sd.music-service-count (+ sd.music-service-count 1))
        (if (= sd.sqHackLen 0)
            (begin (set! sd.sqHackPtr sd.sqHackStart)
                   (set! sd.sqHackLen sd.sqHackSeqLen)
                   (set! sd.alTimeCount 0) (set! sd.sqHackTime 0)) nil)
        true)))

(defn sd.service-music-due ()
  (if (or (= sd.sqHackLen 0) (> sd.sqHackTime sd.alTimeCount))
      true
      (if (>= sd.music-register-event-count sd.MUSIC-REGISTER-ROW-CAPACITY)
          (sd.reject sd.audiot)
          (let ((register (u8@ sd.audiot sd.sqHackPtr))
                (value (u8@ sd.audiot (+ sd.sqHackPtr 1)))
                (delay (u16@ sd.audiot (+ sd.sqHackPtr 2))))
            (begin
              (sd.record-opl-operation 4 register value)
              (let ((row sd.music-register-event-count))
                (begin
                  (sd.music-register-time! row sd.alTimeCount)
                  (sd.music-register-reg! row register)
                  (sd.music-register-value! row value)
                  (sd.music-register-host-service! row sd.music-service-count)
                  (set! sd.music-register-event-count
                    (+ sd.music-register-event-count 1))))
              (set! sd.sqHackTime (+ sd.alTimeCount delay))
              (set! sd.sqHackPtr (+ sd.sqHackPtr 4))
              (set! sd.sqHackLen (- sd.sqHackLen 4))
              (sd.service-music-due))))))

;;; DOFX in ID_SD_A.ASM executes this lane once per 140 Hz service regardless
;;; of whether timer zero is currently programmed for 140, 700, or 7000 Hz.
(defn sd.service-sound-effects ()
  (begin
    (if (> sd.sound-service-left 0)
        (begin
          (if (> sd.al-length-left 0)
              (let ((sample (u8@ sd.audiot sd.al-sound-ptr)))
                (begin
                  (if (= sample 0)
                      (sd.adlib-out 176 0)
                      (begin (sd.adlib-out 160 sample)
                             (sd.adlib-out 176 sd.al-block)))
                  (set! sd.al-sound-ptr (+ sd.al-sound-ptr 1))
                  (set! sd.al-length-left (- sd.al-length-left 1)))) nil)
          (set! sd.sound-service-left (- sd.sound-service-left 1))
          (if (= sd.sound-service-left 0)
              (begin
                (set! sd.al-sound-ptr 0) (set! sd.al-length-left 0)
                (set! sd.SoundNumber 0) (set! sd.SoundPriority 0)
                (set! sd.sound-expires 0)
                ;; The ASM performs a second key-off after the final byte.
                (if (= sd.SoundMode sd.sdm-AdLib) (sd.adlib-out 176 0) nil)) nil)) nil)
    (set! sd.fx-service-count (+ sd.fx-service-count 1))
    true))

(defn sd.service-timer-interrupt ()
  (let ((rate (sd.timer-rate)))
    (begin
      (sd.advance-audio-timeline rate)
      (set! sd.HackCount (+ sd.HackCount 1))
      (set! sd.cumulative-interrupts (+ sd.cumulative-interrupts 1))
        (cond ((= rate 7000)
             (begin
               (set! sd.extreme-count (+ sd.extreme-count 1))
               (if (= sd.extreme-count 10)
                   (begin (set! sd.extreme-count 0) (sd.service-fast-timer)) nil)))
              ((= rate 700) (sd.service-fast-timer))
              (true (sd.service-slow-timer)))
      true)))

(defn sd.service-fast-timer ()
  (begin
    (set! sd.count-fx (+ sd.count-fx 1))
    (if (= sd.count-fx 5)
        (begin (set! sd.count-fx 0) (sd.service-sound-effects)
               (set! sd.count-time (+ sd.count-time 1))
               (sd.service-time)) nil)
    (if (= sd.MusicMode sd.smm-AdLib) (sd.service-music) nil)
    true))

(defn sd.service-slow-timer ()
  ;; DOFX owns the current 140 Hz byte.  Only after it has been consumed may
  ;; the paired 70 Hz time service observe a derived device deadline.
  (begin (sd.service-sound-effects)
         (set! sd.count-time (+ sd.count-time 1)) (sd.service-time) true))

(defn sd.service-time ()
  (if (< sd.count-time 2)
      false
      (begin (set! sd.count-time 0) (sd.service-source-tick))))

(defn sd.advance-timer (interrupts)
  (if (<= interrupts 0) (= interrupts 0)
      (begin (sd.service-reclaimable-interrupt (heap.used) sd.audio-event-count)
             (sd.advance-timer (- interrupts 1)))))

;;; Advance relative 70 Hz source time through the actual currently programmed
;;; timer.  Stopping at the target tick (rather than multiplying once by the
;;; initial rate) preserves partial 140/700 Hz cadence and survives a rate
;;; change caused by an ISR completion.
(defn sd.advance-source-tics (tics)
  (if (< tics 0)
      false
      (sd.advance-source-tics-until (+ sd.current-tick tics))))

(defn sd.service-reclaimable-interrupt (mark events)
  ;; One interrupt bounded by a heap mark taken by the caller. The operation,
  ;; native payload, adlib-register, and music-register logs are now packed
  ;; mutable stores, so their changing counters no longer indicate heap
  ;; escapes; only the remaining cons-backed audio-events log proves heap
  ;; stability. The allocation is released iff sd.audio-event-count is
  ;; unchanged; ordering and tick cadence are otherwise identical.
  (begin
    (sd.service-timer-interrupt)
    (if (= sd.audio-event-count events)
        (heap.release mark)
        nil)
    true))

(defn sd.advance-source-tics-until (target)
  (if (>= sd.current-tick target)
      true
      (begin (sd.service-reclaimable-interrupt (heap.used)
                                               sd.audio-event-count)
             (sd.advance-source-tics-until target))))

(defn sd.digitized-bytes (which)
  (let ((length (sd.digi-length which)))
    (let ((output (bytes.alloc length)))
      (begin (sd.copy-digi-pages output 0 (sd.digi-page which) length) output))))

(defn sd.copy-digi-pages (output write-at page remaining)
  (if (= remaining 0)
      output
      (let ((absolute (+ sd.vswap-sound-start page)))
        (let ((offset (sd.vswap-page-offset absolute))
              (length (sd.vswap-page-length absolute)))
          (let ((take (sd.min remaining length)))
            (if (or (= take 0) (> (+ offset take) (bytes.length sd.vswap)))
                (sd.reject sd.vswap)
                (begin
                  (bytes.copy output write-at sd.vswap offset take)
                  (sd.copy-digi-pages output (+ write-at take) (+ page 1)
                                      (- remaining take)))))))))

(defn sd.render-pc-pcm (sound)
  (let ((chunk (+ sd.STARTPCSOUNDS sound)))
    (let ((start (sd.chunk-start chunk)) (end (sd.chunk-end chunk)))
      (if (and (>= (- end start) 6)
               (<= (+ start 6 (u32@ sd.audiot start)) end))
          (audio.pc-pcm-source sd.audiot (+ start 6) (u32@ sd.audiot start))
          (sd.reject sd.audiot)))))

(defn sd.render-pc-wav (sound) (audio.pcm-to-wav (sd.render-pc-pcm sound)))
(defn sd.render-digitized-pcm (which) (audio.digitized-pcm (sd.digitized-bytes which)))
(defn sd.render-digitized-wav (which)
  (audio.pcm-to-wav (sd.render-digitized-pcm which)))

(defn sd.render-adlib-pcm (sound)
  (begin (set! sd.render-status 'adlib-opl-host-required) nil))
(defn sd.render-music-pcm (music)
  (begin (set! sd.render-status 'adlib-opl-host-required) nil))

(defn sd.audio-capabilities ()
  '(audio-contract (pcm-rate 49716) (channels 1) (bits 16)
    (pc-speaker native-pcm) (digitized native-pcm)
    (adlib opl-register-log) (music opl-register-log)
    (position normalized-event-only)))

(defn sd.render-event-pcm (ticks)
  (if (< ticks 1)
      false
      (let ((pcm (bytes.alloc (* (/ (* ticks audio.NORMALIZED-SAMPLE-RATE) sd.TickBase) 2))))
        (begin
          ;; bytes.alloc intentionally exposes reused heap bytes. A mix target
          ;; is source silence before its first event, so initialize it here.
          (bytes.fill pcm 0 (bytes.length pcm) 0)
          (set! sd.render-status 'ok)
          (sd.render-events-at (sd.audio-event-log) pcm)))))

(defn sd.render-events-at (events pcm)
  (if (nil? events)
      pcm
      (let ((event (car events)))
        (let ((tick (sd.at event 0)) (sound (sd.at event 1)) (source (sd.at event 3)))
          (let ((rendered
                  (cond ((= source 1) (sd.render-pc-pcm sound))
                        ((= source 3) (sd.render-digitized-pcm (sd.digi-map@ sound)))
                        (true (begin (set! sd.render-status 'adlib-opl-host-required) nil)))))
            (if (nil? rendered)
                nil
                (begin
                  (audio.mix-pcm! pcm rendered
                    (/ (* (- tick sd.trace-start-tick) audio.NORMALIZED-SAMPLE-RATE)
                       sd.TickBase))
                  (sd.render-events-at (cdr events) pcm))))))))

(defn sd.render-event-wav (ticks)
  (let ((pcm (sd.render-event-pcm ticks)))
    (if (nil? pcm) nil (audio.pcm-to-wav pcm))))

;;; Compatibility boundary for existing WL_AGENT.C-shaped game callers. Before
;;; mounted audio assets exist it retains the prior deterministic decision log;
;;; after startup it records only manager-accepted calls in that public log.
(defn wl.audio-event-offset (row)
  (* row wl.AUDIO-EVENT-ROW-BYTES))

(defn wl.reset-audio-events ()
  (begin (set! wl.audio-events nil) (set! wl.audio-event-count 0)))

(defn wl.record-audio-event (tick sound source)
  (if (>= wl.audio-event-count wl.AUDIO-EVENT-ROW-CAPACITY)
      (sd.reject wl.audio-event-store)
      (let ((at (wl.audio-event-offset wl.audio-event-count))
            (source-code (sd.audio-callsite-code source)))
        (begin
          (u32! wl.audio-event-store at tick)
          (u16! wl.audio-event-store (+ at 4) sound)
          (u16! wl.audio-event-store (+ at 6) source-code)
          (set! wl.audio-event-count (+ wl.audio-event-count 1))
          true))))

(defn wl.audio-event-row (row)
  (let ((at (wl.audio-event-offset row)))
    (list (i32@ wl.audio-event-store at)
          (u16@ wl.audio-event-store (+ at 4))
          (sd.audio-callsite-name (u16@ wl.audio-event-store (+ at 6))))))

(defn wl.audio-event-rows (index output)
  (if (< index 0)
      output
      (wl.audio-event-rows (- index 1)
        (cons (wl.audio-event-row index) output))))

(defn wl.audio-event-log ()
  (wl.audio-event-rows (- wl.audio-event-count 1) nil))

(defn wl.play-sound (sound source)
  (if (= sd.started 0)
      (begin
        (wl.record-audio-event app.time-count sound source)
        sound)
      (begin
        (sd.set-tick app.time-count)
        (let ((result (sd.play-sound sound source)))
          (if (= sd.last-accepted 1)
              (wl.record-audio-event app.time-count sound source) nil)
          result))))

;;; WL_PLAY.C compatibility. The existing game-facing event log is a decision
;;; log and is retained whether assets are mounted or not. Once the manager is
;;; started, the same call also reaches the IMF sequencer with the stable
;;; source boundary name StartMusic. Keep the historical wrapper return values:
;;; start returns the requested song number and stop returns true.
(defn wl.start-music (song)
  (begin
    (set! wl.music-events (cons (list 'music-start song) wl.music-events))
    (if (= sd.started 1) (sd.start-music song 'StartMusic) nil)
    song))

(defn wl.stop-music ()
  (begin
    (set! wl.music-events (cons '(music-stop) wl.music-events))
    (if (= sd.started 1) (sd.music-off) nil)
    true))
