(define wl.MAXACTORS 150)
(define wl.ICONARROWS 90)
(define wl.SPDPATROL 512)
(define wl.SPDDOG 1500)
(define wl.ACTOR-STAND 255)
(define wl.ACTOR-CHASE 100)
(define wl.ACTOR-SHOOT 110)
(define wl.ACTOR-SHOOT2 111)
(define wl.ACTOR-SHOOT3 112)

(define wl.actorcount 0)
(define wl.actorx (bytes.alloc 600))
(define wl.actory (bytes.alloc 600))
(define wl.actordistance (bytes.alloc 600))
(define wl.actortilex (bytes.alloc 150))
(define wl.actortiley (bytes.alloc 150))
(define wl.actordir (bytes.alloc 150))
(define wl.actorclass (bytes.alloc 150))
(define wl.actoractive (bytes.alloc 150))
(define wl.actorphase (bytes.alloc 150))
(define wl.actorflags (bytes.alloc 150))
(define wl.actorarea (bytes.alloc 150))
(define wl.actorticcount (bytes.alloc 300))
(define wl.actorspeed (bytes.alloc 300))
(define wl.actorhitpoints (bytes.alloc 300))
(define wl.actortemp2 (bytes.alloc 300))
(define wl.actoraux (bytes.alloc 900))
(define wl.actorviewx (bytes.alloc 600))
(define wl.actortransx (bytes.alloc 600))
(define wl.actorat (bytes.alloc 4096))
(define wl.spotvis (bytes.alloc 4096))

(defn wl.actor-x@ (actor) (i32@ wl.actorx (* actor 4)))
(defn wl.actor-x! (actor value) (u32! wl.actorx (* actor 4) value))
(defn wl.actor-y@ (actor) (i32@ wl.actory (* actor 4)))
(defn wl.actor-y! (actor value) (u32! wl.actory (* actor 4) value))
(defn wl.actor-distance@ (actor) (i32@ wl.actordistance (* actor 4)))
(defn wl.actor-distance! (actor value) (u32! wl.actordistance (* actor 4) value))
(defn wl.actor-tilex@ (actor) (u8@ wl.actortilex actor))
(defn wl.actor-tilex! (actor value) (u8! wl.actortilex actor value))
(defn wl.actor-tiley@ (actor) (u8@ wl.actortiley actor))
(defn wl.actor-tiley! (actor value) (u8! wl.actortiley actor value))
(defn wl.actor-dir@ (actor) (u8@ wl.actordir actor))
(defn wl.actor-dir! (actor value) (u8! wl.actordir actor value))
(defn wl.actor-class@ (actor) (u8@ wl.actorclass actor))
(defn wl.actor-active@ (actor) (u8@ wl.actoractive actor))
(defn wl.actor-active! (actor value) (u8! wl.actoractive actor value))
(defn wl.actor-phase@ (actor) (u8@ wl.actorphase actor))
(defn wl.actor-phase! (actor value) (u8! wl.actorphase actor value))
(defn wl.actor-flags@ (actor) (u8@ wl.actorflags actor))
(defn wl.actor-flags! (actor value) (u8! wl.actorflags actor value))
(defn wl.actor-area@ (actor) (u8@ wl.actorarea actor))
(defn wl.actor-area! (actor value) (u8! wl.actorarea actor value))
(defn wl.actor-ticcount@ (actor) (u16@ wl.actorticcount (* actor 2)))
(defn wl.actor-ticcount! (actor value) (u16! wl.actorticcount (* actor 2) value))
(defn wl.actor-speed@ (actor) (u16@ wl.actorspeed (* actor 2)))
(defn wl.actor-hitpoints@ (actor) (i16@ wl.actorhitpoints (* actor 2)))
(defn wl.actor-hitpoints! (actor value) (u16! wl.actorhitpoints (* actor 2) value))
(defn wl.actor-temp2@ (actor) (u16@ wl.actortemp2 (* actor 2)))
(defn wl.actor-temp2! (actor value) (u16! wl.actortemp2 (* actor 2) value))
(defn wl.actor-angle@ (actor) (i16@ wl.actoraux (* actor 6)))
(defn wl.actor-angle! (actor value) (u16! wl.actoraux (* actor 6) value))
(defn wl.actor-temp1@ (actor) (i16@ wl.actoraux (+ (* actor 6) 2)))
(defn wl.actor-temp1! (actor value) (u16! wl.actoraux (+ (* actor 6) 2) value))
(defn wl.actor-temp3@ (actor) (i16@ wl.actoraux (+ (* actor 6) 4)))
(defn wl.actor-temp3! (actor value) (u16! wl.actoraux (+ (* actor 6) 4) value))
(defn wl.actor-aux-zero! (actor)
  (begin (wl.actor-angle! actor 0) (wl.actor-temp1! actor 0) (wl.actor-temp3! actor 0)))
(defn wl.actor-viewx@ (actor) (i32@ wl.actorviewx (* actor 4)))
(defn wl.actor-viewx! (actor value) (u32! wl.actorviewx (* actor 4) value))
(defn wl.actor-transx@ (actor) (i32@ wl.actortransx (* actor 4)))
(defn wl.actor-transx! (actor value) (u32! wl.actortransx (* actor 4) value))
(defn wl.actorat@ (x y) (u8@ wl.actorat (+ (bit.shl x wl.MAPSHIFT) y)))
(defn wl.actorat! (x y owner) (u8! wl.actorat (+ (bit.shl x wl.MAPSHIFT) y) owner))

