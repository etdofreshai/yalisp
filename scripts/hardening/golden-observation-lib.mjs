import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import { arch, cpus, hostname, platform, release, totalmem } from "node:os";
import wabtInit from "wabt";

import {
  SEED_ARTIFACT_PINS,
  SeedLanguageError,
  createSeedSession,
} from "../../apps/web/tests/seed-session.mjs";

export const GOLDEN_SCHEMA = "yalisp-golden-differential-v1";
export const defaultCorpusUrl = new URL(
  "../../apps/web/tests/fixtures/golden-observations-v1.json",
  import.meta.url,
);

const compilerUrl = new URL("../../apps/web/public/yalisp/compiler.lisp", import.meta.url);
const encoder = new TextEncoder();
const observationChannels = Object.freeze([
  "value",
  "printedOutput",
  "effects",
  "error",
  "probes",
  "stateHash",
]);

const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");

function lengthDelimited(hash, value) {
  const bytes = encoder.encode(value);
  const length = Buffer.allocUnsafe(4);
  length.writeUInt32BE(bytes.byteLength);
  hash.update(length);
  hash.update(bytes);
}

export function hashStateProbes(probes) {
  const hash = createHash("sha256");
  for (const probe of probes) {
    lengthDelimited(hash, probe.name);
    lengthDelimited(hash, probe.value);
  }
  return hash.digest("hex");
}

function assertCorpus(corpus) {
  if (corpus?.schema !== "yalisp-golden-observations-v1") {
    throw new Error(`unsupported golden corpus schema: ${corpus?.schema ?? "missing"}`);
  }
  if (!Array.isArray(corpus.stageOrder) || corpus.stageOrder.join(",") !== "seed,bootstrap,compiler") {
    throw new Error("golden stage order must be seed, bootstrap, compiler");
  }
  const caseIds = new Set();
  for (const candidate of corpus.cases ?? []) {
    if (!candidate.id || caseIds.has(candidate.id)) throw new Error(`duplicate or missing case id: ${candidate.id}`);
    caseIds.add(candidate.id);
    if (!Array.isArray(candidate.events) || candidate.events.length === 0) {
      throw new Error(`${candidate.id}: at least one event is required`);
    }
    const eventIds = new Set();
    for (const event of candidate.events) {
      if (!event.id || eventIds.has(event.id)) throw new Error(`${candidate.id}: duplicate or missing event id ${event.id}`);
      eventIds.add(event.id);
      if (!event.expected || !Array.isArray(event.expected.effects) || !Array.isArray(event.expected.probes)) {
        throw new Error(`${candidate.id}/${event.id}: reviewed expected observation is incomplete`);
      }
    }
  }
}

export async function loadGoldenCorpus(url = defaultCorpusUrl) {
  const bytes = await readFile(url);
  const corpus = JSON.parse(bytes);
  assertCorpus(corpus);
  return Object.freeze({ corpus, corpusSha256: sha256(bytes), corpusBytes: bytes.byteLength });
}

function normalizeError(error) {
  if (error instanceof SeedLanguageError) {
    return {
      category: error.category,
      diagnostic: error.diagnostic,
      data: error.data,
      recoverable: error.recoverable,
    };
  }
  const diagnostic = typeof error?.diagnostic === "string" ? error.diagnostic : String(error?.message ?? error);
  return { category: "runtime-trap", diagnostic, data: null, recoverable: false };
}

async function observeProbes(session, declarations) {
  const probes = [];
  for (const declaration of declarations ?? []) {
    probes.push({ name: declaration.name, value: session.evaluateCanonical(declaration.source) });
  }
  return probes;
}

