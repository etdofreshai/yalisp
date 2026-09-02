#!/usr/bin/env node
import { mkdir, writeFile } from "node:fs/promises";
import { homedir } from "node:os";
import { join, resolve } from "node:path";

import { runGoldenDifferential } from "./golden-observation-lib.mjs";

const outputArgument = process.argv.find((argument) => argument.startsWith("--output="));
const report = await runGoldenDifferential();
const timestamp = new Date().toISOString().replaceAll(":", "-");
const directory = outputArgument
  ? resolve(outputArgument.slice("--output=".length))
  : join(homedir(), ".local", "state", "yalisp-hardening", "golden", `${timestamp}-${report.corpus.sha256.slice(0, 12)}`);
await mkdir(directory, { recursive: true });
const reportPath = join(directory, "report.json");
await writeFile(reportPath, `${JSON.stringify(report, null, 2)}\n`, { flag: "wx" });

console.log(JSON.stringify({
  status: report.status,
  corpusSha256: report.corpus.sha256,
  counts: report.counts,
  earliestDivergence: report.earliestDivergence,
  compilerErrorIntersection: {
    status: report.compilerErrorIntersection.status,
    expectedJointErrorCases: report.compilerErrorIntersection.expectedJointErrorCases,
    observedJointErrorCases: report.compilerErrorIntersection.observedJointErrorCases,
    earliestUnexpectedIntersection: report.compilerErrorIntersection.earliestUnexpectedIntersection,
  },
  reportPath,
}, null, 2));

if (report.status !== "pass") process.exitCode = 1;