(define wl.rndtable
  '(0 8 109 220 222 241 149 107 75 248 254 140 16 66
    74 21 211 47 80 242 154 27 205 128 161 89 77 36
    95 110 85 48 212 140 211 249 22 79 200 50 28 188
    52 140 202 120 68 145 62 70 184 190 91 197 152 224
    149 104 25 178 252 182 202 182 141 197 4 81 181 242
    145 42 39 227 156 198 225 193 219 93 122 175 249 0
    175 143 70 239 46 246 163 53 163 109 168 135 2 235
    25 92 20 145 138 77 69 166 78 176 173 212 166 113
    94 161 41 50 239 49 111 164 70 60 2 37 171 75
    136 156 11 56 42 146 138 229 73 146 77 61 98 196
    135 106 63 197 195 86 96 203 113 101 170 247 181 113
    80 250 108 7 255 237 129 226 79 107 112 166 103 241
    24 223 239 120 198 58 60 82 128 3 184 66 143 224
    145 224 81 206 163 45 63 90 168 114 59 33 159 95
    28 139 123 98 125 196 15 70 194 253 54 14 109 226
    71 17 161 93 186 87 244 138 20 52 123 251 26 36
    17 46 52 231 232 76 31 221 84 37 216 165 212 106
    197 242 98 43 39 175 254 145 190 84 118 222 187 136
    120 163 236 249))
(define wl.rndindex 0)

(defn wl.nth (values index)
  (if (= index 0) (car values) (wl.nth (cdr values) (- index 1))))

(defn wl.us-rndt ()
  (begin
    (set! wl.rndindex (bit.and (+ wl.rndindex 1) 255))
    (wl.nth wl.rndtable wl.rndindex)))

(defn wl.init-actors ()
  (begin
    (set! wl.actorcount 0)
    (set! wl.rndindex 0)
    (bytes.fill wl.actorat 0 4096 0)
    (bytes.fill wl.actoractive 0 150 0)
    (bytes.fill wl.actorphase 0 150 0)
    (bytes.fill wl.actorticcount 0 300 0)
    (bytes.fill wl.actorhitpoints 0 300 0)
    (bytes.fill wl.actortemp2 0 300 0)
    (bytes.fill wl.actoraux 0 900 0)))

(defn wl.enemy-dir-36 (tile base difficulty)
  (cond ((wl.in-four? tile base) (- tile base))
        ((and (>= difficulty 2) (wl.in-four? tile (+ base 36))) (- tile (+ base 36)))
        ((and (>= difficulty 3) (wl.in-four? tile (+ base 72))) (- tile (+ base 72)))
        (true -1)))

(defn wl.enemy-dir-18 (tile base difficulty)
  (cond ((wl.in-four? tile base) (- tile base))
        ((and (>= difficulty 2) (wl.in-four? tile (+ base 18))) (- tile (+ base 18)))
        ((and (>= difficulty 3) (wl.in-four? tile (+ base 36))) (- tile (+ base 36)))
        (true -1)))

(defn wl.spawn-info-actor (walls index tile)
  (let ((x (mod index wl.MAPSIZE)) (y (/ index wl.MAPSIZE)))
    (cond ((= tile 124) (begin (wl.spawn-dead-guard x y) false))
          ((>= (wl.enemy-dir-36 tile 112 wl.difficulty) 0)
           (wl.spawn-patrol x y (wl.enemy-dir-36 tile 112 wl.difficulty) 3 wl.SPDPATROL))
          ((>= (wl.enemy-dir-36 tile 120 wl.difficulty) 0)
           (wl.spawn-patrol x y (wl.enemy-dir-36 tile 120 wl.difficulty) 4 wl.SPDPATROL))
          ((>= (wl.enemy-dir-36 tile 130 wl.difficulty) 0)
           (wl.spawn-patrol x y (wl.enemy-dir-36 tile 130 wl.difficulty) 5 wl.SPDPATROL))
          ((>= (wl.enemy-dir-36 tile 138 wl.difficulty) 0)
           (wl.spawn-patrol x y (wl.enemy-dir-36 tile 138 wl.difficulty) 6 wl.SPDDOG))
          ((>= (wl.enemy-dir-18 tile 220 wl.difficulty) 0)
           (wl.spawn-patrol x y (wl.enemy-dir-18 tile 220 wl.difficulty) 11 wl.SPDPATROL))
          ((>= (wl.enemy-dir-36 tile 108 wl.difficulty) 0)
           (wl.spawn-standing walls index x y (wl.enemy-dir-36 tile 108 wl.difficulty) 3))
          ((>= (wl.enemy-dir-36 tile 116 wl.difficulty) 0)
           (wl.spawn-standing walls index x y (wl.enemy-dir-36 tile 116 wl.difficulty) 4))
          ((>= (wl.enemy-dir-36 tile 126 wl.difficulty) 0)
           (wl.spawn-standing walls index x y (wl.enemy-dir-36 tile 126 wl.difficulty) 5))
          ((>= (wl.enemy-dir-36 tile 134 wl.difficulty) 0)
           (wl.spawn-standing walls index x y (wl.enemy-dir-36 tile 134 wl.difficulty) 6))
          ((>= (wl.enemy-dir-18 tile 216 wl.difficulty) 0)
           (wl.spawn-standing walls index x y (wl.enemy-dir-18 tile 216 wl.difficulty) 11))
          ((or (= tile 160)
               (or (and (>= tile 178) (<= tile 179))
                   (or (and (>= tile 196) (<= tile 197))
                       (or (and (>= tile 214) (<= tile 215))
                           (and (>= tile 224) (<= tile 227)))))) true)
          (true nil))))

(defn wl.spawn-dead-guard (x y)
  (begin
    (wl.spawn-actor-base x y 8 2 0 1 wl.ACTOR-STAND 0)
    (wl.actorat! x y wl.actorcount)))

