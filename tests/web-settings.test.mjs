import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { settingsSchema, defaultSettings, sanitizeSettings, frameUniforms, manualPalette } from '../packages/web/src/settings.mjs'
import { extractPixels } from '../windows/web/colors.mjs'

test('visual settings validate input and exclude native integrations', () => {
  const clean=sanitizeSettings({size:100,brightness:true,palette:2.6,hue:-5,customLight:[-.1,.5,2],agentEnabled:true})
  assert.equal(clean.size,1.4);assert.equal(clean.brightness,1);assert.equal(clean.palette,3);assert.equal(clean.hue,0)
  assert.deepEqual(clean.customLight,[0,.5,1]);assert.ok(!Object.hasOwn(clean,'agentEnabled'))
  assert.ok(settingsSchema.settings.every(x=>!['Music','AI agents'].includes(x.group)))
  const copy=sanitizeSettings();copy.customLight[0]=1;assert.notEqual(defaultSettings.customLight[0],1)
})
test('uniform contract initializes GLSL and matches native volume and phase math', () => {
  const s=sanitizeSettings(),frame=frameUniforms(s,1440,900,1.5,2)
  const shader=readFileSync(new URL('../src/sparkles.frag',import.meta.url),'utf8')
  for(const [,type,name] of shader.matchAll(/^uniform (vec[234]|float) (u\w+);$/gm)) {
    assert.ok(frame[name]!==undefined,name);assert.ok((type==='float'?[frame[name]]:frame[name]).every(Number.isFinite),name)
  }
  const bx=Math.sin(.05)*.65,by=Math.cos(.05)*.65
  assert.equal(frame.uWaveX[0],(5.8+bx)*1.5/(1440*.6))
  assert.ok(Math.abs(frame.uPhase[0]-(-2*.5175+.8-(5.8+bx+4+by)*.5/.6))<1e-12)
  const red=sanitizeSettings({palette:8,customLight:[1,0,0],customDeep:[1,0,0],customSoft:[1,0,0],customAccent:[1,0,0]})
  assert.deepEqual(manualPalette(red),Array.from({length:4},()=>[1,0,0]))
})
test('native artwork extraction retains grayscale and multicolor images', () => {
  const pixels=new Uint8ClampedArray(64*64*4)
  for(let i=0;i<pixels.length;i+=4) pixels.set([128,128,128,255],i)
  const gray=extractPixels(pixels);assert.equal(gray.length,1);assert.ok(Math.abs(gray[0][0]-gray[0][1])<1e-6)
  for(let i=0;i<pixels.length;i+=4) pixels.set(i<pixels.length/2?[255,0,0,255]:[0,0,255,255],i)
  assert.equal(extractPixels(pixels).length,2)
})
