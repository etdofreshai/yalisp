# YALisp

A framework-free TypeScript monorepo for the YALisp landing page at
[yalisp.etdofresh.com](https://yalisp.etdofresh.com).

## Workspace layout

- `apps/web` — responsive landing page built with Vite and vanilla TypeScript
- `packages/site-content` — typed, reusable site copy and code examples

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

## Development deployment

The root `Dockerfile` runs the Vite development server on port 5173 with live
reload enabled. Dokploy deploys the `main` branch to `yalisp.etdofresh.com`.
