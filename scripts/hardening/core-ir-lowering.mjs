import {
  CORE_IR_DEFAULT_CAPS,
  CORE_IR_SCHEMA,
  irPair,
  irSymbol,
  serializeYalispData,
  validateCoreIr,
} from "./core-ir-v1.mjs";

export const CORE_IR_LOWERING_SCHEMA = "yalisp-core-ir-lowering-v1";

export const CORE_IR_LOWERING_DEFAULT_CAPS = Object.freeze({
  maxSourceBytes: 130_048,
  maxSourceUnitBytes: CORE_IR_DEFAULT_CAPS.maxSourceBytes,
  maxSyntaxNodes: CORE_IR_DEFAULT_CAPS.maxNodes,
  maxSyntaxDepth: CORE_IR_DEFAULT_CAPS.maxDepth,
  maxMacroExpansions: 1_024,
  maxMacroExpansionBytes: CORE_IR_DEFAULT_CAPS.maxLiteralBytes,
  maxOriginsPerSpan: CORE_IR_DEFAULT_CAPS.maxOriginsPerSpan,
});

const encoder = new TextEncoder();
const FIXNUM_MINIMUM = -1_073_741_824;
const FIXNUM_MAXIMUM = 1_073_741_823;

export class CoreIrLoweringError extends Error {
  constructor(code, message, { unit = "<source>", startByte = 0, endByte = startByte, detail = null } = {}) {
    super(message);
    this.name = "CoreIrLoweringError";
    this.code = code;
    this.unit = unit;
    this.startByte = startByte;
    this.endByte = endByte;
    this.detail = detail;
  }
}

