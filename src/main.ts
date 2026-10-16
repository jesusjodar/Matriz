import './style.css'
import vertexSource from './sparkles.vert?raw'
import fragmentSource from './sparkles.frag?raw'

const canvas = document.querySelector<HTMLCanvasElement>('#canvas')!
const gl = canvas.getContext('webgl2', {
  alpha: false,
  antialias: false,
  depth: false,
  stencil: false,
})

if (gl) {
  const program = gl.createProgram()!

  for (const [type, source] of [
    [gl.VERTEX_SHADER, vertexSource],
    [gl.FRAGMENT_SHADER, fragmentSource],
  ] as const) {
    const shader = gl.createShader(type)!
    gl.shaderSource(shader, source)
    gl.compileShader(shader)
    if (!gl.getShaderParameter(shader, gl.COMPILE_STATUS)) {
      const message = gl.getShaderInfoLog(shader)
      gl.deleteShader(shader)
      throw new Error(message ?? 'No se pudo compilar el shader.')
    }
    gl.attachShader(program, shader)
    gl.deleteShader(shader)
  }

  gl.linkProgram(program)
  if (!gl.getProgramParameter(program, gl.LINK_STATUS)) {
    throw new Error(gl.getProgramInfoLog(program) ?? 'No se pudo enlazar el shader.')
  }
  gl.useProgram(program)
  const resolution = gl.getUniformLocation(program, 'uResolution')
  const density = gl.getUniformLocation(program, 'uPixelRatio')
  const phases = gl.getUniformLocation(program, 'uPhase')
  const waveX = gl.getUniformLocation(program, 'uWaveX')
  const waveY = gl.getUniformLocation(program, 'uWaveY')
  let renderPixelRatio = 0
  gl.uniform4f(gl.getUniformLocation(program, 'uAudio'), 0, 0, 0, 0)
  gl.uniform4f(gl.getUniformLocation(program, 'uSurface'), 1, 1, 1, 0.75)
  gl.uniform4f(gl.getUniformLocation(program, 'uLayout'), 1, 1, 0, 0)
  gl.uniform4f(gl.getUniformLocation(program, 'uOrb'), 0, 0, 0.32, 0)
  gl.uniform2f(gl.getUniformLocation(program, 'uStyle'), 4, 1)
  gl.uniform2f(gl.getUniformLocation(program, 'uGrade'), 1, 1)
  for (const [name, value] of Object.entries({
    uColor0: [0.63, 0.12, 0.45, 1], uColor1: [0.30, 0.13, 0.56, 1],
    uColor2: [0.94, 0.36, 0.57, 1], uColor3: [0.49, 0.12, 0.52, 1],
  })) gl.uniform4f(gl.getUniformLocation(program, name), value[0], value[1], value[2], value[3])
  const phase = (seconds: number, rate: number) => (seconds * rate) % (Math.PI * 2)
  // Los mismos valores iniciales que MatrizSettings en macOS.
  for (const [name, value] of Object.entries({
    uBrightness: 1, uContrast: 1, uSpacing: 8,
    uColorBlur: 0.5, uSize: 1, uVolumeScale: 0.6, uConcavity: 0.78,
  })) gl.uniform1f(gl.getUniformLocation(program, name), value)
  const reducedMotion = window.matchMedia('(prefers-reduced-motion: reduce)')
  let frame = 0
  let dirty = true
  let lastDraw = -Infinity
  let animationTime = 0

  const render = (timestamp = 0) => {
    frame = 0
    if (document.hidden) return
    if (dirty || timestamp - lastDraw >= 1000 / 60 - 1) {
      if (!reducedMotion.matches) {
        animationTime += Math.min((timestamp - lastDraw) * 0.001, 0.05)
      }
      dirty = false
      lastDraw = timestamp
      const angle = phase(animationTime, 0.025)
      const bx = Math.sin(angle) * 0.65, by = Math.cos(angle) * 0.65
      const k0x = 5.8 + bx, k1x = -4.3 - by, k2x = 8.2 - bx
      const k0y = 4.0 + by, k1y = 7.2 + bx, k2y = -3.6 - by
      gl.uniform4f(waveX, k0x * renderPixelRatio / canvas.width,
        k1x * renderPixelRatio / canvas.width, k2x * renderPixelRatio / canvas.width, 0)
      gl.uniform4f(waveY, k0y * renderPixelRatio / canvas.height,
        k1y * renderPixelRatio / canvas.height, k2y * renderPixelRatio / canvas.height, 0)
      gl.uniform4f(phases, -phase(animationTime, 0.5175) + 0.8 - (k0x + k0y) * 0.5,
        phase(animationTime, 0.4095) - 1.2 - (k1x + k1y) * 0.5,
        -phase(animationTime, 0.3285) + 2.4 - (k2x + k2y) * 0.5, 0)
      gl.drawArrays(gl.TRIANGLES, 0, 3)
    }
    if (!reducedMotion.matches) frame = requestAnimationFrame(render)
  }

  const requestRender = () => {
    dirty = true
    if (!frame && !document.hidden) frame = requestAnimationFrame(render)
  }

  reducedMotion.addEventListener('change', requestRender)
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) {
      cancelAnimationFrame(frame)
      frame = 0
    } else {
      requestRender()
    }
  })

  const resize = () => {
    const pixelRatio = Math.min(window.devicePixelRatio, 1.5)
    const width = Math.max(1, Math.round(canvas.clientWidth * pixelRatio))
    const height = Math.max(1, Math.round(canvas.clientHeight * pixelRatio))
    if (width === canvas.width && height === canvas.height && pixelRatio === renderPixelRatio) {
      return
    }
    renderPixelRatio = pixelRatio
    canvas.width = width
    canvas.height = height
    gl.viewport(0, 0, canvas.width, canvas.height)
    gl.clearColor(0, 0, 0, 1)
    gl.clear(gl.COLOR_BUFFER_BIT)
    gl.uniform2f(resolution, canvas.width, canvas.height)
    gl.uniform1f(density, pixelRatio)
    requestRender()
  }

  window.addEventListener('resize', resize)
  resize()
} else {
  document.body.textContent = 'WebGL2 no está disponible en este navegador.'
}
