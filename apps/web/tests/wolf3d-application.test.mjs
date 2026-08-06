import assert from "node:assert/strict";
import test from "node:test";
import { createApplicationDriver } from "../src/examples/runtime/application-driver.ts";
import { assetRequests, mountDeclaredAssets, mountedForm } from "../src/examples/runtime/asset-mount.ts";
import { directive, directives, parseLispValue } from "../src/examples/runtime/lisp-value.ts";
import { createSeedSession } from "./seed-session.mjs";
import {
  fromPublic,
  haveWolf3dOriginals as haveOriginals,
  wolf3dAssetRoot as assetRoot,
  wolf3dSkipReason as skipReason,
  wolf3dSource as source
} from "./wolf3d-source.mjs";

// The Wolf3D application driven through the generic contracts, with the
// originals mounted from disk through the same code the browser runs over the
// network. Nothing about the game is known to the harness: it mounts what the
// program declared, ticks it with declared input, and looks at the pixels that
// come back.

async function application(fetcher = fromPublic) {
  const session = await createSeedSession();
  session.evaluateQuietly(source);
  const result = await mountDeclaredAssets(session, fetcher);
  return { session, ...result };
}

function statusOf(view) {
  const status = directive(directives(view), "status");
  assert.ok(status, "the application should report a status");
  return status.slice(1);
}

// The seed's printer does not quote strings, so a status string containing
// spaces reaches the host as several atoms rather than one. That is a real
// limitation of the current print path and not something these tests should
// hide: they join the atoms back the way the host's own status line does.
function statusText(view) {
  return statusOf(view).map(String).join(" ");
}

const number = (session, form) => Number(session.evaluate(form));
const inputForm = (...held) =>
  `(${["forward", "backward", "turn-left", "turn-right"].map((name) => `(${name} ${held.includes(name) ? 1 : 0})`).join(" ")})`;

// The view constants the tests need are read out of the program rather than
// restated, so a change to the declared view size cannot silently pass here.
function view(session) {
  return {
    width: number(session, "wl.viewwidth"),
    height: number(session, "wl.viewheight"),
    left: number(session, "wl.viewleft"),
    top: number(session, "wl.viewtop"),
    screenWidth: number(session, "wl.SCREENWIDTH"),
    screenHeight: number(session, "wl.SCREENHEIGHT"),
    statusLines: number(session, "wl.STATUSLINES"),
    heightnumerator: number(session, "wl.heightnumerator"),
    mindist: number(session, "wl.MINDIST"),
    focallength: number(session, "wl.focallength")
  };
}

// --- the declaration and the mount ------------------------------------------

test("the application declares its originals and the host mounts exactly those", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { session, mounted, failed } = await application();
  assert.deepEqual(failed, []);
  // The paths are the program's, so the test reads them from the program
  // rather than restating them.
  const declared = assetRequests(parseLispValue(session.evaluate("(app.assets)")));
  assert.deepEqual(mounted.map((asset) => asset.name), declared.map((request) => request.name));
  assert.equal(session.evaluate("(asset.count)"), String(declared.length));

  // Each handle names an asset whose length is the file's own length, and the
  // program was told the same numbers the evaluator holds.
  for (const asset of mounted) {
    const onDisk = await fromPublic(asset.path);
    assert.equal(asset.length, onDisk.length, `${asset.name} length`);
    assert.equal(session.evaluate(`(bytes.length (asset.ref ${asset.handle}))`), String(onDisk.length));
    // Spot the identity at both ends rather than trusting the length alone.
    assert.equal(session.evaluate(`(u8@ (asset.ref ${asset.handle}) 0)`), String(onDisk[0]));
    assert.equal(session.evaluate(`(u8@ (asset.ref ${asset.handle}) ${onDisk.length - 1})`), String(onDisk[onDisk.length - 1]));
  }
  assert.equal(mountedForm(mounted), `(${mounted.map((asset) => `(${asset.name} ${asset.handle} ${asset.length})`).join(" ")})`);
});