(defn wl.spawn-standing (walls index x y dir class)
  (let ((ambush (= (u16@ walls (* index 2)) wl.AMBUSHTILE)))
    (begin
      (if ambush (wl.remove-ambush-marker walls index) nil)
      (wl.spawn-actor-base x y (* dir 2) class wl.SPDPATROL 0 wl.ACTOR-STAND
                           (if ambush 65 1))
      (wl.actorat! x y wl.actorcount))))

(defn wl.spawn-patrol (x y dir class speed)
  (begin
    (wl.spawn-actor-base x y (* dir 2) class speed 1 0 1)
    (wl.actor-ticcount! (- wl.actorcount 1) (mod (wl.us-rndt) 20))
    (wl.patrol-destination (- wl.actorcount 1) dir)
    (wl.actorat! (wl.actor-tilex@ (- wl.actorcount 1))
                 (wl.actor-tiley@ (- wl.actorcount 1)) wl.actorcount)))

(defn wl.spawn-actor-base (x y dir class speed active phase flags)
  (if (= wl.actorcount wl.MAXACTORS)
      nil
      (let ((actor wl.actorcount))
        (begin
          (wl.actor-x! actor (+ (bit.shl x wl.TILESHIFT) (/ wl.TILEGLOBAL 2)))
          (wl.actor-y! actor (+ (bit.shl y wl.TILESHIFT) (/ wl.TILEGLOBAL 2)))
          (wl.actor-tilex! actor x)
          (wl.actor-tiley! actor y)
          (wl.actor-dir! actor dir)
          (u8! wl.actorclass actor class)
          (wl.actor-active! actor active)
          (wl.actor-phase! actor phase)
          (u8! wl.actorflags actor flags)
          (u16! wl.actorspeed (* actor 2) speed)
          (wl.actor-hitpoints! actor (wl.start-hitpoints class))
          (wl.actor-temp2! actor 0)
          (wl.actor-aux-zero! actor)
          (wl.actor-distance! actor (if (= phase wl.ACTOR-STAND) 0 wl.TILEGLOBAL))
          (wl.actor-area! actor (wl.area-at x y))
          (set! wl.actorcount (+ actor 1))))))

;; R1 states use class-specific sprite tables; phase is their compact identity.
(defn wl.actor-shape-base (class stand)
  (cond ((= class 3) (if stand 50 58)) ((= class 4) (if stand 238 246))
        ((= class 5) (if stand 138 146)) ((= class 6) 99)
        ((= class 11) (if stand 187 195)) (true 0)))

(defn wl.actor-shapenum (actor)
  (let ((class (wl.actor-class@ actor)) (phase (wl.actor-phase@ actor)))
    (cond ((= class 2) 95)
          ((= phase wl.ACTOR-STAND) (wl.actor-shape-base class true))
          ((and (= class 3) (>= phase wl.ACTOR-SHOOT)) (- phase 14))
          (true (wl.actor-walk-shape class (if (>= phase wl.ACTOR-CHASE)
                                               (- phase wl.ACTOR-CHASE) phase))))))

(defn wl.actor-walk-shape (class phase)
  (let ((base (wl.actor-shape-base class false)))
    (+ base (cond ((< phase 2) 0) ((= phase 2) 8)
                  ((< phase 5) 16) (true 24)))))

(defn wl.start-hitpoints (class)
  (cond ((= class 3) 25) ((= class 4) 50) ((= class 5) 100)
        ((= class 6) 1) ((= class 11) 55) (true 0)))

(defn wl.patrol-destination (actor dir)
  (cond ((= dir 0) (wl.actor-tilex! actor (+ (wl.actor-tilex@ actor) 1)))
        ((= dir 1) (wl.actor-tiley! actor (- (wl.actor-tiley@ actor) 1)))
        ((= dir 2) (wl.actor-tilex! actor (- (wl.actor-tilex@ actor) 1)))
        (true (wl.actor-tiley! actor (+ (wl.actor-tiley@ actor) 1)))))

(defn wl.area-at (x y)
  (let ((tile (u16@ wl.level-walls (* (+ (* y wl.MAPSIZE) x) 2))))
    (if (>= tile wl.AREATILE) (- tile wl.AREATILE) 0)))

(define wl.areaconnect (bytes.alloc 1369))
(define wl.areabyplayer (bytes.alloc 37))

(defn wl.area-connect@ (a b) (u8@ wl.areaconnect (+ (* a wl.NUMAREAS) b)))
(defn wl.area-connect! (a b value) (u8! wl.areaconnect (+ (* a wl.NUMAREAS) b) value))
(defn wl.area-active? (area) (> (u8@ wl.areabyplayer area) 0))

(defn wl.init-areas ()
  (begin
    (bytes.fill wl.areaconnect 0 1369 0)
    (wl.connect-areas)))

(defn wl.player-area ()
  (wl.area-at (wl.player@ wl.PLAYER-TILEX) (wl.player@ wl.PLAYER-TILEY)))

(defn wl.connect-areas ()
  (begin
    (bytes.fill wl.areabyplayer 0 wl.NUMAREAS 0)
    (u8! wl.areabyplayer (wl.player-area) 1)
    (wl.connect-area-from (wl.player-area) 0)))

(defn wl.connect-area-from (area candidate)
  (if (= candidate wl.NUMAREAS)
      nil
      (begin
        (if (and (> (wl.area-connect@ area candidate) 0)
                 (not (wl.area-active? candidate)))
            (begin (u8! wl.areabyplayer candidate 1)
                   (wl.connect-area-from candidate 0))
            nil)
        (wl.connect-area-from area (+ candidate 1)))))

