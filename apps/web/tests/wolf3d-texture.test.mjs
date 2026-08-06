import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { createApplicationDriver } from "../src/examples/runtime/application-driver.ts";
import { mountDeclaredAssets } from "../src/examples/runtime/asset-mount.ts";
import { parseLispValue } from "../src/examples/runtime/lisp-value.ts";
import { createSeedSession } from "./seed-session.mjs";
import {
  fromPublic,
  haveWolf3dOriginals as haveOriginals,
  wolf3dAssetRoot as assetRoot,
  wolf3dSkipReason as skipReason,
  wolf3dSource as source
} from "./wolf3d-source.mjs";

// The wall textures: that the bytes arrived, that the Lisp reads the page file
// and the palette the way the files are actually laid out, that a post is drawn
// from the page and the column the ray's own hit selects, and that the frame is
// a function of the state and nothing else.
//
// Everything the Lisp claims about a file is checked against this harness's own
// decode of the same bytes, written from the file format rather than from the
// Lisp, so agreement means two independent readings agree.
//
// Nothing here is a claim about how a frame looks. No original screenshot has
// been compared against, and these tests would pass on a frame that is correct
// in every way they can see and still wrong in ways they cannot.

async function application(fetcher = fromPublic) {
  const session = await createSeedSession();
  session.evaluateQuietly(source);
  const result = await mountDeclaredAssets(session, fetcher);
  return { session, ...result };
}

const number = (session, form) => Number(session.evaluate(form));
const inputForm = (...held) =>
  `(${["forward", "backward", "turn-left", "turn-right"].map((name) => `(${name} ${held.includes(name) ? 1 : 0})`).join(" ")})`;

// --- this harness's own readings of the two files ----------------------------

// ID_PM.C's PML_OpenPageFile: three words, then a longword offset per chunk,
// then a word length per chunk.
function pageFile(bytes) {
  const view = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
  const chunks = view.getUint16(0, true);
  return {
    chunks,
    spriteStart: view.getUint16(2, true),
    soundStart: view.getUint16(4, true),
    offset: (n) => view.getUint32(6 + n * 4, true),
    length: (n) => view.getUint16(6 + chunks * 4 + n * 2, true)
  };
}

// Intel OMF: type byte, length word, contents, checksum. The palette is the
// LEDATA record's data, past its segment index and load offset.
function palette(bytes) {
  let at = 0;
  while (at < bytes.length && bytes[at] !== 0xa0) at += 3 + (bytes[at + 1] | (bytes[at + 2] << 8));
  assert.ok(at < bytes.length, "GAMEPAL.OBJ should carry an LEDATA record");
  const base = at + 6;
  const channel = (index) => (bytes[index] << 2).toString(16).padStart(2, "0");
  return Array.from({ length: 256 }, (unused, index) =>
    `#${channel(base + index * 3)}${channel(base + index * 3 + 1)}${channel(base + index * 3 + 2)}`);
}

// --- the bytes ---------------------------------------------------------------

test("the page file and the palette are mounted, and the evaluator holds the files' own bytes", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { session, mounted, failed } = await application();
  assert.deepEqual(failed, []);
  const byName = new Map(mounted.map((asset) => [asset.name, asset]));
  assert.ok(byName.has("vswap"), "VSWAP should be mounted");
  assert.ok(byName.has("gamepal"), "GAMEPAL should be mounted");

  // The build-time bridge recorded them too, at the paths the program declared.
  const manifest = JSON.parse(await readFile(new URL("manifest.json", assetRoot), "utf8"));
  const recorded = new Map(manifest.files.map((file) => [file.name, file.bytes]));
  for (const [name, file] of [["vswap", "VSWAP.WL6"], ["gamepal", "GAMEPAL.OBJ"]]) {
    const asset = byName.get(name);
    const onDisk = await fromPublic(asset.path);
    assert.ok(asset.path.endsWith(file), `${name} should be declared at ${file}`);
    assert.equal(recorded.get(file), onDisk.length, `${file} should be recorded at its own length`);
    assert.equal(asset.length, onDisk.length, `${file} length`);
    assert.equal(session.evaluate(`(bytes.length (asset.ref ${asset.handle}))`), String(onDisk.length));
    // Byte for byte, not merely the right number of them.
    const held = session.evaluateBytes(`(asset.ref ${asset.handle})`);
    assert.deepEqual(held, onDisk, `${file} should reach the evaluator unaltered`);
  }
});