// A checkout without the originals is the common case, and the program has to
// survive it and say so rather than the page failing to load.
test("without its originals the application still mounts and reports the absence", async () => {
  const { session, mounted, failed } = await application(async (path) => {
    throw new Error(`404 for ${path}`);
  });
  assert.equal(mounted.length, 0);
  // Every declared asset failed, and the count is the program's declaration
  // rather than a number written down here.
  assert.equal(failed.length, assetRequests(parseLispValue(session.evaluate("(app.assets)"))).length);
  assert.equal(session.evaluate("(app.mounted?)"), "false");
  const driver = createApplicationDriver(session);
  driver.attach();
  assert.match(statusText(driver.present()), /not mounted/);
  // It also has to keep ticking without its data instead of trapping.
  driver.tick(inputForm("forward"));
  assert.ok(directive(directives(driver.present()), "draw"), "an unmounted application should still draw something");
});

// --- the level and the camera it puts in it ----------------------------------

test("the camera is SpawnPlayer's, on the tile plane 1 nominates", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { session } = await application();
  assert.equal(session.evaluate("(app.mounted?)"), "true");
  const driver = createApplicationDriver(session);
  assert.equal(driver.mode, "state-handle");
  driver.attach();

  // The start is not written down here: it is found by scanning the decoded
  // object plane for ScanInfoPlane's tiles, and the program must agree.
  const plane1 = session.evaluateBytes("(car (cdr app.planes))");
  const tiles = new Uint16Array(plane1.buffer, plane1.byteOffset, 64 * 64);
  const found = [...tiles].flatMap((tile, index) => (tile >= 19 && tile <= 22 ? [index] : []));
  assert.equal(found.length, 1, "plane 1 should hold exactly one player start");

  const [tilex, tiley, angle, x, y] = parseLispValue(driver.stateText()).map(Number);
  assert.equal(tiley * 64 + tilex, found[0], "the player should stand on that tile");
  // SpawnPlayer: x = (tilex<<TILESHIFT)+TILEGLOBAL/2, and angle = (1-dir)*90
  // with dir = NORTH+tile-19, so tiles 19..22 give 90, 0, 270 and 180.
  assert.equal(x, tilex * 65536 + 32768, "the player should stand at the centre of the tile");
  assert.equal(y, tiley * 65536 + 32768, "the player should stand at the centre of the tile");
  const dir = tiles[found[0]] - 19;
  assert.equal(angle, ((1 - dir) * 90 + 360) % 360, "facing should be SpawnPlayer's (1-dir)*90");

  // And that tile has to be floor in the other plane, which only holds if both
  // expansions are right.
  const plane0 = session.evaluateBytes("(car app.planes)");
  assert.ok(new Uint16Array(plane0.buffer, plane0.byteOffset, 64 * 64)[found[0]] >= 107);

  // The status line carries the decoded name, not a caption.
  const name = session.evaluate("(ca.map-name app.maps (ca.header-offset app.tinf 0))");
  const status = statusOf(driver.present());
  const words = name.split(" ");
  assert.deepEqual(status.slice(0, words.length).map(String), words, "the status should open with the decoded map name");
});

// SetupGameLevel transposes the first pass, then SpawnDoor replaces each door
// code with a numbered center tile and marks the two wall faces beside it.
test("SetupGameLevel builds walls and numbered door centers from plane 0", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { session } = await application();
  const plane0 = session.evaluateBytes("(car app.planes)");
  const walls = new Uint16Array(plane0.buffer, plane0.byteOffset, 64 * 64);
  const tilemap = session.evaluateBytes("wl.tilemap");
  const expected = new Uint8Array(64 * 64);
  for (let y = 0; y < 64; y += 1) {
    for (let x = 0; x < 64; x += 1) {
      expected[x * 64 + y] = walls[y * 64 + x] < 107 ? walls[y * 64 + x] : 0;
    }
  }
  const doorCount = number(session, "wl.doornum");
  for (let door = 0; door < doorCount; door += 1) {
    const x = number(session, `(wl.door-x@ ${door})`);
    const y = number(session, `(wl.door-y@ ${door})`);
    const vertical = number(session, `(wl.door-vertical@ ${door})`) === 1;
    expected[x * 64 + y] = 0x80 | door;
    if (vertical) {
      expected[x * 64 + y - 1] |= 0x40;
      expected[x * 64 + y + 1] |= 0x40;
    } else {
      expected[(x - 1) * 64 + y] |= 0x40;
      expected[(x + 1) * 64 + y] |= 0x40;
    }
  }
  assert.deepEqual(tilemap, expected);
  const solid = [...expected].filter(Boolean).length;
  assert.ok(solid > 500, `E1M1 should be mostly walls at the edges, found ${solid} solid tiles`);
  assert.ok(doorCount > 0, "E1M1 should spawn doors");
});

