import assert from "node:assert/strict";
import test from "node:test";
import { codeLines, features, principles } from "../dist/index.js";

test("landing page content has stable feature and code contracts", () => {
  assert.equal(features.length, 3);
  assert.equal(principles.length, 3);
  assert.ok(codeLines.length >= 8);
  assert.deepEqual(features.map(({ index }) => index), ["01", "02", "03"]);
});