// --- the page file -----------------------------------------------------------

test("the page file's header and wall pages are read as the file lays them out", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { session } = await application();
  const bytes = await fromPublic("/assets/wolf3d/VSWAP.WL6");
  const file = pageFile(bytes);

  assert.equal(number(session, "pm.chunks"), file.chunks);
  assert.equal(number(session, "pm.sprite-start"), file.spriteStart);
  assert.equal(number(session, "pm.sound-start"), file.soundStart);
  assert.ok(file.spriteStart > 0 && file.spriteStart < file.soundStart, "walls come before sprites, sprites before sounds");

  // A wall picture is 64 by 64 bytes, which is exactly one page. This is the
  // dimension the raycaster's 0xfc0 mask and 64-texel scaler both assume, so it
  // is checked against the file rather than taken on trust.
  const pageSize = number(session, "pm.PAGE-SIZE");
  assert.equal(pageSize, 64 * 64, "a page is a 64 by 64 wall picture");
  for (let page = 0; page < file.spriteStart; page += 1) {
    assert.equal(number(session, `(pm.page-length ${page})`), file.length(page), `page ${page} length`);
    assert.equal(number(session, `(pm.get-page ${page})`), file.offset(page), `page ${page} offset`);
    assert.equal(file.length(page), pageSize, `wall page ${page} should be a whole page`);
    assert.ok(file.offset(page) + pageSize <= bytes.length, `wall page ${page} should lie inside the file`);
    assert.equal(session.evaluate(`(pm.wall-page? ${page})`), "true");
  }
  // And the first page that is not a wall is not treated as one, which is what
  // keeps a door tile's picture number from being read as a texture.
  assert.equal(session.evaluate(`(pm.wall-page? ${file.spriteStart})`), "false");
  assert.equal(session.evaluate("(pm.wall-page? -1)"), "false");

  // A texel comes out of the file, at the offset the page and the index give.
  for (const [page, index] of [[0, 0], [0, 4095], [3, 1234], [file.spriteStart - 1, 64]]) {
    assert.equal(number(session, `(pm.texel (pm.get-page ${page}) ${index})`), bytes[file.offset(page) + index]);
  }
});

// --- the palette -------------------------------------------------------------

test("the surface palette is GAMEPAL's own 256 colours", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { session } = await application();
  const expected = palette(await fromPublic("/assets/wolf3d/GAMEPAL.OBJ"));

  const colours = parseLispValue(session.evaluate("(app.palette)")).map(String);
  assert.equal(colours.length, 256, "a VGA palette is 256 colours");
  assert.deepEqual(colours, expected, "the decoded palette should be the object file's");
  // The two facts that make it a VGA palette rather than any 768 bytes: it
  // opens on black, and every channel is a six-bit value shifted up by two.
  assert.equal(colours[0], "#000000");
  for (const colour of colours) {
    assert.match(colour, /^#[0-9a-f]{6}$/);
    for (let channel = 1; channel < 7; channel += 2) {
      const value = Number.parseInt(colour.slice(channel, channel + 2), 16);
      assert.equal(value % 4, 0, `${colour} should be a six-bit channel shifted up by two`);
      assert.ok(value <= 252);
    }
  }

  // It is the palette the host is handed, not something computed beside it.
  const mount = parseLispValue(session.evaluate("(app.mount)"));
  assert.deepEqual(mount[5][2].map(String), expected);
  assert.equal(session.evaluate("(wl.textured?)"), "true");
});

// vl.palette? reads the file rather than trusting its name, so a file that is
// not the palette has to be refused - otherwise a mount that went wrong would
// become 768 bytes of some other file rendered as colours.
test("a file that is not the palette object is refused", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { session, mounted } = await application();
  const gamemaps = mounted.find((asset) => asset.name === "gamemaps");
  assert.equal(session.evaluate(`(vl.palette? (asset.ref ${gamemaps.handle}))`), "false");
  assert.equal(session.evaluate(`(vl.palette-at (asset.ref ${gamemaps.handle}))`), "-1");
});

