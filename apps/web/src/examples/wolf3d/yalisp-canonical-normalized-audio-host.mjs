// Route-independent renderer for app.audio-operation-program-export.
// The source program owns scheduling and payload selection. This host only
// renders its absolute 7,000 Hz operations into the canonical comparison WAV.

export const YALISP_CANONICAL_NORMALIZED_PROFILE = Object.freeze({
  format: "wolf3d-normalized-wav-v1",
  sampleRate: 49_716,
  channels: 1,
  bitsPerSample: 16,
  tickRate: 70,
  timelineRate: 7_000,
  mixPolicy: "float64-sum-then-source-clamp-v1",
});

const OP_FIELDS = 13;

function integer(value, label, minimum = 0) {
  if (!Number.isInteger(value) || value < minimum) {
    throw new RangeError(`${label} must be an integer >= ${minimum}.`);
  }
  return value;
}

function exactKeys(value, keys, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) {
    throw new TypeError(`${label} must be an object.`);
  }
  const actual = Object.keys(value).sort(), expected = [...keys].sort();
  if (actual.length !== expected.length || actual.some((key, index) => key !== expected[index])) {
    throw new TypeError(`${label} has an unexpected schema.`);
  }
}

const sampleBoundary = (unit) => Math.floor(
  unit * YALISP_CANONICAL_NORMALIZED_PROFILE.sampleRate
  / YALISP_CANONICAL_NORMALIZED_PROFILE.timelineRate,
);

function normalizeWindow(window) {
  exactKeys(window, ["startTick", "endTick", "tickRate", "sampleCount"], "window");
  integer(window.startTick, "window.startTick");
  integer(window.endTick, "window.endTick", 1);
  if (window.startTick !== 0) throw new RangeError("canonical unified-program windows must start at tick zero.");
  if (window.endTick <= window.startTick) throw new RangeError("window.endTick must follow window.startTick.");
  if (window.tickRate !== YALISP_CANONICAL_NORMALIZED_PROFILE.tickRate) {
    throw new RangeError("window.tickRate must be 70.");
  }
  const sampleCount = Math.floor((window.endTick - window.startTick)
    * YALISP_CANONICAL_NORMALIZED_PROFILE.sampleRate / window.tickRate);
  if (window.sampleCount !== sampleCount) throw new RangeError(`window.sampleCount must be exactly ${sampleCount}.`);
  const finalUnits = (window.endTick - window.startTick)
    * YALISP_CANONICAL_NORMALIZED_PROFILE.timelineRate / window.tickRate;
  if (!Number.isInteger(finalUnits)) throw new RangeError("window does not have an integral 7,000 Hz boundary.");
  return Object.freeze({ ...window, finalUnits });
}

function normalizeOperation(row, index, finalUnits, previous) {
  if (!Array.isArray(row) || row.length !== OP_FIELDS) {
    throw new TypeError(`program.operations[${index}] must contain exactly ${OP_FIELDS} fields.`);
  }
  row.forEach((value, field) => integer(value, `program.operations[${index}][${field}]`,
    (field >= 4 && field <= 10) || field === 12 ? -1 : 0));
  const [unit, order, kind, source, payloadId, register, value, digiMode, sbProPresent,
    left, right, positioned, sound] = row;
  if (unit > finalUnits) throw new RangeError(`program.operations[${index}] is beyond the explicit window.`);
  if (previous && (unit < previous.unit || (unit === previous.unit && order <= previous.order))) {
    throw new RangeError("program operations must be globally strict in absolute unit/order.");
  }
  if (kind === 1) {
    if (source !== 2 && source !== 4) throw new RangeError(`program.operations[${index}] has an unknown OPL source.`);
    if (payloadId !== -1 || register < 0 || register > 255 || value < 0 || value > 255
        || digiMode !== -1 || sbProPresent !== -1 || left !== -1 || right !== -1
        || positioned !== 0 || sound !== -1) {
      throw new RangeError(`program.operations[${index}] has malformed OPL fields.`);
    }
  } else if (kind === 2) {
    if (source !== 1 && source !== 3) throw new RangeError(`program.operations[${index}] has an unknown native source.`);
    if (payloadId < 0 || register !== -1 || value !== -1 || digiMode < 0 || digiMode > 3
        || (sbProPresent !== 0 && sbProPresent !== 1) || left < 0 || left > 15
        || right < 0 || right > 15 || (left === 15 && right === 15)
        || (positioned !== 0 && positioned !== 1) || sound < 0) {
      throw new RangeError(`program.operations[${index}] has malformed native fields.`);
    }
  } else {
    throw new RangeError(`program.operations[${index}] has unknown kind ${kind}.`);
  }
  return Object.freeze({ unit, order, kind, source, payloadId, register, value });
}

