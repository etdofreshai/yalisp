# Wolf3D YALisp port

This directory contains the game-owned YALisp source for the Wolf3D port. It is
executed by the generic YALisp application host; no Wolf3D rules or rendering
decisions belong in that host.

This is the canonical runnable browser package. Its 23 Lisp modules, asset
declaration, acceptance contract, OPL adapter, R0 normalized-audio adapter, and
route-independent canonical normalized-audio adapter are promoted byte-for-byte
from the source-port repository and pinned by
`wolf3d-promotion.manifest.json`. `wolf3d-mirror.test.mjs` verifies that source
payload while this README records the deployment-owned browser integration.
The current 23-module source-manifest SHA-256 is
`47066d293248c81ea4dd14ed02600a41d646cdd02be1bec7449382c8c961d9b6`;
the pinned `app.lisp` SHA-256 is
`c9855c4f1c00013f02cefc0713479794402a0633176088d6abc6d28f85504b65`,
and the pinned `wl-sound.lisp` SHA-256 is
`508afe6fce4ecc3277764fd850c16395a5ee9922856b4d581b0360fccdd8a9cf`.

YALisp does not currently provide a language-level `require`/`load` form or an
installed `yalisp` shell executable. The supported native command-line path is
Node 22 driving the checked-in `yalisp/apps/web/public/yalisp/seed.wasm`, the
same ABI used by YALisp's documented Hello World CLI. The Wolf package is
loaded as separate evaluator inputs in this source-owned order:

```text
wl-def wl-fixed id-ca id-pm id-vl id-vh wl-main wl-game wl-agent wl-act2
wl-state wl-act1 wl-play wl-audio wl-sound wl-text wl-inter wl-menu wl-config
wl-save wl-draw wl-scale app
```

`app.startup` verifies the required public functions and mounted assets before
starting. A missing module API or either missing audio file returns `false`
with `app.runtime-failure` set; it never selects a partial replacement.
`app.attach` is the generic browser/Node startup callback, while `app.advance`,
`app.present`, and `app.shutdown` own tick, presentation, and one-time shutdown
boundaries. The declared immutable inputs now include `AUDIOHED.WL6` and
`AUDIOT.WL6` alongside the existing map, VSWAP, VGA graphics, and palette
inputs.

## Deployment licensing decision

The browser audio host currently depends on `@malvineous/opl`, whose package
metadata declares GPL-3.0. Before distributing a production image, the
deployment owner must decide and document the required notices and source-code
availability for that combined distribution. This note records an unresolved
deployment review item; it is not a legal conclusion and does not substitute
for appropriate licensing review.

Mounted article text remains in its canonical Huffman-expanded DOS byte form.
`T_HELPART` expands directly into a persistent 30,000-byte buffer and is
scanned and drawn in heap-rewound batches; production startup does not convert
the 13,766-byte document into a Lisp string. The shipped help article has 41
pages, a terminal `^E` at byte 13,764, and 18 ordered picture references. All
six episode `ENDART` chunks use the same bytes-native lifecycle. Small Lisp
strings remain supported only for bounded layout fixtures. Missing or malformed
`^E`, `^G`, and `^T` commands and documents above 30,000 bytes fail closed.

The current package is a source-shaped gameplay/runtime slice,
not a complete port or a parity claim. It decodes the original map and wall-page
inputs, runs SpawnDoor and the position/action/ticcount door state machine, and
produces a Lisp-owned indexed framebuffer. Its initial play-screen path also
decodes STRUCTPIC and STATUSBARPIC directly from the original VGAHEAD,
VGAGRAPH, and VGADICT files, converts the original four VGA planes to indexed
rows, and preserves that static 320x40 image below every 160-row refresh. The
source-shaped latch-picture path now draws and updates the living non-SPEAR
face from health and faceframe. At zero health it retains the enemy passed to
`TakeDamage`, draws `FACE8APIC` for an ordinary attacker or `MUTANTBJPIC` for
the `needleobj` class, and preserves the original unconditional
`LastAttacker` dereference as a fail-closed unset-attacker boundary. It draws
`DrawHealth` through the original
right-justified three-cell `LatchNumber(21,16,3,health)` arithmetic, then
`DrawLives` at `(14,16)` and non-SPEAR `DrawLevel` at `(2,16)` with the raw
`map+1` value. It next draws and updates `DrawAmmo` with the original
right-justified two-cell `LatchNumber(27,16,2,ammo)` arithmetic, draws both
`DrawKeys` slots in gold-then-silver order from raw key bits zero and one,
draws the non-SPEAR status weapon with the original unguarded
`KNIFEPIC + weapon` selection arithmetic, and finally draws and updates
`DrawScore` with the original right-justified six-cell
`LatchNumber(6,16,6,score)` arithmetic. The numeric conversion retains the
original visible-minus bug: `'-'-'0'+N_0PIC` selects GOLDKEYPIC. Got-gatling,
SPEAR-only and other special faces remain intentionally absent.

