import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";
import { createSeedSession } from "./seed-session.mjs";

// The Wolf3D map path, tested against the original file format rather than
// against a snapshot of its own output.
//
// Two kinds of evidence are used, and neither is a recorded expectation.
//
//   Synthetic streams. A generator builds a compressed stream and the word
//   array it must expand to, at the same time, from randomized choices. The
//   expected output therefore comes from the construction, not from a prior
//   run of the code under test, and it covers branches the shipped data may
//   never take.
//
//   The originals. MAPHEAD.WL6 and GAMEMAPS.WL6 are decoded by the Lisp
//   module and, independently, by reference ports of CAL_CarmackExpand and
//   CA_RLEWexpand written here straight from ID_CA.C. Agreement between two
//   independent ports over 8192 bytes per plane is the claim; no expected
//   plane bytes are written down anywhere.
//
// Anything that is a constant of the format - the RLEW tag's position, the
// field offsets of maptype, NUMMAPS - is asserted as a relationship inside
// the real file, not as a literal copied out of it.

const assetRoot = new URL("../public/assets/wolf3d/", import.meta.url);
const idCaSource = await readFile(new URL("../src/examples/wolf3d/id-ca.lisp", import.meta.url), "utf8");

// A session with the map module loaded and enough heap for two planes.
async function mapSession() {
  const session = await createSeedSession();
  session.evaluateQuietly("(heap.reserve 50000000)");
  session.evaluateQuietly(idCaSource);
  return session;
}

// Hand a byte array to the evaluator the way the host does, and give the Lisp
// program a name for it.
function ingest(session, name, bytes) {
  session.evaluate(`(asset.reserve ${bytes.length})`);
  const handle = session.ingestBytes(bytes);
  session.evaluateQuietly(`(define ${name} (asset.ref ${handle}))`);
  return handle;
}

function words(bytes) {
  return Array.from(new Uint16Array(bytes.buffer, bytes.byteOffset, bytes.length >> 1));
}

function bytesOfWords(values) {
  return new Uint8Array(Uint16Array.from(values).buffer);
}

// A small deterministic generator. Randomized coverage is only useful if a
// failure can be reproduced, so the seed is explicit and reported.
function random(seed) {
  let state = seed >>> 0;
  return (bound) => {
    state = (Math.imul(state, 1664525) + 1013904223) >>> 0;
    return state % bound;
  };
}

// --- reference ports, transcribed from ID_CA.C -----------------------------

const NEARTAG = 0xa7;
const FARTAG = 0xa8;

// CAL_CarmackExpand (ID_CA.C). length is the EXPANDED length in bytes.
function carmackExpand(source, at, length) {
  const out = new Uint16Array(length >> 1);
  const read16 = (offset) => source[offset] | (source[offset + 1] << 8);
  let remaining = length >> 1;
  let inptr = at;
  let outptr = 0;
  while (remaining) {
    const ch = read16(inptr);
    inptr += 2;
    const chhigh = ch >> 8;
    if (chhigh === NEARTAG || chhigh === FARTAG) {
      const count = ch & 0xff;
      if (!count) {
        out[outptr++] = ch | source[inptr++];
        remaining -= 1;
      } else {
        let copyptr;
        if (chhigh === NEARTAG) copyptr = outptr - source[inptr++];
        else { copyptr = read16(inptr); inptr += 2; }
        remaining -= count;
        for (let index = 0; index < count; index += 1) out[outptr++] = out[copyptr++];
      }
    } else {
      out[outptr++] = ch;
      remaining -= 1;
    }
  }
  return out;
}

// CA_RLEWexpand (ID_CA.C), the portable form the file keeps under #if 0.
function rlewExpand(source, at, length, rlewtag) {
  const out = new Uint16Array(length >> 1);
  const read16 = (offset) => source[offset] | (source[offset + 1] << 8);
  const end = length >> 1;
  let inptr = at;
  let outptr = 0;
  do {
    const value = read16(inptr);
    inptr += 2;
    if (value !== rlewtag) out[outptr++] = value;
    else {
      const count = read16(inptr);
      inptr += 2;
      const repeated = read16(inptr);
      inptr += 2;
      for (let index = 1; index <= count; index += 1) out[outptr++] = repeated;
    }
  } while (outptr < end);
  return out;
}

