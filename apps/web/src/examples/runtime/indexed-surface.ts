// Generic browser presentation for Lisp-owned indexed byte surfaces. The
// caller provides dimensions and palette; this module deliberately knows
// nothing about a particular application's resolution, assets, or renderer.

function rgba(color: string) {
  const short = /^#([0-9a-f]{3})$/i.exec(color);
  const full = /^#([0-9a-f]{6})$/i.exec(color);
  const value = short
    ? [...short[1]!].map((part) => `${part}${part}`).join("")
    : full?.[1];
  if (!value) throw new Error("Indexed surface palette colors must be #rgb or #rrggbb values.");
  return [Number.parseInt(value.slice(0, 2), 16), Number.parseInt(value.slice(2, 4), 16), Number.parseInt(value.slice(4, 6), 16), 255] as const;
}

export function expandIndexedSurface(bytes: Uint8Array, width: number, height: number, palette: readonly string[]) {
  if (!Number.isInteger(width) || !Number.isInteger(height) || width <= 0 || height <= 0) throw new Error("Indexed surface dimensions must be positive integers.");
  if (bytes.length !== width * height) throw new Error(`Indexed surface expected ${width * height} bytes, received ${bytes.length}.`);
  const colors = palette.map(rgba);
  const output = new Uint8ClampedArray(bytes.length * 4);
  for (let index = 0; index < bytes.length; index += 1) {
    const color = colors[bytes[index]!];
    if (!color) throw new Error(`Indexed surface pixel ${index} references undeclared palette index ${bytes[index]}.`);
    output.set(color, index * 4);
  }
  return output;
}
