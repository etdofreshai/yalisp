import { mkdir, readFile, writeFile } from "node:fs/promises";
import wabtInit from "wabt";

const sourceUrl = new URL("../src/seed/bootstrap.wat", import.meta.url);
const outputUrl = new URL("../public/yalisp/seed.wasm", import.meta.url);
const wabt = await wabtInit();
const source = await readFile(sourceUrl, "utf8");
const module = wabt.parseWat("bootstrap.wat", source, {});

try {
  module.validate();
  const { buffer } = module.toBinary({ write_debug_names: false });
  await mkdir(new URL("../public/yalisp/", import.meta.url), { recursive: true });
  await writeFile(outputUrl, Buffer.from(buffer));
  console.log(`wrote public/yalisp/seed.wasm: ${buffer.length} bytes`);
} finally {
  module.destroy();
}
