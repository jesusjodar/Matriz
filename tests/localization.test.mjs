import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync, readdirSync, mkdtempSync, rmSync } from 'node:fs'
import { join, resolve } from 'node:path'
import { tmpdir } from 'node:os'
import { readCatalog, writeLocalizations } from '../scripts/localization.mjs'

const root = resolve(import.meta.dirname, '..')

test('all visible settings and service strings are translated in 20 locales', () => {
  const { catalog, languages } = readCatalog(root)
  assert.equal(languages.length, 20)
  assert.equal(catalog.strings['Made with ❤️ in Spain 🇪🇸'].localizations.es.stringUnit.value, 'Hecho con ❤️ desde España 🇪🇸')
  const keys = new Set()
  for (const file of readdirSync(join(root, 'macos')).filter(name => name.endsWith('.swift'))) {
    const source = readFileSync(join(root, 'macos', file), 'utf8')
    for (const pattern of [/\bLF?\("([^"\\]*)"/g, /\b(?:label|caption|group|slider|toggle)\("([^"\\]*)"/g,
      /\bdetail: "([^"\\]*)"/g, /\bgroup\("[^"]*", "[^"]*", "([^"]*)"/g]) {
      for (const match of source.matchAll(pattern)) keys.add(match[1])
    }
  }
  for (const key of keys) assert.ok(catalog.strings[key], `Not in catalog: ${key}`)
  for (const language of languages) {
    const units = Object.entries(catalog.strings).filter(([key]) => key.length > 45)
    if (language !== 'en') {
      assert.ok(units.every(([key, entry]) => entry.localizations[language].stringUnit.value !== key), `English description in ${language}`)
    }
  }
})

test('native app and saver get their own strings; capture prompts belong only to the app', () => {
  const folder = mkdtempSync(join(tmpdir(), 'matriz-localization-'))
  try {
    writeLocalizations(root, join(folder, 'app'), true)
    writeLocalizations(root, join(folder, 'saver'), false)
    assert.equal(readdirSync(join(folder, 'app')).length, 20)
    assert.ok(readFileSync(join(folder, 'app/es.lproj/Localizable.strings'), 'utf8').includes('"About" = "Acerca de";'))
    assert.ok(readFileSync(join(folder, 'app/es.lproj/InfoPlist.strings'), 'utf8').includes('NSAudioCaptureUsageDescription'))
    assert.deepEqual(readdirSync(join(folder, 'saver/ar.lproj')), ['Localizable.strings'])
  } finally { rmSync(folder, { recursive: true, force: true }) }
})
