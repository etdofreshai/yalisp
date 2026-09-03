import assert from "node:assert/strict";
import test from "node:test";

import {
  INHERITED_CASE_FLOOR,
  RUNNER_SCHEMA,
  aggregateShards,
  assertResumeIdentity,
  coverageDelta,
  parseTap,
  shouldStopAfterShard,
} from "../../../scripts/hardening/conformance-runner.mjs";

function tap({ name = "case", directive = "", fail = 0, cancelled = 0, skipped = 0 } = {}) {
  const outcome = fail ? "not ok" : "ok";
  return `TAP version 13
# Subtest: ${name}
${outcome} 1 - ${name}${directive}
1..1
# tests 1
# suites 0
# pass ${fail ? 0 : 1}
# fail ${fail}
# cancelled ${cancelled}
# skipped ${skipped}
# todo 0
# duration_ms 12.5
`;
}

function shard(file, parsed, status = "completed") {
  return { file, status, tap: parsed, exitCode: parsed.fail ? 1 : 0, signal: null };
}

test("TAP parser retains stable top-level case IDs and strict summary counts", () => {
  const parsed = parseTap(tap({ name: "reader round trip" }), "tests/reader.test.mjs");
  assert.deepEqual(
    { tests: parsed.tests, pass: parsed.pass, fail: parsed.fail, durationMs: parsed.durationMs },
    { tests: 1, pass: 1, fail: 0, durationMs: 12.5 },
  );
  assert.deepEqual(parsed.cases, [{
    id: "tests/reader.test.mjs::1::reader round trip",
    file: "tests/reader.test.mjs",
    ordinal: 1,
    name: "reader round trip",
    ordinalPath: [1],
    namePath: ["reader round trip"],
    status: "pass",
  }]);
});

test("TAP parser retains every nested result with a stable hierarchical ID", () => {
  const parsed = parseTap(`TAP version 13
# Subtest: malformed inputs
    # Subtest: truncated source
    ok 1 - truncated source
      ---
      duration_ms: 1
      type: 'test'
      ...
    # Subtest: wrong dimensions
    ok 2 - wrong dimensions
      ---
      duration_ms: 2
      type: 'test'
      ...
    1..2
ok 1 - malformed inputs
  ---
  duration_ms: 3
  type: 'test'
  ...
1..1
# tests 3
# suites 0
# pass 3
# fail 0
# cancelled 0
# skipped 0
# todo 0
# duration_ms 4
`, "nested.test.mjs");
  assert.deepEqual(parsed.cases, [
    {
      id: "nested.test.mjs::1::malformed inputs",
      file: "nested.test.mjs",
      ordinal: 1,
      name: "malformed inputs",
      ordinalPath: [1],
      namePath: ["malformed inputs"],
      status: "pass",
    },
    {
      id: "nested.test.mjs::1::malformed inputs::1::truncated source",
      file: "nested.test.mjs",
      ordinal: 1,
      name: "truncated source",
      ordinalPath: [1, 1],
      namePath: ["malformed inputs", "truncated source"],
      status: "pass",
    },
    {
      id: "nested.test.mjs::1::malformed inputs::2::wrong dimensions",
      file: "nested.test.mjs",
      ordinal: 2,
      name: "wrong dimensions",
      ordinalPath: [1, 2],
      namePath: ["malformed inputs", "wrong dimensions"],
      status: "pass",
    },
  ]);
});

test("TAP parser preserves nested failure ownership instead of collapsing it into the parent", () => {
  const parsed = parseTap(`TAP version 13
# Subtest: parent failure
    # Subtest: child failure
    not ok 1 - child failure
      ---
      error: boom
      ...
    1..1
not ok 1 - parent failure
  ---
  error: child failure
  ...
1..1
# tests 2
# suites 0
# pass 0
# fail 2
# cancelled 0
# skipped 0
# todo 0
# duration_ms 2
`, "nested-failure.test.mjs");
  assert.deepEqual(parsed.cases.map(({ id, status }) => ({ id, status })), [
    { id: "nested-failure.test.mjs::1::parent failure", status: "fail" },
    { id: "nested-failure.test.mjs::1::parent failure::1::child failure", status: "fail" },
  ]);
});

test("TAP parser rejects an interrupted result without a complete footer", () => {
  assert.throws(
    () => parseTap("TAP version 13\nok 1 - partial\n", "partial.test.mjs"),
    /footer is missing tests/,
  );
});

test("TAP parser makes skips explicit in the case manifest", () => {
  const parsed = parseTap(tap({ name: "optional", directive: " # SKIP unavailable", skipped: 1 }), "skip.test.mjs");
  assert.equal(parsed.cases[0].status, "skip");
  assert.equal(parsed.skipped, 1);
});