// --- stream generators ------------------------------------------------------

// Build a Carmack stream and the exact words it must expand to, together.
// Every branch of CAL_CarmackExpand is reachable: literal, near copy, far
// copy, and the two count==0 forms that carry a literal whose high byte
// collides with a tag.
function carmackStream(seed, targetWords) {
  const next = random(seed);
  const stream = [];
  const expected = [];
  const pushWord = (value) => { stream.push(value & 0xff, (value >> 8) & 0xff); };
  while (expected.length < targetWords) {
    const remaining = targetWords - expected.length;
    const choice = next(10);
    if (choice < 4 || expected.length === 0) {
      // A plain literal, chosen so its high byte is not a tag.
      let value = next(0x10000);
      while ((value >> 8) === NEARTAG || (value >> 8) === FARTAG) value = next(0x10000);
      pushWord(value);
      expected.push(value);
    } else if (choice < 6) {
      // A literal whose high byte is a tag, carried by the count==0 form.
      const tag = next(2) ? NEARTAG : FARTAG;
      const low = next(0x100);
      pushWord(tag << 8);
      stream.push(low);
      expected.push((tag << 8) | low);
    } else if (choice < 8) {
      // A near copy: offset is a byte, measured back from the current output.
      const offset = 1 + next(Math.min(255, expected.length));
      const count = 1 + next(Math.min(255, remaining));
      pushWord((NEARTAG << 8) | count);
      stream.push(offset);
      // Word by word, so a run shorter than its offset replicates exactly the
      // way the original's copy loop does.
      let from = expected.length - offset;
      for (let index = 0; index < count; index += 1) expected.push(expected[from++]);
    } else {
      // A far copy: offset is a whole word, measured from the start of dest.
      const offset = next(expected.length);
      const count = 1 + next(Math.min(255, remaining));
      pushWord((FARTAG << 8) | count);
      pushWord(offset);
      let from = offset;
      for (let index = 0; index < count; index += 1) expected.push(expected[from++]);
    }
  }
  return { stream: Uint8Array.from(stream), expected: Uint16Array.from(expected) };
}

// Build an RLEW stream and its expansion together. A literal that happens to
// equal the tag has to be emitted as a run of one, which is the rule that
// makes the format decodable at all; the generator obeys it.
function rlewStream(seed, targetWords, rlewtag) {
  const next = random(seed);
  const stream = [];
  const expected = [];
  const pushWord = (value) => { stream.push(value & 0xff, (value >> 8) & 0xff); };
  while (expected.length < targetWords) {
    const remaining = targetWords - expected.length;
    const value = next(0x10000);
    if (next(3) === 0 || value === rlewtag) {
      const count = 1 + next(Math.min(0x1000, remaining));
      pushWord(rlewtag);
      pushWord(count);
      pushWord(value);
      for (let index = 0; index < count; index += 1) expected.push(value);
    } else {
      pushWord(value);
      expected.push(value);
    }
  }
  return { stream: Uint8Array.from(stream), expected: Uint16Array.from(expected) };
}

// --- the expanders ----------------------------------------------------------

