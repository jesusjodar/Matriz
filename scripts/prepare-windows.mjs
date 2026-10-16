import { build } from 'vite'
import { cpSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { readCatalog } from './localization.mjs'

const root = fileURLToPath(new URL('../',import.meta.url))
await build({ configFile:resolve(root,'packages/web/vite.config.mjs') })
const assets=resolve(root,'windows/Matriz/Assets')
mkdirSync(resolve(assets,'Web'),{recursive:true})
cpSync(resolve(root,'packages/web/dist/matriz-background.js'),resolve(assets,'Web/matriz-background.js'))
cpSync(resolve(root,'windows/web/index.html'),resolve(assets,'Web/index.html'))
await build({configFile:false,build:{outDir:resolve(assets,'Web'),emptyOutDir:false,lib:{entry:resolve(root,'windows/web/host.js'),formats:['es'],fileName:()=> 'host.js'}}})
const visual=JSON.parse(readFileSync(resolve(root,'shared/settings.json'),'utf8'))
const native=JSON.parse(readFileSync(resolve(root,'shared/native-settings.json'),'utf8'))
writeFileSync(resolve(assets,'settings.json'),JSON.stringify({...visual,settings:[...visual.settings,...native.settings]}))
cpSync(resolve(root,'integrations'),resolve(assets,'Integrations'),{recursive:true})
const {catalog,languages}=readCatalog(root)
writeFileSync(resolve(assets,'strings.json'),JSON.stringify(Object.fromEntries(languages.map(language => [language,Object.fromEntries(Object.entries(catalog.strings).map(([key,value]) => [key,value.localizations[language].stringUnit.value]))]))))
const version=JSON.parse(readFileSync(resolve(root,'package.json'),'utf8')).version
writeFileSync(resolve(assets,'version.txt'),version)
console.log(`Windows assets ready: ${assets}`)