test("resume requires the exact schema and identity hash", () => {
  assert.equal(assertResumeIdentity("abc", { schema: RUNNER_SCHEMA, identityHash: "abc" }), true);
  assert.throws(
    () => assertResumeIdentity("abc", { schema: RUNNER_SCHEMA, identityHash: "def" }),
    /resume identity mismatch/,
  );
  assert.throws(
    () => assertResumeIdentity("abc", { schema: "older", identityHash: "abc" }),
    /resume schema mismatch/,
  );
});

test("coverage floor reports inherited count deltas without inventing old case IDs", () => {
  const cases = Array.from({ length: INHERITED_CASE_FLOOR + 2 }, (_, index) => ({
    id: `case-${index}`,
    file: "suite.test.mjs",
    ordinal: index + 1,
    status: "pass",
  }));
  assert.deepEqual(coverageDelta(cases), {
    baselineTotal: INHERITED_CASE_FLOOR,
    currentTotal: INHERITED_CASE_FLOOR + 2,
    addedCount: 2,
    removedCount: 0,
    renamedCount: null,
    renamedReason: "the inherited complete baseline retained a count but no stable case IDs",
    skippedCount: 0,
    cancelledCount: 0,
  });
});

test("coverage comparison distinguishes additions, removals, and same-ordinal renames", () => {
  const oldCases = [
    { id: "a::1::old", file: "a", ordinal: 1, status: "pass" },
    { id: "a::2::removed", file: "a", ordinal: 2, status: "pass" },
  ];
  const currentCases = [
    { id: "a::1::new", file: "a", ordinal: 1, status: "pass" },
    { id: "b::1::added", file: "b", ordinal: 1, status: "pass" },
  ];
  const delta = coverageDelta(currentCases, { cases: oldCases });
  assert.equal(delta.addedCount, 1);
  assert.equal(delta.removedCount, 1);
  assert.equal(delta.renamedCount, 1);
  assert.deepEqual(delta.renamed, [{ from: "a::1::old", to: "a::1::new" }]);
});

test("coverage comparison matches nested renames only at the same full ordinal path", () => {
  const oldCases = [
    { id: "a::1::parent::1::old", file: "a", ordinal: 1, ordinalPath: [1, 1], status: "pass" },
  ];
  const currentCases = [
    { id: "a::1::parent::2::new", file: "a", ordinal: 2, ordinalPath: [1, 2], status: "pass" },
  ];
  const delta = coverageDelta(currentCases, { cases: oldCases });
  assert.equal(delta.renamedCount, 0);
  assert.equal(delta.addedCount, 1);
  assert.equal(delta.removedCount, 1);
});

test("fail-fast stops on the first non-green shard while promotion completes all shards", () => {
  const failed = shard("bad.test.mjs", parseTap(tap({ fail: 1 }), "bad.test.mjs"));
  assert.equal(shouldStopAfterShard(failed, "fail-fast"), true);
  assert.equal(shouldStopAfterShard(failed, "promotion"), false);
  const passed = shard("good.test.mjs", parseTap(tap(), "good.test.mjs"));
  assert.equal(shouldStopAfterShard(passed, "fail-fast"), false);
});

test("promotion aggregate rejects skips, cancellations, incomplete shards, and coverage loss", () => {
  const parsed = parseTap(tap({ directive: " # SKIP later", skipped: 1 }), "skip.test.mjs");
  const aggregate = aggregateShards([
    shard("skip.test.mjs", parsed),
    { file: "missing.test.mjs", status: "pending" },
  ], "promotion");
  assert.equal(aggregate.status, "fail");
  assert.match(aggregate.violations.join("; "), /incomplete/);
  assert.match(aggregate.violations.join("; "), new RegExp(`below the ${INHERITED_CASE_FLOOR}-case floor`));
  assert.match(aggregate.violations.join("; "), /skipped/);
});

test("a complete failing TAP shard retains its failure counts and abnormal exit evidence", () => {
  const parsed = parseTap(tap({ fail: 1 }), "failed.test.mjs");
  const aggregate = aggregateShards([shard("failed.test.mjs", parsed)], "fail-fast");
  assert.equal(aggregate.counts.tests, 1);
  assert.equal(aggregate.counts.fail, 1);
  assert.deepEqual(aggregate.abnormalProcesses, [{ file: "failed.test.mjs", exitCode: 1, signal: null }]);
  assert.match(aggregate.violations.join("; "), /failed test/);
});
