// Browser/Node host for the register and PCM contracts exported by wl-sound.lisp.
// Asset decoding and device selection stay in Lisp.  This adapter only schedules
// already-decoded OPL writes or native PCM, and reports an unavailable result
// instead of inventing silence when its OPL or playback dependency is absent.

export const YALISP_HOST_SAMPLE_RATE = 44_100;
export const YALISP_HOST_CHANNELS = 2;
export const YALISP_NATIVE_PCM_RATE = 49_716;
export const YALISP_AGGREGATE_TIMELINE_RATE = 7_000;
export const YALISP_AGGREGATE_MIX_POLICY = "sum-then-clamp-i16-v1";

function integer(value, label, minimum = 0) {
  if (!Number.isInteger(value) || value < minimum) throw new RangeError(`${label} must be an integer >= ${minimum}.`);
  return value;
}

function clampI16(value) { return Math.max(-32_768, Math.min(32_767, Math.round(value))); }
function frameBoundary(services, serviceRate, sampleRate) {
  return Math.floor(services * sampleRate / serviceRate);
}

export function parseYalispRegisterLog(text) {
  if (typeof text !== "string") throw new TypeError("YALisp register output must be a string.");
  const source = text.trim();
  if (source === "nil" || source === "()") return [];
  const events = [];
  let consumed = "";
  const pattern = /\(\s*(-?\d+)\s+(-?\d+)\s+(-?\d+)\s*\)/g;
  for (const match of source.matchAll(pattern)) {
    consumed += match[0];
    events.push(match.slice(1).map(Number));
  }
  const normalized = source.replace(/^\s*\(\s*/, "").replace(/\s*\)\s*$/, "").replace(/\s+/g, "");
  if (!events.length || consumed.replace(/\s+/g, "") !== normalized) {
    throw new SyntaxError("Expected a YALisp list of (service register value) triples.");
  }
  return events;
}

export function parseYalispRegisterProgram(text) {
  if (typeof text !== "string") throw new TypeError("YALisp register program must be a string.");
  const match = /^\s*\(\s*(\d+)\s+(\(.*\)|nil)\s*\)\s*$/s.exec(text);
  if (!match) throw new SyntaxError("Expected (services ((service register value) ...)).");
  return { services: integer(Number(match[1]), "services"), registerEvents: parseYalispRegisterLog(match[2]) };
}

