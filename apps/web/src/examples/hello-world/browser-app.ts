import { createSeedSession } from "../../seed-runtime";
import helloSource from "./hello.lisp?raw";

export function mountHelloWorld(root: HTMLElement) {
  const sourceView = root.querySelector<HTMLElement>("[data-example-source]");
  const runButton = root.querySelector<HTMLButtonElement>("[data-example-run]");
  const output = root.querySelector<HTMLOutputElement>("[data-example-output]");
  if (!sourceView || !runButton || !output) throw new Error("Hello World is missing its application controls.");

  const source = helloSource.trim();
  sourceView.textContent = source;
  runButton.disabled = false;
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

  return { source, run: () => runButton.click() };
}
