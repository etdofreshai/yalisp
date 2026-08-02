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
        docs: "docs/index.html"
      }
    }
  }
});
