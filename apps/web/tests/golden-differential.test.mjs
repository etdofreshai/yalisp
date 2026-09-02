import assert from "node:assert/strict";
import { mkdtemp, readFile, rm, writeFile } from "node:fs/promises";
import { tmpdir } from "node:os";
import { join } from "node:path";
import test from "node:test";

import {
  defaultCorpusUrl,
  hashStateProbes,
  loadGoldenCorpus,
  runGoldenDifferential,
} from "../../../scripts/hardening/golden-observation-lib.mjs";

test("the reviewed corpus spans every M1 semantic category and keeps stable stage order", async () => {
  const { corpus, corpusSha256 } = await loadGoldenCorpus();
  assert.match(corpusSha256, /^[0-9a-f]{64}$/);
  assert.deepEqual(corpus.stageOrder, ["seed", "bootstrap", "compiler"]);
  const tags = new Set(corpus.cases.flatMap((candidate) => candidate.tags));
  for (const required of [
    "literal", "data", "scope", "mutation", "closure", "evaluation-order",
    "effects", "macro", "quasiquote", "tail-call", "error", "bytes", "resource-cap", "compiler",
  ]) assert.ok(tags.has(required), `missing M1 corpus tag ${required}`);
  assert.equal(new Set(corpus.cases.map((candidate) => candidate.id)).size, corpus.cases.length);
});

test("all applicable stages match reviewed values, output, effects, errors, probes, and state hashes", async () => {
  const before = await readFile(defaultCorpusUrl);
  const report = await runGoldenDifferential();
  const after = await readFile(defaultCorpusUrl);
  assert.deepEqual(after, before, "normal differential runs must never rewrite expected observations");
  assert.equal(report.status, "pass");
  assert.equal(report.counts.cases, 15);
  assert.equal(report.counts.events, 17);
  assert.equal(report.earliestDivergence, null);
  assert.equal(report.crossStageDivergence, null);
  assert.equal(report.compilerErrorIntersection.status, "pass");
  assert.equal(report.compilerErrorIntersection.observedJointErrorCases, 0);
  assert.equal(report.compilerErrorIntersection.earliestUnexpectedIntersection, null);

  const compiler = report.cases.find((candidate) => candidate.id === "compiler-square");
  assert.deepEqual(compiler.stages.map((stage) => stage.status), ["observed", "observed", "observed"]);
  assert.deepEqual(compiler.stages.map((stage) => stage.events[0].value), ["442", "442", "442"]);

  const macro = report.cases.find((candidate) => candidate.id === "bootstrap-macro");
  assert.deepEqual(macro.stages.map((stage) => stage.status), ["not-applicable", "observed", "not-applicable"]);

  const byteEffect = report.cases.find((candidate) => candidate.id === "byte-effect").stages[1].events[0];
  assert.deepEqual(byteEffect.effects, [{ channel: "bytes", value: "00017fff" }]);
  assert.deepEqual(byteEffect.probes, [{ name: "length", value: "4" }, { name: "last", value: "255" }]);
  assert.equal(byteEffect.stateHash, hashStateProbes(byteEffect.probes));

  const unbound = report.cases.find((candidate) => candidate.id === "unbound-error");
  assert.deepEqual(unbound.stages.slice(0, 2).map((stage) => stage.events[0].error.category), ["unbound-name", "unbound-name"]);
  for (const candidate of report.cases) {
    for (const stage of candidate.stages.filter((entry) => entry.status === "observed")) {
      assert.deepEqual(stage.capViolations, []);
      for (const event of stage.events) assert.match(event.stateHash, /^[0-9a-f]{64}$/);
    }
  }
});

test("a deliberately perturbed stage is localized to the earliest case, event, channel, and byte", async () => {
  const report = await runGoldenDifferential({
    perturbation: {
      stage: "bootstrap",
      caseId: "compiler-square",
      eventId: "evaluate",
      channel: "value",
      value: "443",
    },
  });
  assert.equal(report.status, "divergent");
  assert.deepEqual(report.earliestDivergence, {
    caseIndex: 12,
    caseId: "compiler-square",
    eventIndex: 0,
    eventId: "evaluate",
    channel: "value",
    byteOffset: 3,
    stage: "bootstrap",
    against: "expected",
  });
  assert.equal(report.crossStageDivergence.caseId, "compiler-square");
  assert.equal(report.crossStageDivergence.channel, "value");
});

test("resource caps fail as a named observation channel without changing a program result", async (t) => {
  const directory = await mkdtemp(join(tmpdir(), "yalisp-golden-cap-"));
  t.after(() => rm(directory, { recursive: true, force: true }));
  const { corpus } = await loadGoldenCorpus();
  const capped = structuredClone(corpus);
  capped.defaultCaps.maxOutputBytes = 0;
  const fixture = join(directory, "capped.json");
  await writeFile(fixture, `${JSON.stringify(capped, null, 2)}\n`);
  const report = await runGoldenDifferential({ corpusUrl: new URL(`file://${fixture}`) });
  assert.equal(report.status, "divergent");
  assert.deepEqual(report.earliestDivergence, {
    caseIndex: 0,
    caseId: "literal-data",
    eventIndex: 0,
    eventId: "evaluate",
    channel: "resourceCaps",
    byteOffset: 0,
    stage: "seed",
    against: "declared-caps",
  });
});
