import { test, expect } from '@playwright/test'

test('real WebGL2: independent visual components, updates and no integration API',async ({page})=>{
  const errors=[];page.on('pageerror',error=>errors.push(error.message));await page.goto('/')
  await page.evaluate(async ()=>{
    await import('/packages/web/src/index.mjs');document.querySelector('#canvas').remove()
    for(let i=0;i<2;i++) {
      const node=document.createElement('matriz-background');node.id='bg'+i
      node.style.cssText=`position:absolute;top:0;left:${i*320}px;width:320px;height:240px`
      node.settings={palette:i===0?5:2,backgroundStyle:0};document.body.append(node)
    }
  })
  const first=page.locator('#bg0'),second=page.locator('#bg1')
  await expect(first.locator('canvas')).toHaveJSProperty('width',320)
  expect(await first.evaluate(node=>({agent:typeof node.setAgentState,audio:typeof node.setAudio,controls:node.querySelectorAll('input,button,select').length}))).toEqual({agent:'undefined',audio:'undefined',controls:0})
  await first.evaluate(node=>{node.pause();node.settings={palette:8,customLight:[1,0,0],customDeep:[1,0,0],customSoft:[1,0,0],customAccent:[1,0,0]}})
  const pixels=await first.evaluate(node=>new Promise(resolve=>requestAnimationFrame(()=>{
    const canvas=node.shadowRoot.querySelector('canvas'),gl=canvas.getContext('webgl2'),data=new Uint8Array(canvas.width*canvas.height*4)
    gl.readPixels(0,0,canvas.width,canvas.height,gl.RGBA,gl.UNSIGNED_BYTE,data)
    let r=0,g=0,b=0;for(let i=0;i<data.length;i+=4){r+=data[i];g+=data[i+1];b+=data[i+2]}resolve([r,g,b])
  })))
  expect(pixels[0]).toBeGreaterThan(0);expect(pixels[1]).toBe(0);expect(pixels[2]).toBe(0)
  expect(await second.evaluate(node=>node.settings.palette)).toBe(2)
  await first.evaluate(node=>{node.remove();document.body.append(node)});await expect(first.locator('canvas')).toHaveJSProperty('width',320)
  expect(errors).toEqual([])
})

test('reduced motion and WebGL context recovery',async ({page})=>{
  await page.emulateMedia({reducedMotion:'reduce'});await page.goto('/')
  const result=await page.evaluate(async ()=>{
    const {createMatriz}=await import('/packages/web/src/index.mjs')
    const canvas=document.createElement('canvas');canvas.style.cssText='width:400px;height:300px';document.body.append(canvas)
    const renderer=createMatriz(canvas,{settings:{backgroundStyle:0,palette:3}});await new Promise(requestAnimationFrame)
    const gl=canvas.getContext('webgl2'),extension=gl.getExtension('WEBGL_lose_context')
    extension.loseContext();await new Promise(resolve=>setTimeout(resolve,100));extension.restoreContext()
    await new Promise(resolve=>canvas.addEventListener('webglcontextrestored',resolve,{once:true}));await new Promise(requestAnimationFrame)
    const valid=gl.getError()===gl.NO_ERROR;renderer.destroy();return valid
  })
  expect(result).toBe(true)
})
