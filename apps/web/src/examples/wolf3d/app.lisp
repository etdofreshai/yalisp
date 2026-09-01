

(defn app.assets ()
  '(assets (maphead "/assets/wolf3d/MAPHEAD.WL6")
           (gamemaps "/assets/wolf3d/GAMEMAPS.WL6")
           (vswap "/assets/wolf3d/VSWAP.WL6")
           (vgahead "/assets/wolf3d/VGAHEAD.WL6")
           (vgagraph "/assets/wolf3d/VGAGRAPH.WL6")
           (vgadict "/assets/wolf3d/VGADICT.WL6")
           (audiohed "/assets/wolf3d/AUDIOHED.WL6")
           (audiot "/assets/wolf3d/AUDIOT.WL6")
           (gamepal "/assets/wolf3d/GAMEPAL.OBJ")))

(define app.tinf nil)
(define app.maps nil)
(define app.planes nil)
(define app.wall-plane nil)
(define app.object-plane nil)
(define app.map-expand-buffer (bytes.alloc 65536))
(define app.wall-plane-storage (bytes.alloc ca.MAPSIZE))
(define app.object-plane-storage (bytes.alloc ca.MAPSIZE))
(define app.gamepal nil)
(define app.vgahead nil)
(define app.vgagraph nil)
(define app.vgadict nil)
(define app.audiohed nil)
(define app.audiot nil)
(define app.vswap nil)
(define app.pictable nil)
(define app.drawn-face-picture -1)
(define app.drawn-health nil)
(define app.drawn-lives nil)
(define app.drawn-level nil)
(define app.drawn-ammo nil)
(define app.drawn-keys nil)
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
(define app.mounted-assets nil)
(define app.runtime-started 0)
(define app.runtime-failure 'not-started)
(define app.assets-startup-state 0)
(define app.assets-startup-failure nil)
(define app.assets-startup-mounted nil)
(define app.assets-startup-last-stage 'idle)
(define app.assets-startup-heap-before 0)
(define app.assets-startup-heap-after 0)
(define app.fixed-tables-ready 0)
(define app.fixed-renderer-ready 0)
(define app.projection-view-size -1)
(define app.lifecycle-events nil)
(define app.advance-release-count 0)
(define app.advance-retain-count 0)
(define app.advance-last-retain-mask 0)
(define app.help-article-bytes nil)
(define app.help-article "")
(define app.end-article-bytes nil)
(define app.end-article "")
(define app.intermission-result nil)
(define app.fizzle-pending 0)
(define app.fizzle-prepared 0)
(define app.finished-demo nil)
(define app.deathcam-presentation-phase 0)
(define app.deathcam-presentation-remaining 0)
(define app.deathcam-presentation-carry 0)
(define app.deathcam-victory-consumed 0)
(define app.victory-high-score-insert -1)
(define app.r0-phase 0)
(define app.r0-lifecycle nil)
(define app.r0-frames nil)
(define app.r0-menu-audio nil)
(define app.r0-level-audio nil)
(define app.r0-level-music-started 0)
(define app.r0-shutdown-complete 0)
(define app.r0-signon-font nil)
(define app.r0-route-profile
  '((main-kib 320) (ems-kib 1000) (xms-kib 1000)
    (mouse true) (joystick true) (sound-source true)
    (adlib false) (sound-blaster false)))
(define app.R0-TITLEPIC 87)
(define app.AUDIO-OP-MAX 1073741823)
(define app.r5-capture-active 0)
(define app.r5-config-seed nil)
(define app.r5-frame-pixels nil)
(define app.r5-export-complete 0)
(define app.r3-active 0)
(define app.r3-phase 0)
(define app.r3-events nil)
(define app.r3-lifecycle nil)
(define app.r3-saved-bytes nil)
(define app.r3-saved-x 0)
(define app.r3-saved-y 0)
(define app.r3-saved-tilex 0)
(define app.r3-saved-tiley 0)
(define app.r1-active 0)
(define app.r1-phase 0)
(define app.r1-events nil)
(define app.r1-lifecycle nil)
(define app.r1-trace nil)
(define app.r1-trace-count 0)
(define app.r1-trace-mode 0)
(define app.r1-stream-count 0)
(define app.r1-pending-trace 0)
(define app.r1-pending-record 0)
(define app.r1-pending-exported 0)
(define app.r1-render-pending 0)
(define app.r1-render-token 0)
(define app.r1-render-count 0)
(define app.r1-frames nil)
(define app.r1-frame-index 0)
(define app.r1-finished 0)
(define app.r1-audio nil)
(define app.r1-program nil)
(define app.r2-active 0)
(define app.r2-phase 0)
(define app.r2-events nil)
(define app.r2-lifecycle nil)
(define app.r2-trace nil)
(define app.r2-trace-count 0)
(define app.r2-trace-mode 0)
(define app.r2-stream-count 0)
(define app.r2-pending-trace 0)
(define app.r2-pending-record 0)
(define app.r2-pending-exported 0)
(define app.r2-render-count 0)
(define app.r2-render-pending 0)
(define app.r2-frames nil)
(define app.r2-frame-index 0)
(define app.r2-finished 0)
(define app.r2-audio nil)
(define app.r2-program nil)

(defn app.at (xs n)
  (if (= n 0) (car xs) (app.at (cdr xs) (- n 1))))

(defn app.input? (input name)
  (let ((row (assoc name input)))
    (if row (app.at row 1) 0)))

(defn app.mounted? () (not (nil? app.wall-plane)))

;;; YALisp has no language-level module loader yet, so the generic host loads
;;; these source files in order and this application verifies their public
;;; boundary before it starts. Missing subsystem exports reject startup rather
;;; than silently selecting a partial implementation.
(defn app.module-order ()
  '(wl-def wl-fixed id-ca id-pm id-vl id-vh wl-main wl-game wl-agent wl-act2
    wl-state wl-act1 wl-play wl-audio wl-sound wl-text wl-inter wl-menu wl-config wl-save wl-draw wl-scale
    app))

(defn app.required-runtime-api ()
  '(ca.cache-map pm.startup vl.palette? vl.set-palette
    vl.fade-out-begin vl.fade-in-begin vl.fade-step vh.load-pictable vh.fizzle-status
    wl.build-tables wl.setup-game-level wl.init-player-loop
    wl.application-startup wl.setup-control-panel wl.cp-new-game
    wl.control-panel-step wl.draw-control-panel wl.cache-presentation-font
    wl.draw-picture wl.play-sound wl.start-level-music
    wl.r5-begin wl.r5-action wl.r5-status wl.r5-snapshot
    wl.r5-frame wl.r5-frame-log wl.r5-attempt-log
    wl.r5-config-decode wl.r5-config-encode wl.r5-config-valid?
    wl.new-view-size-units
    wl.finish-playstate wl.play-demo wl.poll-demo-controls
    wl.deathcam-active? wl.reset-deathcam-lifecycle
    wl.poll-controls wl.copy-button-state wl.set-button
    wl.t-player wl.t-attack wl.update-sound-loc
    wl.start-demo-record wl.record-current-demo wl.finish-demo-record
    wl.new-state wl.drop-item wl.give-weapon
    wl.save-the-game wl.load-the-game wl.level-completed wl.victory wl.check-high-score
    wl.intermission-tick wl.victory-tick wl.draw-level-completed wl.draw-victory
    wl.cache-graphics-chunk wl.cache-graphics-chunk-into
    wl.byte-article wl.byte-article? wl.scan-layout-bytes
    wl.scan-layout-text wl.article-page-count
    wl.configure-help-article wl.end-text wl.begin-article
    wl.article-execution-step wl.draw-current-article wl.draw-high-scores
    wl.request-fizzle-in wl.begin-render-fizzle wl.fizzle-refresh-step wl.fizzle-running?
    wl.bar wl.write wl.finish-palette-shifts wl.three-d-refresh wl.draw-scaleds
    sd.startup sd.shutdown sd.set-tick sd.poll sd.stop-digitized sd.begin-audio-trace
    sd.set-sound-mode sd.set-digi-device sd.set-menu-digi-device sd.set-music-mode
    sd.audio-event-log sd.audio-operation-program sd.render-event-pcm sd.render-event-wav
    sd.audio-host-event-log sd.adlib-register-log sd.music-host-register-log
    sd.fx-service-count sd.music-service-count
    sd.render-pc-pcm sd.render-digitized-pcm sd.digi-map@
    sd.advance-timer sd.advance-source-tics sd.timer-rate sd.audio-capabilities))

(defn app.bindings-present? (names)
  (if (nil? names)
      true
      (and (bound? (car names)) (app.bindings-present? (cdr names)))))

(defn app.runtime-api-ready? ()
  (app.bindings-present? (app.required-runtime-api)))

(defn app.runtime-assets-ready? ()
  (and (not (nil? app.mounted-assets))
       (not (nil? (app.required-runtime-assets? app.mounted-assets)))))

(defn app.record-lifecycle (event)
  (begin
    (set! app.lifecycle-events (cons (list app.time-count event) app.lifecycle-events))
    event))

(defn app.lifecycle-log () (reverse app.lifecycle-events))

(defn app.fail-runtime (reason)
  (begin (set! app.runtime-failure reason) false))

(defn app.sync-audio-options ()
  (and (sd.set-sound-mode wl.sound-mode)
       (and (sd.set-menu-digi-device wl.digi-mode)
            (sd.set-music-mode wl.music-mode))))

