;;; WL_ACT1.C action entry points over the compact state store. These names keep
;;; source actions independently fixtureable while sharing wl-act2 simulation.
(defn wl.t-stand (actor) (wl.sight-player actor))
(defn wl.t-path-action (actor) (wl.t-path actor))
(defn wl.t-chase-action (actor) (wl.t-chase actor))
(defn wl.t-shoot-action (actor) (wl.t-shoot actor))

(defn wl.t-bite (actor)
  (wl.t-bite-core actor))

(defn wl.a-hitler-morph (actor) (wl.hitler-morph actor))
(defn wl.a-start-death-cam (actor) (wl.start-death-cam actor))

;;; DropItem searches the center then the surrounding 3x3 in source x/y order.
(defn wl.drop-item (item tilex tiley)
  (if (not (wl.actorat-occupied? tilex tiley))
      (wl.spawn-static-item tilex tiley item)
      (wl.drop-item-x item (- tilex 1) (+ tilex 1) (- tiley 1) (+ tiley 1))))

(defn wl.drop-item-x (item x xh yl yh)
  (if (> x xh) -1
      (let ((placed (wl.drop-item-y item x yl yh)))
        (if (>= placed 0) placed (wl.drop-item-x item (+ x 1) xh yl yh)))))

(defn wl.drop-item-y (item x y yh)
  (if (> y yh) -1
      (if (and (>= x 0) (and (< x wl.MAPSIZE)
               (and (>= y 0) (and (< y wl.MAPSIZE)
                    (not (wl.actorat-occupied? x y))))))
          (wl.spawn-static-item x y item)
          (wl.drop-item-y item x (+ y 1) yh))))