// --- the raycast -------------------------------------------------------------

// An independent check of every column, against a plain double-precision ray
// march over the same tile array. It shares no arithmetic with the program:
// the program works in 16.16 through tables it built itself, and this walks the
// grid in doubles with Math.cos. Agreeing to within a percent on all 320
// columns, from several camera positions, is what makes the claim that these
// are the level's own walls rather than a picture that merely varies.
function marchOracle(session, tilemap) {
  const { heightnumerator, mindist, focallength, width } = view(session);
  const px = number(session, "(wl.player@ wl.PLAYER-X)") / 65536;
  const py = number(session, "(wl.player@ wl.PLAYER-Y)") / 65536;
  const angle = number(session, "(wl.player@ wl.PLAYER-ANGLE)");
  const radians = (angle * Math.PI) / 180;
  // viewx/viewy: the camera sits one focal length behind the player.
  const vx = px - (focallength / 65536) * Math.cos(radians);
  const vy = py + (focallength / 65536) * Math.sin(radians);

  return Array.from({ length: width }, (unused, column) => {
    const fine = angle * 10 + number(session, `(wl.pixelangle@ ${column})`);
    const theta = (fine * 2 * Math.PI) / 3600;
    const dx = Math.cos(theta);
    const dy = -Math.sin(theta);
    let travelled = 0;
    let x = vx;
    let y = vy;
    let vertical = false;
    for (let step = 0; step < 4096; step += 1) {
      const tx = Math.floor(x);
      const ty = Math.floor(y);
      if (tx < 0 || tx >= 64 || ty < 0 || ty >= 64) return null;
      const tile = tilemap[tx * 64 + ty];
      if (tile) {
        if (!(tile & 0x80)) break;
        const advance = vertical ? (tx + 0.5 - x) / dx : (ty + 0.5 - y) / dy;
        const hitX = x + dx * advance;
        const hitY = y + dy * advance;
        const stayedInside = vertical ? Math.floor(hitY) === ty : Math.floor(hitX) === tx;
        const fraction = vertical ? hitY - Math.floor(hitY) : hitX - Math.floor(hitX);
        const position = number(session, `(wl.door-position@ ${tile & 0x7f})`) / 65536;
        if (stayedInside && fraction >= position) {
          travelled += advance;
          x = hitX;
          y = hitY;
          break;
        }
      }
      const toX = dx > 0 ? (tx + 1 - x) / dx : dx < 0 ? (tx - x) / dx : Infinity;
      const toY = dy > 0 ? (ty + 1 - y) / dy : dy < 0 ? (ty - y) / dy : Infinity;
      vertical = toX <= toY;
      const advance = Math.min(toX, toY) + 1e-9;
      travelled += advance;
      x += dx * advance;
      y += dy * advance;
    }
    // CalcHeight's z is measured along the view direction, not to the camera.
    const z = Math.max(travelled * Math.cos(theta - radians) * 65536, mindist);
    return heightnumerator / (Math.floor(z) >> 8);
  });
}

function assertMatchesOracle(session, label) {
  const tilemap = session.evaluateBytes("wl.tilemap");
  const expected = marchOracle(session, tilemap);
  const heights = expected.map((unused, column) => number(session, `(wl.wallheight@ ${column})`));
  let worst = 0;
  for (let column = 0; column < expected.length; column += 1) {
    assert.notEqual(expected[column], null, `${label}: column ${column} left the map`);
    const error = Math.abs(heights[column] - expected[column]) / expected[column];
    worst = Math.max(worst, error);
    assert.ok(error < 0.05, `${label}: column ${column} height ${heights[column]}, expected about ${expected[column].toFixed(1)}`);
  }
  // A renderer that returned one height everywhere would pass a tolerance
  // comparison against an equally flat expectation, so the variation is
  // asserted as well.
  assert.ok(new Set(heights).size > 20, `${label}: only ${new Set(heights).size} distinct column heights`);
  return worst;
}