async function rendererState() {
  const session = await createSeedSession();
  session.evaluateQuietly(source);
  session.evaluateQuietly(`
    (wl.view! wl.PIXX 0)
    (wl.view! wl.VIEWX 0)
    (wl.view! wl.VIEWY 0)
    (wl.view! wl.VIEWCOS 65536)
    (wl.view! wl.VIEWSIN 0)
  `);
  return session;
}

test("moving pushwall hits use the shifted plane, masked picture, and source orientation", async () => {
  const session = await rendererState();
  const tile = 193;
  const verticalY = 20 * 65536 + 32768;
  const horizontalX = 10 * 65536 + 32768;

  for (const [position, tileStep, rayStep] of [[0, 1, 64], [63, -1, -64]]) {
    session.evaluateQuietly(`
      (set! wl.pwallpos ${position})
      (wl.view! wl.XTILESTEP ${tileStep})
      (wl.view! wl.YSTEP ${rayStep})
      (wl.trace-vert-pwall 10 20 0 ${verticalY} ${tile})
    `);
    const mid = verticalY + ((rayStep * position) >> 6);
    const offset = position << 10;
    assert.equal(number(session, "(u8@ wl.wallpic 0)"), 1, "vertical wall 1 picture");
    assert.equal(number(session, "(wl.view@ wl.XINTERCEPT)"),
      10 * 65536 + (tileStep === -1 ? 65536 - offset : offset));
    assert.equal(number(session, "(wl.view@ wl.YINTERCEPT)"), mid);
    assert.equal(number(session, "(wl.walltexture@ 0)"), tileStep === -1
      ? 4032 - ((mid >> 4) & 4032) : ((mid >> 4) & 4032));
  }

  for (const [position, tileStep, rayStep] of [[0, 1, 64], [63, -1, -64]]) {
    session.evaluateQuietly(`
      (set! wl.pwallpos ${position})
      (wl.view! wl.YTILESTEP ${tileStep})
      (wl.view! wl.XSTEP ${rayStep})
      (wl.trace-horiz-pwall 10 20 ${horizontalX} 0 ${tile})
    `);
    const mid = horizontalX + ((rayStep * position) >> 6);
    const offset = position << 10;
    assert.equal(number(session, "(u8@ wl.wallpic 0)"), 0, "horizontal wall 1 picture");
    assert.equal(number(session, "(wl.view@ wl.XINTERCEPT)"), mid);
    assert.equal(number(session, "(wl.view@ wl.YINTERCEPT)"),
      20 * 65536 + (tileStep === -1 ? 65536 - offset : offset));
    assert.equal(number(session, "(wl.walltexture@ 0)"), tileStep === -1
      ? ((mid >> 4) & 4032) : 4032 - ((mid >> 4) & 4032));
  }

  session.evaluateQuietly("(set! wl.pwallpos 63)");
  assert.equal(number(session, "(wl.pwall-intercept 0 75099057)"), 6816770,
    "positive partial step uses wrapped i32 multiply then arithmetic shift");
  assert.equal(number(session, "(wl.pwall-intercept 0 -75099057)"), -6816771,
    "negative partial step uses the same signed high-word result");
});