async function observeInterpreterCase(candidate, stage) {
  const session = await createSeedSession({ boot: stage === "bootstrap" });
  for (const source of candidate.setup ?? []) session.evaluateQuietly(source);
  const events = [];
  let outputBytes = 0;
  for (const event of candidate.events) {
    let value = null;
    let printedOutput = "";
    let effects = [];
    let error = null;
    let probes = [];
    try {
      if (event.kind === "bytes") {
        const bytes = session.evaluateBytes(event.source);
        const hex = Buffer.from(bytes).toString("hex");
        value = `#bytes:${hex}`;
        effects.push({ channel: "bytes", value: hex });
        outputBytes += bytes.byteLength;
      } else {
        value = session.evaluateCanonical(event.source);
        printedOutput = value;
        outputBytes += encoder.encode(printedOutput).byteLength;
      }
      for (const declaration of event.effectProbes ?? []) {
        effects.push({
          channel: declaration.channel,
          name: declaration.name,
          value: session.evaluateCanonical(declaration.source),
        });
      }
      probes = await observeProbes(session, event.probes);
    } catch (caught) {
      error = normalizeError(caught);
      printedOutput = error.diagnostic;
      effects = [{ channel: "diagnostic", value: error.diagnostic }];
      outputBytes += encoder.encode(printedOutput).byteLength;
    }
    events.push({
      id: event.id,
      value,
      printedOutput,
      effects,
      error,
      probes,
      stateHash: hashStateProbes(probes),
    });
    if (error) break;
  }
  return {
    stage,
    status: "observed",
    events,
    resource: {
      sourceBytes: sourceBytes(candidate),
      outputBytes,
      memoryBytes: session.memoryBytes,
    },
  };
}

function assemble(wabt, payload) {
  const parsed = wabt.parseWat("yalisp-golden-compiled.wat", `(module (func (export "run") ${payload}))`, {});
  try {
    parsed.validate();
    return Buffer.from(parsed.toBinary({ write_debug_names: false }).buffer);
  } finally {
    parsed.destroy();
  }
}

async function observeCompilerCase(candidate, compilerSource, wabt) {
  if (!candidate.compiler || candidate.events.length !== 1) {
    throw new Error(`${candidate.id}: compiler-applicable cases require one compiler event`);
  }
  const session = await createSeedSession({ boot: true });
  session.evaluateQuietly(compilerSource);
  const { parameter, body, argument } = candidate.compiler;
  const payload = session.evaluate(`(cc.compile '(${parameter}) '(${body}))`);
  if (payload === "nil") throw new Error(`${candidate.id}: compiler rejected its declared supported form`);
  const bytes = assemble(wabt, payload);
  const { instance } = await WebAssembly.instantiate(bytes);
  const value = String(instance.exports.run(argument));
  const probes = [];
  return {
    stage: "compiler",
    status: "observed",
    events: [{
      id: candidate.events[0].id,
      value,
      printedOutput: value,
      effects: [],
      error: null,
      probes,
      stateHash: hashStateProbes(probes),
    }],
    resource: {
      sourceBytes: sourceBytes(candidate),
      outputBytes: encoder.encode(value).byteLength,
      memoryBytes: 0,
      generatedCodeBytes: bytes.byteLength,
    },
  };
}

function sourceBytes(candidate) {
  return [...(candidate.setup ?? []), ...candidate.events.map((event) => event.source)]
    .reduce((total, source) => total + encoder.encode(source).byteLength, 0);
}

function expectedEvents(candidate) {
  return candidate.events.map((event) => ({
    id: event.id,
    ...event.expected,
    stateHash: hashStateProbes(event.expected.probes),
  }));
}

function capsFor(corpus, candidate) {
  return { ...corpus.defaultCaps, ...(candidate.caps ?? {}) };
}

function capViolations(resource, caps) {
  const violations = [];
  for (const [metric, capName] of [
    ["sourceBytes", "maxSourceBytes"],
    ["outputBytes", "maxOutputBytes"],
    ["memoryBytes", "maxMemoryBytes"],
    ["generatedCodeBytes", "maxGeneratedCodeBytes"],
  ]) {
    if (typeof resource[metric] === "number" && resource[metric] > caps[capName]) {
      violations.push({ metric, actual: resource[metric], cap: caps[capName] });
    }
  }
  return violations;
}

function serialized(value) {
  return JSON.stringify(value);
}

function firstByteDifference(left, right) {
  const a = Buffer.from(serialized(left));
  const b = Buffer.from(serialized(right));
  const length = Math.min(a.length, b.length);
  for (let index = 0; index < length; index += 1) if (a[index] !== b[index]) return index;
  return a.length === b.length ? null : length;
}

function eventDifference(candidate, caseIndex, stage, actual, expected, against = "expected") {
  const count = Math.max(actual.length, expected.length);
  for (let eventIndex = 0; eventIndex < count; eventIndex += 1) {
    const observed = actual[eventIndex];
    const reference = expected[eventIndex];
    if (!observed || !reference) {
      return {
        caseIndex, caseId: candidate.id, eventIndex,
        eventId: observed?.id ?? reference?.id ?? null,
        channel: "event-count", byteOffset: 0, stage, against,
      };
    }
    for (const channel of observationChannels) {
      const byteOffset = firstByteDifference(observed[channel], reference[channel]);
      if (byteOffset !== null) {
        return { caseIndex, caseId: candidate.id, eventIndex, eventId: observed.id, channel, byteOffset, stage, against };
      }
    }
  }
  return null;
}

