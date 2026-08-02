import { defineConfig } from "vite";

export default defineConfig({
  server: {
    host: true
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