test("CA_RLEWexpand reproduces streams built independently of it", async () => {
  for (const seed of [1, 2, 3, 5, 8, 13]) {
    // The tag is varied deliberately: it is a property of the header file, not
    // a constant of the format, so nothing may assume the shipped 0xabcd.
    const rlewtag = [0xabcd, 0x0000, 0xffff, 0x1234][seed % 4];
    const { stream, expected } = rlewStream(seed, 1500, rlewtag);
    const session = await mapSession();
    ingest(session, "map.stream", stream);
    session.evaluateQuietly(`(define map.dest (bytes.alloc ${expected.length * 2}))`);
    const produced = Number(session.evaluate(`(ca.rlew-expand map.stream 0 map.dest ${expected.length * 2} ${rlewtag})`));
    assert.equal(produced, expected.length, `seed ${seed}: expanded word count`);
    assert.deepEqual(words(session.evaluateBytes("map.dest")), Array.from(expected), `seed ${seed}, rlewtag ${rlewtag}`);
    // The same bytes read as a big-endian stream would decode to something
    // else entirely, which is what makes the little-endian claim a claim.
    assert.notDeepEqual(words(bytesOfWords(expected)).map((value) => ((value & 0xff) << 8) | (value >> 8)), Array.from(expected));
  }
});

test("CAL_CarmackExpand reproduces streams built independently of it", async () => {
  for (const seed of [1, 4, 9, 16, 25]) {
    const { stream, expected } = carmackStream(seed, 1200);
    // The reference port must agree with the generator before it is used to
    // judge anything, or a shared misreading of the C would go unnoticed.
    assert.deepEqual(Array.from(carmackExpand(stream, 0, expected.length * 2)), Array.from(expected), `seed ${seed}: reference port`);
    const session = await mapSession();
    ingest(session, "map.stream", stream);
    session.evaluateQuietly(`(define map.dest (bytes.alloc ${expected.length * 2}))`);
    const produced = Number(session.evaluate(`(ca.carmack-expand map.stream 0 map.dest ${expected.length * 2})`));
    assert.equal(produced, expected.length, `seed ${seed}: expanded word count`);
    assert.deepEqual(words(session.evaluateBytes("map.dest")), Array.from(expected), `seed ${seed}`);
  }
});

// A near copy whose count exceeds its offset re-reads words it has just
// written, so the run repeats. Getting this wrong by copying through a
// temporary produces plausible output that is wrong only inside runs, which
// randomized streams can hide; it is pinned on its own.
test("a near copy that overlaps its own output repeats rather than copying a snapshot", async () => {
  const stream = Uint8Array.from([
    0x11, 0x22,                     // literal 0x2211
    0x33, 0x44,                     // literal 0x4433
    (NEARTAG << 8 | 6) & 0xff, NEARTAG, 2 // near copy, count 6, offset 2 words
  ]);
  const expected = [0x2211, 0x4433, 0x2211, 0x4433, 0x2211, 0x4433, 0x2211, 0x4433];
  assert.deepEqual(Array.from(carmackExpand(stream, 0, expected.length * 2)), expected, "reference port");
  const session = await mapSession();
  ingest(session, "map.stream", stream);
  session.evaluateQuietly(`(define map.dest (bytes.alloc ${expected.length * 2}))`);
  session.evaluate(`(ca.carmack-expand map.stream 0 map.dest ${expected.length * 2})`);
  assert.deepEqual(words(session.evaluateBytes("map.dest")), expected);
});

// CA_RLEWexpand tests at the bottom of its loop, so a stream is always read
// at least once even when the caller asks for nothing. This is a real
// original behaviour and the port keeps it.
test("RLEW expansion writes its first word before testing for the end", async () => {
  const session = await mapSession();
  ingest(session, "map.stream", bytesOfWords([0x4321, 0x8765]));
  session.evaluateQuietly("(define map.dest (bytes.alloc 4))");
  assert.equal(session.evaluate("(ca.rlew-expand map.stream 0 map.dest 0 43981)"), "1");
  assert.deepEqual(words(session.evaluateBytes("map.dest")), [0x4321, 0]);
});

// --- the original files -----------------------------------------------------

async function originals() {
  try {
    const manifest = JSON.parse(await readFile(new URL("manifest.json", assetRoot), "utf8"));
    const files = {};
    for (const file of manifest.files) files[file.name] = new Uint8Array(await readFile(new URL(file.name, assetRoot)));
    return { manifest, ...files };
  } catch {
    return undefined;
  }
}

