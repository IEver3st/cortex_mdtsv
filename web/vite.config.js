import { defineConfig } from 'vite';
import { svelte } from '@sveltejs/vite-plugin-svelte';

export default defineConfig({
  plugins: [svelte()],
  base: './',
  optimizeDeps: {
    exclude: ['@lucide/svelte'],
  },
  build: {
    outDir: '../html',
    emptyOutDir: true,
    minify: 'esbuild',
    assetsInlineLimit: 8192,
    rollupOptions: {
      output: {
        manualChunks(id) {
          const normalized = id.replaceAll('\\\\', '/');

          if (normalized.includes('/node_modules/svelte/')) return 'vendor-svelte';
          if (normalized.includes('/node_modules/@lucide/svelte/')) return 'vendor-icons';
          if (normalized.includes('/node_modules/leaflet/')) return 'vendor-map';

          const page = normalized.match(/\/src\/pages\/([^/]+)\.svelte$/);
          if (page) return `page-${page[1].toLowerCase()}`;

          return undefined;
        },
      },
    },
  },
  server: {
    port: 3000,
  },
});
