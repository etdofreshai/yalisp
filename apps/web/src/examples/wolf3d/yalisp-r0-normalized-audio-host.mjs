// Independent normalized-audio renderer for the YALisp R0 route.
//
// This is deliberately not a browser playback adapter.  Its inputs are the
// source-port's complete FX and music register programs, and its only output
// profile is the retained wolf3d-normalized-wav-v1 comparison profile.

import { createHash } from "node:crypto";

export const YALISP_R0_NORMALIZED_PROFILE = Object.freeze({
  sampleRate: 49_716,
  channels: 1,
  bitsPerSample: 16,
  tickRate: 70,
  ticks: 149,
  samples: 105_824,
  fxServiceRate: 140,
  musicServiceRate: 700,
});

export const YALISP_R0_ROUTE_EXPORT_DEPENDENCY =
  "R0 must export complete source-bound FX and music register programs before an authoritative render is eligible.";

export const YALISP_R0_REGISTER_EXPORT_FORMAT = "wolf3d-yalisp-r0-register-programs-v1";
export const YALISP_R0_REGISTER_EXPORT_ROUTE = "R0-full-lifecycle";
export const YALISP_R0_REGISTER_EXPORT_PRODUCER = "app.r0-audio-register-programs";

// These remain deliberately unavailable until a live R0 run exports both
// complete programs. Self-declared envelope hashes are integrity checks, not
// authority; acceptance requires these independently reviewed module pins.
export const YALISP_R0_LIVE_PROGRAM_PINS = Object.freeze({
  fx: Object.freeze({ eventCount: null, sha256: null }),
  music: Object.freeze({ eventCount: null, sha256: null }),
});

function integer(value, label, minimum = 0) {
  if (!Number.isInteger(value) || value < minimum) {
    throw new RangeError(`${label} must be an integer >= ${minimum}.`);
  }
  return value;
}

function boundary(position, rate) {
  return Math.floor(position * YALISP_R0_NORMALIZED_PROFILE.sampleRate / rate);
}

function exactKeys(value, keys, label) {
  if (!value || typeof value !== "object" || Array.isArray(value)) throw new TypeError(`${label} must be an object.`);
  const observed = Object.keys(value).sort(), expected = [...keys].sort();
  if (observed.length !== expected.length || observed.some((key, index) => key !== expected[index])) {
    throw new TypeError(`${label} schema does not match the route-export contract.`);
  }
}

function canonicalTriples(registerEvents, label) {
  if (!Array.isArray(registerEvents) || registerEvents.length === 0) {
    throw new TypeError(`${label}.registerEvents must be a non-empty source-bound array.`);
  }
  return registerEvents.map((entry, index) => {
    if (Array.isArray(entry)) {
      if (entry.length !== 3) throw new TypeError(`${label}.registerEvents[${index}] must be an exact register triple.`);
      return [...entry];
    }
    exactKeys(entry, ["service", "register", "value"], `${label}.registerEvents[${index}]`);
    return [entry.service, entry.register, entry.value];
  });
}

export function digestYalispR0RegisterProgram({ lane, serviceRate, services, registerEvents } = {}) {
  if (lane !== "fx" && lane !== "music") throw new RangeError("register program lane must be fx or music.");
  const triples = canonicalTriples(registerEvents, `${lane}Program`);
  return createHash("sha256").update(JSON.stringify({ lane, serviceRate, services, registerEvents: triples })).digest("hex");
}