function isPlainObject(value) {
  if (value === null || typeof value !== "object") return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function normalizeCaps(overrides) {
  if (overrides !== undefined && !isPlainObject(overrides)) {
    throw new TypeError("lowering caps must be a plain object");
  }
  for (const name of Object.keys(overrides ?? {})) {
    if (!Object.hasOwn(CORE_IR_LOWERING_DEFAULT_CAPS, name)) {
      throw new TypeError(`unknown core IR lowering cap: ${name}`);
    }
  }
  const caps = { ...CORE_IR_LOWERING_DEFAULT_CAPS, ...overrides };
  for (const [name, value] of Object.entries(caps)) {
    if (!Number.isSafeInteger(value) || value < 1) {
      throw new TypeError(`${name} must be a positive safe integer`);
    }
  }
  return Object.freeze(caps);
}

function rawSymbol(name) {
  return Object.freeze({ type: "symbol", name });
}

function isSymbolValue(value, name = undefined) {
  return isPlainObject(value)
    && value.type === "symbol"
    && typeof value.name === "string"
    && (name === undefined || value.name === name);
}

function syntaxValue(items, tail) {
  if (tail === null) return items.map((item) => item.value);
  let value = tail.value;
  for (let index = items.length - 1; index >= 0; index -= 1) {
    value = irPair(items[index].value, value);
  }
  return value;
}

export function parseYalispSource(source, { unit = "<source>", caps: capOverrides } = {}) {
  if (typeof source !== "string") throw new TypeError("source must be a string");
  if (typeof unit !== "string") throw new TypeError("source unit must be a string");
  const caps = normalizeCaps(capOverrides);
  const sourceBytes = encoder.encode(source).byteLength;
  const unitBytes = encoder.encode(unit).byteLength;
  if (unitBytes > caps.maxSourceUnitBytes) {
    throw new CoreIrLoweringError("source-unit-limit", "source unit exceeds the lowering byte cap", {
      unit,
      detail: caps.maxSourceUnitBytes,
    });
  }
  if (sourceBytes > caps.maxSourceBytes) {
    throw new CoreIrLoweringError("reader-source-limit", "source exceeds the lowering byte cap", {
      unit,
      startByte: caps.maxSourceBytes,
      endByte: sourceBytes,
      detail: caps.maxSourceBytes,
    });
  }

  let index = 0;
  let byteOffset = 0;
  let syntaxNodes = 0;
  let maxSyntaxDepth = 0;

  const fail = (code, message, startByte = byteOffset, endByte = startByte, detail = null) => {
    throw new CoreIrLoweringError(code, message, { unit, startByte, endByte, detail });
  };
  const peek = () => source[index];
  const advance = () => {
    if (index >= source.length) return "";
    const codePoint = source.codePointAt(index);
    const character = String.fromCodePoint(codePoint);
    index += character.length;
    byteOffset += encoder.encode(character).byteLength;
    return character;
  };
  const isDelimiter = (character) => character === undefined
    || character.codePointAt(0) <= 32
    || "()'\";`,".includes(character);
  const skipTrivia = () => {
    while (index < source.length) {
      const character = peek();
      if (character.codePointAt(0) <= 32) {
        advance();
        continue;
      }
      if (character !== ";") return;
      while (index < source.length && peek() !== "\n") advance();
      if (peek() === "\n") advance();
    }
  };
  const charge = (depth, startByte) => {
    if (depth > caps.maxSyntaxDepth) {
      fail("reader-depth-limit", "source nesting exceeds the lowering depth cap", startByte, startByte,
        caps.maxSyntaxDepth);
    }
    if (syntaxNodes >= caps.maxSyntaxNodes) {
      fail("reader-node-limit", "source forms exceed the lowering node cap", startByte, startByte,
        caps.maxSyntaxNodes);
    }
    syntaxNodes += 1;
    maxSyntaxDepth = Math.max(maxSyntaxDepth, depth);
  };

  const atomNode = (value, startByte, endByte, synthetic = false) => Object.freeze({
    kind: "atom", value, startByte, endByte, synthetic,
  });
  const listNode = (items, tail, startByte, endByte, synthetic = false) => Object.freeze({
    kind: "list", items: Object.freeze(items), tail, value: syntaxValue(items, tail),
    startByte, endByte, synthetic,
  });

  let readForm;
  const readString = (depth, startByte) => {
    charge(depth, startByte);
    advance();
    let value = "";
    while (index < source.length) {
      const character = advance();
      if (character === "\"") return atomNode(value, startByte, byteOffset);
      if (character !== "\\") {
        value += character;
        continue;
      }
      if (index >= source.length) break;
      const escaped = advance();
      const named = { n: "\n", t: "\t", r: "\r", b: "\b", f: "\f" }[escaped];
      if (named !== undefined) {
        value += named;
        continue;
      }
      if (escaped === "u" && /^00[0-9a-fA-F]{2}$/u.test(source.slice(index, index + 4))) {
        const code = Number.parseInt(source.slice(index + 2, index + 4), 16);
        if (code > 0x7f) {
          fail("reader-string-escape", "non-ASCII byte escapes are not portable UTF-8 strings",
            byteOffset - 2, byteOffset + 4, code);
        }
        for (let count = 0; count < 4; count += 1) advance();
        value += String.fromCharCode(code);
        continue;
      }
      value += escaped;
    }
    fail("reader-unterminated-string", "unterminated string", startByte, byteOffset);
  };

  const standaloneDot = () => peek() === "." && isDelimiter(source[index + 1]);
  const readList = (depth, startByte) => {
    charge(depth, startByte);
    advance();
    const items = [];
    let tail = null;
    while (true) {
      skipTrivia();
      if (index >= source.length) fail("reader-unterminated-list", "unterminated list", startByte, byteOffset);
      if (peek() === ")") {
        advance();
        return listNode(items, tail, startByte, byteOffset);
      }
      if (standaloneDot()) {
        if (items.length === 0) fail("reader-dotted-tail", "a dotted tail requires a preceding item");
        advance();
        skipTrivia();
        if (index >= source.length || peek() === ")") {
          fail("reader-dotted-tail", "a dotted tail requires one value");
        }
        tail = readForm(depth + 1);
        skipTrivia();
        if (peek() !== ")") {
          fail("reader-dotted-tail", "a dotted tail must be the final list value");
        }
        advance();
        return listNode(items, tail, startByte, byteOffset);
      }
      items.push(readForm(depth + 1));
    }
  };

  const readAtom = (depth, startByte) => {
    charge(depth, startByte);
    const startIndex = index;
    while (index < source.length && !isDelimiter(peek())) advance();
    const spelling = source.slice(startIndex, index);
    if (spelling.length === 0) fail("reader-token", "unexpected source token", startByte, byteOffset);
    if (spelling === "nil") return atomNode(null, startByte, byteOffset);
    if (spelling === "true") return atomNode(true, startByte, byteOffset);
    if (spelling === "false") return atomNode(false, startByte, byteOffset);
    if (/^[+-]?\d+$/u.test(spelling)) {
      const value = Number(spelling);
      if (!Number.isSafeInteger(value) || value < FIXNUM_MINIMUM || value > FIXNUM_MAXIMUM) {
        fail("reader-number-range", "integer literal exceeds the signed 30-bit range", startByte, byteOffset);
      }
      return atomNode(value, startByte, byteOffset);
    }
    return atomNode(rawSymbol(spelling), startByte, byteOffset);
  };

  const readPrefix = (depth, startByte, name, width = 1) => {
    charge(depth, startByte);
    for (let count = 0; count < width; count += 1) advance();
    skipTrivia();
    if (index >= source.length) fail("reader-prefix", `${name} requires one source form`, startByte, byteOffset);
    const operand = readForm(depth + 1);
    const head = atomNode(rawSymbol(name), startByte, startByte + width, true);
    return listNode([head, operand], null, startByte, operand.endByte, true);
  };

  readForm = (depth = 1) => {
    skipTrivia();
    const startByte = byteOffset;
    const character = peek();
    if (character === undefined) fail("reader-eof", "expected a source form", startByte, startByte);
    if (character === "(") return readList(depth, startByte);
    if (character === ")") fail("reader-closing", "unexpected closing parenthesis", startByte, startByte + 1);
    if (character === "\"") return readString(depth, startByte);
    if (character === "'") return readPrefix(depth, startByte, "quote");
    if (character === "`") return readPrefix(depth, startByte, "quasiquote");
    if (character === ",") {
      return source[index + 1] === "@"
        ? readPrefix(depth, startByte, "unquote-splicing", 2)
        : readPrefix(depth, startByte, "unquote");
    }
    return readAtom(depth, startByte);
  };

  const forms = [];
  skipTrivia();
  while (index < source.length) {
    forms.push(readForm(1));
    skipTrivia();
  }
  return Object.freeze({
    schema: CORE_IR_LOWERING_SCHEMA,
    unit,
    sourceBytes,
    forms: Object.freeze(forms),
    metrics: Object.freeze({ syntaxNodes, maxSyntaxDepth }),
    caps,
  });
}

function sourceRange(node, context, origins = context.origins) {
  const range = context.override ?? { unit: context.unit, startByte: node.startByte, endByte: node.endByte };
  return [irSymbol("src"), range.unit, range.startByte, range.endByte, origins];
}

function loweringFailure(code, message, node, context, detail = null) {
  const range = context.override ?? { unit: context.unit, startByte: node.startByte, endByte: node.endByte };
  throw new CoreIrLoweringError(code, message, { ...range, detail });
}

function symbolName(node, code, context) {
  if (!node || !isSymbolValue(node.value)) {
    loweringFailure(code, "expected a symbol", node ?? { startByte: 0, endByte: 0 }, context);
  }
  try {
    irSymbol(node.value.name);
  } catch {
    loweringFailure("nonportable-symbol", "symbol cannot be represented in core IR", node, context, node.value.name);
  }
  return node.value.name;
}

function properItems(node, code, context) {
  if (!node || node.kind !== "list" || node.tail !== null) {
    loweringFailure(code, "expected a proper list", node ?? { startByte: 0, endByte: 0 }, context);
  }
  return node.items;
}

function requireCount(items, minimum, maximum, node, context, name) {
  const count = items.length - 1;
  if (count < minimum || count > maximum) {
    loweringFailure("lowering-arity", `${name} expects ${minimum === maximum ? minimum : `${minimum}..${maximum}`} operand(s)`,
      node, context, { name, minimum, maximum, actual: count });
  }
}

export async function lowerSourceToCoreIr(source, {
  unit = "<source>",
  caps: capOverrides,
  expandOuter,
} = {}) {
  if (expandOuter !== undefined && typeof expandOuter !== "function") {
    throw new TypeError("expandOuter must be a function");
  }
  const caps = normalizeCaps(capOverrides);
  const parsed = parseYalispSource(source, { unit, caps });
  if (parsed.forms.length !== 1) {
    throw new CoreIrLoweringError("lowering-form-count", "core IR lowering requires exactly one submission form", {
      unit,
      startByte: 0,
      endByte: parsed.sourceBytes,
      detail: parsed.forms.length,
    });
  }
  const state = {
    nextBindingId: 0,
    expansionCount: 0,
    macroExpansionBytes: 0,
    syntaxNodes: parsed.metrics.syntaxNodes,
    maxSyntaxDepth: parsed.metrics.maxSyntaxDepth,
  };
  const specialForms = new Set([
    "quote", "if", "lambda", "macro", "define", "set!", "begin",
    "quasiquote", "unquote", "unquote-splicing",
  ]);

  const binding = (name, scope) => scope.has(name)
    ? [irSymbol("local"), scope.get(name)]
    : [irSymbol("global"), irSymbol(name)];

  const appendOrigin = (context, origin, node) => {
    if (context.origins.length >= caps.maxOriginsPerSpan) {
      loweringFailure("source-origin-limit", "macro/generated provenance exceeds the lowering cap",
        node, context, caps.maxOriginsPerSpan);
    }
    return [...context.origins, origin];
  };

  let lower;
  const lowerSequence = async (forms, tail, scope, context, reason, owner) => {
    if (forms.length === 1) return lower(forms[0], tail, scope, context);
    const startByte = forms[0]?.startByte ?? owner.endByte;
    const endByte = forms.at(-1)?.endByte ?? owner.endByte;
    const sequenceNode = { startByte, endByte };
    const origins = appendOrigin(context, [irSymbol("generated"), irSymbol(reason)], sequenceNode);
    const lowered = [];
    for (let index = 0; index < forms.length; index += 1) {
      lowered.push(await lower(forms[index], index === forms.length - 1 ? tail : false, scope, context));
    }
    return [irSymbol("begin"), tail, sourceRange(sequenceNode, context, origins), lowered];
  };

  const lowerLambda = async (node, items, tail, scope, context) => {
    requireCount(items, 2, Number.MAX_SAFE_INTEGER, node, context, "lambda");
    const parameterNode = items[1];
    const childScope = new Map(scope);
    const parameters = [];
    let rest = null;
    const bind = (candidate) => {
      const name = symbolName(candidate, "lambda-parameter", context);
      const id = state.nextBindingId;
      state.nextBindingId += 1;
      childScope.set(name, id);
      return [irSymbol("bind"), id, irSymbol(name)];
    };
    if (parameterNode.kind === "atom" && isSymbolValue(parameterNode.value)) {
      rest = bind(parameterNode);
    } else {
      if (parameterNode.kind !== "list") {
        loweringFailure("lambda-parameters", "expected a parameter list or rest symbol", parameterNode, context);
      }
      for (const candidate of parameterNode.items) parameters.push(bind(candidate));
      if (parameterNode.tail !== null) rest = bind(parameterNode.tail);
    }
    const childContext = { ...context, globalFrame: false };
    const body = await lowerSequence(items.slice(2), true, childScope, childContext, "implicit-begin", node);
    return [irSymbol("lambda"), tail, sourceRange(node, context), parameters, rest, body];
  };

  lower = async (node, tail, scope, context) => {
    if (node.kind === "atom") {
      if (isSymbolValue(node.value)) {
        const name = symbolName(node, "reference-name", context);
        return [irSymbol("ref"), tail, sourceRange(node, context), binding(name, scope)];
      }
      return [irSymbol("const"), tail, sourceRange(node, context), node.value];
    }
    if (node.items.length === 0 && node.tail === null) {
      return [irSymbol("const"), tail, sourceRange(node, context), null];
    }
    if (node.tail !== null) loweringFailure("improper-application", "an application must be a proper list", node, context);
    const items = node.items;
    const headName = isSymbolValue(items[0]?.value) ? items[0].value.name : null;

    if (headName === "quote") {
      requireCount(items, 1, 1, node, context, "quote");
      return [irSymbol("const"), tail, sourceRange(node, context), items[1].value];
    }
    if (headName === "if") {
      requireCount(items, 2, 3, node, context, "if");
      const test = await lower(items[1], false, scope, context);
      const consequent = await lower(items[2], tail, scope, context);
      const missingElse = items.length === 3;
      const alternate = missingElse
        ? [irSymbol("const"), tail,
          sourceRange({ startByte: node.endByte, endByte: node.endByte }, context,
            appendOrigin(context, [irSymbol("generated"), irSymbol("missing-else")], node)), null]
        : await lower(items[3], tail, scope, context);
      return [irSymbol("if"), tail, sourceRange(node, context),
        test, consequent, alternate];
    }
    if (headName === "lambda") return lowerLambda(node, items, tail, scope, context);
    if (headName === "define") {
      requireCount(items, 2, 2, node, context, "define");
      if (!context.globalFrame) {
        loweringFailure("unsupported-local-define",
          "core IR v1 cannot preserve current-frame define semantics inside a closure", node, context);
      }
      const name = symbolName(items[1], "define-name", context);
      return [irSymbol("define"), tail, sourceRange(node, context), irSymbol(name),
        await lower(items[2], false, scope, context)];
    }
    if (headName === "set!") {
      requireCount(items, 2, 2, node, context, "set!");
      const name = symbolName(items[1], "set-name", context);
      return [irSymbol("set"), tail, sourceRange(node, context), binding(name, scope),
        await lower(items[2], false, scope, context)];
    }
    if (headName === "begin") {
      const forms = [];
      for (let index = 1; index < items.length; index += 1) {
        forms.push(await lower(items[index], index === items.length - 1 ? tail : false, scope, context));
      }
      return [irSymbol("begin"), tail, sourceRange(node, context), forms];
    }
    if (headName === "macro" || headName === "quasiquote"
        || headName === "unquote" || headName === "unquote-splicing") {
      loweringFailure("unsupported-core-form", `${headName} must be resolved before runtime core lowering`, node, context,
        headName);
    }

    if (expandOuter && headName !== null && !specialForms.has(headName) && !scope.has(headName)) {
      const canonicalInput = serializeYalispData(node.value);
      const expandedSource = await expandOuter(canonicalInput);
      if (typeof expandedSource !== "string") {
        loweringFailure("macro-expansion-result", "macro expansion must return canonical source text", node, context);
      }
      const expansionBytes = encoder.encode(expandedSource).byteLength;
      if (state.macroExpansionBytes + expansionBytes > caps.maxMacroExpansionBytes) {
        loweringFailure("macro-expansion-byte-limit", "macro expansion output exceeds the lowering byte cap",
          node, context, caps.maxMacroExpansionBytes);
      }
      state.macroExpansionBytes += expansionBytes;
      const expanded = parseYalispSource(expandedSource, { unit, caps });
      if (state.syntaxNodes + expanded.metrics.syntaxNodes > caps.maxSyntaxNodes) {
        loweringFailure("macro-syntax-node-limit", "expanded syntax exceeds the lowering node cap",
          node, context, caps.maxSyntaxNodes);
      }
      state.syntaxNodes += expanded.metrics.syntaxNodes;
      state.maxSyntaxDepth = Math.max(state.maxSyntaxDepth, expanded.metrics.maxSyntaxDepth);
      if (expanded.forms.length !== 1) {
        loweringFailure("macro-expansion-result", "macro expansion must return exactly one form", node, context,
          expanded.forms.length);
      }
      const expandedNode = expanded.forms[0];
      const canonicalExpanded = serializeYalispData(expandedNode.value);
      if (canonicalExpanded !== canonicalInput) {
        if (state.expansionCount >= caps.maxMacroExpansions) {
          loweringFailure("macro-expansion-limit", "macro expansion exceeds the lowering step cap", node, context,
            caps.maxMacroExpansions);
        }
        state.expansionCount += 1;
        const range = context.override ?? { unit: context.unit, startByte: node.startByte, endByte: node.endByte };
        const origin = [irSymbol("macro"), irSymbol(symbolName(items[0], "macro-name", context)),
          range.unit, range.startByte, range.endByte];
        return lower(expandedNode, tail, scope, {
          ...context,
          override: range,
          origins: appendOrigin(context, origin, node),
        });
      }
    }

    const callee = await lower(items[0], false, scope, context);
    const argumentsIr = [];
    for (let index = 1; index < items.length; index += 1) {
      argumentsIr.push(await lower(items[index], false, scope, context));
    }
    return [irSymbol("call"), tail, sourceRange(node, context), callee, argumentsIr];
  };

  const context = { unit, override: null, origins: [], globalFrame: true };
  const root = await lower(parsed.forms[0], true, new Map(), context);
  const program = [irSymbol(CORE_IR_SCHEMA), root];
  const validation = validateCoreIr(program);
  if (validation.status !== "valid") {
    throw new CoreIrLoweringError("invalid-lowered-ir", "lowering produced invalid core IR", {
      unit,
      detail: validation.error,
    });
  }
  return Object.freeze({
    schema: CORE_IR_LOWERING_SCHEMA,
    program,
    expansionCount: state.expansionCount,
    bindings: state.nextBindingId,
    sourceBytes: parsed.sourceBytes,
    syntaxMetrics: Object.freeze({
      inputNodes: parsed.metrics.syntaxNodes,
      totalNodes: state.syntaxNodes,
      maxDepth: state.maxSyntaxDepth,
      macroExpansionBytes: state.macroExpansionBytes,
    }),
    validation,
  });
}