(defn wl.door-area-pair (door)
  (let ((x (wl.door-x@ door)) (y (wl.door-y@ door)))
    (if (= (wl.door-vertical@ door) 1)
        (list (wl.area-at (+ x 1) y) (wl.area-at (- x 1) y))
        (list (wl.area-at x (- y 1)) (wl.area-at x (+ y 1))))))

(defn wl.change-door-area-connection (door delta)
  (let ((areas (wl.door-area-pair door)))
    (let ((a (car areas)) (b (car (cdr areas))))
      (begin
        (wl.area-connect! a b (+ (wl.area-connect@ a b) delta))
        (wl.area-connect! b a (+ (wl.area-connect@ b a) delta))
        (wl.connect-areas)))))


(define wl.FL-SHOOTABLE 1)
(define wl.FL-VISABLE 8)
(define wl.FL-ATTACKMODE 16)
(define wl.FL-FIRSTATTACK 32)
(define wl.FL-AMBUSH 64)
(define wl.madenoise 0)

(defn wl.abs (value) (if (< value 0) (- 0 value) value))

(defn wl.clamp-line-step (value)
  (cond ((> value 32767) 32767) ((< value -32767) -32767) (true value)))

(defn wl.line-solid? (x y intercept)
  (let ((value (wl.tilemap@ x y)))
    (cond ((= value 0) false)
          ((or (< value 128) (> value 256)) true)
          (true (> (bit.and intercept 65535)
                   (wl.door-position@ (bit.and value 127)))))))

(defn wl.check-line (fromx fromy tox toy)
  (let ((x1 (bit.shr fromx 8)) (y1 (bit.shr fromy 8))
        (x2 (bit.shr tox 8)) (y2 (bit.shr toy 8)))
    (and (wl.check-line-x x1 y1 x2 y2)
         (wl.check-line-y x1 y1 x2 y2))))

(defn wl.check-line-x (x1 y1 x2 y2)
  (let ((xt1 (bit.shr x1 8)) (xt2 (bit.shr x2 8)))
    (if (= xt1 xt2)
        true
        (let ((step (if (> xt2 xt1) 1 -1)))
          (let ((partial (if (= step 1) (- 256 (bit.and x1 255)) (bit.and x1 255)))
                (ystep (wl.clamp-line-step (/ (* (- y2 y1) 256) (wl.abs (- x2 x1))))))
            (wl.check-line-x-tiles (+ xt1 step) (+ xt2 step) step
              (+ y1 (bit.shr (* ystep partial) 8)) ystep))))))

(defn wl.check-line-x-tiles (x end step yfrac ystep)
  (if (= x end)
      true
      (let ((y (bit.shr yfrac 8)) (nextfrac (+ yfrac ystep)))
        (if (wl.line-solid? x y (- nextfrac (/ ystep 2)))
            false
            (wl.check-line-x-tiles (+ x step) end step nextfrac ystep)))))

(defn wl.check-line-y (x1 y1 x2 y2)
  (let ((yt1 (bit.shr y1 8)) (yt2 (bit.shr y2 8)))
    (if (= yt1 yt2)
        true
        (let ((step (if (> yt2 yt1) 1 -1)))
          (let ((partial (if (= step 1) (- 256 (bit.and y1 255)) (bit.and y1 255)))
                (xstep (wl.clamp-line-step (/ (* (- x2 x1) 256) (wl.abs (- y2 y1))))))
            (wl.check-line-y-tiles (+ yt1 step) (+ yt2 step) step
              (+ x1 (bit.shr (* xstep partial) 8)) xstep))))))

(defn wl.check-line-y-tiles (y end step xfrac xstep)
  (if (= y end)
      true
      (let ((x (bit.shr xfrac 8)) (nextfrac (+ xfrac xstep)))
        (if (wl.line-solid? x y (- nextfrac (/ xstep 2)))
            false
            (wl.check-line-y-tiles (+ y step) end step nextfrac xstep)))))

(defn wl.actor-check-line-player (actor)
  (wl.check-line (wl.actor-x@ actor) (wl.actor-y@ actor)
                 (wl.player@ wl.PLAYER-X) (wl.player@ wl.PLAYER-Y)))

(defn wl.actor-facing-player? (actor dx dy)
  (let ((dir (wl.actor-dir@ actor)))
    (or (and (and (> dx -98304) (< dx 98304))
             (and (> dy -98304) (< dy 98304)))
        (and (and (or (not (= dir 2)) (<= dy 0))
                  (or (not (= dir 0)) (>= dx 0)))
             (and (or (not (= dir 6)) (>= dy 0))
                  (or (not (= dir 4)) (<= dx 0)))))))

(defn wl.sight-player (actor)
  (if (> (bit.and (wl.actor-flags@ actor) wl.FL-ATTACKMODE) 0)
      false
      (if (> (wl.actor-temp2@ actor) 0)
          (begin
            (wl.actor-temp2! actor (- (wl.actor-temp2@ actor) wl.tics))
            (if (> (wl.actor-temp2@ actor) 0)
                false
                (begin
                  (wl.actor-temp2! actor 0)
                  (wl.actor-phase! actor wl.ACTOR-CHASE)
                  (wl.actor-ticcount! actor 10)
                  (u16! wl.actorspeed (* actor 2) (* (wl.actor-speed@ actor) 3))
                  (wl.actor-flags! actor
                    (bit.or (wl.actor-flags@ actor)
                            (bit.or wl.FL-ATTACKMODE wl.FL-FIRSTATTACK)))
                  true)))
          (if (not (wl.area-active? (wl.actor-area@ actor)))
              false
              (wl.sight-player-test actor
                (- (wl.player@ wl.PLAYER-X) (wl.actor-x@ actor))
                (- (wl.player@ wl.PLAYER-Y) (wl.actor-y@ actor)))))))

