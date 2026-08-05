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
(define wl.secrettotal 0)
(define wl.r1-clip-active 0)
(define wl.r1-clip-x 0)
(define wl.r1-clip-y 0)

(defn wl.tilemap@ (x y) (u8@ wl.tilemap (+ (bit.shl x wl.MAPSHIFT) y)))
(defn wl.tilemap! (x y v) (u8! wl.tilemap (+ (bit.shl x wl.MAPSHIFT) y) v))

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
    ;; The fixed list is zeroed first, as InitDoorList does; SpawnDoor marks
    ;; only live slots closed. This also preserves unused-slot trace bytes.
    (bytes.fill wl.dooraction 0 64 0)
    (bytes.fill wl.doorticcount 0 128 0)))

(defn wl.wall? (x y)
  (and (and (>= x 0) (< x wl.MAPSIZE))
       (and (and (>= y 0) (< y wl.MAPSIZE))
            (> (wl.tilemap@ x y) 0))))

(defn wl.setup-game-level (walls objects)
  (begin
    (set! wl.level-walls walls)
    (set! wl.level-objects objects)
    (set! wl.killtotal 0)
    (set! wl.killcount 0)
    (set! wl.treasuretotal 0)
    (set! wl.secrettotal 0)
    (bytes.fill wl.tilemap 0 wl.MAPAREA 0)
    (wl.setup-tiles walls 0)
    (wl.init-actors)
    (set! wl.r1-clip-active 0)
    (wl.init-door-list)
    (wl.spawn-doors walls 0)
    (wl.scan-info-plane walls objects 0)
    (wl.remove-ambush-markers walls 0)
    (wl.init-areas)))

(defn wl.setup-tiles (walls index)
  (if (= index wl.MAPAREA)
      index
      (begin
        (wl.setup-tile walls index (u16@ walls (* index 2)))
        (wl.setup-tiles walls (+ index 1)))))

(defn wl.setup-tile (walls index tile)
  (if (wl.solid? tile)
      (wl.tilemap! (mod index wl.MAPSIZE) (/ index wl.MAPSIZE) tile)
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
  (if (= (wl.door-action@ door) wl.DR-OPEN)
      (wl.door-ticcount! door 0)
      (wl.door-action! door wl.DR-OPENING)))

(defn wl.locked-door? (door)
  (let ((lock (wl.door-lock@ door)))
    (and (and (>= lock 1) (<= lock 4))
         (= (bit.and wl.keys (bit.shl 1 (- lock 1))) 0))))

(defn wl.operate-door (door)
  (if (wl.locked-door? door)
      false
      (begin
        (if (or (= (wl.door-action@ door) wl.DR-CLOSED)
                (= (wl.door-action@ door) wl.DR-CLOSING))
            (wl.open-door door)
            (wl.close-door door))
        true)))

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
      (begin (wl.door-action! door wl.DR-CLOSING) true)))

(defn wl.door-open (door)
  (let ((count (+ (wl.door-ticcount@ door) wl.tics)))
    (begin
      (wl.door-ticcount! door count)
      (if (>= count wl.OPENTICS) (wl.close-door door) nil))))

(defn wl.door-opening (door)
  (let ((position (+ (wl.door-position@ door) (bit.shl wl.tics 10))))
    (begin
      (if (= (wl.door-position@ door) 0) (wl.change-door-area-connection door 1) nil)
      (if (>= position 65535)
          (begin
            (wl.door-position! door 65535)
            (wl.door-ticcount! door 0)
            (wl.door-action! door wl.DR-OPEN))
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
  (if (and (= high 0) (= low 0)) "0" (wl.u32-decimal-nonzero high low)))

(defn wl.u32-decimal-nonzero (high low)
  (let ((quotient-high (/ high 10)) (combined (+ (* (mod high 10) 65536) low)))
    (wl.u32-decimal-digit quotient-high (/ combined 10) (mod combined 10))))

(defn wl.u32-decimal-digit (high low digit)
  (string.append
    (if (and (= high 0) (= low 0)) "" (wl.u32-decimal-nonzero high low))
    (string.slice "0123456789" digit (+ digit 1))))

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
    (if (and (= tile 49) (= index (+ 40 (* 61 wl.MAPSIZE))))
        (begin
          (set! wl.r1-clip-active 1)
          (set! wl.r1-clip-x (mod index wl.MAPSIZE))
          (set! wl.r1-clip-y (/ index wl.MAPSIZE)))
        nil)
    (if (wl.player-start? tile)
        (wl.spawn-player (mod index wl.MAPSIZE) (/ index wl.MAPSIZE)
                         (+ wl.NORTH (- tile wl.PLAYERSTART-FIRST)))
        nil)
    (wl.scan-info-plane walls objects (+ index 1))))

(defn wl.update-r1-clip-bonus ()
  (if (= wl.r1-clip-active 0)
      false
      (begin
        (wl.calc-view)
        (if (wl.transform-tile-in-range? wl.r1-clip-x wl.r1-clip-y)
            (wl.get-r1-clip)
            false))))

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

(defn wl.get-r1-clip ()
  (if (= wl.ammo 99)
      false
      (begin
        (set! wl.ammo (+ wl.ammo 8))
        (if (> wl.ammo 99) (set! wl.ammo 99) nil)
        (set! wl.r1-clip-active 0)
        true)))

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
