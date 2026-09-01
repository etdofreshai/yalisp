export type LegacyOplModule = {
  OPL: new (sampleRate: number, channels: number, bufferBytes: number) => {
    generate(frames: number): void;
    getBuffer(): Int16Array;
    write(register: number, value: number): void;
  };
};

export type LegacyOplLoader = (options: {
  locateFile(path: string): string;
  onAbort(reason: unknown): void;
}) => {
  // Emscripten's legacy Module returns itself from `then`. It must be consumed
  // by callback rather than await/Promise.resolve, which would recursively
  // assimilate the same thenable and never settle.
  then(
    callback: (module: LegacyOplModule) => void,
    rejection?: (reason: unknown) => void,
  ): unknown;
};

export type LegacyOplLoadOptions = {
  timeoutMs?: number;
};

type LegacyOplDevice = {
  write(register: number, value: number): void;
  generate(frames: number, Format?: typeof Int16Array): Int16Array;
};

function detail(reason: unknown) {
  if (reason instanceof Error) return reason.message;
  if (typeof reason === "string") return reason;
  try { return JSON.stringify(reason); }
  catch { return String(reason); }
}

export function loadLegacyOplDevice(
  loader: LegacyOplLoader,
  wasmUrl: string,
  sampleRate: number,
  channels = 2,
  { timeoutMs = 15_000 }: LegacyOplLoadOptions = {},
): Promise<LegacyOplDevice> {
  if (!Number.isFinite(timeoutMs) || timeoutMs <= 0) {
    return Promise.reject(new Error("OPL WebAssembly initialization timeout must be greater than zero."));
  }
  return new Promise<LegacyOplDevice>((resolve, reject) => {
    let settled = false;
    let timeout: ReturnType<typeof setTimeout> | undefined;
    const fail = (error: Error) => {
      if (settled) return;
      settled = true;
      if (timeout !== undefined) clearTimeout(timeout);
      reject(error);
    };
    const succeed = (device: LegacyOplDevice) => {
      if (settled) return;
      settled = true;
      if (timeout !== undefined) clearTimeout(timeout);
      resolve(device);
    };

    timeout = setTimeout(() => {
      fail(new Error(`OPL WebAssembly initialization timed out after ${timeoutMs} ms.`));
    }, timeoutMs);
    try {
      const loading = loader({
        locateFile(path: string) { return path.endsWith(".wasm") ? wasmUrl : path; },
        onAbort(reason: unknown) {
          fail(new Error(`OPL WebAssembly initialization aborted: ${detail(reason)}`));
        },
      });
      loading.then((module) => {
        if (settled) return;
        try {
          const framesPerBlock = 512;
          const device = new module.OPL(sampleRate, channels, framesPerBlock * channels * Int16Array.BYTES_PER_ELEMENT);
          const buffer = device.getBuffer();
          // Resolve a plain wrapper, never the thenable Emscripten Module.
          succeed({
            write(register: number, value: number) { device.write(register, value); },
            generate(frames: number, Format: typeof Int16Array = Int16Array) {
              device.generate(frames);
              return new Format(buffer.buffer, buffer.byteOffset, frames * channels);
            },
          });
        } catch (error) {
          fail(error instanceof Error ? error : new Error(`OPL device construction failed: ${detail(error)}`));
        }
      }, (reason) => {
        fail(new Error(`OPL WebAssembly initialization rejected: ${detail(reason)}`));
      });
    } catch (error) {
      fail(error instanceof Error ? error : new Error(`OPL WebAssembly initialization failed: ${detail(error)}`));
    }
  });
}