The Lisp package now directly parses the shipped `PlayDemo` byte layout and
preserves signed controls, `DEMOTICS=4`, button bits, and the source rule that
the final command executes after `ex_completed` is set. It also owns the
non-SPEAR GameLoop map transitions for normal completion, secret entry/return,
death reset, and victory state. A source-shaped control-panel state layer owns
startup/menu/play/shutdown phases, sound/music/device option selections,
control toggles, the 4..19 view-size choice, article/high-score execution, and
indexed menu rasterization. Presentation-font caching occurs before transient
draw marks so control-panel-first and repeated article paths retain a valid
12,314-byte font buffer.

`SaveTheGame`/`LoadTheGame` now round-trip the current mid-level state through a
Lisp byte buffer, including the 68-byte gamestate layout, all eight non-SPEAR
`LevelRatios` rows, player, maps, areas, actors, statics, doors, and pushwall
state. The original adjacent-byte XOR checksum coverage and corrupt-save
penalty are retained; structurally invalid buffers reject before mutation.
Because named stage-05
file bindings remain contract-only, the DOS file handle is unavoidably
translated to an in-memory buffer; pointer-linked DOS actors are serialized as
the port's complete structure-of-arrays actor representation. This buffer is
therefore semantic port state, not a byte-compatible `SAVEGAM?.WL6` artifact.

Malformed graphics diagnostics are fail-closed traps. The seed has no
language-level error recovery or unwind protection, so caught corruption tests
inspect the already-written prefix and unchanged cache with an explicit
test-harness heap rewind; they do not claim that an application session can
recover from a corrupt mounted asset. Current mounted assets are immutable, and
successful status refreshes are the path covered by the heap-bounded contract.

The application also exposes a narrow `wolf3d-trace-bin-v3` field projection
for canonical R1 replay. It directly consumes recorded `tics`, `controlx`,
`controly`, and button bits, and reports the 44 fields currently owned by this
port: time and input, player and game state, level-progress totals and counters,
pushwall state, the door checksum, the deterministic random-table cursor, and
map-plane hashes plus live `actorhash` and static-and-door `worldhash`. All 44
fields match the retained 401-record R1 route. `actorhash` is produced from the
live player/enemy storage in source order rather than supplied by a fixture or
host. The mounted native D1 route matches all 691 retained records across all
44 fields in one session, with an equal post-chunk heap watermark and canonical
`nil` exhaustion at the exact declared demo boundary. Cursor parity establishes
only the random consumers reached by the verified routes; this is not yet a
claim of complete D1/R0-R5 parity. The remaining R0-R5 tick gates and the
complete native-frame, lifecycle, and normalized-audio matrix remain open until
their fail-closed gates finish.

The audio manager decodes original AUDIOHED/AUDIOT chunks and VSWAP digitized
pages, owns source device fallback, priority, positioning, timer state, and
event ordering, and keeps the existing `GetBonus` decision log. The native
application callbacks export normalized 49,716 Hz mono PCM16/WAV for
PC-speaker and Sound Blaster events. AdLib sound/music exports an OPL register
stream and deliberately returns no PCM rather than fabricating silence. The
checked-in `yalisp-opl-audio-host.mjs` adapter consumes persistent 140 Hz SFX
and monotonic 700 Hz music register logs through live OPL sinks, and renders
PC/Sound Blaster source PCM into 44.1 kHz stereo host buffers. Missing OPL or
playback dependencies remain explicit unavailable results. Portal playback and
a complete replay audio comparison are not claimed here.

