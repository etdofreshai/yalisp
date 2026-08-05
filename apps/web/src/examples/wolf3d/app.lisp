

(defn app.assets ()
  '(assets (maphead "/assets/wolf3d/MAPHEAD.WL6")
           (gamemaps "/assets/wolf3d/GAMEMAPS.WL6")
           (vswap "/assets/wolf3d/VSWAP.WL6")
           (gamepal "/assets/wolf3d/GAMEPAL.OBJ")))

(define app.tinf nil)
(define app.maps nil)
(define app.planes nil)
(define app.wall-plane nil)
(define app.object-plane nil)
(define app.gamepal nil)
(define app.map-name "")
(define app.frame-buffer (bytes.alloc 64000))
(define app.use-held 0)
(define app.attack-held 0)
(define app.time-count 0)
(define app.trace-tics 0)
(define app.trace-controlx 0)
(define app.trace-controly 0)
(define app.trace-buttons 0)
(define app.plane0hash-high 0)
(define app.plane0hash-low 0)
(define app.plane1hash-high 0)
(define app.plane1hash-low 0)

(defn app.at (xs n)
  (if (= n 0) (car xs) (app.at (cdr xs) (- n 1))))

(defn app.input? (input name)
  (let ((row (assoc name input)))
    (if row (app.at row 1) 0)))

(defn app.mounted? () (not (nil? app.wall-plane)))

