import { defineConfig, type Plugin } from "vite";

const canonicalPageRoutes = new Set([
  "/playground",
  "/examples",
  "/examples/hello-world",
  "/examples/pong",
  "/examples/breakout",
  "/examples/asteroids",
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

const canonicalRouteRedirects = {
  name: "yalisp-canonical-route-redirects",
  configureServer(server) {
    server.middlewares.use((request, response, next) => {
      const url = new URL(request.originalUrl ?? "/", "http://yalisp.local");
      if (!canonicalPageRoutes.has(url.pathname)) return next();
      response.statusCode = 308;
      response.setHeader("Location", `${url.pathname}/${url.search}`);
      response.end();
    });
  },
  configurePreviewServer(server) {
    server.middlewares.use((request, response, next) => {
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
        playground: "playground/index.html",
        examples: "examples/index.html",
        helloWorld: "examples/hello-world/index.html",
        pong: "examples/pong/index.html",
        breakout: "examples/breakout/index.html",
        asteroids: "examples/asteroids/index.html",
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
