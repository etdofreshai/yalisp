import { createSeedSession } from "./seed-runtime";
import { parseLispValue, printLispValue } from "./examples/runtime/lisp-application";

type LispValue = number | string | LispValue[];
type LispList = LispValue[];

const eventAttribute = "on-click";
const documentThemeAttribute = "document-theme";

function isList(value: LispValue): value is LispList {
  return Array.isArray(value);
}

function text(value: LispValue | undefined): string {
  if (typeof value === "number") return String(value);
  if (typeof value === "string") return value;
  throw new Error("A DOM Lisp atom must be text or a number.");
}

function appendNode(
  parent: ParentNode,
  value: LispValue,
  dispatch: (event: string) => void
): void {
  if (!isList(value)) {
    parent.append(document.createTextNode(text(value)));
    return;
  }

  const [tag, rawAttributes, ...children] = value;
  const attributes: LispValue = rawAttributes === "nil" ? [] : (rawAttributes ?? []);
  if (text(tag ?? "") === "fragment") {
    if (isList(attributes)) {
      attributes.forEach((attribute) => {
        if (isList(attribute) && attribute[0] === documentThemeAttribute) {
          document.documentElement.dataset.theme = text(attribute[1]);
        }
      });
    }
    children.forEach((child) => appendNode(parent, child, dispatch));
    return;
  }
  if (typeof tag !== "string") throw new Error("A DOM Lisp node needs a symbolic element name.");
  if (!isList(attributes)) throw new Error(`The <${tag}> node needs an attribute list.`);

  const element = document.createElement(tag);
  attributes.forEach((attribute) => {
    if (!isList(attribute) || attribute.length !== 2 || typeof attribute[0] !== "string") {
      throw new Error(`The <${tag}> node has an invalid attribute.`);
    }
    const [name, attributeValue] = attribute;
    const valueText = text(attributeValue ?? "");
    if (name === documentThemeAttribute) {
      document.documentElement.dataset.theme = valueText;
    } else if (name === eventAttribute) {
      element.addEventListener("click", () => dispatch(valueText));
    } else {
      element.setAttribute(name, valueText);
    }
  });
  children.forEach((child) => appendNode(element, child, dispatch));
  parent.append(element);
}

/**
 * Execute a YALISP DOM application. The browser owns only this renderer and
 * event bridge: element structure, attributes, text, and event state all come
 * from the checked-in Lisp program.
 */
export async function runDomApplication(root: HTMLElement, source: string) {
  const session = await createSeedSession("bootstrap");
  session.evaluateQuietly(source);
  let state = parseLispValue(session.evaluateDom("(app.initial-state)"));
  let rendering = false;

  const render = () => {
    const tree = parseLispValue(session.evaluateDom(`(app.view '${printLispValue(state)})`));
    root.replaceChildren();
    appendNode(root, tree, (event) => {
      if (rendering) return;
      rendering = true;
      try {
        state = parseLispValue(session.evaluateDom(`(app.event '${printLispValue(state)} '${event})`));
        render();
      } finally {
        rendering = false;
      }
    });
  };

  render();
}
