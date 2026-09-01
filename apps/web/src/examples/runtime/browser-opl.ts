// @malvineous/opl's public entrypoint leaves its legacy Emscripten binary at a
// runtime-relative `opl.wasm` URL. Importing the loader and binary explicitly
// lets Vite fingerprint the WASM and gives the loader the exact emitted URL.
// @ts-expect-error The package publishes CommonJS without declarations.
import loadOplModule from "@malvineous/opl/lib/opl.js";
import oplWasmUrl from "@malvineous/opl/lib/opl.wasm?url";
// @ts-expect-error The exact mirrored adapter intentionally has no declarations.
import { createYalispAudioHost } from "../wolf3d/yalisp-opl-audio-host.mjs";
import { loadLegacyOplDevice, type LegacyOplLoader } from "./legacy-opl-loader";

const oplInitializationTimeoutMs = 15_000;

export function createBrowserOpl(sampleRate: number, channels = 2) {
  return loadLegacyOplDevice(loadOplModule as LegacyOplLoader, oplWasmUrl, sampleRate, channels, {
    timeoutMs: oplInitializationTimeoutMs,
  });
}

export function createYalispBrowserAudioHost() {
  return createYalispAudioHost({ createOpl: createBrowserOpl });
}
