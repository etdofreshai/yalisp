import "./docs";
import seedSource from "./seed/bootstrap.wat?raw";

const seedTarget = document.querySelector<HTMLElement>("[data-seed-source]");
const bootstrapTarget = document.querySelector<HTMLElement>("[data-bootstrap-source]");

if (!seedTarget || !bootstrapTarget) {
  throw new Error("The YALISP Code page is missing a source target.");
}

seedTarget.textContent = seedSource;

try {
  const response = await fetch("/yalisp/boot.lisp");
  if (!response.ok) throw new Error(`HTTP ${response.status}`);
  bootstrapTarget.textContent = await response.text();
} catch (error) {
  bootstrapTarget.textContent = `The checked-in bootstrap source could not be loaded: ${error instanceof Error ? error.message : String(error)}`;
}
