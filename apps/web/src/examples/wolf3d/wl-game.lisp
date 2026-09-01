(define wl.tilemap (bytes.alloc 4096))
(define wl.level-walls nil)
(define wl.level-objects nil)

(define wl.MAXDOORS 64)
(define wl.DOOR-CENTRE 128)
(define wl.DOOR-SIDE 64)
(define wl.doorposition (bytes.alloc 128))
(define wl.doortilex (bytes.alloc 64))
(define wl.doortiley (bytes.alloc 64))
(define wl.doorvertical (bytes.alloc 64))
(define wl.doorlock (bytes.alloc 64))
(define wl.dooraction (bytes.alloc 64))
(define wl.doorticcount (bytes.alloc 128))
(define wl.doornum 0)
(define wl.keys 0)
(define wl.DR-OPEN 0)
(define wl.DR-CLOSED 1)
(define wl.DR-OPENING 2)
(define wl.DR-CLOSING 3)
(define wl.OPENTICS 300)
(define wl.difficulty 2)
(define wl.killtotal 0)
(define wl.killcount 0)
(define wl.treasuretotal 0)
(define wl.treasurecount 0)
(define wl.secrettotal 0)
(define wl.secretcount 0)
;; Source actorat is split into wall and actor bytes; occupied? rejoins them.
(define wl.actorat-wall (bytes.alloc 4096))
(define wl.MAXSTATICS 400)
(define wl.staticcount 0)
(define wl.staticx (bytes.alloc 400))
(define wl.staticy (bytes.alloc 400))
(define wl.staticshapenum (bytes.alloc 800))
(define wl.staticflags (bytes.alloc 400))
(define wl.staticitem (bytes.alloc 400))
(define wl.FL-BONUS 2)
(define wl.spotvis-current 0)
(define wl.STAT-DRESSING 0)
(define wl.STAT-BLOCK 1)
(define wl.BO-GIBS 2)
(define wl.BO-ALPO 3)
(define wl.BO-FIRSTAID 4)
(define wl.BO-KEY1 5)
(define wl.BO-KEY2 6)
(define wl.BO-KEY3 7)
(define wl.BO-KEY4 8)
(define wl.BO-CROSS 9)
(define wl.BO-CHALICE 10)
(define wl.BO-BIBLE 11)
(define wl.BO-CROWN 12)
(define wl.BO-CLIP 13)
(define wl.BO-CLIP2 14)
(define wl.BO-MACHINEGUN 15)
(define wl.BO-CHAINGUN 16)
(define wl.BO-FOOD 17)
(define wl.BO-FULLHEAL 18)
(define wl.BO-25CLIP 19)
(define wl.BO-SPEAR 20)

;;; AUDIOWL6.H sound identities used by WL_GAME.C, WL_ACT1.C, WL_STATE.C, and
;;; WL_ACT2.C.  Keep the source enum values at the game boundary: actor and
;;; door decisions are available in core-only evaluators before ID_SD is
;;; loaded, while the eventual call still flows through wl.play-sound.
(define wl.OPENDOORSND 18)
(define wl.CLOSEDOORSND 19)
(define wl.SCHABBSTHROWSND 8)
(define wl.HALTSND 21)
(define wl.DEATHSCREAM2SND 22)
(define wl.DEATHSCREAM3SND 25)
(define wl.DEATHSCREAM1SND 29)
(define wl.DOGDEATHSND 10)
(define wl.DOGBARKSND 41)
(define wl.MUTTISND 50)
(define wl.SCHUTZADSND 51)
(define wl.AHHHGSND 52)
(define wl.DIESND 53)
(define wl.EVASND 54)
(define wl.GUTENTAGSND 55)
(define wl.LEBENSND 56)
(define wl.SCHEISTSND 57)
(define wl.NAZIFIRESND 58)
(define wl.BOSSFIRESND 59)
(define wl.SSFIRESND 60)
(define wl.SLURPIESND 61)
(define wl.TOT-HUNDSND 62)
(define wl.MEINGOTTSND 63)
(define wl.SCHABBSHASND 64)
(define wl.HITLERHASND 65)
(define wl.SPIONSND 66)
(define wl.NEINSOVASSND 67)
(define wl.DOGATTACKSND 68)
(define wl.FLAMETHROWERSND 69)
(define wl.MECHSTEPSND 70)
(define wl.GETMACHINESND 30)
(define wl.HEALTH1SND 33)
(define wl.HEALTH2SND 34)
(define wl.GETGATLINGSND 38)
(define wl.YEAHSND 72)
(define wl.DEATHSCREAM4SND 73)
(define wl.DEATHSCREAM5SND 74)
(define wl.DEATHSCREAM6SND 75)
(define wl.DEATHSCREAM7SND 76)
(define wl.DEATHSCREAM8SND 77)
(define wl.DEATHSCREAM9SND 78)
(define wl.DONNERSND 79)
(define wl.EINESND 80)
(define wl.ERLAUBENSND 81)
(define wl.KEINSND 82)
(define wl.MEINSND 83)
(define wl.ROSESND 84)
(define wl.MISSILEFIRESND 85)
(define wl.MISSILEHITSND 86)

;;; WL_GAME.C SetSoundLoc tables.  Rows are absolute sideways distance 0..14;
;;; columns are forward distance -15..14.  Values are attenuation, not volume.
(define wl.righttable nil)
(define wl.lefttable nil)
(define wl.righttable-bytes (bytes.alloc 450))
(define wl.lefttable-bytes (bytes.alloc 450))
(define wl.sound-table-load-mark 0)

(defn wl.load-sound-table-row (target values at)
  (if (nil? values)
      at
      (begin
        (u8! target at (car values))
        (wl.load-sound-table-row target (cdr values) (+ at 1)))))

(defn wl.load-sound-table-rows (target rows at)
  (if (nil? rows)
      at
      (wl.load-sound-table-rows target (cdr rows)
        (wl.load-sound-table-row target (car rows) at))))

(set! wl.sound-table-load-mark (heap.used))
(set! wl.righttable
  '((8 8 8 8 8 8 8 7 7 7 7 7 7 6 0 0 0 0 0 1 3 5 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 7 7 7 7 7 6 4 0 0 0 0 0 2 4 6 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 7 7 7 7 6 6 4 1 0 0 0 1 2 4 6 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 7 7 7 7 6 5 4 2 1 0 1 2 3 5 7 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 7 7 7 6 5 4 3 2 2 3 3 5 6 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 7 7 7 6 6 5 4 4 4 4 5 6 7 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 7 7 7 6 6 5 5 5 6 6 7 8 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 8 7 7 7 6 6 7 7 8 8 8 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8)))

(set! wl.lefttable
  '((8 8 8 8 8 8 8 8 5 3 1 0 0 0 0 0 6 7 7 7 7 7 7 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 6 4 2 0 0 0 0 0 4 6 7 7 7 7 7 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 6 4 2 1 0 0 0 1 4 6 6 7 7 7 7 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 7 5 3 2 1 0 1 2 4 5 6 7 7 7 7 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 6 5 3 3 2 2 3 4 5 6 7 7 7 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 7 6 5 4 4 4 4 5 6 6 7 7 7 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 7 6 6 5 5 5 6 6 7 7 7 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 8 8 7 7 6 6 7 7 7 8 8 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8)
    (8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8 8)))

