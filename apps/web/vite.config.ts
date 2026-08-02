import { defineConfig } from "vite";

export default defineConfig({
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