function normalizeProgram(program, label, lane, serviceRate) {
  if (!program || typeof program !== "object" || Array.isArray(program)) {
    throw new TypeError(`${label} must be an explicit register program.`);
  }
  exactKeys(program, ["lane", "serviceRate", "services", "eventCount", "sha256", "registerEvents"], label);
  if (program.lane !== lane) throw new RangeError(`${label}.lane must be ${lane}.`);
  if (program.serviceRate !== serviceRate) {
    throw new RangeError(`${label}.serviceRate must be ${serviceRate}.`);
  }
  const expectedServices = YALISP_R0_NORMALIZED_PROFILE.ticks * serviceRate
    / YALISP_R0_NORMALIZED_PROFILE.tickRate;
  if (program.services !== expectedServices) {
    throw new RangeError(`${label}.services must be the complete ${expectedServices}-service R0 window.`);
  }
  const triples = canonicalTriples(program.registerEvents, label);
  if (program.eventCount !== triples.length) throw new RangeError(`${label}.eventCount does not match registerEvents.`);
  const digest = digestYalispR0RegisterProgram({ ...program, registerEvents: triples });
  if (program.sha256 !== digest) throw new RangeError(`${label}.sha256 does not match its register program content.`);
  let priorService = -1;
  const registerEvents = triples.map((entry, index) => {
    const [service, register, value] = entry;
    integer(service, `${label}.registerEvents[${index}].service`);
    integer(register, `${label}.registerEvents[${index}].register`);
    integer(value, `${label}.registerEvents[${index}].value`);
    if (service < priorService) throw new RangeError(`${label} register services must be nondecreasing.`);
    if (service >= expectedServices) throw new RangeError(`${label} register event is outside the R0 capture window.`);
    if (register > 0xff || value > 0xff) throw new RangeError(`${label} register/value must fit in one byte.`);
    priorService = service;
    return Object.freeze({ service, register, value, order: index });
  });
  return Object.freeze({ lane, serviceRate, services: expectedServices, eventCount: triples.length, sha256: digest, registerEvents });
}

function normalizeRouteExport(routeExport) {
  exactKeys(routeExport, ["format", "route", "producer", "window", "lanes"], "routeExport");
  if (routeExport.format !== YALISP_R0_REGISTER_EXPORT_FORMAT
      || routeExport.route !== YALISP_R0_REGISTER_EXPORT_ROUTE
      || routeExport.producer !== YALISP_R0_REGISTER_EXPORT_PRODUCER) {
    throw new RangeError("routeExport identity does not match the R0 register-program producer contract.");
  }
  exactKeys(routeExport.window, ["startTick", "endTick", "tickRate", "ticks"], "routeExport.window");
  const expectedWindow = { startTick: 0, endTick: 149, tickRate: 70, ticks: 149 };
  for (const [key, expected] of Object.entries(expectedWindow)) {
    if (routeExport.window[key] !== expected) throw new RangeError(`routeExport.window.${key} must be ${expected}.`);
  }
  exactKeys(routeExport.lanes, ["fx", "music"], "routeExport.lanes");
  return Object.freeze({
    fx: normalizeProgram(routeExport.lanes.fx, "routeExport.lanes.fx", "fx", 140),
    music: normalizeProgram(routeExport.lanes.music, "routeExport.lanes.music", "music", 700),
  });
}

function acceptanceReasons(programs, injectedOpl) {
  const reasons = [];
  if (injectedOpl) reasons.push("injected-opl-dependency");
  for (const lane of ["fx", "music"]) {
    const pin = YALISP_R0_LIVE_PROGRAM_PINS[lane];
    if (!Number.isInteger(pin.eventCount) || !/^[0-9a-f]{64}$/.test(pin.sha256 ?? "")) {
      reasons.push(`${lane}-live-program-pin-unavailable`);
    } else if (programs[lane].eventCount !== pin.eventCount || programs[lane].sha256 !== pin.sha256) {
      reasons.push(`${lane}-live-program-pin-mismatch`);
    }
  }
  return reasons;
}

async function defaultCreateOpl(sampleRate) {
  const module = await import("@malvineous/opl");
  return module.default.create(sampleRate, 2);
}

function addMonoProgram(opl, program, accumulator) {
  let cursor = 0;
  const generateUntil = (until) => {
    while (cursor < until) {
      const count = Math.min(512, until - cursor);
      const generated = opl.generate(count === 1 ? 2 : count, Int16Array);
      if (!(generated instanceof Int16Array) || generated.length < count * 2) {
        throw new Error("OPL generated an invalid stereo block.");
      }
      for (let frame = 0; frame < count; frame += 1) {
        accumulator[cursor + frame] += generated[frame * 2] / 32_768;
      }
      cursor += count;
    }
  };
  for (const event of program.registerEvents) {
    generateUntil(boundary(event.service, program.serviceRate));
    opl.write(event.register, event.value);
  }
  generateUntil(YALISP_R0_NORMALIZED_PROFILE.samples);
}