test("moving pushwall tile-cross passes mark spotvis and advance from the unshifted intercept", async () => {
  const session = await rendererState();
  session.evaluateQuietly(`
    (define t.vx 0) (define t.vy 0) (define t.vxi 0) (define t.vyi 0)
    (define t.hx 0) (define t.hy 0) (define t.hxi 0) (define t.hyi 0)
    (defn wl.vert-loop (x y xi yi)
      (begin (set! t.vx x) (set! t.vy y) (set! t.vxi xi) (set! t.vyi yi) true))
    (defn wl.horiz-loop (x y xi yi)
      (begin (set! t.hx x) (set! t.hy y) (set! t.hxi xi) (set! t.hyi yi) true))
    (bytes.fill wl.spotvis 0 4096 0)
    (set! wl.pwallpos 63)
    (wl.view! wl.XTILESTEP 1) (wl.view! wl.YSTEP 128)
    (wl.trace-vert-pwall 5 7 1234 720860 193)
    (wl.view! wl.YTILESTEP 1) (wl.view! wl.XSTEP 128)
    (wl.trace-horiz-pwall 7 5 720860 1234 193)
  `);
  assert.deepEqual(["t.vx", "t.vy", "t.vxi", "t.vyi"].map((form) => number(session, form)),
    [6, 7, 1234, 720988], "vertical pass advances from yi, not the moving midpoint");
  assert.deepEqual(["t.hx", "t.hy", "t.hxi", "t.hyi"].map((form) => number(session, form)),
    [7, 6, 720988, 1234], "horizontal pass advances from xi, not the moving midpoint");
  assert.equal(number(session, `(u8@ wl.spotvis ${5 * 64 + 10})`), 1, "vertical pass cell");
  assert.equal(number(session, `(u8@ wl.spotvis ${10 * 64 + 5})`), 1, "horizontal pass cell");
});

test("normal doors still use door position, lock picture, and door midpoint", async () => {
  const session = await rendererState();
  session.evaluateQuietly(`
    (set! pm.sprite-start 20)
    (wl.door-position! 0 0)
    (u8! wl.doorlock 0 0)
    (set! wl.pwallpos 63)
    (wl.view! wl.XTILESTEP 1) (wl.view! wl.YSTEP 0)
    (wl.trace-vert-door 10 20 0 1343488 128)
  `);
  assert.deepEqual([
    number(session, "(u8@ wl.wallpic 0)"),
    number(session, "(wl.view@ wl.XINTERCEPT)"),
    number(session, "(wl.view@ wl.YINTERCEPT)")
  ], [13, 10 * 65536 + 32768, 1343488]);

  session.evaluateQuietly(`
    (wl.view! wl.YTILESTEP 1) (wl.view! wl.XSTEP 0)
    (wl.trace-horiz-door 10 20 688128 0 128)
  `);
  assert.deepEqual([
    number(session, "(u8@ wl.wallpic 0)"),
    number(session, "(wl.view@ wl.XINTERCEPT)"),
    number(session, "(wl.view@ wl.YINTERCEPT)")
  ], [12, 688128, 20 * 65536 + 32768]);
});

// --- which page and which column a post is drawn from ------------------------

// A march in floating point, from the camera the program says it has, recording
// which of the two tile boundaries the ray crossed last and where along the
// wall it landed. It is not the program's arithmetic: it is a second opinion
// about the same geometry, and it is compared with a tolerance because it is
// not expected to agree at grazing angles or exactly on a corner.
function hits(session, tilemap) {
  const width = number(session, "wl.viewwidth");
  const focallength = number(session, "wl.focallength") / 65536;
  const px = number(session, "(wl.player@ wl.PLAYER-X)") / 65536;
  const py = number(session, "(wl.player@ wl.PLAYER-Y)") / 65536;
  const angle = number(session, "(wl.player@ wl.PLAYER-ANGLE)");
  const radians = (angle * Math.PI) / 180;
  const vx = px - focallength * Math.cos(radians);
  const vy = py + focallength * Math.sin(radians);
  return Array.from({ length: width }, (unused, column) => {
    const fine = angle * 10 + number(session, `(wl.pixelangle@ ${column})`);
    const theta = (fine * 2 * Math.PI) / 3600;
    const dx = Math.cos(theta);
    const dy = -Math.sin(theta);
    let x = vx;
    let y = vy;
    let vertical = false;
    for (let step = 0; step < 4096; step += 1) {
      const tx = Math.floor(x);
      const ty = Math.floor(y);
      if (tx < 0 || tx >= 64 || ty < 0 || ty >= 64) return null;
      const tile = tilemap[tx * 64 + ty];
      if (tile) {
        // vertwall is the face on a plane of constant x, and its texture runs
        // along y; horizwall is the other way round. The mirroring is the
        // original's 0xfc0-texture, which is the column counted from the far
        // end when the wall is approached from the far side.
        const along = vertical ? y - Math.floor(y) : x - Math.floor(x);
        const mirrored = vertical ? dx < 0 : dy > 0;
        const texel = Math.floor(along * 64);
        return {
          tile,
          special: Boolean(tile & 0xc0),
          pic: (tile - 1) * 2 + (vertical ? 1 : 0),
          column: mirrored ? 63 - texel : texel
        };
      }
      const toX = dx > 0 ? (tx + 1 - x) / dx : dx < 0 ? (tx - x) / dx : Infinity;
      const toY = dy > 0 ? (ty + 1 - y) / dy : dy < 0 ? (ty - y) / dy : Infinity;
      vertical = toX <= toY;
      const advance = Math.min(toX, toY) + 1e-9;
      x += dx * advance;
      y += dy * advance;
    }
    return null;
  });
}