(defn wl.sight-player-test (actor dx dy)
  (let ((visible (and (wl.actor-facing-player? actor dx dy)
                      (wl.actor-check-line-player actor))))
    (if (and (> (bit.and (wl.actor-flags@ actor) wl.FL-AMBUSH) 0) (not visible))
        false
        (if (and (= wl.madenoise 0) (not visible))
            false
            (begin
              (if (> (bit.and (wl.actor-flags@ actor) wl.FL-AMBUSH) 0)
                  (wl.actor-flags! actor
                    (bit.and (wl.actor-flags@ actor) (- 255 wl.FL-AMBUSH))) nil)
              (wl.actor-temp2! actor (wl.reaction-delay actor))
              false)))))

(defn wl.reaction-delay (actor)
  (let ((class (wl.actor-class@ actor)))
    (cond ((= class 3) (+ 1 (/ (wl.us-rndt) 4)))
          ((= class 4) 2)
          ((or (= class 5) (= class 11)) (+ 1 (/ (wl.us-rndt) 6)))
          ((= class 6) (+ 1 (/ (wl.us-rndt) 8)))
          (true 1))))

(defn wl.spotvis-vert! (xtile yintercept)
  (u8! wl.spotvis (+ (bit.shl xtile wl.MAPSHIFT) (bit.shr yintercept 16)) 1))

(defn wl.spotvis-horiz! (ytile xintercept)
  (u8! wl.spotvis (+ (bit.shl (bit.shr xintercept 16) 6) ytile) 1))

(defn wl.spotvis-neighbor? (spot offset)
  (and (> (u8@ wl.spotvis (+ spot offset)) 0)
       (= (u8@ wl.tilemap (+ spot offset)) 0)))

(defn wl.actor-spot-visible? (actor)
  (let ((spot (+ (bit.shl (wl.actor-tilex@ actor) wl.MAPSHIFT)
                 (wl.actor-tiley@ actor))))
    (or (> (u8@ wl.spotvis spot) 0)
        (or (wl.spotvis-neighbor? spot -1) (wl.spotvis-neighbor? spot 1)
            (or (wl.spotvis-neighbor? spot -65) (wl.spotvis-neighbor? spot -64)
                (or (wl.spotvis-neighbor? spot -63) (wl.spotvis-neighbor? spot 65)
                    (or (wl.spotvis-neighbor? spot 64)
                        (wl.spotvis-neighbor? spot 63))))))))

(defn wl.transform-actor (actor)
  (let ((gx (- (wl.actor-x@ actor) (wl.view@ wl.VIEWX)))
        (gy (- (wl.actor-y@ actor) (wl.view@ wl.VIEWY))))
    (let ((nx (- (- (fx.by-frac gx (wl.view@ wl.VIEWCOS))
                       (fx.by-frac gy (wl.view@ wl.VIEWSIN))) 16384))
          (ny (+ (fx.by-frac gy (wl.view@ wl.VIEWCOS))
                 (fx.by-frac gx (wl.view@ wl.VIEWSIN)))))
      (begin (wl.actor-transx! actor nx)
        (if (>= nx wl.MINDIST)
            (begin (wl.actor-viewx! actor (+ 159 (/ (* ny wl.scale) nx))) true)
            false)))))

(defn wl.refresh-actor-visibility ()
  (begin (bytes.fill wl.spotvis 0 4096 0) (wl.calc-view) (wl.asm-refresh)
         (wl.refresh-actor-projection 0)))

(defn wl.refresh-actor-projection (actor)
  (if (= actor wl.actorcount)
      nil
      (begin
        (if (wl.actor-spot-visible? actor)
            (begin
              (wl.actor-active! actor 1)
              (if (wl.transform-actor actor)
                  (wl.actor-flags! actor
                    (bit.or (wl.actor-flags@ actor) wl.FL-VISABLE))
                  nil))
            (wl.actor-flags! actor
              (bit.and (wl.actor-flags@ actor) (- 255 wl.FL-VISABLE))))
        (wl.refresh-actor-projection (+ actor 1)))))

(defn wl.move-actors () (wl.move-actor-number 0))

(defn wl.move-actor-number (actor)
  (if (= actor wl.actorcount)
      nil
      (begin (wl.do-actor actor) (wl.move-actor-number (+ actor 1)))))

(defn wl.do-actor (actor)
  (if (and (= (wl.actor-active@ actor) 0) (not (wl.area-active? (wl.actor-area@ actor))))
      nil
      (begin
        (wl.actorat-clear-owner actor)
        (cond ((= (wl.actor-phase@ actor) wl.ACTOR-STAND)
               (if (> (wl.actor-hitpoints@ actor) 0) (wl.sight-player actor) nil))
              ((>= (wl.actor-phase@ actor) wl.ACTOR-SHOOT) (wl.do-shoot-state actor))
              ((>= (wl.actor-phase@ actor) wl.ACTOR-CHASE) (wl.do-chase-state actor))
              (true (wl.do-patrol-state actor)))
        (wl.actorat! (wl.actor-tilex@ actor) (wl.actor-tiley@ actor) (+ actor 1)))))

(defn wl.actorat-clear-owner (actor)
  (let ((x (wl.actor-tilex@ actor)) (y (wl.actor-tiley@ actor)))
    (if (= (wl.actorat@ x y) (+ actor 1)) (wl.actorat! x y 0) nil)))

(defn wl.do-chase-state (actor)
  (if (= (wl.actor-ticcount@ actor) 0)
      (if (wl.chase-phase-thinks? (wl.actor-phase@ actor)) (wl.t-chase actor) nil)
      (begin
        (wl.actor-ticcount! actor (- (wl.actor-ticcount@ actor) wl.tics))
        (wl.advance-chase-state actor)
        (if (wl.chase-phase-thinks? (wl.actor-phase@ actor)) (wl.t-chase actor) nil))))

