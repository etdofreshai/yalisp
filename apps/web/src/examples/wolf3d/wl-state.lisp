;;; WL_STATE.C source-facing state and movement entry points. The compact seed
;;; representation stores state identity in actorphase and time in actorticcount;
;;; think/action dispatch remains Lisp-owned in wl.do-actor.
(define wl.ST-NONE 0)
(define wl.ST-PATH wl.ACTOR-CHASE)
(define wl.ST-SHOOT wl.ACTOR-SHOOT)
(define wl.ST-PROJECTILE wl.ACTOR-PROJECTILE)
(define wl.ST-DEAD wl.ACTOR-DEAD)

(defn wl.new-state (actor state tics)
  (begin
    (wl.actor-phase! actor state)
    (wl.actor-ticcount! actor tics)
    state))

(defn wl.spawn-new-obj (tilex tiley state tics)
  (if (= wl.actorcount wl.MAXACTORS)
      -1
      (let ((actor wl.actorcount))
        (begin
          (wl.spawn-actor-base tilex tiley 8 0 0 0 state 0)
          (wl.actor-ticcount! actor (if (= tics 0) 0 (mod (wl.us-rndt) tics)))
          (wl.actorat! tilex tiley (+ actor 1))
          actor))))

(defn wl.state-step (actor tics)
  (begin (set! wl.tics tics) (wl.do-actor actor)))

(defn wl.try-walk-state (actor) (wl.try-walk actor))
(defn wl.move-obj-state (actor move) (wl.move-obj actor move))