function normalizePayloadReference(row, index) {
  if (!Array.isArray(row) || row.length !== 3) {
    throw new TypeError(`program.payloadReferences[${index}] must be [id, source, reference].`);
  }
  const [id, source, reference] = row;
  integer(id, `program.payloadReferences[${index}].id`);
  integer(reference, `program.payloadReferences[${index}].reference`);
  if (source !== 1 && source !== 3) throw new RangeError(`program.payloadReferences[${index}] has unknown source.`);
  return Object.freeze({ id, source, reference });
}

function normalizeResolvedPayload(row, index) {
  exactKeys(row, ["id", "source", "reference", "pcmBytes"], `program.resolvedPayloads[${index}]`);
  integer(row.id, `program.resolvedPayloads[${index}].id`);
  integer(row.reference, `program.resolvedPayloads[${index}].reference`);
  if (row.source !== 1 && row.source !== 3) throw new RangeError(`program.resolvedPayloads[${index}] has unknown source.`);
  if (!(row.pcmBytes instanceof Uint8Array) || row.pcmBytes.length === 0 || row.pcmBytes.length % 2 !== 0) {
    throw new TypeError(`program.resolvedPayloads[${index}].pcmBytes must be non-empty mono PCM16 bytes.`);
  }
  return Object.freeze({ id: row.id, source: row.source, reference: row.reference, pcmBytes: row.pcmBytes.slice() });
}

function normalizeProgram(program, window) {
  exactKeys(program, ["finalUnits", "operations", "payloadReferences", "resolvedPayloads"], "program");
  integer(program.finalUnits, "program.finalUnits");
  if (program.finalUnits !== window.finalUnits) {
    throw new RangeError(`program.finalUnits must equal the explicit window boundary ${window.finalUnits}.`);
  }
  if (!Array.isArray(program.operations) || !Array.isArray(program.payloadReferences)
      || !Array.isArray(program.resolvedPayloads)) throw new TypeError("program lists must be arrays.");
  let previous;
  const operations = program.operations.map((row, index) => {
    const operation = normalizeOperation(row, index, window.finalUnits, previous);
    previous = operation; return operation;
  });
  const references = program.payloadReferences.map(normalizePayloadReference);
  const resolved = program.resolvedPayloads.map(normalizeResolvedPayload);
  const uniqueMap = (rows, label) => {
    const map = new Map();
    for (const row of rows) {
      if (map.has(row.id)) throw new RangeError(`duplicate ${label} id ${row.id}.`);
      map.set(row.id, row);
    }
    return map;
  };
  const referenceById = uniqueMap(references, "payload reference");
  const resolvedById = uniqueMap(resolved, "resolved payload");
  const nativeIds = operations.filter(({ kind }) => kind === 2).map(({ payloadId }) => payloadId);
  if (new Set(nativeIds).size !== nativeIds.length) throw new RangeError("native payload ids may start only once.");
  if (nativeIds.length !== references.length || nativeIds.length !== resolved.length) {
    throw new RangeError("native operations, references, and resolved payloads must be one-to-one.");
  }
  for (const operation of operations.filter(({ kind }) => kind === 2)) {
    const reference = referenceById.get(operation.payloadId), payload = resolvedById.get(operation.payloadId);
    if (!reference || !payload) throw new RangeError(`unresolved native payload ${operation.payloadId}.`);
    if (reference.source !== operation.source || payload.source !== operation.source
        || reference.reference !== payload.reference) throw new RangeError(`native payload ${operation.payloadId} linkage mismatch.`);
  }
  return Object.freeze({ operations, resolvedById });
}

