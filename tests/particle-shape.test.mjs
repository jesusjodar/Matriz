import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'

test('la concavidad depende del tamaño real: pequeña cóncava, grande abierta', () => {
  const source = readFileSync(new URL('../src/sparkles.frag', import.meta.url), 'utf8')
  const body = source.match(/float particleConcavity\(float radius, float base, float influence\) \{([^}]+)\}/)[1]
  const mix = (a, b, t) => a + (b - a) * t
  const smoothstep = (a, b, x) => { const t = Math.min(1, Math.max(0, (x - a) / (b - a))); return t * t * (3 - 2 * t) }
  const curve = new Function('radius', 'base', 'influence', 'mix', 'smoothstep', body)
  for (const base of [0, 0.4, 0.85]) for (const influence of [0, 0.5, 1]) {
    let previous = Infinity
    for (let radius = 0; radius <= 4; radius += 0.05) {
      const value = curve(radius, base, influence, mix, smoothstep)
      assert.ok(value >= -1e-8 && value <= 0.88 + 1e-8)
      assert.ok(value <= previous + 1e-8)
      if (influence === 0) assert.equal(value, base)
      previous = value
    }
  }
  assert.ok(curve(0.65, 0.85, 1, mix, smoothstep) > 0.87)
  assert.ok(curve(2.8, 0.85, 1, mix, smoothstep) < 0.05)
  assert.match(source, /radius \*= smoothstep[^;]+;[\s\S]*curve = particleConcavity\(radius, concavity, surface.w\)/)
})