const skipReason = "The original Wolf3D data is not mounted. Run `node scripts/mount-assets.mjs` with a Steam installation available.";

test("MAPHEAD.WL6 is read as the original's mapfiletype", async (t) => {
  const original = await originals();
  if (!original) return t.skip(skipReason);
  const head = original["MAPHEAD.WL6"];
  const view = new DataView(head.buffer, head.byteOffset, head.length);
  const session = await mapSession();
  ingest(session, "map.tinf", head);

  // mapfiletype is a tag word followed by 100 longs followed by tileinfo, so
  // the file cannot be shorter than that fixed part. This is the size claim,
  // rather than the file's own length written down.
  assert.ok(head.length >= 2 + 100 * 4, "MAPHEAD is too short to hold mapfiletype");
  assert.equal(Number(session.evaluate("(ca.rlew-tag map.tinf)")), view.getUint16(0, true));
  // Little-endian is load-bearing here: the shipped tag is not a palindrome,
  // so reading it the other way round gives a different number.
  assert.notEqual(view.getUint16(0, true), view.getUint16(0, false));

  // Every one of the 100 header offsets, not a sample of them.
  for (let index = 0; index < 100; index += 1) {
    assert.equal(Number(session.evaluate(`(ca.header-offset map.tinf ${index})`)), view.getInt32(2 + index * 4, true), `headeroffsets[${index}]`);
  }
  // headeroffsets[] is always 100 entries wide, but CAL_SetupMapFile only
  // reads the first NUMMAPS of them. In this file all 60 are real and the
  // remaining 40 are zero rather than the negative sparse marker, so the
  // marker predicate has to agree with the file rather than with the story
  // that the padding is sparse.
  const NUMMAPS = 60;
  const starts = [];
  for (let index = 0; index < 100; index += 1) {
    const sparse = session.evaluate(`(ca.sparse-map? map.tinf ${index})`) === "true";
    assert.equal(sparse, view.getInt32(2 + index * 4, true) < 0, `sparse marker at ${index}`);
    assert.equal(sparse, false, `no map in this file is marked sparse, including ${index}`);
    starts.push(view.getInt32(2 + index * 4, true));
  }
  assert.ok(starts.slice(0, NUMMAPS).every((start) => start > 0), "every one of NUMMAPS maps should have a real header position");
  assert.ok(starts.slice(NUMMAPS).every((start) => start === 0), "entries past NUMMAPS should be unused");
  // The maps are laid out in ascending order in the data file, which is what
  // makes a header offset usable as a seek without a directory.
  const used = starts.slice(0, NUMMAPS);
  assert.deepEqual(used, [...used].sort((left, right) => left - right));
});

