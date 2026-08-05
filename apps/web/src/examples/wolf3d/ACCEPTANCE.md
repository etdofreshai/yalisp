# Wolf3D YALisp visual acceptance contract

The original executable is the behavior and visual oracle. The YALisp port
copies original quirks rather than correcting them.

## Reference frame rule

Compare source and port captures at the native **320x200** framebuffer before
browser scaling, with the same episode, level, skill, game tick, deterministic
input replay, and original data files. Do not crop, resample, blur, or apply a
display shader before comparison.

## Screenshot pass rule

A candidate frame passes when all of the following are true:

1. At least **95%** of pixels have every RGB channel within 8 levels of the
   original pixel.
2. Mean absolute RGB-channel error across the complete frame is at most 10.
3. No unapproved connected mismatch region occupies more than 5% of the frame.
   This prevents a correct background from hiding a misplaced view, HUD, menu,
   or sprite.
4. Palette-indexed output should be compared exactly whenever the port is using
   the original VGA palette; the tolerance exists only for browser conversion
   boundaries.

Every mismatch mask and reference image is retained with the run, not merely a
single similarity score.

## Required checkpoints

- Title/menu and a fresh level start.
- Stationary view in each cardinal direction.
- Movement, wall collision, door use, and secret exit.
- Weapon idle, attack, enemy sighting, damage, pickup, HUD, intermission, and
  victory screens.
- Any original bug reproduced by a deterministic replay is an expected result,
  not an exception to be smoothed away.

## State and audio follow-up

When the original trace runner is unblocked, position, direction, health, ammo,
map state, and RNG-relevant state become tick-exact gates before a screenshot is
accepted. Audio validation uses the same replay and compares event order,
sample start tick, and PCM output after device-format conversion.