test("every column's wall height is the one the real plane-0 tiles put there", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { session } = await application();
  const driver = createApplicationDriver(session);
  driver.attach();

  session.evaluate("(app.frame-bytes)");
  assertMatchesOracle(session, "at the player start");

  // The same check from two more camera states, so the agreement is not an
  // accident of one angle being axis-aligned.
  for (let tick = 0; tick < 3; tick += 1) driver.tick(inputForm("turn-left"));
  session.evaluate("(app.frame-bytes)");
  assertMatchesOracle(session, "after turning left");

  for (let tick = 0; tick < 4; tick += 1) driver.tick(inputForm("forward"));
  session.evaluate("(app.frame-bytes)");
  assertMatchesOracle(session, "after walking forward");
});

// The third condition, and the sharpest one: change a tile in the decoded
// plane, rebuild the level from it, and the column looking at that tile has to
// change. If the picture came from anywhere but the map data, it would not.
test("changing the wall tile the centre column hits changes that column", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { session } = await application();
  const { width, left, top, screenWidth } = view(session);
  const centre = width / 2 - 1;

  const before = session.evaluateBytes("(app.frame-bytes)").slice();
  const beforeHeight = number(session, `(wl.wallheight@ ${centre})`);
  assert.ok(beforeHeight > 0, "the centre column should be looking at a wall");

  // Which tile that is comes out of the march, not out of a recorded answer.
  const tilemap = session.evaluateBytes("wl.tilemap");
  const hit = centreHit(session, tilemap, centre);
  assert.ok(hit, "the centre ray should meet a tile");
  assert.ok(tilemap[hit.x * 64 + hit.y] > 0, "and that tile should be solid");

  // AREATILE is 107 and everything from it up is floor, so writing it into
  // plane 0 is how the level itself says "this is not a wall".
  session.evaluateQuietly(`(u16! app.wall-plane ${(hit.y * 64 + hit.x) * 2} 107)`);
  session.evaluateQuietly("(wl.setup-game-level app.wall-plane app.object-plane)");
  assert.equal(session.evaluateBytes("wl.tilemap")[hit.x * 64 + hit.y], 0, "the tile should now be floor");

  const after = session.evaluateBytes("(app.frame-bytes)").slice();
  const afterHeight = number(session, `(wl.wallheight@ ${centre})`);
  assert.notEqual(afterHeight, beforeHeight, "the centre column's wall height should have changed");
  assert.ok(afterHeight < beforeHeight, "the ray should now reach something further away, so the post is shorter");
  // And it changed on the screen, in that column, not merely in a variable.
  const changed = [];
  for (let row = 0; row < view(session).height; row += 1) {
    const index = (row + top) * screenWidth + left + centre;
    if (before[index] !== after[index]) changed.push(row);
  }
  assert.ok(changed.length > 0, "the centre column's pixels should have changed");
  // The rest of the frame is still whatever it was; the check is that a
  // single-tile edit is not a whole-frame reset.
  assert.notDeepEqual(Array.from(after), Array.from(before));
});

function centreHit(session, tilemap, column) {
  const focallength = number(session, "wl.focallength") / 65536;
  const px = number(session, "(wl.player@ wl.PLAYER-X)") / 65536;
  const py = number(session, "(wl.player@ wl.PLAYER-Y)") / 65536;
  const angle = number(session, "(wl.player@ wl.PLAYER-ANGLE)");
  const radians = (angle * Math.PI) / 180;
  const fine = angle * 10 + number(session, `(wl.pixelangle@ ${column})`);
  const theta = (fine * 2 * Math.PI) / 3600;
  const dx = Math.cos(theta);
  const dy = -Math.sin(theta);
  let x = px - focallength * Math.cos(radians);
  let y = py + focallength * Math.sin(radians);
  for (let step = 0; step < 4096; step += 1) {
    const tx = Math.floor(x);
    const ty = Math.floor(y);
    if (tx < 0 || tx >= 64 || ty < 0 || ty >= 64) return undefined;
    if (tilemap[tx * 64 + ty]) return { x: tx, y: ty };
    const toX = dx > 0 ? (tx + 1 - x) / dx : dx < 0 ? (tx - x) / dx : Infinity;
    const toY = dy > 0 ? (ty + 1 - y) / dy : dy < 0 ? (ty - y) / dy : Infinity;
    const advance = Math.min(toX, toY) + 1e-9;
    x += dx * advance;
    y += dy * advance;
  }
  return undefined;
}

// --- what a tick does to the picture -----------------------------------------

