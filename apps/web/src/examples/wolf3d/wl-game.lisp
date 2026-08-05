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
;; SetupGameLevel puts every solid plane-0 tile into tilemap AND actorat, so the
;; original actorat cell holds either a small tile number or a live actor's far
;; pointer. A Lisp byte cannot carry both, so the actor half stays in
;; wl.actorat and the wall half lives here; wl.actorat-occupied? is the source's
;; single `actorat[x][y]` test.
(define wl.actorat-wall (bytes.alloc 4096))
(define wl.MAXSTATICS 400)
(define wl.staticcount 0)
(define wl.staticx (bytes.alloc 400))
(define wl.staticy (bytes.alloc 400))
(define wl.staticitem (bytes.alloc 400))
(define wl.BO-CROSS 9)
(define wl.BO-CHALICE 10)
(define wl.BO-BIBLE 11)
(define wl.BO-CROWN 12)
(define wl.BO-CLIP 13)
(define wl.BO-FULLHEAL 18)

(defn wl.tilemap@ (x y) (u8@ wl.tilemap (+ (bit.shl x wl.MAPSHIFT) y)))
(defn wl.tilemap! (x y v) (u8! wl.tilemap (+ (bit.shl x wl.MAPSHIFT) y) v))

(defn wl.actorat-wall@ (x y) (u8@ wl.actorat-wall (+ (bit.shl x wl.MAPSHIFT) y)))
(defn wl.actorat-wall! (x y v) (u8! wl.actorat-wall (+ (bit.shl x wl.MAPSHIFT) y) v))

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
    (set! wl.treasurecount 0)
    (set! wl.secrettotal 0)
    ;; The `if (!loadedgame)` block resets secretcount with the other counters.
    ;; It does not touch pwallstate, pwallpos, pwallx, pwally, or pwalldir, and
    ;; neither does this, so a level change carries them exactly as it does in
    ;; the original.
    (set! wl.secretcount 0)
    (set! wl.plane0-dirty 0)
    (set! wl.plane1-dirty 0)
    (bytes.fill wl.tilemap 0 wl.MAPAREA 0)
    (bytes.fill wl.actorat-wall 0 wl.MAPAREA 0)
    (wl.setup-tiles walls 0)
    (wl.init-actors)
    (wl.init-static-list)
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

;;
;; PUSHABLE WALLS
;;
;; PushWall's activation and MovePWalls' motion are both implemented, and those
;; two functions are the only writers of these five variables anywhere in the
;; source outside SaveTheGame/LoadTheGame. SetupGameLevel deliberately resets
;; none of them and neither does this port. Still absent: PUSHWALLSND/NOWAYSND,
;; the renderer's pwallpos wall offset, and the elevator/secret-exit arm.
;;
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

;; The source switch either refuses with NOWAYSND, which this port does not
;; play, or copies the moved tile one cell further along dir into both actorat
;; and tilemap. A dir outside the four controldir_t values matches no case at
;; all and still reaches the counter below, which is preserved here.
(defn wl.push-wall-clear? (checkx checky dir oldtile)
  (cond ((= dir wl.NORTH) (wl.push-wall-step checkx (- checky 1) oldtile))
        ((= dir wl.EAST) (wl.push-wall-step (+ checkx 1) checky oldtile))
        ((= dir wl.SOUTH) (wl.push-wall-step checkx (+ checky 1) oldtile))
        ((= dir wl.WEST) (wl.push-wall-step (- checkx 1) checky oldtile))
        (true true)))

;; Both switches — PushWall's and MovePWalls' — are the same three statements:
;; refuse on an occupied cell, otherwise write oldtile into actorat and tilemap.
(defn wl.push-wall-step (x y oldtile)
  (if (wl.actorat-occupied? x y)
      false
      (begin
        (wl.actorat-wall! x y oldtile)
        (wl.tilemap! x y oldtile)
        true)))

