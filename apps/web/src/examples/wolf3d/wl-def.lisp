(heap.reserve 62000000)

(define wl.EXITTILE 99)
(define wl.PUSHABLETILE 98)
(define wl.AREATILE 107)
(define wl.NUMAREAS 37)
(define wl.ELEVATORTILE 21)
(define wl.AMBUSHTILE 106)
(define wl.ALTELEVATORTILE 107)

(defn wl.solid? (tile) (< tile wl.AREATILE))
(defn wl.area-number (tile) (- tile wl.AREATILE))

(define wl.PLAYERSTART-FIRST 19)
(define wl.PLAYERSTART-LAST 22)
(defn wl.player-start? (tile)
  (and (>= tile wl.PLAYERSTART-FIRST) (<= tile wl.PLAYERSTART-LAST)))

(define wl.DOORTILE-FIRST 90)
(define wl.DOORTILE-LAST 101)
(defn wl.door? (tile)
  (and (>= tile wl.DOORTILE-FIRST) (<= tile wl.DOORTILE-LAST)))

(define wl.GLOBAL1 65536)
(define wl.TILEGLOBAL 65536)
(define wl.TILESHIFT 16)
(define wl.MINDIST 22528)
(define wl.FOCALLENGTH 22272)
(define wl.VIEWGLOBAL 65536)
(define wl.PLAYERSIZE 22528)

(define wl.MAPSHIFT 6)
(define wl.MAPSIZE 64)
(define wl.MAPAREA 4096)

(define wl.ANGLES 360)
(define wl.ANGLEQUAD 90)
(define wl.FINEANGLES 3600)
(define wl.ANG90 900)
(define wl.ANG180 1800)
(define wl.ANG270 2700)
(define wl.ANG360 3600)

;; controldir_t. SpawnPlayer reads it out of the object plane, and it is also
;; what Cmd_Use hands to PushWall, so the two uses share one enum as in the
;; original; it is not the eight-way dirtype the actors walk with.
(define wl.NORTH 0)
(define wl.EAST 1)
(define wl.SOUTH 2)
(define wl.WEST 3)

(define wl.SCREENWIDTH 320)
(define wl.SCREENHEIGHT 200)
(define wl.STATUSLINES 40)
(define wl.viewwidth 320)
(define wl.viewheight 160)

(define wl.MOVESCALE 150)
(define wl.BACKMOVESCALE 100)
(define wl.ANGLESCALE 20)
(define wl.BASEMOVE 35)
(define wl.RUNMOVE 70)

(define wl.tics 6)