(defn wl.advance-chase-state (actor)
  (if (> (wl.actor-ticcount@ actor) 0)
      nil
      (let ((phase (+ wl.ACTOR-CHASE (mod (+ (- (wl.actor-phase@ actor) wl.ACTOR-CHASE) 1) 6))))
        (begin
          (wl.actor-phase! actor phase)
          (wl.actor-ticcount! actor (+ (wl.actor-ticcount@ actor) (wl.chase-phase-time phase)))
          (wl.advance-chase-state actor)))))

(defn wl.chase-phase-time (phase)
  (let ((p (- phase wl.ACTOR-CHASE)))
    (cond ((or (= p 0) (= p 3)) 10) ((or (= p 1) (= p 4)) 3) (true 8))))

(defn wl.chase-phase-thinks? (phase)
  (let ((p (- phase wl.ACTOR-CHASE)))
    (or (or (= p 0) (= p 2)) (or (= p 3) (= p 5)))))

(defn wl.do-shoot-state (actor)
  (if (not (= (wl.actor-class@ actor) 3))
      nil
      (begin
        (wl.actor-ticcount! actor (- (wl.actor-ticcount@ actor) wl.tics))
        (wl.advance-shoot-state actor))))

(defn wl.advance-shoot-state (actor)
  (if (> (wl.actor-ticcount@ actor) 0)
      nil
      (let ((phase (wl.actor-phase@ actor)))
        (begin
          (if (= phase wl.ACTOR-SHOOT2) (wl.t-shoot actor) nil)
          (cond ((= phase wl.ACTOR-SHOOT)
                 (begin (wl.actor-phase! actor wl.ACTOR-SHOOT2)
                        (wl.actor-ticcount! actor (+ (wl.actor-ticcount@ actor) 20))))
                ((= phase wl.ACTOR-SHOOT2)
                 (begin (wl.actor-phase! actor wl.ACTOR-SHOOT3)
                        (wl.actor-ticcount! actor (+ (wl.actor-ticcount@ actor) 20))))
                (true
                 (begin (wl.actor-phase! actor wl.ACTOR-CHASE)
                        (wl.actor-ticcount! actor (+ (wl.actor-ticcount@ actor) 10))
                        (wl.t-chase actor))))
          (if (<= (wl.actor-ticcount@ actor) 0) (wl.advance-shoot-state actor) nil)))))

(defn wl.t-shoot (actor)
  (if (not (wl.area-active? (wl.actor-area@ actor)))
      false
      (if (not (wl.actor-check-line-player actor))
          false
          (let ((distance
                  (wl.max (wl.abs (- (wl.actor-tilex@ actor) (wl.player@ wl.PLAYER-TILEX)))
                          (wl.abs (- (wl.actor-tiley@ actor) (wl.player@ wl.PLAYER-TILEY))))))
            (let ((hitchance
                    (- (if (>= wl.thrustspeed 6000) 160 256)
                       (* distance (if (> (bit.and (wl.actor-flags@ actor) wl.FL-VISABLE) 0) 16 8)))))
              (if (< (wl.us-rndt) hitchance)
                  (wl.take-damage
                    (let ((roll (wl.us-rndt)))
                      (cond ((< distance 2) (bit.shr roll 2))
                            ((< distance 4) (bit.shr roll 3))
                            (true (bit.shr roll 4)))))
                  false))))))

(defn wl.take-damage (points)
  (let ((damage (if (= wl.difficulty 0) (bit.shr points 2) points)))
    (begin
      (set! wl.health (wl.max 0 (- wl.health damage)))
      true)))

(defn wl.t-chase (actor)
  (let ((line (wl.actor-check-line-player actor)))
    (if line
        (let ((distance (wl.max (wl.abs (- (wl.actor-tilex@ actor) (wl.player@ wl.PLAYER-TILEX)))
                                (wl.abs (- (wl.actor-tiley@ actor) (wl.player@ wl.PLAYER-TILEY))))))
          (let ((chance (if (or (= distance 0)
                                (and (= distance 1) (< (wl.actor-distance@ actor) 16384)))
                            300 (/ (bit.shl wl.tics 4) distance))))
            (if (< (wl.us-rndt) chance)
                (begin
                  (wl.actor-phase! actor wl.ACTOR-SHOOT)
                  (wl.actor-ticcount! actor 20))
                (wl.chase-move actor (* (wl.actor-speed@ actor) wl.tics) true))))
        (wl.chase-move actor (* (wl.actor-speed@ actor) wl.tics) false))))

(defn wl.chase-move (actor move dodge)
  (if (= move 0)
      nil
      (if (< (wl.actor-distance@ actor) 0)
          (let ((door (- 0 (wl.actor-distance@ actor) 1)))
            (begin
              (wl.open-door door)
              (if (= (wl.door-action@ door) wl.DR-OPEN)
                  (begin (wl.actor-distance! actor wl.TILEGLOBAL)
                         (wl.chase-move actor move dodge)) nil)))
          (if (< move (wl.actor-distance@ actor))
              (wl.move-obj actor move)
              (let ((remaining (- move (wl.actor-distance@ actor))))
                (begin
                  (wl.actor-x! actor (+ (bit.shl (wl.actor-tilex@ actor) wl.TILESHIFT) 32768))
                  (wl.actor-y! actor (+ (bit.shl (wl.actor-tiley@ actor) wl.TILESHIFT) 32768))
                  (if dodge (wl.select-dodge-dir actor) (wl.select-chase-dir actor))
                  (if (= (wl.actor-dir@ actor) 8) nil
                      (wl.chase-move actor remaining dodge))))))))

