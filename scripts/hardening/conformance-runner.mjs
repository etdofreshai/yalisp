#!/usr/bin/env node

import { createHash } from "node:crypto";
import { spawn, spawnSync } from "node:child_process";
import {
  lstat,
  mkdir,
  readFile,
  readlink,
  readdir,
  rename,
  writeFile,
} from "node:fs/promises";
import os from "node:os";
import path from "node:path";
import process from "node:process";
import { fileURLToPath, pathToFileURL } from "node:url";

export const RUNNER_SCHEMA = "yalisp-conformance-shards-v2";
export const INHERITED_CASE_FLOOR = 358;

const scriptPath = fileURLToPath(import.meta.url);
const repoRoot = path.resolve(path.dirname(scriptPath), "../..");
const webRoot = path.join(repoRoot, "apps/web");
const testRoot = path.join(webRoot, "tests");
const defaultStateRoot = process.env.YALISP_HARDENING_STATE_DIR
  ?? path.join(os.homedir(), ".local/state/yalisp-hardening/conformance");

const artifactPaths = Object.freeze({
  wat: "apps/web/src/seed/bootstrap.wat",
  wasm: "apps/web/public/yalisp/seed.wasm",
  bootstrap: "apps/web/public/yalisp/boot.lisp",
  compiler: "apps/web/public/yalisp/compiler.lisp",
  aotExample: "apps/web/public/yalisp/aot-benchmark.wasm",
  coreIrExample: "apps/web/tests/fixtures/core-ir-v1-example.lisp",
  coreIrValidator: "scripts/hardening/core-ir-v1.mjs",
  coreIrLowerer: "scripts/hardening/core-ir-lowering.mjs",
});

const buildProtectedPaths = Object.freeze([
  "apps/web/src/seed/bootstrap.wat",
  "apps/web/public/yalisp/boot.lisp",
  "apps/web/public/yalisp/compiler.lisp",
  "apps/web/public/yalisp/aot-benchmark.wasm",
  "apps/web/tests/fixtures/core-ir-v1-example.lisp",
  "apps/web/scripts/build-seed.mjs",
  "apps/web/scripts/build-aot.mjs",
  "scripts/hardening/core-ir-v1.mjs",
  "scripts/hardening/core-ir-lowering.mjs",
  "apps/web/package.json",
  "package-lock.json",
]);

const sha256 = (value) => createHash("sha256").update(value).digest("hex");

