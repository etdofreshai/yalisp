(define wl.MAXACTORS 150)
(define wl.ICONARROWS 90)
(define wl.SPDPATROL 512)
(define wl.SPDDOG 1500)
(define wl.ACTOR-STAND 255)
(define wl.ACTOR-CHASE 100)
(define wl.ACTOR-SHOOT 110)
(define wl.ACTOR-SHOOT2 111)
(define wl.ACTOR-SHOOT3 112)
(define wl.ACTOR-PAIN 180)
(define wl.ACTOR-DYING 200)
(define wl.ACTOR-PROJECTILE 220)
(define wl.ACTOR-DEAD 230)
(define wl.NEEDLEOBJ 12)
(define wl.FIREOBJ 13)
(define wl.REALHITLEROBJ 16)
(define wl.ROCKETOBJ 20)
(define wl.PROJECTILESPEED 8192)
(define wl.PROJECTILESIZE 49152)
(define wl.PROJSIZE 8192)
(define wl.MINACTORDIST 65536)
(define wl.FL-NONMARK 128)
(define wl.PLAYER-DEATHCAM-STATE 1)
(define wl.DEATHCAM-IDLE 0)
(define wl.DEATHCAM-ACTIVE 1)
(define wl.DEATHCAM-MAX-SEARCH-STEPS 256)
(define wl.deathcam-active 0)
(define wl.deathcam-phase wl.DEATHCAM-IDLE)
(define wl.killx 0)
(define wl.killy 0)
(define wl.death-action-count 0)

;;; WL_DEF.H classtype values used by the Wolf3D boss/ghost spawners.
(define wl.GUARDOBJ 3)
(define wl.OFFICEROBJ 4)
(define wl.SSOBJ 5)
(define wl.DOGOBJ 6)
(define wl.BOSSOBJ 7)
(define wl.SCHABBOBJ 8)
(define wl.FAKEOBJ 9)
(define wl.MECHAHITLEROBJ 10)
(define wl.MUTANTOBJ 11)
(define wl.GHOSTOBJ 15)
(define wl.GRETELOBJ 17)
(define wl.GIFTOBJ 18)
(define wl.FATOBJ 19)

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
(define wl.actorviewheight (bytes.alloc 300))
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
(defn wl.actor-phase-raw@ (actor) (u8@ wl.actorphase actor))
(defn wl.actor-phase@ (actor)
  (let ((phase (wl.actor-phase-raw@ actor)))
    ;; The compact byte stores source state ordinals for multi-frame families.
    ;; Public phase identity remains stable while save/load retains progress.
    (cond ((and (> phase wl.ACTOR-SHOOT2) (< phase wl.ACTOR-PAIN)) wl.ACTOR-SHOOT3)
          ((= phase (+ wl.ACTOR-PAIN 1)) wl.ACTOR-PAIN)
          ((and (> phase wl.ACTOR-DYING) (< phase (+ wl.ACTOR-DYING 10))) wl.ACTOR-DYING)
          (true phase))))
(defn wl.actor-phase! (actor value) (u8! wl.actorphase actor value))
(defn wl.actor-flags@ (actor) (u8@ wl.actorflags actor))
(defn wl.actor-flags! (actor value) (u8! wl.actorflags actor value))
(defn wl.actor-area@ (actor) (u8@ wl.actorarea actor))
(defn wl.actor-area! (actor value) (u8! wl.actorarea actor value))
(defn wl.actor-ticcount@ (actor) (i16@ wl.actorticcount (* actor 2)))
(defn wl.actor-ticcount! (actor value) (u16! wl.actorticcount (* actor 2) value))
(defn wl.actor-speed@ (actor) (u16@ wl.actorspeed (* actor 2)))
(defn wl.actor-hitpoints@ (actor) (i16@ wl.actorhitpoints (* actor 2)))
(defn wl.actor-hitpoints! (actor value) (u16! wl.actorhitpoints (* actor 2) value))
(defn wl.actor-temp2@ (actor) (i16@ wl.actortemp2 (* actor 2)))
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
(defn wl.actor-viewheight@ (actor) (u16@ wl.actorviewheight (* actor 2)))
(defn wl.actor-viewheight! (actor value) (u16! wl.actorviewheight (* actor 2) value))
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
          ;; WL_GAME.C's non-SPEAR object-plane boss assignments.
          ((= tile 160) (wl.spawn-fake-hitler x y))
          ((= tile 178) (wl.spawn-hitler x y))
          ((= tile 179) (wl.spawn-fat x y))
          ((= tile 196) (wl.spawn-schabbs x y))
          ((= tile 197) (wl.spawn-gretel x y))
          ((= tile 214) (wl.spawn-boss x y))
          ((= tile 215) (wl.spawn-gift x y))
          ((and (>= tile 224) (<= tile 227))
           (wl.spawn-ghost (- tile 224) x y))
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

;;; These preserve SpawnBoss/SpawnGretel/SpawnSchabbs/SpawnGift/SpawnFat,
;;; SpawnFakeHitler, SpawnHitler, and SpawnGhosts. SetupGameLevel owns the
;;; killtotal increment after a successful object-plane spawn.
(defn wl.spawn-boss-base (x y class enemy dir)
  (if (= wl.actorcount wl.MAXACTORS)
      false
      (let ((actor wl.actorcount))
        (begin
          (wl.spawn-actor-base x y dir class wl.SPDPATROL 0 wl.ACTOR-STAND
                               (bit.or wl.FL-SHOOTABLE wl.FL-AMBUSH))
          (wl.actor-hitpoints! actor (wl.start-hitpoints-enemy enemy))
          (wl.actorat! x y (+ actor 1))
          true))))

(defn wl.spawn-boss (x y) (wl.spawn-boss-base x y wl.BOSSOBJ 4 6))
(defn wl.spawn-schabbs (x y) (wl.spawn-boss-base x y wl.SCHABBOBJ 5 6))
(defn wl.spawn-fake-hitler (x y) (wl.spawn-boss-base x y wl.FAKEOBJ 6 2))
(defn wl.spawn-hitler (x y) (wl.spawn-boss-base x y wl.MECHAHITLEROBJ 7 6))
(defn wl.spawn-gretel (x y) (wl.spawn-boss-base x y wl.GRETELOBJ 13 2))
(defn wl.spawn-gift (x y) (wl.spawn-boss-base x y wl.GIFTOBJ 14 2))
(defn wl.spawn-fat (x y) (wl.spawn-boss-base x y wl.FATOBJ 15 6))

(defn wl.spawn-ghost (which x y)
  (if (= wl.actorcount wl.MAXACTORS)
      false
      (let ((actor wl.actorcount))
        (begin
          (wl.spawn-actor-base x y 0 wl.GHOSTOBJ wl.SPDDOG 1 wl.ACTOR-CHASE wl.FL-AMBUSH)
          (wl.actor-hitpoints! actor (wl.start-hitpoints-enemy (+ 9 which)))
          (wl.actor-temp1! actor which)
          (wl.actor-ticcount! actor 10)
          (wl.actorat! x y (+ actor 1))
          true))))

;; R1 states use class-specific sprite tables; phase is their compact identity.
(defn wl.actor-shape-base (class stand)
  (cond ((= class 3) (if stand 50 58)) ((= class 4) (if stand 238 246))
        ((= class 5) (if stand 138 146)) ((= class 6) 99)
        ((= class 7) 296) ((= class 8) 307) ((= class 9) 321)
        ((= class 10) 334) ((= class 11) (if stand 187 195))
        ((= class 16) 345) ((= class 17) 385) ((= class 18) 360) ((= class 19) 396)
        (true 0)))

(defn wl.actor-shapenum (actor)
  (let ((class (wl.actor-class@ actor)) (phase (wl.actor-phase@ actor))
        (raw-phase (wl.actor-phase-raw@ actor)))
    (cond ((= class 2) 95)
          ((= class wl.NEEDLEOBJ) (+ 318 (mod (wl.actor-temp1@ actor) 4)))
          ((= class wl.FIREOBJ) (+ 326 (mod (wl.actor-temp1@ actor) 2)))
          ((= class wl.ROCKETOBJ) (+ 370 (mod (wl.actor-temp1@ actor) 8)))
          ((= class wl.GHOSTOBJ) (wl.ghost-shapenum actor))
          ((= phase wl.ACTOR-DEAD) (wl.actor-dead-shape class))
          ((= phase wl.ACTOR-DYING) (wl.death-shape class (- raw-phase wl.ACTOR-DYING)))
          ((= phase wl.ACTOR-PAIN) (wl.pain-shape class (- raw-phase wl.ACTOR-PAIN)))
          ((= phase wl.ACTOR-STAND) (wl.actor-shape-base class true))
          ((>= phase wl.ACTOR-SHOOT) (wl.shoot-shape class (- raw-phase wl.ACTOR-SHOOT)))
          ((wl.boss-class? class)
           (+ (wl.actor-shape-base class false)
              (mod (- phase wl.ACTOR-CHASE) 4)))
          (true (wl.actor-walk-shape class (if (>= phase wl.ACTOR-CHASE)
                                               (- phase wl.ACTOR-CHASE) phase))))))

