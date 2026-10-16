import { execFileSync } from 'node:child_process'
import { mkdtempSync,readFileSync,writeFileSync,rmSync } from 'node:fs'
import { tmpdir } from 'node:os'
import { join } from 'node:path'
import { generateMetal } from './metal.mjs'
const folder=mkdtempSync(join(tmpdir(),'matriz-metal-'))
try {
  const source=join(folder,'Matriz.metal');writeFileSync(source,generateMetal(readFileSync(new URL('../src/sparkles.frag',import.meta.url),'utf8')))
  execFileSync('xcrun',['-sdk','macosx','metal','-c',source,'-o',join(folder,'Matriz.air')],{stdio:'inherit'})
} finally { rmSync(folder,{recursive:true,force:true}) }