(defn wl.opposite-dir (dir) (if (= dir 8) 8 (mod (+ dir 4) 8)))

(defn wl.toward-x (delta) (cond ((> delta 0) 0) ((< delta 0) 4) (true 8)))
(defn wl.toward-y (delta) (cond ((> delta 0) 6) ((< delta 0) 2) (true 8)))

(defn wl.select-chase-dir (actor)
  (let ((old (wl.actor-dir@ actor))
        (dx (- (wl.player@ wl.PLAYER-TILEX) (wl.actor-tilex@ actor)))
        (dy (- (wl.player@ wl.PLAYER-TILEY) (wl.actor-tiley@ actor))))
    (let ((xdir (wl.toward-x dx)) (ydir (wl.toward-y dy)) (turn (wl.opposite-dir old)))
      (if (> (wl.abs dy) (wl.abs dx))
          (wl.select-chase-tries actor ydir xdir old turn)
          (wl.select-chase-tries actor xdir ydir old turn)))))

(defn wl.select-chase-tries (actor first second old turn)
  (if (wl.try-chase-dir actor (if (= first turn) 8 first))
      true
      (if (wl.try-chase-dir actor (if (= second turn) 8 second))
          true
          (if (wl.try-chase-dir actor old)
              true
              (if (> (wl.us-rndt) 128)
                  (wl.select-chase-search actor turn 2 1)
                  (wl.select-chase-search actor turn 4 -1))))))

(defn wl.try-chase-dir (actor dir)
  (if (= dir 8) false
      (begin (wl.actor-dir! actor dir) (wl.try-walk actor))))

(defn wl.select-chase-search (actor turn dir step)
  (if (if (= step 1) (> dir 4) (< dir 2))
      (if (wl.try-chase-dir actor turn) true (begin (wl.actor-dir! actor 8) false))
      (if (and (not (= dir turn)) (wl.try-chase-dir actor dir))
          true
          (wl.select-chase-search actor turn (+ dir step) step))))

(defn wl.diagonal-dir (xdir ydir)
  (cond ((and (= xdir 0) (= ydir 2)) 1)
        ((and (= xdir 4) (= ydir 2)) 3)
        ((and (= xdir 4) (= ydir 6)) 5)
        ((and (= xdir 0) (= ydir 6)) 7)
        (true 8)))

(defn wl.select-dodge-dir (actor)
  (let ((first (> (bit.and (wl.actor-flags@ actor) wl.FL-FIRSTATTACK) 0))
        (dx (- (wl.player@ wl.PLAYER-TILEX) (wl.actor-tilex@ actor)))
        (dy (- (wl.player@ wl.PLAYER-TILEY) (wl.actor-tiley@ actor))))
    (begin
      (if first (wl.actor-flags! actor (bit.and (wl.actor-flags@ actor) 223)) nil)
      (wl.select-dodge-order actor (if first 8 (wl.opposite-dir (wl.actor-dir@ actor)))
        (if (> dx 0) 0 4) (if (> dy 0) 6 2) dx dy))))

(defn wl.select-dodge-order (actor turn xdir ydir dx dy)
  (let ((first (if (> (wl.abs dx) (wl.abs dy)) ydir xdir))
        (second (if (> (wl.abs dx) (wl.abs dy)) xdir ydir)))
    (if (< (wl.us-rndt) 128)
        (wl.select-dodge-tries actor turn second first)
        (wl.select-dodge-tries actor turn first second))))

(defn wl.select-dodge-tries (actor turn first second)
  (let ((third (wl.opposite-dir first)) (fourth (wl.opposite-dir second)))
    (if (wl.try-dir-list actor turn
          (list (wl.diagonal-dir first second) first second third fourth))
        true
        (if (wl.try-chase-dir actor turn) true (begin (wl.actor-dir! actor 8) false)))))

(defn wl.try-dir-list (actor turn dirs)
  (if (nil? dirs)
      false
      (if (and (not (= (car dirs) turn)) (wl.try-chase-dir actor (car dirs)))
          true
          (wl.try-dir-list actor turn (cdr dirs)))))

(defn wl.do-patrol-state (actor)
  (if (= (wl.actor-ticcount@ actor) 0)
      (if (wl.path-phase-thinks? (wl.actor-phase@ actor)) (wl.t-path actor) nil)
      (begin
        (wl.actor-ticcount! actor (- (wl.actor-ticcount@ actor) wl.tics))
        (wl.advance-path-state actor)
        (if (wl.path-phase-thinks? (wl.actor-phase@ actor)) (wl.t-path actor) nil))))

(defn wl.advance-path-state (actor)
  (if (> (wl.actor-ticcount@ actor) 0)
      nil
      (let ((phase (mod (+ (wl.actor-phase@ actor) 1) 6)))
        (begin
          (wl.actor-phase! actor phase)
          (wl.actor-ticcount! actor (+ (wl.actor-ticcount@ actor) (wl.path-phase-time phase)))
          (wl.advance-path-state actor)))))

(defn wl.path-phase-time (phase)
  (cond ((= phase 0) 20) ((= phase 1) 5) ((= phase 2) 15)
        ((= phase 3) 20) ((= phase 4) 5) (true 15)))

(defn wl.path-phase-thinks? (phase)
  (or (or (= phase 0) (= phase 2)) (or (= phase 3) (= phase 5))))

(defn wl.t-path (actor)
  (if (wl.sight-player actor)
      nil
      (if (= (wl.actor-dir@ actor) 8)
          (wl.select-path-dir actor)
          (wl.t-path-move actor (* (wl.actor-speed@ actor) wl.tics)))))

