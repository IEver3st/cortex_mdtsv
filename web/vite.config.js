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
  },
  server: {
    port: 3000,
  },
});