function defaultDependencyError(reason, cause) {
  const error = new Error(reason, cause === undefined ? undefined : { cause });
  error.yalispAcceptanceReason = reason; return error;
}

async function defaultCreateOpl(sampleRate, channels) {
  let module;
  try { module = await import("@malvineous/opl"); }
  catch (error) { throw defaultDependencyError("default-opl-import-failure", error); }
  try { return await module.default.create(sampleRate, channels); }
  catch (error) { throw defaultDependencyError("default-opl-create-failure", error); }
}

function addOplLane(opl, operations, samples, accumulator) {
  let cursor = 0;
  const generateUntil = (until) => {
    while (cursor < until) {
      const remaining = until - cursor;
      // @malvineous/opl accepts 2..512 frames. Avoid leaving a one-frame
      // remainder after a 512-frame block: generating two and committing one
      // would advance hidden chip state across the following register write.
      const count = remaining > 512 && remaining % 512 === 1 ? 511 : Math.min(512, remaining);
      const generated = opl.generate(count, Int16Array);
      if (!(generated instanceof Int16Array) || generated.length < count * 2) {
        throw new Error("OPL generated an invalid stereo block.");
      }
      for (let frame = 0; frame < count; frame += 1) accumulator[cursor + frame] += generated[frame * 2] / 32_768;
      cursor += count;
    }
  };
  for (const operation of operations) {
    generateUntil(sampleBoundary(operation.unit));
    opl.write(operation.register, operation.value);
  }
  generateUntil(samples);
}

function addNative(operation, payload, accumulator) {
  const start = sampleBoundary(operation.unit);
  const view = new DataView(payload.pcmBytes.buffer, payload.pcmBytes.byteOffset, payload.pcmBytes.byteLength);
  const naturalSamples = payload.pcmBytes.length / 2;
  const mixedSamples = Math.max(0, Math.min(naturalSamples, accumulator.length - start));
  for (let sample = 0; sample < mixedSamples; sample += 1) {
    accumulator[start + sample] += view.getInt16(sample * 2, true) / 32_768;
  }
  return Object.freeze({ id: operation.payloadId, source: operation.source, unit: operation.unit,
    startFrame: start, naturalEndFrame: start + naturalSamples,
    clippedSamples: naturalSamples - mixedSamples });
}

function sourceClamp(value) {
  const clamped = Math.max(-1, Math.min(1, value));
  return Math.round(clamped * (clamped < 0 ? 32_768 : 32_767));
}

export function encodeYalispCanonicalNormalizedWav(pcm) {
  if (!(pcm instanceof Int16Array)) throw new TypeError("pcm must be an Int16Array.");
  const wav = new Uint8Array(44 + pcm.byteLength), view = new DataView(wav.buffer);
  for (const [offset, text] of [[0, "RIFF"], [8, "WAVE"], [12, "fmt "], [36, "data"]]) {
    for (let index = 0; index < text.length; index += 1) wav[offset + index] = text.charCodeAt(index);
  }
  view.setUint32(4, 36 + pcm.byteLength, true); view.setUint32(16, 16, true);
  view.setUint16(20, 1, true); view.setUint16(22, 1, true);
  view.setUint32(24, YALISP_CANONICAL_NORMALIZED_PROFILE.sampleRate, true);
  view.setUint32(28, YALISP_CANONICAL_NORMALIZED_PROFILE.sampleRate * 2, true);
  view.setUint16(32, 2, true); view.setUint16(34, 16, true); view.setUint32(40, pcm.byteLength, true);
  for (let index = 0; index < pcm.length; index += 1) view.setInt16(44 + index * 2, pcm[index], true);
  return wav;
}

