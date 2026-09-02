import react from "@vitejs/plugin-react";
import { defineConfig } from "vite";

// Inside docker compose the API is reachable as `api`; running vite natively it
// is on localhost. Everything under /api is proxied, so the browser never makes
// a cross-origin request and you do not have to think about CORS.
const proxyTarget = process.env.VITE_PROXY_TARGET ?? "http://localhost:8000";

export default defineConfig({
  plugins: [react()],
  server: {
    port: 3000,
    // Bind-mounted source on macOS/Windows does not emit inotify events.
    watch: { usePolling: true },
    proxy: {
      "/api": {
        target: proxyTarget,
        changeOrigin: true,
      },
    },
  },
});
