;;; Fixed-point arithmetic for the Wolf3D port.
;;;
;;; Two different things live here, and it matters which is which.
;;;
;;; The first is the original's own fixed-point layer. Wolf3D's `fixed` is a
;;; 16.16 signed quantity and its multiply is FixedByFrac, written in assembly
;;; in ID's sources (WL_ASM.ASM / ID_ASM). fx.mul-shift is the evaluator's
;;; generic multiply-then-shift with a 64-bit intermediate, so the port's
;;; FixedByFrac is one call rather than a routine.
;;;
;;; The second is not in the original at all. BuildTables in WL_MAIN.C calls
;;; libm's sin and tan, and CalcProjection calls atan; there is no libm here
;;; and the tables are not going to be smuggled in as host data, so this file
;;; evaluates those functions in fixed point instead. That is a substitution
;;; and it is named as one: the tables' contents, layout, and use are the
;;; original's, and only the arithmetic that fills them is this port's.
;;;
;;; The working precision for the transcendentals is 2^28, not the game's
;;; 16.16. A fixnum in this evaluator carries 31 signed bits, so 2^28 is the
;;; largest binary point that still leaves room for the square of an argument
;;; up to pi/2 - and 16.16 is far too coarse to build finetangent, whose first
;;; entry is 57 and whose last is 75 million.

(define fx.FRACBITS 28)
(define fx.ONE 268435456)          ;; 1.0
(define fx.PI 843314857)           ;; pi
(define fx.DEGREE 4685083)         ;; pi/180, one degree of ANGLES
(define fx.HALFFINE 234254)        ;; pi/3600, half a fine angle
(define fx.FINE 468508)            ;; 2*pi/3600, one fine angle

;;; --- the original's fixed-point multiply ------------------------------------
;;;
;;; FixedByFrac(a,b) is a*b>>16. The original's version reads b as sign and
;;; magnitude rather than two's complement, which is why BuildTables stores a
;;; negative sine as `value|0x80000000` instead of negating it: sintable holds
;;; sign-magnitude, and sin(180 degrees) is therefore a negative zero. That
;;; representation is not expressible in a 31-bit fixnum, and it does not have
;;; to be: every table value has magnitude at most GLOBAL1, so the two readings
;;; agree everywhere except on negative zero, which multiplies to zero either
;;; way. The tables below hold ordinary negatives and say so.
;;;
;;; The assembly negates negative operands, multiplies their magnitudes, then
;;; reapplies the sign. Preserve that truncation toward zero explicitly rather
;;; than using an arithmetic right shift, which rounds a negative product down.
(defn fx.by-frac (a b)
  (if (< a 0)
      (if (< b 0)
          (fx.mul-shift (- 0 a) (- 0 b) 16)
          (- 0 (fx.mul-shift (- 0 a) b 16)))
      (if (< b 0)
          (- 0 (fx.mul-shift a (- 0 b) 16))
          (fx.mul-shift a b 16))))

;;; Multiplication at the working precision of this file.
(defn fx.mul (a b) (fx.mul-shift a b fx.FRACBITS))

;;; --- division to a 16.16 quotient -------------------------------------------
;;;
;;; floor(a*65536/b) for positive a and b. The product does not fit in a
;;; fixnum, so this is restoring division: the integer part first, then sixteen
;;; shift-and-subtract steps for the fraction. It is the one place the port
;;; needs a quotient whose numerator would overflow, and it is used only while
;;; the tables are being built.
(defn fx.div16 (a b) (fx.div16-loop (/ a b) (mod a b) b 16))

(defn fx.div16-loop (q r b n)
  (if (= n 0)
      q
      (fx.div16-step (* q 2) (* r 2) b n)))

(defn fx.div16-step (q r b n)
  (if (>= r b)
      (fx.div16-loop (+ q 1) (- r b) b (- n 1))
      (fx.div16-loop q r b (- n 1))))

;;; --- sine and cosine --------------------------------------------------------
;;;
;;; Taylor series in Horner form, for arguments in [0, pi/2], which is all the
;;; tables ever ask for:
;;;
;;;   sin x = x*(1 - u/6*(1 - u/20*(1 - u/42*(1 - u/72*(1 - u/110*(1 - u/156))))))
;;;   cos x =   (1 - u/2*(1 - u/12*(1 - u/30*(1 - u/56*(1 - u/90*(1 - u/132))))))
;;;
;;; with u = x*x. The first omitted term is x^15/15! for the sine and x^14/14!
;;; for the cosine; at pi/2 both are under a fiftieth of a unit at 2^28, so
;;; what remains is the rounding of the individual steps.
(defn fx.step (u d inner) (- fx.ONE (/ (fx.mul u inner) d)))

(defn fx.sin (x)
  (fx.sin-with x (fx.mul x x)))

(defn fx.sin-with (x u)
  (fx.mul x (fx.step u 6 (fx.step u 20 (fx.step u 42
             (fx.step u 72 (fx.step u 110 (fx.step u 156 fx.ONE))))))))

(defn fx.cos (x)
  (fx.cos-with (fx.mul x x)))

(defn fx.cos-with (u)
  (fx.step u 2 (fx.step u 12 (fx.step u 30
   (fx.step u 56 (fx.step u 90 (fx.step u 132 fx.ONE)))))))

;;; tan x as a 16.16 quantity, and its reciprocal. Both take the sine and the
;;; cosine at full working precision and divide once, so neither loses the
;;; other's accuracy: 1/tan(0.05 degrees) is 75 million and a tangent rounded
;;; to 16.16 first would carry a whole percent of error into it.
(defn fx.tan16 (x) (fx.div16 (fx.sin x) (fx.cos x)))
(defn fx.cotan16 (x) (fx.div16 (fx.cos x) (fx.sin x)))
