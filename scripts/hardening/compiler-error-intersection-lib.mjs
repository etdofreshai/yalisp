import { createHash } from "node:crypto";
import { readFile } from "node:fs/promises";
import wabtInit from "wabt";

import {
  SEED_ERROR_CATEGORIES,
  SeedLanguageError,
  classifySeedTrap,
  createSeedSession,
} from "../../apps/web/tests/seed-session.mjs";

export const defaultCompilerErrorProfileUrl = new URL(
  "../../apps/web/tests/fixtures/compiler-error-intersection-v1.json",
  import.meta.url,
);

const compilerUrl = new URL("../../apps/web/public/yalisp/compiler.lisp", import.meta.url);
const seedUrl = new URL("../../apps/web/public/yalisp/seed.wasm", import.meta.url);
const decoder = new TextDecoder();
const sha256 = (bytes) => createHash("sha256").update(bytes).digest("hex");

function assemble(wabt, payload) {
  const parsed = wabt.parseWat(
    "yalisp-compiler-error-intersection.wat",
    `(module (func (export "run") ${payload}))`,
    {},
  );
  try {
    parsed.validate();
    return Buffer.from(parsed.toBinary({ write_debug_names: false }).buffer);
  } finally {
    parsed.destroy();
  }
}

function normalizeLanguageError(error) {
  if (!(error instanceof SeedLanguageError)) {
    return {
      categoryCode: 0,
      category: "runtime-trap",
      diagnostic: String(error?.message ?? error),
      data: null,
    };
  }
  return {
    categoryCode: error.categoryCode,
    category: error.category,
    diagnostic: error.diagnostic,
    data: error.data,
  };
}

async function observeSourceError(candidate) {
  const session = await createSeedSession({ boot: false });
  for (const source of candidate.setup ?? []) session.evaluateQuietly(source);
  if (candidate.ingestHex) session.ingestBytes(Buffer.from(candidate.ingestHex, "hex"));
  try {
    if (candidate.boundary === "precompile-reader") session.read(candidate.interpreterSource);
    else session.evaluate(candidate.interpreterSource);
    return null;
  } catch (error) {
    return normalizeLanguageError(error);
  }
}

async function observeHostContractError(seedBytes) {
  let memory;
  const output = [];
  const { instance } = await WebAssembly.instantiate(seedBytes, {
    host: {
      write(pointer, length) {
        output.push(new Uint8Array(memory.buffer, pointer, length).slice());
      },
      bytes_write() {},
    },
  });
  memory = instance.exports.memory;
  instance.exports.init();
  try {
    instance.exports.asset_commit();
    return null;
  } catch (error) {
    const diagnostic = decoder.decode(Buffer.concat(output.map((bytes) => Buffer.from(bytes)))).trimEnd();
    const pointer = instance.exports.error_data_pointer();
    const length = instance.exports.error_data_length();
    const data = decoder.decode(new Uint8Array(memory.buffer, pointer, length));
    return normalizeLanguageError(classifySeedTrap(error, instance.exports.error_kind(), diagnostic, data));
  }
}

function firstMismatch(candidate, actual) {
  const expected = {
    categoryCode: candidate.categoryCode,
    category: candidate.category,
    ...candidate.expectedError,
  };
  return JSON.stringify(actual) === JSON.stringify(expected) ? null : { expected, actual };
}

function divergence(candidate, channel, detail) {
  return {
    caseId: candidate.id,
    eventId: "compiler-error-intersection",
    channel,
    stage: "compiler",
    against: "declared-profile",
    detail,
  };
}

