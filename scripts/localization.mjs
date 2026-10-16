import { mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { join } from 'node:path'

export function readCatalog(root) {
  const catalog = JSON.parse(readFileSync(join(root, 'macos/Localizable.xcstrings'), 'utf8'))
  const languages = Object.keys(catalog.strings.About.localizations)
  for (const [key, entry] of Object.entries(catalog.strings)) {
    for (const language of languages) {
      const value = entry.localizations[language]?.stringUnit?.value
      if (typeof value !== 'string' || !value.trim()) throw new Error(`Missing ${language}: ${key}`)
      const placeholders = value.match(/%[@d]/g) ?? []
      if (JSON.stringify(placeholders.sort()) !== JSON.stringify((key.match(/%[@d]/g) ?? []).sort())) {
        throw new Error(`Invalid format in ${language}: ${key}`)
      }
    }
  }
  return { catalog, languages }
}

export function writeLocalizations(root, resources, permissions) {
  const { catalog, languages } = readCatalog(root)
  const line = (key, value) => `${JSON.stringify(key)} = ${JSON.stringify(value)};`
  for (const language of languages) {
    const folder = join(resources, `${language}.lproj`)
    mkdirSync(folder, { recursive: true })
    const value = key => catalog.strings[key].localizations[language].stringUnit.value
    writeFileSync(join(folder, 'Localizable.strings'), Object.keys(catalog.strings).map(key => line(key, value(key))).join('\n') + '\n')
    if (permissions) {
      writeFileSync(join(folder, 'InfoPlist.strings'), [
        line('NSAudioCaptureUsageDescription', value('Matriz analyzes Mac audio locally. Audio is never saved or sent.')),
        line('NSAppleEventsUsageDescription', value('Matriz reads the current song and artwork from Music or Spotify to change the background colors.')),
      ].join('\n') + '\n')
    }
  }
}