test("the first map's maptype header is decoded from GAMEMAPS.WL6", async (t) => {
  const original = await originals();
  if (!original) return t.skip(skipReason);
  const head = original["MAPHEAD.WL6"];
  const maps = original["GAMEMAPS.WL6"];
  const headView = new DataView(head.buffer, head.byteOffset, head.length);
  const mapsView = new DataView(maps.buffer, maps.byteOffset, maps.length);
  const session = await mapSession();
  ingest(session, "map.tinf", head);
  ingest(session, "map.maps", maps);
  const pos = headView.getInt32(2, true);
  session.evaluateQuietly("(define map.pos (ca.header-offset map.tinf 0))");
  assert.equal(Number(session.evaluate("map.pos")), pos);

  for (let plane = 0; plane < 3; plane += 1) {
    assert.equal(Number(session.evaluate(`(ca.plane-start map.maps map.pos ${plane})`)), mapsView.getInt32(pos + plane * 4, true), `planestart[${plane}]`);
    assert.equal(Number(session.evaluate(`(ca.plane-length map.maps map.pos ${plane})`)), mapsView.getUint16(pos + 12 + plane * 2, true), `planelength[${plane}]`);
  }
  // SetupGameLevel quits unless the map is 64*64, so these are the only values
  // the rest of the port is allowed to see.
  assert.equal(Number(session.evaluate("(ca.map-width map.maps map.pos)")), 64);
  assert.equal(Number(session.evaluate("(ca.map-height map.maps map.pos)")), 64);
  assert.equal(Number(session.evaluate("(ca.map-width map.maps map.pos)")), mapsView.getUint16(pos + 18, true));

  // name[16] is compared to the bytes in the file, and separately checked for
  // the shape a fixed-width C string has: printable text, then NUL padding.
  const name = JSON.parse(session.evaluate("(ca.map-name-codes map.maps map.pos)").replace(/[()]/g, (bracket) => (bracket === "(" ? "[" : "]")).replace(/ /g, ","));
  assert.deepEqual(name, Array.from(maps.subarray(pos + 22, pos + 38)));
  const terminator = name.indexOf(0);
  assert.ok(terminator > 0, "the map name should be a non-empty C string");
  assert.ok(name.slice(0, terminator).every((code) => code >= 0x20 && code < 0x7f), "the map name should be printable");
  assert.ok(name.slice(terminator).every((code) => code === 0), "name[16] should be NUL padded");

  // Every plane lies inside the file and the two the game caches are
  // compressed, which is what selects the CARMACIZED path.
  for (let plane = 0; plane < 2; plane += 1) {
    const start = mapsView.getInt32(pos + plane * 4, true);
    const compressed = mapsView.getUint16(pos + 12 + plane * 2, true);
    assert.ok(start > 0 && start + compressed <= maps.length, `plane ${plane} lies inside the file`);
    assert.ok(compressed < 8192, `plane ${plane} should be compressed`);
    // The Carmack stream declares its own expanded length first, and that
    // length is the RLEW stream plus its own skipped length word.
    assert.equal(mapsView.getUint16(start, true) % 2, 0, `plane ${plane} expands to whole words`);
  }
});

// name[16] is decoded to text in Lisp, including the code-to-character table,
// so this checks all sixty names in the file rather than the one the port
// happens to load. A table with a single misplaced entry would still produce a
// plausible-looking name for map 0 alone.
test("every map name in the file decodes to the text the bytes spell", async (t) => {
  const original = await originals();
  if (!original) return t.skip(skipReason);
  const head = original["MAPHEAD.WL6"];
  const maps = original["GAMEMAPS.WL6"];
  const headView = new DataView(head.buffer, head.byteOffset, head.length);
  const session = await mapSession();
  ingest(session, "map.tinf", head);
  ingest(session, "map.maps", maps);

  const seen = new Set();
  for (let index = 0; index < 60; index += 1) {
    const pos = headView.getInt32(2 + index * 4, true);
    const field = Array.from(maps.subarray(pos + 22, pos + 38));
    const terminator = field.indexOf(0);
    const expected = field
      .slice(0, terminator === -1 ? 16 : terminator)
      .map((code) => (code >= 32 && code <= 126 ? String.fromCharCode(code) : "?"))
      .join("");
    assert.equal(session.evaluate(`(ca.map-name map.maps (ca.header-offset map.tinf ${index}))`), expected, `map ${index}`);
    assert.ok(expected.length > 0, `map ${index} should be named`);
    seen.add(expected);
  }
  // Sixty distinct names is what a real map directory looks like; sixty copies
  // of one name is what reading the same header sixty times looks like.
  assert.equal(seen.size, 60, "every map should have its own name");
});

