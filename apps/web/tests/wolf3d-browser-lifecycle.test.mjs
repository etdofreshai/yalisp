import assert from "node:assert/strict";
import { readFile } from "node:fs/promises";
import test from "node:test";

test("the browser host owns one idempotent Lisp and audio shutdown path", async () => {
  const source = await readFile(new URL("../src/examples/runtime/lisp-application.ts", import.meta.url), "utf8");
  const closeStart = source.indexOf("const closeApplication = async () => {");
  const shutdown = source.indexOf('session.evaluateQuietly("(app.shutdown)")', closeStart);
  const audioClose = source.indexOf("await audio.close()", closeStart);
  const pageHide = source.indexOf("const handlePageHide = () => {");

  assert.ok(closeStart >= 0);
  assert.ok(source.indexOf("if (closed) return;", closeStart) > closeStart);
  assert.ok(shutdown > closeStart && audioClose > shutdown, "Lisp shutdown must precede audio close");
  assert.equal(source.match(/session\.evaluateQuietly\("\(app\.shutdown\)"\)/g)?.length, 1);
  assert.ok(source.indexOf("void closeApplication().catch", pageHide) > pageHide);
});

test("the browser host releases global input listeners and held input state", async () => {
  const source = await readFile(new URL("../src/examples/runtime/lisp-application.ts", import.meta.url), "utf8");
  for (const event of ["keydown", "keyup"]) {
    const handler = event === "keydown" ? "handleKeyDown" : "handleKeyUp";
    assert.match(source, new RegExp(`window\\.addEventListener\\(\\"${event}\\", ${handler}\\)`));
    assert.match(source, new RegExp(`window\\.removeEventListener\\(\\"${event}\\", ${handler}\\)`));
  }
  assert.match(source, /const clearHeldInputs = \(\) => \{\s*held\.clear\(\)/);
  assert.match(source, /window\.addEventListener\("blur", clearHeldInputs\)/);
  assert.match(source, /window\.removeEventListener\("blur", clearHeldInputs\)/);
  assert.match(source, /if \(closed\) return;\s*if \(running && !busy\)/);
});
