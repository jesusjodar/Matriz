import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
import { generateMetal } from '../scripts/metal.mjs'

const fixture = `#version 300 es
precision highp float;

uniform vec2 uResolution;
uniform float uSpacing;

out vec4 outColor;

float wave(vec2 point) {
  vec3 swell = vec3(point, uSpacing);
  return dFdx(swell.x) + dFdy(swell.y);
}

void main() {
  vec2 cell = gl_FragCoord.xy / uResolution;
  outColor = vec4(wave(cell), 0.0, 0.0, 1.0);
}
`

test('generateMetal traduce el GLSL a MSL exactamente', () => {
  const metal = generateMetal(fixture)
  assert.equal(metal, `#include <metal_stdlib>
using namespace metal;
struct Uniforms { float2 resolution; float spacing; };
struct VertexOut { float4 position [[position]]; };
vertex VertexOut matrizVertex(uint id [[vertex_id]]) {
    const float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0)};
    return {float4(positions[id], 0.0, 1.0)};
}



float wave(float2 point) {
  float3 swell = float3(point, uSpacing);
  return dfdx(swell.x) + dfdy(swell.y);
}

fragment float4 matrizFragment(VertexOut in [[stage_in]], constant Uniforms& uniforms [[buffer(0)]]) {
    float2 uResolution = uniforms.resolution;
    float uSpacing = uniforms.spacing;
    float4 gl_FragCoord = float4(in.position.x, uResolution.y - in.position.y, 0.0, 1.0);
  float2 cell = gl_FragCoord.xy / uResolution;
  return float4(wave(cell), 0.0, 0.0, 1.0);
}
`)
  // Comprobaciones puntuales de cada conversión, para que un fallo sea legible.
  assert.ok(metal.includes('struct Uniforms { float2 resolution; float spacing; };'))
  assert.ok(metal.includes('float2 cell = gl_FragCoord.xy / uResolution;'))
  assert.ok(metal.includes('return dfdx(swell.x) + dfdy(swell.y);'))
  assert.ok(metal.includes('fragment float4 matrizFragment(VertexOut in [[stage_in]], constant Uniforms& uniforms [[buffer(0)]]) {'))
  assert.ok(metal.includes('return float4(wave(cell), 0.0, 0.0, 1.0);'))
  assert.ok(!metal.includes('outColor'))
})

test('el shader real se genera sin restos de GLSL', () => {
  const source = readFileSync(new URL('../src/sparkles.frag', import.meta.url), 'utf8')
  assert.equal([...source.matchAll(/outColor = /g)].length, 1)
  assert.equal([...source.matchAll(/void main\(\) \{/g)].length, 1)
  const metal = generateMetal(source)
  assert.ok(metal.includes('matrizVertex'))
  assert.ok(metal.includes('matrizFragment'))
  assert.doesNotMatch(metal, /\bvec[234]\b/)
  assert.doesNotMatch(metal, /\bdFdx\b|\bdFdy\b/)
  assert.doesNotMatch(metal, /#version/)
  assert.doesNotMatch(metal, /precision highp/)
  assert.doesNotMatch(metal, /outColor/)
})