function sourceClamp(value) {
  const clamped = Math.max(-1, Math.min(1, value));
  return Math.round(clamped * (clamped < 0 ? 32_768 : 32_767));
}

export function encodeYalispR0NormalizedWav(pcm) {
  if (!(pcm instanceof Int16Array) || pcm.length !== YALISP_R0_NORMALIZED_PROFILE.samples) {
    throw new TypeError(`pcm must contain exactly ${YALISP_R0_NORMALIZED_PROFILE.samples} mono PCM16 samples.`);
  }
  const wav = new Uint8Array(44 + pcm.byteLength), view = new DataView(wav.buffer);
  for (const [offset, text] of [[0, "RIFF"], [8, "WAVE"], [12, "fmt "], [36, "data"]]) {
    for (let index = 0; index < text.length; index += 1) wav[offset + index] = text.charCodeAt(index);
  }
  view.setUint32(4, 36 + pcm.byteLength, true);
  view.setUint32(16, 16, true);
  view.setUint16(20, 1, true);
  view.setUint16(22, 1, true);
  view.setUint32(24, YALISP_R0_NORMALIZED_PROFILE.sampleRate, true);
  view.setUint32(28, YALISP_R0_NORMALIZED_PROFILE.sampleRate * 2, true);
  view.setUint16(32, 2, true);
  view.setUint16(34, 16, true);
  view.setUint32(40, pcm.byteLength, true);
  for (let index = 0; index < pcm.length; index += 1) view.setInt16(44 + index * 2, pcm[index], true);
  return wav;
}

export async function renderYalispR0NormalizedAudio({
  sampleRate,
  channels,
  bitsPerSample,
  ticks,
  routeExport,
  createOpl,
} = {}) {
  const profile = YALISP_R0_NORMALIZED_PROFILE;
  if (sampleRate !== profile.sampleRate || channels !== profile.channels
      || bitsPerSample !== profile.bitsPerSample || ticks !== profile.ticks) {
    throw new RangeError("R0 normalized audio requires the exact 49,716 Hz mono PCM16 149-tick profile.");
  }
  const programs = normalizeRouteExport(routeExport), { fx, music } = programs;
  const injectedOpl = createOpl !== undefined, oplFactory = injectedOpl ? createOpl : defaultCreateOpl;
  const reasons = acceptanceReasons(programs, injectedOpl);
  const eligibility = { authoritative: reasons.length === 0, acceptanceStatus: reasons.length ? "acceptance-ineligible" : "eligible", acceptanceReasons: reasons };
  if (typeof oplFactory !== "function") {
    return { ok: false, status: "opl-unavailable", ...eligibility, pcm: null, wav: null };
  }
  try {
    const fxOpl = await oplFactory(profile.sampleRate, 2, "fx");
    const musicOpl = await oplFactory(profile.sampleRate, 2, "music");
    for (const opl of [fxOpl, musicOpl]) {
      if (!opl || typeof opl.write !== "function" || typeof opl.generate !== "function") {
        return { ok: false, status: "opl-unavailable", ...eligibility, pcm: null, wav: null };
      }
    }
    if (fxOpl === musicOpl) {
      return { ok: false, status: "opl-voices-not-independent", ...eligibility, pcm: null, wav: null };
    }
    const accumulator = new Float64Array(profile.samples);
    addMonoProgram(fxOpl, fx, accumulator);
    addMonoProgram(musicOpl, music, accumulator);
    const pcm = new Int16Array(profile.samples);
    for (let index = 0; index < pcm.length; index += 1) pcm[index] = sourceClamp(accumulator[index]);
    return {
      ok: true,
      status: "ok",
      ...eligibility,
      format: "wolf3d-normalized-wav-v1",
      sampleRate: profile.sampleRate,
      channels: profile.channels,
      bitsPerSample: profile.bitsPerSample,
      ticks: profile.ticks,
      samples: profile.samples,
      pcm,
      wav: encodeYalispR0NormalizedWav(pcm),
    };
  } catch (error) {
    return { ok: false, status: "opl-unavailable", ...eligibility, pcm: null, wav: null, error };
  }
}
