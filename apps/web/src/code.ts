import "./docs";
import seedSource from "./seed/bootstrap.wat?raw";

const seedTarget = document.querySelector<HTMLElement>("[data-seed-source]");
const bootstrapTarget = document.querySelector<HTMLElement>("[data-bootstrap-source]");
const compilerTarget = document.querySelector<HTMLElement>("[data-compiler-source]");

if (!seedTarget || !bootstrapTarget || !compilerTarget) {
  throw new Error("The YALISP Code page is missing a source target.");
}

seedTarget.textContent = seedSource;

async function renderSource(path: string, target: HTMLElement, label: string) {
  try {
    const response = await fetch(path);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    target.textContent = await response.text();
  } catch (error) {
    target.textContent = `The checked-in ${label} source could not be loaded: ${error instanceof Error ? error.message : String(error)}`;
  }
}

await Promise.all([
  renderSource("/yalisp/boot.lisp", bootstrapTarget, "bootstrap"),
  renderSource("/yalisp/compiler.lisp", compilerTarget, "compiler")
]);
