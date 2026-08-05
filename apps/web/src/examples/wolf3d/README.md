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
`controly`, and button bits, and reports only tick, player pose, sampled input,
door checksum, and map-plane hashes. All thirteen fields match the retained
401-record route after the object-plane patrol prerequisite reproduces the
off-route door operation. This remains a deliberately partial actor system:
actor chase/attack states, statics, game/HUD
state, pushwalls, `rndindex`, `actorhash`, and `worldhash` are explicitly
omitted. It is not a complete v3 trace or a claim of D1/R0-R5 parity.

The player loop owns WL_AGENT.C's `UpdateFace`, pistol attack cadence,
retained target selection, `CheckLine`, and damage semantics. Record 215 now
matches for the source reason: GunAttack finds no crosshair target and draws
nothing; its noise makes the area-2 guard's `SightPlayer` consume byte 221 and
schedule a 56-tic reaction. The cursor is exact through record 293. Record 294
is the next honest boundary, at the unimplemented `T_Chase` chance draw.