test("each post names the tile the ray met, the face it met, and a column of that face", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { session } = await application();
  const driver = createApplicationDriver(session);
  driver.attach();
  const spriteStart = number(session, "pm.sprite-start");
  const doorWall = spriteStart - 8;

  const everySeen = new Set();
  let sawDoorPicture = false;
  const check = (label) => {
    session.evaluate("(app.frame-bytes)");
    const tilemap = session.evaluateBytes("wl.tilemap");
    const solid = new Set([...tilemap].filter(Boolean));
    const expected = hits(session, tilemap);
    let pics = 0;
    let columns = 0;
    const seen = new Set();
    for (let column = 0; column < expected.length; column += 1) {
      const pic = number(session, `(u8@ wl.wallpic ${column})`);
      const texture = number(session, `(wl.walltexture@ ${column})`);
      assert.notEqual(pic, 255, `${label}: column ${column} found no wall`);

      // Structural, and true of every column: a texture offset is the start of
      // a whole column of a whole page, and the picture is one of the pair
      // SetupGameLevel built for a tile that is actually solid on this level.
      assert.equal(texture % 64, 0, `${label}: column ${column} texture ${texture} is not a column start`);
      assert.ok(texture >= 0 && texture <= 4032, `${label}: column ${column} texture ${texture} is outside the page`);
      const doorPicture = pic >= doorWall && pic < spriteStart;
      if (doorPicture) sawDoorPicture = true;
      else assert.ok(solid.has((pic >> 1) + 1), `${label}: column ${column} picture ${pic} is not a solid tile's`);
      seen.add(pic);
      everySeen.add(pic);

      // And agreeing with the second opinion, where the second opinion is
      // entitled to an answer: a ray that lands within a pixel of a corner can
      // legitimately choose the other face.
      const hit = expected[column];
      if (!hit) continue;
      if (doorPicture || hit.special || hit.pic === pic) pics += 1;
      if (doorPicture || hit.special || (hit.pic === pic && Math.abs(hit.column - texture / 64) <= 1)) columns += 1;
    }
    const total = expected.filter(Boolean).length;
    assert.ok(pics / total > 0.97, `${label}: only ${pics} of ${total} columns picked the expected picture`);
    assert.ok(columns / total > 0.95, `${label}: only ${columns} of ${total} columns picked the expected texture column`);
    // A renderer that named one picture everywhere would satisfy all of the
    // above against an equally uniform expectation. One view of a corridor is
    // entitled to be short of variety, so the strong claim is made across all
    // three below; each one on its own has to show at least both faces.
    assert.ok(seen.size >= 2, `${label}: only ${seen.size} distinct wall pictures across the view`);
    // Both faces of the wall pair are in use, which is the odd/even split
    // horizwall and vertwall make.
    assert.ok([...seen].some((pic) => pic % 2 === 0), `${label}: no horizontal face`);
    assert.ok([...seen].some((pic) => pic % 2 === 1), `${label}: no vertical face`);
    // Ordinary walls and the eight door/jamb pictures all precede sprites in
    // VSWAP, so every picture selected by this slice is a real wall page.
    for (const pic of seen) {
      assert.equal(session.evaluate(`(pm.wall-page? ${pic})`), "true");
    }
  };

  check("at the player start");
  for (let tick = 0; tick < 5; tick += 1) driver.tick(inputForm("turn-left"));
  check("after turning left");
  for (let tick = 0; tick < 4; tick += 1) driver.tick(inputForm("forward"));
  check("after walking forward");
  assert.ok(everySeen.size >= 4, `only ${everySeen.size} distinct wall pictures across three views`);
  assert.ok(sawDoorPicture, "the three views should include a source door or jamb picture");
  assert.ok([...everySeen].every((pic) => pic < spriteStart), "no rendered wall post may sample a sprite page");
});

