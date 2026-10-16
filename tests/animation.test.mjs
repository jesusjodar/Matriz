import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
import { runInNewContext } from 'node:vm'
import ts from 'typescript'

test('anima sin interacción, respeta movimiento reducido y pausa al ocultarse', () => {
  const events = {}
  const frames = []
  const timeUpdates = []
  const uniforms = {}
  let draws = 0
  const motion = {
    matches: true,
    addEventListener: (_, handler) => { events.motionchange = handler },
  }
  const gl = {
    ...Object.fromEntries([
      'shaderSource', 'compileShader', 'attachShader', 'deleteShader',
      'linkProgram', 'useProgram', 'viewport', 'clearColor', 'clear',
    ].map((name) => [name, () => {}])),
    VERTEX_SHADER: 35633,
    FRAGMENT_SHADER: 35632,
    TRIANGLES: 4,
    COLOR_BUFFER_BIT: 16384,
    createProgram: () => ({}),
    createShader: () => ({}),
    getShaderParameter: () => true,
    getProgramParameter: () => true,
    getUniformLocation: (_, name) => name,
    uniform1f: (name, value) => {
      uniforms[name] = value
    },
    uniform2f: (name, ...value) => { uniforms[name] = value },
    uniform4f: (name, ...value) => {
      uniforms[name] = value
      if (name === 'uPhase') timeUpdates.push(-(value[0] - 0.8 + (uniforms.uWaveX[0] * canvas.width + uniforms.uWaveY[0] * canvas.height) / (2 * uniforms.uPixelRatio)) / 0.5175)
    },
    drawArrays: () => { draws++ },
  }
  const canvas = {
    clientWidth: 800,
    clientHeight: 600,
    getContext: () => gl,
    addEventListener: (name, handler) => { events[name] = handler },
  }
  const source = readFileSync(new URL('../src/main.ts', import.meta.url), 'utf8')
    .replace(/^import .*\n/gm, '')
  const document = {
    hidden: false,
    querySelector: () => canvas,
    addEventListener: (name, handler) => { events[name] = handler },
  }
  runInNewContext(ts.transpileModule(source, {}).outputText, {
    vertexSource: '', fragmentSource: '',
    document,
    window: {
      devicePixelRatio: 2,
      matchMedia: () => motion,
      addEventListener: (name, handler) => { events[name] = handler },
    },
    requestAnimationFrame: (callback) => frames.push(callback),
    cancelAnimationFrame: () => { frames.length = 0 },
  })

  assert.equal(frames.length, 1)
  for (const [name, value] of Object.entries({ uBrightness: 1, uContrast: 1,
    uSpacing: 8, uColorBlur: 0.5, uSize: 1, uVolumeScale: 0.6, uConcavity: 0.78 })) assert.equal(uniforms[name], value)
  assert.deepEqual(uniforms.uAudio, [0, 0, 0, 0])
  assert.deepEqual(uniforms.uSurface, [1, 1, 1, 0.75])
  assert.deepEqual(uniforms.uOrb, [0, 0, 0.32, 0])
  assert.deepEqual(uniforms.uLayout, [1, 1, 0, 0])
  assert.deepEqual(uniforms.uStyle, [4, 1])
  assert.deepEqual(uniforms.uGrade, [1, 1])
  for (const [name, value] of Object.entries({
    uColor0: [0.63, 0.12, 0.45, 1], uColor1: [0.30, 0.13, 0.56, 1],
    uColor2: [0.94, 0.36, 0.57, 1], uColor3: [0.49, 0.12, 0.52, 1],
  })) assert.deepEqual(uniforms[name], value, name)

  frames.shift()()
  assert.equal(draws, 1)
  // Todos los uniforms deben estar inicializados antes del primer fotograma.
  const shader = readFileSync(new URL('../src/sparkles.frag', import.meta.url), 'utf8')
  const declarations = [...shader.matchAll(/^uniform (vec[234]|float) (u\w+);$/gm)]
  for (const [, type, name] of declarations) {
    assert.ok(Object.hasOwn(uniforms, name), `${name} sin inicializar`)
    const values = type === 'float' ? [uniforms[name]] : uniforms[name]
    assert.equal(values.length, type === 'float' ? 1 : Number(type.at(-1)), name)
    assert.ok(values.every(Number.isFinite), name)
  }

  assert.equal(Object.hasOwn(uniforms, 'uArtwork'), false)
  assert.equal(Object.hasOwn(uniforms, 'uHueRotation'), false)
  assert.equal(frames.length, 0)
  for (const event of ['pointermove', 'pointerdown', 'deviceorientation', 'devicemotion']) {
    assert.equal(events[event], undefined)
  }

  motion.matches = false
  events.motionchange()
  frames.shift()(100)
  assert.equal(draws, 2)
  assert.equal(frames.length, 1)
  frames.shift()(116)
  assert.equal(draws, 3)
  frames.shift()(124)
  assert.equal(draws, 3)
  frames.shift()(134)
  assert.equal(draws, 4)
  const timeBeforeHiding = timeUpdates.at(-1)
  document.hidden = true
  events.visibilitychange()
  assert.equal(frames.length, 0)
  document.hidden = false
  events.visibilitychange()
  assert.equal(frames.length, 1)
  frames.shift()(60_000)
  assert.equal(draws, 5)
  assert.ok(timeUpdates.at(-1) - timeBeforeHiding <= 0.051)
  const pausedTime = timeUpdates.at(-1)
  motion.matches = true
  events.motionchange()
  frames.shift()(60_016)
  assert.equal(draws, 6)
  assert.equal(timeUpdates.at(-1), pausedTime)
  assert.equal(frames.length, 0)
})
