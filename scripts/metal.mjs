export function generateMetal(source) {
  const uniforms = [...source.matchAll(/^uniform (vec[234]|float) (u\w+);$/gm)]
  const metalType = type => type.replace('vec', 'float')
  const field = name => name[1].toLowerCase() + name.slice(2)
  // Las ecuaciones se generan desde el GLSL para mantener una única fuente visual.
  return `#include <metal_stdlib>
using namespace metal;
struct Uniforms { ${uniforms.map(([, type, name]) => `${metalType(type)} ${field(name)};`).join(' ')} };
struct VertexOut { float4 position [[position]]; };
vertex VertexOut matrizVertex(uint id [[vertex_id]]) {
    const float2 positions[3] = {float2(-1.0, -1.0), float2(3.0, -1.0), float2(-1.0, 3.0)};
    return {float4(positions[id], 0.0, 1.0)};
}
` + source
    .replace(/^#version.*\n|^precision.*\n|^uniform.*\n|^out vec4.*\n/gm, '')
    .replace(/^const float /gm, 'constant float ')
    .replace(/\bvec([234])\b/g, 'float$1')
    .replace(/\bdFdx\b/g, 'dfdx').replace(/\bdFdy\b/g, 'dfdy')
    .replace('void main() {', `fragment float4 matrizFragment(VertexOut in [[stage_in]], constant Uniforms& uniforms [[buffer(0)]]) {
    ${uniforms.map(([, type, name]) => `${metalType(type)} ${name} = uniforms.${field(name)};`).join('\n    ')}
    float4 gl_FragCoord = float4(in.position.x, uResolution.y - in.position.y, 0.0, 1.0);`)
    .replace('outColor = ', 'return ')
}