export async function renderYalispCanonicalNormalizedAudio(options = {}) {
  return renderWithDefaultDependency(options, defaultCreateOpl);
}

async function renderWithDefaultDependency(options, ownedDefaultCreateOpl) {
  exactKeys(options, ["window", "program", "createOpl"].filter((key) => key !== "createOpl" || Object.hasOwn(options, key)), "options");
  const injected = Object.hasOwn(options, "createOpl");
  const window = normalizeWindow(options.window), program = normalizeProgram(options.program, window);
  const eligibility = injected
    ? { authoritative: false, acceptanceStatus: "diagnostic", acceptanceReasons: ["injected-opl-dependency"] }
    : { authoritative: true, acceptanceStatus: "eligible", acceptanceReasons: [] };
  const createOpl = injected ? options.createOpl : ownedDefaultCreateOpl;
  const failure = (status, reason, error) => ({ ok: false, status, authoritative: false,
    acceptanceStatus: "acceptance-ineligible",
    acceptanceReasons: [...eligibility.acceptanceReasons, reason], pcm: null, wav: null,
    ...(error === undefined ? {} : { error }) });
  if (typeof createOpl !== "function") return failure("opl-unavailable",
    injected ? "injected-opl-unavailable" : "default-opl-unavailable");
  try {
    const fx = await createOpl(YALISP_CANONICAL_NORMALIZED_PROFILE.sampleRate, 2, "fx");
    const music = await createOpl(YALISP_CANONICAL_NORMALIZED_PROFILE.sampleRate, 2, "music");
    for (const opl of [fx, music]) {
      if (!opl || typeof opl.write !== "function" || typeof opl.generate !== "function") {
        return failure("opl-unavailable", injected ? "injected-opl-invalid" : "default-opl-invalid");
      }
    }
    if (fx === music) return failure("opl-devices-not-independent",
      injected ? "injected-opl-shared-instance" : "default-opl-shared-instance");
    const accumulator = new Float64Array(window.sampleCount);
    addOplLane(fx, program.operations.filter(({ kind, source }) => kind === 1 && source === 2), window.sampleCount, accumulator);
    addOplLane(music, program.operations.filter(({ kind, source }) => kind === 1 && source === 4), window.sampleCount, accumulator);
    const nativeTails = program.operations.filter(({ kind }) => kind === 2).map((operation) =>
      addNative(operation, program.resolvedById.get(operation.payloadId), accumulator));
    const pcm = new Int16Array(window.sampleCount);
    for (let index = 0; index < pcm.length; index += 1) pcm[index] = sourceClamp(accumulator[index]);
    return { ok: true, status: "ok", ...eligibility, ...YALISP_CANONICAL_NORMALIZED_PROFILE,
      ticks: window.endTick - window.startTick, samples: window.sampleCount, pcm,
      wav: encodeYalispCanonicalNormalizedWav(pcm),
      clippedNativeTails: Object.freeze(nativeTails.filter(({ clippedSamples }) => clippedSamples > 0)) };
  } catch (error) {
    return failure("opl-unavailable", injected ? "injected-opl-runtime-failure"
      : error?.yalispAcceptanceReason ?? "default-opl-runtime-failure", error);
  }
}

// A module-owned negative seam exercises default-dependency failure semantics
// without accepting a caller factory and can never produce an authoritative result.
export function testOnlyYalispCanonicalDefaultOplFailure(options = {}, phase = "runtime") {
  if (!["import", "create", "runtime", "shared"].includes(phase)) {
    throw new RangeError("test-only default OPL failure phase");
  }
  let shared;
  const ownedFailure = async () => {
    if (phase === "import") throw defaultDependencyError("default-opl-import-failure");
    if (phase === "create") throw defaultDependencyError("default-opl-create-failure");
    if (phase === "shared") return shared ??= { write() {}, generate(count) { return new Int16Array(count * 2); } };
    return { write() {}, generate() { throw new Error("test-only default OPL runtime failure"); } };
  };
  return renderWithDefaultDependency(options, ownedFailure);
}