(defn wl.push-wall-activate (checkx checky dir)
  (begin
    (set! wl.secretcount (+ wl.secretcount 1))
    (set! wl.pwallx checkx)
    (set! wl.pwally checky)
    (set! wl.pwalldir dir)
    (set! wl.pwallstate 1)
    (set! wl.pwallpos 0)
    (wl.tilemap! wl.pwallx wl.pwally (bit.or (wl.tilemap@ wl.pwallx wl.pwally) 192))
    ;; remove P tile info
    (u16! wl.level-objects (* (+ (* wl.pwally wl.MAPSIZE) wl.pwallx) 2) 0)
    ;; The object plane is one of the two projected plane hashes, so the cached
    ;; fingerprint has to be recomputed once this tic finishes rather than kept.
    (set! wl.plane1-dirty 1)
    true))

;;
;; MovePWalls, called from PlayLoop between MoveDoors and the actor loop.
;;
(defn wl.move-pwalls ()
  (if (= wl.pwallstate 0)
      nil
      (wl.move-pwalls-tic (/ wl.pwallstate 128))))

;; `oldblock = pwallstate/128; pwallstate += tics;` and then the block-crossing
;; test. `pwallpos = (pwallstate/2)&63` is the function's last statement, so the
;; only paths that skip it are the two that `return` after zeroing pwallstate.
(defn wl.move-pwalls-tic (oldblock)
  (begin
    (set! wl.pwallstate (+ wl.pwallstate wl.tics))
    (if (= (/ wl.pwallstate 128) oldblock)
        (wl.pwall-position)
        (wl.move-pwalls-block (bit.and (wl.tilemap@ wl.pwallx wl.pwally) 63)))))

;; The vacated tile joins the *player's* area rather than the area it was cut
;; out of, which is how a secret room opens onto wherever the player stands.
;; This port has no stored player->areanumber; Thrust recomputes it from this
;; same plane-0 cell on every move and MovePWalls runs before T_Player, so
;; wl.player-area reads exactly the value the original carried into this line.
(defn wl.move-pwalls-block (oldtile)
  (begin
    ;; the tile can now be walked into
    (wl.tilemap! wl.pwallx wl.pwally 0)
    (wl.actorat-clear! wl.pwallx wl.pwally)
    (u16! wl.level-walls (* (+ (* wl.pwally wl.MAPSIZE) wl.pwallx) 2)
          (+ (wl.player-area) wl.AREATILE))
    (set! wl.plane0-dirty 1)
    ;; see if it should be pushed farther
    (if (> wl.pwallstate 256)
        ;; the block has been pushed two tiles
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

;; Every arm moves pwallx/pwally first and only then tests the cell beyond it,
;; so a refused push leaves both variables at the advanced tile exactly as the
;; source does. A pwalldir outside the four controldir_t values matches no case,
;; moves nothing, and still falls through to the retag below it.
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
        (true true)))

(defn wl.pwall-position ()
  (set! wl.pwallpos (bit.and (/ wl.pwallstate 2) 63)))

;; `(unsigned)actorat[pwallx][pwally] = 0` clears one original cell, and this
;; port splits that cell into a wall half and a live-actor half, so both are
;; cleared for wl.actorat-occupied? to keep agreeing with the source test.
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
      ;; `if ((unsigned)actorat[x][y] == AMBUSHTILE) actorat[x][y] = NULL;`
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
    (if (> (wl.static-item-for-tile tile) 0)
        (wl.spawn-static-item (mod index wl.MAPSIZE) (/ index wl.MAPSIZE)
                              (wl.static-item-for-tile tile)) nil)
    (if (wl.player-start? tile)
        (wl.spawn-player (mod index wl.MAPSIZE) (/ index wl.MAPSIZE)
                         (+ wl.NORTH (- tile wl.PLAYERSTART-FIRST)))
        nil)
    (wl.scan-info-plane walls objects (+ index 1))))