export async function runCompilerErrorIntersection({ profileUrl = defaultCompilerErrorProfileUrl } = {}) {
  const [profileBytes, compilerSource, seedBytes] = await Promise.all([
    readFile(profileUrl),
    readFile(compilerUrl, "utf8"),
    readFile(seedUrl),
  ]);
  const fixture = JSON.parse(profileBytes);
  if (fixture.schema !== "yalisp-compiler-error-intersection-v1") {
    throw new Error(`unsupported compiler error profile: ${fixture.schema ?? "missing"}`);
  }
  if (!Array.isArray(fixture.cases) || fixture.cases.length === 0) {
    throw new Error("compiler error profile requires reviewed cases");
  }

  const coveredCategoryCodes = [...new Set(fixture.cases
    .map((candidate) => candidate.categoryCode)
    .filter(Number.isInteger))]
    .sort((left, right) => left - right);
  const declaredCategoryCodes = Object.keys(SEED_ERROR_CATEGORIES).map(Number).sort((left, right) => left - right);
  if (JSON.stringify(coveredCategoryCodes) !== JSON.stringify(declaredCategoryCodes)) {
    throw new Error(`compiler error profile category coverage is incomplete: ${coveredCategoryCodes.join(",")}`);
  }

  const compileSession = await createSeedSession({ boot: true });
  compileSession.evaluateQuietly(compilerSource);
  const wabt = await wabtInit();
  const cases = [];
  let earliestUnexpectedIntersection = null;
  let observedJointErrorCases = 0;
  let compilerRejections = 0;
  let precompileBoundaries = 0;
  let numericDomainExclusions = 0;

  for (const candidate of fixture.cases) {
    const interpreterValue = null;
    const interpreterError = candidate.boundary === "precompile-host"
      ? await observeHostContractError(seedBytes)
      : await observeSourceError(candidate);
    const mismatch = candidate.expectedError ? firstMismatch(candidate, interpreterError) : null;
    if (!earliestUnexpectedIntersection && mismatch) {
      earliestUnexpectedIntersection = divergence(candidate, "interpreter-error", mismatch);
    }

    let compilerDisposition;
    let compiledValue = null;
    if (candidate.boundary === "compiler-rejection") {
      const payload = compileSession.evaluate(`(cc.compile '(x) '(${candidate.body}))`);
      compilerDisposition = payload === "nil" ? "rejected-before-codegen" : "unexpectedly-compiled";
      if (payload === "nil") compilerRejections += 1;
      else {
        observedJointErrorCases += 1;
        if (!earliestUnexpectedIntersection) {
          earliestUnexpectedIntersection = divergence(candidate, "compiler-disposition", { expected: "nil", actual: payload });
        }
      }
    } else if (candidate.boundary === "numeric-domain-exclusion") {
      const payload = compileSession.evaluate(`(cc.compile '(x) '(${candidate.body}))`);
      if (payload === "nil") {
        compilerDisposition = "unexpectedly-rejected";
        if (!earliestUnexpectedIntersection) {
          earliestUnexpectedIntersection = divergence(candidate, "compiler-disposition", { expected: "compiled", actual: "nil" });
        }
      } else {
        const bytes = assemble(wabt, payload);
        const { instance } = await WebAssembly.instantiate(bytes);
        compiledValue = String(instance.exports.run(candidate.argument));
        compilerDisposition = "outside-numeric-profile";
        numericDomainExclusions += 1;
        const outsideProfile = candidate.firstOutOfRangeValue < fixture.profile.numericMinimum
          || candidate.firstOutOfRangeValue > fixture.profile.numericMaximum;
        if (!outsideProfile && !earliestUnexpectedIntersection) {
          earliestUnexpectedIntersection = divergence(candidate, "numeric-profile-boundary", {
            minimum: fixture.profile.numericMinimum,
            maximum: fixture.profile.numericMaximum,
            actual: candidate.firstOutOfRangeValue,
          });
        }
        if (compiledValue !== candidate.expectedCompiledValue && !earliestUnexpectedIntersection) {
          earliestUnexpectedIntersection = divergence(candidate, "compiled-boundary-value", {
            expected: candidate.expectedCompiledValue,
            actual: compiledValue,
          });
        }
      }
    } else if (candidate.boundary === "precompile-reader" || candidate.boundary === "precompile-host") {
      compilerDisposition = "not-reached-before-valid-source-form";
      precompileBoundaries += 1;
    } else {
      throw new Error(`${candidate.id}: unsupported compiler boundary ${candidate.boundary}`);
    }

    cases.push({
      id: candidate.id,
      categoryCode: candidate.categoryCode,
      category: candidate.category,
      boundary: candidate.boundary,
      interpreterError,
      interpreterValue,
      compilerDisposition,
      compiledValue,
      firstOutOfRangeValue: candidate.firstOutOfRangeValue ?? null,
    });
  }

  if (observedJointErrorCases !== fixture.expectedJointErrorCases && !earliestUnexpectedIntersection) {
    earliestUnexpectedIntersection = divergence(
      { id: "profile-total" },
      "joint-error-count",
      { expected: fixture.expectedJointErrorCases, actual: observedJointErrorCases },
    );
  }

  return {
    schema: fixture.schema,
    status: earliestUnexpectedIntersection ? "divergent" : "pass",
    fixture: { bytes: profileBytes.byteLength, sha256: sha256(profileBytes) },
    profile: fixture.profile,
    expectedJointErrorCases: fixture.expectedJointErrorCases,
    observedJointErrorCases,
    coveredCategoryCodes,
    counts: {
      cases: cases.length,
      compilerRejections,
      precompileBoundaries,
      numericDomainExclusions,
    },
    earliestUnexpectedIntersection,
    cases,
  };
}