(defn app.startup ()
  (if (= app.runtime-started 1)
      true
      (if (not (app.runtime-api-ready?))
          (app.fail-runtime 'missing-runtime-api)
          (if (not (app.runtime-assets-ready?))
              (app.fail-runtime 'missing-runtime-assets)
              (if (sd.startup app.audiohed app.audiot app.vswap)
                  (if (app.sync-audio-options)
                      (begin
                        (app.reset-deathcam-application-lifecycle)
                        (wl.application-startup)
                        (set! app.runtime-started 1)
                        (set! app.runtime-failure nil)
                        (app.record-lifecycle 'startup)
                        true)
                      (begin (sd.shutdown) (app.fail-runtime 'audio-mode-rejected)))
                  (app.fail-runtime 'audio-startup-rejected))))))

(defn app.shutdown ()
  (if (= app.runtime-started 0)
      false
      (begin
        (wl.stop-demo)
        (sd.shutdown)
        (wl.cp-quit true)
        (set! app.runtime-started 0)
        (app.record-lifecycle 'shutdown)
        true)))

(defn app.asset-startup-name? (name)
  (or (eq? name 'maphead)
      (or (eq? name 'gamemaps)
          (or (eq? name 'vswap)
              (or (eq? name 'vgahead)
                  (or (eq? name 'vgagraph)
                      (or (eq? name 'vgadict)
                          (or (eq? name 'audiohed)
                              (or (eq? name 'audiot) (eq? name 'gamepal))))))))))

(defn app.asset-startup-member? (value values)
  (if (nil? values) false
      (if (eq? value (car values)) true
          (app.asset-startup-member? value (cdr values)))))

(defn app.asset-startup-rows-valid? (rows names handles count)
  (if (nil? rows)
      (= count 9)
      (if (not (pair? (car rows)))
          false
          (let ((row (car rows)))
            (if (not (app.exact-list-length? row 3))
                false
                (let ((name (app.at row 0)) (handle (app.at row 1)) (length (app.at row 2)))
                  (if (or (not (app.asset-startup-name? name))
                          (or (app.asset-startup-member? name names)
                              (or (not (app.route-integer? handle))
                                  (or (< handle 0)
                                      (or (>= handle (asset.count))
                                          (or (app.asset-startup-member? handle handles)
                                              (or (not (app.route-integer? length))
                                                  (or (<= length 0)
                                                      (not (= length (bytes.length (asset.ref handle))))))))))))
                      false
                      (app.asset-startup-rows-valid? (cdr rows) (cons name names)
                                                     (cons handle handles) (+ count 1)))))))))

(defn app.assets-startup-valid? (mounted)
  (and (app.runtime-api-ready?)
       (and (app.asset-startup-rows-valid? mounted nil nil 0)
            (and (app.required-runtime-assets? mounted)
                 (vl.palette? (app.asset mounted 'gamepal))))))

(defn app.assets-startup-stage-name ()
  (cond ((= app.assets-startup-state 0) 'idle)
        ((= app.assets-startup-state 1) 'bind-pictures)
        ((= app.assets-startup-state 2) 'pictable)
        ((= app.assets-startup-state 3) 'help-article)
        ((= app.assets-startup-state 4) 'initial-level-cache)
        ((= app.assets-startup-state 5) 'fixed-renderer)
        ((= app.assets-startup-state 6) 'mutable-level)
        ((= app.assets-startup-state 7) 'runtime-startup)
        ((= app.assets-startup-state 8) 'complete)
        (true 'failed)))

(defn app.assets-startup-snapshot ()
  (list (list 'status (cond ((= app.assets-startup-state 8) 'complete)
                            ((< app.assets-startup-state 0) 'failed)
                            ((= app.assets-startup-state 0) 'idle)
                            (true 'running)))
        (list 'phase app.assets-startup-state)
        (list 'stage (app.assets-startup-stage-name))
        (list 'last-stage app.assets-startup-last-stage)
        (list 'failure app.assets-startup-failure)
        (list 'heap-before app.assets-startup-heap-before)
        (list 'heap-after app.assets-startup-heap-after)))

(defn app.assets-startup-reject (reason)
  (begin
    (set! app.assets-startup-state -1)
    (set! app.assets-startup-failure reason)
    (set! app.runtime-failure reason)
    false))

(defn app.assets-startup-begin (mounted)
  (if (not (= app.assets-startup-state 0))
      false
      (if (not (app.assets-startup-valid? mounted))
          (app.assets-startup-reject 'invalid-runtime-assets)
          (begin
            ;; Reserve the complete Lisp-owned graphics workspace before any
            ;; mounted handle becomes live application state.
            (heap.reserve app.GRAPHICS-HEAP-RESERVE)
            (set! app.assets-startup-mounted mounted)
            (set! app.assets-startup-failure nil)
            (set! app.assets-startup-last-stage 'acquired)
            (set! app.assets-startup-heap-before (heap.used))
            (set! app.assets-startup-heap-after app.assets-startup-heap-before)
            (set! app.assets-startup-state 1)
            (app.assets-startup-snapshot)))))

(defn app.assets-startup-finish-step (stage before result)
  (begin
    (set! app.assets-startup-last-stage stage)
    (set! app.assets-startup-heap-before before)
    (set! app.assets-startup-heap-after (heap.used))
    (if result
        (begin
          (set! app.assets-startup-state (+ app.assets-startup-state 1))
          (app.assets-startup-snapshot))
        (begin
          (app.assets-startup-reject stage)
          (app.assets-startup-snapshot)))))

(defn app.assets-startup-bind-pictures ()
  (begin
    (set! app.mounted-assets app.assets-startup-mounted)
    (set! app.vgahead (app.asset app.assets-startup-mounted 'vgahead))
    (set! app.vgagraph (app.asset app.assets-startup-mounted 'vgagraph))
    (set! app.vgadict (app.asset app.assets-startup-mounted 'vgadict))
    (set! app.audiohed (app.asset app.assets-startup-mounted 'audiohed))
    (set! app.audiot (app.asset app.assets-startup-mounted 'audiot))
    (set! app.vswap (app.asset app.assets-startup-mounted 'vswap))
    (app.setup-pictures app.assets-startup-mounted)
    true))

(defn app.assets-startup-load-pictable ()
  (let ((value (vh.load-pictable app.vgahead app.vgagraph app.vgadict)))
    (if (nil? value) false (begin (set! app.pictable value) true))))

(defn app.assets-startup-cache-initial-level ()
  (begin
    (wl.new-game 2 0)
    (app.prepare-level (app.asset app.assets-startup-mounted 'maphead)
                       (app.asset app.assets-startup-mounted 'gamemaps) 0)))

(defn app.assets-startup-step ()
  (if (or (< app.assets-startup-state 1) (> app.assets-startup-state 7))
      false
      (let ((before (heap.used)))
        (cond ((= app.assets-startup-state 1)
           (app.assets-startup-finish-step 'bind-pictures before
                                           (app.assets-startup-bind-pictures)))
          ((= app.assets-startup-state 2)
           (app.assets-startup-finish-step 'pictable before
                                           (app.assets-startup-load-pictable)))
          ((= app.assets-startup-state 3)
           (app.assets-startup-finish-step 'help-article before
                                           (app.cache-help-article)))
          ((= app.assets-startup-state 4)
           (app.assets-startup-finish-step 'initial-level-cache before
                                           (app.assets-startup-cache-initial-level)))
          ((= app.assets-startup-state 5)
           (app.assets-startup-finish-step 'fixed-renderer before
                                           (app.ensure-fixed-renderer)))
          ((= app.assets-startup-state 6)
           (app.assets-startup-finish-step 'mutable-level before
                                           (app.setup-level-mutable)))
          ((= app.assets-startup-state 7)
           (app.assets-startup-finish-step 'runtime-startup before (app.startup)))
          (true false)))))

(defn app.assets-startup-drain ()
  (cond ((= app.assets-startup-state 8) true)
        ((or (= app.assets-startup-state 0) (< app.assets-startup-state 0)) false)
        ((app.assets-startup-step) (app.assets-startup-drain))
        (true false)))

(defn app.assets-mounted (mounted)
  (if (app.assets-startup-begin mounted) (app.assets-startup-drain) false))

(defn app.required-assets? (mounted)
  (and (assoc 'maphead mounted)
       (and (assoc 'gamemaps mounted)
            (and (assoc 'vswap mounted)
                 (and (assoc 'gamepal mounted)
                      (and (assoc 'vgahead mounted)
                           (and (assoc 'vgagraph mounted)
                                (assoc 'vgadict mounted))))))))

(defn app.required-runtime-assets? (mounted)
  (and (app.required-assets? mounted)
       (and (assoc 'audiohed mounted) (assoc 'audiot mounted))))

(defn app.asset (mounted name)
  (let ((row (assoc name mounted)))
    (if row (asset.ref (app.at row 1)) nil)))

;;; Article chunks are Huffman-decoded in Lisp like every other graphics
;;; chunk. Their bytes are DOS ASCII; CR, NUL, and the text-file EOF marker are
;;; structural rather than visible characters. Fixed 64-byte blocks match the
;;; layout scanner's cadence, bound recursion, and avoid retaining one evaluator
;;; call tree per byte while the source's large help document is assembled.
(defn app.article-byte-character (value)
  (cond ((= value 10) "\n")
        ((or (= value 0) (or (= value 13) (= value 26))) "")
        ((= value 9) " ")
        ((and (>= value 32) (<= value 126))
         (string.substring ca.ASCII (- value 32) (+ (- value 32) 1)))
        (true (wl.text-reject))))

(defn app.article-bytes-to-string (source)
  (if (> (bytes.length source) wl.ARTICLE-SMALL-STRING-LIMIT)
      (wl.text-reject)
      (app.article-bytes-range source 0 (bytes.length source))))

(defn app.article-bytes-range (source start end)
  (if (= start end)
      ""
      (let ((next (if (< (+ start 64) end) (+ start 64) end)))
        (string.append (app.article-bytes-block source start next "")
                       (app.article-bytes-range source next end)))))

(defn app.article-bytes-block (source at end decoded)
  (if (= at end)
      decoded
      (app.article-bytes-block source (+ at 1) end
        (string.append decoded (app.article-byte-character (u8@ source at))))))

(defn app.article-valid? (article)
  (if (wl.byte-article? article)
      (begin (wl.scan-layout-bytes article) true)
      (app.article-valid-marked article (heap.used))))

(defn app.article-valid-marked (article mark)
  (let ((valid (> (wl.article-page-count (wl.scan-layout-text article)) 0)))
    (begin (heap.release mark) valid)))

(defn app.cache-help-article ()
  (app.cache-help-article-marked (heap.used)))

(defn app.cache-help-article-marked (mark)
  (let ((length (wl.cache-graphics-chunk-into
                  app.vgahead app.vgagraph app.vgadict wl.T-HELPART
                  wl.help-article-storage)))
    (begin
      (u16! wl.help-article-length-cell 0 length)
      (if (not (app.article-valid? wl.help-byte-article))
          (begin (heap.release mark) false)
          (begin
            (set! app.help-article-bytes wl.help-article-storage)
            (set! app.help-article wl.help-byte-article)
            (wl.configure-help-article wl.help-byte-article)
            (heap.release mark)
            true)))))

(defn app.cache-end-article (episode)
  (if (or (< episode 0) (>= episode 6))
      false
      (app.cache-end-article-marked episode (heap.used))))

(defn app.cache-end-article-marked (episode mark)
  (if (or (< episode 0) (>= episode 6))
      false
      (let ((length (wl.cache-graphics-chunk-into
                      app.vgahead app.vgagraph app.vgadict
                      (+ wl.T-ENDART1 episode) wl.end-article-storage)))
        (begin
          (u16! wl.end-article-length-cell 0 length)
          (if (not (app.article-valid? wl.end-byte-article))
              (begin (heap.release mark) false)
              (begin
                (set! app.end-article-bytes wl.end-article-storage)
                (set! app.end-article wl.end-byte-article)
                (heap.release mark)
                true))))))

(defn app.setup-pictures (mounted)
  (app.setup-pictures-with (app.asset mounted 'vswap) (app.asset mounted 'gamepal)))

(defn app.setup-pictures-with (vswap gamepal)
  (if (and (not (nil? vswap)) (and (not (nil? gamepal)) (vl.palette? gamepal)))
      (begin
        (pm.startup vswap)
        (set! app.gamepal gamepal)
        (vl.set-palette gamepal)
        (wl.set-textured 1))
      (wl.set-textured 0)))

(defn app.setup-level (tinf maps mapnum)
  (if (not (= app.fixed-renderer-ready 1))
      false
      (if (not (app.prepare-level tinf maps mapnum))
          false
          (if (not (app.apply-current-view-size))
              false
              (app.setup-level-mutable)))))

(defn app.prepare-level (tinf maps mapnum)
  (begin
    (set! app.tinf tinf)
    (set! app.maps maps)
    ;; The DOS cache manager reuses the two fixed mapsegs across levels. Keep
    ;; that lifetime here too: allocating fresh plane buffers at every demo,
    ;; secret-exit, load, or victory transition eventually exhausts the seed.
    (app.cache-level-planes tinf maps mapnum)
    (set! app.map-name (ca.map-name maps (ca.header-offset tinf mapnum)))
    true))

(defn app.cache-level-planes (tinf maps mapnum)
  (let ((pos (ca.header-offset tinf mapnum)) (tag (ca.rlew-tag tinf)))
    (begin
      (ca.cache-plane-into maps (ca.plane-start maps pos 0) tag
                           app.map-expand-buffer app.wall-plane-storage)
      (ca.cache-plane-into maps (ca.plane-start maps pos 1) tag
                           app.map-expand-buffer app.object-plane-storage)
      (set! app.wall-plane app.wall-plane-storage)
      (set! app.object-plane app.object-plane-storage)
      (set! app.planes (list app.wall-plane app.object-plane)))))

(defn app.ensure-fixed-renderer ()
  (if (= app.fixed-renderer-ready 1)
      true
      (let ((mark (heap.used)))
        ;; Source InitGame owns both calls. SetupGameLevel never rebuilds
        ;; either table; later projection changes belong to NewViewSize. Keep
        ;; the fixed-table latch separate so a rejected projection retry cannot
        ;; execute BuildTables twice.
        (if (and (or (= app.fixed-tables-ready 1)
                     (if (wl.build-tables)
                         (begin (set! app.fixed-tables-ready 1) true)
                         false))
                 (wl.new-view-size-units wl.view-size))
            (begin
              (set! app.projection-view-size wl.view-size)
              (set! app.fixed-renderer-ready 1)
              (heap.release mark)
              true)
            (begin (heap.release mark) false)))))

(defn app.apply-current-view-size ()
  (if (not (= app.fixed-renderer-ready 1))
      false
      (if (= app.projection-view-size wl.view-size)
          true
          (let ((mark (heap.used)))
            (if (wl.new-view-size-units wl.view-size)
                (begin
                  (set! app.projection-view-size wl.view-size)
                  (heap.release mark)
                  true)
                (begin (heap.release mark) false))))))

(defn app.setup-level-mutable ()
  (app.setup-tables (heap.used)))

(defn app.setup-tables (mark)
  (begin
    (app.setup-game-level-bounded)
    ;; This is the fresh SetupGameLevel -> InitPlayer lifecycle boundary. It
    ;; clears only port-owned death-camera execution state; source victory and
    ;; the boss-kill snapshot deliberately survive ordinary deathcam passes.
    (app.reset-deathcam-application-lifecycle)
    (app.init-player-loop-bounded)
    (app.draw-statusbar-bounded)
    ;; DrawPlayScreen draws the static bar first, then the eight source HUD layers.
    (set! app.drawn-face-picture -1)
    (app.refresh-face)
    (set! app.drawn-health nil)
    (app.refresh-health)
    (set! app.drawn-lives nil)
    (app.refresh-lives)
    (set! app.drawn-level nil)
    (app.refresh-level)
    (set! app.drawn-ammo nil)
    (app.refresh-ammo)
    (set! app.drawn-keys nil)
    (app.refresh-keys)
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

(defn app.build-tables-bounded ()
  (app.build-tables-marked (heap.used)))

(defn app.build-tables-marked (mark)
  (begin (wl.build-tables) (heap.release mark)))

(defn app.calc-projection-bounded ()
  (app.calc-projection-marked (heap.used)))

(defn app.calc-projection-marked (mark)
  (begin (wl.calc-projection) (heap.release mark)))

(defn app.setup-game-level-bounded ()
  (app.setup-game-level-marked (heap.used)))

(defn app.setup-game-level-marked (mark)
  (begin
    (wl.setup-game-level app.wall-plane app.object-plane)
    (heap.release mark)))

(defn app.init-player-loop-bounded ()
  (app.init-player-loop-marked (heap.used)))

(defn app.init-player-loop-marked (mark)
  (begin (wl.init-player-loop) (heap.release mark)))

(defn app.draw-statusbar-bounded ()
  (app.draw-statusbar-marked (heap.used)))

(defn app.draw-statusbar-marked (mark)
  (begin
    (vh.draw-statusbar app.vgahead app.vgagraph app.vgadict app.frame-buffer)
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
  (if (wl.textured?) (vl.palette-colours vl.current-palette) (app.flat-palette)))

(defn app.palette-bytes () vl.current-palette)

;;; Palette and fizzle waits are outer-loop steps. The host supplies elapsed
;;; 70 Hz ticks, while Lisp advances the source-owned transition and audio
;;; timer state exactly once per callback.
(defn app.presentation-clock (elapsed)
  (if (< elapsed 0)
      false
      (begin
        (set! app.time-count (+ app.time-count elapsed))
        (if (= app.runtime-started 1)
            (begin (sd.set-tick app.time-count) (sd.poll)) nil)
        true)))

(defn app.begin-fade-out (start end red green blue steps)
  (if (<= steps 0) false (vl.fade-out-begin start end red green blue steps)))

(defn app.begin-fade-in (start end palette steps)
  (if (<= steps 0) false (vl.fade-in-begin start end palette steps)))

(defn app.fade-advance (elapsed)
  (if (app.presentation-clock elapsed) (vl.fade-step) false))

(defn app.request-fizzle-in ()
  (begin
    (wl.request-fizzle-in)
    (set! app.fizzle-pending 1)
    (set! app.fizzle-prepared 0)
    true))

(defn app.reset-post-fizzle-timer ()
  (begin
    ;; ThreeDRefresh resets both TimeCount and lasttimecount after FizzleFade.
    ;; This app exposes only the shared source clock, so reset it at the exact
    ;; completed/aborted outer-frame boundary and resynchronise audio.
    (set! app.time-count 0)
    (if (= app.runtime-started 1) (sd.set-tick 0) nil)
    (set! app.fizzle-pending 0)
    (set! app.fizzle-prepared 0)
    true))

(defn app.fizzle-advance (acknowledged elapsed)
  (if (= app.fizzle-pending 0)
      'idle
      (if (not (app.presentation-clock elapsed))
          false
          (begin
            (if (= app.fizzle-prepared 0)
                (begin
                  (wl.begin-render-fizzle app.frame-buffer)
                  (set! app.fizzle-prepared 1))
                (wl.fizzle-refresh-step app.frame-buffer acknowledged))
            (let ((status (vh.fizzle-status wl.fizzle-state)))
              (if (or (eq? status 'complete) (eq? status 'aborted))
                  (begin (app.reset-post-fizzle-timer) status)
                  status))))))

(defn app.controls ()
  '((forward press step-forward (ArrowUp w))
    (backward press step-back (ArrowDown s))
    (turn-left press turn-left (ArrowLeft a))
    (turn-right press turn-right (ArrowRight d))
    (attack press attack (ControlLeft ControlRight))
    (strafe press strafe (AltLeft AltRight))
    (run press run (ShiftLeft ShiftRight))
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

(defn app.attach ()
  (if (app.startup) (app.state) nil))

(defn app.advance (input)
  (app.advance-reclaimable
    input (heap.used)
    app.lifecycle-events wl.music-events
    app.finished-demo wl.finished-demo
    wl.playstate wl.demo-recording))

(defn app.advance-result-release-safe? (result)
  (or (nil? result) (or (eq? result true) (eq? result false))))

;;; Bitmask for the conservative ownership boundary below. The mask is scalar
;;; and survives a successful rewind, so a host can diagnose why a live sample
;;; retained its interpreter frames without asking for any heap-owned snapshot.
;;; 1=result, 8=lifecycle, 16=music decisions, 32/64=finished demos,
;;; 128=playstate, 256=recording. Audio decisions and register traffic use
;;; preallocated packed stores; their scalar counts are not heap escapes.
(defn app.advance-retain-mask
  (result lifecycle music-events app-demo wl-demo playstate demo-recording)
  (bit.or (if (app.advance-result-release-safe? result) 0 1)
    (bit.or (if (eq? app.lifecycle-events lifecycle) 0 8)
      (bit.or (if (eq? wl.music-events music-events) 0 16)
        (bit.or (if (eq? app.finished-demo app-demo) 0 32)
          (bit.or (if (eq? wl.finished-demo wl-demo) 0 64)
            (bit.or (if (= wl.playstate playstate) 0 128)
                    (if (= wl.demo-recording demo-recording) 0 256))))))))

(defn app.advance-reclaimable
  (input mark lifecycle music-events app-demo wl-demo playstate demo-recording)
  (let ((result (app.advance-persistent input)))
    ;; Interpreter frames and the decoded control list are transient on an
    ;; ordinary PlayLoop sample. Rewind them only when every heap-owned event
    ;; channel is unchanged and no aggregate value crosses the return boundary.
    ;; Scalar/player/actor/world mutations live in globals and preallocated
    ;; byte stores, so they survive the rewind exactly.
    (let ((mask (app.advance-retain-mask
                  result lifecycle music-events app-demo wl-demo
                  playstate demo-recording)))
      (if (= mask 0)
          (begin
            (set! app.advance-release-count (+ app.advance-release-count 1))
            (set! app.advance-last-retain-mask 0)
            (heap.release mark)
            result)
          (begin
            (set! app.advance-retain-count (+ app.advance-retain-count 1))
            (set! app.advance-last-retain-mask mask)
            result)))))

(defn app.advance-persistent (input)
  (if (and (app.mounted?) (= app.runtime-started 1))
      (if (app.deathcam-presentation-active?)
          (app.deathcam-outer-advance
            (app.input? input 'elapsed)
            (> (app.input? input 'acknowledged) 0))
          (let ((controls (wl.poll-controls input)))
            (if (nil? controls) nil
                (if (not (app.record-live-demo-controls))
                    nil
                    (app.live-advance (app.at controls 0)
                                      (app.at controls 1)
                                      (app.at controls 2)
                                      (app.at controls 3))))))
      nil))

(defn app.player-tick (use attack controlx controly)
  (begin
    (if (= wl.attack-active 1)
        (wl.t-attack controlx controly)
        (wl.t-player controlx controly))
    (set! app.use-held (u8@ wl.buttonstate wl.BT-USE))
    (set! app.attack-held (u8@ wl.buttonstate wl.BT-ATTACK))))

(defn app.refresh-renderer-state ()
  (app.refresh-renderer-state-marked (heap.used)))

(defn app.refresh-renderer-state-marked (mark)
  (begin
    (wl.refresh-actor-visibility)
    (app.refresh-face)
    (app.refresh-health)
    (app.refresh-lives)
    (app.refresh-level)
    (app.refresh-ammo)
    (app.refresh-keys)
    (app.refresh-weapon)
    ;; Only renderer call frames and closure environments rewind to the mark;
    ;; the score scalar tail is returned across the release boundary exactly as
    ;; the unbounded original did.
    (let ((result (app.refresh-score)))
      (begin (heap.release mark) result))))

;;; CheckKeys applies the MLI cheat after a completed gameplay record and before
;;; the next one. Keep this bounded seam source-ordered and explicit: the replay
;;; harness owns when it is invoked, while this application owns the mutation,
;;; status refresh, and digitized-channel stop. The modal message/acknowledgement
;;; and raw keyboard chord are intentionally outside this trace-facing boundary.
(defn app.apply-source-mli-cheat ()
  (begin
    (set! wl.health 100)
    (set! wl.ammo 99)
    (set! wl.keys 3)
    (set! wl.score 0)
    (set! app.time-count (+ app.time-count 42000))
    (wl.give-weapon wl.WP-CHAINGUN)
    (set! app.drawn-weapon-picture -1)
    (app.refresh-weapon)
    (set! app.drawn-health nil)
    (app.refresh-health)
    (set! app.drawn-keys nil)
    (app.refresh-keys)
    (set! app.drawn-ammo nil)
    (app.refresh-ammo)
    (set! app.drawn-score nil)
    (app.refresh-score)
    (sd.stop-digitized)
    true))

(defn app.refresh-face ()
  (app.refresh-face-picture (wl.status-face-picture)))

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

(defn app.refresh-lives ()
  (app.refresh-lives-number wl.lives))

(defn app.refresh-lives-number (number)
  (if (and (not (nil? app.drawn-lives)) (= number app.drawn-lives))
      number
      (app.draw-lives-number number (heap.used))))

(defn app.draw-lives-number (number mark)
  (begin
    (app.draw-number-chunks app.frame-buffer (wl.latch-number-chunks 1 number) 14 16)
    (heap.release mark)
    (set! app.drawn-lives number)))

(defn app.refresh-level ()
  (app.refresh-level-number (+ wl.map 1)))

(defn app.refresh-level-number (number)
  (if (and (not (nil? app.drawn-level)) (= number app.drawn-level))
      number
      (app.draw-level-number number (heap.used))))

(defn app.draw-level-number (number mark)
  (begin
    (app.draw-number-chunks app.frame-buffer (wl.latch-number-chunks 2 number) 2 16)
    (heap.release mark)
    (set! app.drawn-level number)))

(defn app.refresh-ammo ()
  (app.refresh-ammo-number wl.ammo))

(defn app.refresh-ammo-number (number)
  (if (and (not (nil? app.drawn-ammo)) (= number app.drawn-ammo))
      number
      (app.draw-ammo-number number (heap.used))))

(defn app.draw-ammo-number (number mark)
  (begin
    ;; Preserve LatchNumber's direct left-to-right writes and advance the
    ;; numeric cache only after both source cells have completed.
    (app.draw-number-chunks app.frame-buffer (wl.latch-number-chunks 2 number) 27 16)
    (heap.release mark)
    (set! app.drawn-ammo number)))

(defn app.refresh-keys ()
  (app.refresh-key-bits wl.keys))

(defn app.refresh-key-bits (keys)
  (if (and (not (nil? app.drawn-keys)) (= keys app.drawn-keys))
      keys
      (app.draw-key-pictures keys (heap.used))))

(defn app.draw-key-pictures (keys mark)
  (begin
    ;; DrawKeys always writes gold then silver. A rejected silver picture must
    ;; preserve the completed gold prefix without advancing the raw-bit cache.
    (vh.status-draw-picture app.vgahead app.vgagraph app.vgadict
                            app.pictable app.frame-buffer 30 4
                            (wl.gold-key-picture keys))
    (vh.status-draw-picture app.vgahead app.vgagraph app.vgadict
                            app.pictable app.frame-buffer 30 20
                            (wl.silver-key-picture keys))
    (heap.release mark)
    (set! app.drawn-keys keys)))

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

;; Only dirty gameplay planes are rehashed. wl.plane-hash-words returns a
;; temporary two-word list per rehash; rewind at this boundary only, after the
;; scalar hash globals and dirty flags have absorbed the result.
(defn app.refresh-plane-hashes ()
  (app.refresh-plane-hashes-marked (heap.used)))

(defn app.refresh-plane-hashes-marked (mark)
  (let ((result (begin (app.refresh-plane0-hash) (app.refresh-plane1-hash))))
    (begin (heap.release mark) result)))

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
  (if (app.deathcam-presentation-active?)
      (app.deathcam-presentation-state)
      (if (app.replay-tick tics controlx controly buttons)
      (let ((record (app.trace-record)))
        (begin (app.consume-deathcam-victory) record)) nil)))

(defn app.live-advance (tics controlx controly buttons)
  (if (app.deathcam-presentation-active?)
      (app.deathcam-presentation-state)
      (if (app.live-tick tics controlx controly buttons)
          ;; PlayLoop does not construct a diagnostic snapshot after every
          ;; ordinary input sample. The state-handle host also intentionally
          ;; consumes no return value from this path. Keep full trace export in
          ;; app.replay-advance/app.trace-record, and retain only the live
          ;; gameplay mutation plus the source-ordered deathcam transition.
          (begin (app.consume-deathcam-victory) true)
          nil)))

(defn app.replay-tick (tics controlx controly buttons)
  (if (app.deathcam-presentation-active?)
      (app.deathcam-presentation-state)
      (if (and (app.mounted?) (= app.runtime-started 1))
      (begin
        (app.decode-replay-buttons buttons)
        (app.replay-tick-persistent tics controlx controly buttons))
      nil)))

(defn app.live-tick (tics controlx controly buttons)
  (if (app.deathcam-presentation-active?)
      (app.deathcam-presentation-state)
      (if (and (app.mounted?) (= app.runtime-started 1))
      (app.replay-tick-persistent tics controlx controly buttons)
      nil)))

(defn app.decode-replay-buttons (buttons)
  (begin
    (wl.copy-button-state 0)
    (app.decode-replay-button-at buttons 0)))

(defn app.decode-replay-button-at (buttons button)
  (if (= button wl.NUMBUTTONS)
      true
      (begin
        (wl.set-button button (bit.and buttons (bit.shl 1 button)))
        (app.decode-replay-button-at buttons (+ button 1)))))

(defn app.replay-tick-persistent (tics controlx controly buttons)
  (begin
    (set! wl.tics tics)
    (set! app.time-count (+ app.time-count tics))
    (set! app.trace-tics tics)
    (set! app.trace-controlx controlx)
    (set! app.trace-controly controly)
    (set! app.trace-buttons buttons)
    ;; Drive the source-owned ISR cadence. Direct tick assignment skips the
    ;; 140/700 Hz services and cannot produce source audio output.
    (if (= app.runtime-started 1) (sd.advance-source-tics tics) nil)
    (let ((deathcam-at-entry (wl.deathcam-active?)))
          (begin
            (set! wl.madenoise 0)
            (wl.move-doors)
            (wl.move-pwalls)
            (wl.update-palette-shifts)
            ;; The actor traversal that initiates deathcam occurs later in this
            ;; tick, so its initiation tick legitimately runs T_Player once.
            (if (not deathcam-at-entry)
                (app.player-tick (if (> (bit.and buttons 8) 0) 1 0)
                                 (if (> (bit.and buttons 1) 0) 1 0)
                                 controlx controly) nil)
            (wl.move-actors)
            (wl.update-static-bonuses)
            (app.refresh-renderer-state)
            (app.refresh-plane-hashes)
            (if (= app.runtime-started 1) (sd.poll) nil)
            (app.finish-demo-record-if-complete)
            ;; Enter the blocking-equivalent presentation only after the
            ;; initiating actor tick's complete world/render/audio/demo tail.
            (if (and (not deathcam-at-entry) (wl.deathcam-active?))
                (app.begin-deathcam-presentation) nil)
            true))))

;;; Compatibility seam for diagnostics that still name the former marked
;;; wrapper. Persistent gameplay effects must never rewind to a caller mark.
(defn app.replay-tick-marked (tics controlx controly buttons mark)
  (app.replay-tick-persistent tics controlx controly buttons))

(defn app.reset-deathcam-application-lifecycle ()
  (begin
    (wl.reset-deathcam-lifecycle)
    (set! app.deathcam-presentation-phase 0)
    (set! app.deathcam-presentation-remaining 0)
    (set! app.deathcam-presentation-carry 0)
    (set! app.deathcam-victory-consumed 0)
    true))

(defn app.deathcam-presentation-active? ()
  (or (= app.deathcam-presentation-phase 1)
      (= app.deathcam-presentation-phase 2)))

(defn app.deathcam-presentation-state ()
  (list 'deathcam-presentation app.deathcam-presentation-phase
        app.deathcam-presentation-remaining))

;;; First-class outer callback. It accepts only host elapsed time and an
;;; acknowledgement sample: no gameplay/demo command, button array, or trace
;;; record crosses this boundary while source PlayLoop is blocked.
(defn app.deathcam-outer-advance-persistent (elapsed acknowledged)
  (if (not (app.deathcam-presentation-active?))
      false
      (if (< elapsed 0)
          false
          (begin
            (if (= app.runtime-started 1)
                (begin (sd.advance-source-tics elapsed) (sd.poll)) nil)
            (app.deathcam-presentation-advance acknowledged elapsed)
            true))))

(defn app.deathcam-outer-advance (elapsed acknowledged)
  (if (app.deathcam-outer-advance-persistent elapsed acknowledged)
      (app.deathcam-presentation-state) false))

(defn app.begin-deathcam-presentation ()
  (if (not (= app.deathcam-presentation-phase 0))
      false
      (begin
        (wl.finish-palette-shifts)
        (set! app.deathcam-presentation-phase 1)
        (set! app.deathcam-presentation-remaining 100)
        (set! app.deathcam-presentation-carry 0)
        (app.record-lifecycle 'deathcam-wait-vbl)
        true)))

(defn app.draw-deathcam-presentation ()
  (begin
    ;; The one-page renderer can express the source clear and message/update
    ;; order, but not FizzleFade's two-page copy. Keep that unsupported stage
    ;; explicit in lifecycle provenance instead of claiming a fake dissolve.
    (wl.bar app.frame-buffer 0 0 320 160 127)
    (app.record-lifecycle 'deathcam-bar)
    (app.record-lifecycle 'deathcam-fizzle-unavailable)
    (wl.write app.frame-buffer 0 7 "Let's see that again!")
    (app.record-lifecycle 'deathcam-message-update)
    app.frame-buffer))

(defn app.deathcam-presentation-advance (acknowledged elapsed)
  (if (< elapsed 0)
      false
      (cond
        ((= app.deathcam-presentation-phase 1)
         (if (< elapsed app.deathcam-presentation-remaining)
             (begin
               (set! app.deathcam-presentation-remaining
                     (- app.deathcam-presentation-remaining elapsed))
               true)
             (let ((residual (- elapsed app.deathcam-presentation-remaining)))
               (begin
                 (app.draw-deathcam-presentation)
                 (set! app.deathcam-presentation-phase 2)
                 (set! app.deathcam-presentation-carry residual)
                 (set! app.deathcam-presentation-remaining (- 300 residual))
                 (app.record-lifecycle 'deathcam-ack)
                 (if (or acknowledged (<= app.deathcam-presentation-remaining 0))
                     (app.finish-deathcam-presentation) nil)
                 true))))
        ((= app.deathcam-presentation-phase 2)
         (begin
           (set! app.deathcam-presentation-remaining
                 (- app.deathcam-presentation-remaining elapsed))
           (if (or acknowledged (<= app.deathcam-presentation-remaining 0))
               (app.finish-deathcam-presentation) nil)
           true))
        (true false))))

(defn app.finish-deathcam-presentation ()
  (begin
    (set! app.deathcam-presentation-phase 0)
    (set! app.deathcam-presentation-remaining 0)
    (set! app.deathcam-presentation-carry 0)
    (app.record-lifecycle 'deathcam-resume)
    true))

(defn app.consume-deathcam-victory ()
  (if (or (= app.deathcam-victory-consumed 1)
          (not (= wl.playstate wl.EX-VICTORIOUS)))
      false
      (begin
        (set! app.deathcam-victory-consumed 1)
        (app.finish-playstate wl.EX-VICTORIOUS)
        (app.begin-victory)
        true)))

(defn app.start-demo-record (level)
  (begin
    (app.reset-deathcam-application-lifecycle)
    (set! app.finished-demo nil)
    (wl.start-demo-record level)))

(defn app.record-live-demo-controls ()
  (if (= wl.demo-recording 0) true (wl.record-current-demo)))

(defn app.finish-demo-record-if-complete ()
  (if (and (= wl.demo-recording 1)
           (not (= wl.playstate wl.EX-STILLPLAYING)))
      (app.finish-demo-record)
      true))

(defn app.finish-demo-record ()
  (let ((finished (wl.finish-demo-record)))
    (if (nil? finished)
        false
        (begin (set! app.finished-demo finished) true))))

(defn app.take-finished-demo ()
  (let ((finished app.finished-demo))
    (begin (set! app.finished-demo nil) finished)))

;;; PlayDemo hands the decoded record to SetupGameLevel before PlayLoop. The
;;; immutable source bytes remain Lisp-owned; no host-side demo parsing occurs.
(defn app.play-demo (source)
  (if (wl.play-demo source)
      (begin (app.setup-level app.tinf app.maps wl.map) true)
      false))

(defn app.demo-advance ()
  (if (app.deathcam-presentation-active?)
      (app.deathcam-presentation-state)
      (let ((command (wl.poll-demo-controls)))
    (if (nil? command)
        nil
        (app.replay-advance (app.at command 0)
                            (app.at command 1)
                            (app.at command 2)
                            (app.at command 3))))))

;;; Source-shaped route callbacks for a Node/browser host. They keep policy in
;;; the owning modules and provide one stable application boundary to native
;;; launchers without reimplementing game, menu, intermission, or save logic.
(defn app.new-game (difficulty episode)
  (if (wl.cp-new-game difficulty episode)
      (begin (app.setup-current-level) true)
      false))

(defn app.finish-playstate (playstate)
  (let ((map (wl.finish-playstate playstate)))
    (begin
      (if (= wl.application-phase wl.APP-PLAYING)
          (app.setup-current-level) nil)
      map)))

(defn app.current-global-map ()
  (if (= wl.demo-playback 1) wl.map (+ (* wl.episode 10) wl.map)))

(defn app.setup-current-level ()
  (if (app.mounted?)
      (app.setup-level app.tinf app.maps (app.current-global-map))
      false))

;;; TEDLEVEL is a global data-map address, while gamestate.map remains the
;;; episode-local semantic map used by traces, exits, saves, and intermission.
;;; Validate the complete request before NewGame mutates any source state.
(defn app.ted-integer-in-range? (value maximum)
  (if (not (number? value))
      false
      (if (not (= (mod value 1) 0))
          false
          (if (< value 0) false (not (> value maximum))))))

(defn app.start-ted-level (level difficulty)
  (if (not (app.ted-integer-in-range? level 59))
      false
      (if (not (app.ted-integer-in-range? difficulty 3))
          false
          (if (not (app.mounted?))
              false
              (let ((episode (/ level 10)) (local-map (mod level 10)))
                (if (wl.cp-new-game difficulty episode)
                    (begin
                      (wl.select-map local-map)
                      (app.setup-level app.tinf app.maps level)
                      true)
                    false))))))

(defn app.level-completed ()
  (begin (wl.level-completed) (app.finish-playstate wl.EX-COMPLETED)))

;;; Presentation/application callbacks stay non-blocking. The host supplies
;;; sampled menu or acknowledgement input and only schedules the next call;
;;; selection, count-up state, framebuffer pixels, and audio remain Lisp-owned.
(defn app.open-control-panel (scancode)
  (if (= app.runtime-started 1)
      (begin
        (wl.us-control-panel scancode)
        (app.draw-control-panel)
        (app.record-lifecycle 'menu)
        wl.menu-screen)
      nil))

(defn app.control-panel-step (input)
  (if (= app.runtime-started 1)
      (let ((old-view wl.view-size) (screen (wl.control-panel-step input)))
        (begin
          (if (not (= old-view wl.view-size))
              (app.apply-current-view-size) nil)
          (app.sync-audio-options)
          (app.draw-control-panel)
          screen))
      nil))

(defn app.draw-control-panel ()
  (begin
    (wl.cache-presentation-font)
    (app.draw-control-panel-marked (heap.used))))

(defn app.draw-control-panel-marked (mark)
  (begin
    (wl.draw-control-panel app.frame-buffer wl.presentation-font)
    (heap.release mark)
    app.frame-buffer))

;;; R0's product presentation is an app-owned outer state machine.  It keeps
;;; the five retained screens independent of the shared framebuffer, and does
;;; not synthesize any of the later 140 PlayLoop rows owned by the native
;;; producer.  SIGNON.BIN is already row-major but remains the pristine input:
;;; IntroScreen and FinishSignon source operations produce the retained signon
;;; frame. TITLEPIC alone follows the VGA graphics chunk/deplane path.
(defn app.r0-record-lifecycle (checkpoint)
  (begin
    (set! app.r0-lifecycle (cons checkpoint app.r0-lifecycle))
    checkpoint))

(defn app.r0-save-frame (name)
  (let ((snapshot (bytes.alloc 64000)))
    (begin
      (bytes.copy snapshot 0 app.frame-buffer 0 64000)
      (set! app.r0-frames (cons (list name snapshot) app.r0-frames))
      snapshot)))

(defn app.r0-find-frame (frames name)
  (if (nil? frames)
      nil
      (if (eq? (car (car frames)) name)
          (car (cdr (car frames)))
          (app.r0-find-frame (cdr frames) name))))

(defn app.r0-frame-snapshot (name)
  (let ((stored (app.r0-find-frame app.r0-frames name)))
    (if (nil? stored)
        nil
        (let ((copy (bytes.alloc 64000)))
          (begin (bytes.copy copy 0 stored 0 64000) copy)))))

(defn app.r0-lifecycle-snapshot () (reverse app.r0-lifecycle))

(defn app.r0-append (left right)
  (if (nil? left) right (cons (car left) (app.r0-append (cdr left) right))))

(defn app.r0-audio-snapshot ()
  (app.r0-append app.r0-menu-audio app.r0-level-audio))

;;; The retained original route normalized the DOS machine-dependent values to
;;; a fully populated 320 KiB conventional / 1000 KiB EMS / 1000 KiB XMS
;;; display. Device presence is likewise fixed by the captured route. Reject a
;;; changed or extended profile before touching route-owned state or pixels.
(defn app.r0-route-profile-valid? (profile)
  (equal? profile
    '((main-kib 320) (ems-kib 1000) (xms-kib 1000)
      (mouse true) (joystick true) (sound-source true)
      (adlib false) (sound-blaster false))))

(defn app.r0-profile-value (profile name)
  (app.at (assoc name profile) 1))

(defn app.r0-draw-memory-bars (thresholds available x index)
  (if (nil? thresholds)
      app.frame-buffer
      (begin
        (if (>= available (car thresholds))
            (wl.bar app.frame-buffer x (- 163 (* 8 index)) 6 5 (- 108 index))
            nil)
        (app.r0-draw-memory-bars (cdr thresholds) available x (+ index 1)))))

(defn app.r0-draw-intro-screen (profile)
  (if (not (app.r0-route-profile-valid? profile))
      false
      (begin
        (app.r0-draw-memory-bars '(32 64 96 128 160 192 224 256 288 320)
                                 (app.r0-profile-value profile 'main-kib) 49 0)
        (app.r0-draw-memory-bars '(100 200 300 400 500 600 700 800 900 1000)
                                 (app.r0-profile-value profile 'ems-kib) 89 0)
        (app.r0-draw-memory-bars '(100 200 300 400 500 600 700 800 900 1000)
                                 (app.r0-profile-value profile 'xms-kib) 129 0)
        (if (app.r0-profile-value profile 'mouse)
            (wl.bar app.frame-buffer 164 82 12 2 14) nil)
        (if (app.r0-profile-value profile 'joystick)
            (wl.bar app.frame-buffer 164 105 12 2 14) nil)
        (if (and (app.r0-profile-value profile 'adlib)
                 (not (app.r0-profile-value profile 'sound-blaster)))
            (wl.bar app.frame-buffer 164 128 12 2 14) nil)
        (if (app.r0-profile-value profile 'sound-blaster)
            (wl.bar app.frame-buffer 164 151 12 2 14) nil)
        (if (app.r0-profile-value profile 'sound-source)
            (wl.bar app.frame-buffer 164 174 12 2 14) nil)
        true)))

(defn app.r0-cache-signon-font ()
  (if (nil? app.r0-signon-font)
      (set! app.r0-signon-font
        (wl.cache-font app.vgahead app.vgagraph app.vgadict 0))
      app.r0-signon-font))

(defn app.r0-finish-signon ()
  (begin
    ;; FinishSignon's peekb(0xa000,0) samples the source frame, not a pinned
    ;; palette index. The captured pristine input currently supplies index 41.
    (wl.bar app.frame-buffer 0 189 300 11 (u8@ app.frame-buffer 0))
    (let ((font (app.r0-cache-signon-font)))
      (let ((width (car (wl.measure-prop-string font "Press a key"))))
        (begin
          (wl.draw-prop-string app.frame-buffer font "Press a key"
                               (/ (- 320 width) 2) 190 14)
          true)))))

(defn app.r0-render-signon (signon profile)
  (if (or (nil? signon)
          (or (not (= (bytes.length signon) 64000))
              (not (app.r0-route-profile-valid? profile))))
      false
      (begin
        (bytes.copy app.frame-buffer 0 signon 0 64000)
        (app.r0-draw-intro-screen profile)
        (app.r0-finish-signon))))

(defn app.r0-presentation-step (signon)
  (if (not (= app.r0-phase 0))
      false
      (if (or (nil? signon)
              (or (not (= (bytes.length signon) 64000))
                  (not (app.r0-route-profile-valid? app.r0-route-profile))))
          false
          (begin
            (set! app.r0-lifecycle nil)
            (set! app.r0-frames nil)
            (set! app.r0-menu-audio nil)
            (set! app.r0-level-audio nil)
            (set! app.r0-level-music-started 0)
            (set! app.r0-shutdown-complete 0)
            ;; Open the route boundary only after the supplied SIGNON image
            ;; and normalized profile pass validation, so no pre-route manager
            ;; event can leak in.
            (sd.begin-audio-trace 0)
            (app.r0-record-lifecycle 1)
            (app.r0-render-signon signon app.r0-route-profile)
            (app.r0-save-frame 'signon)
            (app.r0-record-lifecycle 3)
            (set! app.r0-phase 1)
            app.r0-phase))))

(defn app.r0-draw-title ()
  (begin
    (wl.draw-picture app.frame-buffer app.vgahead app.vgagraph app.vgadict
                     app.pictable 0 0 app.R0-TITLEPIC)
    (app.r0-save-frame 'title)
    true))

(defn app.r0-draw-menu-entry-overlay (name)
  (cond
    ((eq? name 'main-menu)
     (wl.r0-handle-menu-entry app.frame-buffer wl.presentation-font
                              wl.r0-main-menu 76 55 24 wl.menu-cursor true false))
    ((eq? name 'episode-menu)
     (wl.r0-handle-menu-entry app.frame-buffer wl.presentation-font
                              wl.episode-menu 10 23 88 wl.menu-cursor true false))
    ((eq? name 'difficulty-menu)
     (wl.r0-handle-menu-entry app.frame-buffer wl.presentation-font
                              wl.difficulty-menu 50 100 24 wl.difficulty-cursor false true))
    (true false)))

(defn app.r0-draw-menu-checkpoint (name)
  (cond
    ((eq? name 'main-menu)
     (wl.r0-handle-menu-checkpoint app.frame-buffer 76 55 wl.menu-cursor false))
    ((eq? name 'episode-menu)
     (wl.r0-handle-menu-checkpoint app.frame-buffer 10 23 wl.menu-cursor false))
    ((eq? name 'difficulty-menu)
     (wl.r0-handle-menu-checkpoint app.frame-buffer 50 100 wl.difficulty-cursor true))
    (true false)))

(defn app.r0-draw-menu-frame (name)
  (begin
    (app.draw-control-panel)
    ;; The retained boundary is the first HandleMenu update, after its gun,
    ;; selected-row redraw, optional DrawNewGameDiff callback, and first
    ;; eight-tic cursor animation.
    (app.r0-draw-menu-entry-overlay name)
    (app.r0-draw-menu-checkpoint name)
    (app.r0-save-frame name)
    true))

(defn app.r0-menu-confirm-sound ()
  (begin
    (wl.play-sound 32 'R0Menu)
    true))

;;; The authoritative route has five Enter edges: signon, title, New Game,
;;; Episode 1, and difficulty row 2 (gd_medium). Only the final three are HandleMenu
;;; confirmations and therefore attempt SHOOTSND (32).
(defn app.r0-menu-enter (key)
  (if (not (string=? key "Enter"))
      false
      (cond
        ((= app.r0-phase 1)
         (begin
           (app.r0-record-lifecycle 2)
           (app.r0-draw-title)
           (app.r0-record-lifecycle 4)
           (set! app.r0-phase 2)
           app.r0-phase))
        ((= app.r0-phase 2)
         (begin
           ;; Do not call setup-control-panel-machine: its MENUSONG is outside
           ;; the retained R0 accepted-event boundary.
           (wl.setup-control-panel)
           (set! wl.menu-screen wl.MENU-MAIN)
           (set! wl.menu-cursor 0)
           (app.r0-draw-menu-frame 'main-menu)
           (app.r0-record-lifecycle 5)
           (set! app.r0-phase 3)
           app.r0-phase))
        ((= app.r0-phase 3)
         (begin
           (app.r0-menu-confirm-sound)
           (wl.control-panel-step '((confirm 1)))
           (if (not (= wl.menu-screen wl.MENU-EPISODE))
               false
               (begin
                 (app.r0-draw-menu-frame 'episode-menu)
                 (app.r0-record-lifecycle 6)
                 (set! app.r0-phase 4)
                 app.r0-phase))))
        ((= app.r0-phase 4)
         (begin
           (app.r0-menu-confirm-sound)
           (wl.control-panel-step '((confirm 1)))
           (if (not (= wl.menu-screen wl.MENU-DIFFICULTY))
               false
               (begin
                 (app.r0-draw-menu-frame 'difficulty-menu)
                 (app.r0-record-lifecycle 7)
                 (set! app.r0-phase 5)
                 app.r0-phase))))
        ((= app.r0-phase 5)
         (begin
           (app.r0-menu-confirm-sound)
           (wl.control-panel-step '((confirm 1)))
           (if (not (= wl.menu-screen wl.MENU-CLOSED))
               false
               (begin
                 (app.r0-record-lifecycle 8)
                 (set! app.r0-phase 6)
                 app.r0-phase))))
        (true false))))

(defn app.r0-start-level-music ()
  (if (or (not (= app.r0-phase 6)) (= app.r0-level-music-started 1))
      false
      (begin
        ;; Preserve the accepted menu decisions before the manager opens the
        ;; gameplay-local audio boundary and clears its generic event list.
        (set! app.r0-menu-audio (sd.audio-event-log))
        (set! wl.episode 0)
        (set! wl.map 0)
        (if (not (app.setup-current-level))
            false
            (begin
              (sd.begin-audio-trace 0)
              (if (not (= (wl.start-level-music) 3))
                  false
                  (begin
                    (set! app.r0-level-audio (sd.audio-event-log))
                    (set! app.r0-level-music-started 1)
                    (app.r0-record-lifecycle 9)
                    (set! app.r0-phase 7)
                    true)))))))

(defn app.r0-graceful-shutdown ()
  (if (or (not (= app.r0-phase 7)) (= app.r0-shutdown-complete 1))
      false
      (if (not (app.shutdown))
          false
          (begin
            (set! app.r0-shutdown-complete 1)
            (app.r0-record-lifecycle 255)
            (set! app.r0-phase 8)
            true))))

;;; -------------------------------------------------------------------------
;;; R3 product/save/load application route

(defn app.r3-add-lifecycle (checkpoint name)
  (begin
    (set! app.r3-lifecycle (cons (list checkpoint name) app.r3-lifecycle))
    true))

(defn app.r3-key-event (sequence checkpoint key)
  (list (list 'occurrence 1) (list 'sequence sequence)
        (list 'checkpoint checkpoint) (list 'kind 'key)
        (list 'key key) (list 'action 'press)))

(defn app.r3-slot-event (sequence checkpoint action)
  (list (list 'occurrence 1) (list 'sequence sequence)
        (list 'checkpoint checkpoint) (list 'kind 'save-slot)
        (list 'action action) (list 'adapter 'wolf3d-save-slot-v1)
        (list 'slot 0) (list 'artifact 'r3-e1m1-slot0)))

(defn app.r3-add-event (event)
  (begin (set! app.r3-events (cons event app.r3-events)) true))

(defn app.r3-event-snapshot () (app.copy-list-tree (reverse app.r3-events)))
(defn app.r3-lifecycle-snapshot () (app.copy-list-tree (reverse app.r3-lifecycle)))

(defn app.r3-reset (signon)
  (begin
    (set! app.r3-active 0) (set! app.r3-phase 0)
    (set! app.r3-events nil) (set! app.r3-lifecycle nil)
    (set! app.r3-saved-bytes nil)
    (set! app.r0-phase 0)
    (let ((started (app.r0-presentation-step signon)))
      (if (not (= started 1))
          false
          (begin
            (app.r3-add-lifecycle 1 'application-entry)
            (app.r3-add-lifecycle 3 'signon-ready)
            (set! app.r3-active 1)
            true)))))

(defn app.r3-action (sequence checkpoint key)
  (if (= app.r3-active 0)
      false
      (cond
        ((= app.r3-phase 0)
         (if (and (= sequence 10) (and (= checkpoint 3) (eq? key 'Enter)))
             (if (= (app.r0-menu-enter "Enter") 2)
                 (begin (app.r3-add-event (app.r3-key-event 10 3 'Enter))
                   (app.r3-add-lifecycle 2 'init-complete)
                   (app.r3-add-lifecycle 4 'title-ready)
                   (set! app.r3-phase 1) true) false) false))
        ((= app.r3-phase 1)
         (if (and (= sequence 20) (and (= checkpoint 4) (eq? key 'Enter)))
             (if (= (app.r0-menu-enter "Enter") 3)
                 (begin (app.r3-add-event (app.r3-key-event 20 4 'Enter))
                   (app.r3-add-lifecycle 5 'menu-shown)
                   (app.r3-add-lifecycle 14 'main-menu-ready)
                   (set! app.r3-phase 2) true) false) false))
        ((= app.r3-phase 2)
         (if (and (= sequence 30) (and (= checkpoint 5) (eq? key 'Enter)))
             (if (= (app.r0-menu-enter "Enter") 4)
                 (begin (app.r3-add-event (app.r3-key-event 30 5 'Enter))
                   (app.r3-add-lifecycle 6 'episode-menu-ready)
                   (set! app.r3-phase 3) true) false) false))
        ((= app.r3-phase 3)
         (if (and (= sequence 40) (and (= checkpoint 6) (eq? key 'Enter)))
             (if (= (app.r0-menu-enter "Enter") 5)
                 (begin (app.r3-add-event (app.r3-key-event 40 6 'Enter))
                   (app.r3-add-lifecycle 7 'difficulty-menu-ready)
                   (set! app.r3-phase 4) true) false) false))
        ((or (= app.r3-phase 4) (= app.r3-phase 5))
         (let ((expected (if (= app.r3-phase 4) 50 51)))
           (if (and (= sequence expected) (and (= checkpoint 7) (eq? key 'ArrowUp)))
               (let ((before wl.menu-cursor)
                     (screen (wl.control-panel-step '((up 1)))))
                 (if (and (= screen wl.MENU-DIFFICULTY)
                          (= wl.menu-cursor (- before 1)))
                     (begin (app.r3-add-event (app.r3-key-event expected 7 'ArrowUp))
                       (set! app.r3-phase (+ app.r3-phase 1)) true) false))
               false)))
        ((= app.r3-phase 6)
         (if (and (= sequence 52) (and (= checkpoint 7) (eq? key 'Enter)))
             (if (= (app.r0-menu-enter "Enter") 6)
                 (begin (app.r3-add-event (app.r3-key-event 52 7 'Enter))
                   (app.r3-add-lifecycle 8 'game-start)
                   (set! app.r3-phase 7) true) false) false))
        ((= app.r3-phase 8)
         (if (and (= sequence 60) (and (= checkpoint 16) (eq? key 'F2)))
             (if (= (app.open-control-panel wl.SC-F2) wl.MENU-SAVE)
                 (begin (app.r3-add-event (app.r3-key-event 60 16 'F2))
                   (app.r3-add-lifecycle 16 'save-request-ready)
                   (app.r3-add-lifecycle 12 'save-menu-ready)
                   (set! app.r3-phase 9) true) false) false))
        ((= app.r3-phase 9)
         (if (and (= sequence 80) (and (= checkpoint 12) (eq? key 'Enter)))
             (if (= (app.control-panel-step '((confirm 1))) wl.MENU-SAVE-NAME)
                 (begin (app.r3-add-event (app.r3-key-event 80 12 'Enter))
                   (set! app.r3-phase 10) true) false) false))
        ((= app.r3-phase 10)
         (if (and (= sequence 81) (and (= checkpoint 12) (eq? key 'Enter)))
             (if (= (app.control-panel-step '((confirm 1))) wl.MENU-CLOSED)
                 (begin (app.r3-add-event (app.r3-key-event 81 12 'Enter))
                   (set! app.r3-phase 11) true) false) false))
        ((= app.r3-phase 13)
         (if (and (= sequence 110) (and (= checkpoint 15) (eq? key 'F3)))
             (if (= (app.open-control-panel wl.SC-F3) wl.MENU-LOAD)
                 (begin (app.r3-add-event (app.r3-key-event 110 15 'F3))
                   (app.r3-add-lifecycle 13 'load-menu-ready)
                   (set! app.r3-phase 14) true) false) false))
        ((= app.r3-phase 15)
         (if (and (= sequence 131) (and (= checkpoint 13) (eq? key 'Enter)))
             (if (= (app.control-panel-step '((confirm 1))) wl.MENU-CLOSED)
                 (begin (app.r3-add-event (app.r3-key-event 131 13 'Enter))
                   (set! app.r3-phase 16) true) false) false))
        (true false))))

(defn app.r3-checkpoint (checkpoint)
  (if (and (= app.r3-active 1) (and (= app.r3-phase 7) (= checkpoint 9)))
      (if (app.r0-start-level-music)
          (begin (app.r3-add-lifecycle 9 'playloop-enter)
                 (set! app.r3-phase 8) true)
          false)
      false))

(defn app.r3-save-persistent (sequence checkpoint)
  (if (not (and (= app.r3-active 1)
                (and (= app.r3-phase 11) (and (= sequence 90) (= checkpoint 10)))))
      false
      (let ((save (app.save-bytes)))
        (if (or (nil? save) (not (= (bytes.length save) wl.SAVE-BYTES)))
            false
            (begin
              (set! app.r3-saved-bytes (app.copy-byte-payload save))
              (set! app.r3-saved-x (wl.player@ wl.PLAYER-X))
              (set! app.r3-saved-y (wl.player@ wl.PLAYER-Y))
              (set! app.r3-saved-tilex (wl.player@ wl.PLAYER-TILEX))
              (set! app.r3-saved-tiley (wl.player@ wl.PLAYER-TILEY))
              (app.r3-add-event (app.r3-slot-event 90 10 'capture))
              (app.r3-add-lifecycle 10 'save-complete)
              (set! app.r3-phase 12)
              true)))))

(defn app.r3-save-export ()
  (if (nil? app.r3-saved-bytes) false (app.copy-byte-payload app.r3-saved-bytes)))

(defn app.r3-save (sequence checkpoint)
  (if (app.r3-save-persistent sequence checkpoint) (app.r3-save-export) false))

(defn app.r3-mutation ()
  (if (not (and (= app.r3-active 1) (= app.r3-phase 12)))
      false
      (if (and (= (wl.player@ wl.PLAYER-X) app.r3-saved-x)
               (and (= (wl.player@ wl.PLAYER-Y) app.r3-saved-y)
                    (and (= (wl.player@ wl.PLAYER-TILEX) app.r3-saved-tilex)
                         (= (wl.player@ wl.PLAYER-TILEY) app.r3-saved-tiley))))
          false
          (begin (app.r3-add-lifecycle 15 'mutation-complete)
                 (set! app.r3-phase 13) true))))

(defn app.r3-load (sequence checkpoint)
  (if (not (and (= app.r3-active 1)
                (and (= app.r3-phase 14) (and (= sequence 130) (= checkpoint 13)))))
      false
      (if (or (nil? app.r3-saved-bytes) (not (app.load-bytes app.r3-saved-bytes)))
          false
          (begin
            (app.r3-add-event (app.r3-slot-event 130 13 'restore))
            (app.r3-add-lifecycle 11 'load-complete)
            (set! app.r3-phase 15)
            true))))

(defn app.r3-shutdown ()
  (if (not (and (= app.r3-active 1) (= app.r3-phase 16)))
      false
      (if (not (app.shutdown))
          false
          (begin (app.r3-add-lifecycle 255 'graceful-shutdown)
                 (set! app.r3-phase 17) (set! app.r3-active 0) true))))

;;; R1/R2 application transactions. Gameplay state, pixels, and audio always
;;; come from the production owners; this layer owns ordering and capture.
(defn app.route-key-event (sequence checkpoint key)
  (list (list 'sequence sequence) (list 'checkpoint checkpoint)
        (list 'key key) (list 'action 'press)))
(defn app.route-integer? (value)
  (and (number? value) (= (mod value 1) 0)))
(defn app.route-gameplay-input? (tics controlx controly buttons)
  (and (app.route-integer? tics) (and (> tics 0)
    (and (app.route-integer? controlx) (and (app.route-integer? controly)
      (and (app.route-integer? buttons) (>= buttons 0)))))))
(defn app.route-add-lifecycle (route checkpoint name)
  (if (= route 1)
      (set! app.r1-lifecycle (cons (list checkpoint name) app.r1-lifecycle))
      (set! app.r2-lifecycle (cons (list checkpoint name) app.r2-lifecycle))))
(defn app.route-frame-records (route)
  (if (= route 1)
      '(13 26 39 52 65 78 91 104 117 130)
      '(2345 2346 2347 2348 2349 2350 2351 2352 2353 2354 2355 2356
        2651 2855 2856 2857 2858 2859 2860 2861 2862 2863 2864 2865 2874 2875)))
(defn app.route-copy-frames (frames)
  (if (nil? frames) nil
      (cons (list (car (car frames)) (app.copy-byte-payload (car (cdr (car frames)))))
            (app.route-copy-frames (cdr frames)))))
(defn app.route-copy-resolved-audio (payloads)
  (if (nil? payloads) nil
      (let ((payload (car payloads)))
        (cons (list (app.at payload 0) (app.at payload 1) (app.at payload 2)
                    (app.copy-byte-payload (app.at payload 3)))
              (app.route-copy-resolved-audio (cdr payloads))))))
(defn app.route-copy-program (program)
  (if (nil? program) nil
      (list (app.copy-list-tree (app.at program 0))
            (app.route-copy-resolved-audio (app.at program 1)))))

(defn app.r1-event-snapshot () (app.copy-list-tree (reverse app.r1-events)))
(defn app.r1-lifecycle-snapshot () (app.copy-list-tree (reverse app.r1-lifecycle)))
(defn app.r1-trace-snapshot () (app.copy-list-tree (reverse app.r1-trace)))
(defn app.r1-frame-snapshot () (app.route-copy-frames (reverse app.r1-frames)))
(defn app.r2-event-snapshot () (app.copy-list-tree (reverse app.r2-events)))
(defn app.r2-lifecycle-snapshot () (app.copy-list-tree (reverse app.r2-lifecycle)))
(defn app.r2-trace-snapshot () (app.copy-list-tree (reverse app.r2-trace)))
(defn app.r2-frame-snapshot () (app.route-copy-frames (reverse app.r2-frames)))
(defn app.r1-accepted-audio-snapshot () (app.copy-list-tree app.r1-audio))
(defn app.r1-unified-program-snapshot () (app.route-copy-program app.r1-program))
(defn app.r2-accepted-audio-snapshot () (app.copy-list-tree app.r2-audio))
(defn app.r2-unified-program-snapshot () (app.route-copy-program app.r2-program))
(defn app.r1-route-status ()
  (list app.r1-active app.r1-phase app.r1-trace-count app.r1-frame-index app.r1-finished))
(defn app.r2-route-status ()
  (list app.r2-active app.r2-phase app.r2-trace-count app.r2-frame-index app.r2-finished))

;;; R0 owns the presentation framebuffer, menu globals, and the audio trace
;;; boundary used by both routes. Acquire that shared owner before clearing any
;;; route-local state so a refused begin is observationally inert.
(defn app.route-begin-ready? (signon)
  (and (not (nil? signon))
    (and (= (bytes.length signon) 64000)
      (and (= app.r1-active 0) (and (= app.r2-active 0)
      (and (= app.r0-phase 0) (and (= app.r3-active 0)
      (and (= app.r5-capture-active 0)
           (not (app.deathcam-presentation-active?))))))))))

(defn app.r1-route-begin (signon)
  (if (not (app.route-begin-ready? signon)) false
      (if (= (app.r0-presentation-step signon) 1)
          (begin
            (set! app.r1-phase 0) (set! app.r1-events nil)
            (set! app.r1-lifecycle nil) (set! app.r1-trace nil) (set! app.r1-frames nil)
            (set! app.r1-trace-count 0)
            (set! app.r1-trace-mode 0) (set! app.r1-stream-count 0)
            (set! app.r1-pending-trace 0) (set! app.r1-pending-record 0)
            (set! app.r1-pending-exported 0) (set! app.r1-render-pending 0)
            (set! app.r1-render-token 0) (set! app.r1-render-count 0)
            (set! app.r1-frame-index 0) (set! app.r1-finished 0)
            (set! app.r1-audio nil) (set! app.r1-program nil)
            (app.route-add-lifecycle 1 1 'application-entry)
            (app.route-add-lifecycle 1 3 'signon-ready)
            (set! app.r1-active 1) true) false)))

(defn app.r1-route-action (sequence checkpoint key)
  (if (= app.r1-active 0) false
      (cond
        ((= app.r1-phase 0)
         (if (and (= sequence 2) (and (= checkpoint 3) (eq? key 'Enter))
                  (= (app.r0-menu-enter "Enter") 2))
             (begin (set! app.r1-events (cons (app.route-key-event sequence checkpoint key) app.r1-events))
               (app.route-add-lifecycle 1 2 'init-complete) (app.route-add-lifecycle 1 4 'title-ready)
               (set! app.r1-phase 1) true) false))
        ((= app.r1-phase 1)
         (if (and (= sequence 4) (and (= checkpoint 4) (eq? key 'Enter))
                  (= (app.r0-menu-enter "Enter") 3))
             (begin (set! app.r1-events (cons (app.route-key-event sequence checkpoint key) app.r1-events))
               (app.route-add-lifecycle 1 5 'menu-shown) (set! app.r1-phase 2) true) false))
        ((= app.r1-phase 2)
         (if (and (= sequence 5) (and (= checkpoint 5) (eq? key 'Enter))
                  (= (app.r0-menu-enter "Enter") 4))
             (begin (set! app.r1-events (cons (app.route-key-event sequence checkpoint key) app.r1-events))
               (app.route-add-lifecycle 1 6 'episode-menu-ready) (set! app.r1-phase 3) true) false))
        ((= app.r1-phase 3)
         (if (and (= sequence 6) (and (= checkpoint 6) (eq? key 'Enter))
                  (= (app.r0-menu-enter "Enter") 5))
             (begin (set! app.r1-events (cons (app.route-key-event sequence checkpoint key) app.r1-events))
               (app.route-add-lifecycle 1 7 'difficulty-menu-ready) (set! app.r1-phase 4) true) false))
        ((= app.r1-phase 4)
         (if (and (= sequence 7) (and (= checkpoint 7) (eq? key 'Enter))
                  (= (app.r0-menu-enter "Enter") 6) (app.r0-start-level-music))
             (begin (set! app.r1-events (cons (app.route-key-event sequence checkpoint key) app.r1-events))
               (app.route-add-lifecycle 1 8 'game-start) (app.route-add-lifecycle 1 9 'playloop-enter)
               (set! wl.startgame 0) (set! app.r1-phase 5) true) false))
        (true false))))

(defn app.r2-route-begin (signon)
  (if (not (app.route-begin-ready? signon)) false
      (if (= (app.r0-presentation-step signon) 1)
          (begin
            (set! app.r2-phase 0) (set! app.r2-events nil)
            (set! app.r2-lifecycle nil) (set! app.r2-trace nil) (set! app.r2-frames nil)
            (set! app.r2-trace-count 0)
            (set! app.r2-trace-mode 0) (set! app.r2-stream-count 0)
            (set! app.r2-pending-trace 0) (set! app.r2-pending-record 0)
            (set! app.r2-pending-exported 0) (set! app.r2-render-count 0)
            (set! app.r2-render-pending 0)
            (set! app.r2-frame-index 0) (set! app.r2-finished 0)
            (set! app.r2-audio nil) (set! app.r2-program nil)
            (app.route-add-lifecycle 2 1 'application-entry)
            (app.route-add-lifecycle 2 3 'signon-ready)
            (set! app.r2-active 1) true) false)))

(defn app.r2-route-action (sequence checkpoint key)
  (if (= app.r2-active 0) false
      (cond
        ((= app.r2-phase 0)
         (if (and (= sequence 20) (and (= checkpoint 3) (eq? key 'Enter))
                  (= (app.r0-menu-enter "Enter") 2))
             (begin (set! app.r2-events (cons (app.route-key-event sequence checkpoint key) app.r2-events))
               (app.route-add-lifecycle 2 2 'init-complete) (app.route-add-lifecycle 2 4 'title-ready)
               (set! app.r2-phase 1) true) false))
        ((= app.r2-phase 1)
         (if (and (= sequence 40) (and (= checkpoint 4) (eq? key 'Enter))
                  (= (app.r0-menu-enter "Enter") 3))
             (begin (set! app.r2-events (cons (app.route-key-event sequence checkpoint key) app.r2-events))
               (app.route-add-lifecycle 2 5 'menu-shown) (set! app.r2-phase 2) true) false))
        ((= app.r2-phase 2)
         (if (and (= sequence 50) (and (= checkpoint 5) (eq? key 'Enter))
                  (= (app.r0-menu-enter "Enter") 4))
             (begin (set! app.r2-events (cons (app.route-key-event sequence checkpoint key) app.r2-events))
               (app.route-add-lifecycle 2 6 'episode-menu-ready) (set! app.r2-phase 3) true) false))
        ((= app.r2-phase 3)
         (if (and (= sequence 60) (and (= checkpoint 6) (eq? key 'Enter))
                  (= (app.r0-menu-enter "Enter") 5))
             (begin (set! app.r2-events (cons (app.route-key-event sequence checkpoint key) app.r2-events))
               (app.route-add-lifecycle 2 7 'difficulty-menu-ready) (set! app.r2-phase 4) true) false))
        ((or (= app.r2-phase 4) (= app.r2-phase 5))
         (let ((expected (if (= app.r2-phase 4) 70 71)) (before wl.menu-cursor))
           (if (and (= sequence expected) (and (= checkpoint 7) (eq? key 'ArrowUp)))
               (if (and (= (wl.control-panel-step '((up 1))) wl.MENU-DIFFICULTY)
                        (= wl.menu-cursor (- before 1)))
                   (begin (set! app.r2-events (cons (app.route-key-event sequence checkpoint key) app.r2-events))
                          (set! app.r2-phase (+ app.r2-phase 1)) true) false) false)))
        ((= app.r2-phase 6)
         (if (and (= sequence 72) (and (= checkpoint 7) (eq? key 'Enter))
                  (= (app.r0-menu-enter "Enter") 6) (app.r0-start-level-music))
             (begin (set! app.r2-events (cons (app.route-key-event sequence checkpoint key) app.r2-events))
               (app.route-add-lifecycle 2 8 'game-start) (app.route-add-lifecycle 2 9 'playloop-enter)
               (set! wl.startgame 0) (set! app.r2-phase 7) true) false))
        (true false))))

(defn app.r1-route-tick-persistent (tics controlx controly buttons)
  (if (or (not (app.route-gameplay-input? tics controlx controly buttons))
          (or (= app.r1-active 0) (or (not (= app.r1-phase 5))
          (or (= app.r1-trace-mode 2) (or (= app.r1-pending-trace 1)
          (or (not (= wl.playstate wl.EX-STILLPLAYING)) (>= app.r1-trace-count 401))))))) false
      (if (not (app.replay-tick tics controlx controly buttons)) false
          (let ((record (app.trace-record)))
            (begin (app.consume-deathcam-victory)
              (set! app.r1-trace (cons record app.r1-trace))
              (set! app.r1-trace-mode 1)
              (set! app.r1-trace-count (+ app.r1-trace-count 1)) true)))))

;;; Streaming R1 transaction. A due sparse frame is a protocol barrier: the
;;; host must render, commit, and copy that exact record before gameplay may
;;; advance, so candidate bytes cannot drift to a later state.
(defn app.r1-frame-due? ()
  (and (< app.r1-frame-index (length (app.route-frame-records 1)))
       (= app.r1-trace-count (app.at (app.route-frame-records 1) app.r1-frame-index))))
(defn app.r1-route-tick-begin-persistent (tics controlx controly buttons)
  (if (not (and (app.route-gameplay-input? tics controlx controly buttons)
                (and (= app.r1-active 1) (and (= app.r1-phase 5)
                (and (not (= app.r1-trace-mode 1))
                (and (= app.r1-pending-trace 0)
                (and (not (app.r1-frame-due?))
                (and (= app.r1-render-pending 0)
                (and (= wl.playstate wl.EX-STILLPLAYING)
                     (< app.r1-trace-count 401))))))))))
      false
      (if (not (app.replay-tick tics controlx controly buttons)) false
          (begin
            (set! app.r1-pending-trace 1)
            (set! app.r1-pending-record (+ app.r1-trace-count 1))
            (set! app.r1-pending-exported 0)
            true))))
(defn app.r1-route-pending-trace-export ()
  (if (or (= app.r1-pending-trace 0)
          (or (= app.r1-pending-exported 1)
              (not (= app.r1-pending-record (+ app.r1-trace-count 1)))))
      false
      (begin (set! app.r1-pending-exported 1) (app.trace-record))))
(defn app.r1-route-tick-commit-persistent ()
  (if (or (= app.r1-pending-trace 0)
          (or (= app.r1-pending-exported 0)
              (or (= app.r1-trace-mode 1)
                  (not (= app.r1-pending-record (+ app.r1-trace-count 1))))))
      false
      (begin
        (app.consume-deathcam-victory)
        (set! app.r1-trace-mode 2)
        (set! app.r1-stream-count (+ app.r1-stream-count 1))
        (set! app.r1-trace-count (+ app.r1-trace-count 1))
        (set! app.r1-pending-trace 0)
        (set! app.r1-pending-record 0)
        (set! app.r1-pending-exported 0)
        true)))
(defn app.r1-route-trace-export ()
  (if (nil? app.r1-trace) false (app.copy-list-tree (car app.r1-trace))))
(defn app.r1-route-tick (tics controlx controly buttons)
  (if (app.r1-route-tick-persistent tics controlx controly buttons)
      (app.r1-route-trace-export) false))

(defn app.r2-route-tick-persistent (tics controlx controly buttons)
  (if (or (not (app.route-gameplay-input? tics controlx controly buttons))
          (or (= app.r2-active 0) (or (not (= app.r2-phase 7))
          (or (= app.r2-trace-mode 2) (or (= app.r2-pending-trace 1)
          (or (not (= wl.playstate wl.EX-STILLPLAYING)) (>= app.r2-trace-count 2875))))))) false
      (if (not (app.replay-tick tics controlx controly buttons)) false
          (let ((record (app.trace-record)))
            (begin (app.consume-deathcam-victory)
              (set! app.r2-trace (cons record app.r2-trace))
              (set! app.r2-trace-mode 1)
              (set! app.r2-trace-count (+ app.r2-trace-count 1)) true)))))

;;; Streaming R2 transaction. The effect, transient trace construction, and
;;; persistent commit are distinct so the host can compare a copied trace row
;;; before accepting it without retaining 2,875 Lisp alist trees.
(defn app.r2-route-tick-begin-persistent (tics controlx controly buttons)
  (if (or (not (app.route-gameplay-input? tics controlx controly buttons))
          (or (= app.r2-active 0) (or (not (= app.r2-phase 7))
          (or (= app.r2-trace-mode 1) (or (= app.r2-pending-trace 1)
          (or (not (= wl.playstate wl.EX-STILLPLAYING))
              (>= app.r2-trace-count 2875)))))))
      false
      (if (not (app.replay-tick tics controlx controly buttons)) false
          (begin
            (set! app.r2-pending-trace 1)
            (set! app.r2-pending-record (+ app.r2-trace-count 1))
            (set! app.r2-pending-exported 0)
            true))))

(defn app.r2-route-pending-trace-export ()
  (if (or (= app.r2-pending-trace 0)
          (or (= app.r2-pending-exported 1)
              (not (= app.r2-pending-record (+ app.r2-trace-count 1)))))
      false
      (begin (set! app.r2-pending-exported 1) (app.trace-record))))

(defn app.r2-route-tick-commit-persistent ()
  (if (or (= app.r2-pending-trace 0)
          (or (= app.r2-pending-exported 0)
              (or (= app.r2-trace-mode 1)
                  (not (= app.r2-pending-record (+ app.r2-trace-count 1))))))
      false
      (begin
        (app.consume-deathcam-victory)
        (set! app.r2-trace-mode 2)
        (set! app.r2-stream-count (+ app.r2-stream-count 1))
        (set! app.r2-trace-count (+ app.r2-trace-count 1))
        (set! app.r2-pending-trace 0)
        (set! app.r2-pending-record 0)
        (set! app.r2-pending-exported 0)
        true)))
(defn app.r2-route-trace-export ()
  (if (nil? app.r2-trace) false (app.copy-list-tree (car app.r2-trace))))
(defn app.r2-route-tick (tics controlx controly buttons)
  (if (app.r2-route-tick-persistent tics controlx controly buttons)
      (app.r2-route-trace-export) false))

(defn app.route-capture-frame-persistent (route record)
  (let ((pixels (app.frame-bytes)))
    (app.route-store-current-frame-persistent route record pixels)))

(defn app.route-store-current-frame-persistent (route record pixels)
  (let ((index (if (= route 1) app.r1-frame-index app.r2-frame-index))
        (rows (if (= route 1) app.r1-trace-count app.r2-trace-count)))
    (if (or (>= index (length (app.route-frame-records route)))
            (or (not (= rows record))
                (not (= record (app.at (app.route-frame-records route) index)))))
        false
        (if (or (nil? pixels) (not (= (bytes.length pixels) 64000))) false
            (let ((copy (app.copy-byte-payload pixels)))
              (if (= route 1)
                  (begin (set! app.r1-frames (cons (list record copy) app.r1-frames))
                         (set! app.r1-frame-index (+ index 1)) true)
                  (begin (set! app.r2-frames (cons (list record copy) app.r2-frames))
                         (set! app.r2-frame-index (+ index 1)) true)))))))
(defn app.route-last-frame-export (route record)
  (let ((frames (if (= route 1) app.r1-frames app.r2-frames)))
    (if (or (nil? frames) (not (= (car (car frames)) record))) false
        (app.copy-byte-payload (car (cdr (car frames)))))))
(defn app.r1-route-frame-persistent (record)
  (if (and (= app.r1-active 1) (and (= app.r1-phase 5)
      (= app.r1-trace-mode 1)))
      (app.route-capture-frame-persistent 1 record) false))
(defn app.r1-route-frame (record)
  (if (app.r1-route-frame-persistent record) (app.route-last-frame-export 1 record) false))
(defn app.r1-render-persistent (record)
  (if (not (and (= app.r1-active 1) (and (= app.r1-phase 5)
           (and (= app.r1-trace-mode 2) (and (app.r1-frame-due?)
           (and (= app.r1-trace-count record)
           (and (= (app.at (app.route-frame-records 1) app.r1-frame-index) record)
           (and (= app.r1-render-pending 0) (= app.r1-render-token 0)))))))))
      false
      (if (not (app.render-persistent)) false
          (begin (set! app.r1-render-pending record) true))))
(defn app.r1-render-commit-persistent (record)
  (if (= app.r1-render-pending record)
      (begin (set! app.r1-render-token record)
             (set! app.r1-render-pending 0) true) false))
(defn app.r1-current-frame-persistent (record)
  (if (and (= app.r1-active 1) (and (= app.r1-phase 5)
      (and (= app.r1-trace-mode 2) (and (= app.r1-render-token record)
      (and (= app.r1-trace-count record) (app.r1-frame-due?))))))
      (if (app.route-store-current-frame-persistent 1 record app.frame-buffer)
          (begin (set! app.r1-render-token 0)
                 (set! app.r1-render-count (+ app.r1-render-count 1)) true)
          false)
      false))
(defn app.r2-route-frame-persistent (record)
  (if (and (= app.r2-active 1) (= app.r2-phase 7))
      (app.route-capture-frame-persistent 2 record) false))
(defn app.r2-current-frame-persistent (record)
  (if (and (= app.r2-active 1) (and (= app.r2-phase 7)
      (and (= app.r2-trace-mode 2) (= app.r2-render-count record))))
      (app.route-store-current-frame-persistent 2 record app.frame-buffer) false))
(defn app.r2-render-persistent (record)
  (if (or (not (= app.r2-active 1))
          (or (not (= app.r2-phase 7))
          (or (not (= app.r2-trace-mode 2))
          (or (not (= app.r2-trace-count record))
          (or (not (= app.r2-render-count (- record 1)))
          (or (not (= app.r2-render-pending 0))
          (or (not (= app.r2-pending-trace 0))
              (not (= app.r2-pending-exported 0)))))))))
      false
      (if (not (app.render-persistent)) false
          (begin (set! app.r2-render-pending record) true))))
(defn app.r2-render-commit-persistent (record)
  (if (and (= app.r2-render-pending record)
           (= app.r2-render-count (- record 1)))
      (begin (set! app.r2-render-count record)
             (set! app.r2-render-pending 0) true) false))
(defn app.r2-route-frame (record)
  (if (app.r2-route-frame-persistent record) (app.route-last-frame-export 2 record) false))

(defn app.r1-trace-complete? ()
  (or (and (= app.r1-trace-mode 1)
           (and (= (length app.r1-trace) 401) (= app.r1-trace-count 401)))
      (and (= app.r1-trace-mode 2)
           (and (nil? app.r1-trace)
           (and (= app.r1-stream-count 401)
           (and (= app.r1-trace-count 401)
           (and (= app.r1-pending-trace 0)
           (and (= app.r1-pending-record 0)
           (and (= app.r1-pending-exported 0)
           (and (= app.r1-render-pending 0)
           (and (= app.r1-render-token 0)
           (and (= app.r1-render-count (length (app.route-frame-records 1)))
                (= (length app.r1-frames) 10)))))))))))))
(defn app.r1-route-finish-persistent ()
  (if (not (and (= app.r1-active 1)
           (and (= app.r1-phase 5)
           (and (= app.r1-finished 0)
           (and (app.r1-trace-complete?)
           (and (= wl.playstate wl.EX-STILLPLAYING)
                (= app.r1-frame-index (length (app.route-frame-records 1))))))))) false
      (let ((program (app.audio-operation-program-export)))
        (if (not program) false
            (begin (set! app.r1-audio (app.copy-list-tree (sd.audio-event-log)))
              (set! app.r1-program (app.route-copy-program program))
              (set! app.r1-finished 1) (set! app.r1-phase 6) true)))))
(defn app.r1-route-finish-export ()
  (if (= app.r1-finished 0) false
      (list (app.r1-event-snapshot) (app.r1-lifecycle-snapshot)
            (app.r1-trace-snapshot) (app.r1-frame-snapshot)
            (app.r1-accepted-audio-snapshot) (app.r1-unified-program-snapshot))))
(defn app.r1-route-finish ()
  (if (app.r1-route-finish-persistent) (app.r1-route-finish-export) false))
(defn app.r1-stream-attestation-export ()
  (list app.r1-trace-mode app.r1-trace-count app.r1-stream-count
        app.r1-pending-trace app.r1-pending-record app.r1-pending-exported
        app.r1-render-pending app.r1-render-token app.r1-render-count app.r1-frame-index
        (length app.r1-trace)))

(defn app.r2-route-finish-persistent ()
  (if (not (and (= app.r2-active 1) (and (= app.r2-phase 7) (and (= app.r2-finished 0)
      (and (or (and (= app.r2-trace-mode 1)
                    (and (= (length app.r2-trace) 2875) (= app.r2-trace-count 2875)))
               (and (= app.r2-trace-mode 2)
                    (and (nil? app.r2-trace)
                    (and (= app.r2-stream-count 2875)
                    (and (= app.r2-trace-count 2875)
                    (and (= app.r2-pending-trace 0)
                    (and (= app.r2-pending-exported 0)
                    (and (= app.r2-render-pending 0)
                         (= app.r2-render-count 2875)))))))))
      (and (= app.r2-frame-index (length (app.route-frame-records 2)))
      (and (= wl.playstate wl.EX-SECRETLEVEL) (and (= wl.startgame 0)
      (and (= wl.health 7) (and (= wl.map 0) (and (= wl.episode 0) (= wl.secretcount 2)))))))))))) false
      (let ((program (app.audio-operation-program-export)))
        (if (not program) false
            (begin (set! app.r2-audio (app.copy-list-tree (sd.audio-event-log)))
              (set! app.r2-program (app.route-copy-program program))
              (set! app.r2-finished 1) (set! app.r2-phase 8) true)))))
(defn app.r2-route-finish-export ()
  (if (= app.r2-finished 0) false
      (list (app.r2-event-snapshot) (app.r2-lifecycle-snapshot)
            (app.r2-trace-snapshot) (app.r2-frame-snapshot)
            (app.r2-accepted-audio-snapshot) (app.r2-unified-program-snapshot)
            (list wl.playstate wl.startgame wl.health wl.map wl.episode
                  wl.secretcount app.r2-trace-count))))
(defn app.r2-route-finish ()
  (if (app.r2-route-finish-persistent) (app.r2-route-finish-export) false))
(defn app.r1-route-shutdown ()
  (if (not (and (= app.r1-active 1) (= app.r1-finished 1))) false
      (if (not (app.shutdown)) false
          (begin (app.route-add-lifecycle 1 255 'graceful-shutdown)
                 (set! app.r1-active 0) (set! app.r1-phase 7) true))))
(defn app.r2-route-shutdown ()
  (if (not (and (= app.r2-active 1) (= app.r2-finished 1))) false
      (if (not (app.shutdown)) false
          (begin (app.route-add-lifecycle 2 255 'graceful-shutdown)
                 (set! app.r2-active 0) (set! app.r2-phase 9) true))))

;;; Host-facing ownership vocabulary. These names make the allocation contract
;;; explicit without removing the established application API: persistent
;;; calls may retain evaluator objects through global state, while export calls
;;; are copy-only and may be enclosed by a host heap mark/release pair.
(defn app.r0-presentation-step-persistent (signon) (app.r0-presentation-step signon))
(defn app.r0-menu-enter-persistent (key) (app.r0-menu-enter key))
(defn app.r0-start-level-music-persistent () (app.r0-start-level-music))
(defn app.r0-graceful-shutdown-persistent () (app.r0-graceful-shutdown))
(defn app.r1-route-begin-persistent (signon) (app.r1-route-begin signon))
(defn app.r1-route-action-persistent (sequence checkpoint key)
  (app.r1-route-action sequence checkpoint key))
(defn app.r1-route-shutdown-persistent () (app.r1-route-shutdown))
(defn app.r2-route-begin-persistent (signon) (app.r2-route-begin signon))
(defn app.r2-route-action-persistent (sequence checkpoint key)
  (app.r2-route-action sequence checkpoint key))
(defn app.r2-route-shutdown-persistent () (app.r2-route-shutdown))
(defn app.r3-reset-persistent (signon) (app.r3-reset signon))
(defn app.r3-action-persistent (sequence checkpoint key)
  (app.r3-action sequence checkpoint key))
(defn app.r3-checkpoint-persistent (checkpoint) (app.r3-checkpoint checkpoint))
(defn app.r3-mutation-persistent () (app.r3-mutation))
(defn app.r3-load-persistent (sequence checkpoint) (app.r3-load sequence checkpoint))
(defn app.r3-shutdown-persistent () (app.r3-shutdown))
(defn app.r4-start-ted-level-persistent (level difficulty)
  (app.start-ted-level level difficulty))
(defn app.r4-apply-source-mli-cheat-persistent () (app.apply-source-mli-cheat))

(defn app.menu-action-export () (wl.menu-action-log))

(defn app.begin-level-completed ()
  (let ((result (wl.level-completed)))
    (begin
      (set! app.intermission-result result)
      (wl.draw-level-completed app.frame-buffer result)
      (app.record-lifecycle 'intermission)
      result)))

(defn app.intermission-advance (acknowledged elapsed)
  (if (not (app.presentation-clock elapsed))
      false
      (let ((state (wl.intermission-tick acknowledged elapsed)))
        (begin
          (if (not (nil? app.intermission-result))
              (wl.draw-level-completed app.frame-buffer app.intermission-result) nil)
          (if (eq? (car state) 'level-done)
              (app.complete-level-intermission) state)))))

(defn app.complete-level-intermission ()
  (let ((map (wl.finish-playstate wl.EX-COMPLETED)))
    (begin
      (set! wl.application-phase wl.APP-PLAYING)
      (app.setup-current-level)
      (set! app.intermission-result nil)
      (app.record-lifecycle 'playing)
      (list 'playing map))))

(defn app.begin-victory ()
  (let ((summary (wl.victory)))
    (begin
      (wl.draw-victory app.frame-buffer summary)
      (app.record-lifecycle 'victory)
      summary)))

(defn app.victory-advance (acknowledged elapsed)
  (if (not (app.presentation-clock elapsed))
      false
      (let ((state (wl.victory-tick acknowledged)))
        (if (eq? (car state) 'victory-end-text)
            (app.begin-victory-end-text (app.at state 1))
            state))))

(defn app.victory-advance-persistent (acknowledged elapsed)
  (if (not (app.presentation-clock elapsed))
      false
      (let ((state (wl.victory-tick acknowledged)))
        (begin
          (if (eq? (car state) 'victory-end-text)
              (app.begin-victory-end-text (app.at state 1)) nil)
          true))))

(defn app.begin-victory-end-text (episode)
  (if (not (app.cache-end-article episode))
      (app.fail-runtime 'end-article-rejected)
      (begin
        ;; EndText validates the non-SPEAR episode/chunk contract; the explicit
        ;; execution state then supplies resumable page timing and navigation.
        ;; Its validation scan is transient; begin-article owns the one scan
        ;; that must survive while the host advances and draws the document.
        (app.validate-end-text episode app.end-article)
        (wl.begin-article app.end-article)
        (app.draw-article-frame true)
        (app.record-lifecycle 'end-text)
        wl.article-execution)))

(defn app.validate-end-text (episode article)
  (app.validate-end-text-marked episode article (heap.used)))

(defn app.validate-end-text-marked (episode article mark)
  (let ((state (wl.end-text episode article)))
    (begin (heap.release mark) (not (nil? state)))))

(defn app.end-text-advance (direction elapsed)
  (if (not (app.presentation-clock elapsed))
      false
      (let ((state (wl.article-execution-step direction elapsed)))
        (if (eq? (car state) 'article-done)
            (app.complete-victory-end-text)
            (begin (app.draw-article-frame true) state)))))

(defn app.complete-victory-end-text-persistent ()
  (let ((insert (wl.check-high-score wl.score (+ wl.map 1) wl.episode)))
    (begin
      (set! app.victory-high-score-insert insert)
      (set! wl.application-phase wl.APP-MENU)
      (app.draw-high-scores-frame)
      (app.record-lifecycle 'high-scores)
      true)))

(defn app.complete-victory-end-text-export ()
  (list 'high-scores app.victory-high-score-insert))
(defn app.complete-victory-end-text ()
  (if (app.complete-victory-end-text-persistent)
      (app.complete-victory-end-text-export) false))

(defn app.draw-article-frame (shownumber)
  (begin
    (wl.cache-presentation-font)
    (app.draw-article-frame-marked shownumber (heap.used))))

(defn app.draw-article-frame-marked (shownumber mark)
  (begin
    (wl.draw-current-article app.frame-buffer wl.presentation-font shownumber)
    (heap.release mark)
    app.frame-buffer))

(defn app.draw-high-scores-frame ()
  (app.draw-high-scores-frame-marked (heap.used)))

(defn app.draw-high-scores-frame-marked (mark)
  (begin
    (wl.draw-high-scores app.frame-buffer)
    (heap.release mark)
    app.frame-buffer))

(defn app.pg13-frame () (wl.pg13 app.frame-buffer))

(defn app.save-bytes () (wl.save-the-game))

(defn app.load-bytes (save)
  (if (or (nil? save) (not (= (bytes.length save) wl.SAVE-BYTES)))
      false
      (let ((accepted (wl.load-the-game save)))
        (begin
          (if accepted (app.reset-deathcam-application-lifecycle) nil)
          (if (app.mounted?)
              (begin
                (app.cache-plane-hashes (wl.plane-hash-words app.wall-plane)
                                        (wl.plane-hash-words app.object-plane))
                (set! app.drawn-face-picture -1)
                (set! app.drawn-health nil) (set! app.drawn-lives nil)
                (set! app.drawn-level nil) (set! app.drawn-ammo nil)
                (set! app.drawn-keys nil) (set! app.drawn-weapon-picture -1)
                (set! app.drawn-score nil)
                (app.refresh-renderer-state))
              nil)
          accepted))))

(defn app.set-sound-mode (mode)
  (if (sd.set-sound-mode mode) (wl.cp-sound mode) false))

(defn app.set-digitized-mode (mode)
  (if (sd.set-menu-digi-device mode)
      (wl.cp-digitized-sound mode) false))

(defn app.set-music-mode (mode)
  (if (sd.set-music-mode mode) (wl.cp-music mode) false))

(defn app.trace-export () (app.trace-record))
(defn app.audio-event-export () (sd.audio-event-log))
(defn app.audio-host-event-export () (sd.audio-host-event-log))
(defn app.adlib-register-export ()
  (list sd.fx-service-count (sd.adlib-register-log)))
(defn app.music-register-export ()
  (list sd.music-service-count (sd.music-host-register-log)))

(defn app.exact-list-length? (value remaining)
  (if (= remaining 0)
      (nil? value)
      (and (pair? value) (app.exact-list-length? (cdr value) (- remaining 1)))))

(defn app.number-member? (value values)
  (if (nil? values)
      false
      (or (= value (car values)) (app.number-member? value (cdr values)))))

(defn app.audio-operation-shape? (operation)
  (and (app.exact-list-length? operation 13)
       (app.audio-operation-fields? operation 0)))

(defn app.audio-operation-fields? (fields index)
  (if (= index 13)
      true
      (and (number? (car fields))
           (app.audio-operation-fields? (cdr fields) (+ index 1)))))

(defn app.audio-opl-operation? (operation)
  (and (or (= (app.at operation 3) 2) (= (app.at operation 3) 4))
       (and (= (app.at operation 4) -1)
         (and (>= (app.at operation 5) 0) (and (<= (app.at operation 5) 255)
           (and (>= (app.at operation 6) 0) (and (<= (app.at operation 6) 255)
             (and (= (app.at operation 7) -1) (and (= (app.at operation 8) -1)
               (and (= (app.at operation 9) -1) (and (= (app.at operation 10) -1)
                 (and (= (app.at operation 11) 0)
                      (= (app.at operation 12) -1)))))))))))))

(defn app.audio-native-operation? (operation)
  (let ((source (app.at operation 3)) (payload (app.at operation 4))
        (left (app.at operation 9)) (right (app.at operation 10)))
    (and (or (= source 1) (= source 3))
         (and (and (>= payload 0) (< payload app.AUDIO-OP-MAX))
           (and (and (= (app.at operation 5) -1) (= (app.at operation 6) -1))
             (and (and (>= (app.at operation 7) 0) (<= (app.at operation 7) 3))
               (and (or (= (app.at operation 8) 0) (= (app.at operation 8) 1))
                 (and (>= left 0) (and (<= left 15)
                   (and (>= right 0) (and (<= right 15)
                     (and (not (and (= left 15) (= right 15)))
                       (and (or (= (app.at operation 11) 0) (= (app.at operation 11) 1))
                            (and (>= (app.at operation 12) 0)
                                 (< (app.at operation 12) sd.LASTSOUND)))))))))))))))

(defn app.audio-operations-valid? (operations final-units previous-unit previous-order native-ids)
  (if (nil? operations)
      true
      (let ((operation (car operations)))
        (if (not (app.audio-operation-shape? operation))
            false
            (let ((unit (app.at operation 0)) (order (app.at operation 1))
                  (kind (app.at operation 2)) (payload (app.at operation 4)))
              (and (>= unit 0)
                (and (<= unit final-units)
                  (and (and (>= order 0) (< order app.AUDIO-OP-MAX))
                    (and (or (> unit previous-unit)
                             (and (= unit previous-unit) (> order previous-order)))
                      (and (if (= kind 1)
                               (app.audio-opl-operation? operation)
                               (and (= kind 2)
                                    (and (not (app.number-member? payload native-ids))
                                         (app.audio-native-operation? operation))))
                        (app.audio-operations-valid? (cdr operations) final-units unit order
                          (if (= kind 2) (cons payload native-ids) native-ids))))))))))))

(defn app.audio-native-ids (operations ids)
  (if (nil? operations)
      ids
      (app.audio-native-ids (cdr operations)
        (if (= (app.at (car operations) 2) 2)
            (cons (app.at (car operations) 4) ids)
            ids))))

(defn app.audio-native-source-for-id (operations id)
  (if (nil? operations)
      -1
      (let ((operation (car operations)))
        (if (and (= (app.at operation 2) 2) (= (app.at operation 4) id))
            (app.at operation 3)
            (app.audio-native-source-for-id (cdr operations) id)))))

(defn app.audio-payload-reference? (payload)
  (if (not (app.exact-list-length? payload 3))
      false
      (let ((id (app.at payload 0)) (source (app.at payload 1))
            (reference (app.at payload 2)))
        (and (number? id) (and (and (>= id 0) (< id app.AUDIO-OP-MAX))
          (and (number? source) (and (or (= source 1) (= source 3))
            (and (number? reference) (and (>= reference 0)
              (if (= source 1) (< reference sd.LASTSOUND)
                                 (< reference sd.NumDigi)))))))))))

(defn app.audio-payloads-valid? (payloads operations native-ids seen)
  (if (nil? payloads)
      (= (length seen) (length native-ids))
      (let ((payload (car payloads)))
        (and (app.audio-payload-reference? payload)
          (let ((id (app.at payload 0)))
            (and (app.number-member? id native-ids)
              (and (= (app.at payload 1)
                      (app.audio-native-source-for-id operations id))
                (and (not (app.number-member? id seen))
                     (app.audio-payloads-valid? (cdr payloads) operations native-ids
                                                (cons id seen))))))))))

(defn app.copy-byte-payload (source)
  (if (nil? source)
      false
      (let ((copy (bytes.alloc (bytes.length source))))
        (begin (bytes.copy copy 0 source 0 (bytes.length source)) copy))))

(defn app.resolve-audio-payloads (payloads)
  (if (nil? payloads)
      nil
      (let ((payload (car payloads)))
        (let ((id (app.at payload 0)) (source (app.at payload 1))
              (reference (app.at payload 2)))
          (let ((bytes (if (= source 1) (sd.render-pc-pcm reference)
                                           (sd.render-digitized-pcm reference))))
            (if (nil? bytes)
                false
                (let ((copy (app.copy-byte-payload bytes)))
                  (let ((rest (app.resolve-audio-payloads (cdr payloads))))
                    (if (and (not (nil? (cdr payloads))) (not rest))
                        false
                        (cons (list id source reference copy) rest))))))))))

;;; Return (raw-program resolved-payloads). The raw program is the manager's
;;; exact finalUnits/operations/payload-reference triple; native byte payloads
;;; are resolved once and defensively copied without consulting route events.
(defn app.audio-operation-program-export ()
  (let ((program (sd.audio-operation-program)))
    (if (not (app.exact-list-length? program 3))
        false
        (let ((final-units (app.at program 0)) (operations (app.at program 1))
              (payloads (app.at program 2)))
          (if (not (and (number? final-units)
                        (and (>= final-units 0) (<= final-units app.AUDIO-OP-MAX))))
              false
              (if (not (app.audio-operations-valid? operations final-units -1 -1 nil))
                  false
                  (let ((native-ids (app.audio-native-ids operations nil)))
                    (if (not (app.audio-payloads-valid? payloads operations native-ids nil))
                        false
                        (let ((resolved (app.resolve-audio-payloads payloads)))
                          (if (and (not (nil? payloads)) (not resolved))
                              false
                              (list program resolved)))))))))))

(defn app.copy-list-tree (value)
  (if (nil? value)
      nil
      (if (pair? value)
          (cons (app.copy-list-tree (car value)) (app.copy-list-tree (cdr value)))
          value)))

;;; R5 host bridge. Elapsed time is host observation, never inferred from the
;;; source ordinal. wl.r5-action remains the sole authored input validator and
;;; owner of route decisions and accepted/rejected sound behavior.
(defn app.r5-config-write-values (target values index)
  (if (nil? values)
      target
      (begin
        (u8! target index (if (= (car values) -1) 255 (car values)))
        (app.r5-config-write-values target (cdr values) (+ index 1)))))

(defn app.r5-config-menu-digi (mode)
  (cond ((= mode 0) 0) ((= mode 2) 1) ((= mode 3) 2) (true false)))

(defn app.r5-apply-config (config)
  (if (or (not (wl.r5-config-valid? config))
          (not (number? (app.r5-config-menu-digi (wl.r5-config-value config 2)))))
      false
      (begin
        (set! wl.sound-mode (wl.r5-config-value config 0))
        (set! wl.music-mode (wl.r5-config-value config 1))
        (set! wl.digi-mode (app.r5-config-menu-digi (wl.r5-config-value config 2)))
        (set! wl.view-size (wl.r5-config-value config 3))
        (set! wl.pending-view-size wl.view-size)
        (app.r5-config-write-values wl.dirscan (wl.r5-config-value config 4) 0)
        (app.r5-config-write-values wl.buttonscan (wl.r5-config-value config 5) 0)
        (set! wl.mouse-enabled (if (wl.r5-config-value config 6) 1 0))
        (set! wl.joystick-enabled (if (wl.r5-config-value config 7) 1 0))
        (set! wl.joypad-enabled (if (wl.r5-config-value config 8) 1 0))
        (set! wl.joystick-progressive (if (wl.r5-config-value config 9) 1 0))
        (set! wl.joystick-port (wl.r5-config-value config 10))
        (app.r5-config-write-values wl.buttonmouse (wl.r5-config-value config 11) 0)
        (app.r5-config-write-values wl.buttonjoy (wl.r5-config-value config 12) 0)
        (set! wl.mouse-adjustment (wl.r5-config-value config 13))
        (and (sd.set-sound-mode wl.sound-mode)
             (and (sd.set-digi-device (wl.r5-config-value config 2))
                  (sd.set-music-mode wl.music-mode))))))

(defn app.r5-capture-begin (seed)
  (begin
    ;; A re-begin is a new transaction. Never leave the prior capture usable
    ;; if decode, configuration, or the menu reset fails after partial work.
    (set! app.r5-capture-active 0)
    (set! app.r5-export-complete 0)
    (set! app.r5-frame-pixels nil)
    (let ((decoded (wl.r5-config-decode seed)))
      (if (not decoded)
          false
          (let ((prior (wl.r5-snapshot)))
            (if (not (app.r5-apply-config decoded))
                (begin (app.r5-apply-config prior) false)
                (let ((snapshot (wl.r5-begin)))
                  (if (not snapshot)
                      (begin (app.r5-apply-config prior) false)
                      ;; Begin owns the route/audio reset and restores source
                      ;; defaults, so reapply the already validated import.
                      (if (not (app.r5-apply-config decoded))
                          (begin (app.r5-apply-config prior) false)
                          (begin
                            (set! app.r5-config-seed (app.copy-byte-payload seed))
                            (set! app.r5-capture-active 1)
                            (app.copy-list-tree (wl.r5-snapshot))))))))))))

(defn app.r5-frame-stored? (name)
  (not (nil? (app.r0-find-frame app.r5-frame-pixels name))))

(defn app.r5-capture-frame-pixels (name)
  (if (or (= app.r5-capture-active 0)
          (or (= wl.r5-terminal 1)
              (or (not (eq? name (wl.r5-capture-name)))
                  (app.r5-frame-stored? name))))
      false
      (let ((old-frames wl.r5-frames)
            (drawn (wl.r5-frame name app.frame-buffer wl.presentation-font)))
        (if (or (not drawn) (not (= (bytes.length app.frame-buffer) 64000)))
            (begin (set! wl.r5-frames old-frames) false)
            (let ((pixels (app.copy-byte-payload app.frame-buffer)))
              (begin
                (set! app.r5-frame-pixels (cons (list name pixels) app.r5-frame-pixels))
                (app.copy-byte-payload pixels)))))))

(defn app.r5-frame-pixel-snapshot (name)
  (if (= app.r5-capture-active 0)
      false
      (let ((stored (app.r0-find-frame app.r5-frame-pixels name)))
        (if (nil? stored) false (app.copy-byte-payload stored)))))

(defn app.r5-action-checkpoint-ready? ()
  (let ((name (wl.r5-capture-name)))
    (if (nil? name) true (app.r5-frame-stored? name))))

(defn app.r5-capture-action (elapsed source-ordinal input)
  (if (or (= app.r5-capture-active 0)
          (or (= wl.r5-terminal 1) (or (not (number? elapsed)) (< elapsed 0))))
      false
      (if (not (app.r5-action-checkpoint-ready?))
          false
          (if (not (sd.advance-source-tics elapsed))
              false
              (wl.r5-action source-ordinal input)))))

(defn app.r5-action-snapshot ()
  (if (= app.r5-capture-active 0) false (app.copy-list-tree (wl.r5-status))))

(defn app.r5-config-snapshot ()
  (if (= app.r5-capture-active 0) false (app.copy-list-tree (wl.r5-snapshot))))

(defn app.r5-frame-name-snapshot ()
  (if (= app.r5-capture-active 0) false (app.copy-list-tree (wl.r5-frame-log))))

(defn app.r5-attempt-snapshot ()
  (if (= app.r5-capture-active 0) false (app.copy-list-tree (wl.r5-attempt-log))))

(defn app.r5-accepted-audio-snapshot ()
  (if (= app.r5-capture-active 0) false (app.copy-list-tree (sd.audio-event-log))))

(defn app.r5-unified-program-snapshot ()
  (if (= app.r5-capture-active 0) false (app.audio-operation-program-export)))

(defn app.r5-terminal-status ()
  (if (= app.r5-capture-active 0)
      (list 'active false 'terminal false 'shutdown false)
      (list 'active true
            'terminal (= wl.r5-terminal 1)
            'shutdown (= wl.application-phase wl.APP-SHUTDOWN))))

(defn app.r5-exact-frame-names? ()
  (equal? (wl.r5-frame-log)
    '(main-initial sound-initial control-panel-initial custom-controls-initial
      view-initial main-final)))

(defn app.r5-all-frame-pixels? (names)
  (if (nil? names)
      true
      (and (app.r5-frame-stored? (car names))
           (app.r5-all-frame-pixels? (cdr names)))))

(defn app.r5-frame-pixel-export (names)
  (if (nil? names)
      nil
      (cons (list (car names) (app.r5-frame-pixel-snapshot (car names)))
            (app.r5-frame-pixel-export (cdr names)))))

;;; Export precedes shutdown. The host persists this value and then invokes
;;; the separate post-export shutdown callback.
(defn app.r5-capture-finish ()
  (let ((names '(main-initial sound-initial control-panel-initial custom-controls-initial
                  view-initial main-final)))
    (if (or (= app.r5-capture-active 0)
            (or (not (= wl.r5-route-index 39))
                (or (not (= wl.r5-terminal 1))
                    (or (not (= wl.application-phase wl.APP-SHUTDOWN))
                        (or (not (app.r5-exact-frame-names?))
                            (not (app.r5-all-frame-pixels? names)))))))
        false
        (let ((patched (wl.r5-config-encode app.r5-config-seed (wl.r5-snapshot))))
          (if (not patched)
              false
              (let ((actions (app.r5-action-snapshot))
                    (config (app.r5-config-snapshot))
                    (pixels (app.r5-frame-pixel-export names))
                    (attempts (app.r5-attempt-snapshot))
                    (audio (app.r5-accepted-audio-snapshot))
                    (program (app.r5-unified-program-snapshot))
                    (status (app.r5-terminal-status)))
                (if (not program)
                    false
                    (begin
                      (set! app.r5-export-complete 1)
                      (list 'r5-finish patched actions config pixels attempts audio program status)))))))))

(defn app.r5-post-export-shutdown ()
  (if (or (= app.r5-capture-active 0) (= app.r5-export-complete 0))
      false
      (begin
        (sd.shutdown)
        (set! app.r5-capture-active 0)
        true)))

(defn app.pc-pcm-bytes (sound) (sd.render-pc-pcm sound))
(defn app.digitized-pcm-bytes (sound)
  (sd.render-digitized-pcm (sd.digi-map@ sound)))
(defn app.advance-audio-timer (tics)
  (if (< tics 0)
      false
      (sd.advance-source-tics tics)))
(defn app.audio-capabilities () (sd.audio-capabilities))
(defn app.pcm-bytes (ticks) (sd.render-event-pcm ticks))
(defn app.wav-bytes (ticks) (sd.render-event-wav ticks))

(defn app.render-persistent ()
  (begin
    (if (= wl.application-phase wl.APP-PLAYING) (wl.update-sound-loc) nil)
    (if (= app.fizzle-pending 1)
        (app.fizzle-advance false 0)
        (wl.three-d-refresh app.frame-buffer))
    true))

;;; Allocate every render-owned bytevector before a host transient render
;;; arena. A merely reserved fizzle state is DONE, so preallocation does not
;;; request or advance a transition; the real request seam resets it later.
(defn app.ensure-render-owned-storage ()
  (begin
    (wl.ensure-fizzle-target)
    (if (nil? wl.fizzle-state)
        (begin (set! wl.fizzle-state (bytes.alloc vh.FIZZLE-STATE-BYTES))
               (u8! wl.fizzle-state vh.FIZZLE-DONE 1)) nil)
    (and (= (bytes.length wl.fizzle-target) (* wl.SCREENWIDTH wl.SCREENHEIGHT))
         (= (bytes.length wl.fizzle-state) vh.FIZZLE-STATE-BYTES))))

(defn app.frame-export () app.frame-buffer)
(defn app.render ()
  ;; Any bytevector that can survive a frame is allocated before the transient
  ;; render mark. The frame itself is also pre-mark storage and remains valid
  ;; after the interpreter's wall/actor/overlay call frames are released.
  (if (app.ensure-render-owned-storage)
      (app.render-marked (heap.used))
      false))

(defn app.render-marked (mark)
  (let ((rendered (app.render-persistent)))
    (begin
      (heap.release mark)
      (if rendered (app.frame-export) false))))

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
