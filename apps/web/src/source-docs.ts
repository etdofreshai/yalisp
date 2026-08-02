import "./docs";
import seedSource from "./seed/bootstrap.wat?raw";

const sourceTargets = [
  { selector: "[data-seed-source]", source: seedSource, label: "WAT seed" },
  { selector: "[data-bootstrap-source]", path: "/yalisp/boot.lisp", label: "bootstrap" },
  { selector: "[data-compiler-source]", path: "/yalisp/compiler.lisp", label: "compiler" }
] as const;

async function renderSource(target: HTMLElement, path: string, label: string) {
  try {
    const response = await fetch(path);
    if (!response.ok) throw new Error(`HTTP ${response.status}`);
    target.textContent = await response.text();
  } catch (error) {
    target.textContent = `The checked-in ${label} source could not be loaded: ${error instanceof Error ? error.message : String(error)}`;
  }
}

await Promise.all(sourceTargets.map(async ({ selector, label, ...entry }) => {
  const target = document.querySelector<HTMLElement>(selector);
  if (!target) return;
  if ("source" in entry) target.textContent = entry.source;
  else await renderSource(target, entry.path, label);
}));