function runGit(args, options = {}) {
  const result = spawnSync("git", args, {
    cwd: repoRoot,
    encoding: options.encoding ?? "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  if (result.status !== 0) {
    throw new Error(`git ${args.join(" ")} failed: ${String(result.stderr).trim()}`);
  }
  return result.stdout;
}

function runTool(command, args) {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  if (result.status !== 0) {
    throw new Error(`${command} ${args.join(" ")} failed: ${result.stderr.trim()}`);
  }
  return result.stdout.trim();
}

async function hashPath(relativePath) {
  const absolutePath = path.join(repoRoot, relativePath);
  const metadata = await lstat(absolutePath);
  if (metadata.isSymbolicLink()) {
    const target = await readlink(absolutePath);
    return { path: relativePath, kind: "symlink", bytes: Buffer.byteLength(target), sha256: sha256(target) };
  }
  if (!metadata.isFile()) throw new Error(`identity path is not a file: ${relativePath}`);
  const bytes = await readFile(absolutePath);
  return {
    path: relativePath,
    kind: "file",
    mode: metadata.mode & 0o111 ? "executable" : "regular",
    bytes: bytes.byteLength,
    sha256: sha256(bytes),
  };
}

async function hashOptionalPath(relativePath) {
  try {
    return await hashPath(relativePath);
  } catch (error) {
    if (error?.code === "ENOENT") return { path: relativePath, missing: true };
    throw error;
  }
}

async function hashPaths(relativePaths) {
  return Promise.all([...relativePaths].sort().map(hashPath));
}

async function discoverTests() {
  const names = (await readdir(testRoot))
    .filter((name) => name.endsWith(".test.mjs"))
    .sort((left, right) => left.localeCompare(right));
  if (names.length === 0) throw new Error("no apps/web test shards were discovered");
  return names.map((name) => `apps/web/tests/${name}`);
}

async function repositoryManifest() {
  const raw = runGit(["ls-files", "-co", "--exclude-standard", "-z"], { encoding: "buffer" });
  const relativePaths = raw.toString("utf8").split("\0").filter(Boolean).sort();
  const files = await hashPaths(relativePaths);
  const digest = createHash("sha256");
  for (const file of files) {
    const encoded = Buffer.from(JSON.stringify(file));
    const length = Buffer.allocUnsafe(8);
    length.writeBigUInt64BE(BigInt(encoded.byteLength));
    digest.update(length).update(encoded);
  }
  return { fileCount: files.length, sha256: digest.digest("hex") };
}

async function artifactManifest() {
  return Object.fromEntries(await Promise.all(Object.entries(artifactPaths).map(async ([name, relativePath]) => {
    const identity = await hashOptionalPath(relativePath);
    return [name, identity.missing ? identity : { bytes: identity.bytes, sha256: identity.sha256 }];
  })));
}

async function wolfInputManifest() {
  const declarationPath = path.join(webRoot, "src/examples/wolf3d/assets.manifest.json");
  const declaration = JSON.parse(await readFile(declarationPath, "utf8"));
  const declarationDirectory = path.dirname(declarationPath);
  const inputs = [];
  for (const file of declaration.files) {
    const candidates = [];
    for (const scope of [file, declaration]) {
      if (scope.sourceEnvironmentVariable && process.env[scope.sourceEnvironmentVariable]) {
        candidates.push({
          source: `environment:${scope.sourceEnvironmentVariable}`,
          path: path.resolve(process.env[scope.sourceEnvironmentVariable], file.source ?? file.name),
        });
      }
      for (const root of scope.sourceRoots ?? []) {
        candidates.push({
          source: "declared-source-root",
          path: path.resolve(declarationDirectory, root, file.source ?? file.name),
        });
      }
    }
    candidates.push({ source: "read-only-public-mount", path: path.join(webRoot, "public/assets/wolf3d", file.name) });
    let found = null;
    for (const candidate of candidates) {
      try {
        const bytes = await readFile(candidate.path);
        found = { name: file.name, source: candidate.source, bytes: bytes.byteLength, sha256: sha256(bytes) };
        break;
      } catch (error) {
        if (error?.code !== "ENOENT") throw error;
      }
    }
    inputs.push(found ?? { name: file.name, missing: true });
  }
  return inputs;
}

async function protectedBuildManifest() {
  return hashPaths(buildProtectedPaths);
}

function exactJson(value) {
  if (Array.isArray(value)) return `[${value.map(exactJson).join(",")}]`;
  if (value && typeof value === "object") {
    return `{${Object.keys(value).sort().map((key) => `${JSON.stringify(key)}:${exactJson(value[key])}`).join(",")}}`;
  }
  return JSON.stringify(value);
}

async function atomicJson(filePath, value) {
  const temporary = `${filePath}.tmp-${process.pid}`;
  await writeFile(temporary, `${JSON.stringify(value, null, 2)}\n`);
  await rename(temporary, filePath);
}

export function parseTap(tap, file = "unknown") {
  const summary = {};
  const roots = [];
  const declared = [];
  const stack = [];
  for (const line of tap.split(/\r?\n/)) {
    const count = line.match(/^# (tests|suites|pass|fail|cancelled|skipped|todo) (\d+)$/);
    if (count) summary[count[1]] = Number.parseInt(count[2], 10);
    const duration = line.match(/^# duration_ms ([0-9]+(?:\.[0-9]+)?)$/);
    if (duration) summary.durationMs = Number.parseFloat(duration[1]);

    const subtest = line.match(/^(\s*)# Subtest: (.+)$/);
    if (subtest) {
      const indent = subtest[1].length;
      while (stack.length && stack.at(-1).indent >= indent) stack.pop();
      const parent = stack.at(-1) ?? null;
      const node = { indent, name: subtest[2], parent, children: [], result: null };
      if (parent) parent.children.push(node);
      else roots.push(node);
      declared.push(node);
      stack.push(node);
      continue;
    }

    const result = line.match(/^(\s*)(ok|not ok) (\d+) - (.+?)(?: # (SKIP|TODO)(?: .*)?)?$/i);
    if (result) {
      const indent = result[1].length;
      const name = result[4];
      let node = declared.findLast((candidate) => (
        candidate.result === null && candidate.indent === indent && candidate.name === name
      ));
      if (!node) {
        while (stack.length && stack.at(-1).indent >= indent) stack.pop();
        const parent = stack.at(-1) ?? null;
        node = { indent, name, parent, children: [], result: null };
        if (parent) parent.children.push(node);
        else roots.push(node);
        declared.push(node);
      }
      node.result = {
        ordinal: Number.parseInt(result[3], 10),
        status: result[5]?.toLowerCase() ?? (result[2] === "ok" ? "pass" : "fail"),
      };
    }
  }
  for (const field of ["tests", "pass", "fail", "cancelled", "skipped", "todo", "durationMs"]) {
    if (summary[field] === undefined) throw new Error(`${file}: TAP footer is missing ${field}`);
  }

  const cases = [];
  const append = (node, parentOrdinalPath = [], parentNamePath = []) => {
    if (node.result === null) return;
    const ordinalPath = [...parentOrdinalPath, node.result.ordinal];
    const namePath = [...parentNamePath, node.name];
    cases.push({
      id: [file, ...ordinalPath.flatMap((ordinal, index) => [ordinal, namePath[index]])].join("::"),
      file,
      ordinal: node.result.ordinal,
      name: node.name,
      ordinalPath,
      namePath,
      status: node.result.status,
    });
    for (const child of node.children) append(child, ordinalPath, namePath);
  };
  for (const root of roots) append(root);
  if (cases.length !== summary.tests) {
    throw new Error(`${file}: TAP declared ${summary.tests} tests but exposed ${cases.length} hierarchical results`);
  }
  return { ...summary, cases };
}

export function assertResumeIdentity(expectedHash, savedManifest) {
  if (savedManifest.schema !== RUNNER_SCHEMA) {
    throw new Error(`resume schema mismatch: expected ${RUNNER_SCHEMA}, found ${savedManifest.schema}`);
  }
  if (savedManifest.identityHash !== expectedHash) {
    throw new Error(`resume identity mismatch: expected ${expectedHash}, found ${savedManifest.identityHash}`);
  }
  return true;
}

export function coverageDelta(cases, baseline = { total: INHERITED_CASE_FLOOR }) {
  const skippedCount = cases.filter((item) => item.status === "skip").length;
  const cancelledCount = cases.filter((item) => item.status === "cancelled").length;
  if (!Array.isArray(baseline.cases)) {
    return {
      baselineTotal: baseline.total,
      currentTotal: cases.length,
      addedCount: Math.max(0, cases.length - baseline.total),
      removedCount: Math.max(0, baseline.total - cases.length),
      renamedCount: null,
      renamedReason: "the inherited complete baseline retained a count but no stable case IDs",
      skippedCount,
      cancelledCount,
    };
  }

  const previousById = new Map(baseline.cases.map((item) => [item.id, item]));
  const currentById = new Map(cases.map((item) => [item.id, item]));
  let removed = baseline.cases.filter((item) => !currentById.has(item.id));
  let added = cases.filter((item) => !previousById.has(item.id));
  const renamed = [];
  for (const oldCase of [...removed]) {
    const oldOrdinalPath = oldCase.ordinalPath ?? [oldCase.ordinal];
    const replacement = added.find((item) => (
      item.file === oldCase.file
      && exactJson(item.ordinalPath ?? [item.ordinal]) === exactJson(oldOrdinalPath)
    ));
    if (!replacement) continue;
    renamed.push({ from: oldCase.id, to: replacement.id });
    removed = removed.filter((item) => item !== oldCase);
    added = added.filter((item) => item !== replacement);
  }
  return {
    baselineTotal: baseline.cases.length,
    currentTotal: cases.length,
    addedCount: added.length,
    removedCount: removed.length,
    renamedCount: renamed.length,
    added: added.map((item) => item.id).sort(),
    removed: removed.map((item) => item.id).sort(),
    renamed,
    skippedCount,
    cancelledCount,
  };
}

export function aggregateShards(shards, mode, baseline) {
  if (!new Set(["fail-fast", "promotion"]).has(mode)) throw new Error(`unknown mode: ${mode}`);
  const complete = shards.filter((shard) => shard.status === "completed");
  const counts = Object.fromEntries(
    ["tests", "pass", "fail", "cancelled", "skipped", "todo"].map((field) => [
      field,
      complete.reduce((total, shard) => total + shard.tap[field], 0),
    ]),
  );
  const cases = complete.flatMap((shard) => shard.tap.cases);
  const coverage = coverageDelta(cases, baseline);
  coverage.skippedCount = counts.skipped;
  coverage.cancelledCount = counts.cancelled;
  const incompleteShards = shards.filter((shard) => shard.status !== "completed").map((shard) => shard.file);
  const abnormalProcesses = complete
    .filter((shard) => shard.exitCode !== undefined && (shard.exitCode !== 0 || shard.signal !== null))
    .map((shard) => ({ file: shard.file, exitCode: shard.exitCode, signal: shard.signal }));
  const violations = [];
  if (incompleteShards.length) violations.push(`${incompleteShards.length} shard(s) incomplete`);
  if (abnormalProcesses.length) violations.push(`${abnormalProcesses.length} shard process(es) exited abnormally`);
  if (counts.fail) violations.push(`${counts.fail} failed test(s)`);
  if (counts.cancelled) violations.push(`${counts.cancelled} cancelled test(s)`);
  if (counts.tests < INHERITED_CASE_FLOOR) violations.push(`${counts.tests} tests is below the ${INHERITED_CASE_FLOOR}-case floor`);
  if (mode === "promotion" && counts.skipped) violations.push(`${counts.skipped} skipped test(s) are forbidden in promotion mode`);
  return {
    mode,
    status: violations.length === 0 ? "pass" : "fail",
    counts,
    shardCount: shards.length,
    completedShardCount: complete.length,
    durationMs: complete.reduce((total, shard) => total + shard.tap.durationMs, 0),
    coverage,
    incompleteShards,
    abnormalProcesses,
    violations,
    cases,
  };
}

export function shouldStopAfterShard(shard, mode) {
  if (mode === "promotion") return false;
  if (mode !== "fail-fast") throw new Error(`unknown mode: ${mode}`);
  return shard.status !== "completed"
    || (shard.exitCode !== undefined && (shard.exitCode !== 0 || shard.signal !== null))
    || shard.tap.fail !== 0
    || shard.tap.cancelled !== 0;
}

function parseArguments(argv) {
  const options = { mode: "fail-fast", stateRoot: defaultStateRoot, resume: null, baseline: null };
  for (const argument of argv) {
    if (argument === "--help") options.help = true;
    else if (argument.startsWith("--mode=")) options.mode = argument.slice("--mode=".length);
    else if (argument.startsWith("--state-dir=")) options.stateRoot = path.resolve(argument.slice("--state-dir=".length));
    else if (argument.startsWith("--resume=")) options.resume = path.resolve(argument.slice("--resume=".length));
    else if (argument.startsWith("--baseline=")) options.baseline = path.resolve(argument.slice("--baseline=".length));
    else throw new Error(`unknown argument: ${argument}`);
  }
  if (!new Set(["fail-fast", "promotion"]).has(options.mode)) throw new Error(`invalid --mode: ${options.mode}`);
  return options;
}

async function loadBaseline(filePath) {
  if (!filePath) return { total: INHERITED_CASE_FLOOR };
  const parsed = JSON.parse(await readFile(filePath, "utf8"));
  if (!Array.isArray(parsed.cases)) throw new Error(`baseline has no cases array: ${filePath}`);
  return parsed;
}

async function buildIdentity(mode, tests, build, baseline) {
  const testFiles = await hashPaths(tests);
  const status = runGit(["status", "--porcelain=v1", "-z", "--untracked-files=all"], { encoding: "buffer" });
  const identity = {
    schema: RUNNER_SCHEMA,
    mode,
    git: {
      head: runGit(["rev-parse", "HEAD"]).trim(),
      originMain: runGit(["rev-parse", "origin/main"]).trim(),
      ahead: Number.parseInt(runGit(["rev-list", "--count", "origin/main..HEAD"]).trim(), 10),
      porcelainSha256: sha256(status),
      workingTree: await repositoryManifest(),
    },
    machine: {
      hostname: os.hostname(),
      platform: process.platform,
      architecture: process.arch,
      kernel: os.release(),
      cpuModel: os.cpus()[0]?.model ?? "unknown",
      logicalCpuCount: os.cpus().length,
      totalMemoryBytes: os.totalmem(),
      node: process.version,
      npm: runTool("npm", ["--version"]),
    },
    command: {
      executable: process.execPath,
      shardArguments: ["--test", "--test-concurrency=1", "--test-reporter=tap", "--test-reporter-destination=<external-tap>", "<test-file>"],
      cwd: "apps/web",
      ordering: "lexicographic file path, one fresh process at a time",
      mode,
    },
    relevantEnvironment: Object.fromEntries([
      "NODE_OPTIONS",
      "TZ",
      "UV_THREADPOOL_SIZE",
      "YALISP_WOLF3D_ASSET_SOURCE",
      "YALISP_WOLF3D_PALETTE_SOURCE",
    ]
      .filter((name) => process.env[name] !== undefined)
      .map((name) => [name, process.env[name]])),
    resourcePolicy: {
      inheritedCaseFloor: INHERITED_CASE_FLOOR,
      wolfReplayLinearMemory: "exact 240 MiB cap asserted by test source",
      rawTapLocation: "external state directory",
    },
    tests: testFiles,
    artifacts: await artifactManifest(),
    wolfInputs: await wolfInputManifest(),
    coverageBaseline: {
      total: Array.isArray(baseline.cases) ? baseline.cases.length : baseline.total,
      sha256: sha256(exactJson(baseline)),
    },
    build,
  };
  return { identity, identityHash: sha256(exactJson(identity)) };
}

async function runBuild() {
  const beforeProtected = await protectedBuildManifest();
  const beforeArtifacts = await artifactManifest();
  const result = spawnSync("npm", ["run", "build-seed", "--workspace", "@yalisp/web"], {
    cwd: repoRoot,
    encoding: "utf8",
    maxBuffer: 64 * 1024 * 1024,
  });
  if (result.status !== 0) {
    throw new Error(`seed build failed:\n${result.stdout}\n${result.stderr}`);
  }
  const afterProtected = await protectedBuildManifest();
  const afterArtifacts = await artifactManifest();
  const changedProtected = afterProtected.filter((item, index) => item.sha256 !== beforeProtected[index].sha256);
  if (changedProtected.length) {
    throw new Error(`seed build altered protected tracked content: ${changedProtected.map((item) => item.path).join(", ")}`);
  }
  if (!beforeArtifacts.wasm.missing && beforeArtifacts.wasm.sha256 !== afterArtifacts.wasm.sha256) {
    throw new Error("seed build was not byte-identical to the existing seed.wasm");
  }
  return {
    command: "npm run build-seed --workspace @yalisp/web",
    stdout: result.stdout.trim().split(/\r?\n/),
    protectedTrackedContentUnchanged: true,
    beforeArtifacts,
    afterArtifacts,
  };
}

function runShard(testFile, tapPath, stderrPath, onChild) {
  return new Promise((resolve, reject) => {
    const child = spawn(process.execPath, [
      "--test",
      "--test-concurrency=1",
      "--test-reporter=tap",
      `--test-reporter-destination=${tapPath}`,
      path.join(repoRoot, testFile),
    ], { cwd: webRoot, stdio: ["ignore", "ignore", "pipe"] });
    onChild(child);
    const stderr = [];
    child.stderr.on("data", (chunk) => stderr.push(chunk));
    child.once("error", reject);
    child.once("close", async (code, signal) => {
      try {
        const stderrBytes = Buffer.concat(stderr);
        await writeFile(stderrPath, stderrBytes);
        resolve({ code, signal, stderrSha256: sha256(stderrBytes), stderrBytes: stderrBytes.byteLength });
      } catch (error) {
        reject(error);
      }
    });
  });
}

function usage() {
  return `Usage: node scripts/hardening/conformance-runner.mjs [options]\n\n`
    + `  --mode=fail-fast|promotion  stop at first failing shard or complete every shard\n`
    + `  --state-dir=PATH            external parent directory for a new run\n`
    + `  --resume=RUN_DIRECTORY      resume only when the complete identity matches\n`
    + `  --baseline=JSON             compare stable case IDs with an earlier result\n`;
}

async function main() {
  const options = parseArguments(process.argv.slice(2));
  if (options.help) {
    process.stdout.write(usage());
    return;
  }

  const tests = await discoverTests();
  const build = await runBuild();
  const baseline = await loadBaseline(options.baseline);
  const { identity, identityHash } = await buildIdentity(options.mode, tests, build, baseline);
  const runDirectory = options.resume
    ?? path.join(options.stateRoot, `${new Date().toISOString().replaceAll(":", "-")}-${identityHash.slice(0, 12)}`);
  if (options.resume) {
    await lstat(runDirectory);
  } else {
    await mkdir(options.stateRoot, { recursive: true });
    await mkdir(runDirectory);
  }
  const manifestPath = path.join(runDirectory, "manifest.json");
  let manifest;
  if (options.resume) {
    manifest = JSON.parse(await readFile(manifestPath, "utf8"));
    assertResumeIdentity(identityHash, manifest);
  } else {
    manifest = {
      schema: RUNNER_SCHEMA,
      identityHash,
      identity,
      runDirectory,
      startedAt: new Date().toISOString(),
      status: "running",
      shards: tests.map((file, index) => ({ index, file, status: "pending" })),
    };
    await atomicJson(manifestPath, manifest);
  }

  let activeChild = null;
  let interruptedSignal = null;
  const interrupt = (signal) => {
    interruptedSignal = signal;
    if (activeChild && activeChild.exitCode === null) activeChild.kill(signal);
  };
  process.once("SIGINT", () => interrupt("SIGINT"));
  process.once("SIGTERM", () => interrupt("SIGTERM"));

  process.stdout.write(`YaLisp ${options.mode} conformance run ${identityHash}\n${runDirectory}\n`);
  for (const shard of manifest.shards) {
    if (shard.status === "completed") continue;
    if (interruptedSignal) break;
    const safeName = `${String(shard.index + 1).padStart(3, "0")}-${path.basename(shard.file, ".test.mjs")}`;
    const attemptNumber = (shard.attempts?.length ?? 0) + 1;
    const tapPath = path.join(runDirectory, `${safeName}.attempt-${attemptNumber}.tap`);
    const stderrPath = path.join(runDirectory, `${safeName}.attempt-${attemptNumber}.stderr.txt`);
    const attempt = { number: attemptNumber, status: "running", startedAt: new Date().toISOString() };
    (shard.attempts ??= []).push(attempt);
    shard.status = "running";
    shard.startedAt = attempt.startedAt;
    delete shard.finishedAt;
    delete shard.exitCode;
    delete shard.signal;
    delete shard.stderr;
    delete shard.tapArtifact;
    delete shard.tap;
    delete shard.parseError;
    await atomicJson(manifestPath, manifest);
    process.stdout.write(`[${shard.index + 1}/${manifest.shards.length}] ${shard.file} (attempt ${attemptNumber})\n`);
    const childResult = await runShard(shard.file, tapPath, stderrPath, (child) => { activeChild = child; });
    activeChild = null;
    shard.finishedAt = new Date().toISOString();
    shard.exitCode = childResult.code;
    shard.signal = childResult.signal;
    shard.stderr = { path: path.basename(stderrPath), bytes: childResult.stderrBytes, sha256: childResult.stderrSha256 };
    Object.assign(attempt, {
      finishedAt: shard.finishedAt,
      exitCode: childResult.code,
      signal: childResult.signal,
      stderr: shard.stderr,
    });
    try {
      const tapBytes = await readFile(tapPath);
      shard.tapArtifact = { path: path.basename(tapPath), bytes: tapBytes.byteLength, sha256: sha256(tapBytes) };
      shard.tap = parseTap(tapBytes.toString("utf8"), shard.file);
      shard.status = "completed";
      Object.assign(attempt, { status: "completed", tapArtifact: shard.tapArtifact, tap: shard.tap });
    } catch (error) {
      shard.status = interruptedSignal ? "interrupted" : "failed";
      shard.parseError = error.message;
      Object.assign(attempt, {
        status: shard.status,
        tapArtifact: shard.tapArtifact,
        parseError: shard.parseError,
      });
    }
    await atomicJson(manifestPath, manifest);
    const green = shard.status === "completed"
      && shard.exitCode === 0
      && shard.signal === null
      && shard.tap.fail === 0
      && shard.tap.cancelled === 0;
    process.stdout.write(`  ${green ? "pass" : "fail"}: ${shard.tap?.tests ?? 0} tests, ${shard.tap?.durationMs ?? 0} ms\n`);
    if (shouldStopAfterShard(shard, options.mode)) break;
  }

  const aggregate = aggregateShards(manifest.shards, options.mode, baseline);
  manifest.finishedAt = new Date().toISOString();
  manifest.status = interruptedSignal ? "interrupted" : aggregate.status;
  manifest.interruptedSignal = interruptedSignal;
  manifest.aggregate = aggregate;
  await atomicJson(manifestPath, manifest);
  process.stdout.write(`${JSON.stringify({ runDirectory, identityHash, status: manifest.status, aggregate }, null, 2)}\n`);
  if (manifest.status !== "pass") process.exitCode = interruptedSignal ? 130 : 1;
}

if (process.argv[1] && pathToFileURL(path.resolve(process.argv[1])).href === import.meta.url) {
  main().catch((error) => {
    process.stderr.write(`${error.stack ?? error}\n`);
    process.exitCode = 1;
  });
}