;; ScanInfoPlane hands object tiles 23-74 to SpawnStatic as statinfo[tile-23].
;; Only the bonus subset this slice owns is spawned: statinfo 26 clip and the
;; five treasure entries 29-33. Blocking and dressing statics, the other
;; pickups, and their actorat side effects are not part of this slice.
(defn wl.static-item-for-tile (tile)
  (cond ((= tile 49) wl.BO-CLIP)
        ((= tile 52) wl.BO-CROSS)
        ((= tile 53) wl.BO-CHALICE)
        ((= tile 54) wl.BO-BIBLE)
        ((= tile 55) wl.BO-CROWN)
        ((= tile 56) wl.BO-FULLHEAL)
        (true 0)))

(defn wl.init-static-list ()
  (begin (set! wl.staticcount 0) (bytes.fill wl.staticitem 0 wl.MAXSTATICS 0)))

(defn wl.spawn-static-item (x y item)
  (if (= wl.staticcount wl.MAXSTATICS) -1
      (let ((index wl.staticcount))
        (begin (u8! wl.staticx index x) (u8! wl.staticy index y)
               (u8! wl.staticitem index item)
               (set! wl.staticcount (+ wl.staticcount 1)) index))))

(defn wl.static-at (x y index)
  (if (= index wl.staticcount) -1
      (if (and (= (u8@ wl.staticx index) x) (= (u8@ wl.staticy index) y)) index
          (wl.static-at x y (+ index 1)))))

(defn wl.update-static-bonuses ()
  (begin (wl.calc-view) (wl.update-static-at 0)))

;; DrawScaleds walks the whole static list and collects any FL_BONUS entry
;; TransformTile puts inside the pickup box. Its `*statptr->visspot` gate needs
;; the renderer's spotvis, which this slice does not keep, so every live static
;; is offered to the same bounds test.
(defn wl.update-static-at (index)
  (if (= index wl.staticcount) false
      (let ((got (if (and (> (u8@ wl.staticitem index) 0)
                           (wl.transform-tile-in-range? (u8@ wl.staticx index) (u8@ wl.staticy index)))
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
  (let ((got (wl.apply-static-item (u8@ wl.staticitem index))))
    (if got (begin (u8! wl.staticitem index 0) true) false)))

(defn wl.apply-static-item (item)
  (cond ((= item wl.BO-CROSS) (wl.give-treasure 100))
        ((= item wl.BO-CHALICE) (wl.give-treasure 500))
        ((= item wl.BO-BIBLE) (wl.give-treasure 1000))
        ((= item wl.BO-CROWN) (wl.give-treasure 5000))
        ((= item wl.BO-CLIP) (if (= wl.ammo 99) false (begin (wl.give-ammo 8) true)))
        ((= item wl.BO-FULLHEAL)
         (begin (wl.heal-self 99) (wl.give-ammo 25) (wl.give-extra-man)
                (set! wl.treasurecount (+ wl.treasurecount 1)) true))
        (true false)))

(defn wl.give-treasure (points)
  (begin (wl.give-points points)
         (set! wl.treasurecount (+ wl.treasurecount 1)) true))

;; HealSelf adds its points and clamps; bo_fullheal asks for 99, not for 100.
(defn wl.heal-self (points)
  (begin (set! wl.health (+ wl.health points))
         (if (> wl.health 100) (set! wl.health 100) nil)))

(defn wl.give-ammo (amount)
  (begin
    ;; The knife was out, so the chosen firearm returns before the ammo lands.
    (if (and (= wl.ammo 0) (= wl.attackframe 0))
        (set! wl.weapon wl.chosenweapon) nil)
    (set! wl.ammo (+ wl.ammo amount))
    (if (> wl.ammo 99) (set! wl.ammo 99) nil)))

(defn wl.give-extra-man ()
  (if (< wl.lives 9) (set! wl.lives (+ wl.lives 1)) nil))

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