(defn wl.ghost-shapenum (actor)
  (+ (wl.nth '(288 292 290 294) (wl.actor-temp1@ actor))
     (mod (- (wl.actor-phase@ actor) wl.ACTOR-CHASE) 2)))

(defn wl.boss-class? (class)
  (or (or (= class wl.BOSSOBJ) (= class wl.SCHABBOBJ))
      (or (or (= class wl.FAKEOBJ) (= class wl.MECHAHITLEROBJ))
          (or (or (= class wl.REALHITLEROBJ) (= class wl.GRETELOBJ))
              (or (= class wl.GIFTOBJ) (= class wl.FATOBJ))))))

(defn wl.actor-dead-shape (class)
  (cond ((= class 3) 95) ((= class 4) 284) ((= class 5) 183)
        ((= class 6) 134) ((= class 7) 303) ((= class 8) 316)
        ((= class 9) 333) ((= class 10) 341) ((= class 11) 233)
        ((= class 16) 352) ((= class 17) 392) ((= class 18) 369)
        ((= class 19) 407) (true 0)))

(defn wl.pain-shapes (class)
  (cond ((= class 3) '(90 94)) ((= class 4) '(278 282))
        ((= class 5) '(178 182)) ((= class 11) '(227 231))
        (true '(0 0))))

(defn wl.pain-shape (class step) (wl.nth (wl.pain-shapes class) step))

;;; WL_ACT2.C death states in exact frame order, including repeated W1 lead-in
;;; frames for Schabbs/Gift/Fat/Hitler and each terminal source sprite.
(defn wl.death-shapes (class)
  (cond ((= class 3) '(91 92 93 95)) ((= class 4) '(279 280 281 283 284))
        ((= class 5) '(179 180 181 183)) ((= class 6) '(131 132 133 134))
        ((= class 11) '(228 229 230 232 233))
        ((= class wl.BOSSOBJ) '(304 305 306 303))
        ((= class wl.GRETELOBJ) '(393 394 395 392))
        ((= class wl.SCHABBOBJ) '(307 307 313 314 315 316))
        ((= class wl.GIFTOBJ) '(360 360 366 367 368 369))
        ((= class wl.FATOBJ) '(396 396 404 405 406 407))
        ((= class wl.FAKEOBJ) '(328 329 330 331 332 333))
        ((= class wl.MECHAHITLEROBJ) '(342 343 344 341))
        ((= class wl.REALHITLEROBJ) '(345 345 353 354 355 356 357 358 359 352))
        (true '(0))))

(defn wl.death-times (class)
  (cond ((= class 4) '(11 11 11 11 0)) ((= class 11) '(7 7 7 7 0))
        ((or (= class 3) (or (= class 5) (or (= class 6)
          (or (= class wl.BOSSOBJ) (= class wl.GRETELOBJ))))) '(15 15 15 0))
        ((or (= class wl.SCHABBOBJ) (or (= class wl.GIFTOBJ) (= class wl.FATOBJ)))
         (if (= class wl.SCHABBOBJ) '(10 10 10 10 10 20) '(1 10 10 10 10 20)))
        ((= class wl.FAKEOBJ) '(10 10 10 10 10 0))
        ((= class wl.MECHAHITLEROBJ) '(10 10 10 0))
        ((= class wl.REALHITLEROBJ) '(1 10 10 10 10 10 10 10 10 20))
        (true '(0))))

(defn wl.death-shape (class step) (wl.nth (wl.death-shapes class) step))

(defn wl.start-actor-pain (actor)
  (let ((class (wl.actor-class@ actor)))
    (if (or (= class 3) (or (= class 4) (or (= class 5) (= class 11))))
        (begin
          ;; WL_STATE.C selects pain1 for odd HP and pain2 for even HP.
          ;; Compact raw step 0 is pain1 and raw step 1 is pain2.
          (wl.actor-phase! actor
            (+ wl.ACTOR-PAIN (- 1 (bit.and (wl.actor-hitpoints@ actor) 1))))
          (wl.actor-ticcount! actor 10)
          true)
        false)))

(defn wl.start-actor-death (actor)
  (begin
    (wl.actor-phase! actor wl.ACTOR-DYING)
    (wl.actor-ticcount! actor (car (wl.death-times (wl.actor-class@ actor))))
    true))

(defn wl.actor-walk-shape (class phase)
  (let ((base (wl.actor-shape-base class false)))
    (+ base (cond ((< phase 2) 0) ((= phase 2) 8)
                  ((< phase 5) 16) (true 24)))))

;;; WL_ACT2.C starthitpoints[4][NUMENEMIES], retained in source order for the
;;; base-game enemy indices reached by this port. The final six Spear-only
;;; entries are deliberately outside this Wolf3D data path.
(define wl.start-hitpoints-table
  '((25 50 100 1 850 850 200 800 45 25 25 25 25 850 850 850)
    (25 50 100 1 950 950 300 950 55 25 25 25 25 950 950 950)
    (25 50 100 1 1050 1550 400 1050 55 25 25 25 25 1050 1050 1050)
    (25 50 100 1 1200 2400 500 1200 65 25 25 25 25 1200 1200 1200)))

(defn wl.start-hitpoints-enemy (enemy)
  (if (or (< wl.difficulty 0) (> wl.difficulty 3))
      0
      (if (or (< enemy 0) (> enemy 15))
          0
          (wl.nth (wl.nth wl.start-hitpoints-table wl.difficulty) enemy))))

(defn wl.class-enemy (class)
  (cond ((and (>= class 3) (<= class 11)) (- class 3))
        ((= class wl.GHOSTOBJ) 9)
        ((= class wl.GRETELOBJ) 13)
        ((= class wl.GIFTOBJ) 14)
        ((= class wl.FATOBJ) 15)
        (true -1)))

(defn wl.start-hitpoints (class)
  (wl.start-hitpoints-enemy (wl.class-enemy class)))

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
                (wl.first-sighting actor)))
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

(defn wl.first-sighting (actor)
  (begin
    ;; WL_STATE.C emits the class response before changing state or speed.
    (wl.first-sighting-sound actor)
    (wl.actor-temp2! actor 0)
    (wl.actor-phase! actor wl.ACTOR-CHASE)
    (wl.actor-ticcount! actor 10)
    (u16! wl.actorspeed (* actor 2) (wl.first-sighting-speed actor))
    (wl.actor-flags! actor
      (bit.or (wl.actor-flags@ actor)
              (bit.or wl.FL-ATTACKMODE wl.FL-FIRSTATTACK)))
    true))

(defn wl.first-sighting-sound (actor)
  (let ((class (wl.actor-class@ actor)))
    (cond ((= class wl.GUARDOBJ) (wl.play-sound-loc-actor wl.HALTSND actor))
          ((= class wl.OFFICEROBJ) (wl.play-sound-loc-actor wl.SPIONSND actor))
          ((= class wl.SSOBJ) (wl.play-sound-loc-actor wl.SCHUTZADSND actor))
          ((= class wl.DOGOBJ) (wl.play-sound-loc-actor wl.DOGBARKSND actor))
          ((= class wl.BOSSOBJ) (wl.play-sound wl.GUTENTAGSND 'FirstSighting))
          ((= class wl.GRETELOBJ) (wl.play-sound wl.KEINSND 'FirstSighting))
          ((= class wl.GIFTOBJ) (wl.play-sound wl.EINESND 'FirstSighting))
          ((= class wl.FATOBJ) (wl.play-sound wl.ERLAUBENSND 'FirstSighting))
          ((= class wl.SCHABBOBJ) (wl.play-sound wl.SCHABBSHASND 'FirstSighting))
          ((= class wl.FAKEOBJ) (wl.play-sound wl.TOT-HUNDSND 'FirstSighting))
          ((or (= class wl.MECHAHITLEROBJ) (= class wl.REALHITLEROBJ))
           (wl.play-sound wl.DIESND 'FirstSighting))
          (true false))))

;; WL_STATE.C FirstSighting class switch. Boss starts from SPDPATROL in this
;; data path; the other cases multiply the actor's exact source spawn speed.
(defn wl.first-sighting-speed (actor)
  (let ((class (wl.actor-class@ actor)) (speed (wl.actor-speed@ actor)))
    (cond ((or (= class wl.OFFICEROBJ) (= class wl.REALHITLEROBJ)) (* speed 5))
          ((= class wl.SSOBJ) (* speed 4))
          ((or (= class wl.DOGOBJ) (= class wl.GHOSTOBJ)) (* speed 2))
          ((= class wl.BOSSOBJ) (* wl.SPDPATROL 3))
          (true (* speed 3)))))

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
            (begin
              (wl.actor-viewx! actor (+ wl.centerx (/ (* ny wl.scale) nx)))
              (wl.actor-viewheight! actor (/ wl.heightnumerator (bit.shr nx 8)))
              true)
            (begin (wl.actor-viewheight! actor 0) false))))))

(defn wl.refresh-actor-visibility ()
  (if (= wl.spotvis-current 1)
      (begin
        ;; update-static-bonuses already performed this frame's source
        ;; ThreeDRefresh wall cast. Actor projection consumes the same spotvis.
        (set! wl.spotvis-current 0)
        (wl.refresh-actor-projection 0))
      (begin
        (bytes.fill wl.spotvis 0 4096 0)
        (wl.calc-view)
        (wl.asm-refresh)
        (wl.refresh-actor-projection 0))))

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

(defn wl.move-actors ()
  (wl.move-actors-reclaimable (heap.used)
    sd.audio-operation-count sd.audio-native-payload-count
    sd.adlib-register-event-count sd.music-register-event-count
    sd.audio-event-count wl.audio-event-count))

;;; One full actor sweep bounded by a heap mark taken by the caller. Persistent
;;; cons escapes are confined to the sound module's counted logs and the
;;; wl.audio-events decision log, so the sweep releases only when every
;;; guarding counter is unchanged. Actor slots, actorcount, deathcam, playstate,
;;; and all world cells are preallocated storage and survive the release.
;;; Visitation order and the nil return shape match wl.move-actor-number.
(defn wl.move-actors-reclaimable (mark operations payloads adlib music sd-events wl-events)
  (begin
    (wl.move-actor-number 0)
    (if (and (= sd.audio-operation-count operations)
             (and (= sd.audio-native-payload-count payloads)
                  (and (= sd.adlib-register-event-count adlib)
                       (and (= sd.music-register-event-count music)
                            (and (= sd.audio-event-count sd-events)
                                 (= wl.audio-event-count wl-events))))))
        (heap.release mark)
        nil)
    nil))

(defn wl.move-actor-number (actor)
  (if (= actor wl.actorcount)
      nil
      (begin (wl.do-actor actor) (wl.move-actor-number (+ actor 1)))))

(defn wl.do-actor (actor)
  (if (and (= (wl.actor-active@ actor) 0) (not (wl.area-active? (wl.actor-area@ actor))))
      nil
      (begin
        (wl.actorat-clear-owner actor)
        (cond ((= (wl.actor-phase@ actor) wl.ACTOR-PROJECTILE)
               (wl.t-projectile actor))
              ((= (wl.actor-phase@ actor) wl.ACTOR-DYING) (wl.do-death-state actor))
              ((= (wl.actor-phase@ actor) wl.ACTOR-PAIN) (wl.do-pain-state actor))
              ((= (wl.actor-phase@ actor) wl.ACTOR-DEAD) nil)
              ((= (wl.actor-phase@ actor) wl.ACTOR-STAND)
               (if (> (wl.actor-hitpoints@ actor) 0) (wl.sight-player actor) nil))
              ((>= (wl.actor-phase@ actor) wl.ACTOR-SHOOT) (wl.do-shoot-state actor))
              ((>= (wl.actor-phase@ actor) wl.ACTOR-CHASE) (wl.do-chase-state actor))
              (true (wl.do-patrol-state actor)))
        (if (= (bit.and (wl.actor-flags@ actor) wl.FL-NONMARK) 0)
            (wl.actorat! (wl.actor-tilex@ actor) (wl.actor-tiley@ actor) (+ actor 1)) nil))))

(defn wl.do-pain-state (actor)
  (begin
    (wl.actor-ticcount! actor (- (wl.actor-ticcount@ actor) wl.tics))
    (if (<= (wl.actor-ticcount@ actor) 0)
        (begin
          (wl.actor-phase! actor wl.ACTOR-CHASE)
          ;; DoActor carries the expired state's overshoot into chase1.
          (wl.actor-ticcount! actor (+ (wl.actor-ticcount@ actor) 10))
          ;; Pain states also advance to chase1 at DoActor's think label.
          (wl.actor-chase-think actor))
        nil)))

(defn wl.do-death-state (actor)
  (begin
    (wl.actor-ticcount! actor (- (wl.actor-ticcount@ actor) wl.tics))
    (wl.advance-death-state actor)))

(defn wl.advance-death-state (actor)
  (if (> (wl.actor-ticcount@ actor) 0)
      nil
      (let ((class (wl.actor-class@ actor))
            (step (- (wl.actor-phase-raw@ actor) wl.ACTOR-DYING)))
        (begin
          (wl.death-state-action actor class step)
          ;; First-pass A_StartDeathCam emulates NewState(deathcam) followed by
          ;; DoActor's immediate `state = state->next`: it has already replaced
          ;; the terminal state with renderable die1 and loaded lead+die1 tics.
          ;; Second-pass A_StartDeathCam leaves the terminal state unchanged,
          ;; so the generic self-loop below reloads its source 20 ticks.
          (if (not (= (wl.actor-phase-raw@ actor) (+ wl.ACTOR-DYING step)))
              nil
              (let ((next (+ step 1)) (times (wl.death-times class)))
                (if (= next (wl.list-length times))
                    (if (= (wl.nth times step) 0)
                        (begin (wl.actor-phase! actor wl.ACTOR-DEAD) (wl.actor-ticcount! actor 0))
                        (wl.actor-ticcount! actor (+ (wl.actor-ticcount@ actor) (wl.nth times step))))
                    (begin
                      (wl.actor-phase! actor (+ wl.ACTOR-DYING next))
                      (if (= (wl.nth times next) 0)
                          (begin (wl.actor-phase! actor wl.ACTOR-DEAD) (wl.actor-ticcount! actor 0))
                          (wl.actor-ticcount! actor
                            (+ (wl.actor-ticcount@ actor) (wl.nth times next))))))))
          (if (and (= (wl.actor-phase@ actor) wl.ACTOR-DYING)
                   (<= (wl.actor-ticcount@ actor) 0))
              (wl.advance-death-state actor) nil)))))

(defn wl.death-state-action (actor class step)
  (begin
    (if (= step 0)
        (begin
          (wl.death-scream actor class)
          (set! wl.death-action-count (+ wl.death-action-count 1))) nil)
    (if (and (= class wl.REALHITLEROBJ) (= step 2))
        (wl.play-sound wl.SLURPIESND 'A_Slurpie) nil)
    (if (and (= class wl.MECHAHITLEROBJ) (= step 2)) (wl.hitler-morph actor) nil)
    (if (and (or (= class wl.SCHABBOBJ)
                 (or (= class wl.GIFTOBJ)
                     (or (= class wl.FATOBJ) (= class wl.REALHITLEROBJ))))
             (= step (- (wl.list-length (wl.death-times class)) 1)))
        (wl.start-death-cam actor) nil)))

(defn wl.regular-death-class? (class)
  (or (= class wl.MUTANTOBJ)
      (or (= class wl.GUARDOBJ)
          (or (= class wl.OFFICEROBJ)
              (or (= class wl.SSOBJ) (= class wl.DOGOBJ))))))

(defn wl.death-scream (actor class)
  (let ((episode-nine-roll (if (= wl.map 9) (wl.us-rndt) -1)))
    (if (and (= episode-nine-roll 0) (wl.regular-death-class? class))
        (wl.play-sound-loc-actor wl.DEATHSCREAM6SND actor)
        (cond
          ((= class wl.MUTANTOBJ) (wl.play-sound-loc-actor wl.AHHHGSND actor))
          ((= class wl.GUARDOBJ)
           (wl.play-sound-loc-actor
             (wl.nth
               (list wl.DEATHSCREAM1SND wl.DEATHSCREAM2SND wl.DEATHSCREAM3SND
                     wl.DEATHSCREAM4SND wl.DEATHSCREAM5SND wl.DEATHSCREAM7SND
                     wl.DEATHSCREAM8SND wl.DEATHSCREAM9SND)
               (mod (wl.us-rndt) 8))
             actor))
          ((= class wl.OFFICEROBJ) (wl.play-sound-loc-actor wl.NEINSOVASSND actor))
          ((= class wl.SSOBJ) (wl.play-sound-loc-actor wl.LEBENSND actor))
          ((= class wl.DOGOBJ) (wl.play-sound-loc-actor wl.DOGDEATHSND actor))
          ((= class wl.BOSSOBJ) (wl.play-sound wl.MUTTISND 'A_DeathScream))
          ((= class wl.SCHABBOBJ) (wl.play-sound wl.MEINGOTTSND 'A_DeathScream))
          ((= class wl.FAKEOBJ) (wl.play-sound wl.HITLERHASND 'A_DeathScream))
          ((= class wl.MECHAHITLEROBJ) (wl.play-sound wl.SCHEISTSND 'A_DeathScream))
          ((= class wl.REALHITLEROBJ) (wl.play-sound wl.EVASND 'A_DeathScream))
          ((= class wl.GRETELOBJ) (wl.play-sound wl.MEINSND 'A_DeathScream))
          ((= class wl.GIFTOBJ) (wl.play-sound wl.DONNERSND 'A_DeathScream))
          ((= class wl.FATOBJ) (wl.play-sound wl.ROSESND 'A_DeathScream))
          (true false)))))

(defn wl.actorat-clear-owner (actor)
  (let ((x (wl.actor-tilex@ actor)) (y (wl.actor-tiley@ actor)))
    (if (= (wl.actorat@ x y) (+ actor 1)) (wl.actorat! x y 0) nil)))

(defn wl.do-chase-state (actor)
  (if (= (wl.actor-ticcount@ actor) 0)
      (if (wl.chase-phase-thinks? (wl.actor-phase@ actor)) (wl.actor-chase-think actor) nil)
      (begin
        (wl.actor-ticcount! actor (- (wl.actor-ticcount@ actor) wl.tics))
        (wl.advance-chase-state actor)
        (if (wl.chase-phase-thinks? (wl.actor-phase@ actor)) (wl.actor-chase-think actor) nil))))

(defn wl.actor-chase-think (actor)
  (let ((class (wl.actor-class@ actor)))
    (cond ((= class wl.GHOSTOBJ)
           (wl.chase-move actor (* (wl.actor-speed@ actor) wl.tics) false))
          ((= class wl.DOGOBJ) (wl.t-dog-chase actor))
          ((= class wl.FAKEOBJ) (wl.t-fake actor))
          ((= class wl.SCHABBOBJ) (wl.t-schabb actor))
          ((= class wl.GIFTOBJ) (wl.t-gift actor))
          ((= class wl.FATOBJ) (wl.t-fat actor))
          (true (wl.t-chase actor)))))

(defn wl.advance-chase-state (actor)
  (if (> (wl.actor-ticcount@ actor) 0)
      nil
      (let ((phase (+ wl.ACTOR-CHASE (mod (+ (- (wl.actor-phase@ actor) wl.ACTOR-CHASE) 1) 6))))
        (begin
          (wl.chase-state-action actor)
          (wl.actor-phase! actor phase)
          (wl.actor-ticcount! actor (+ (wl.actor-ticcount@ actor) (wl.chase-phase-time phase)))
          (wl.advance-chase-state actor)))))

(defn wl.chase-state-action (actor)
  (let ((step (- (wl.actor-phase@ actor) wl.ACTOR-CHASE)))
    (if (and (= (wl.actor-class@ actor) wl.MECHAHITLEROBJ)
             (and (or (= step 0) (= step 3))
                  (wl.area-active? (wl.actor-area@ actor))))
        (wl.play-sound-loc-actor wl.MECHSTEPSND actor)
        false)))

(defn wl.chase-phase-time (phase)
  (let ((p (- phase wl.ACTOR-CHASE)))
    (cond ((or (= p 0) (= p 3)) 10) ((or (= p 1) (= p 4)) 3) (true 8))))

(defn wl.chase-phase-thinks? (phase)
  (let ((p (- phase wl.ACTOR-CHASE)))
    (or (or (= p 0) (= p 2)) (or (= p 3) (= p 5)))))

(defn wl.do-shoot-state (actor)
  (begin
    (wl.actor-ticcount! actor (- (wl.actor-ticcount@ actor) wl.tics))
    (wl.advance-source-shoot-state actor)
    ;; WL_PLAY.C DoActor falls through to the think label after advancing the
    ;; state chain.  If the last shoot frame became a chase state this tick,
    ;; its thinker runs immediately (including its source RNG/movement order).
    (if (and (>= (wl.actor-phase@ actor) wl.ACTOR-CHASE)
             (< (wl.actor-phase@ actor) wl.ACTOR-SHOOT)
             (wl.chase-phase-thinks? (wl.actor-phase@ actor)))
        (wl.actor-chase-think actor)
        nil)))

(defn wl.advance-source-shoot-state (actor)
  (if (> (wl.actor-ticcount@ actor) 0)
      nil
      (let ((class (wl.actor-class@ actor))
            (step (- (wl.actor-phase-raw@ actor) wl.ACTOR-SHOOT)))
        (begin
          (if (wl.shoot-action? class step) (wl.perform-actor-attack-step actor step) nil)
          (let ((next (+ step 1)))
            (if (= next (wl.list-length (wl.shoot-times class)))
                (begin
                  (wl.actor-phase! actor wl.ACTOR-CHASE)
                  (wl.actor-ticcount! actor (+ (wl.actor-ticcount@ actor) 10)))
                (begin
                  (wl.actor-phase! actor (+ wl.ACTOR-SHOOT next))
                  (wl.actor-ticcount! actor
                    (+ (wl.actor-ticcount@ actor) (wl.nth (wl.shoot-times class) next))))))
          (if (<= (wl.actor-ticcount@ actor) 0)
              (wl.advance-source-shoot-state actor) nil)))))

(defn wl.list-length (values)
  (if (nil? values) 0 (+ 1 (wl.list-length (cdr values)))))

(defn wl.min (a b) (if (< a b) a b))

;;; Exact WL_ACT2.C state order: one tics entry and one shapenum per state.
(defn wl.shoot-times (class)
  (cond ((= class 3) '(20 20 20)) ((= class 4) '(6 20 10))
        ((= class 5) '(20 20 10 10 10 10 10 10 10))
        ((= class 6) '(10 10 10 10 10)) ((= class 11) '(6 20 10 20))
        ((or (= class wl.BOSSOBJ) (= class wl.GRETELOBJ)) '(30 10 10 10 10 10 10 10))
        ((or (= class wl.SCHABBOBJ) (= class wl.GIFTOBJ)) '(30 10))
        ((= class wl.FATOBJ) '(30 10 10 10 10 10))
        ((= class wl.FAKEOBJ) '(8 8 8 8 8 8 8 8 8))
        ((or (= class wl.MECHAHITLEROBJ) (= class wl.REALHITLEROBJ)) '(30 10 10 10 10 10))
        (true '(20 20 20))))

(defn wl.shoot-shapes (class)
  (cond ((= class 3) '(96 97 98)) ((= class 4) '(285 286 287))
        ((= class 5) '(184 185 186 185 186 185 186 185 186))
        ((= class 6) '(135 136 137 135 99)) ((= class 11) '(234 235 236 237))
        ((= class wl.BOSSOBJ) '(300 301 302 301 302 301 302 300))
        ((= class wl.GRETELOBJ) '(389 390 391 390 391 390 391 389))
        ((= class wl.SCHABBOBJ) '(311 312)) ((= class wl.GIFTOBJ) '(364 365))
        ((= class wl.FATOBJ) '(400 401 402 403 402 403))
        ((= class wl.FAKEOBJ) '(325 325 325 325 325 325 325 325 325))
        ((= class wl.MECHAHITLEROBJ) '(338 339 340 339 340 339))
        ((= class wl.REALHITLEROBJ) '(349 350 351 350 351 350))
        (true '(0 0 0))))

(defn wl.shoot-shape (class step) (wl.nth (wl.shoot-shapes class) step))

(defn wl.shoot-action? (class step)
  (cond ((or (= class 3) (= class 4)) (= step 1))
        ((= class 5) (or (= step 1) (or (= step 3) (or (= step 5) (= step 7)))))
        ((= class 6) (= step 1))
        ((= class 11) (or (= step 0) (= step 2)))
        ((or (= class wl.BOSSOBJ) (= class wl.GRETELOBJ)) (and (>= step 1) (<= step 6)))
        ((or (= class wl.SCHABBOBJ) (= class wl.GIFTOBJ)) (= step 1))
        ((= class wl.FATOBJ) (and (>= step 1) (<= step 5)))
        ((= class wl.FAKEOBJ) (<= step 7))
        ((or (= class wl.MECHAHITLEROBJ) (= class wl.REALHITLEROBJ))
         (and (>= step 1) (<= step 4)))
        (true false)))

(defn wl.perform-actor-attack-step (actor step)
  (let ((class (wl.actor-class@ actor)))
    (cond ((= class 6) (wl.t-bite-core actor))
          ((= class wl.SCHABBOBJ) (wl.spawn-aimed-projectile actor wl.NEEDLEOBJ))
          ((= class wl.FAKEOBJ) (wl.spawn-aimed-projectile actor wl.FIREOBJ))
          ((= class wl.GIFTOBJ) (wl.spawn-aimed-projectile actor wl.ROCKETOBJ))
          ((and (= class wl.FATOBJ) (= step 1))
           (wl.spawn-aimed-projectile actor wl.ROCKETOBJ))
          (true (wl.t-shoot actor)))))

(defn wl.t-bite-core (actor)
  (begin
    ;; JAB source order is deliberate: bark even when the range or hit fails.
    (wl.play-sound-loc-actor wl.DOGATTACKSND actor)
    (let ((dx (- (wl.abs (- (wl.player@ wl.PLAYER-X) (wl.actor-x@ actor)))
                 wl.TILEGLOBAL)))
      (if (<= dx wl.MINACTORDIST)
          (let ((dy (- (wl.abs (- (wl.player@ wl.PLAYER-Y) (wl.actor-y@ actor)))
                       wl.TILEGLOBAL)))
            (if (and (<= dy wl.MINACTORDIST) (< (wl.us-rndt) 180))
                (wl.take-damage (bit.shr (wl.us-rndt) 4) actor) false))
          false))))

;;; T_SchabbThrow, T_GiftThrow, and T_FakeFire share the same source setup;
;;; only class/damage and sprite state differ.
(defn wl.spawn-aimed-projectile (source class)
  (if (= wl.actorcount wl.MAXACTORS)
      -1
      (let ((actor wl.actorcount))
        (begin
          (wl.spawn-actor-base (wl.actor-tilex@ source) (wl.actor-tiley@ source)
                               8 class wl.PROJECTILESPEED 1 wl.ACTOR-PROJECTILE
                               wl.FL-NONMARK)
          (wl.actor-x! actor (wl.actor-x@ source))
          (wl.actor-y! actor (wl.actor-y@ source))
          (wl.actor-angle! actor
            (wl.aim-angle (- (wl.player@ wl.PLAYER-X) (wl.actor-x@ source))
                          (- (wl.actor-y@ source) (wl.player@ wl.PLAYER-Y))))
          (wl.actor-ticcount! actor 1)
          (wl.projectile-launch-sound actor class)
          actor))))

(defn wl.projectile-launch-sound (actor class)
  (cond ((= class wl.NEEDLEOBJ)
         (wl.play-sound-loc-actor wl.SCHABBSTHROWSND actor))
        ((= class wl.FIREOBJ)
         (wl.play-sound-loc-actor wl.FLAMETHROWERSND actor))
        ((= class wl.ROCKETOBJ)
         (wl.play-sound-loc-actor wl.MISSILEFIRESND actor))
        (true false)))

(defn wl.aim-angle (dx dy)
  (let ((ax (wl.abs dx)) (ay (wl.abs dy)))
    (cond ((> ax (* ay 2)) (if (> dx 0) 0 180))
          ((> ay (* ax 2)) (if (> dy 0) 90 270))
          ((and (> dx 0) (> dy 0)) 45)
          ((and (< dx 0) (> dy 0)) 135)
          ((and (< dx 0) (< dy 0)) 225)
          (true 315))))

(defn wl.projectile-try-move (actor)
  (wl.projectile-box-clear?
    (bit.shr (- (wl.actor-x@ actor) wl.PROJSIZE) wl.TILESHIFT)
    (bit.shr (- (wl.actor-y@ actor) wl.PROJSIZE) wl.TILESHIFT)
    (bit.shr (+ (wl.actor-x@ actor) wl.PROJSIZE) wl.TILESHIFT)
    (bit.shr (+ (wl.actor-y@ actor) wl.PROJSIZE) wl.TILESHIFT)))

(defn wl.projectile-box-clear? (xl yl xh yh)
  (if (or (< xl 0) (or (< yl 0) (or (> xh 63) (> yh 63))))
      false
      (wl.projectile-rows-clear? xl yl xh yh yl)))

(defn wl.projectile-rows-clear? (xl yl xh yh y)
  (if (> y yh) true
      (if (wl.projectile-row-clear? xl xh y xl)
          (wl.projectile-rows-clear? xl yl xh yh (+ y 1)) false)))

(defn wl.projectile-row-clear? (xl xh y x)
  (if (> x xh) true
      (if (or (> (wl.actorat-wall@ x y) 0)
              (> (wl.tilemap@ x y) 0))
          false (wl.projectile-row-clear? xl xh y (+ x 1)))))

(defn wl.projectile-damage (class)
  (let ((roll (bit.shr (wl.us-rndt) 3)))
    (cond ((= class wl.NEEDLEOBJ) (+ roll 20))
          ((= class wl.ROCKETOBJ) (+ roll 30))
          (true roll))))

(defn wl.t-projectile (actor)
  (let ((speed (* (wl.actor-speed@ actor) wl.tics))
        (angle (wl.actor-angle@ actor)))
    (let ((dx (wl.clamp-projectile-step (fx.by-frac speed (wl.costable@ angle))))
          (dy (wl.clamp-projectile-step (- 0 (fx.by-frac speed (wl.sintable@ angle))))))
      (begin
        (wl.actor-x! actor (+ (wl.actor-x@ actor) dx))
        (wl.actor-y! actor (+ (wl.actor-y@ actor) dy))
        (wl.actor-temp1! actor (+ (wl.actor-temp1@ actor) 1))
        (if (not (wl.projectile-try-move actor))
            (begin
              (if (= (wl.actor-class@ actor) wl.ROCKETOBJ)
                  (wl.play-sound-loc-actor wl.MISSILEHITSND actor) nil)
              (wl.actor-phase! actor wl.ACTOR-DEAD))
            (if (and (< (wl.abs (- (wl.actor-x@ actor) (wl.player@ wl.PLAYER-X)))
                        wl.PROJECTILESIZE)
                     (< (wl.abs (- (wl.actor-y@ actor) (wl.player@ wl.PLAYER-Y)))
                        wl.PROJECTILESIZE))
                (begin
                  (wl.take-damage (wl.projectile-damage (wl.actor-class@ actor)) actor)
                  (wl.actor-phase! actor wl.ACTOR-DEAD))
                (begin
                  (wl.actor-tilex! actor (bit.shr (wl.actor-x@ actor) wl.TILESHIFT))
                  (wl.actor-tiley! actor (bit.shr (wl.actor-y@ actor) wl.TILESHIFT)))))
        (not (= (wl.actor-phase@ actor) wl.ACTOR-DEAD))))))

(defn wl.clamp-projectile-step (value)
  (cond ((> value wl.TILEGLOBAL) wl.TILEGLOBAL)
        ((< value (- 0 wl.TILEGLOBAL)) (- 0 wl.TILEGLOBAL))
        (true value)))

;;; A_HitlerMorph keeps the dying mecha slot and allocates the faster unarmored
;;; Hitler at its exact fixed-point position.
(defn wl.hitler-morph (mecha)
  (if (= wl.actorcount wl.MAXACTORS)
      -1
      (let ((actor wl.actorcount))
        (begin
          (wl.spawn-actor-base (wl.actor-tilex@ mecha) (wl.actor-tiley@ mecha)
                               (wl.actor-dir@ mecha) wl.REALHITLEROBJ
                               (* wl.SPDPATROL 5) 1 wl.ACTOR-CHASE
                               (bit.or (wl.actor-flags@ mecha) wl.FL-SHOOTABLE))
          (wl.actor-x! actor (wl.actor-x@ mecha))
          (wl.actor-y! actor (wl.actor-y@ mecha))
          (wl.actor-distance! actor (wl.actor-distance@ mecha))
          (wl.actor-hitpoints! actor (wl.nth '(500 700 800 900) wl.difficulty))
          (wl.actorat! (wl.actor-tilex@ actor) (wl.actor-tiley@ actor) (+ actor 1))
          actor))))

;;; WL_ACT2.C A_StartDeathCam consumes the KillActor-time player snapshot.
;;; Presentation, acknowledgment, and post-PlayLoop lifecycle remain app-owned;
;;; this seam owns only camera placement and the two terminal actor passes.
(defn wl.deathcam-class? (class)
  (or (= class wl.SCHABBOBJ)
      (or (= class wl.GIFTOBJ)
          (or (= class wl.FATOBJ) (= class wl.REALHITLEROBJ)))))

(defn wl.deathcam-terminal-actor? (actor)
  (if (or (< actor 0) (>= actor wl.actorcount))
      false
      (let ((class (wl.actor-class@ actor)))
        (and (wl.deathcam-class? class)
             (= (wl.actor-phase-raw@ actor)
                (+ wl.ACTOR-DYING (- (wl.list-length (wl.death-times class)) 1)))))))

;;; A_StartDeathCam stores atan2's result in a C float before normalizing a
;;; negative angle and truncating fangle/(2*pi)*360.  That float32 rounding can
;;; move a mathematically super-boundary vector into the preceding degree, so
;;; the fixed-point sine table is not an oracle for this one source operation.
;;;
;;; The evaluator has no float32 atan2.  These four tables are the deterministic
;;; finite-domain representation of that source path for map-sized components
;;; (abs(dx),abs(dy) <= MAPSIZE*TILEGLOBAL).  Each (numerator denominator) is a
;;; Farey separator between the closest attainable integer-vector slopes on the
;;; two sides of one rounded-float boundary.  Each reduced separator has at
;;; least one component beyond the map limit, so no valid vector can equal one.
;;; Q3/Q4 are deliberately not mirrored: the source's negative-angle add
;;; performs a second float rounding.
(define wl.deathcam-angle-q1-boundaries
  '((73469 4209036) (215751 6178300) (273883 5225999) (378304 5409999) (388904 4445193) (520936 4956375)
    (519167 4228276) (631684 4494665) (705574 4454819) (763368 4329275) (961238 4945141) (1254539 5902142)
    (1109894 4807479) (1100637 4414414) (1169099 4363137) (1809153 6309266) (1325987 4337108) (1497549 4608982)
    (1650801 4794274) (1888611 5188916) (2153111 5609046) (2432601 6020899) (3110456 7327775) (1882125 4227322)
    (2062267 4422546) (2533725 5194906) (2365986 4643509) (2383539 4482785) (2441563 4404696) (2442848 4231137)
    (2740026 4560169) (3398534 5438791) (2755913 4243734) (4646296 6888417) (3364113 4804451) (3063954 4217171)
    (3354730 4451877) (3436528 4398555) (4249191 5247314) (4909979 5851485) (4900043 5636855) (5193688 5768175)
    (4089697 4385663) (4364829 4519913) (4194304 4194305) (4248082 4102325) (4362519 4068115) (4764933 4290365)
    (6084217 5288929) (4832874 4055263) (5545418 4490591) (4470451 3492699) (4467954 3366845) (6019448 4373385)
    (6552836 4588345) (4517495 3047089) (6437079 4180288) (4248751 2654914) (4909792 2950101) (4308315 2487407)
    (4787930 2653993) (6390483 3397880) (6848051 3489256) (6211792 3029693) (5239167 2443064) (5071216 2257851)
    (6951298 2950651) (5380891 2174021) (4655589 1787113) (4350057 1583291) (5102721 1757008) (5772235 1875513)
    (4332640 1324621) (4197114 1203503) (5040572 1350617) (7252356 1808215) (4457443 1029082) (4231071 899342)
    (4335115 842661) (4706223 829834) (4390666 695413) (4798340 674363) (4598663 564645) (7772007 816871)
    (4530107 396333) (4705364 329031) (4784389 250739) (4631391 161732) (5537006 96649)))

(define wl.deathcam-angle-q2-boundaries
  '((122043 6991837) (216273 6193244) (377255 7198448) (370447 5297643) (619323 7078897) (467922 4451981)
    (590221 4806964) (669118 4761021) (688648 4347951) (1227897 6963752) (875045 4501717) (934121 4394694)
    (1020817 4421644) (1395587 5597393) (1148457 4286099) (1208549 4214712) (1776584 5810945) (1503496 4627285)
    (1800818 5229955) (1533077 4212094) (1859159 4843274) (2087499 5166742) (1863255 4389554) (2253671 5061828)
    (3019615 6475586) (2310761 4737761) (2219528 4356069) (3488826 6561529) (2471493 4458691) (2761067 4782309)
    (2564628 4268257) (3106386 4971257) (2726339 4198195) (3029572 4491525) (2999711 4284032) (3975865 5472308)
    (5049927 6701480) (3472913 4445125) (4916522 6071399) (3559444 4241981) (3843955 4421964) (5025791 5581707)
    (4227625 4533572) (6492338 6723013) (4194304 4194305) (4232661 4087433) (6417788 5984685) (5150735 4637742)
    (5272696 4583485) (5963895 5004301) (4198091 3399547) (5681912 4439197) (5570879 4197958) (5766891 4189892)
    (5422759 3797056) (4378084 2953055) (4214323 2736814) (5383809 3364177) (5355812 3218097) (5421869 3130317)
    (4229633 2344524) (4714723 2506862) (4778209 2434619) (4402963 2147469) (4589001 2139886) (4586155 2041888)
    (7579328 3217233) (5043727 2037798) (5116409 1964006) (4417631 1607886) (5194851 1788731) (4263550 1385311)
    (4224682 1291615) (4250546 1218825) (6352522 1702153) (4869299 1214053) (4500461 1039013) (4207524 894337)
    (5847329 1136605) (4281591 754960) (5402939 855742) (4311396 605927) (6043029 741991) (7384266 776117)
    (4273753 373905) (5862663 409958) (5573641 292102) (4199011 146633) (4240963 74026)))

(define wl.deathcam-angle-q3-boundaries
  '((105104 6021345) (146633 4199011) (292102 5573641) (409958 5862663) (373905 4273753) (558139 5310330)
    (741991 6043029) (605927 4311396) (855742 5402939) (754960 4281591) (962717 4952746) (894337 4207524)
    (1016142 4401391) (1214053 4869299) (1702153 6352522) (1218825 4250546) (1291615 4224682) (1376589 4236703)
    (1788731 5194851) (1607886 4417631) (1964006 5116409) (2037798 5043727) (2040329 4806712) (2041888 4586155)
    (2139886 4589001) (2147469 4402963) (2434619 4778209) (2888171 5431858) (2344524 4229633) (2763170 4785949)
    (3218097 5355812) (3364177 5383809) (2736814 4214323) (2953055 4378084) (3287717 4695345) (4189892 5766891)
    (4197958 5570879) (4439197 5681912) (3399547 4198091) (5519113 6577421) (4583485 5272696) (3818686 4241079)
    (5984685 6417788) (4087433 4232661) (4194305 4194304) (6723013 6492338) (4426689 4127953) (5581707 5025791)
    (4421964 3843955) (4301221 3609154) (4915502 3980497) (7038753 5499275) (6701480 5049927) (5472308 3975865)
    (4195369 2937630) (7288491 4916152) (4198195 2726339) (4971257 3106386) (4268257 2564628) (4480727 2586950)
    (5753487 3189212) (6561529 3488826) (4356069 2219528) (4737761 2310761) (5972423 2784988) (4569523 2034484)
    (4735145 2009949) (5166742 2087499) (4843274 1859159) (7029294 2558455) (4738421 1631568) (4233097 1375416)
    (5810945 1776584) (4580756 1313511) (4549281 1218977) (5946361 1482593) (4645939 1072599) (4394694 934121)
    (4240196 824211) (6008518 1059465) (4808799 761638) (6592800 926557) (4806964 590221) (5923799 622617)
    (4738397 414557) (4260937 297953) (4387103 229918) (6193244 216273) (4619085 80627)))

(define wl.deathcam-angle-q4-boundaries
  '((85631 4905753) (161732 4631391) (250739 4784389) (333690 4771999) (497643 5688070) (505232 4806955)
    (564645 4598663) (615457 4379206) (733559 4631514) (740399 4199006) (820840 4222853) (899342 4231071)
    (1064513 4610914) (1053511 4225405) (1186219 4427026) (1365148 4760835) (1324621 4332640) (1364905 4200747)
    (2412157 7005417) (1781485 4894587) (1656553 4315467) (2174021 5380891) (2152287 5070472) (1885119 4234049)
    (2120016 4546387) (2568649 5266510) (3489256 6848051) (2250896 4233321) (3827722 6905397) (2550545 4417672)
    (2950101 4909792) (2654914 4248751) (2930813 4513058) (2966483 4397990) (4257059 6079709) (4373385 6019448)
    (3175712 4214313) (3501820 4482127) (4172149 5152173) (3945062 4701541) (5288929 6084217) (4209270 4674869)
    (5200516 5576873) (4128374 4275055) (4194305 4194304) (6602195 6375666) (4635023 4322230) (4882819 4396512)
    (6709826 5832761) (5288220 4437343) (5098244 4128477) (5089511 3976363) (5540611 4175152) (5323109 3867464)
    (6031148 4223055) (4903672 3307569) (4601449 2988217) (5399860 3374209) (4513845 2712191) (4231137 2442848)
    (4256989 2359688) (4202617 2234572) (5842669 2976987) (5894535 2874956) (4422546 2062267) (6755255 3007634)
    (5534031 2349058) (6259362 2528945) (4327385 1661127) (5188916 1888611) (4272601 1471175) (5063066 1645091)
    (6246325 1909692) (6218686 1783179) (5552638 1487825) (5016919 1250859) (6825689 1575836) (4242653 901803)
    (4339865 843584) (4619865 814607) (4869281 771219) (4254059 597870) (4691915 576094) (4582282 481617)
    (6890912 602877) (4929315 344692) (7248975 379901) (5035332 175837) (4265819 74460)))

(defn wl.deathcam-angle (dx dy)
  (cond ((and (= dx 0) (= dy 0)) 0)
        ((= dy 0) (if (> dx 0) 0 180))
        ((= dx 0) (if (> dy 0) 90 270))
        ((and (> dx 0) (> dy 0))
         (wl.deathcam-angle-from-ratio dy dx 1 wl.deathcam-angle-q1-boundaries))
        ((and (< dx 0) (> dy 0))
         (wl.deathcam-angle-from-ratio (- 0 dx) dy 91 wl.deathcam-angle-q2-boundaries))
        ((and (< dx 0) (< dy 0))
         (wl.deathcam-angle-from-ratio (- 0 dy) (- 0 dx) 181 wl.deathcam-angle-q3-boundaries))
        (true
         (wl.deathcam-angle-from-ratio dx (- 0 dy) 271 wl.deathcam-angle-q4-boundaries))))

(defn wl.deathcam-angle-from-ratio (numerator denominator boundary separators)
  (if (nil? separators)
      (- boundary 1)
      (let ((separator (car separators)))
        (if (< (wl.deathcam-ratio-compare numerator denominator
                 (car separator) (car (cdr separator))) 0)
            (- boundary 1)
            (wl.deathcam-angle-from-ratio numerator denominator (+ boundary 1)
                                          (cdr separators))))))

;;; Euclidean fraction comparison avoids overflowing the seed's 31-bit fixnum;
;;; cross products of a map coordinate and a separator do not fit there.
(defn wl.deathcam-ratio-compare (an ad bn bd)
  (let ((aq (/ an ad)) (bq (/ bn bd)))
    (cond ((< aq bq) -1)
          ((> aq bq) 1)
          (true (wl.deathcam-ratio-compare-remainders
                  (mod an ad) ad (mod bn bd) bd)))))

(defn wl.deathcam-ratio-compare-remainders (ar ad br bd)
  (cond ((= ar 0) (if (= br 0) 0 -1))
        ((= br 0) 1)
        (true (- 0 (wl.deathcam-ratio-compare ad ar bd br)))))

(defn wl.deathcam-position-clear? (x y)
  (let ((xl (bit.shr (- x wl.PLAYERSIZE) wl.TILESHIFT))
        (yl (bit.shr (- y wl.PLAYERSIZE) wl.TILESHIFT))
        (xh (bit.shr (+ x wl.PLAYERSIZE) wl.TILESHIFT))
        (yh (bit.shr (+ y wl.PLAYERSIZE) wl.TILESHIFT)))
    (if (or (< xl 0) (or (< yl 0) (or (>= xh wl.MAPSIZE) (>= yh wl.MAPSIZE))))
        false
        (wl.deathcam-position-rows-clear? xl xh yl yh))))

(defn wl.deathcam-position-rows-clear? (xl xh y yh)
  (if (> y yh)
      true
      (if (wl.deathcam-position-row-clear? xl xh y)
          (wl.deathcam-position-rows-clear? xl xh (+ y 1) yh)
          false)))

(defn wl.deathcam-position-row-clear? (x xh y)
  (if (> x xh)
      true
      (if (> (wl.actorat-wall@ x y) 0)
          false
          (wl.deathcam-position-row-clear? (+ x 1) xh y))))

(defn wl.find-deathcam-position (actor angle step)
  (if (= step wl.DEATHCAM-MAX-SEARCH-STEPS)
      false
      (let ((distance (+ 81920 (* step 4096))))
        (let ((x (- (wl.actor-x@ actor)
                    (fx.by-frac distance (wl.costable@ angle))))
              (y (+ (wl.actor-y@ actor)
                    (fx.by-frac distance (wl.sintable@ angle)))))
          (if (wl.deathcam-position-clear? x y)
              (list x y distance)
              (wl.find-deathcam-position actor angle (+ step 1)))))))

(defn wl.apply-deathcam-position (actor angle position)
  (let ((x (car position)) (y (car (cdr position)))
        (class (wl.actor-class@ actor)))
    (begin
      (set! wl.victoryflag 1)
      (set! wl.deathcam-active 1)
      (set! wl.deathcam-phase wl.DEATHCAM-ACTIVE)
      (wl.player! wl.PLAYER-STATE wl.PLAYER-DEATHCAM-STATE)
      (wl.player! wl.PLAYER-X x)
      (wl.player! wl.PLAYER-Y y)
      (wl.player! wl.PLAYER-ANGLE angle)
      (wl.player! wl.PLAYER-TILEX (bit.shr x wl.TILESHIFT))
      (wl.player! wl.PLAYER-TILEY (bit.shr y wl.TILESHIFT))
      ;; NewState(ob, deathcam) loads the class lead-in (Hitler 10, the other
      ;; three 1).  The enclosing source DoActor then immediately follows
      ;; deathcam->die1 and adds die1's duration in the same transition loop.
      (wl.actor-phase! actor wl.ACTOR-DYING)
      (wl.actor-ticcount! actor
        (+ (wl.deathcam-lead-tics class) (car (wl.death-times class))))
      'deathcam-started)))

(defn wl.deathcam-lead-tics (class)
  (if (= class wl.REALHITLEROBJ) 10 1))

;;; Stable public lifecycle surface for the later application owner.  These are
;;; the three port-only death-camera fields; source victory, kill snapshot,
;;; playstate, camera coordinates, and actor state deliberately survive reset.
(defn wl.deathcam-active? ()
  (and (= wl.deathcam-active 1)
       (and (= wl.deathcam-phase wl.DEATHCAM-ACTIVE)
            (= (wl.player@ wl.PLAYER-STATE) wl.PLAYER-DEATHCAM-STATE))))

(defn wl.reset-deathcam-lifecycle ()
  (begin
    (set! wl.deathcam-active 0)
    (set! wl.deathcam-phase wl.DEATHCAM-IDLE)
    (wl.player! wl.PLAYER-STATE 0)
    true))

;;; A_StartDeathCam's palette completion, 100-VBL wait, victory presentation,
;;; 300-tic acknowledgement, play-loop freeze, and new-game/reset lifecycle are
;;; deliberately app-owned.  The public reset above supplies the narrow port
;;; operation, but its app lifecycle callsite remains unwired.  This explicit
;;; boundary prevents camera placement from being mistaken for completion.
(defn wl.deathcam-remaining-app-seams ()
  '(finish-palette-shifts wait-vbl-100 victory-presentation ack-300
    play-loop-freeze lifecycle-reset))

(defn wl.start-death-cam (actor)
  (if (not (wl.deathcam-terminal-actor? actor))
      false
      (if (= wl.victoryflag 1)
          (begin
            (set! wl.playstate wl.EX-VICTORIOUS)
            'victory-complete)
          (if (or (not (= wl.deathcam-phase wl.DEATHCAM-IDLE))
                  (or (not (= wl.victoryflag 0))
                      (or (<= wl.killx 0) (<= wl.killy 0))))
              false
              (let ((angle (wl.deathcam-angle
                             (- (wl.actor-x@ actor) wl.killx)
                             (- wl.killy (wl.actor-y@ actor)))))
                (let ((position (wl.find-deathcam-position actor angle 0)))
                  (if position
                      (wl.apply-deathcam-position actor angle position)
                      false)))))))

(defn wl.t-shoot (actor)
  (if (not (wl.area-active? (wl.actor-area@ actor)))
      false
      (if (not (wl.actor-check-line-player actor))
          false
          (let ((distance (wl.actor-shot-distance actor)))
            (let ((hitchance
                    (- (if (>= wl.thrustspeed 6000) 160 256)
                       (* distance (if (> (bit.and (wl.actor-flags@ actor) wl.FL-VISABLE) 0) 16 8)))))
              (let ((hit
                      (if (< (wl.us-rndt) hitchance)
                          (wl.take-damage
                            (let ((roll (wl.us-rndt)))
                              (cond ((< distance 2) (bit.shr roll 2))
                                    ((< distance 4) (bit.shr roll 3))
                                    (true (bit.shr roll 4))))
                            actor)
                          false)))
                (begin (wl.actor-attack-sound actor) hit)))))))

(defn wl.actor-shot-distance (actor)
  (let ((distance
          (wl.max (wl.abs (- (wl.actor-tilex@ actor) (wl.player@ wl.PLAYER-TILEX)))
                  (wl.abs (- (wl.actor-tiley@ actor) (wl.player@ wl.PLAYER-TILEY))))))
    (if (or (= (wl.actor-class@ actor) wl.SSOBJ)
            (= (wl.actor-class@ actor) wl.BOSSOBJ))
        (/ (* distance 2) 3)
        distance)))

(defn wl.actor-attack-sound (actor)
  (let ((class (wl.actor-class@ actor)))
    (cond ((= class wl.SSOBJ) (wl.play-sound-loc-actor wl.SSFIRESND actor))
          ((or (= class wl.GIFTOBJ) (= class wl.FATOBJ))
           (wl.play-sound-loc-actor wl.MISSILEFIRESND actor))
          ((or (= class wl.MECHAHITLEROBJ)
               (or (= class wl.REALHITLEROBJ) (= class wl.BOSSOBJ)))
           (wl.play-sound-loc-actor wl.BOSSFIRESND actor))
          ((= class wl.SCHABBOBJ)
           (wl.play-sound-loc-actor wl.SCHABBSTHROWSND actor))
          ((= class wl.FAKEOBJ)
           (wl.play-sound-loc-actor wl.FLAMETHROWERSND actor))
          (true (wl.play-sound-loc-actor wl.NAZIFIRESND actor)))))

(defn wl.bj-yell (actor)
  (wl.play-sound-loc-actor wl.YEAHSND actor))

(defn wl.take-damage (points attacker)
  (begin
    ;; The original records LastAttacker before any difficulty or health work.
    (set! wl.last-attacker attacker)
    (let ((damage (if (= wl.difficulty 0) (bit.shr points 2) points)))
      (begin
        (set! wl.health (wl.max 0 (- wl.health damage)))
        (set! wl.gotgatgun 0)
        true))))

;;; WL_ACT2.C keeps these chase thinkers distinct. Their line-test/RNG order,
;;; close-range retreat, and movement loops are gameplay-visible and cannot be
;;; represented by routing every class through T_Chase.
(defn wl.t-dog-chase (actor)
  (if (and (= (wl.actor-dir@ actor) 8) (not (wl.select-dodge-dir actor)))
      false
      (wl.dog-chase-move actor (* (wl.actor-speed@ actor) wl.tics))))

(defn wl.dog-chase-move (actor move)
  (if (= move 0)
      true
      (let ((dx (- (wl.abs (- (wl.player@ wl.PLAYER-X) (wl.actor-x@ actor))) move)))
        (if (<= dx wl.MINACTORDIST)
            (let ((dy (- (wl.abs (- (wl.player@ wl.PLAYER-Y) (wl.actor-y@ actor))) move)))
              (if (<= dy wl.MINACTORDIST)
                  (begin (wl.start-actor-shoot actor) true)
                  (wl.dog-chase-move-after-range actor move)))
            (wl.dog-chase-move-after-range actor move)))))

(defn wl.dog-chase-move-after-range (actor move)
  (if (< move (wl.actor-distance@ actor))
      (wl.move-obj actor move)
      (let ((remaining (- move (wl.actor-distance@ actor))))
        (begin
          (wl.snap-actor-to-destination actor)
          (wl.select-dodge-dir actor)
          (if (= (wl.actor-dir@ actor) 8)
              false
              (wl.dog-chase-move actor remaining))))))

(defn wl.t-fake (actor)
  (if (and (wl.actor-check-line-player actor)
           (< (wl.us-rndt) (bit.shl wl.tics 1)))
      (begin (wl.start-actor-shoot actor) true)
      (if (and (= (wl.actor-dir@ actor) 8) (not (wl.select-dodge-dir actor)))
          false
          (wl.fake-chase-move actor (* (wl.actor-speed@ actor) wl.tics)))))

(defn wl.fake-chase-move (actor move)
  (if (= move 0)
      true
      (if (< move (wl.actor-distance@ actor))
          (wl.move-obj actor move)
          (let ((remaining (- move (wl.actor-distance@ actor))))
            (begin
              (wl.snap-actor-to-destination actor)
              (wl.select-dodge-dir actor)
              (if (= (wl.actor-dir@ actor) 8)
                  false
                  (wl.fake-chase-move actor remaining)))))))

(defn wl.t-schabb (actor) (wl.t-ranged-boss-chase actor))
(defn wl.t-gift (actor) (wl.t-ranged-boss-chase actor))
(defn wl.t-fat (actor) (wl.t-ranged-boss-chase actor))

(defn wl.t-ranged-boss-chase (actor)
  (let ((distance
          (wl.max (wl.abs (- (wl.actor-tilex@ actor) (wl.player@ wl.PLAYER-TILEX)))
                  (wl.abs (- (wl.actor-tiley@ actor) (wl.player@ wl.PLAYER-TILEY))))))
    (if (wl.actor-check-line-player actor)
        (if (< (wl.us-rndt) (bit.shl wl.tics 3))
            (begin (wl.start-actor-shoot actor) true)
            (wl.ranged-boss-chase-start actor distance true))
        (wl.ranged-boss-chase-start actor distance false))))

(defn wl.ranged-boss-chase-start (actor distance dodge)
  (if (= (wl.actor-dir@ actor) 8)
      (begin
        (if dodge (wl.select-dodge-dir actor) (wl.select-chase-dir actor))
        (if (= (wl.actor-dir@ actor) 8)
            false
            (wl.ranged-boss-chase-move actor (* (wl.actor-speed@ actor) wl.tics)
                                       distance dodge)))
      (wl.ranged-boss-chase-move actor (* (wl.actor-speed@ actor) wl.tics)
                                 distance dodge)))

(defn wl.ranged-boss-chase-move (actor move distance dodge)
  (if (= move 0)
      true
      (if (< (wl.actor-distance@ actor) 0)
          (let ((door (- 0 (wl.actor-distance@ actor) 1)))
            (begin
              (wl.open-door door)
              (if (= (wl.door-action@ door) wl.DR-OPEN)
                  (begin
                    (wl.actor-distance! actor wl.TILEGLOBAL)
                    (wl.ranged-boss-chase-move actor move distance dodge))
                  false)))
          (if (< move (wl.actor-distance@ actor))
              (wl.move-obj actor move)
              (let ((remaining (- move (wl.actor-distance@ actor))))
                (begin
                  (wl.snap-actor-to-destination actor)
                  (cond ((< distance 4) (wl.select-run-dir actor))
                        (dodge (wl.select-dodge-dir actor))
                        (true (wl.select-chase-dir actor)))
                  (if (= (wl.actor-dir@ actor) 8)
                      false
                      (wl.ranged-boss-chase-move actor remaining distance dodge))))))))

(defn wl.snap-actor-to-destination (actor)
  (begin
    (wl.actor-x! actor (+ (bit.shl (wl.actor-tilex@ actor) wl.TILESHIFT)
                          (/ wl.TILEGLOBAL 2)))
    (wl.actor-y! actor (+ (bit.shl (wl.actor-tiley@ actor) wl.TILESHIFT)
                          (/ wl.TILEGLOBAL 2)))
    true))

(defn wl.t-chase (actor)
  (let ((line (wl.actor-check-line-player actor)))
    (if line
        (let ((distance (wl.max (wl.abs (- (wl.actor-tilex@ actor) (wl.player@ wl.PLAYER-TILEX)))
                                (wl.abs (- (wl.actor-tiley@ actor) (wl.player@ wl.PLAYER-TILEY))))))
          (let ((chance (if (or (= distance 0)
                                (and (= distance 1) (< (wl.actor-distance@ actor) 16384)))
                            300 (/ (bit.shl wl.tics 4) distance))))
            (if (< (wl.us-rndt) chance)
                (wl.start-actor-shoot actor)
                (wl.chase-start actor true))))
        (wl.chase-start actor false))))

(defn wl.chase-start (actor dodge)
  (if (= (wl.actor-dir@ actor) 8)
      (begin
        (if dodge (wl.select-dodge-dir actor) (wl.select-chase-dir actor))
        (if (= (wl.actor-dir@ actor) 8) false
            (wl.chase-move actor (* (wl.actor-speed@ actor) wl.tics) dodge)))
      (wl.chase-move actor (* (wl.actor-speed@ actor) wl.tics) dodge)))

(defn wl.start-actor-shoot (actor)
  (begin
    (wl.actor-phase! actor wl.ACTOR-SHOOT)
    (wl.actor-ticcount! actor (car (wl.shoot-times (wl.actor-class@ actor))))))

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

;;; WL_STATE.C SelectRunDir deliberately has no old-direction/turnaround case.
;;; It first tries the two cardinals directly away from the player, then the
;;; exact north..west or west..north search selected by one RNG byte.
(defn wl.select-run-dir (actor)
  (let ((dx (- (wl.player@ wl.PLAYER-TILEX) (wl.actor-tilex@ actor)))
        (dy (- (wl.player@ wl.PLAYER-TILEY) (wl.actor-tiley@ actor))))
    (let ((xdir (if (< dx 0) 0 4)) (ydir (if (< dy 0) 6 2)))
      (if (> (wl.abs dy) (wl.abs dx))
          (wl.select-run-tries actor ydir xdir)
          (wl.select-run-tries actor xdir ydir)))))

(defn wl.select-run-tries (actor first second)
  (if (wl.try-chase-dir actor first)
      true
      (if (wl.try-chase-dir actor second)
          true
          (if (> (wl.us-rndt) 128)
              (wl.select-run-search actor 2 1)
              (wl.select-run-search actor 4 -1)))))

(defn wl.select-run-search (actor dir step)
  (if (if (= step 1) (> dir 4) (< dir 2))
      (begin (wl.actor-dir! actor 8) false)
      (if (wl.try-chase-dir actor dir)
          true
          (wl.select-run-search actor (+ dir step) step))))

(defn wl.diagonal-dir (xdir ydir)
  ;; WL_STATE.C indexes the symmetric diagonal[9][9] table after independently
  ;; swapping its horizontal/vertical preferences. These inputs are always
  ;; perpendicular cardinals; their circular midpoint is the source diagonal.
  (if (= (wl.abs (- xdir ydir)) 6) 7 (/ (+ xdir ydir) 2)))

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
  (if (wl.walk-blocked? actor dir oldx oldy x y)
      false
      ;; Source CHECKSIDE classifies doors from actorat, whose marker is
      ;; cleared once a door is fully open.  tilemap remains render geometry.
      (let ((marker (wl.actorat-wall@ x y)))
        (begin
          (wl.actor-tilex! actor x)
          (wl.actor-tiley! actor y)
          (if (wl.door-tile? marker)
              (begin
                (wl.open-door (wl.door-number marker))
                (wl.actor-distance! actor (- 0 (wl.door-number marker) 1)))
              (begin
                (wl.actor-area! actor (wl.area-at x y))
                (wl.actor-distance! actor wl.TILEGLOBAL)))
          true))))

(defn wl.walk-blocked? (actor dir oldx oldy x y)
  (if (or (< x 0) (or (> x 63) (or (< y 0) (> y 63))))
      true
      (if (= (wl.actor-class@ actor) 2)
        false
        (if (or (= dir 1) (or (= dir 3) (or (= dir 5) (= dir 7))))
            (or (wl.walk-diagonal-blocked? x y)
                (or (wl.walk-diagonal-blocked? x oldy)
                    (wl.walk-diagonal-blocked? oldx y)))
            (if (or (= (wl.actor-class@ actor) 6)
                    (= (wl.actor-class@ actor) wl.FAKEOBJ))
                (wl.walk-diagonal-blocked? x y)
                (wl.walk-side-blocked? x y))))))

(defn wl.walk-owner-blocks? (owner)
  (if (= owner 0)
      false
      (let ((actor (- owner 1)))
        (if (or (< actor 0) (>= actor wl.actorcount))
            true
            (> (bit.and (wl.actor-flags@ actor) wl.FL-SHOOTABLE) 0)))))

(defn wl.walk-diagonal-blocked? (x y)
  (let ((tile (wl.tilemap@ x y)) (marker (wl.actorat-wall@ x y)))
    (or (and (> tile 0)
             (not (and (wl.door-tile? tile) (= marker 0))))
        (or (> marker 0)
            (wl.walk-owner-blocks? (wl.actorat@ x y))))))

(defn wl.walk-side-blocked? (x y)
  (let ((tile (wl.tilemap@ x y)) (marker (wl.actorat-wall@ x y)))
    (or (and (> tile 0) (not (wl.door-tile? tile)))
        (or (and (> marker 0) (not (wl.door-tile? marker)))
            (wl.walk-owner-blocks? (wl.actorat@ x y))))))

(defn wl.move-obj (actor move)
  (let ((dir (wl.actor-dir@ actor))
        (oldx (wl.actor-x@ actor)) (oldy (wl.actor-y@ actor)))
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
      (if (and (wl.area-active? (wl.actor-area@ actor))
               (and (<= (wl.abs (- (wl.actor-x@ actor) (wl.player@ wl.PLAYER-X)))
                        wl.TILEGLOBAL)
                    (<= (wl.abs (- (wl.actor-y@ actor) (wl.player@ wl.PLAYER-Y)))
                        wl.TILEGLOBAL)))
          (begin
            (if (= (wl.actor-class@ actor) wl.GHOSTOBJ)
                (wl.take-damage (* wl.tics 2) actor) nil)
            (wl.actor-x! actor oldx)
            (wl.actor-y! actor oldy)
            false)
          (begin
            (wl.actor-distance! actor (- (wl.actor-distance@ actor) move))
            true)))))

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