// --- the scaler, on a page whose contents are known --------------------------

// The real pages cannot say which way up they were drawn, because any answer
// looks like a texture. So the page file is replaced with one this test wrote:
// page 0's every column counts 0 to 63 down its own length, and page 1's every
// column is filled with its own number. What the scaler does with those two is
// unambiguous.
const syntheticPageFile = `
(define t.file (bytes.alloc 8210))
(defn t.setup ()
  (begin
    (u16! t.file 0 2)                       ;; ChunksInFile
    (u16! t.file 2 2)                       ;; PMSpriteStart
    (u16! t.file 4 2)                       ;; PMSoundStart
    (u32! t.file 6 18)                      ;; offset of page 0
    (u32! t.file 10 4114)                   ;; offset of page 1
    (u16! t.file 14 4096)
    (u16! t.file 16 4096)
    (t.pages 0)
    (pm.startup t.file)
    (wl.set-textured 1)
    (bytes.fill wl.wallpic 0 320 255)))
(defn t.pages (i)
  (if (= i 4096)
      i
      (begin
        (u8! t.file (+ 18 i) (mod i 64))    ;; page 0: the texel's row
        (u8! t.file (+ 4114 i) (/ i 64))    ;; page 1: the texel's column
        (t.pages (+ i 1)))))
(define t.frame (bytes.alloc 64000))
(defn t.post (pic height texture)
  (begin
    (bytes.fill t.frame 0 64000 200)
    (u8! wl.wallpic 160 pic)
    (wl.wallheight! 160 (* height 8))
    (wl.walltexture! 160 (* texture 64))
    (wl.scale-post t.frame 160)
    t.frame))
`;

async function scaler() {
  const session = await createSeedSession();
  session.evaluateQuietly(source);
  session.evaluateQuietly(syntheticPageFile);
  session.evaluateQuietly("(t.setup)");
  return session;
}

function postColumn(session, pic, height, texture) {
  const frame = session.evaluateBytes(`(t.post ${pic} ${height} ${texture})`);
  const width = number(session, "wl.SCREENWIDTH");
  const view = number(session, "wl.viewheight");
  const left = number(session, "wl.viewleft");
  const top = number(session, "wl.viewtop");
  return Array.from({ length: view }, (unused, row) => frame[(row + top) * width + left + 160]);
}

test("a post is the texture column, top texel at the top, over the rows the height gives", async () => {
  const session = await scaler();
  // wallheight>>3 of 40 is a post 80 rows tall, centred on the horizon at 60.
  const column = postColumn(session, 0, 40, 0);
  const top = 20;
  const bottom = 99;

  for (let row = 0; row < column.length; row += 1) {
    if (row < top || row > bottom) assert.equal(column[row], 200, `row ${row} is outside the post and should be untouched`);
  }
  const post = column.slice(top, bottom + 1);
  assert.equal(post.length, 80);
  // The whole texture, in order, top first. This is the orientation: texel 0 is
  // drawn at the top of the wall and texel 63 at the bottom.
  assert.equal(post[0], 0, "the top of the post is the top of the texture column");
  assert.equal(post[post.length - 1], 63, "the bottom of the post is the bottom of the texture column");
  for (let row = 1; row < post.length; row += 1) {
    assert.ok(post[row] >= post[row - 1], `texel ${post[row]} at row ${row} is above texel ${post[row - 1]}`);
  }
  assert.deepEqual([...new Set(post)].sort((a, b) => a - b), Array.from({ length: 64 }, (unused, i) => i),
    "80 rows of a 64 texel column should show every texel");
  // Stretched evenly: no texel gets three rows when the post is only a quarter
  // taller than the texture.
  const runs = new Map();
  for (const texel of post) runs.set(texel, (runs.get(texel) ?? 0) + 1);
  assert.deepEqual([...new Set(runs.values())].sort(), [1, 2]);
});

