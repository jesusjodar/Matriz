import { test, expect } from '@playwright/test'

test.beforeEach(async ({page})=>{
  await page.addInitScript(()=>{
    const pending=new WeakMap(),draw=WebGL2RenderingContext.prototype.drawArrays
    WebGL2RenderingContext.prototype.drawArrays=function(...args){
      draw.apply(this,args)
      const capture=pending.get(this.canvas)
      if(capture){pending.delete(this.canvas);capture(this)}
    }
    window.readMatrizFrame=async (canvas,change)=>{
      await change()
      return new Promise((resolve,reject)=>{
        const timeout=setTimeout(()=>{pending.delete(canvas);reject(new Error('Matriz did not draw the requested frame'))},5000)
        pending.set(canvas,gl=>{
          // WebGL may clear its default buffer after compositing; read inside the draw call.
          const data=new Uint8Array(canvas.width*canvas.height*4),sum=[0,0,0]
          gl.readPixels(0,0,canvas.width,canvas.height,gl.RGBA,gl.UNSIGNED_BYTE,data)
          for(let i=0;i<data.length;i+=4)for(let c=0;c<3;c++)sum[c]+=data[i+c]
          clearTimeout(timeout);resolve(sum)
        })
      })
    }
  })
})

test('real WebGL2: independent visual components, updates and no integration API',async ({page})=>{
  const errors=[];page.on('pageerror',error=>errors.push(error.message));await page.goto('/browser-tests/fixture.html')
  await page.evaluate(async ()=>{
    await import('/packages/web/dist/matriz-background.js');document.querySelector('#canvas').remove()
    for(let i=0;i<2;i++) {
      const node=document.createElement('matriz-background');node.id='bg'+i
      node.style.cssText=`position:absolute;top:0;left:${i*320}px;width:320px;height:240px`
      node.settings={palette:i===0?5:2,backgroundStyle:0};document.body.append(node)
    }
  })
  const first=page.locator('#bg0'),second=page.locator('#bg1')
  await expect(first.locator('canvas')).toHaveJSProperty('width',320)
  expect(await first.evaluate(node=>({agent:typeof node.setAgentState,audio:typeof node.setAudio,controls:node.querySelectorAll('input,button,select').length}))).toEqual({agent:'undefined',audio:'undefined',controls:0})
  const pixels=await first.evaluate(node=>window.readMatrizFrame(node.shadowRoot.querySelector('canvas'),()=>{
    node.pause();node.settings={palette:8,customLight:[1,0,0],customDeep:[1,0,0],customSoft:[1,0,0],customAccent:[1,0,0]}
  }))
  expect(pixels[0]).toBeGreaterThan(0);expect(pixels[1]).toBe(0);expect(pixels[2]).toBe(0)
  expect(await second.evaluate(node=>node.settings.palette)).toBe(2)
  await first.evaluate(node=>{node.remove();document.body.append(node)});await expect(first.locator('canvas')).toHaveJSProperty('width',320)
  expect(errors).toEqual([])
})

test('reduced motion and WebGL context recovery',async ({page})=>{
  await page.emulateMedia({reducedMotion:'reduce'});await page.goto('/browser-tests/fixture.html')
  const result=await page.evaluate(async ()=>{
    const {createMatriz}=await import('/packages/web/dist/matriz-background.js')
    const canvas=document.createElement('canvas');canvas.style.cssText='width:400px;height:300px';document.body.append(canvas)
    const renderer=createMatriz(canvas,{settings:{backgroundStyle:0,palette:3}});await new Promise(requestAnimationFrame)
    const gl=canvas.getContext('webgl2'),extension=gl.getExtension('WEBGL_lose_context')
    extension.loseContext();await new Promise(resolve=>setTimeout(resolve,100));extension.restoreContext()
    await new Promise(resolve=>canvas.addEventListener('webglcontextrestored',resolve,{once:true}));await new Promise(requestAnimationFrame)
    const valid=gl.getError()===gl.NO_ERROR;renderer.destroy();return valid
  })
  expect(result).toBe(true)
})

test('Windows adapter keeps native integrations separate and renders agent and artwork palettes',async ({page})=>{
  await page.emulateMedia({reducedMotion:'reduce'});await page.goto('/browser-tests/fixture.html')
  const result=await page.evaluate(async ()=>{
    const messages=[];let receive
    window.chrome={webview:{addEventListener:(_,listener)=>{receive=listener},postMessage:message=>messages.push(message)}}
    document.querySelector('canvas').style.cssText='width:320px;height:240px'
    await import('/windows/Matriz/Assets/Web/host.js')
    const {defaultSettings}=await import('/packages/web/dist/matriz-background.js')
    const send=data=>receive({data})
    await send({type:'settings',settings:{...defaultSettings,backgroundStyle:0,agentEnabled:true,artworkEnabled:true,artworkIntensity:1,artworkColors:4,artworkTransition:0}})
    await send({type:'pause',value:true})
    const pixels=change=>window.readMatrizFrame(document.querySelector('canvas'),change)
    const green=await pixels(()=>send({type:'agent',state:'completed'}))
    const red=await pixels(()=>send({type:'agent',state:'error'}))
    await send({type:'agent',state:null})
    const image=document.createElement('canvas');image.width=image.height=64
    const ctx=image.getContext('2d');ctx.fillStyle='#888';ctx.fillRect(0,0,64,64)
    const gray=await pixels(()=>send({type:'artwork',mime:'image/png',base64:image.toDataURL().split(',')[1]}))
    await send({type:'self-test'})
    return {green,red,gray,errors:messages.filter(x=>x.type==='error'),reply:messages.find(x=>x.type==='self-test')}
  })
  expect(result.errors).toEqual([]);expect(result.reply.webgl).toBe(true)
  expect(result.reply.settings.agentEnabled).toBeUndefined();expect(result.reply.settings.audioEnabled).toBeUndefined()
  expect(result.green[1]).toBeGreaterThan(result.green[0]*2);expect(result.red[0]).toBeGreaterThan(result.red[1]*2)
  expect(Math.max(...result.gray)-Math.min(...result.gray)).toBeLessThan(Math.max(...result.gray)*.01)
})
