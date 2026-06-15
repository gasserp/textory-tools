import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

// https://vite.dev/config/
export default defineConfig({
  plugins: [svelte()],
  // Work around an esbuild >=0.27.7 regression where destructuring transforms
  // are incorrectly reported as unsupported for the default build targets.
  // https://github.com/evanw/esbuild/issues/4436
  esbuild: {
    supported: {
      destructuring: true,
    },
  },
})