test("a post taller than the view is clipped to it and keeps its order", async () => {
  const session = await scaler();
  const column = postColumn(session, 0, 200, 0);
  assert.ok(column.every((texel) => texel !== 200), "a post this tall should cover every row of the view");
  assert.ok(column[0] > 0, "the top of the texture is above the view");
  assert.ok(column[column.length - 1] < 63, "the bottom of the texture is below the view");
  for (let row = 1; row < column.length; row += 1) {
    assert.ok(column[row] >= column[row - 1], `row ${row} is out of order`);
  }
});

test("the texture offset selects the column of the page, and the picture selects the page", async () => {
  const session = await scaler();
  // Page 1's every texel is its own column number, so a post drawn from column
  // c is c all the way down - which is only true if the offset addressed the
  // column the raycaster asked for.
  for (const wanted of [0, 1, 17, 62, 63]) {
    const column = postColumn(session, 1, 40, wanted).slice(20, 100);
    assert.deepEqual([...new Set(column)], [wanted], `texture offset ${wanted * 64} should draw column ${wanted}`);
  }
  // And the same offset in the other page is not the same bytes, so the picture
  // number is doing work too.
  assert.notDeepEqual(postColumn(session, 0, 40, 17), postColumn(session, 1, 40, 17));
});

test("a picture with no wall page is not sampled", async () => {
  const session = await scaler();
  // Page 2 is past PMSpriteStart in the synthetic file, which is the state a
  // door tile puts the renderer in. It has to be drawn as the port's own
  // marker rather than as whatever bytes follow the wall pages.
  const nopic = number(session, "wl.VGANOPIC");
  const column = postColumn(session, 2, 40, 0).slice(20, 100);
  assert.deepEqual([...new Set(column)], [nopic], "a post with no wall page should be the no-picture index");
});

// --- the frame as a function of the state ------------------------------------

test("a textured frame is deterministic, responds to input, and is not a flat fill", async (t) => {
  if (!(await haveOriginals())) return t.skip(skipReason);
  const { session } = await application();
  const driver = createApplicationDriver(session);
  driver.attach();

  const first = session.evaluateBytes("(app.frame-bytes)").slice();
  const again = session.evaluateBytes("(app.frame-bytes)").slice();
  assert.deepEqual(again, first, "rendering the same state twice should give the same bytes");

  driver.tick(inputForm("turn-left"));
  const turned = session.evaluateBytes("(app.frame-bytes)").slice();
  assert.notDeepEqual(turned, first, "a turn should change the frame");

  // Replaying the same input from the same state reproduces the same frame, so
  // the difference above was the input and not the renderer.
  const replay = await application();
  const replayDriver = createApplicationDriver(replay.session);
  replayDriver.attach();
  replay.session.evaluateBytes("(app.frame-bytes)");
  replayDriver.tick(inputForm("turn-left"));
  assert.deepEqual(replay.session.evaluateBytes("(app.frame-bytes)").slice(), turned);

  // And the posts carry texture rather than one colour each. Counted inside the
  // posts only, so the ceiling and floor cannot supply the variety.
  const width = number(session, "wl.viewwidth");
  const screenWidth = number(session, "wl.SCREENWIDTH");
  const height = number(session, "wl.viewheight");
  const left = number(session, "wl.viewleft");
  const topOffset = number(session, "wl.viewtop");
  const inPosts = new Set();
  let varied = 0;
  for (let column = 0; column < width; column += 1) {
    const rawHalf = number(session, `(wl.wallheight@ ${column})`) >> 3;
    if (rawHalf <= 0) continue;
    const half = number(session, `(wl.scaler-height ${rawHalf})`);
    const top = Math.max(0, height / 2 - half);
    const bottom = Math.min(height - 1, height / 2 + half - 1);
    const post = new Set();
    for (let row = top; row <= bottom; row += 1) {
      post.add(first[(row + topOffset) * screenWidth + left + column]);
      inPosts.add(first[(row + topOffset) * screenWidth + left + column]);
    }
    if (post.size > 1) varied += 1;
  }
  assert.ok(inPosts.size > 20, `the posts use only ${inPosts.size} palette indices`);
  assert.ok(varied > width / 2, `only ${varied} of ${width} posts vary down their own length`);
});
