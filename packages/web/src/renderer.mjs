import vertexSource from '../../../src/sparkles.vert?raw'
import fragmentSource from '../../../src/sparkles.frag?raw'
import { sanitizeSettings, manualPalette, frameUniforms } from './settings.mjs'

export function createMatriz(canvas, options = {}) {
  if (!canvas?.getContext) throw new TypeError('A canvas is required')
  const gl = canvas.getContext('webgl2', { alpha:false, antialias:false, depth:false, stencil:false })
  if (!gl) throw new Error('Matriz requires WebGL2')
  let settings = sanitizeSettings(options.settings)
  let program, locations, frame = 0, disposed = false, lost = false, paused = false, onscreen = true, dirty = true
  let elapsed = 0, previous, lastDraw = -Infinity, ratio = 1
  const motion = matchMedia('(prefers-reduced-motion: reduce)')
  const controller = new AbortController()
  const eventOptions = { signal:controller.signal }

  function initialize() {
    const shaders = []
    program = gl.createProgram()
    try {
      for (const [type, source] of [[gl.VERTEX_SHADER,vertexSource],[gl.FRAGMENT_SHADER,fragmentSource]]) {
        const shader = gl.createShader(type)
        shaders.push(shader)
        gl.shaderSource(shader,source); gl.compileShader(shader)
        if (!gl.getShaderParameter(shader,gl.COMPILE_STATUS)) throw new Error(gl.getShaderInfoLog(shader) || 'Shader compilation failed')
        gl.attachShader(program,shader)
      }
      gl.linkProgram(program)
      if (!gl.getProgramParameter(program,gl.LINK_STATUS)) throw new Error(gl.getProgramInfoLog(program) || 'Shader link failed')
      locations = Object.fromEntries([...fragmentSource.matchAll(/^uniform \w+ (u\w+);$/gm)].map(([,name]) => [name,gl.getUniformLocation(program,name)]))
    } catch (error) { gl.deleteProgram(program); throw error }
    finally { shaders.forEach(shader => gl.deleteShader(shader)) }
  }
  initialize()
  const visible = () => !disposed && !lost && !document.hidden && onscreen && canvas.clientWidth > 0 && canvas.clientHeight > 0
  const request = () => {
    dirty = true
    if (!frame && visible()) frame = requestAnimationFrame(render)
  }
  const stop = () => { cancelAnimationFrame(frame); frame = 0; previous = undefined }
  function render(timestamp = performance.now()) {
    frame = 0
    if (!visible()) { previous = undefined; return }
    const fps = settings.quality === 0 ? 30 : 60
    if (dirty || timestamp-lastDraw >= 1000/fps-1) {
      if (previous !== undefined && !paused && !motion.matches) elapsed += Math.min(.05,Math.max(0,(timestamp-previous)/1000))*settings.speed
      previous = timestamp; lastDraw = timestamp; dirty = false
      ratio = Math.min(window.devicePixelRatio || 1,[1,1.5,2][settings.quality])
      const width = Math.max(1,Math.round(canvas.clientWidth*ratio)), height = Math.max(1,Math.round(canvas.clientHeight*ratio))
      if (canvas.width !== width || canvas.height !== height) { canvas.width = width; canvas.height = height; gl.viewport(0,0,width,height) }
      const inputs = options.frameInputs?.() ?? {}
      const palette = inputs.palette ?? manualPalette(settings)
      const bands = inputs.audio ?? [0,0,0,0]
      const uniforms = frameUniforms(settings,width,height,ratio,elapsed,bands,palette)
      gl.useProgram(program)
      for (const [name,value] of Object.entries(uniforms)) {
        const location = locations[name]
        if (typeof value === 'number') gl.uniform1f(location,value)
        else if (value.length === 2) gl.uniform2f(location,...value)
        else gl.uniform4f(location,...value)
      }
      gl.drawArrays(gl.TRIANGLES,0,3)
    }
    if (!paused && !motion.matches) frame = requestAnimationFrame(render)
  }
  function report(error) { options.onError?.(error) }
  document.addEventListener('visibilitychange',() => { stop(); request() },eventOptions)
  window.addEventListener('resize',request,eventOptions)
  motion.addEventListener('change',() => { stop(); request() },eventOptions)
  canvas.addEventListener('webglcontextlost',event => { event.preventDefault(); lost = true; stop() },eventOptions)
  canvas.addEventListener('webglcontextrestored',() => {
    if (disposed) return
    try { initialize(); lost = false; previous = undefined; request() } catch (error) { report(error) }
  },eventOptions)
  const resize = typeof ResizeObserver === 'undefined' ? null : new ResizeObserver(request)
  resize?.observe(canvas)
  const intersection = typeof IntersectionObserver === 'undefined' ? null : new IntersectionObserver(entries => {
    onscreen = entries.some(entry => entry.isIntersecting)
    stop(); request()
  })
  intersection?.observe(canvas)
  request()
  return {
    get settings() { return sanitizeSettings(settings) },
    update(patch) { if (!disposed) { settings = sanitizeSettings(patch,settings); request() } },
    pause() { paused = true; stop(); request() },
    play() { paused = false; previous = undefined; request() },
    destroy() {
      if (disposed) return
      disposed = true; stop(); controller.abort(); resize?.disconnect(); intersection?.disconnect(); gl.deleteProgram(program)
    },
  }
}
