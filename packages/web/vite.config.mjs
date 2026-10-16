import { defineConfig } from 'vite'
import { fileURLToPath } from 'node:url'
export default defineConfig({
  build: {
    outDir:fileURLToPath(new URL('./dist',import.meta.url)),emptyOutDir:true,
    lib:{entry:fileURLToPath(new URL('./src/index.mjs',import.meta.url)),name:'Matriz',formats:['es','umd'],fileName:format => format === 'es' ? 'matriz-background.js' : 'matriz-background.umd.cjs'},
  },
})