export function parseYalispAudioHostEventLog(text) {
  if (typeof text !== "string") throw new TypeError("YALisp audio host events must be a string.");
  const source = text.trim();
  if (source === "nil" || source === "()") return [];
  const pattern = /\(\s*(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+(-?\d+)\s+([^\s()]+)\s*\)/g;
  const events = []; let consumed = "";
  for (const match of source.matchAll(pattern)) {
    consumed += match[0];
    const numbers = match.slice(1, 10).map(Number);
    events.push({
      tick: numbers[0], sound: numbers[1], soundMode: numbers[2], digiMode: numbers[3],
      source: numbers[4], left: numbers[5], right: numbers[6], positioned: numbers[7],
      sbProPresent: Boolean(numbers[8]), callsite: match[10],
    });
  }
  const normalized = source.replace(/^\s*\(\s*/, "").replace(/\s*\)\s*$/, "").replace(/\s+/g, "");
  if (!events.length || consumed.replace(/\s+/g, "") !== normalized) throw new SyntaxError("Expected YALisp 10-field audio host events.");
  return events;
}

export function normalizeYalispRegisterEvents(input) {
  const values = typeof input === "string" ? parseYalispRegisterLog(input) : input;
  if (!Array.isArray(values)) throw new TypeError("registerEvents must be an array or a YALisp list string.");
  let priorService = -1;
  return values.map((entry, order) => {
    const service = integer(Array.isArray(entry) ? entry[0] : entry?.service ?? entry?.tick, `event ${order} service`);
    const register = integer(Array.isArray(entry) ? entry[1] : entry?.register ?? entry?.address, `event ${order} register`);
    const value = integer(Array.isArray(entry) ? entry[2] : entry?.value, `event ${order} value`);
    if (service < priorService) throw new RangeError("registerEvents must be in nondecreasing service order.");
    if (register > 0xff || value > 0xff) throw new RangeError(`event ${order} register/value must fit in one byte.`);
    priorService = service;
    return { service, register, value, order };
  });
}

export function encodeYalispStereoWav(pcm, sampleRate = YALISP_HOST_SAMPLE_RATE) {
  if (!(pcm instanceof Int16Array)) throw new TypeError("pcm must be an Int16Array.");
  if (pcm.length % 2) throw new RangeError("stereo PCM must contain an even number of samples.");
  integer(sampleRate, "sampleRate", 1);
  const wav = new Uint8Array(44 + pcm.byteLength), view = new DataView(wav.buffer);
  for (const [at, value] of [[0, "RIFF"], [8, "WAVE"], [12, "fmt "], [36, "data"]]) {
    for (let index = 0; index < value.length; index += 1) wav[at + index] = value.charCodeAt(index);
  }
  view.setUint32(4, 36 + pcm.byteLength, true); view.setUint32(16, 16, true);
  view.setUint16(20, 1, true); view.setUint16(22, 2, true);
  view.setUint32(24, sampleRate, true); view.setUint32(28, sampleRate * 4, true);
  view.setUint16(32, 4, true); view.setUint16(34, 16, true); view.setUint32(40, pcm.byteLength, true);
  for (let index = 0; index < pcm.length; index += 1) view.setInt16(44 + index * 2, pcm[index], true);
  return wav;
}

async function defaultCreateOpl(sampleRate) {
  const module = await import("@malvineous/opl");
  return module.default.create(sampleRate, YALISP_HOST_CHANNELS);
}

export async function renderYalispOplRegisterProgram({
  registerEvents,
  serviceRate,
  services,
  releaseServices = 0,
  sampleRate = YALISP_HOST_SAMPLE_RATE,
  createOpl = defaultCreateOpl,
} = {}) {
  const events = normalizeYalispRegisterEvents(registerEvents ?? []);
  integer(serviceRate, "serviceRate", 1); integer(releaseServices, "releaseServices"); integer(sampleRate, "sampleRate", 1);
  const inferredServices = events.length ? events.at(-1).service + 1 : 0;
  const durationServices = services === undefined ? inferredServices : integer(services, "services");
  if (events.some((event) => event.service > durationServices)) throw new RangeError("register event falls after the program duration.");
  if (typeof createOpl !== "function") return { ok: false, status: "opl-unavailable", pcm: null, wav: null };
  try {
    const opl = await createOpl(sampleRate, YALISP_HOST_CHANNELS);
    if (!opl || typeof opl.write !== "function" || typeof opl.generate !== "function") {
      return { ok: false, status: "opl-unavailable", pcm: null, wav: null };
    }
    const frames = frameBoundary(durationServices + releaseServices, serviceRate, sampleRate);
    const pcm = new Int16Array(frames * 2);
    let writeFrame = 0;
    const renderUntil = (until) => {
      let remaining = until - writeFrame;
      while (remaining > 0) {
        const count = Math.min(512, remaining);
        const generated = opl.generate(count === 1 ? 2 : count, Int16Array);
        if (!(generated instanceof Int16Array) || generated.length < count * 2) throw new Error("OPL generated an invalid stereo block.");
        pcm.set(generated.subarray(0, count * 2), writeFrame * 2);
        writeFrame += count; remaining -= count;
      }
    };
    for (const event of events) {
      renderUntil(frameBoundary(event.service, serviceRate, sampleRate));
      opl.write(event.register, event.value);
    }
    renderUntil(frames);
    return { ok: true, status: "ok", sampleRate, channels: 2, frames, pcm, wav: encodeYalispStereoWav(pcm, sampleRate) };
  } catch (error) {
    return { ok: false, status: "opl-unavailable", pcm: null, wav: null, error };
  }
}

export function renderYalispNativePcm({
  pcm,
  sampleRate = YALISP_NATIVE_PCM_RATE,
  outputRate = YALISP_HOST_SAMPLE_RATE,
  source,
  digiMode = 0,
  sbProPresent = false,
  left = 0,
  right = 0,
} = {}) {
  if (!(pcm instanceof Uint8Array) || pcm.byteLength % 2) throw new TypeError("native pcm must be little-endian PCM16 bytes.");
  integer(sampleRate, "sampleRate", 1); integer(outputRate, "outputRate", 1);
  if (source !== 1 && source !== 3) throw new RangeError("native PCM source must be 1 (PC) or 3 (digitized).");
  integer(left, "left"); integer(right, "right");
  if (left > 15 || right > 15 || (left === 15 && right === 15)) throw new RangeError("illegal Wolf3D sound position.");
  const sourceFrames = pcm.byteLength / 2, frames = Math.floor(sourceFrames * outputRate / sampleRate);
  const output = new Int16Array(frames * 2), view = new DataView(pcm.buffer, pcm.byteOffset, pcm.byteLength);
  const positionedSb = source === 3 && digiMode === 3 && Boolean(sbProPresent);
  const leftGain = positionedSb ? (15 - left) / 15 : 1, rightGain = positionedSb ? (15 - right) / 15 : 1;
  for (let frame = 0; frame < frames; frame += 1) {
    const value = view.getInt16(Math.floor(frame * sampleRate / outputRate) * 2, true);
    output[frame * 2] = clampI16(value * leftGain); output[frame * 2 + 1] = clampI16(value * rightGain);
  }
  return { ok: true, status: "ok", sampleRate: outputRate, channels: 2, frames, pcm: output, wav: encodeYalispStereoWav(output, outputRate) };
}

function aggregateOperationKey({ unit, order }) { return `${unit}:${order}`; }

function normalizeAggregateOperations(oplWrites, nativeStarts, cursorUnit, throughUnit, seenNativeIds, seenOperationKeys, lastOperation) {
  if (!Array.isArray(oplWrites) || !Array.isArray(nativeStarts)) throw new TypeError("oplWrites and nativeStarts must be arrays.");
  const operations = [];
  const keys = new Set();
  const normalizePosition = (operation, label) => {
    if (!operation || typeof operation !== "object" || Array.isArray(operation)) throw new TypeError(`${label} must be an object.`);
    const unit = integer(operation.unit, `${label} unit`), order = integer(operation.order, `${label} order`);
    if (unit < cursorUnit || unit > throughUnit) throw new RangeError(`${label} is outside the drain timeline window.`);
    const key = aggregateOperationKey({ unit, order });
    if (keys.has(key) || seenOperationKeys.has(key)) throw new RangeError(`duplicate aggregate operation position ${key}.`);
    keys.add(key);
    return { unit, order };
  };
  let prior;
  for (let index = 0; index < oplWrites.length; index += 1) {
    const input = oplWrites[index], position = normalizePosition(input, `oplWrites[${index}]`);
    const register = integer(input.register, `oplWrites[${index}] register`);
    const value = integer(input.value, `oplWrites[${index}] value`);
    if (register > 0xff || value > 0xff) throw new RangeError(`oplWrites[${index}] register/value must fit in one byte.`);
    const operation = { ...position, key: aggregateOperationKey(position), kind: "opl", register, value };
    if (prior && (operation.unit < prior.unit || (operation.unit === prior.unit && operation.order <= prior.order))) {
      throw new RangeError("oplWrites must be in strictly increasing unit/order position.");
    }
    prior = operation; operations.push(operation);
  }
  prior = undefined;
  const batchNativeIds = new Set();
  for (let index = 0; index < nativeStarts.length; index += 1) {
    const input = nativeStarts[index], position = normalizePosition(input, `nativeStarts[${index}]`);
    if ((typeof input.id !== "string" && !Number.isInteger(input.id)) || String(input.id).length === 0) {
      throw new TypeError(`nativeStarts[${index}] requires a non-empty string or integer id.`);
    }
    const id = `${typeof input.id}:${input.id}`;
    if (seenNativeIds.has(id) || batchNativeIds.has(id)) throw new RangeError(`duplicate native payload id ${String(input.id)}.`);
    if (!(input.pcm instanceof Uint8Array)) throw new TypeError(`nativeStarts[${index}] requires Uint8Array pcm.`);
    const operation = { ...position, key: aggregateOperationKey(position), kind: "native", id, input };
    if (prior && (operation.unit < prior.unit || (operation.unit === prior.unit && operation.order <= prior.order))) {
      throw new RangeError("nativeStarts must be in strictly increasing unit/order position.");
    }
    prior = operation; batchNativeIds.add(id); operations.push(operation);
  }
  operations.sort((left, right) => left.unit - right.unit || left.order - right.order);
  if (lastOperation && operations.length && (operations[0].unit < lastOperation.unit
      || (operations[0].unit === lastOperation.unit && operations[0].order <= lastOperation.order))) {
    throw new RangeError("aggregate operations must be in globally increasing unit/order position.");
  }
  return operations;
}

export async function openYalispAggregateCapture({
  sampleRate = YALISP_HOST_SAMPLE_RATE,
  timelineRate = YALISP_AGGREGATE_TIMELINE_RATE,
  mixPolicy = YALISP_AGGREGATE_MIX_POLICY,
  createOpl = defaultCreateOpl,
} = {}) {
  integer(sampleRate, "sampleRate", 1); integer(timelineRate, "timelineRate", 1);
  if (sampleRate !== YALISP_HOST_SAMPLE_RATE) throw new RangeError(`sampleRate must be ${YALISP_HOST_SAMPLE_RATE}.`);
  if (timelineRate !== YALISP_AGGREGATE_TIMELINE_RATE) throw new RangeError(`timelineRate must be ${YALISP_AGGREGATE_TIMELINE_RATE}.`);
  if (mixPolicy !== YALISP_AGGREGATE_MIX_POLICY) throw new RangeError(`unsupported aggregate mix policy ${String(mixPolicy)}.`);
  if (typeof createOpl !== "function") return { ok: false, status: "opl-unavailable" };
  try {
    const opl = await createOpl(sampleRate, YALISP_HOST_CHANNELS);
    if (!opl || typeof opl.write !== "function" || typeof opl.generate !== "function") return { ok: false, status: "opl-unavailable" };
    let cursorUnit = 0, cursorFrame = 0, finished = false, accumulator = new Float64Array(0), nativeEndFrame = 0;
    const seenNativeIds = new Set(), seenOperationKeys = new Set();
    let lastOperation;
    const ensureFrames = (frames) => {
      if (frames * 2 <= accumulator.length) return;
      const grown = new Float64Array(frames * 2); grown.set(accumulator); accumulator = grown;
    };
    const generateUntil = (untilFrame) => {
      ensureFrames(untilFrame);
      while (cursorFrame < untilFrame) {
        const count = Math.min(512, untilFrame - cursorFrame);
        const generated = opl.generate(count === 1 ? 2 : count, Int16Array);
        if (!(generated instanceof Int16Array) || generated.length < count * 2) throw new Error("OPL generated an invalid stereo block.");
        for (let sample = 0; sample < count * 2; sample += 1) accumulator[cursorFrame * 2 + sample] += generated[sample];
        cursorFrame += count;
      }
    };
    const drain = ({ oplWrites = [], nativeStarts = [], throughUnit } = {}) => {
      if (finished) return { ok: false, status: "capture-finished" };
      integer(throughUnit, "throughUnit");
      if (throughUnit < cursorUnit) throw new RangeError("throughUnit cannot move backwards.");
      const operations = normalizeAggregateOperations(oplWrites, nativeStarts, cursorUnit, throughUnit,
        seenNativeIds, seenOperationKeys, lastOperation);
      for (const operation of operations) {
        const frame = frameBoundary(operation.unit, timelineRate, sampleRate);
        generateUntil(frame);
        if (operation.kind === "opl") {
          opl.write(operation.register, operation.value);
        } else {
          const rendered = renderYalispNativePcm({ ...operation.input, outputRate: sampleRate });
          const endFrame = frame + rendered.frames;
          ensureFrames(endFrame);
          for (let sample = 0; sample < rendered.pcm.length; sample += 1) accumulator[frame * 2 + sample] += rendered.pcm[sample];
          nativeEndFrame = Math.max(nativeEndFrame, endFrame);
          seenNativeIds.add(operation.id);
        }
        seenOperationKeys.add(operation.key); lastOperation = operation;
      }
      const endFrame = frameBoundary(throughUnit, timelineRate, sampleRate);
      generateUntil(endFrame); cursorUnit = throughUnit;
      return { ok: true, status: "ok", throughUnit, throughFrame: endFrame, operations: operations.length };
    };
    const finish = (options) => {
      if (!options || options.throughUnit === undefined) throw new TypeError("finish requires an explicit throughUnit.");
      if (finished) return { ok: false, status: "capture-finished", pcm: null, wav: null };
      const result = drain({ oplWrites: options.oplWrites ?? [], nativeStarts: options.nativeStarts ?? [], throughUnit: options.throughUnit });
      const frames = frameBoundary(options.throughUnit, timelineRate, sampleRate);
      if (nativeEndFrame > frames) throw new RangeError("finish throughUnit would trim a native PCM payload.");
      finished = true;
      const pcm = new Int16Array(frames * 2);
      for (let sample = 0; sample < pcm.length; sample += 1) pcm[sample] = clampI16(accumulator[sample]);
      return { ...result, status: "finished", sampleRate, channels: 2, frames, pcm, wav: encodeYalispStereoWav(pcm, sampleRate), mixPolicy, timelineRate };
    };
    return {
      ok: true, status: "ready", sampleRate, channels: 2, timelineRate, mixPolicy, drain, finish,
      get cursorUnit() { return cursorUnit; }, get finished() { return finished; },
    };
  } catch (error) { return { ok: false, status: "opl-unavailable", error }; }
}

export function createYalispAudioHost({ createOpl = defaultCreateOpl, audioContextFactory } = {}) {
  let context;
  const renderRegisters = (program) => renderYalispOplRegisterProgram({ ...program, createOpl });
  const openAggregateCapture = (options) => openYalispAggregateCapture({ ...options, createOpl });
  const openRegisterSink = async ({ serviceRate, sampleRate = YALISP_HOST_SAMPLE_RATE } = {}) => {
    integer(serviceRate, "serviceRate", 1); integer(sampleRate, "sampleRate", 1);
    if (typeof createOpl !== "function") return { ok: false, status: "opl-unavailable" };
    try {
      const opl = await createOpl(sampleRate, YALISP_HOST_CHANNELS);
      if (!opl || typeof opl.write !== "function" || typeof opl.generate !== "function") return { ok: false, status: "opl-unavailable" };
      let cursorService = 0, closed = false;
      const drain = ({ registerEvents = [], throughService } = {}) => {
        if (closed) return { ok: false, status: "sink-closed", pcm: null, wav: null };
        integer(throughService, "throughService");
        if (throughService < cursorService) throw new RangeError("throughService cannot move backwards.");
        const events = normalizeYalispRegisterEvents(registerEvents);
        if (events.some(({ service }) => service < cursorService || service > throughService)) {
          throw new RangeError("drained register event is outside the sink service window.");
        }
        const startFrame = frameBoundary(cursorService, serviceRate, sampleRate);
        const endFrame = frameBoundary(throughService, serviceRate, sampleRate);
        const pcm = new Int16Array((endFrame - startFrame) * 2);
        let absoluteFrame = startFrame;
        const renderUntil = (until) => {
          let remaining = until - absoluteFrame;
          while (remaining > 0) {
            const count = Math.min(512, remaining), generated = opl.generate(count === 1 ? 2 : count, Int16Array);
            if (!(generated instanceof Int16Array) || generated.length < count * 2) throw new Error("OPL generated an invalid stereo block.");
            pcm.set(generated.subarray(0, count * 2), (absoluteFrame - startFrame) * 2);
            absoluteFrame += count; remaining -= count;
          }
        };
        for (const event of events) {
          renderUntil(frameBoundary(event.service, serviceRate, sampleRate));
          opl.write(event.register, event.value);
        }
        renderUntil(endFrame); cursorService = throughService;
        return { ok: true, status: "ok", sampleRate, channels: 2, frames: endFrame - startFrame, pcm, wav: encodeYalispStereoWav(pcm, sampleRate) };
      };
      return {
        ok: true, status: "ready", serviceRate, sampleRate, drain,
        close() { closed = true; return true; },
        get cursorService() { return cursorService; },
      };
    } catch (error) { return { ok: false, status: "opl-unavailable", error }; }
  };
  const renderEvent = async (event = {}) => {
    if (event.source === 1 || event.source === 3) {
      if (!(event.pcm instanceof Uint8Array)) return { ok: false, status: "native-pcm-unavailable", pcm: null, wav: null };
      try { return renderYalispNativePcm(event); }
      catch (error) { return { ok: false, status: "native-pcm-invalid", pcm: null, wav: null, error }; }
    }
    if (event.source === 2 || event.source === 4) return renderRegisters(event);
    return { ok: false, status: "unsupported-source", pcm: null, wav: null };
  };
  const play = async (rendered, { when = 0, loop = false } = {}) => {
    if (!rendered?.ok || !(rendered.pcm instanceof Int16Array)) return { ok: false, status: rendered?.status ?? "render-unavailable" };
    const factory = audioContextFactory ?? (() => typeof AudioContext === "function" ? new AudioContext({ sampleRate: rendered.sampleRate }) : undefined);
    try {
      context ??= factory();
      if (!context?.createBuffer || !context?.createBufferSource) return { ok: false, status: "audio-context-unavailable" };
      const buffer = context.createBuffer(2, rendered.frames, rendered.sampleRate);
      const left = buffer.getChannelData(0), right = buffer.getChannelData(1);
      for (let frame = 0; frame < rendered.frames; frame += 1) {
        left[frame] = rendered.pcm[frame * 2] / 32768; right[frame] = rendered.pcm[frame * 2 + 1] / 32768;
      }
      const node = context.createBufferSource(); node.buffer = buffer; node.loop = Boolean(loop); node.connect(context.destination); node.start(when);
      return { ok: true, status: "playing", node, context };
    } catch (error) { return { ok: false, status: "audio-context-unavailable", error }; }
  };
  return { openAggregateCapture, openRegisterSink, renderRegisters, renderEvent, play, get context() { return context; } };
}