test("both planes of the first map expand to the original 64x64 tile arrays", async (t) => {
  const original = await originals();
  if (!original) return t.skip(skipReason);
  const head = original["MAPHEAD.WL6"];
  const maps = original["GAMEMAPS.WL6"];
  const headView = new DataView(head.buffer, head.byteOffset, head.length);
  const mapsView = new DataView(maps.buffer, maps.byteOffset, maps.length);
  const session = await mapSession();
  ingest(session, "map.tinf", head);
  ingest(session, "map.maps", maps);
  session.evaluateQuietly("(define map.planes (ca.cache-map map.tinf map.maps 0))");

  const rlewtag = headView.getUint16(0, true);
  const pos = headView.getInt32(2, true);
  for (let plane = 0; plane < 2; plane += 1) {
    const start = mapsView.getInt32(pos + plane * 4, true);
    // CA_CacheMap: expanded length word, Carmack expand, then RLEW expand
    // starting one word in.
    const carmacked = carmackExpand(maps, start + 2, mapsView.getUint16(start, true));
    const reference = rlewExpand(new Uint8Array(carmacked.buffer), 2, 64 * 64 * 2, rlewtag);
    const produced = session.evaluateBytes(`(car ${plane ? "(cdr map.planes)" : "map.planes"})`);
    assert.equal(produced.length, 64 * 64 * 2, `plane ${plane} length`);
    assert.deepEqual(words(produced), Array.from(reference), `plane ${plane} differs from the reference expansion`);
  }

  // Independently of the reference port, the decoded planes have to satisfy
  // what the original's own level setup requires of them. A decoder that
  // produced self-consistent nonsense would pass byte comparison against a
  // matching mistake but not these.
  const plane0 = words(session.evaluateBytes("(car map.planes)"));
  const plane1 = words(session.evaluateBytes("(car (cdr map.planes))"));
  assert.equal(plane0.length, 64 * 64);

  // ScanInfoPlane spawns the player from tiles 19..22 in plane 1, and a level
  // with no player start or more than one cannot be played.
  const starts = plane1.filter((tile) => tile >= 19 && tile <= 22);
  assert.equal(starts.length, 1, "plane 1 should hold exactly one player start");

  // SetupGameLevel treats tiles below AREATILE as solid wall and the rest as
  // floor. The border of a Wolf level is solid, or the player walks out of the
  // world; the interior is not, or there is no level.
  const AREATILE = 107;
  const at = (x, y) => plane0[y * 64 + x];
  for (let index = 0; index < 64; index += 1) {
    for (const [x, y] of [[index, 0], [index, 63], [0, index], [63, index]]) {
      assert.ok(at(x, y) < AREATILE, `border tile ${x},${y} should be solid`);
    }
  }
  const floor = plane0.filter((tile) => tile >= AREATILE).length;
  assert.ok(floor > 64 && floor < 64 * 64, `a level should have interior floor, found ${floor}`);

  // The player start must stand on floor, which ties the two planes together:
  // only a correct expansion of both puts them in agreement.
  const startIndex = plane1.findIndex((tile) => tile >= 19 && tile <= 22);
  assert.ok(plane0[startIndex] >= AREATILE, "the player should start on floor");

  // Doors are tiles 90..101 in plane 0, and each sits between two solid walls
  // along its own axis: even numbers are vertical, odd are horizontal.
  let doors = 0;
  for (let y = 1; y < 63; y += 1) {
    for (let x = 1; x < 63; x += 1) {
      const tile = at(x, y);
      if (tile < 90 || tile > 101) continue;
      doors += 1;
      if (tile % 2 === 0) assert.ok(at(x, y - 1) < AREATILE && at(x, y + 1) < AREATILE, `vertical door ${x},${y} should be framed`);
      else assert.ok(at(x - 1, y) < AREATILE && at(x + 1, y) < AREATILE, `horizontal door ${x},${y} should be framed`);
    }
  }
  assert.ok(doors > 0, "the first map should have doors");
});

test("the mounted originals are the bytes the bridge recorded", async (t) => {
  const original = await originals();
  if (!original) return t.skip(skipReason);
  const { createHash } = await import("node:crypto");
  assert.equal(original.manifest.kind, "yalisp-mounted-assets-v1");
  assert.ok(original.manifest.files.length > 0);
  for (const file of original.manifest.files) {
    const bytes = original[file.name];
    assert.equal(bytes.length, file.bytes, `${file.name} length`);
    assert.equal(createHash("sha256").update(bytes).digest("hex"), file.sha256, `${file.name} digest`);
  }
});
