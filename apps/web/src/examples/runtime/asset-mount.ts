// Generic asset mounting for YALISP applications.
//
// A program that reads original data files needs those bytes inside the
// evaluator before it can say anything about them. This module is the whole
// of what the host does about that: it reads a list of names and paths the
// program itself declared, retrieves each path as bytes, reserves exactly
// enough asset capacity for them, hands them over, and reports the handles
// back in the same order.
//
// It does not know what a path holds, in what format, or whether the bytes it
// moved are valid. There is no parsing, no length check against an expected
// size, and no fallback content. Everything above "these bytes now have this
// handle" belongs to the Lisp program.
//
// The explicit extension keeps this loadable by Node's type stripping, so a
// test can mount from the filesystem through the same code the browser uses
// over the network.
import { isList, parseLispValue, printLispValue, textAt, type LispValue } from "./lisp-value.ts";

export interface AssetSession {
  evaluate(source: string): string;
  ingestBytes(bytes: Uint8Array): number;
}

export interface AssetRequest {
  name: string;
  path: string;
}

export interface MountedAsset extends AssetRequest {
  handle: number;
  length: number;
}

export interface AssetMountResult {
  mounted: MountedAsset[];
  failed: Array<AssetRequest & { reason: string }>;
}

/** Bytes for a declared path. A browser passes fetch; a test passes readFile. */
export type AssetFetcher = (path: string) => Promise<Uint8Array>;

// The declaration a program returns from (app.assets):
//
//   (assets (maphead "/assets/wolf3d/MAPHEAD.WL6")
//           (gamemaps "/assets/wolf3d/GAMEMAPS.WL6"))
//
// The path is written in the program, not assembled here, so the host never
// holds a name belonging to any particular application.
export function assetRequests(value: LispValue): AssetRequest[] {
  if (!isList(value) || textAt(value, 0, "assets tag") !== "assets") {
    throw new Error("A Lisp application's asset declaration must be an (assets ...) form.");
  }
  return value.slice(1).map((entry) => {
    if (!isList(entry)) throw new Error("A declared asset must be a (name path) list.");
    return { name: textAt(entry, 0, "asset name"), path: textAt(entry, 1, "asset path") };
  });
}

// Retrieval is attempted for every request, and a failure is reported rather
// than thrown: whether a program can run without one of its assets is the
// program's own question, and a host that decided it here would be deciding
// something about the application.
export async function mountAssets(session: AssetSession, requests: AssetRequest[], fetchBytes: AssetFetcher): Promise<AssetMountResult> {
  const retrieved: Array<AssetRequest & { bytes: Uint8Array }> = [];
  const failed: AssetMountResult["failed"] = [];
  for (const request of requests) {
    try {
      retrieved.push({ ...request, bytes: await fetchBytes(request.path) });
    } catch (error) {
      failed.push({ ...request, reason: error instanceof Error ? error.message : String(error) });
    }
  }
  // Capacity is asked for once, for the total, before anything is handed over.
  // Reserving per asset would let a later one fail after earlier ones had
  // already been committed, leaving the program half-mounted.
  const total = retrieved.reduce((sum, asset) => sum + asset.bytes.length, 0);
  if (total) session.evaluate(`(asset.reserve ${total})`);
  const mounted = retrieved.map((asset) => ({
    name: asset.name,
    path: asset.path,
    handle: session.ingestBytes(asset.bytes),
    length: asset.bytes.length
  }));
  return { mounted, failed };
}

// What the program is told afterwards: for each asset it got, the handle it
// is known by and how many bytes are under it. An asset that could not be
// retrieved is simply absent, so a program tests for what it has rather than
// being handed a placeholder.
export function mountedForm(mounted: MountedAsset[]) {
  return printLispValue(mounted.map((asset) => [asset.name, asset.handle, asset.length]));
}

// The whole exchange, for hosts that have no reason to do it in pieces.
export async function mountDeclaredAssets(session: AssetSession, fetchBytes: AssetFetcher) {
  if (session.evaluate("(bound? 'app.assets)") !== "true") return { mounted: [], failed: [] };
  const requests = assetRequests(parseLispValue(session.evaluate("(app.assets)")));
  const result = await mountAssets(session, requests, fetchBytes);
  // The program is told what it got even when that is nothing, so "no assets
  // were mounted" is a state it is handed rather than one it has to infer
  // from never having been called.
  session.evaluate(`(app.assets-mounted '${mountedForm(result.mounted)})`);
  return result;
}