(defn app.assets-mounted (mounted)
  (begin
    (app.setup-pictures mounted)
    (if (and (assoc 'maphead mounted) (assoc 'gamemaps mounted))
        (begin
          (wl.new-game 2 0)
          (app.setup-level (asset.ref (app.at (assoc 'maphead mounted) 1))
                           (asset.ref (app.at (assoc 'gamemaps mounted) 1))
                           0))
        nil)))

(defn app.asset (mounted name)
  (let ((row (assoc name mounted)))
    (if row (asset.ref (app.at row 1)) nil)))

(defn app.setup-pictures (mounted)
  (app.setup-pictures-with (app.asset mounted 'vswap) (app.asset mounted 'gamepal)))

(defn app.setup-pictures-with (vswap gamepal)
  (if (and (not (nil? vswap)) (and (not (nil? gamepal)) (vl.palette? gamepal)))
      (begin
        (pm.startup vswap)
        (set! app.gamepal gamepal)
        (wl.set-textured 1))
      (wl.set-textured 0)))

(defn app.setup-level (tinf maps mapnum)
  (begin
    (wl.select-map mapnum)
    (set! app.tinf tinf)
    (set! app.maps maps)
    (set! app.planes (ca.cache-map tinf maps mapnum))
    (set! app.wall-plane (car app.planes))
    (set! app.object-plane (car (cdr app.planes)))
    (set! app.map-name (ca.map-name maps (ca.header-offset tinf mapnum)))
    ;; The planes, the plane list, and the name are live from here on and were
    ;; allocated above, so the reclaimable region starts after them. Everything
    ;; below writes into buffers that were allocated when this file was loaded
    ;; and keeps nothing else, which is what makes the release sound.
    (app.setup-tables (heap.used))))

(defn app.setup-tables (mark)
  (begin
    (wl.build-tables)
    (wl.calc-projection)
    (wl.setup-game-level app.wall-plane app.object-plane)
    (wl.init-player-loop)
    (set! app.time-count 0)
    (set! app.use-held 0)
    (set! app.attack-held 0)
    (app.cache-plane-hashes (wl.plane-hash-words app.wall-plane)
                            (wl.plane-hash-words app.object-plane))
    (heap.release mark)))

(defn app.cache-plane-hashes (plane0 plane1)
  (begin
    (set! app.plane0hash-high (car plane0))
    (set! app.plane0hash-low (car (cdr plane0)))
    (set! app.plane1hash-high (car plane1))
    (set! app.plane1hash-low (car (cdr plane1)))))


(defn app.flat-palette ()
  '("#000000" "#4a4a52" "#2b2b30"
    "#8e8e96" "#6a6a72" "#5b6f8e" "#43536b" "#8a6f4a" "#68533a" "#7a8a6a" "#5b6a4e"
    "#161a20"))

(defn app.palette ()
  (if (wl.textured?) (vl.palette-colours app.gamepal) (app.flat-palette)))

(defn app.controls ()
  '((forward press step-forward (ArrowUp w))
    (backward press step-back (ArrowDown s))
    (turn-left press turn-left (ArrowLeft a))
    (turn-right press turn-right (ArrowRight d))
    (use press use (Space e))))

(defn app.mount ()
  (list 'mount 320 200 'Wolf3D
        (app.controls)
        (list 'surface 'indexed8 (app.palette))))

(defn app.timing () '(timing 70 6))

(defn app.state ()
  (if (app.mounted?)
      (list (wl.player@ wl.PLAYER-TILEX) (wl.player@ wl.PLAYER-TILEY)
            (wl.player@ wl.PLAYER-ANGLE)
            (wl.player@ wl.PLAYER-X) (wl.player@ wl.PLAYER-Y))
      (list 0 0 0 0 0)))

(defn app.attach () (app.state))

(defn app.advance (input)
  (if (app.mounted?)
      (app.advance-marked input (heap.used))
      nil))

(defn app.advance-marked (input mark)
  (begin
    (set! wl.tics 6)
    (set! app.time-count (+ app.time-count wl.tics))
    (set! app.trace-tics wl.tics)
    (set! app.trace-controlx
          (* (- (app.input? input 'turn-right) (app.input? input 'turn-left))
             (* wl.BASEMOVE wl.tics)))
    (set! app.trace-controly
          (* (- (app.input? input 'backward) (app.input? input 'forward))
             (* wl.BASEMOVE wl.tics)))
    (set! app.trace-buttons (if (> (app.input? input 'use) 0) 8 0))
    ;; PlayLoop moves doors before T_Player handles use and movement. Thus a
    ;; use tick changes action only; position first changes on the next tick.
    (set! wl.madenoise 0)
    (wl.move-doors)
    (app.player-tick (app.input? input 'use) 0
                     app.trace-controlx app.trace-controly)
    (wl.move-actors)
    (wl.update-r1-clip-bonus)
    (app.prepare-attack-visibility)
    (heap.release mark)))

(defn app.player-tick (use attack controlx controly)
  (begin
    (wl.update-face)
    (if (= wl.attack-active 1)
        (begin
          (wl.control-movement controlx controly)
          (wl.update-attack))
        (begin
          (app.poll-use use)
          (if (and (> attack 0) (= app.attack-held 0)) (wl.start-attack) nil)
          (wl.control-movement controlx controly)))
    (set! app.attack-held (if (> attack 0) 1 0))))

(defn app.prepare-attack-visibility ()
  (if (and (= wl.attack-active 1)
           (and (= wl.attackframe 1) (<= wl.attackcount wl.tics)))
      (wl.refresh-actor-visibility)
      nil))

(defn app.poll-use (pressed)
  (if (= pressed 0)
      (set! app.use-held 0)
      (if (= app.use-held 0)
          (begin (set! app.use-held 1) (wl.cmd-use))
          nil)))

(defn app.trace-projection-contract ()
  '(projection wolf3d-trace-bin-v3
    (fields tick tics score health ammo keys lives x y angle tilex tiley
            state flags controlx controly buttons difficulty map episode
            bestweapon weapon chosenweapon faceframe attackframe attackcount
            weaponframe killcount secrettotal treasuretotal killtotal
            doorchecksum plane0hash plane1hash)
    (encoding plane0hash u32-decimal plane1hash u32-decimal)
    (omitted secretcount treasurecount
             pwallstate pwallpos pwallx pwally pwalldir
             rndindex actorhash worldhash)))

(defn app.trace-record ()
  (list (list 'tick app.time-count)
        (list 'tics app.trace-tics)
        (list 'score wl.score)
        (list 'health wl.health)
        (list 'ammo wl.ammo)
        (list 'keys wl.keys)
        (list 'lives wl.lives)
        (list 'x (wl.player@ wl.PLAYER-X))
        (list 'y (wl.player@ wl.PLAYER-Y))
        (list 'angle (wl.player@ wl.PLAYER-ANGLE))
        (list 'tilex (wl.player@ wl.PLAYER-TILEX))
        (list 'tiley (wl.player@ wl.PLAYER-TILEY))
        (list 'state (wl.player@ wl.PLAYER-STATE))
        (list 'flags (wl.player@ wl.PLAYER-FLAGS))
        (list 'controlx app.trace-controlx)
        (list 'controly app.trace-controly)
        (list 'buttons app.trace-buttons)
        (list 'difficulty wl.difficulty)
        (list 'map wl.map)
        (list 'episode wl.episode)
        (list 'bestweapon wl.bestweapon)
        (list 'weapon wl.weapon)
        (list 'chosenweapon wl.chosenweapon)
        (list 'faceframe wl.faceframe)
        (list 'attackframe wl.attackframe)
        (list 'attackcount wl.attackcount)
        (list 'weaponframe wl.weaponframe)
        (list 'killcount wl.killcount)
        (list 'secrettotal wl.secrettotal)
        (list 'treasuretotal wl.treasuretotal)
        (list 'killtotal wl.killtotal)
        (list 'doorchecksum (wl.door-checksum))
        (list 'plane0hash (wl.u32-decimal app.plane0hash-high app.plane0hash-low))
        (list 'plane1hash (wl.u32-decimal app.plane1hash-high app.plane1hash-low))))

(defn app.replay-advance (tics controlx controly buttons)
  (if (app.mounted?)
      (app.replay-advance-marked tics controlx controly buttons (heap.used))
      nil))

(defn app.replay-advance-marked (tics controlx controly buttons mark)
  (begin
    (set! wl.tics tics)
    (set! app.time-count (+ app.time-count tics))
    (set! app.trace-tics tics)
    (set! app.trace-controlx controlx)
    (set! app.trace-controly controly)
    (set! app.trace-buttons buttons)
    (set! wl.madenoise 0)
    (wl.move-doors)
    (app.player-tick (if (> (bit.and buttons 8) 0) 1 0)
                     (if (> (bit.and buttons 1) 0) 1 0)
                     controlx controly)
    (wl.move-actors)
    (wl.update-r1-clip-bonus)
    (app.prepare-attack-visibility)
    (heap.release mark)
    (app.trace-record)))

(defn app.render () (app.render-marked (heap.used)))

(defn app.render-marked (mark)
  (begin
    (wl.three-d-refresh app.frame-buffer)
    (heap.release mark)
    app.frame-buffer))

(defn app.frame-bytes () (app.render))

(defn app.view (state)
  (if (app.mounted?)
      (list '(framebuffer app.frame-bytes)
            (list 'status app.map-name
                  (app.at state 0) (app.at state 1) (app.at state 2)))
      (list '(draw (clear "#161a20"))
            '(status "originals not mounted - run scripts/mount-assets.mjs"))))

(defn app.present () (app.view (app.state)))

(defn app.initial-state () (app.state))

(defn app.frame (state input)
  (begin
    (app.advance input)
    (cons (list 'state (app.state)) (app.view (app.state)))))
