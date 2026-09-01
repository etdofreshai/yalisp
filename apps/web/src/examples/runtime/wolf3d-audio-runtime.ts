// The audio implementation is mirrored byte-for-byte with the standalone
// Wolf3D YALisp package. It is JavaScript because the same adapter is exercised
// directly by Node fidelity tests in that repository.
// @ts-expect-error The mirrored .mjs intentionally has no TypeScript sidecar.
import { createYalispAudioHost, parseYalispAudioHostEventLog, parseYalispRegisterProgram } from "../wolf3d/yalisp-opl-audio-host.mjs";

export interface Wolf3dAudioSession {
  evaluate(source: string): string;
  evaluateBytes(source: string): Uint8Array;
}

type RegisterProgram = { services: number; registerEvents: number[][] };
type RegisterSink = {
  ok: boolean;
  status: string;
  cursorService: number;
  drain(input: { registerEvents: number[][]; throughService: number }): RenderedAudio;
  close(): boolean;
};
type RenderedAudio = { ok: boolean; status: string; frames?: number; pcm?: Int16Array };
type AudioHost = {
  openRegisterSink(input: { serviceRate: number }): Promise<RegisterSink>;
  renderEvent(input: Record<string, unknown>): Promise<RenderedAudio>;
  play(rendered: RenderedAudio): Promise<{ ok: boolean; status: string }>;
  context?: { close?: () => Promise<void> | void };
};

const requiredExports = [
  "app.advance-audio-timer",
  "app.audio-host-event-export",
  "app.adlib-register-export",
  "app.music-register-export",
  "app.pc-pcm-bytes",
  "app.digitized-pcm-bytes",
];

function hasBinding(session: Wolf3dAudioSession, name: string) {
  return session.evaluate(`(bound? '${name})`) === "true";
}

function requireReady<T extends { ok: boolean; status: string }>(result: T, operation: string): T {
  if (!result.ok) throw new Error(`${operation}: ${result.status}`);
  return result;
}

/**
 * Bridges the source-owned 140 Hz effects and 700 Hz music register clocks to
 * the browser OPL sink. All missing exports, dependencies, malformed programs,
 * and playback failures stop at this boundary instead of becoming silence.
 */
export function createWolf3dAudioRuntime(
  session: Wolf3dAudioSession,
  host: AudioHost = createYalispAudioHost() as AudioHost,
) {
  const exportsAvailable = requiredExports.every((name) => hasBinding(session, name));
  const available = exportsAvailable && session.evaluate("app.runtime-started") === "1";
  let effects: RegisterSink | undefined;
  let music: RegisterSink | undefined;
  let effectsEventCount = 0;
  let musicEventCount = 0;
  let hostEventCount = 0;
  let started = false;
  let closed = false;

  const openSinks = async () => {
    effects = requireReady(await host.openRegisterSink({ serviceRate: 140 }), "Wolf3D AdLib effects unavailable");
    music = requireReady(await host.openRegisterSink({ serviceRate: 700 }), "Wolf3D AdLib music unavailable");
  };

  const play = async (rendered: RenderedAudio, label: string) => {
    requireReady(rendered, label);
    if ((rendered.frames ?? 0) === 0) return;
    requireReady(await host.play(rendered), `${label} playback unavailable`);
  };

  const drainRegisters = async (
    program: RegisterProgram,
    sink: RegisterSink,
    consumed: number,
    label: string,
  ) => {
    if (program.services < sink.cursorService || program.registerEvents.length < consumed) {
      throw new Error(`${label} clock moved backwards`);
    }
    const rendered = sink.drain({
      registerEvents: program.registerEvents.slice(consumed),
      throughService: program.services,
    });
    await play(rendered, label);
    return program.registerEvents.length;
  };

  return {
    available,
    get started() { return started; },
    async start() {
      if (!available) throw new Error(exportsAvailable
        ? "Wolf3D runtime did not start"
        : "Wolf3D audio exports are unavailable");
      if (closed) throw new Error("Wolf3D audio runtime is closed");
      if (started) return;
      await openSinks();
      started = true;
    },
    async advance(tics: number) {
      if (!started || !effects || !music) throw new Error("Wolf3D audio runtime is not started");
      if (!Number.isInteger(tics) || tics <= 0) throw new Error("Wolf3D audio tics must be a positive integer");
      if (session.evaluate(`(app.advance-audio-timer ${tics})`) !== "true") {
        throw new Error("Wolf3D audio timer rejected its tick advance");
      }

      const effectsProgram = parseYalispRegisterProgram(session.evaluate("(app.adlib-register-export)")) as RegisterProgram;
      const musicProgram = parseYalispRegisterProgram(session.evaluate("(app.music-register-export)")) as RegisterProgram;
      effectsEventCount = await drainRegisters(effectsProgram, effects, effectsEventCount, "Wolf3D AdLib effects");
      musicEventCount = await drainRegisters(musicProgram, music, musicEventCount, "Wolf3D AdLib music");

      const events = parseYalispAudioHostEventLog(session.evaluate("(app.audio-host-event-export)")) as Array<Record<string, unknown> & {
        source: number; sound: number;
      }>;
      if (events.length < hostEventCount) throw new Error("Wolf3D audio event log moved backwards");
      for (const event of events.slice(hostEventCount)) {
        if (event.source !== 1 && event.source !== 3) continue;
        const pcm = session.evaluateBytes(event.source === 1
          ? `(app.pc-pcm-bytes ${event.sound})`
          : `(app.digitized-pcm-bytes ${event.sound})`);
        await play(await host.renderEvent({ ...event, pcm }), "Wolf3D native audio");
      }
      hostEventCount = events.length;
    },
    async close() {
      if (closed) return;
      closed = true;
      effects?.close();
      music?.close();
      await host.context?.close?.();
    },
  };
}
