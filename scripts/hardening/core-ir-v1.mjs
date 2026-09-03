import { createHash } from "node:crypto";

export const CORE_IR_SCHEMA = "yalisp-core-ir-v1";

export const CORE_IR_DEFAULT_CAPS = Object.freeze({
  maxNodes: 4_096,
  maxDepth: 256,
  maxLiteralNodes: 8_192,
  maxLiteralBytes: 1_048_576,
  maxSourceBytes: 65_536,
  maxOriginsPerSpan: 64,
});

const encoder = new TextEncoder();
const FIXNUM_MINIMUM = -1_073_741_824;
const FIXNUM_MAXIMUM = 1_073_741_823;

function isPlainObject(value) {
  if (value === null || typeof value !== "object") return false;
  const prototype = Object.getPrototypeOf(value);
  return prototype === Object.prototype || prototype === null;
}

function validSymbolName(name) {
  return typeof name === "string" && name.length > 0
    && !/[\s()"'`,;]/u.test(name) && name !== "."
    && name !== "nil" && name !== "true" && name !== "false";
}

export function irSymbol(name) {
  if (!validSymbolName(name)) {
    throw new TypeError(`invalid YaLisp symbol spelling: ${JSON.stringify(name)}`);
  }
  return Object.freeze({ type: "symbol", name });
}

export function irPair(car, cdr) {
  return Object.freeze({ type: "pair", car, cdr });
}

export function isIrSymbol(value, name = undefined) {
  return isPlainObject(value)
    && value.type === "symbol"
    && validSymbolName(value.name)
    && (name === undefined || value.name === name);
}

function sourceString(value) {
  let source = "\"";
  for (const character of value) {
    const code = character.codePointAt(0);
    if (character === "\"" || character === "\\") source += `\\${character}`;
    else if (character === "\n") source += "\\n";
    else if (character === "\t") source += "\\t";
    else if (character === "\r") source += "\\r";
    else if (character === "\b") source += "\\b";
    else if (character === "\f") source += "\\f";
    else if (code < 0x20) source += `\\u00${code.toString(16).padStart(2, "0")}`;
    else source += character;
  }
  return `${source}\"`;
}

export function serializeYalispData(value) {
  const active = new WeakSet();
  function serializePair(candidate) {
    const entered = [];
    const items = [];
    let tail = candidate;
    try {
      while (isPlainObject(tail) && tail.type === "pair") {
        if (active.has(tail)) throw new TypeError("cannot serialize cyclic YaLisp data");
        active.add(tail);
        entered.push(tail);
        items.push(serialize(tail.car));
        tail = tail.cdr;
      }
      if (Array.isArray(tail)) {
        if (active.has(tail)) throw new TypeError("cannot serialize cyclic YaLisp data");
        active.add(tail);
        entered.push(tail);
        for (const item of tail) items.push(serialize(item));
        tail = null;
      }
      return tail === null
        ? `(${items.join(" ")})`
        : `(${items.join(" ")} . ${serialize(tail)})`;
    } finally {
      for (const valueEntered of entered) active.delete(valueEntered);
    }
  }
  function serialize(candidate) {
    if (candidate === null) return "nil";
    if (candidate === true) return "true";
    if (candidate === false) return "false";
    if (Number.isSafeInteger(candidate)
        && candidate >= FIXNUM_MINIMUM && candidate <= FIXNUM_MAXIMUM) return String(candidate);
    if (typeof candidate === "string") return sourceString(candidate);
    if (isIrSymbol(candidate)) return candidate.name;
    if (Array.isArray(candidate)) {
      if (active.has(candidate)) throw new TypeError("cannot serialize cyclic YaLisp data");
      active.add(candidate);
      const result = `(${candidate.map(serialize).join(" ")})`;
      active.delete(candidate);
      return result;
    }
    if (isPlainObject(candidate) && candidate.type === "pair") {
      return serializePair(candidate);
    }
    throw new TypeError(`value is not portable YaLisp data: ${Object.prototype.toString.call(candidate)}`);
  }
  return serialize(value);
}

export function hashCoreIr(program) {
  return createHash("sha256").update(serializeYalispData(program), "utf8").digest("hex");
}

function normalizedCaps(overrides) {
  if (overrides !== undefined && !isPlainObject(overrides)) {
    throw new TypeError("caps must be a plain object");
  }
  for (const name of Object.keys(overrides ?? {})) {
    if (!Object.hasOwn(CORE_IR_DEFAULT_CAPS, name)) throw new TypeError(`unknown core IR cap: ${name}`);
  }
  const caps = { ...CORE_IR_DEFAULT_CAPS, ...overrides };
  for (const [name, value] of Object.entries(caps)) {
    if (!Number.isSafeInteger(value) || value < 1) {
      throw new TypeError(`${name} must be a positive safe integer`);
    }
  }
  return Object.freeze(caps);
}

function exactLength(value, length) {
  return Array.isArray(value) && value.length === length;
}

function nonnegativeInteger(value) {
  return Number.isSafeInteger(value) && value >= 0 && value <= FIXNUM_MAXIMUM;
}

export function validateCoreIr(program, options = {}) {
  const caps = normalizedCaps(options.caps);
  const context = {
    caps,
    error: null,
    activeNodes: new WeakSet(),
    bindingIds: new Set(),
    metrics: {
      nodesVisited: 0,
      maxDepth: 0,
      sourceSpans: 0,
      sourceOrigins: 0,
      bindings: 0,
      literalNodes: 0,
      literalBytes: 0,
    },
  };

  function reject(code, path, detail) {
    if (!context.error) context.error = { code, path: [...path], detail };
    return false;
  }

  function checkSourcePoint(unit, start, end, path) {
    if (typeof unit !== "string" || encoder.encode(unit).byteLength > caps.maxSourceBytes) {
      return reject("source-unit", [...path, "unit"], "source unit must be a capped string");
    }
    if (!nonnegativeInteger(start) || !nonnegativeInteger(end) || end < start) {
      return reject("source-range", [...path, "range"], "source byte range must satisfy 0 <= start <= end");
    }
    return true;
  }

  function validateSpan(span, path) {
    if (!exactLength(span, 5) || !isIrSymbol(span[0], "src")) {
      return reject("source-map-shape", path, "expected (src unit start end origins)");
    }
    if (!checkSourcePoint(span[1], span[2], span[3], path)) return false;
    if (!Array.isArray(span[4])) {
      return reject("source-origins-shape", [...path, "origins"], "origin stack must be a proper list");
    }
    if (span[4].length > caps.maxOriginsPerSpan) {
      return reject("source-origin-limit", [...path, "origins", caps.maxOriginsPerSpan], caps.maxOriginsPerSpan);
    }
    context.metrics.sourceSpans += 1;
    for (let index = 0; index < span[4].length; index += 1) {
      const origin = span[4][index];
      const originPath = [...path, "origins", index];
      context.metrics.sourceOrigins += 1;
      if (exactLength(origin, 5) && isIrSymbol(origin[0], "macro") && isIrSymbol(origin[1])) {
        if (!checkSourcePoint(origin[2], origin[3], origin[4], originPath)) return false;
      } else if (!(exactLength(origin, 2) && isIrSymbol(origin[0], "generated") && isIrSymbol(origin[1]))) {
        return reject("source-origin-shape", originPath,
          "expected (macro name unit start end) or (generated reason)");
      }
    }
    return true;
  }

  function validateLiteral(value, path, active = new WeakSet()) {
    if (context.metrics.literalNodes >= caps.maxLiteralNodes) {
      return reject("literal-node-limit", path, caps.maxLiteralNodes);
    }
    context.metrics.literalNodes += 1;
    if (value === null || typeof value === "boolean") return true;
    if (typeof value === "string" || isIrSymbol(value)) {
      const bytes = encoder.encode(typeof value === "string" ? value : value.name).byteLength;
      if (context.metrics.literalBytes + bytes > caps.maxLiteralBytes) {
        return reject("literal-byte-limit", path, caps.maxLiteralBytes);
      }
      context.metrics.literalBytes += bytes;
      return true;
    }
    if (Number.isSafeInteger(value) && value >= FIXNUM_MINIMUM && value <= FIXNUM_MAXIMUM) return true;
    if (typeof value === "number") {
      return reject("literal-number", path, "literal integer must fit the signed 30-bit YaLisp range");
    }
    if (Array.isArray(value)) {
      if (active.has(value)) return reject("literal-cycle", path, "literal data must be acyclic");
      active.add(value);
      for (let index = 0; index < value.length; index += 1) {
        if (!validateLiteral(value[index], [...path, index], active)) return false;
      }
      active.delete(value);
      return true;
    }
    if (isPlainObject(value) && value.type === "pair") {
      if (active.has(value)) return reject("literal-cycle", path, "literal data must be acyclic");
      active.add(value);
      if (!validateLiteral(value.car, [...path, "car"], active)
          || !validateLiteral(value.cdr, [...path, "cdr"], active)) return false;
      active.delete(value);
      return true;
    }
    return reject("literal-type", path, "literal is not portable YaLisp data");
  }

  function validateBinding(binding, scope, path) {
    if (!exactLength(binding, 2) || !isIrSymbol(binding[0])) {
      return reject("binding-shape", path, "expected (global symbol) or (local id)");
    }
    if (binding[0].name === "global") {
      return isIrSymbol(binding[1])
        || reject("global-binding-name", [...path, "name"], "global binding name must be a symbol");
    }
    if (binding[0].name === "local") {
      if (!nonnegativeInteger(binding[1])) {
        return reject("local-binding-id", [...path, "id"], "local binding id must be a nonnegative integer");
      }
      return scope.has(binding[1])
        || reject("unbound-local", [...path, "id"], binding[1]);
    }
    return reject("binding-kind", [...path, "kind"], binding[0].name);
  }

  function validateBinder(binder, scope, path) {
    if (!exactLength(binder, 3) || !isIrSymbol(binder[0], "bind")
        || !nonnegativeInteger(binder[1]) || !isIrSymbol(binder[2])) {
      return reject("binder-shape", path, "expected (bind nonnegative-id source-name)");
    }
    if (context.bindingIds.has(binder[1])) {
      return reject("duplicate-binding-id", [...path, "id"], binder[1]);
    }
    context.bindingIds.add(binder[1]);
    context.metrics.bindings += 1;
    scope.add(binder[1]);
    return true;
  }

  function validateNode(node, expectedTail, scope, path, depth) {
    if (Array.isArray(node) && context.activeNodes.has(node)) {
      return reject("node-cycle", path, "IR graphs must be acyclic");
    }
    if (depth > caps.maxDepth) return reject("node-depth-limit", path, caps.maxDepth);
    if (context.metrics.nodesVisited >= caps.maxNodes) return reject("node-count-limit", path, caps.maxNodes);
    context.metrics.nodesVisited += 1;
    context.metrics.maxDepth = Math.max(context.metrics.maxDepth, depth);
    if (!Array.isArray(node) || node.length < 4 || !isIrSymbol(node[0])) {
      return reject("node-shape", path, "node must be a proper list beginning with an opcode");
    }
    context.activeNodes.add(node);
    try {
      if (node[1] !== expectedTail) {
        return reject("tail-position", [...path, "tail"], { expected: expectedTail, actual: node[1] });
      }
      if (!validateSpan(node[2], [...path, "source"])) return false;
      const op = node[0].name;
      if (op === "const") {
        return exactLength(node, 4)
          ? validateLiteral(node[3], [...path, "value"])
          : reject("node-arity", path, { op, expected: 4, actual: node.length });
      }
      if (op === "ref") {
        return exactLength(node, 4)
          ? validateBinding(node[3], scope, [...path, "binding"])
          : reject("node-arity", path, { op, expected: 4, actual: node.length });
      }
      if (op === "set") {
        if (!exactLength(node, 5)) return reject("node-arity", path, { op, expected: 5, actual: node.length });
        return validateBinding(node[3], scope, [...path, "binding"])
          && validateNode(node[4], false, scope, [...path, "value"], depth + 1);
      }
      if (op === "define") {
        if (!exactLength(node, 5)) return reject("node-arity", path, { op, expected: 5, actual: node.length });
        if (!isIrSymbol(node[3])) return reject("define-name", [...path, "name"], "define name must be a symbol");
        return validateNode(node[4], false, scope, [...path, "value"], depth + 1);
      }
      if (op === "if") {
        if (!exactLength(node, 6)) return reject("node-arity", path, { op, expected: 6, actual: node.length });
        return validateNode(node[3], false, scope, [...path, "test"], depth + 1)
          && validateNode(node[4], expectedTail, scope, [...path, "then"], depth + 1)
          && validateNode(node[5], expectedTail, scope, [...path, "else"], depth + 1);
      }
      if (op === "lambda") {
        if (!exactLength(node, 6)) return reject("node-arity", path, { op, expected: 6, actual: node.length });
        if (!Array.isArray(node[3])) return reject("parameter-list", [...path, "parameters"], "parameters must be a proper list");
        const childScope = new Set(scope);
        for (let index = 0; index < node[3].length; index += 1) {
          if (!validateBinder(node[3][index], childScope, [...path, "parameters", index])) return false;
        }
        if (node[4] !== null && !validateBinder(node[4], childScope, [...path, "rest"])) return false;
        return validateNode(node[5], true, childScope, [...path, "body"], depth + 1);
      }
      if (op === "call") {
        if (!exactLength(node, 5)) return reject("node-arity", path, { op, expected: 5, actual: node.length });
        if (!Array.isArray(node[4])) return reject("argument-list", [...path, "arguments"], "arguments must be a proper list");
        if (!validateNode(node[3], false, scope, [...path, "callee"], depth + 1)) return false;
        for (let index = 0; index < node[4].length; index += 1) {
          if (!validateNode(node[4][index], false, scope, [...path, "arguments", index], depth + 1)) return false;
        }
        return true;
      }
      if (op === "begin") {
        if (!exactLength(node, 4)) return reject("node-arity", path, { op, expected: 4, actual: node.length });
        if (!Array.isArray(node[3])) return reject("form-list", [...path, "forms"], "forms must be a proper list");
        for (let index = 0; index < node[3].length; index += 1) {
          const childTail = index === node[3].length - 1 ? expectedTail : false;
          if (!validateNode(node[3][index], childTail, scope, [...path, "forms", index], depth + 1)) return false;
        }
        return true;
      }
      return reject("unknown-opcode", [...path, "opcode"], op);
    } finally {
      context.activeNodes.delete(node);
    }
  }

  if (!exactLength(program, 2) || !isIrSymbol(program[0], CORE_IR_SCHEMA)) {
    reject("program-shape", [], `expected (${CORE_IR_SCHEMA} root)`);
  } else {
    validateNode(program[1], true, new Set(), ["root"], 1);
  }

  const result = context.error
    ? { schema: CORE_IR_SCHEMA, status: "invalid", error: context.error, metrics: context.metrics, caps }
    : { schema: CORE_IR_SCHEMA, status: "valid", error: null, metrics: context.metrics, caps };
  return structuredClone(result);
}