(wl.load-sound-table-rows wl.righttable-bytes wl.righttable 0)
(wl.load-sound-table-rows wl.lefttable-bytes wl.lefttable 0)
(set! wl.righttable nil)
(set! wl.lefttable nil)
(heap.release wl.sound-table-load-mark)
(set! wl.righttable wl.righttable-bytes)
(set! wl.lefttable wl.lefttable-bytes)

(define wl.globalsoundx 0)
(define wl.globalsoundy 0)
(define wl.leftchannel 0)
(define wl.rightchannel 0)

;;; WL_GAME.C demo-record allocation and pointer lifecycle. PollControls owns
;;; sampling; these routines own the 4-byte header, cadence-scaled command
;;; encoding, strict 8192-byte limit, and exact-length finished byte record.
(define wl.MAXDEMOSIZE 8192)
(define wl.demo-buffer nil)
(define wl.demo-ptr 0)
(define wl.last-demo-ptr 0)
(define wl.demo-recording 0)
(define wl.demo-record-overflow 0)
(define wl.finished-demo nil)

(defn wl.start-demo-record (level)
  (if (or (< level 0) (> level 255))
      false
      (begin
        (set! wl.demo-buffer (bytes.alloc wl.MAXDEMOSIZE))
        (u8! wl.demo-buffer 0 level)
        ;; The DOS pointer skips all four header bytes; FinishDemoRecord writes
        ;; only the two-byte length at offsets 1..2. Offset 3 stays reserved.
        (set! wl.demo-ptr 4)
        (set! wl.last-demo-ptr wl.MAXDEMOSIZE)
        (set! wl.demo-recording 1)
        (set! wl.demo-record-overflow 0)
        (set! wl.finished-demo nil)
        true)))

(defn wl.record-demo (buttonbits controlx controly tics)
  (if (or (= wl.demo-recording 0) (<= tics 0))
      false
      (if (>= (+ wl.demo-ptr 3) wl.last-demo-ptr)
          (begin
            ;; Source Quit is terminal. The embeddable port fails closed before
            ;; an out-of-range byte write and makes the terminal condition visible.
            (set! wl.demo-record-overflow 1)
            (set! wl.demo-recording 0)
            false)
          (begin
            (u8! wl.demo-buffer wl.demo-ptr (bit.and buttonbits 255))
            (u8! wl.demo-buffer (+ wl.demo-ptr 1)
              (bit.and (/ controlx tics) 255))
            (u8! wl.demo-buffer (+ wl.demo-ptr 2)
              (bit.and (/ controly tics) 255))
            (set! wl.demo-ptr (+ wl.demo-ptr 3))
            true))))

(defn wl.record-current-demo ()
  (wl.record-demo (wl.button-bits 0 0) wl.controlx wl.controly wl.tics))

(defn wl.finish-demo-record ()
  (if (or (nil? wl.demo-buffer) (= wl.demo-record-overflow 1))
      nil
      (let ((length wl.demo-ptr))
        (let ((finished (bytes.alloc length)))
          (begin
            (set! wl.demo-recording 0)
            (u16! wl.demo-buffer 1 length)
            (bytes.copy finished 0 wl.demo-buffer 0 length)
            (set! wl.finished-demo finished)
            finished)))))

(defn wl.sound-table-at (table x y)
  (u8@ table (+ (* x 30) (+ y 15))))

;;; Source SetSoundLoc uses the focal-point view globals produced by CalcView,
;;; not the player's center. FixedByFrac preserves the DOS sign-magnitude rule.
(defn wl.set-sound-loc (gx gy)
  (wl.set-sound-loc-marked gx gy (heap.used)))

(defn wl.set-sound-loc-marked (gx gy mark)
  (begin
    (wl.set-sound-loc-core gx gy)
    (heap.release mark)
    true))

(defn wl.set-sound-loc-core (gx gy)
  (let ((rx (- gx (wl.view@ wl.VIEWX))) (ry (- gy (wl.view@ wl.VIEWY))))
    (let ((x (bit.shr (- (fx.by-frac rx (wl.view@ wl.VIEWCOS))
                          (fx.by-frac ry (wl.view@ wl.VIEWSIN))) wl.TILESHIFT))
          (y (bit.shr (+ (fx.by-frac ry (wl.view@ wl.VIEWCOS))
                          (fx.by-frac rx (wl.view@ wl.VIEWSIN))) wl.TILESHIFT)))
      (let ((cx (if (>= (if (< x 0) (- 0 x) x) 15) 14
                    (if (< x 0) (- 0 x) x)))
            (cy (cond ((>= y 15) 14) ((<= y -15) -15) (true y))))
        (begin
          (set! wl.leftchannel (wl.sound-table-at wl.lefttable cx cy))
          (set! wl.rightchannel (wl.sound-table-at wl.righttable cx cy))
          true)))))