function applyPerturbation(result, perturbation) {
  if (!perturbation || result.stage !== perturbation.stage) return;
  const event = result.events.find((candidate) => candidate.id === perturbation.eventId);
  if (!event) throw new Error(`perturbation event not found: ${perturbation.eventId}`);
  if (!observationChannels.includes(perturbation.channel)) throw new Error(`unsupported perturbation channel: ${perturbation.channel}`);
  event[perturbation.channel] = perturbation.value;
}

export async function runGoldenDifferential({ corpusUrl = defaultCorpusUrl, perturbation } = {}) {
  const loaded = await loadGoldenCorpus(corpusUrl);
  const { corpus } = loaded;
  const compilerSource = await readFile(compilerUrl, "utf8");
  const wabt = await wabtInit();
  const cases = [];
  let earliestDivergence = null;
  let crossStageDivergence = null;
  let observedStageCount = 0;
  let notApplicableStageCount = 0;

  for (const [caseIndex, candidate] of corpus.cases.entries()) {
    const expected = expectedEvents(candidate);
    const stages = [];
    for (const stage of corpus.stageOrder) {
      if (!candidate.stages.includes(stage)) {
        stages.push({ stage, status: "not-applicable", reason: "outside declared stage profile" });
        notApplicableStageCount += 1;
        continue;
      }
      const result = stage === "compiler"
        ? await observeCompilerCase(candidate, compilerSource, wabt)
        : await observeInterpreterCase(candidate, stage);
      applyPerturbation(result, perturbation?.caseId === candidate.id ? perturbation : null);
      result.caps = capsFor(corpus, candidate);
      result.capViolations = capViolations(result.resource, result.caps);
      result.status = result.capViolations.length === 0 ? "observed" : "resource-cap-failed";
      stages.push(result);
      observedStageCount += 1;
      if (!earliestDivergence) {
        earliestDivergence = eventDifference(candidate, caseIndex, stage, result.events, expected);
        if (!earliestDivergence && result.capViolations.length > 0) {
          earliestDivergence = {
            caseIndex, caseId: candidate.id, eventIndex: 0, eventId: candidate.events[0].id,
            channel: "resourceCaps", byteOffset: 0, stage, against: "declared-caps",
          };
        }
      }
    }
    const applicable = stages.filter((stage) => stage.status !== "not-applicable");
    if (!crossStageDivergence && applicable.length > 1) {
      const reference = applicable[0];
      for (const stage of applicable.slice(1)) {
        crossStageDivergence = eventDifference(
          candidate,
          caseIndex,
          stage.stage,
          stage.events,
          reference.events,
          reference.stage,
        );
        if (crossStageDivergence) break;
      }
    }
    cases.push({ id: candidate.id, tags: candidate.tags, expected, stages });
  }

  return {
    schema: GOLDEN_SCHEMA,
    corpus: {
      schema: corpus.schema,
      version: corpus.corpusVersion,
      bytes: loaded.corpusBytes,
      sha256: loaded.corpusSha256,
    },
    inputs: {
      seedArtifacts: SEED_ARTIFACT_PINS,
      compiler: { bytes: encoder.encode(compilerSource).byteLength, sha256: sha256(encoder.encode(compilerSource)) },
    },
    machine: {
      hostname: hostname(),
      platform: platform(),
      architecture: arch(),
      kernel: release(),
      cpuModel: cpus()[0]?.model ?? "unknown",
      logicalCpuCount: cpus().length,
      totalMemoryBytes: totalmem(),
      node: process.version,
    },
    stageOrder: corpus.stageOrder,
    status: earliestDivergence || crossStageDivergence ? "divergent" : "pass",
    counts: {
      cases: corpus.cases.length,
      events: corpus.cases.reduce((total, candidate) => total + candidate.events.length, 0),
      observedStages: observedStageCount,
      notApplicableStages: notApplicableStageCount,
    },
    earliestDivergence: earliestDivergence ?? crossStageDivergence,
    expectedDivergence: earliestDivergence,
    crossStageDivergence,
    cases,
  };
}
