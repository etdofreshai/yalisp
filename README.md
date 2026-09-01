# YALisp

A small WAT/Lisp bootstrap runtime and framework-free TypeScript site for YALisp at
[yalisp.etdofresh.com](https://yalisp.etdofresh.com).

## Workspace layout

- `apps/web` — responsive landing page, documentation, and executable
  `/playground/` built with Vite and vanilla TypeScript
- `packages/site-content` — typed, reusable site copy and code examples

The Playground assembles `apps/web/src/seed/bootstrap.wat` into WebAssembly and
loads the checked-in `apps/web/public/yalisp/boot.lisp` bootstrap. It currently
exposes the interpreter only; JIT and AOT remain explicitly unavailable.

## Local development

```bash
npm install
npm run dev
```

The development server binds to `0.0.0.0` and prints both local and LAN URLs.

## Checks

```bash
npm run typecheck
npm test
npm run build
```

## Hardening evidence

The normative semantics, staged bootstrap map, sequential roadmap,
deterministic harness, and living scorecard are under `docs/hardening/`. The
current partial M2 evidence is frozen in the reader/printer and macro-expansion
baselines under `docs/hardening/baselines/`.

## Development deployment

The root `Dockerfile` runs the Vite development server on port 5173 with live
reload enabled. Dokploy deploys the `main` branch to `yalisp.etdofresh.com`.
