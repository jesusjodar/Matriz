import { execFileSync } from 'node:child_process'
import { cpSync, existsSync, mkdirSync, readFileSync, renameSync, rmSync, writeFileSync } from 'node:fs'
import { homedir } from 'node:os'
import { dirname, join, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { writeLocalizations } from './localization.mjs'
import { generateMetal } from './metal.mjs'

if (process.platform !== 'darwin') throw new Error('La versión nativa requiere macOS y las herramientas de Xcode.')
const root = resolve(dirname(fileURLToPath(import.meta.url)), '..')
// Compilar fuera de iCloud evita que sus atributos invaliden la firma del bundle.
const output = join(homedir(), 'Library/Application Support/Matriz/Build')
const run = (command, args) => execFileSync(command, args, { stdio: 'inherit', cwd: root })
const version = JSON.parse(readFileSync(join(root, 'package.json'), 'utf8')).version
const buildNumber = '9'
const icons = join(output, 'Icons')
mkdirSync(icons, { recursive: true })
run('xcrun', ['actool', 'macos/Assets/Matriz.icon', '--compile', icons,
  '--platform', 'macosx', '--minimum-deployment-target', '14.0', '--app-icon', 'Matriz',
  '--output-partial-info-plist', join(icons, 'partial.plist'), '--target-device', 'mac'])
const icon = join(icons, 'Matriz.icns')
const source = readFileSync(join(root, 'src/sparkles.frag'), 'utf8')
const metal = generateMetal(source)

function bundle(name, extension, identifier, principalClass) {
  const path = join(output, `${name}.${extension}`)
  mkdirSync(join(path, 'Contents/MacOS'), { recursive: true })
  mkdirSync(join(path, 'Contents/Resources'), { recursive: true })
  writeFileSync(join(path, 'Contents/Resources/Matriz.metal'), metal)
  try {
    const air = join(output, `${extension}.air`)
    const metallib = join(path, 'Contents/Resources/Matriz.metallib')
    rmSync(air, { force: true })
    rmSync(metallib, { force: true })
    run('xcrun', ['-sdk', 'macosx', 'metal', '-mmacosx-version-min=14.0', '-c',
      join(path, 'Contents/Resources/Matriz.metal'), '-o', air])
    run('xcrun', ['-sdk', 'macosx', 'metallib', air, '-o', metallib])
  } catch (error) {
    console.warn(`Aviso: no se pudo precompilar Matriz.metallib (${error.message}); se usará la fuente .metal.`)
  }
  cpSync(join(root, 'integrations'), join(path, 'Contents/Resources/AgentIntegrations'), { recursive: true })
  cpSync(icon, join(path, 'Contents/Resources/Matriz.icns'))
  cpSync(join(icons, 'Assets.car'), join(path, 'Contents/Resources/Assets.car'))
  cpSync(join(root, 'macos/Assets/Author.jpg'), join(path, 'Contents/Resources/Author.jpg'))
  writeLocalizations(root, join(path, 'Contents/Resources'), !principalClass)
  const plist = {
    CFBundleName: name, CFBundleDisplayName: name, CFBundleIdentifier: identifier,
    CFBundleExecutable: name, CFBundlePackageType: extension === 'app' ? 'APPL' : 'BNDL',
    CFBundleShortVersionString: version, CFBundleVersion: buildNumber, LSMinimumSystemVersion: '14.0',
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
const common = ['swiftc', '-swift-version', '5', '-O', '-parse-as-library', '-target', `${process.arch === 'arm64' ? 'arm64' : 'x86_64'}-apple-macos14.0`, 'macos/MatrizSettings.swift', 'macos/MatrizLocalization.swift', 'macos/MatrizSettingsPanel.swift', 'macos/MatrizRenderer.swift', 'macos/MatrizLiveState.swift', 'macos/MatrizAgents.swift', 'macos/MatrizColor.swift', '-framework', 'AppKit', '-framework', 'MetalKit', '-framework', 'ScreenSaver', '-framework', 'SwiftUI']
const audioObject = join(output, 'MatrizAudioBuffer.o')
run('xcrun', ['clang', '-O2', '-std=c11', '-mmacosx-version-min=14.0', '-c', 'macos/MatrizAudioBuffer.c', '-o', audioObject])
const media = ['macos/MatrizAudio.swift', 'macos/MatrizAudioAnalysis.swift', 'macos/MatrizArtwork.swift', 'macos/MatrizMedia.swift',
  '-import-objc-header', 'macos/MatrizAudioBuffer.h', audioObject, '-framework', 'CoreAudio', '-framework', 'Accelerate', '-framework', 'Carbon']
run('xcrun', [...common, ...media, 'macos/MatrizApp.swift', 'macos/MatrizWallpaperSettings.swift', '-module-name', 'Matriz', '-o', join(app, 'Contents/MacOS/Matriz')])
run('xcrun', [...common, 'macos/MatrizSaver.swift', '-framework', 'ScreenSaver', '-module-name', 'MatrizSaver', '-emit-library', '-o', join(saver, 'Contents/MacOS/Matriz')])
const wallpaper = join(app, 'Contents/Extensions/MatrizWallpaper.appex')
mkdirSync(join(wallpaper, 'Contents/MacOS'), { recursive: true })
mkdirSync(join(wallpaper, 'Contents/Resources'), { recursive: true })
cpSync(join(app, 'Contents/Resources/Matriz.metallib'), join(wallpaper, 'Contents/Resources/Matriz.metallib'))
cpSync(join(root, 'macos/ThirdPartyNotices.txt'), join(wallpaper, 'Contents/Resources/ThirdPartyNotices.txt'))
// A shader thumbnail is rendered by the native checker below; the icon is a build-only fallback.
cpSync(join(root, 'macos/Assets/Matriz.icon/Assets/Matriz-Background.png'), join(wallpaper, 'Contents/Resources/Matriz-thumbnail.png'))
writeFileSync(join(wallpaper, 'Contents/Info.plist'), `<?xml version="1.0" encoding="UTF-8"?><!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd"><plist version="1.0"><dict>
<key>CFBundleIdentifier</key><string>com.matriz.wallpaper.extension</string><key>CFBundleExecutable</key><string>MatrizWallpaper</string>
<key>CFBundleName</key><string>Matriz</string><key>CFBundleDisplayName</key><string>Matriz</string><key>CFBundlePackageType</key><string>XPC!</string>
<key>CFBundleVersion</key><string>${buildNumber}</string><key>CFBundleShortVersionString</key><string>${version}</string><key>LSMinimumSystemVersion</key><string>26.0</string>
<key>EXAppExtensionAttributes</key><dict><key>EXExtensionPointIdentifier</key><string>com.apple.wallpaper</string></dict>
</dict></plist>`)
const entitlements = join(output, 'Wallpaper.entitlements')
writeFileSync(entitlements, `<?xml version="1.0"?><plist version="1.0"><dict><key>com.apple.security.app-sandbox</key><true/></dict></plist>`)
run('xcrun', [...common, '-target', `${process.arch === 'arm64' ? 'arm64' : 'x86_64'}-apple-macos26.0`, '-application-extension', '-Xlinker', '-e', '-Xlinker', '_NSExtensionMain', 'macos/Wallpaper/MatrizWallpaper.swift', 'macos/Wallpaper/MatrizWallpaperCatalog.swift',
  '-import-objc-header', 'macos/Wallpaper/MatrizWallpaper.h', '-framework', 'ExtensionFoundation', '-framework', 'IOSurface', '-framework', 'Security',
  '-module-name', 'MatrizWallpaper', '-o', join(wallpaper, 'Contents/MacOS/MatrizWallpaper')])
run('xcrun', [...common, '-D', 'WALLPAPER_CHECK', 'macos/Wallpaper/MatrizWallpaper.swift', 'macos/Wallpaper/MatrizWallpaperCatalog.swift',
  'macos/Wallpaper/MatrizWallpaperCheck.swift', '-import-objc-header', 'macos/Wallpaper/MatrizWallpaper.h',
  '-framework', 'ExtensionFoundation', '-framework', 'IOSurface', '-framework', 'Security',
  '-module-name', 'MatrizWallpaperCheck', '-o', join(output, 'MatrizWallpaperCheck')])
run(join(output, 'MatrizWallpaperCheck'), [wallpaper])
function signBundles() {
  run('codesign', ['--force', '--sign', '-', '--timestamp=none', '--entitlements', entitlements, wallpaper])
  for (const path of [app, saver]) run('codesign', ['--force', '--sign', '-', '--timestamp=none', path])
}
signBundles()

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
  run('xcrun', [...common, ...media, 'macos/MatrizMediaCheck.swift', 'macos/MatrizAgentCheck.swift', 'macos/MatrizCheck.swift', '-module-name', 'MatrizCheck', '-o', join(output, 'MatrizCheck')])
  run(join(output, 'MatrizCheck'), [app, join(output, 'Matriz-preview.png'), saver])
  cpSync(join(output, 'Matriz-preview.png'), join(wallpaper, 'Contents/Resources/Matriz-thumbnail.png'))
  signBundles()
}
console.log(`Listo: ${app}\nSalvapantallas: ${saver}`)
