import assert from "node:assert/strict";
import test from "node:test";

import { runCompilerErrorIntersection } from "../../../scripts/hardening/compiler-error-intersection-lib.mjs";

test("the bounded compiler has an explicit empty language-error intersection", async () => {
  const report = await runCompilerErrorIntersection();
  assert.equal(report.status, "pass");
  assert.equal(report.expectedJointErrorCases, 0);
  assert.equal(report.observedJointErrorCases, 0);
  assert.equal(report.earliestUnexpectedIntersection, null);
  assert.deepEqual(report.coveredCategoryCodes, [1, 2, 3, 4, 5, 6, 7, 8, 9, 10]);
  assert.equal(report.counts.cases, 11);
  assert.equal(report.counts.compilerRejections, 8);
  assert.equal(report.counts.precompileBoundaries, 2);
  assert.equal(report.counts.numericDomainExclusions, 1);

  const overflow = report.cases.find((candidate) => candidate.id === "accepted-expression-outside-numeric-profile");
  assert.equal(overflow.compilerDisposition, "outside-numeric-profile");
  assert.equal(overflow.compiledValue, "1073741824");
  assert.equal(overflow.interpreterValue, null);
  assert.equal(overflow.interpreterError.category, "arithmetic");
  assert.equal(overflow.interpreterError.diagnostic, "value exceeds fixnum range");
  assert.equal(overflow.firstOutOfRangeValue, 1073741824);
});
