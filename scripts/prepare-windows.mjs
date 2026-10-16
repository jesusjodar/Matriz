import { build } from 'vite'
import { cpSync, mkdirSync, readFileSync, writeFileSync } from 'node:fs'
import { resolve } from 'node:path'
import { fileURLToPath } from 'node:url'
import { readCatalog } from './localization.mjs'

const root = fileURLToPath(new URL('../',import.meta.url))
const assets=resolve(root,'windows/Matriz/Assets')
mkdirSync(resolve(assets,'Web'),{recursive:true})
cpSync(resolve(root,'windows/web/index.html'),resolve(assets,'Web/index.html'))
await build({configFile:false,build:{outDir:resolve(assets,'Web'),emptyOutDir:false,lib:{entry:resolve(root,'windows/web/host.js'),formats:['es'],fileName:()=> 'host.js'}}})
const visual=JSON.parse(readFileSync(resolve(root,'shared/settings.json'),'utf8'))
const native=JSON.parse(readFileSync(resolve(root,'shared/native-settings.json'),'utf8'))
writeFileSync(resolve(assets,'settings.json'),JSON.stringify({...visual,settings:[...visual.settings,...native.settings]}))
cpSync(resolve(root,'integrations'),resolve(assets,'Integrations'),{recursive:true})
const {catalog,languages}=readCatalog(root)
const audioLabels={en:'React to system audio',es:'Reacción al audio del sistema',fr:'Réagir au son du système',de:'Auf Systemaudio reagieren',it:'Reagisci all’audio di sistema',pt:'Reagir ao áudio do sistema',ca:'Reacció a l’àudio del sistema',nl:'Reageren op systeemaudio',ru:'Реакция на системный звук',uk:'Реакція на системний звук',ja:'システムオーディオに反応',ko:'시스템 오디오에 반응','zh-Hans':'响应系统音频','zh-Hant':'回應系統音訊',ar:'التفاعل مع صوت النظام',he:'תגובה לשמע המערכת',pl:'Reaguj na dźwięk systemowy',tr:'Sistem sesine tepki ver',sv:'Reagera på systemljud',hi:'सिस्टम ऑडियो पर प्रतिक्रिया'}
writeFileSync(resolve(assets,'strings.json'),JSON.stringify(Object.fromEntries(languages.map(language => [language,{
  ...Object.fromEntries(Object.entries(catalog.strings).map(([key,value]) => [key,value.localizations[language].stringUnit.value])),
  'React to Mac audio':audioLabels[language],
}]))))
const version=JSON.parse(readFileSync(resolve(root,'package.json'),'utf8')).version
writeFileSync(resolve(assets,'version.txt'),version)
console.log(`Windows assets ready: ${assets}`)
