

(defn app.assets ()
  '(assets (maphead "/assets/wolf3d/MAPHEAD.WL6")
           (gamemaps "/assets/wolf3d/GAMEMAPS.WL6")
           (vswap "/assets/wolf3d/VSWAP.WL6")
           (vgahead "/assets/wolf3d/VGAHEAD.WL6")
           (vgagraph "/assets/wolf3d/VGAGRAPH.WL6")
           (vgadict "/assets/wolf3d/VGADICT.WL6")
           (gamepal "/assets/wolf3d/GAMEPAL.OBJ")))

(define app.tinf nil)
(define app.maps nil)
(define app.planes nil)
(define app.wall-plane nil)
(define app.object-plane nil)
(define app.gamepal nil)
(define app.vgahead nil)
(define app.vgagraph nil)
(define app.vgadict nil)
(define app.pictable nil)
(define app.drawn-face-picture -1)
(define app.drawn-health nil)
(define app.drawn-weapon-picture -1)
(define app.drawn-score nil)
(define app.GRAPHICS-HEAP-RESERVE 2097152)
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
    (if (app.required-assets? mounted)
        (begin
          ;; Huffman expansion is Lisp-owned and transiently evaluates one
          ;; bounded source block at a time. Declare its headroom before setup
          ;; so capacity failure happens here rather than halfway through a chunk.
          (heap.reserve app.GRAPHICS-HEAP-RESERVE)
          (set! app.vgahead (app.asset mounted 'vgahead))
          (set! app.vgagraph (app.asset mounted 'vgagraph))
          (set! app.vgadict (app.asset mounted 'vgadict))
          (set! app.pictable
                (vh.load-pictable app.vgahead app.vgagraph app.vgadict))
          (wl.new-game 2 0)
          (app.setup-level (asset.ref (app.at (assoc 'maphead mounted) 1))
                           (asset.ref (app.at (assoc 'gamemaps mounted) 1))
                           0))
        nil)))

(defn app.required-assets? (mounted)
  (and (assoc 'maphead mounted)
       (and (assoc 'gamemaps mounted)
            (and (assoc 'vswap mounted)
                 (and (assoc 'gamepal mounted)
                      (and (assoc 'vgahead mounted)
                           (and (assoc 'vgagraph mounted)
                                (assoc 'vgadict mounted))))))))

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
    ;; Setup temporaries precede this mark; later writes target persistent buffers.
    (app.setup-tables (heap.used))))

(defn app.setup-tables (mark)
  (begin
    (wl.build-tables)
    (wl.calc-projection)
    (wl.setup-game-level app.wall-plane app.object-plane)
    (wl.init-player-loop)
    (vh.draw-statusbar app.vgahead app.vgagraph app.vgadict app.frame-buffer)
    ;; DrawPlayScreen draws the static bar first, then face, health, weapon and score.
    (set! app.drawn-face-picture -1)
    (app.refresh-face)
    (set! app.drawn-health nil)
    (app.refresh-health)
    (set! app.drawn-weapon-picture -1)
    (app.refresh-weapon)
    (set! app.drawn-score nil)
    (app.refresh-score)
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
    ;; Preserve PlayLoop order: doors/pwalls, then player input and movement.
    (set! wl.madenoise 0)
    (wl.move-doors)
    (wl.move-pwalls)
    (app.player-tick (app.input? input 'use) 0
                     app.trace-controlx app.trace-controly)
    (wl.move-actors)
    (wl.update-static-bonuses)
    (app.refresh-renderer-state)
    (app.refresh-plane-hashes)
    (heap.release mark)))

(defn app.player-tick (use attack controlx controly)
  (begin
    (wl.update-face)
    ;; buttonheld-use is the prior tic's use state.
    (set! wl.buttonheld-use app.use-held)
    (set! app.use-held (if (> use 0) 1 0))
    (if (= wl.attack-active 1)
        (begin
          (wl.control-movement controlx controly)
          (wl.update-attack))
        (begin
          (if (> use 0) (wl.cmd-use) nil)
          (if (and (> attack 0) (= app.attack-held 0)) (wl.start-attack) nil)
          (wl.control-movement controlx controly)))
    (set! app.attack-held (if (> attack 0) 1 0))))

(defn app.refresh-renderer-state ()
  (begin
    (wl.refresh-actor-visibility)
    (app.refresh-face)
    (app.refresh-health)
    (app.refresh-weapon)
    (app.refresh-score)))

(defn app.refresh-face ()
  (app.refresh-face-picture (wl.living-face-picture)))

(defn app.refresh-face-picture (picture)
  (if (< picture 0)
      (set! app.drawn-face-picture -1)
      (if (= picture app.drawn-face-picture)
          picture
          (begin
            (vh.status-draw-picture app.vgahead app.vgagraph app.vgadict
                                    app.pictable app.frame-buffer 17 4 picture)
            (set! app.drawn-face-picture picture)))))

(defn app.refresh-health ()
  (app.refresh-health-number wl.health))

(defn app.refresh-health-number (number)
  (if (and (not (nil? app.drawn-health)) (= number app.drawn-health))
      number
      (app.draw-health-number number (heap.used))))

(defn app.draw-health-number (number mark)
  (begin
    ;; LatchNumber draws directly and left-to-right.  A rejected later cell can
    ;; therefore leave its already-drawn prefix, but the cache advances only
    ;; after the complete number succeeds.
    (app.draw-number-chunks app.frame-buffer (wl.latch-number-chunks 3 number) 21 16)
    (heap.release mark)
    (set! app.drawn-health number)))

(defn app.draw-number-chunks (frame chunks x y)
  (if (nil? chunks)
      frame
      (begin
        (vh.status-draw-picture app.vgahead app.vgagraph app.vgadict
                                app.pictable frame x y (car chunks))
        (app.draw-number-chunks frame (cdr chunks) (+ x 1) y))))

(defn app.refresh-weapon ()
  (app.refresh-weapon-picture (wl.status-weapon-picture)))

(defn app.refresh-weapon-picture (picture)
  (if (= picture app.drawn-weapon-picture)
      picture
      (begin
        (vh.status-draw-picture app.vgahead app.vgagraph app.vgadict
                                app.pictable app.frame-buffer 32 8 picture)
        (set! app.drawn-weapon-picture picture))))

(defn app.refresh-score ()
  (app.refresh-score-number wl.score))

(defn app.refresh-score-number (number)
  (if (and (not (nil? app.drawn-score)) (= number app.drawn-score))
      number
      (app.draw-score-number number (heap.used))))

(defn app.draw-score-number (number mark)
  (begin
    ;; Preserve LatchNumber's direct left-to-right writes and advance the
    ;; numeric cache only after all six source cells have completed.
    (app.draw-number-chunks app.frame-buffer (wl.latch-number-chunks 6 number) 6 16)
    (heap.release mark)
    (set! app.drawn-score number)))

;; Only dirty gameplay planes are rehashed.
(defn app.refresh-plane-hashes ()
  (begin (app.refresh-plane0-hash) (app.refresh-plane1-hash)))

(defn app.refresh-plane0-hash ()
  (if (= wl.plane0-dirty 1) (app.recache-plane0-hash) nil))

(defn app.recache-plane0-hash ()
  (let ((words (wl.plane-hash-words app.wall-plane)))
    (begin
      (set! app.plane0hash-high (car words))
      (set! app.plane0hash-low (car (cdr words)))
      (set! wl.plane0-dirty 0))))

(defn app.refresh-plane1-hash ()
  (if (= wl.plane1-dirty 1) (app.recache-plane1-hash) nil))

(defn app.recache-plane1-hash ()
  (let ((words (wl.plane-hash-words app.object-plane)))
    (begin
      (set! app.plane1hash-high (car words))
      (set! app.plane1hash-low (car (cdr words)))
      (set! wl.plane1-dirty 0))))

(defn app.trace-projection-contract ()
  '(projection wolf3d-trace-bin-v3
    (fields tick tics score health ammo keys lives x y angle tilex tiley
            state flags controlx controly buttons difficulty map episode
            bestweapon weapon chosenweapon faceframe attackframe attackcount
            weaponframe secretcount treasurecount killcount secrettotal
            treasuretotal killtotal pwallstate pwallpos pwallx pwally pwalldir
            doorchecksum rndindex plane0hash plane1hash actorhash worldhash)
    (encoding plane0hash u32-decimal plane1hash u32-decimal
              actorhash u32-decimal worldhash u32-decimal)
    (omitted)))

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
        (list 'secretcount wl.secretcount)
        (list 'treasurecount wl.treasurecount)
        (list 'killcount wl.killcount)
        (list 'secrettotal wl.secrettotal)
        (list 'treasuretotal wl.treasuretotal)
        (list 'killtotal wl.killtotal)
        (list 'pwallstate wl.pwallstate)
        (list 'pwallpos wl.pwallpos)
        (list 'pwallx wl.pwallx)
        (list 'pwally wl.pwally)
        (list 'pwalldir wl.pwalldir)
        (list 'doorchecksum (wl.door-checksum))
        (list 'rndindex wl.rndindex)
        (list 'plane0hash (wl.u32-decimal app.plane0hash-high app.plane0hash-low))
        (list 'plane1hash (wl.u32-decimal app.plane1hash-high app.plane1hash-low))
        (list 'actorhash (wl.actor-hash-decimal))
        (list 'worldhash (wl.world-hash-decimal))))

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
    (wl.move-pwalls)
    (app.player-tick (if (> (bit.and buttons 8) 0) 1 0)
                     (if (> (bit.and buttons 1) 0) 1 0)
                     controlx controly)
    (wl.move-actors)
    (wl.update-static-bonuses)
    (app.refresh-renderer-state)
    (app.refresh-plane-hashes)
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
