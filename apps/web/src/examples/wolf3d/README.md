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
produces a Lisp-owned indexed framebuffer. Actor collision and area/sound side
effects for doors, actors, sprites, menus, HUD, audio, saves, and full oracle
replay validation remain later gates.

The application also exposes a narrow `wolf3d-trace-bin-v3` field projection
for canonical R1 replay. It directly consumes recorded `tics`, `controlx`,
`controly`, and button bits, and reports the 42 fields currently owned by this
port: time and input, player and game state, level-progress totals and counters,
pushwall state, the door checksum, the deterministic random-table cursor, and
map-plane hashes. All 42 fields match the retained 401-record R1 route. This
remains a deliberately partial actor and world system: `actorhash` and
`worldhash` are explicitly omitted. Cursor parity establishes only the random
consumers reached by canonical R1; it is not all-route RNG completion, a
complete v3 trace, or a claim of D1/R0-R5 parity.

The player loop owns WL_AGENT.C's `UpdateFace`, pistol attack cadence,
retained target selection, `CheckLine`, and damage semantics. Record 215 matches
for the source reason: GunAttack finds no crosshair target and draws nothing;
its noise makes the area-2 guard's `SightPlayer` consume byte 221 and schedule
a 56-tic reaction. The implemented chase, shooting, and damage paths retain the
canonical random cursor through all 401 R1 records.
