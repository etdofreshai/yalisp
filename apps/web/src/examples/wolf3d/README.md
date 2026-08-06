# Wolf3D YALisp port

This directory contains the game-owned YALisp source for the Wolf3D port. It is
executed by the generic YALisp application host; no Wolf3D rules or rendering
decisions belong in that host.

The canonical runnable browser package lives at
`apps/web/src/examples/wolf3d/` in the YALisp repository. Every non-AppleDouble
file in that directory is mirrored here byte-for-byte while the two repositories
remain independent. YALisp's `wolf3d-mirror.test.mjs` enforces both the complete
file set and file contents before either copy is committed.

The current package is a source-shaped wall-and-door raycaster slice,
not a complete port or a parity claim. It decodes the original map and wall-page
inputs, runs SpawnDoor and the position/action/ticcount door state machine, and
produces a Lisp-owned indexed framebuffer. Its initial play-screen path also
decodes STRUCTPIC and STATUSBARPIC directly from the original VGAHEAD,
VGAGRAPH, and VGADICT files, converts the original four VGA planes to indexed
rows, and preserves that static 320x40 image below every 160-row refresh. The
source-shaped latch-picture path now draws and updates the living non-SPEAR
face from health and faceframe, draws `DrawHealth` through the original
right-justified three-cell `LatchNumber(21,16,3,health)` arithmetic, then
`DrawLives` at `(14,16)` and non-SPEAR `DrawLevel` at `(2,16)` with the raw
`map+1` value. It next draws and updates `DrawAmmo` with the original
right-justified two-cell `LatchNumber(27,16,2,ammo)` arithmetic, draws both
`DrawKeys` slots in gold-then-silver order from raw key bits zero and one,
draws the non-SPEAR status weapon with the original unguarded
`KNIFEPIC + weapon` selection arithmetic, and finally draws and updates
`DrawScore` with the original right-justified six-cell
`LatchNumber(6,16,6,score)` arithmetic. The numeric conversion retains the
original visible-minus bug: `'-'-'0'+N_0PIC` selects GOLDKEYPIC. Dead and
special faces remain intentionally absent, and this status slice does not claim
key-pickup or audio call-graph parity. Actor collision and area/sound side
effects for doors, generalized sprites, menus, audio, saves, and full oracle
replay validation remain later gates.

Malformed graphics diagnostics are fail-closed traps. The seed has no
language-level error recovery or unwind protection, so caught corruption tests
inspect the already-written prefix and unchanged cache with an explicit
test-harness heap rewind; they do not claim that an application session can
recover from a corrupt mounted asset. Current mounted assets are immutable, and
successful status refreshes are the path covered by the heap-bounded contract.

The application also exposes a narrow `wolf3d-trace-bin-v3` field projection
for canonical R1 replay. It directly consumes recorded `tics`, `controlx`,
`controly`, and button bits, and reports the 43 fields currently owned by this
port: time and input, player and game state, level-progress totals and counters,
pushwall state, the door checksum, the deterministic random-table cursor, and
map-plane hashes plus the live static-and-door `worldhash`. All 43 fields match
the retained 401-record R1 route. This remains a deliberately partial actor
system: `actorhash` is explicitly omitted. Cursor parity establishes only the random
consumers reached by canonical R1; it is not all-route RNG completion, a
complete v3 trace, or a claim of D1/R0-R5 parity.

The player loop owns WL_AGENT.C's `UpdateFace`, pistol attack cadence,
retained target selection, `CheckLine`, and damage semantics. Record 215 matches
for the source reason: GunAttack finds no crosshair target and draws nothing;
its noise makes the area-2 guard's `SightPlayer` consume byte 221 and schedule
a 56-tic reaction. The implemented chase, shooting, and damage paths retain the
canonical random cursor through all 401 R1 records.

Static storage now follows the non-SPEAR `statinfo` table rather than keeping a
bonus-only subset. `SetupGameLevel` retains every dressing, blocking, and bonus
entry in map-scan order, including each entry's source shapenum, flags, and
itemnumber plus blocking `actorat` occupancy. Pickup removal changes only the
shapenum to -1; flags and itemnumber remain in the reusable source slot. This
reproduces all 121 E1M1 static records and the record-366 clip transition while
feeding `worldhash` directly from the five live fields of every static followed
by the six live fields of every door in source order. The 32-bit hash uses the
source's multiply-by-33/XOR operation without fixture or host substitution.
