import assert from "node:assert/strict";
import test from "node:test";

import {
  YALISP_AGGREGATE_MIX_POLICY,
  createYalispAudioHost,
} from "../src/examples/wolf3d/yalisp-opl-audio-host.mjs";
import {
  YALISP_R0_NORMALIZED_PROFILE,
  YALISP_R0_REGISTER_EXPORT_FORMAT,
  YALISP_R0_REGISTER_EXPORT_PRODUCER,
  YALISP_R0_REGISTER_EXPORT_ROUTE,
  digestYalispR0RegisterProgram,
  renderYalispR0NormalizedAudio,
} from "../src/examples/wolf3d/yalisp-r0-normalized-audio-host.mjs";
import {
  YALISP_CANONICAL_NORMALIZED_PROFILE,
  renderYalispCanonicalNormalizedAudio,
} from "../src/examples/wolf3d/yalisp-canonical-normalized-audio-host.mjs";

function oplFactory() {
  return async () => {
    let level = 0;
    return {
      write(register, value) { level = (level + register + value) & 0x7fff; },
      generate(frames) { return new Int16Array(frames * 2).fill(level); },
    };
  };
}

function pcmBytes(...samples) {
  const bytes = new Uint8Array(samples.length * 2);
  const view = new DataView(bytes.buffer);
  samples.forEach((sample, index) => view.setInt16(index * 2, sample, true));
  return bytes;
}

function lane(laneName, serviceRate, services, registerEvents) {
  const program = { lane: laneName, serviceRate, services, registerEvents };
  return {
    ...program,
    eventCount: registerEvents.length,
    sha256: digestYalispR0RegisterProgram(program),
  };
}

test("the promoted aggregate host preserves one ordered OPL and native PCM timeline", async () => {
  const host = createYalispAudioHost({ createOpl: oplFactory() });
  const capture = await host.openAggregateCapture();
  assert.equal(capture.ok, true);
  capture.drain({
    throughUnit: 10,
    oplWrites: [
      { unit: 0, order: 0, register: 0x20, value: 6 },
      { unit: 10, order: 0, register: 0xb0, value: 0 },
    ],
    nativeStarts: [{
      id: "pc",
      unit: 0,
      order: 1,
      pcm: pcmBytes(1000, -1000, 2000, -2000),
      source: 1,
    }],
  });
  const rendered = capture.finish({ throughUnit: 11 });
  assert.equal(rendered.ok, true);
  assert.equal(rendered.mixPolicy, YALISP_AGGREGATE_MIX_POLICY);
  assert.equal(rendered.sampleRate, 44_100);
  assert.ok(rendered.pcm instanceof Int16Array);
  assert.equal(new DataView(rendered.wav.buffer).getUint16(22, true), 2);
});

test("the promoted R0 normalized host enforces the exact route profile and remains diagnostic with injected OPL", async () => {
  const profile = YALISP_R0_NORMALIZED_PROFILE;
  const routeExport = {
    format: YALISP_R0_REGISTER_EXPORT_FORMAT,
    route: YALISP_R0_REGISTER_EXPORT_ROUTE,
    producer: YALISP_R0_REGISTER_EXPORT_PRODUCER,
    window: { startTick: 0, endTick: 149, tickRate: 70, ticks: 149 },
    lanes: {
      fx: lane("fx", 140, 298, [[0, 0x20, 3], [297, 0xb0, 0]]),
      music: lane("music", 700, 1490, [[0, 0x40, 5], [1489, 0xb0, 0]]),
    },
  };
  const rendered = await renderYalispR0NormalizedAudio({
    sampleRate: profile.sampleRate,
    channels: profile.channels,
    bitsPerSample: profile.bitsPerSample,
    ticks: profile.ticks,
    routeExport,
    createOpl: oplFactory(),
  });
  assert.equal(rendered.ok, true);
  assert.equal(rendered.authoritative, false);
  assert.ok(rendered.acceptanceReasons.includes("injected-opl-dependency"));
  assert.equal(rendered.pcm.length, profile.samples);
  assert.equal(rendered.wav.length, 44 + profile.samples * 2);
  await assert.rejects(
    renderYalispR0NormalizedAudio({
      sampleRate: 44_100,
      channels: profile.channels,
      bitsPerSample: profile.bitsPerSample,
      ticks: profile.ticks,
      routeExport,
      createOpl: oplFactory(),
    }),
    /exact .* profile/,
  );
});

test("the promoted canonical host renders an explicit route-independent operation window", async () => {
  const window = { startTick: 0, endTick: 1, tickRate: 70, sampleCount: 710 };
  const program = {
    finalUnits: 100,
    operations: [
      [0, 0, 1, 2, -1, 0x20, 6, -1, -1, -1, -1, 0, -1],
      [10, 0, 1, 4, -1, 0x40, 7, -1, -1, -1, -1, 0, -1],
    ],
    payloadReferences: [],
    resolvedPayloads: [],
  };
  const rendered = await renderYalispCanonicalNormalizedAudio({
    window,
    program,
    createOpl: oplFactory(),
  });
  assert.equal(rendered.ok, true);
  assert.equal(rendered.authoritative, false);
  assert.deepEqual(rendered.acceptanceReasons, ["injected-opl-dependency"]);
  assert.deepEqual(
    [rendered.format, rendered.sampleRate, rendered.channels, rendered.bitsPerSample, rendered.samples],
    ["wolf3d-normalized-wav-v1", 49_716, 1, 16, 710],
  );
  assert.equal(rendered.wav.length, 44 + 710 * 2);
  assert.equal(YALISP_CANONICAL_NORMALIZED_PROFILE.timelineRate, 7_000);

  const missing = await renderYalispCanonicalNormalizedAudio({ window, program, createOpl: null });
  assert.deepEqual(
    [missing.ok, missing.status, missing.authoritative, missing.wav],
    [false, "opl-unavailable", false, null],
  );
});

test("the corrected canonical host clips and reports native tails at the explicit window", async () => {
  const pcmBytes = new Uint8Array(40);
  const rendered = await renderYalispCanonicalNormalizedAudio({
    window: { startTick: 0, endTick: 1, tickRate: 70, sampleCount: 710 },
    program: {
      finalUnits: 100,
      operations: [[99, 0, 2, 1, 7, -1, -1, 0, 1, 0, 0, 0, 5]],
      payloadReferences: [[7, 1, 5]],
      resolvedPayloads: [{ id: 7, source: 1, reference: 5, pcmBytes }],
    },
    createOpl: oplFactory(),
  });
  assert.equal(rendered.ok, true);
  assert.deepEqual(rendered.clippedNativeTails, [{
    id: 7,
    source: 1,
    unit: 99,
    startFrame: 703,
    naturalEndFrame: 723,
    clippedSamples: 13,
  }]);
  assert.equal(rendered.samples, 710);
});
