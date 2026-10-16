import { mkdtempSync, readFileSync, writeFileSync, rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join, resolve } from 'node:path'
import { execFileSync } from 'node:child_process'
import { createRequire } from 'node:module'
import { pathToFileURL } from 'node:url'
import assert from 'node:assert/strict'

const version = JSON.parse(readFileSync('packages/web/package.json')).version
const folder = mkdtempSync(join(tmpdir(), 'matriz-consumer-'))
try {
  assert.ok(process.env.npm_execpath, 'Run this check through npm run web:pack')
  execFileSync(process.execPath, [process.env.npm_execpath, 'install', '--offline', '--prefix', folder, '--ignore-scripts', '--package-lock=false', '--no-audit', '--no-fund', resolve(`build/matriz-background-${version}.tgz`)], { stdio:'pipe' })
  const entry = join(folder, 'node_modules/@matriz/background')
  const es = await import(pathToFileURL(join(entry, 'dist/matriz-background.js')))
  const umd = createRequire(import.meta.url)(join(entry, 'dist/matriz-background.umd.cjs'))
  const keys = ['MatrizBackground', 'createMatriz', 'defaultSettings', 'sanitizeSettings', 'settingsSchema'].sort()
  assert.deepEqual(Object.keys(es).sort(), keys)
  assert.deepEqual(Object.keys(umd).sort(), keys)
  writeFileSync(join(folder, 'consumer.mts'), `import {createMatriz, MatrizBackground} from '@matriz/background';
const bg = createMatriz(document.createElement('canvas'), {settings:{speed:1,customDeep:[0,.2,1]}});
bg.update({colorBlur:.7});
new MatrizBackground().settings = {hue:42};
// @ts-expect-error Music is not a public API
bg.setAudio([1,1,1,1]);
// @ts-expect-error Agent states are not configurable on web
bg.update({agentEnabled:true});
`)
  execFileSync(process.execPath, [resolve('node_modules/typescript/bin/tsc'), '--ignoreConfig', '--noEmit', '--strict', '--module', 'nodenext', '--target', 'es2023', join(folder, 'consumer.mts')], { stdio:'inherit' })
  console.log('Installed web package: ESM, CommonJS, SSR import and TypeScript consumer passed')
} finally { rmSync(folder, { recursive:true, force:true }) }