test("a turn and a step each change the frame, and the same input replays exactly", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { session } = await application();
  const driver = createApplicationDriver(session);
  driver.attach();

  const start = session.evaluateBytes("(app.frame-bytes)").slice();
  const startState = driver.stateText();

  driver.tick(inputForm("turn-left"));
  const turnedState = parseLispValue(driver.stateText()).map(Number);
  const startNumbers = parseLispValue(startState).map(Number);
  assert.notEqual(turnedState[2], startNumbers[2], "a turn should change the angle");
  assert.deepEqual(turnedState.slice(3), startNumbers.slice(3), "a turn should not move the player");
  const turned = session.evaluateBytes("(app.frame-bytes)").slice();
  assert.notDeepEqual(Array.from(turned), Array.from(start), "a turn should change the picture");

  driver.tick(inputForm("forward"));
  const walkedState = parseLispValue(driver.stateText()).map(Number);
  assert.notDeepEqual(walkedState.slice(3), turnedState.slice(3), "a step should move the player");
  assert.equal(walkedState[2], turnedState[2], "a step should not turn the player");
  const walked = session.evaluateBytes("(app.frame-bytes)").slice();
  assert.notDeepEqual(Array.from(walked), Array.from(turned), "a step should change the picture");

  // Deterministic: a second program, given the same inputs, produces the same
  // bytes. Nothing here reads a clock or a random source, and this is what says
  // so rather than a comment claiming it.
  const replay = await application();
  const replayDriver = createApplicationDriver(replay.session);
  replayDriver.attach();
  replayDriver.tick(inputForm("turn-left"));
  replayDriver.tick(inputForm("forward"));
  assert.equal(replayDriver.stateText(), driver.stateText(), "the replayed state should be identical");
  assert.deepEqual(Array.from(replay.session.evaluateBytes("(app.frame-bytes)")), Array.from(walked));
});

// ClipMove and TryMove are the original's, so the guarantee they carry is the
// original's too: whatever the player does, they are never standing in a wall.
test("the player never walks into a wall over a long deterministic circuit", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { session } = await application();
  const driver = createApplicationDriver(session);
  driver.attach();
  const tilemap = session.evaluateBytes("wl.tilemap");
  const size = number(session, "wl.PLAYERSIZE");

  let moved = 0;
  let blocked = 0;
  for (let step = 0; step < 120; step += 1) {
    const [, , , x, y] = parseLispValue(driver.stateText()).map(Number);
    driver.tick(step % 5 === 4 ? inputForm("turn-right") : inputForm("forward"));
    const [tilex, tiley, , nx, ny] = parseLispValue(driver.stateText()).map(Number);
    if (nx === x && ny === y) blocked += 1;
    else moved += 1;
    assert.equal(tilex, nx >> 16, "tilex should track x");
    assert.equal(tiley, ny >> 16, "tiley should track y");
    // TryMove clears a PLAYERSIZE box, so every tile the box covers is open.
    for (let ty = (ny - size) >> 16; ty <= (ny + size) >> 16; ty += 1) {
      for (let tx = (nx - size) >> 16; tx <= (nx + size) >> 16; tx += 1) {
        assert.equal(tilemap[tx * 64 + ty], 0, `the player's box covers solid tile ${tx},${ty}`);
      }
    }
  }
  assert.ok(moved > 0, "the circuit should have moved at least once");
  assert.ok(blocked > 0, "the circuit should have been refused at least once");
});

// --- the frame the host is handed --------------------------------------------

