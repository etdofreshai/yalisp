;;; WL_MAIN.C - BuildTables, ported to YALISP.
;;;
;;;   void BuildTables (void)
;;;   {
;;;     //
;;;     // calculate fine tangents
;;;     //
;;;     for (i=0;i<FINEANGLES/8;i++)
;;;     {
;;;       tang = tan( (double)(i+0.5)/radtoint);
;;;       finetangent[i] = tang*TILEGLOBAL;
;;;       finetangent[FINEANGLES/4-1-i] = 1/tang*TILEGLOBAL;
;;;     }
;;;     //
;;;     // costable overlays sintable with a quarter phase shift
;;;     // ANGLES is assumed to be divisable by four
;;;     //
;;;     angle = 0;
;;;     anglestep = PI/2/ANGLEQUAD;
;;;     for (i=0;i<=ANGLEQUAD;i++)
;;;     {
;;;       value=GLOBAL1*sin(angle);
;;;       sintable[i]= value;
;;;       sintable[i+ANGLES]= value;
;;;       sintable[ANGLES/2-i] = value;
;;;       *((long *)&sintable[ANGLES-i]) = value|0x80000000l;
;;;       *((long *)&sintable[ANGLES/2+i]) = value|0x80000000l;
;;;       angle += anglestep;
;;;     }
;;;   }
;;;
;;; radtoint is FINEANGLES/2/PI, so (i+0.5)/radtoint is the angle half a fine
;;; unit past index i. The tangent's reciprocal half of the table is not a
;;; separate quantity: index FINEANGLES/4-1-i is the complement of index i, so
;;; the whole table is tan((k+0.5) fine units) read as one array. It is filled
;;; here the way the original fills it, from both ends at once.
;;;
;;; The sign-magnitude quirk in the last two stores is discussed in
;;; wl-fixed.lisp; this port writes ordinary negatives, which multiply the same.
;;;
;;; Both tables are byte buffers of 32-bit words rather than lists, because the
;;; raycaster indexes them once per column and a list would make that a walk.

(define wl.finetangent (bytes.alloc 3600))   ;; FINEANGLES/4 longs
(define wl.sintable (bytes.alloc 1804))      ;; ANGLES+ANGLEQUAD+1 longs

(defn wl.finetangent@ (i) (i32@ wl.finetangent (* i 4)))
(defn wl.finetangent! (i v) (u32! wl.finetangent (* i 4) v))
(defn wl.sintable@ (i) (i32@ wl.sintable (* i 4)))
(defn wl.sintable! (i v) (u32! wl.sintable (* i 4) v))

;;; costable overlays sintable with a quarter phase shift.
(defn wl.costable@ (i) (wl.sintable@ (+ i wl.ANGLEQUAD)))

(defn wl.build-tables ()
  (begin (wl.build-finetangent 0) (wl.build-sintable 0)))

(defn wl.build-finetangent (i)
  (if (= i 450)
      i
      (wl.build-finetangent-at i (* (+ (* i 2) 1) fx.HALFFINE))))

(defn wl.build-finetangent-at (i angle)
  (begin
    (wl.finetangent! i (fx.tan16 angle))
    (wl.finetangent! (- 899 i) (fx.cotan16 angle))
    (wl.build-finetangent (+ i 1))))

(defn wl.build-sintable (i)
  (if (> i wl.ANGLEQUAD)
      i
      (wl.build-sintable-at i (bit.shr (fx.sin (* i fx.DEGREE)) 12))))

;;; GLOBAL1*sin(angle) is truncated into a long, so the working value is shifted
;;; from 2^28 down to 2^16 rather than rounded. WL_MAIN.C's angle and anglestep
;;; are float, however: its ninety accumulated float additions differ from the
;;; host-free fixed transcendental at exactly base indices 30 and 47. Preserve
;;; those two executable low words before the source's symmetric stores.
(defn wl.build-sintable-at (i value)
  (wl.build-sintable-value i
    (cond ((= i 30) 32767)
          ((= i 47) 47930)
          ((= value wl.GLOBAL1) (- wl.GLOBAL1 1))
          (true value))))

;;; BuildTables accumulates its float angle in ninety additions. At the
;;; quarter turn the published executable truncates a value just below 65536
;;; to 65535; the fixed transcendental lands on exactly 65536, so preserve the
;;; source table endpoint explicitly.
(defn wl.build-sintable-value (i value)
  (begin
    (wl.sintable! i value)
    (wl.sintable! (+ i wl.ANGLES) value)
    (wl.sintable! (- 180 i) value)
    (wl.sintable! (- wl.ANGLES i) (- 0 value))
    (wl.sintable! (+ 180 i) (- 0 value))
    (wl.build-sintable (+ i 1))))
