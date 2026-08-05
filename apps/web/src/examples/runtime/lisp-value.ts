// Reading and printing the seed evaluator's textual values. This module is
// deliberately free of DOM and seed imports so the same helpers can run in a
// browser host, in a Node test, or in a benchmark harness.

export type LispValue = number | string | LispValue[];
export type LispList = LispValue[];

export function isList(value: LispValue): value is LispList {
  return Array.isArray(value);
}

export function atomText(value: LispValue) {
  return typeof value === "number" ? String(value) : value;
}

export function displayText(value: string) {
  return value.replaceAll("-", " ").replace(/(^|\s)\S/g, (character) => character.toUpperCase());
}

function tokenize(source: string) {
  const tokens: string[] = [];
  let index = 0;
  while (index < source.length) {
    const character = source[index]!;
    if (/\s/.test(character)) { index += 1; continue; }
    if (character === "(" || character === ")") { tokens.push(character); index += 1; continue; }
    if (character === '"') {
      let value = '"';
      index += 1;
      while (index < source.length) {
        const next = source[index]!;
        value += next;
        index += 1;
        if (next === "\\") {
          if (index < source.length) { value += source[index]!; index += 1; }
        } else if (next === '"') break;
      }
      tokens.push(value);
      continue;
    }
    let value = "";
    while (index < source.length && !/[\s()]/.test(source[index]!)) { value += source[index]!; index += 1; }
    tokens.push(value);
  }
  return tokens;
}

export function parseLispValue(source: string): LispValue {
  const tokens = tokenize(source);
  let index = 0;
  const read = (): LispValue => {
    const token = tokens[index++];
    if (token === undefined) throw new Error("The Lisp application returned an incomplete command list.");
    if (token === "(") {
      const values: LispValue[] = [];
      while (tokens[index] !== ")") {
        if (tokens[index] === undefined) throw new Error("The Lisp application returned an unterminated command list.");
        values.push(read());
      }
      index += 1;
      return values;
    }
    if (token === ")") throw new Error("The Lisp application returned an unexpected closing parenthesis.");
    if (token.startsWith('"')) return JSON.parse(token);
    const number = Number(token);
    return Number.isFinite(number) && token !== "" ? number : token;
  };
  const result = read();
  if (index !== tokens.length) throw new Error("The Lisp application returned more than one value.");
  return result;
}

export function printLispValue(value: LispValue): string {
  if (Array.isArray(value)) return `(${value.map(printLispValue).join(" ")})`;
  if (typeof value === "number") return String(value);
  return /^[^\s()";]+$/.test(value) ? value : JSON.stringify(value);
}

export function listAt(list: LispList, index: number) {
  return list[index];
}

export function numberAt(list: LispList, index: number, label: string) {
  const value = listAt(list, index);
  if (typeof value !== "number") throw new Error(`The Lisp application's ${label} must be a number.`);
  return value;
}

export function textAt(list: LispList, index: number, label: string) {
  const value = listAt(list, index);
  if (typeof value !== "string") throw new Error(`The Lisp application's ${label} must be a symbol or string.`);
  return value;
}

export function directives(value: LispValue) {
  if (!isList(value)) throw new Error("The Lisp application must return a directive list.");
  return value.filter(isList);
}

export function directive(values: LispList[], name: string) {
  return values.find((value) => atomText(value[0] ?? "") === name);
}
