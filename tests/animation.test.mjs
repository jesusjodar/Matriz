import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { runInNewContext } from 'node:vm'
import { sanitizeSettings, manualPalette, frameUniforms } from '../packages/web/src/settings.mjs'

test('renderer pauses, freezes hidden time, restores context and disposes listeners', () => {
  const events=new Map(),frames=new Map(),uniforms={};let id=0,now=0,draws=0,deleted=0
  const listen=target => (type,callback,options) => {
    const key=target+type;events.set(key,callback)
    options?.signal?.addEventListener('abort',()=>events.delete(key))
  }
  const motion={matches:true,addEventListener:listen('motion:')}
  const gl={...Object.fromEntries(['shaderSource','compileShader','attachShader','deleteShader','linkProgram','useProgram','viewport'].map(name=>[name,()=>{}])),
    VERTEX_SHADER:1,FRAGMENT_SHADER:2,COMPILE_STATUS:3,LINK_STATUS:4,TRIANGLES:5,
    createProgram:()=>({}),createShader:()=>({}),getShaderParameter:()=>true,getProgramParameter:()=>true,getUniformLocation:(_,name)=>name,
    uniform1f:(name,value)=>{uniforms[name]=value},uniform2f:(name,...values)=>{uniforms[name]=values},uniform4f:(name,...values)=>{uniforms[name]=values},
    drawArrays:()=>draws++,deleteProgram:()=>deleted++,
  }
  const canvas={clientWidth:800,clientHeight:600,getContext:()=>gl,addEventListener:listen('canvas:')}
  const document={hidden:false,addEventListener:listen('document:')}
  const source=readFileSync(new URL('../packages/web/src/renderer.mjs',import.meta.url),'utf8').replace(/^import .*\n/gm,'').replace('export function createMatriz','function createMatriz')+'\nglobalThis.create=createMatriz;'
  const context={sanitizeSettings,manualPalette,frameUniforms,fragmentSource:readFileSync(new URL('../src/sparkles.frag',import.meta.url),'utf8'),vertexSource:'',canvas,document,AbortController,
    matchMedia:()=>motion,window:{devicePixelRatio:2,addEventListener:listen('window:')},performance:{now:()=>now},
    requestAnimationFrame:fn=>{frames.set(++id,fn);return id},cancelAnimationFrame:id=>frames.delete(id),
  }
  runInNewContext(source,context);const renderer=context.create(canvas)
  function flush(time) {now=time;const pending=[...frames.values()];frames.clear();pending.forEach(fn=>fn(time))}
  flush(0);assert.equal(draws,1);assert.equal(frames.size,0);assert.equal(canvas.width,1200)
  assert.deepEqual(uniforms.uAudio,[0,0,0,0]);assert.deepEqual(uniforms.uSurface,[1,1,1,.75])
  motion.matches=false;events.get('motion:change')();flush(100);flush(120);assert.equal(draws,3)
  const phase=[...uniforms.uPhase]
  document.hidden=true;events.get('document:visibilitychange')();assert.equal(frames.size,0)
  document.hidden=false;events.get('document:visibilitychange')();flush(60000);assert.deepEqual(uniforms.uPhase,phase)
  renderer.pause();flush(61000);assert.equal(frames.size,0)
  renderer.update({hue:90});flush(62000);assert.equal(renderer.settings.hue,90)
  let prevented=false;events.get('canvas:webglcontextlost')({preventDefault:()=>{prevented=true}});assert.ok(prevented);assert.equal(frames.size,0)
  events.get('canvas:webglcontextrestored')();flush(63000);assert.equal(frames.size,0)
  renderer.destroy();assert.equal(events.size,0);assert.equal(frames.size,0);assert.equal(deleted,1)
  renderer.play();assert.equal(frames.size,0)
})