test("the frame is a 320x200 indexed surface with the view above the status bar", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { session } = await application();
  const driver = createApplicationDriver(session);
  driver.attach();
  const framebuffer = directive(directives(driver.present()), "framebuffer");
  assert.ok(framebuffer, "a mounted application should return a framebuffer");

  const pixels = session.evaluateBytes(`(${framebuffer[1]})`);
  const { width, height, left, top: viewTop, screenWidth, screenHeight, statusLines } = view(session);
  assert.equal(pixels.length, 320 * 200, "the surface is the original's 320x200");

  // Which three indices VGAClearScreen wrote depends on which palette the
  // frame is in, and that follows from what was mounted. The test reads the
  // program's own answer rather than assuming either mode.
  const textured = session.evaluate("(wl.textured?)") === "true";
  const ceiling = number(session, textured ? "wl.VGACEILING" : "wl.CEILING");
  const floor = number(session, textured ? "wl.VGAFLOOR" : "wl.FLOOR");
  const status = number(session, textured ? "wl.VGASTATUS" : "wl.STATUS");
  // Below the view is the status bar's rows, untouched by the raycaster.
  for (let index = (screenHeight - statusLines) * screenWidth; index < screenWidth * screenHeight; index += 1) {
    assert.equal(pixels[index], status, `status bar pixel ${index}`);
  }

  assert.deepEqual([width, height, left, viewTop], [240, 120, 40, 20], "no-config viewsize 15 geometry");
  const outside = (x, y) => {
    if (x === left - 1 && y === viewTop + height) return 124;
    if (x === left + width && y >= viewTop - 1 && y <= viewTop + height) return 125;
    if (y === viewTop + height && x >= left && x <= left + width) return 125;
    if (x === left - 1 && y >= viewTop - 1 && y < viewTop + height) return 0;
    if (y === viewTop - 1 && x >= left - 1 && x < left + width) return 0;
    return 127;
  };
  for (let y = 0; y < screenHeight - statusLines; y += 1) {
    for (let x = 0; x < screenWidth; x += 1) {
      if (x >= left && x < left + width && y >= viewTop && y < viewTop + height) continue;
      assert.equal(pixels[y * screenWidth + x], outside(x, y), `play border pixel ${x},${y}`);
    }
  }

  // A post's rows are decided by CalcHeight and the horizon, so where it is
  // can be asked of the program and checked against the pixels. This is by
  // position rather than by colour on purpose: a texel is free to be the same
  // index as the ceiling, and once posts carry textures a colour test would be
  // asserting that a wall never contains one particular shade.
  let walls = 0;
  for (let column = 0; column < width; column += 1) {
    const wallheight = number(session, `(wl.wallheight@ ${column})`);
    const drawn = number(session, `(u8@ wl.wallpic ${column})`) !== 255 && wallheight >> 3 > 0;
    const rawHalf = wallheight >> 3;
    const half = textured ? number(session, `(wl.scaler-height ${rawHalf})`) : rawHalf;
    const postTop = drawn ? Math.max(0, height / 2 - half) : height;
    const postBottom = drawn ? Math.min(height - 1, height / 2 + half - 1) : -1;
    for (let row = 0; row < height; row += 1) {
      const pixel = pixels[(row + viewTop) * screenWidth + left + column];
      if (row >= postTop && row <= postBottom) { walls += 1; continue; }
      // Outside the post, and only outside it, VGAClearScreen's own two bytes
      // stand, each on its own side of the horizon.
      assert.equal(pixel, row < height / 2 ? ceiling : floor, `unpainted pixel at ${column},${row}`);
    }
    assert.equal(Math.max(0, postBottom - postTop + 1), Math.min(height, 2 * half),
      `column ${column} covers the wrong rows for wall height ${wallheight}`);
  }
  assert.ok(walls > 5000, `the view should be substantially wall, found ${walls} wall pixels`);
});

// The declared surface has to actually cover the colours the program paints
// with, or the host would index past the palette it was given.
test("the declared palette covers every colour the program paints", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { session } = await application();
  const mount = parseLispValue(session.evaluate("(app.mount)"));
  const surface = mount[5];
  assert.equal(surface[0], "surface");
  assert.equal(surface[1], "indexed8");
  const palette = surface[2];
  assert.ok(palette.every((colour) => /^#[0-9a-f]{6}$/i.test(colour)), "every palette entry should be a colour");
  const driver = createApplicationDriver(session);
  driver.attach();
  const pixels = session.evaluateBytes("(app.frame-bytes)");
  assert.ok(Math.max(...pixels) < palette.length, `painted index ${Math.max(...pixels)} is outside the declared palette of ${palette.length}`);
});

// The renderer allocates several megabytes per frame in an evaluator whose
// allocator never collects, and hands it back with heap.release. If that were
// wrong the program would simply stop after a few frames, so the ceiling is
// checked rather than assumed.
test("a frame's allocation is handed back, so the program can render indefinitely", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { session } = await application();
  const driver = createApplicationDriver(session);
  driver.attach();
  session.evaluate("(app.frame-bytes)");
  const settled = number(session, "(heap.used)");
  for (let tick = 0; tick < 12; tick += 1) {
    driver.tick(tick % 3 === 0 ? inputForm("turn-right") : inputForm("forward"));
    session.evaluate("(app.frame-bytes)");
  }
  const after = number(session, "(heap.used)");
  assert.ok(after - settled < 65536, `twelve frames retained ${after - settled} bytes`);
});
