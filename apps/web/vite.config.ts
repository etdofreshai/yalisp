import { defineConfig, type Plugin } from "vite";

const canonicalPageRoutes = new Set([
  "/repl",
  "/examples",
  "/examples/hello-world",
  "/examples/pong",
  "/examples/breakout",
  "/examples/asteroids",
  "/examples/wolf3d",
  "/code",
  "/docs",
  "/docs/foundation",
  "/docs/compiler",
  "/docs/seed",
  "/docs/bootstrap",
  "/docs/applications",
  "/docs/assembly",
  "/docs/system-interface",
  "/docs/dom",
  "/docs/host",
  "/docs/sdl"
]);

const legacyRouteRedirects = new Map([
  ["/playground", "/repl/"],
  ["/playground/", "/repl/"]
]);

function redirectLegacyRoute(request: { originalUrl?: string; url?: string }, response: { statusCode: number; setHeader(name: string, value: string): void; end(): void }) {
  const url = new URL(request.originalUrl ?? request.url ?? "/", "http://yalisp.local");
  const target = legacyRouteRedirects.get(url.pathname);
  if (!target) return false;
  response.statusCode = 308;
  response.setHeader("Location", `${target}${url.search}${url.hash}`);
  response.end();
  return true;
}

const canonicalRouteRedirects = {
  name: "yalisp-canonical-route-redirects",
  configureServer(server) {
    server.middlewares.use((request, response, next) => {
      if (redirectLegacyRoute(request, response)) return;
      const url = new URL(request.originalUrl ?? "/", "http://yalisp.local");
      if (!canonicalPageRoutes.has(url.pathname)) return next();
      response.statusCode = 308;
      response.setHeader("Location", `${url.pathname}/${url.search}`);
      response.end();
    });
  },
  configurePreviewServer(server) {
    server.middlewares.use((request, response, next) => {
      if (redirectLegacyRoute(request, response)) return;
      const url = new URL(request.originalUrl ?? "/", "http://yalisp.local");
      if (!canonicalPageRoutes.has(url.pathname)) return next();
      response.statusCode = 308;
      response.setHeader("Location", `${url.pathname}/${url.search}`);
      response.end();
    });
  }
} satisfies Plugin;

export default defineConfig({
  plugins: [canonicalRouteRedirects],
  server: {
    host: true,
    allowedHosts: ["yalisp.etdofresh.com"]
  },
  preview: {
    host: true
  },
  build: {
    rollupOptions: {
      input: {
        main: "index.html",
        repl: "repl/index.html",
        examples: "examples/index.html",
        helloWorld: "examples/hello-world/index.html",
        pong: "examples/pong/index.html",
        breakout: "examples/breakout/index.html",
        asteroids: "examples/asteroids/index.html",
        wolf3d: "examples/wolf3d/index.html",
        code: "code/index.html",
        docs: "docs/index.html",
        foundation: "docs/foundation/index.html",
        compiler: "docs/compiler/index.html",
        seed: "docs/seed/index.html",
        bootstrap: "docs/bootstrap/index.html",
        applications: "docs/applications/index.html",
        assembly: "docs/assembly/index.html",
        systemInterface: "docs/system-interface/index.html",
        dom: "docs/dom/index.html",
        legacyHost: "docs/host/index.html",
        sdl: "docs/sdl/index.html"
      }
    }
  }
});
