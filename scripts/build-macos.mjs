import { execFileSync } from 'node:child_process'
import { cpSync, existsSync, mkdirSync, readFileSync, renameSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { writeLocalizations } from './localization.mjs'

if (process.platform !== 'darwin') throw new Error('La versión nativa requiere macOS y las herramientas de Xcode.')
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
// Compilar fuera de iCloud evita que sus atributos invaliden la firma del bundle.
const output = join(homedir(), 'Library/Application Support/Matriz/Build')
const run = (command, args) => execFileSync(command, args, { stdio: 'inherit', cwd: root })
const icons = join(output, 'Icons')
mkdirSync(icons, { recursive: true })
run('xcrun', ['actool', 'macos/Assets/Matriz.icon', '--compile', icons,
  '--platform', 'macosx', '--minimum-deployment-target', '14.0', '--app-icon', 'Matriz',
  '--output-partial-info-plist', join(icons, 'partial.plist'), '--target-device', 'mac'])
const icon = join(icons, 'Matriz.icns')
const source = readFileSync(join(root, 'src/sparkles.frag'), 'utf8')
const uniforms = [...source.matchAll(/^uniform (vec[234]|float) (u\w+);$/gm)]
const metalType = type => type.replace('vec', 'float')
const field = name => name[1].toLowerCase() + name.slice(2)
// Las ecuaciones se generan desde el GLSL para mantener una única fuente visual.
const metal = `#include <metal_stdlib>
using namespace metal;
struct Uniforms { ${uniforms.map(([, type, name]) => `${metalType(type)} ${field(name)};`).join(' ')} };
struct VertexOut { float4 position [[position]]; };
vertex VertexOut matrizVertex(uint id [[vertex_id]]) {
    const float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0)};
    return {float4(positions[id], 0.0, 1.0)};
}
` + source
  .replace(/^#version.*\n|^precision.*\n|^uniform.*\n|^out vec4.*\n/gm, '')
  .replace(/^const float /gm, 'constant float ')
  .replace(/\bvec([234])\b/g, 'float$1')
  .replace(/\bdFdx\b/g, 'dfdx').replace(/\bdFdy\b/g, 'dfdy')
  .replace('void main() {', `fragment float4 matrizFragment(VertexOut in [[stage_in]], constant Uniforms& uniforms [[buffer(0)]]) {
    ${uniforms.map(([, type, name]) => `${metalType(type)} ${name} = uniforms.${field(name)};`).join('\n    ')}
    float4 gl_FragCoord = float4(in.position.x, uResolution.y - in.position.y, 0.0, 1.0);`)
  .replace('outColor = ', 'return ')

function bundle(name, extension, identifier, principalClass) {
  const path = join(output, `${name}.${extension}`)
  mkdirSync(join(path, 'Contents/MacOS'), { recursive: true })
  mkdirSync(join(path, 'Contents/Resources'), { recursive: true })
  writeFileSync(join(path, 'Contents/Resources/Matriz.metal'), metal)
  cpSync(icon, join(path, 'Contents/Resources/Matriz.icns'))
  cpSync(join(icons, 'Assets.car'), join(path, 'Contents/Resources/Assets.car'))
  cpSync(join(root, 'macos/Assets/Author.jpg'), join(path, 'Contents/Resources/Author.jpg'))
  writeLocalizations(root, join(path, 'Contents/Resources'), !principalClass)
  const plist = {
    CFBundleName: name, CFBundleDisplayName: name, CFBundleIdentifier: identifier,
    CFBundleExecutable: name, CFBundlePackageType: extension === 'app' ? 'APPL' : 'BNDL',
    CFBundleShortVersionString: '2.0.0', CFBundleVersion: '7', LSMinimumSystemVersion: '14.0',
    CFBundleIconFile: 'Matriz.icns', CFBundleIconName: 'Matriz', CFBundleDevelopmentRegion: 'en',
    NSHighResolutionCapable: true,
    ...(principalClass ? { NSPrincipalClass: principalClass } : {
      LSUIElement: true,
      NSAudioCaptureUsageDescription: 'Matriz analiza el sonido de la salida del Mac para animar el fondo. El audio no se guarda ni se envía.',
      NSAppleEventsUsageDescription: 'Matriz consulta la canción y la portada de Música o Spotify para adaptar los colores del fondo.',
    }),
  }
  writeFileSync(join(path, 'Contents/Info.plist'), `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>${Object.entries(plist).map(([key, value]) => `<key>${key}</key>${typeof value === 'boolean' ? `<${value}/>` : `<string>${value}</string>`}`).join('')}</dict></plist>`)
  return path
}

const app = bundle('Matriz', 'app', 'com.matriz.wallpaper')
const saver = bundle('Matriz', 'saver', 'com.matriz.screensaver', 'MatrizSaverView')
const common = ['swiftc', '-swift-version', '5', '-O', '-parse-as-library', '-target', `${process.arch === 'arm64' ? 'arm64' : 'x86_64'}-apple-macos14.0`, 'macos/MatrizSettings.swift', 'macos/MatrizLocalization.swift', 'macos/MatrizSettingsPanel.swift', 'macos/MatrizRenderer.swift', 'macos/MatrizLiveState.swift', 'macos/MatrizColor.swift', '-framework', 'AppKit', '-framework', 'MetalKit', '-framework', 'ScreenSaver', '-framework', 'SwiftUI']
const audioObject = join(output, 'MatrizAudioBuffer.o')
run('xcrun', ['clang', '-O2', '-std=c11', '-mmacosx-version-min=14.0', '-c', 'macos/MatrizAudioBuffer.c', '-o', audioObject])
const media = ['macos/MatrizAudio.swift', 'macos/MatrizAudioAnalysis.swift', 'macos/MatrizArtwork.swift', 'macos/MatrizMedia.swift',
  '-import-objc-header', 'macos/MatrizAudioBuffer.h', audioObject, '-framework', 'CoreAudio', '-framework', 'Accelerate', '-framework', 'Carbon']
run('xcrun', [...common, ...media, 'macos/MatrizApp.swift', '-module-name', 'Matriz', '-o', join(app, 'Contents/MacOS/Matriz')])
run('xcrun', [...common, 'macos/MatrizSaver.swift', '-framework', 'ScreenSaver', '-module-name', 'MatrizSaver', '-emit-library', '-o', join(saver, 'Contents/MacOS/Matriz')])
for (const path of [app, saver]) run('codesign', ['--force', '--sign', '-', '--timestamp=none', path])

if (process.argv.includes('--install')) {
  const backup = join(homedir(), 'Library/Application Support/Matriz/Backups', `install-${new Date().toISOString().replace(/[:.]/g, '-')}`)
  for (const [source, folder, extension] of [[app, 'Applications', 'app'], [saver, 'Library/Screen Savers', 'saver']]) {
    const destination = join(homedir(), folder, `Matriz.${extension}`)
    mkdirSync(dirname(destination), { recursive: true })
    for (const name of ['Matriz']) {
      const previous = join(homedir(), folder, `${name}.${extension}`)
      if (existsSync(previous)) {
        mkdirSync(backup, { recursive: true })
        renameSync(previous, join(backup, `${name}.${extension}`))
      }
    }
    cpSync(source, destination, { recursive: true })
    console.log(`Instalado: ${destination}`)
  }
}

if (process.argv.includes('--check')) {
  run('xcrun', [...common, ...media, 'macos/MatrizMediaCheck.swift', 'macos/MatrizCheck.swift', '-module-name', 'MatrizCheck', '-o', join(output, 'MatrizCheck')])
  run(join(output, 'MatrizCheck'), [app, join(output, 'Matriz-preview.png'), saver])
}
console.log(`Listo: ${app}\nSalvapantallas: ${saver}`)