(defn wl.play-sound-loc-global (sound gx gy)
  (if (not (bound? 'sd.position-sound))
      (if (bound? 'wl.play-sound) (wl.play-sound sound 'PlaySoundLocGlobal) false)
      (begin
        (wl.set-sound-loc gx gy)
        (sd.position-sound wl.leftchannel wl.rightchannel)
        (let ((accepted (wl.play-sound sound 'PlaySoundLocGlobal)))
          (if accepted
              (begin (set! wl.globalsoundx gx) (set! wl.globalsoundy gy)) nil)
          accepted))))

(defn wl.play-sound-loc-actor (sound actor)
  (wl.play-sound-loc-global sound (wl.actor-x@ actor) (wl.actor-y@ actor)))

(defn wl.play-sound-loc-tile (sound tilex tiley)
  (wl.play-sound-loc-global sound
    (+ (bit.shl tilex wl.TILESHIFT) (bit.shl 1 (- wl.TILESHIFT 1)))
    (+ (bit.shl tiley wl.TILESHIFT) (bit.shl 1 (- wl.TILESHIFT 1)))))

(defn wl.update-sound-loc ()
  (if (and (bound? 'sd.SoundPositioned) (= sd.SoundPositioned 1))
      (begin
        (wl.set-sound-loc wl.globalsoundx wl.globalsoundy)
        (sd.set-position wl.leftchannel wl.rightchannel))
      false))

;;; WL_GAME.C's non-SPEAR secret-level return table. The source comment notes
;;; that these are already zero-based map numbers.
(define wl.elevator-back-to '(1 1 7 3 5 3))

(defn wl.tilemap@ (x y) (u8@ wl.tilemap (+ (bit.shl x wl.MAPSHIFT) y)))
(defn wl.tilemap! (x y v) (u8! wl.tilemap (+ (bit.shl x wl.MAPSHIFT) y) v))

(defn wl.actorat-wall@ (x y) (u8@ wl.actorat-wall (+ (bit.shl x wl.MAPSHIFT) y)))
(defn wl.actorat-wall! (x y v) (u8! wl.actorat-wall (+ (bit.shl x wl.MAPSHIFT) y) v))

(defn wl.static-shapenum@ (index) (i16@ wl.staticshapenum (* index 2)))
(defn wl.static-shapenum! (index shape)
  (u16! wl.staticshapenum (* index 2) (if (< shape 0) (+ shape 65536) shape)))
(defn wl.static-flags@ (index) (u8@ wl.staticflags index))
(defn wl.static-flags! (index flags) (u8! wl.staticflags index flags))

(defn wl.door-position@ (door) (u16@ wl.doorposition (* door 2)))
(defn wl.door-position! (door position) (u16! wl.doorposition (* door 2) position))
(defn wl.door-x@ (door) (u8@ wl.doortilex door))
(defn wl.door-y@ (door) (u8@ wl.doortiley door))
(defn wl.door-vertical@ (door) (u8@ wl.doorvertical door))
(defn wl.door-lock@ (door) (u8@ wl.doorlock door))
(defn wl.door-action@ (door) (u8@ wl.dooraction door))
(defn wl.door-action! (door action) (u8! wl.dooraction door action))
(defn wl.door-ticcount@ (door) (u16@ wl.doorticcount (* door 2)))
(defn wl.door-ticcount! (door count) (u16! wl.doorticcount (* door 2) count))
(defn wl.door-tile? (tile) (> (bit.and tile wl.DOOR-CENTRE) 0))
(defn wl.door-number (tile) (bit.and tile 127))

(defn wl.init-door-list ()
  (begin
    (set! wl.doornum 0)
    (bytes.fill wl.doorposition 0 128 0)
    (bytes.fill wl.doortilex 0 64 0)
    (bytes.fill wl.doortiley 0 64 0)
    (bytes.fill wl.doorvertical 0 64 0)
    (bytes.fill wl.doorlock 0 64 0)
    (bytes.fill wl.dooraction 0 64 0)
    (bytes.fill wl.doorticcount 0 128 0)))

(defn wl.wall? (x y)
  (and (and (>= x 0) (< x wl.MAPSIZE))
       (and (and (>= y 0) (< y wl.MAPSIZE))
            (> (wl.tilemap@ x y) 0))))

;;; SetupGameLevel's scans mutate fixed persistent buffers, but the seed
;;; evaluator allocates list/evaluation cells while walking 4096 map entries.
;;; The DOS loops reuse stack locals. Each bounded helper releases only its own
;;; completed call frame, matching the seed's established marked-helper pattern.
(defn wl.setup-game-level (walls objects)
  (begin
    (set! wl.level-walls walls)
    (set! wl.level-objects objects)
    (set! wl.killtotal 0)
    (set! wl.killcount 0)
    (set! wl.treasuretotal 0)
    (set! wl.treasurecount 0)
    (set! wl.secrettotal 0)
    ;; Source resets counters here but carries pushwall state.
    (set! wl.secretcount 0)
    (set! wl.plane0-dirty 0)
    (set! wl.plane1-dirty 0)
    (bytes.fill wl.tilemap 0 wl.MAPAREA 0)
    (bytes.fill wl.actorat-wall 0 wl.MAPAREA 0)
    (wl.setup-tiles-bounded walls)
    (wl.init-actors)
    (wl.init-static-list)
    (wl.init-door-list)
    (wl.spawn-doors-bounded walls)
    (wl.scan-info-plane-bounded walls objects)
    (wl.remove-ambush-markers-bounded walls)
    (wl.init-areas-bounded)))

(defn wl.setup-tiles-bounded (walls)
  (wl.setup-tiles-marked walls (heap.used)))

(defn wl.setup-tiles-marked (walls mark)
  (begin (wl.setup-tiles walls 0) (heap.release mark)))

(defn wl.spawn-doors-bounded (walls)
  (wl.spawn-doors-marked walls (heap.used)))

(defn wl.spawn-doors-marked (walls mark)
  (begin (wl.spawn-doors walls 0) (heap.release mark)))

(defn wl.scan-info-plane-bounded (walls objects)
  (wl.scan-info-plane-marked walls objects (heap.used)))

(defn wl.scan-info-plane-marked (walls objects mark)
  (begin (wl.scan-info-plane walls objects 0) (heap.release mark)))

(defn wl.remove-ambush-markers-bounded (walls)
  (wl.remove-ambush-markers-marked walls (heap.used)))

(defn wl.remove-ambush-markers-marked (walls mark)
  (begin (wl.remove-ambush-markers walls 0) (heap.release mark)))

(defn wl.init-areas-bounded ()
  (wl.init-areas-marked (heap.used)))

(defn wl.init-areas-marked (mark)
  (begin (wl.init-areas) (heap.release mark)))

(defn wl.setup-tiles (walls index)
  (if (= index wl.MAPAREA)
      index
      (begin
        (wl.setup-tile walls index (u16@ walls (* index 2)))
        (wl.setup-tiles walls (+ index 1)))))

(defn wl.setup-tile (walls index tile)
  (if (wl.solid? tile)
      (begin
        (wl.tilemap! (mod index wl.MAPSIZE) (/ index wl.MAPSIZE) tile)
        (wl.actorat-wall! (mod index wl.MAPSIZE) (/ index wl.MAPSIZE) tile))
      nil))

(defn wl.spawn-doors (walls index)
  (if (= index wl.MAPAREA)
      wl.doornum
      (begin
        (wl.spawn-door-tile walls index (u16@ walls (* index 2)))
        (wl.spawn-doors walls (+ index 1)))))

(defn wl.spawn-door-tile (walls index tile)
  (if (wl.door? tile)
      (wl.spawn-door walls
                     (mod index wl.MAPSIZE) (/ index wl.MAPSIZE)
                     (if (= (mod tile 2) 0) 1 0)
                     (/ (- tile (if (= (mod tile 2) 0) 90 91)) 2))
      nil))

(defn wl.spawn-door (walls tilex tiley vertical lock)
  (if (= wl.doornum wl.MAXDOORS)
      nil
      (begin
        (wl.door-position! wl.doornum 0)
        (u8! wl.doortilex wl.doornum tilex)
        (u8! wl.doortiley wl.doornum tiley)
        (u8! wl.doorvertical wl.doornum vertical)
        (u8! wl.doorlock wl.doornum lock)
        (wl.door-action! wl.doornum wl.DR-CLOSED)
        (wl.door-ticcount! wl.doornum 0)
        (wl.tilemap! tilex tiley (+ wl.DOOR-CENTRE wl.doornum))
        (wl.actorat-wall! tilex tiley (+ wl.DOOR-CENTRE wl.doornum))
        (wl.spawn-door-plane walls tilex tiley vertical)
        (set! wl.doornum (+ wl.doornum 1)))))

(defn wl.spawn-door-plane (walls tilex tiley vertical)
  (if (= vertical 1)
      (begin
        (u16! walls (* (+ (* tiley wl.MAPSIZE) tilex) 2)
              (u16@ walls (* (+ (* tiley wl.MAPSIZE) (- tilex 1)) 2)))
        (wl.tilemap! tilex (- tiley 1) (bit.or (wl.tilemap@ tilex (- tiley 1)) wl.DOOR-SIDE))
        (wl.tilemap! tilex (+ tiley 1) (bit.or (wl.tilemap@ tilex (+ tiley 1)) wl.DOOR-SIDE)))
      (begin
        (u16! walls (* (+ (* tiley wl.MAPSIZE) tilex) 2)
              (u16@ walls (* (+ (* (- tiley 1) wl.MAPSIZE) tilex) 2)))
        (wl.tilemap! (- tilex 1) tiley (bit.or (wl.tilemap@ (- tilex 1) tiley) wl.DOOR-SIDE))
        (wl.tilemap! (+ tilex 1) tiley (bit.or (wl.tilemap@ (+ tilex 1) tiley) wl.DOOR-SIDE)))))

(defn wl.door-solid? (door) (not (= (wl.door-action@ door) wl.DR-OPEN)))

(defn wl.open-door (door)
  (if (or (< door 0) (>= door wl.doornum))
      false
      (begin
        (if (= (wl.door-action@ door) wl.DR-OPEN)
            (wl.door-ticcount! door 0)
            (wl.door-action! door wl.DR-OPENING))
        true)))

(defn wl.locked-door? (door)
  (let ((lock (wl.door-lock@ door)))
    (and (and (>= lock 1) (<= lock 4))
         (= (bit.and wl.keys (bit.shl 1 (- lock 1))) 0))))

(defn wl.operate-door (door)
  (if (or (< door 0) (>= door wl.doornum))
      false
      (if (wl.locked-door? door)
          false
          (begin
            (if (or (= (wl.door-action@ door) wl.DR-CLOSED)
                    (= (wl.door-action@ door) wl.DR-CLOSING))
                (wl.open-door door)
                (wl.close-door door))
            true))))

(defn wl.player-blocks-door? (door)
  (let ((tilex (wl.door-x@ door)) (tiley (wl.door-y@ door)))
    (or (and (= (wl.player@ wl.PLAYER-TILEX) tilex)
             (= (wl.player@ wl.PLAYER-TILEY) tiley))
        (if (= (wl.door-vertical@ door) 1)
            (and (= (wl.player@ wl.PLAYER-TILEY) tiley)
                 (or (= (bit.shr (+ (wl.player@ wl.PLAYER-X) wl.MINDIST) wl.TILESHIFT) tilex)
                     (= (bit.shr (- (wl.player@ wl.PLAYER-X) wl.MINDIST) wl.TILESHIFT) tilex)))
            (and (= (wl.player@ wl.PLAYER-TILEX) tilex)
                 (or (= (bit.shr (+ (wl.player@ wl.PLAYER-Y) wl.MINDIST) wl.TILESHIFT) tiley)
                     (= (bit.shr (- (wl.player@ wl.PLAYER-Y) wl.MINDIST) wl.TILESHIFT) tiley)))))))

(defn wl.close-door (door)
  (if (or (wl.player-blocks-door? door) (wl.actor-blocks-door? door))
      false
      (begin
        (if (wl.door-sound-active? door)
            (wl.play-sound-loc-tile wl.CLOSEDOORSND
              (wl.door-x@ door) (wl.door-y@ door)) nil)
        (wl.door-action! door wl.DR-CLOSING)
        (wl.actorat-wall! (wl.door-x@ door) (wl.door-y@ door)
                          (+ wl.DOOR-CENTRE door))
        true)))

(defn wl.door-sound-active? (door)
  (if (not (bound? 'wl.door-area-pair))
      false
      (let ((areas (wl.door-area-pair door)))
        (or (wl.area-active? (car areas))
            (wl.area-active? (car (cdr areas)))))))

(defn wl.door-open (door)
  (let ((count (+ (wl.door-ticcount@ door) wl.tics)))
    (begin
      (wl.door-ticcount! door count)
      (if (>= count wl.OPENTICS) (wl.close-door door) nil))))

(defn wl.door-opening (door)
  (let ((position (+ (wl.door-position@ door) (bit.shl wl.tics 10))))
    (begin
      (if (= (wl.door-position@ door) 0)
          (begin
            (wl.change-door-area-connection door 1)
            (if (wl.door-sound-active? door)
                (wl.play-sound-loc-tile wl.OPENDOORSND
                  (wl.door-x@ door) (wl.door-y@ door)) nil)) nil)
      (if (>= position 65535)
          (begin
            (wl.door-position! door 65535)
            (wl.door-ticcount! door 0)
            (wl.door-action! door wl.DR-OPEN)
            (wl.actorat-wall! (wl.door-x@ door) (wl.door-y@ door) 0))
          (wl.door-position! door position)))))

(defn wl.door-closing (door)
  (if (wl.player-blocks-door? door)
      (wl.open-door door)
      (let ((position (- (wl.door-position@ door) (bit.shl wl.tics 10))))
        (if (<= position 0)
            (begin
              (wl.door-position! door 0)
              (wl.door-action! door wl.DR-CLOSED)
              (wl.change-door-area-connection door -1))
            (wl.door-position! door position)))))

(defn wl.move-doors () (wl.move-door-number 0))

(defn wl.move-door-number (door)
  (if (= door wl.doornum)
      nil
      (begin
        (cond ((= (wl.door-action@ door) wl.DR-OPEN) (wl.door-open door))
              ((= (wl.door-action@ door) wl.DR-OPENING) (wl.door-opening door))
              ((= (wl.door-action@ door) wl.DR-CLOSING) (wl.door-closing door))
              (true nil))
        (wl.move-door-number (+ door 1)))))

;; Source PushWall/MovePWalls own these values; setup does not reset them.
(define wl.pwallstate 0)
(define wl.pwallpos 0)
(define wl.pwallx 0)
(define wl.pwally 0)
(define wl.pwalldir 0)
(define wl.plane0-dirty 0)
(define wl.plane1-dirty 0)

(defn wl.actorat-occupied? (x y)
  (or (> (wl.actorat@ x y) 0) (> (wl.actorat-wall@ x y) 0)))

(defn wl.push-wall (checkx checky dir)
  (if (> wl.pwallstate 0)
      false
      (wl.push-wall-tile checkx checky dir (wl.tilemap@ checkx checky))))

(defn wl.push-wall-tile (checkx checky dir oldtile)
  (if (= oldtile 0)
      false
      (if (wl.push-wall-clear? checkx checky dir oldtile)
          (wl.push-wall-activate checkx checky dir)
          false)))

(defn wl.push-wall-clear? (checkx checky dir oldtile)
  (cond ((= dir wl.NORTH) (wl.push-wall-step checkx (- checky 1) oldtile))
        ((= dir wl.EAST) (wl.push-wall-step (+ checkx 1) checky oldtile))
        ((= dir wl.SOUTH) (wl.push-wall-step checkx (+ checky 1) oldtile))
        ((= dir wl.WEST) (wl.push-wall-step (- checkx 1) checky oldtile))
        (true false)))

(defn wl.push-wall-step (x y oldtile)
  (if (or (< x 0) (or (> x 63) (or (< y 0) (> y 63))))
      false
      (if (wl.actorat-occupied? x y)
          false
          (begin
            (wl.actorat-wall! x y oldtile)
            (wl.tilemap! x y oldtile)
            true))))

(defn wl.push-wall-activate (checkx checky dir)
  (begin
    (set! wl.secretcount (+ wl.secretcount 1))
    (set! wl.pwallx checkx)
    (set! wl.pwally checky)
    (set! wl.pwalldir dir)
    (set! wl.pwallstate 1)
    (set! wl.pwallpos 0)
    (wl.tilemap! wl.pwallx wl.pwally (bit.or (wl.tilemap@ wl.pwallx wl.pwally) 192))
    (u16! wl.level-objects (* (+ (* wl.pwally wl.MAPSIZE) wl.pwallx) 2) 0)
    (set! wl.plane1-dirty 1)
    true))

(defn wl.move-pwalls ()
  (if (= wl.pwallstate 0)
      nil
      (wl.move-pwalls-tic (/ wl.pwallstate 128))))

(defn wl.move-pwalls-tic (oldblock)
  (begin
    (set! wl.pwallstate (+ wl.pwallstate wl.tics))
    (if (= (/ wl.pwallstate 128) oldblock)
        (wl.pwall-position)
        (wl.move-pwalls-block (bit.and (wl.tilemap@ wl.pwallx wl.pwally) 63)))))

;; Source assigns the vacated tile to the player's current area.
(defn wl.move-pwalls-block (oldtile)
  (begin
    (wl.tilemap! wl.pwallx wl.pwally 0)
    (wl.actorat-clear! wl.pwallx wl.pwally)
    (u16! wl.level-walls (* (+ (* wl.pwally wl.MAPSIZE) wl.pwallx) 2)
          (+ (wl.player-area) wl.AREATILE))
    (set! wl.plane0-dirty 1)
    (if (> wl.pwallstate 256)
        (set! wl.pwallstate 0)
        (wl.move-pwalls-farther oldtile))))

(defn wl.move-pwalls-farther (oldtile)
  (if (wl.move-pwalls-advance oldtile)
      (wl.pwall-retag oldtile)
      (set! wl.pwallstate 0)))

(defn wl.pwall-retag (oldtile)
  (begin
    (wl.tilemap! wl.pwallx wl.pwally (bit.or oldtile 192))
    (wl.pwall-position)))

(defn wl.move-pwalls-advance (oldtile)
  (cond ((= wl.pwalldir wl.NORTH)
         (begin (set! wl.pwally (- wl.pwally 1))
                (wl.push-wall-step wl.pwallx (- wl.pwally 1) oldtile)))
        ((= wl.pwalldir wl.EAST)
         (begin (set! wl.pwallx (+ wl.pwallx 1))
                (wl.push-wall-step (+ wl.pwallx 1) wl.pwally oldtile)))
        ((= wl.pwalldir wl.SOUTH)
         (begin (set! wl.pwally (+ wl.pwally 1))
                (wl.push-wall-step wl.pwallx (+ wl.pwally 1) oldtile)))
        ((= wl.pwalldir wl.WEST)
         (begin (set! wl.pwallx (- wl.pwallx 1))
                (wl.push-wall-step (- wl.pwallx 1) wl.pwally oldtile)))
        (true false)))

(defn wl.pwall-position ()
  (set! wl.pwallpos (bit.and (/ wl.pwallstate 2) 63)))

(defn wl.actorat-clear! (x y)
  (begin (wl.actorat-wall! x y 0) (wl.actorat! x y 0)))

(defn wl.remove-ambush-markers (walls index)
  (if (= index wl.MAPAREA)
      nil
      (begin
        (if (= (u16@ walls (* index 2)) wl.AMBUSHTILE)
            (wl.remove-ambush-marker walls index)
            nil)
        (wl.remove-ambush-markers walls (+ index 1)))))

(defn wl.remove-ambush-marker (walls index)
  (let ((tile wl.AMBUSHTILE))
    (begin
      (wl.tilemap! (mod index wl.MAPSIZE) (/ index wl.MAPSIZE) 0)
      (if (= (wl.actorat-wall@ (mod index wl.MAPSIZE) (/ index wl.MAPSIZE)) wl.AMBUSHTILE)
          (wl.actorat-wall! (mod index wl.MAPSIZE) (/ index wl.MAPSIZE) 0) nil)
      (if (>= (u16@ walls (* (+ index 1) 2)) wl.AREATILE)
          (set! tile (u16@ walls (* (+ index 1) 2))) nil)
      (if (>= (u16@ walls (* (- index wl.MAPSIZE) 2)) wl.AREATILE)
          (set! tile (u16@ walls (* (- index wl.MAPSIZE) 2))) nil)
      (if (>= (u16@ walls (* (+ index wl.MAPSIZE) 2)) wl.AREATILE)
          (set! tile (u16@ walls (* (+ index wl.MAPSIZE) 2))) nil)
      (if (>= (u16@ walls (* (- index 1) 2)) wl.AREATILE)
          (set! tile (u16@ walls (* (- index 1) 2))) nil)
      (u16! walls (* index 2) tile))))

(defn wl.door-checksum () (wl.door-checksum-at 0 0))

(defn wl.door-checksum-at (door checksum)
  (if (= door wl.MAXDOORS)
      checksum
      (wl.door-checksum-at
        (+ door 1)
        (bit.and
          (bit.xor (bit.xor (bit.xor (* checksum 33)
                                     (wl.door-position@ door))
                            (bit.shl (wl.door-action@ door) 8))
                   (wl.door-ticcount@ door))
          65535))))

;; Original TraceMix order: player first, then the source-order enemy store.
;; Two u16 words preserve the full signed/unsigned 32-bit operand bit pattern.
(define wl.actorhash-high 0)
(define wl.actorhash-low 5381)

(defn wl.actor-hash-refresh () (wl.actor-hash-refresh-marked (heap.used)))

(defn wl.actor-hash-refresh-marked (mark)
  (begin (wl.actor-hash-at 0 0 0 5381) (heap.release mark)))

(defn wl.actor-hash-at (ordinal field high low)
  (if (> ordinal wl.actorcount)
      (begin (set! wl.actorhash-high high) (set! wl.actorhash-low low))
      (wl.actor-hash-mix ordinal field high
        (if (= ordinal 0) (wl.player-hash-value field)
            (wl.enemy-hash-value (- ordinal 1) field)) (* low 33))))

(defn wl.actor-hash-mix (ordinal field high value product)
  (let ((next-high (bit.xor
                     (bit.and (+ (* high 33) (/ product 65536)) 65535)
                     (bit.and (bit.shr value 16) 65535)))
        (next-low (bit.xor (bit.and product 65535) (bit.and value 65535))))
    (if (= field 16)
        (wl.actor-hash-at (+ ordinal 1) 0 next-high next-low)
        (wl.actor-hash-at ordinal (+ field 1) next-high next-low))))

(defn wl.player-hash-value (field)
  (cond ((= field 0) 1) ((= field 2) 1)
        ((= field 3) (wl.player@ wl.PLAYER-STATE))
        ((= field 4) (wl.player@ wl.PLAYER-FLAGS))
        ((= field 7) (wl.player@ wl.PLAYER-X))
        ((= field 8) (wl.player@ wl.PLAYER-Y))
        ((= field 9) (wl.player@ wl.PLAYER-TILEX))
        ((= field 10) (wl.player@ wl.PLAYER-TILEY))
        ((= field 11) (wl.player@ wl.PLAYER-ANGLE)) (true 0)))

(defn wl.enemy-hash-value (actor field)
  (cond ((= field 0) (wl.actor-active@ actor))
        ((= field 1) (wl.actor-ticcount@ actor))
        ((= field 2) (wl.actor-class@ actor))
        ((= field 3) (wl.actor-shapenum actor))
        ((= field 4) (wl.actor-flags@ actor))
        ((= field 5) (wl.actor-distance@ actor))
        ((= field 6) (wl.actor-dir@ actor))
        ((= field 7) (wl.actor-x@ actor)) ((= field 8) (wl.actor-y@ actor))
        ((= field 9) (wl.actor-tilex@ actor))
        ((= field 10) (wl.actor-tiley@ actor))
        ((= field 11) (wl.actor-angle@ actor))
        ((= field 12) (wl.actor-hitpoints@ actor))
        ((= field 13) (wl.actor-speed@ actor))
        ((= field 14) (wl.actor-temp1@ actor))
        ((= field 15) (wl.actor-temp2@ actor))
        (true (wl.actor-temp3@ actor))))

(defn wl.actor-hash-words ()
  (begin (wl.actor-hash-refresh) (list wl.actorhash-high wl.actorhash-low)))

(defn wl.actor-hash-decimal ()
  (begin (wl.actor-hash-refresh) (wl.u32-decimal wl.actorhash-high wl.actorhash-low)))

;; Source-order static/door TraceMix, held as two u16 words under a heap mark.
(define wl.worldhash-high 0)
(define wl.worldhash-low 5381)

(defn wl.world-hash-refresh ()
  (wl.world-hash-refresh-marked (heap.used)))

(defn wl.world-hash-refresh-marked (mark)
  (begin
    (wl.world-hash-static-at 0 0 0 5381)
    (heap.release mark)))

(defn wl.world-hash-words ()
  (begin
    (wl.world-hash-refresh)
    (list wl.worldhash-high wl.worldhash-low)))

(defn wl.world-hash-static-at (index field high low)
  (if (= index wl.staticcount)
      (wl.world-hash-door-at 0 0 high low)
      (let ((value (cond ((= field 0) (u8@ wl.staticx index))
                         ((= field 1) (u8@ wl.staticy index))
                         ((= field 2) (wl.static-shapenum@ index))
                         ((= field 3) (wl.static-flags@ index))
                         (true (u8@ wl.staticitem index)))))
        (wl.world-hash-static-mix index field high value (* low 33)))))

(defn wl.world-hash-static-mix (index field high value low-product)
  (let ((mixed-high
          (bit.xor
            (bit.and (+ (* high 33) (/ low-product 65536)) 65535)
            (if (< value 0) 65535 0)))
        (mixed-low (bit.xor (bit.and low-product 65535)
                            (bit.and value 65535))))
    (if (= field 4)
        (wl.world-hash-static-at (+ index 1) 0 mixed-high mixed-low)
        (wl.world-hash-static-at index (+ field 1) mixed-high mixed-low))))

(defn wl.world-hash-door-at (index field high low)
  (if (= index wl.doornum)
      (begin (set! wl.worldhash-high high) (set! wl.worldhash-low low))
      (let ((value (cond ((= field 0) (wl.door-x@ index))
                         ((= field 1) (wl.door-y@ index))
                         ((= field 2) (wl.door-vertical@ index))
                         ((= field 3) (wl.door-lock@ index))
                         ((= field 4) (wl.door-action@ index))
                         (true (wl.door-ticcount@ index)))))
        (wl.world-hash-door-mix index field high value (* low 33)))))

(defn wl.world-hash-door-mix (index field high value low-product)
  (let ((mixed-high
          (bit.xor
            (bit.and (+ (* high 33) (/ low-product 65536)) 65535)
            (if (< value 0) 65535 0)))
        (mixed-low (bit.xor (bit.and low-product 65535)
                            (bit.and value 65535))))
    (if (= field 5)
        (wl.world-hash-door-at (+ index 1) 0 mixed-high mixed-low)
        (wl.world-hash-door-at index (+ field 1) mixed-high mixed-low))))

(defn wl.world-hash-decimal ()
  (begin
    (wl.world-hash-refresh)
    (wl.u32-decimal wl.worldhash-high wl.worldhash-low)))

;;; The original actorat[][] combines wall/static sentinels and actor pointers.
;;; This port splits those representations, so the fidelity fixture hashes each
;;; source cell's wall byte followed by its actor-owner byte in map order.
(define wl.occupancyhash-high 0)
(define wl.occupancyhash-low 5381)

(defn wl.occupancy-hash-refresh ()
  (wl.occupancy-hash-marked (heap.used)))

(defn wl.occupancy-hash-marked (mark)
  (begin (wl.occupancy-hash-at 0 0 5381) (heap.release mark)))

(defn wl.occupancy-hash-at (index high low)
  (if (= index wl.MAPAREA)
      (begin (set! wl.occupancyhash-high high) (set! wl.occupancyhash-low low))
      (wl.occupancy-hash-wall index high low (* low 33))))

(defn wl.occupancy-hash-wall (index high low low-product)
  (let ((next-high (bit.xor (bit.and (+ (* high 33) (/ low-product 65536)) 65535) 0))
        (next-low (bit.xor (bit.and low-product 65535)
                           (wl.actorat-wall@ (mod index wl.MAPSIZE) (/ index wl.MAPSIZE)))))
    (wl.occupancy-hash-actor index next-high next-low (* next-low 33))))

(defn wl.occupancy-hash-actor (index high low low-product)
  (let ((next-high (bit.xor (bit.and (+ (* high 33) (/ low-product 65536)) 65535) 0))
        (next-low (bit.xor (bit.and low-product 65535)
                           (wl.actorat@ (mod index wl.MAPSIZE) (/ index wl.MAPSIZE)))))
    (wl.occupancy-hash-at (+ index 1) next-high next-low)))

(defn wl.occupancy-hash-words ()
  (begin
    (wl.occupancy-hash-refresh)
    (list wl.occupancyhash-high wl.occupancyhash-low)))

(defn wl.occupancy-hash-decimal ()
  (begin
    (wl.occupancy-hash-refresh)
    (wl.u32-decimal wl.occupancyhash-high wl.occupancyhash-low)))

(defn wl.plane-hash-words (plane) (wl.plane-hash-at plane 0 0 5381))

(defn wl.plane-hash-at (plane index high low)
  (if (= index wl.MAPAREA)
      (list high low)
      (wl.plane-hash-product plane index high low (* low 33))))

(defn wl.plane-hash-product (plane index high low low-product)
  (wl.plane-hash-at
    plane (+ index 1)
    (bit.and (+ (* high 33) (/ low-product 65536)) 65535)
    (bit.xor (bit.and low-product 65535) (u16@ plane (* index 2)))))

(defn wl.u32-decimal (high low)
  (let ((top (/ high 1000))
        (joined (+ (* (mod high 1000) 65536) low)))
    (let ((middle (/ joined 1000)) (last (mod joined 1000)))
      (let ((joined-top (+ (* top 65536) middle)))
        (wl.u32-decimal-groups (/ joined-top 1000) (mod joined-top 1000) last)))))

(defn wl.u32-decimal-groups (first middle last)
  (cond ((> first 0) (string.append (to-string first) (wl.u32-decimal-pad3 middle)
                                    (wl.u32-decimal-pad3 last)))
        ((> middle 0) (string.append (to-string middle) (wl.u32-decimal-pad3 last)))
        (true (to-string last))))

(defn wl.u32-decimal-pad3 (value)
  (string.slice (to-string (+ value 1000)) 1 4))

(defn wl.scan-info-plane (walls objects index)
  (if (= index wl.MAPAREA)
      nil
      (wl.scan-info-tile walls objects index (u16@ objects (* index 2)))))

(defn wl.scan-info-tile (walls objects index tile)
  (begin
    (if (= tile 98) (set! wl.secrettotal (+ wl.secrettotal 1)) nil)
    (if (and (>= tile 52) (<= tile 56))
        (set! wl.treasuretotal (+ wl.treasuretotal 1)) nil)
    (if (>= tile 108)
        (if (wl.spawn-info-actor walls index tile)
            (set! wl.killtotal (+ wl.killtotal 1)) nil) nil)
    (if (wl.static-tile? tile)
        (wl.spawn-static (mod index wl.MAPSIZE) (/ index wl.MAPSIZE) (- tile 23)) nil)
    (if (wl.player-start? tile)
        (wl.spawn-player (mod index wl.MAPSIZE) (/ index wl.MAPSIZE)
                         (+ wl.NORTH (- tile wl.PLAYERSTART-FIRST)))
        nil)
    (wl.scan-info-plane walls objects (+ index 1))))

;; Non-SPEAR statinfo is entries 0-47 plus clip2 alias 48.
(defn wl.static-tile? (tile) (and (>= tile 23) (<= tile 71)))

(defn wl.static-item-for-tile (tile)
  (if (wl.static-tile? tile) (wl.static-info-type (- tile 23)) -1))

(defn wl.static-info-type (type)
  (cond ((= type 6) wl.BO-ALPO)
        ((= type 20) wl.BO-KEY1)
        ((= type 21) wl.BO-KEY2)
        ((= type 24) wl.BO-FOOD)
        ((= type 25) wl.BO-FIRSTAID)
        ((= type 26) wl.BO-CLIP)
        ((= type 27) wl.BO-MACHINEGUN)
        ((= type 28) wl.BO-CHAINGUN)
        ((= type 29) wl.BO-CROSS)
        ((= type 30) wl.BO-CHALICE)
        ((= type 31) wl.BO-BIBLE)
        ((= type 32) wl.BO-CROWN)
        ((= type 33) wl.BO-FULLHEAL)
        ((= type 34) wl.BO-GIBS)
        ((= type 38) wl.BO-GIBS)
        ((= type 48) wl.BO-CLIP2)
        ((wl.static-dressing-type? type) wl.STAT-DRESSING)
        ((and (>= type 0) (<= type 47)) wl.STAT-BLOCK)
        (true -1)))

(defn wl.static-dressing-type? (type)
  (or (or (or (= type 0) (= type 4))
          (or (= type 9) (= type 14)))
      (or (or (or (= type 15) (= type 19))
              (or (= type 23) (= type 41)))
          (or (or (= type 42) (= type 43))
              (or (= type 44) (= type 47))))))

(defn wl.static-shape-for-type (type) (if (= type 48) 28 (+ type 2)))

(defn wl.init-static-list ()
  (set! wl.staticcount 0))

(defn wl.spawn-static (x y type)
  (if (or (= wl.staticcount wl.MAXSTATICS) (< (wl.static-info-type type) 0))
      -1
      (let ((index wl.staticcount) (item (wl.static-info-type type)))
        (begin
          (u8! wl.staticx index x)
          (u8! wl.staticy index y)
          (wl.static-shapenum! index (wl.static-shape-for-type type))
          (if (= item wl.STAT-BLOCK)
              (begin (wl.actorat-wall! x y 1) (wl.static-flags! index 0))
              (if (= item wl.STAT-DRESSING)
                  (wl.static-flags! index 0)
                  (begin (wl.static-flags! index wl.FL-BONUS)
                         (u8! wl.staticitem index item))))
          (set! wl.staticcount (+ wl.staticcount 1))
          index))))

(defn wl.spawn-static-item (x y item)
  (wl.place-static-item x y item (wl.find-static-type item 0)))

(defn wl.find-static-type (item type)
  (if (> type 48) -1
      (if (= (wl.static-info-type type) item) type
          (wl.find-static-type item (+ type 1)))))

(defn wl.place-static-item (x y item type)
  (if (< type 0) -1
      (wl.place-static-item-at x y item type (wl.first-free-static 0))))

(defn wl.first-free-static (index)
  (if (= index wl.staticcount) index
      (if (= (wl.static-shapenum@ index) -1) index
          (wl.first-free-static (+ index 1)))))

(defn wl.place-static-item-at (x y item type index)
  (if (= index wl.MAXSTATICS) -1
      (begin
        (if (= index wl.staticcount) (set! wl.staticcount (+ wl.staticcount 1)) nil)
        (u8! wl.staticx index x)
        (u8! wl.staticy index y)
        (wl.static-shapenum! index (wl.static-shape-for-type type))
        (wl.static-flags! index wl.FL-BONUS)
        (u8! wl.staticitem index item)
        index)))

(defn wl.static-at (x y index)
  (if (= index wl.staticcount) -1
      (if (and (= (u8@ wl.staticx index) x) (= (u8@ wl.staticy index) y)) index
          (wl.static-at x y (+ index 1)))))

(defn wl.update-static-bonuses ()
  (wl.update-static-bonuses-marked (heap.used)))

;; True result means a pickup fired: wl.get-static/wl.apply-static-item may
;; have consed persistently, so retain every allocation made since the mark.
;; False result proves no pickup ran, so the refresh temps are droppable.
(defn wl.update-static-bonuses-marked (mark)
  (let ((got (begin
               ;; DrawScaleds consumes spotvis from the current ThreeDRefresh,
               ;; not the preceding frame. The application callback reaches
               ;; bonus handling before its renderer callback, so reproduce
               ;; that source wall-cast prefix here.
               (bytes.fill wl.spotvis 0 4096 0)
               (wl.calc-view)
               (wl.asm-refresh)
               (set! wl.spotvis-current 1)
               (wl.update-static-at 0))))
    (if got got (begin (heap.release mark) false))))

;; DrawScaleds offers live bonus statics to this source pickup-box test.
(defn wl.update-static-at (index)
  (if (= index wl.staticcount) false
      (let ((got (if (and (not (= (wl.static-shapenum@ index) -1))
                           (and (wl.static-spot-visible? index)
                                (and (wl.transform-tile-in-range?
                                       (u8@ wl.staticx index) (u8@ wl.staticy index))
                                     (= (bit.and (wl.static-flags@ index) wl.FL-BONUS)
                                        wl.FL-BONUS))))
                      (wl.get-static index) false)))
        (if (wl.update-static-at (+ index 1)) true got))))

(defn wl.transform-tile-in-range? (tilex tiley)
  (let ((gx (- (+ (bit.shl tilex wl.TILESHIFT) 32768) (wl.view@ wl.VIEWX)))
        (gy (- (+ (bit.shl tiley wl.TILESHIFT) 32768) (wl.view@ wl.VIEWY))))
    (let ((nx (- (- (fx.by-frac gx (wl.view@ wl.VIEWCOS))
                       (fx.by-frac gy (wl.view@ wl.VIEWSIN))) 8192))
          (ny (+ (fx.by-frac gy (wl.view@ wl.VIEWCOS))
                 (fx.by-frac gx (wl.view@ wl.VIEWSIN)))))
      (and (>= nx wl.MINDIST)
           (and (< nx wl.TILEGLOBAL)
                (and (> ny (- 0 (/ wl.TILEGLOBAL 2)))
                     (< ny (/ wl.TILEGLOBAL 2))))))))

(defn wl.get-static (index)
  (if (= (wl.static-shapenum@ index) -1) false
      (let ((got (wl.apply-static-item (u8@ wl.staticitem index))))
        (if got (begin (wl.static-shapenum! index -1) true) false))))

(defn wl.give-key (key)
  (if (or (< key 0) (> key 3)) false
      (begin
        (set! wl.keys (bit.or wl.keys (bit.shl 1 key)))
        true)))

(defn wl.apply-static-item (item)
  (cond ((= item wl.BO-FIRSTAID)
         (if (= wl.health 100) false
             (begin (wl.play-sound wl.HEALTH2SND 'GetBonus)
                    (wl.heal-self 25) true)))
        ((= item wl.BO-KEY1) (wl.give-key-bonus 0))
        ((= item wl.BO-KEY2) (wl.give-key-bonus 1))
        ((= item wl.BO-KEY3) (wl.give-key-bonus 2))
        ((= item wl.BO-KEY4) (wl.give-key-bonus 3))
        ((= item wl.BO-CROSS) (wl.give-treasure 100 wl.BONUS1SND))
        ((= item wl.BO-CHALICE) (wl.give-treasure 500 wl.BONUS2SND))
        ((= item wl.BO-BIBLE) (wl.give-treasure 1000 wl.BONUS3SND))
        ((= item wl.BO-CROWN) (wl.give-treasure 5000 wl.BONUS4SND))
        ((= item wl.BO-CLIP)
         (if (= wl.ammo 99) false
             (begin (wl.play-sound wl.GETAMMOSND 'GetBonus) (wl.give-ammo 8) true)))
        ((= item wl.BO-CLIP2)
         (if (= wl.ammo 99) false
             (begin (wl.play-sound wl.GETAMMOSND 'GetBonus) (wl.give-ammo 4) true)))
        ((= item wl.BO-MACHINEGUN)
         (begin (wl.play-sound wl.GETMACHINESND 'GetBonus)
                (wl.give-weapon wl.WP-MACHINEGUN) true))
        ((= item wl.BO-CHAINGUN)
         (begin (wl.play-sound wl.GETGATLINGSND 'GetBonus)
                (wl.give-weapon wl.WP-CHAINGUN)
                (set! wl.facecount 0)
                (set! wl.gotgatgun 1)
                true))
        ((= item wl.BO-FULLHEAL)
         (begin (wl.play-sound wl.BONUS1UPSND 'GetBonus)
                (wl.heal-self 99) (wl.give-ammo 25) (wl.give-extra-man)
                (set! wl.treasurecount (+ wl.treasurecount 1)) true))
        ((= item wl.BO-FOOD)
         (if (= wl.health 100) false
             (begin (wl.play-sound wl.HEALTH1SND 'GetBonus)
                    (wl.heal-self 10) true)))
        ((= item wl.BO-ALPO)
         (if (= wl.health 100) false
             (begin (wl.play-sound wl.HEALTH1SND 'GetBonus)
                    (wl.heal-self 4) true)))
        ((= item wl.BO-GIBS)
         (if (> wl.health 10) false
             (begin (wl.play-sound wl.SLURPIESND 'GetBonus)
                    (wl.heal-self 1) true)))
        (true false)))

(defn wl.give-key-bonus (key)
  (if (wl.give-key key)
      (begin (wl.play-sound wl.GETKEYSND 'GetBonus) true)
      false))

(defn wl.give-treasure (points sound)
  (begin (wl.play-sound sound 'GetBonus)
         (wl.give-points points)
         (set! wl.treasurecount (+ wl.treasurecount 1)) true))

(defn wl.heal-self (points)
  (begin (set! wl.health (+ wl.health points))
         (if (> wl.health 100) (set! wl.health 100) nil)
         (set! wl.gotgatgun 0)))

(defn wl.give-ammo (amount)
  (begin
    (if (and (= wl.ammo 0) (= wl.attackframe 0))
        (set! wl.weapon wl.chosenweapon) nil)
    (set! wl.ammo (+ wl.ammo amount))
    (if (> wl.ammo 99) (set! wl.ammo 99) nil)))

(defn wl.give-weapon (weapon)
  (begin
    (wl.give-ammo 6)
    (if (< wl.bestweapon weapon)
        (begin (set! wl.bestweapon weapon)
               (set! wl.weapon weapon)
               (set! wl.chosenweapon weapon))
        nil)
    true))

(defn wl.give-extra-man ()
  (begin
    (if (< wl.lives 9) (set! wl.lives (+ wl.lives 1)) nil)
    (wl.play-sound wl.BONUS1UPSND 'GiveExtraMan)))

(defn wl.give-points (points)
  (begin (set! wl.score (+ wl.score points)) (wl.give-points-extras)))

(defn wl.give-points-extras ()
  (if (< wl.score wl.nextextra)
      nil
      (begin (set! wl.nextextra (+ wl.nextextra 40000))
             (wl.give-extra-man)
             (wl.give-points-extras))))

(defn wl.in-four? (tile first)
  (and (>= tile first) (<= tile (+ first 3))))

(defn wl.standing-enemy? (tile difficulty)
  (or (or (or (or (or (wl.in-four? tile 108)
                       (wl.in-four? tile 116))
                   (wl.in-four? tile 126))
               (wl.in-four? tile 134))
           (wl.in-four? tile 216))
      (and (>= difficulty 2)
           (or (or (or (or (wl.in-four? tile 144)
                            (wl.in-four? tile 152))
                        (wl.in-four? tile 162))
                    (wl.in-four? tile 170))
               (wl.in-four? tile 234)))
      (and (>= difficulty 3)
           (or (or (or (or (wl.in-four? tile 180)
                            (wl.in-four? tile 188))
                        (wl.in-four? tile 198))
                    (wl.in-four? tile 206))
               (wl.in-four? tile 252)))))

;;; GameLoop's post-PlayLoop state transition, separated from presentation and
;;; music calls. This owns the campaign map/score/key/life semantics used by R2
;;; and R4 while leaving intermission/victory rendering as explicit gaps.
(defn wl.finish-playstate (playstate)
  (cond
    ((or (= playstate wl.EX-COMPLETED) (= playstate wl.EX-SECRETLEVEL))
     (begin
       (set! wl.keys 0)
       (set! wl.oldscore wl.score)
       (if (= wl.map 9)
           (set! wl.map (wl.nth wl.elevator-back-to wl.episode))
           (if (= playstate wl.EX-SECRETLEVEL)
               (set! wl.map 9)
               (set! wl.map (+ wl.map 1))))
       (set! wl.application-phase wl.APP-INTERMISSION)
       wl.map))
    ((= playstate wl.EX-DIED) (wl.died))
    ((= playstate wl.EX-VICTORIOUS)
     (begin
       (set! wl.victoryflag 1)
       (set! wl.application-phase wl.APP-VICTORY)
       wl.map))
    (true playstate)))

;;; Died's game-state portion. Rotation, palette fade, and sound stay in the
;;; renderer/audio lanes; the original decrements lives then resets this exact
;;; equipment/status group only when lives remains greater than -1.
(defn wl.died ()
  (begin
    (set! wl.weapon -1)
    (set! wl.lives (- wl.lives 1))
    (if (> wl.lives -1)
        (begin
          (set! wl.health 100)
          (set! wl.weapon wl.WP-PISTOL)
          (set! wl.bestweapon wl.WP-PISTOL)
          (set! wl.chosenweapon wl.WP-PISTOL)
          (set! wl.ammo 8)
          (set! wl.keys 0)
          (set! wl.attackframe 0)
          (set! wl.attackcount 0)
          (set! wl.weaponframe 0)
          wl.lives)
        wl.lives)))
