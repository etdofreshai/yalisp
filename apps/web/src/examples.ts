import "./docs";
import "./examples.css";
import { createSeedSession } from "./seed-runtime";

const runner = document.querySelector<HTMLElement>("[data-yalispexample]");

if (runner) {
  const sourceUrl = runner.dataset.source;
  const sourceView = runner.querySelector<HTMLElement>("[data-example-source]");
  const runButton = runner.querySelector<HTMLButtonElement>("[data-example-run]");
  const output = runner.querySelector<HTMLOutputElement>("[data-example-output]");
  if (!sourceUrl || !sourceView || !runButton || !output) {
    throw new Error("The YALISP example is missing its source or runner controls.");
  }

  let source = "";
  fetch(sourceUrl)
    .then((response) => {
      if (!response.ok) throw new Error(`${sourceUrl} returned ${response.status}`);
      return response.text();
    })
    .then((text) => {
      source = text.trim();
      sourceView.textContent = source;
      runButton.disabled = false;
    })
    .catch((error) => {
      output.textContent = `Source unavailable: ${error instanceof Error ? error.message : String(error)}`;
    });

  runButton.addEventListener("click", async () => {
    runButton.disabled = true;
    output.textContent = "Evaluating in the WebAssembly seed…";
    try {
      const session = await createSeedSession("seed");
      output.textContent = session.evaluate(source) || "nil";
    } catch (error) {
      output.textContent = `Interpreter stopped: ${error instanceof Error ? error.message : String(error)}`;
    } finally {
      runButton.disabled = false;
    }
  });
}