(defn wl.t-path-move (actor move)
  (if (= move 0)
      nil
      (if (< (wl.actor-distance@ actor) 0)
          (wl.t-path-door actor move (- 0 (wl.actor-distance@ actor) 1))
          (if (< move (wl.actor-distance@ actor))
              (wl.move-obj actor move)
              (wl.t-path-cross actor move)))))

(defn wl.t-path-door (actor move door)
  (begin
    (wl.open-door door)
    (if (= (wl.door-action@ door) wl.DR-OPEN)
        (begin (wl.actor-distance! actor wl.TILEGLOBAL) (wl.t-path-move actor move))
        nil)))

(defn wl.t-path-cross (actor move)
  (let ((remaining (- move (wl.actor-distance@ actor))))
    (begin
      (wl.actor-x! actor (+ (bit.shl (wl.actor-tilex@ actor) wl.TILESHIFT) (/ wl.TILEGLOBAL 2)))
      (wl.actor-y! actor (+ (bit.shl (wl.actor-tiley@ actor) wl.TILESHIFT) (/ wl.TILEGLOBAL 2)))
      (wl.select-path-dir actor)
      (if (= (wl.actor-dir@ actor) 8) nil (wl.t-path-move actor remaining)))))

(defn wl.select-path-dir (actor)
  (let ((spot (- (u16@ wl.level-objects
                         (* (+ (* (wl.actor-tiley@ actor) wl.MAPSIZE)
                               (wl.actor-tilex@ actor)) 2))
                 wl.ICONARROWS)))
    (begin
      (if (and (>= spot 0) (< spot 8)) (wl.actor-dir! actor spot) nil)
      (wl.actor-distance! actor wl.TILEGLOBAL)
      (if (not (wl.try-walk actor)) (wl.actor-dir! actor 8) nil))))

(defn wl.try-walk (actor)
  (let ((dir (wl.actor-dir@ actor))
        (x (wl.actor-tilex@ actor)) (y (wl.actor-tiley@ actor)))
    (wl.try-walk-destination actor dir x y
      (+ x (cond ((or (= dir 0) (= dir 1)) 1)
                 ((or (= dir 3) (= dir 4) (= dir 5)) -1)
                 ((= dir 7) 1) (true 0)))
      (+ y (cond ((or (= dir 1) (= dir 2) (= dir 3)) -1)
                 ((or (= dir 5) (= dir 6) (= dir 7)) 1) (true 0))))))

(defn wl.try-walk-destination (actor dir oldx oldy x y)
  (let ((tile (wl.tilemap@ x y)))
    (if (or (and (> tile 0) (not (wl.door-tile? tile)))
            (> (wl.actorat@ x y) 0))
        false
        (begin
          (wl.actor-tilex! actor x)
          (wl.actor-tiley! actor y)
          (if (wl.door-tile? tile)
              (begin
                (wl.open-door (wl.door-number tile))
                (wl.actor-distance! actor (- 0 (wl.door-number tile) 1)))
              (begin
                (wl.actor-area! actor (wl.area-at x y))
                (wl.actor-distance! actor wl.TILEGLOBAL)))
          true))))

(defn wl.move-obj (actor move)
  (let ((dir (wl.actor-dir@ actor)))
    (begin
      (cond ((= dir 0) (wl.actor-x! actor (+ (wl.actor-x@ actor) move)))
            ((= dir 1) (begin (wl.actor-x! actor (+ (wl.actor-x@ actor) move))
                              (wl.actor-y! actor (- (wl.actor-y@ actor) move))))
            ((= dir 2) (wl.actor-y! actor (- (wl.actor-y@ actor) move)))
            ((= dir 3) (begin (wl.actor-x! actor (- (wl.actor-x@ actor) move))
                              (wl.actor-y! actor (- (wl.actor-y@ actor) move))))
            ((= dir 4) (wl.actor-x! actor (- (wl.actor-x@ actor) move)))
            ((= dir 5) (begin (wl.actor-x! actor (- (wl.actor-x@ actor) move))
                              (wl.actor-y! actor (+ (wl.actor-y@ actor) move))))
            ((= dir 6) (wl.actor-y! actor (+ (wl.actor-y@ actor) move)))
            ((= dir 7) (begin (wl.actor-x! actor (+ (wl.actor-x@ actor) move))
                              (wl.actor-y! actor (+ (wl.actor-y@ actor) move))))
            (true nil))
      (wl.actor-distance! actor (- (wl.actor-distance@ actor) move)))))

(defn wl.actor-blocks-door? (door)
  (let ((x (wl.door-x@ door)) (y (wl.door-y@ door)))
    (or (> (wl.actorat@ x y) 0)
        (if (= (wl.door-vertical@ door) 1)
            (or (wl.actor-crosses-vertical? (wl.actorat@ (- x 1) y) x 1)
                (wl.actor-crosses-vertical? (wl.actorat@ (+ x 1) y) x -1))
            (or (wl.actor-crosses-horizontal? (wl.actorat@ x (- y 1)) y 1)
                (wl.actor-crosses-horizontal? (wl.actorat@ x (+ y 1)) y -1))))))

(defn wl.actor-crosses-vertical? (owner tilex sign)
  (if (= owner 0) false
      (= (bit.shr (+ (wl.actor-x@ (- owner 1)) (* sign wl.MINDIST)) wl.TILESHIFT) tilex)))

(defn wl.actor-crosses-horizontal? (owner tiley sign)
  (if (= owner 0) false
      (= (bit.shr (+ (wl.actor-y@ (- owner 1)) (* sign wl.MINDIST)) wl.TILESHIFT) tiley)))
