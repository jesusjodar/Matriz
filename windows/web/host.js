import { createMatriz } from '../../packages/web/src/renderer.mjs'
import { manualPalette } from '../../packages/web/src/settings.mjs'
import { toLab, fromLab, mixColor, extractArtwork } from './colors.mjs'

const colors={idle:[.38,.42,.48],running:[.12,.48,.95],permission:[1,.60,.08],input:[.68,.35,.95],error:[.96,.15,.22],completed:[.12,.82,.43]}
const linear=x => x<=.04045 ? x/12.92 : ((x+.055)/1.055)**2.4
const host=window.chrome?.webview
const report=error => host?.postMessage({type:'error',message:String(error?.message ?? error)})
let settings={},bands=[0,0,0,0],audioAt=-Infinity,artwork=null,agent=null,transition=null,ticket=0,paused=false
let renderer
function target() {
  let palette=manualPalette(renderer.settings)
  if (artwork && settings.artworkEnabled) palette=Array.from({length:4},(_,i) => {
    const lab=toLab(artwork[i % Math.min(settings.artworkColors,artwork.length)])
    return fromLab([lab[0],lab[1]*settings.artworkIntensity,lab[2]*settings.artworkIntensity])
  })
  if (agent && settings.agentEnabled) palette=Array.from({length:4},()=>colors[agent].map(linear))
  return palette
}
function paletteAt(now) {
  if(!transition) return target()
  const t=Math.min(1,Math.max(0,(now-transition.start)/transition.duration))
  return transition.from.map((c,i)=>mixColor(c,transition.to[i],t*t*(3-2*t)))
}
function change(change,duration) {
  const now=performance.now(),from=paletteAt(now);change()
  transition=duration>0 && !paused && !matchMedia('(prefers-reduced-motion: reduce)').matches ? {from,to:target(),start:now,duration:duration*1000} : null
  renderer.update({})
}
try {
  renderer=createMatriz(document.querySelector('canvas'),{onError:report,frameInputs:()=>({
    palette:paletteAt(performance.now()),audio:settings.audioEnabled ? bands.map(x=>x*Math.exp(-Math.max(0,performance.now()-audioAt-200)/650)*(settings.audioIntensity ?? 0)) : [0,0,0,0],
  })})
} catch(error) { report(error) }
host?.addEventListener('message',async ({data}) => {
  if(!renderer) return
  try {
    if(data.type==='settings') change(()=>{settings=data.settings;renderer.update(settings)},0)
    if(data.type==='pause' && paused!==data.value) { paused=data.value; if(paused) renderer.pause();else renderer.play() }
    if(data.type==='audio') { bands=data.bands;audioAt=performance.now() }
    if(data.type==='agent' && (data.state===null || Object.hasOwn(colors,data.state)) && agent!==data.state) change(()=>{agent=data.state},.6)
    if(data.type==='artwork') {
      const current=++ticket
      const blob=data.base64 ? new Blob([Uint8Array.from(atob(data.base64),c=>c.charCodeAt(0))],{type:data.mime}) : null
      const palette=blob ? await extractArtwork(blob) : null
      if(current===ticket) change(()=>{artwork=palette},settings.artworkTransition ?? 3)
    }
    if(data.type==='self-test') host.postMessage({type:'self-test',webgl:!!document.querySelector('canvas').getContext('webgl2'),settings:renderer.settings})
  } catch(error) { report(error) }
})
host?.postMessage({type:'ready'})