The checked-in `yalisp-canonical-normalized-audio-host.mjs` consumes the
source-owned absolute 7,000 Hz operation program exported by
`app.audio-operation-program-export` and renders both OPL lanes plus native PCM
into the exact 49,716 Hz mono comparison profile. It requires an explicit,
untrimmed window and treats injected OPL devices as diagnostic rather than
authoritative. Native payload tails crossing the explicit comparison window are
clipped at that boundary and reported through `clippedNativeTails`.

The focused native integration command is:

```sh
node --test tools/verify-yalisp-runtime-integration.test.mjs
```

It loads the real checked-in seed binary, proves missing APIs/assets fail
closed, mounts the original files, and exercises lifecycle, the exact 691-row
D1 44-field trace and demo boundary, 320x200 indexed-frame, bytes-native
HELP/END articles, repeated article and high-score frames, persistent audio
logs, PCM/WAV, demo recording, and shutdown boundaries.
`tools/verify-yalisp-full-port.test.mjs` and
`tools/verify-yalisp-key-pickup.test.mjs` remain the current gameplay/save/HUD
regression gates. These tests are application integration evidence; the D1
tick projection is complete, while the remaining R0-R5 tick and oracle
screenshot/audio matrix is still required to close G4.

The application routes live controls through `PollControls` buttonstate and
buttonheld arrays, dispatches `T_Player`/`T_Attack`, and decodes packed replay
button bits into those same arrays before each replay tick. Live demo recording
samples immediately after `PollControls`, preserves the source 4-byte header
and fixed 3-byte command cadence, and exposes the exact finished byte buffer.
Rendered play frames update the active positioned sound once before refresh.

Static storage now follows the non-SPEAR `statinfo` table rather than keeping a
bonus-only subset. `SetupGameLevel` retains every dressing, blocking, and bonus
entry in map-scan order, including each entry's source shapenum, flags, and
itemnumber plus blocking `actorat` occupancy. Pickup removal changes only the
shapenum to -1; flags and itemnumber remain in the reusable source slot. This
reproduces all 121 E1M1 static records and the record-366 clip transition while
feeding `worldhash` directly from the five live fields of every static followed
by the six live fields of every door in source order. The 32-bit hash uses the
source's multiply-by-33/XOR operation without fixture or host substitution.
`InitStaticList` rewinds the live count without clearing those backing rows,
matching the source pointer reset; a dressing or blocking spawn therefore
retains the reused row's prior `itemnumber`, an observable original quirk.

## Persistent-effect and transient-export boundary

The seed remains a sharp bump allocator: `heap.release` does not discover
roots and must never rewind an application mutation. Host-facing R0-R4
mutators therefore expose `-persistent` names, while snapshots and copied byte
payloads expose `-export` names and are the only calls enclosed by host
mark/release pairs. Compatibility entry points remain available to ordinary
application callers.

R1 authority uses an R1-local begin/export/commit stream for all 401 trace
rows. The host compares each copied row before commit, while legacy callers
retain the original list-owning transaction in a separate mode. Sparse frame
records 13 through 130 use a render token and copy the already-rendered current
frame exactly once; a due frame blocks the next streamed tick until that copy
is committed. The producer fixes the evaluator at 240 MiB, preallocates render
storage before replay, and samples every transient scope plus clean ownership
against a 64 MiB minimum headroom.

R2 uses an explicit begin/export/commit transaction for each of its 2,875
ticks. A trace row is exported and released only after the begin effect is
owned; a render token is committed only after one balanced render; the 26
selected framebuffer copies are separately persistent. The non-authoritative
real-seed regression is
`tools/verify-yalisp-persistent-streaming-real-seed.test.mjs`. Its pinned
240 MiB measurement is 45 heap checks with zero regressions, final 59-row and
251-row windows of 2,926,480 and 9,057,124 bytes, final/max clean-owned use of
94,375,592 bytes, and final/min clean-owned remaining capacity of 157,151,576
bytes. The same harness proves the 298/1,490 R0 audio-service window, R3
save/load survival, R4 presentation survival, and the intentional
dangling-global negative control without reading or writing acceptance ledgers.
