import { cpSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs'
import { execFileSync } from 'node:child_process'
import { tmpdir } from 'node:os'
import { resolve, join } from 'node:path'
import { createHash } from 'node:crypto'

const version = JSON.parse(readFileSync('packages/web/package.json')).version
const archive = resolve('build', `Matriz-Web-${version}.zip`)
const staging = mkdtempSync(join(tmpdir(), 'matriz-web-'))
try {
  for (const file of ['dist', 'README.md', 'index.d.ts', 'example.html']) cpSync(join('packages/web', file), join(staging, file), { recursive:true })
  rmSync(archive, { force:true })
  if (process.platform === 'win32') {
    const quote = value => "'" + value.replaceAll("'", "''") + "'"
    execFileSync('powershell.exe', ['-NoProfile', '-NonInteractive', '-Command', `Compress-Archive -Path ${quote(join(staging, '*'))} -DestinationPath ${quote(archive)}`])
  } else execFileSync('zip', ['-qr', archive, '.'], { cwd:staging })
  const sum = createHash('sha256').update(readFileSync(archive)).digest('hex')
  writeFileSync(resolve('build', 'SHA256SUMS-Web'), `${sum}  Matriz-Web-${version}.zip\n`)
  console.log(archive)
} finally { rmSync(staging, { recursive:true, force:true }) }
