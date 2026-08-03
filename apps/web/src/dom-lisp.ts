import { createSeedSession } from "./seed-runtime";
import { parseLispValue, printLispValue } from "./examples/runtime/lisp-application";

type LispValue = number | string | LispValue[];
type LispList = LispValue[];

const eventAttribute = "on-click";
const documentThemeAttribute = "document-theme";
const sectionChangeAttribute = "on-section-change";

type RenderOptions = {
  sectionEventPrefix?: string;
};

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
  dispatch: (event: string) => void,
  options: RenderOptions
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
        if (!isList(attribute)) return;
        if (attribute[0] === documentThemeAttribute) document.documentElement.dataset.theme = text(attribute[1]);
        if (attribute[0] === sectionChangeAttribute) options.sectionEventPrefix = text(attribute[1]);
      });
    }
    children.forEach((child) => appendNode(parent, child, dispatch, options));
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
  children.forEach((child) => appendNode(element, child, dispatch, options));
  parent.append(element);
}

/**
 * Execute a YALISP DOM application. The browser owns only this renderer and
 * event bridge: element structure, attributes, text, and event state all come
 * from the checked-in Lisp program.
 */
export async function runDomApplication(root: HTMLElement, source: string | readonly string[]) {
  const session = await createSeedSession("bootstrap");
  for (const module of typeof source === "string" ? [source] : source) {
    session.evaluateQuietly(module);
  }
  let state = parseLispValue(session.evaluateDom("(app.initial-state)"));
  let rendering = false;
  let sectionEventPrefix: string | undefined;
  let activeSection = "";

  const dispatch = (event: string) => {
    if (rendering) return;
    rendering = true;
    try {
      state = parseLispValue(session.evaluateDom(`(app.event '${printLispValue(state)} '${event})`));
      render();
    } finally {
      rendering = false;
    }
  };

  const syncActiveSection = () => {
    if (!sectionEventPrefix) return;
    const hash = window.location.hash.slice(1);
    const sections = [...root.querySelectorAll<HTMLElement>("main section[id]")];
    const selected = hash && sections.some((section) => section.id === hash)
      ? hash
      : sections.reduce((current, section) => section.getBoundingClientRect().top <= Math.max(96, window.innerHeight * 0.24) ? section.id : current, sections[0]?.id ?? "");
    if (!selected || selected === activeSection) return;
    activeSection = selected;
    dispatch(`${sectionEventPrefix}-${selected}`);
  };

  let scrollFrame = 0;
  window.addEventListener("hashchange", syncActiveSection);
  window.addEventListener("scroll", () => {
    if (!sectionEventPrefix || scrollFrame) return;
    scrollFrame = window.requestAnimationFrame(() => {
      scrollFrame = 0;
      syncActiveSection();
    });
  }, { passive: true });

  const render = () => {
    const tree = parseLispValue(session.evaluateDom(`(app.view '${printLispValue(state)})`));
    root.replaceChildren();
    const options: RenderOptions = {};
    appendNode(root, tree, dispatch, options);
    sectionEventPrefix = options.sectionEventPrefix;
  };

  render();
  syncActiveSection();
}
