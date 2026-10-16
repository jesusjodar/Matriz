#version 300 es
precision highp float;

uniform vec2 uResolution;
uniform float uPixelRatio;
uniform float uBrightness;
uniform vec4 uPhase;
uniform vec4 uWaveX;
uniform vec4 uWaveY;
uniform float uContrast;
uniform float uSpacing;
uniform float uSize;
uniform float uVolumeScale;
uniform float uConcavity;
uniform vec4 uAudio;
uniform vec4 uSurface;
uniform vec2 uStyle;
uniform vec2 uGrade;
uniform vec4 uColor0;
uniform vec4 uColor1;
uniform vec4 uColor2;
uniform vec4 uColor3;
uniform vec4 uLayout;
out vec4 outColor;

float sparkleCoverage(vec2 cell, float radius, float concavity, vec2 pixel) {
  float filteredRadius = max(radius, max(pixel.x, pixel.y) * 1.5);
  float area = radius * radius / (filteredRadius * filteredRadius);
  float curve = cell.x + cell.y - filteredRadius
    + concavity * (filteredRadius * filteredRadius - dot(cell, cell)) / (2.0 * filteredRadius);
  vec2 gradient = max(vec2(0.0), 1.0 - concavity * cell / filteredRadius);
  float width = max(dot(gradient, pixel) * 0.5, 0.0001);
  float interior = 1.0 - smoothstep(-width, width, curve);
  vec2 bounds = 1.0 - smoothstep(vec2(filteredRadius) - pixel * 0.5, vec2(filteredRadius) + pixel * 0.5, cell);
  return min(interior, bounds.x * bounds.y) * area;
}

vec3 anglesAt(vec2 position, vec4 phase, vec4 waveX, vec4 waveY) {
  return position.x * waveX.xyz + position.y * waveY.xyz + phase.xyz;
}

float depthAt(vec3 flow, float contrast, float music) {
  // Interferencias cruzadas forman volúmenes, en lugar de bandas paralelas.
  vec3 volume = flow + flow.yzx * flow.zxy * 0.38;
  return 0.10 + 0.90 * smoothstep(-0.90, 0.90,
    dot(volume, vec3(0.42, 0.34, 0.24)) * contrast * (1.0 + music * 0.85));
}

float backgroundMask(vec2 position, vec2 resolution, vec3 flow, vec4 layout) {
  if (layout.x < 0.5) return 1.0;
  vec2 uv = position / resolution;
  if (layout.x < 2.5) {
    float side = (uv.x - 0.5) * 2.0;
    float edge = 0.43 + 0.24 * side * side * (1.0 + side * 0.20)
      + flow.x * 0.045 + flow.z * 0.025;
    float y = layout.x < 1.5 ? uv.y : 1.0 - uv.y;
    return 1.0 - smoothstep(edge - 0.09, edge + 0.09, y);
  }
  if (layout.x < 3.5) {
    float center = 0.5 + flow.x * 0.045 + flow.z * 0.025;
    float width = 0.16 + flow.y * 0.025;
    return 1.0 - smoothstep(width - 0.075, width + 0.075, abs(uv.y - center));
  }
  vec2 point = (position - resolution * 0.5) / min(resolution.x, resolution.y);
  float radius = 0.34 * layout.y * (1.0 + flow.x * 0.055 + flow.y * 0.035);
  float feather = 0.08 * clamp(layout.y, 0.6, 2.0);
  float orb = 1.0 - smoothstep(radius - feather, radius + feather, length(point));
  return layout.x < 4.5 ? orb : 1.0 - orb;
}

float geometricCoverage(vec2 cell, float radius, float concavity, vec2 pixel, float shape) {
  if (shape < 0.5) return sparkleCoverage(cell, radius, concavity, pixel);
  float filtered = max(radius, max(pixel.x, pixel.y) * 1.5);
  float area = radius * radius / (filtered * filtered);
  float distance = shape < 1.5 ? length(cell) : max(cell.x, cell.y);
  float width = max(max(pixel.x, pixel.y) * 0.5, 0.0001);
  return (1.0 - smoothstep(filtered - width, filtered + width, distance)) * area;
}

float pointCoverage(vec2 screen, vec2 center, vec2 resolution,
  float spacing, vec4 phase, vec4 waveX, vec4 waveY, float contrast, float music,
  float size, float concavity, vec4 surface, float amplitude, vec2 pixel, vec4 layout) {
  vec3 flow = sin(anglesAt(center, phase, waveX, waveY));
  float depth = depthAt(flow, contrast, music);
  vec2 position = center + flow.xy * amplitude;
  float radius = min(spacing * 0.32, max(0.65, 2.1 * size
    * clamp(1.0 + surface.z * (depth - 0.55) * 0.55, 0.35, 1.9)));
  radius *= smoothstep(0.0, 0.75, backgroundMask(position, resolution, flow, layout));
  float curve = clamp(concavity + surface.w * (depth - 0.55) * 0.32, 0.0, 0.88);
  return geometricCoverage(abs(screen - position) / spacing, radius / spacing, curve, pixel, layout.z)
    * (0.4 + depth * 0.6);
}

float cellSparkle(vec2 screen, vec2 inverseScreen, float stagger, vec2 resolution,
  float spacing, vec4 phase, vec4 waveX, vec4 waveY, float contrast, float music,
  float size, float concavity, vec4 surface, float amplitude, vec2 pixel, vec4 layout, float displacement) {
  vec2 grid = inverseScreen / spacing + stagger;
  vec2 center = (floor(grid) + 0.5 - stagger) * spacing;
  float coverage = pointCoverage(screen, center, resolution, spacing, phase, waveX, waveY,
    contrast, music, size, concavity, surface, amplitude, pixel, layout);
  // En el rango ampliado, las celdas vecinas evitan recortar formas al comprimirse el flujo.
  if (displacement > 1.0) {
    vec2 edge = fract(grid) - 0.5;
    vec2 neighbor = sign(edge) * spacing;
    if (abs(edge.x) > 0.25) {
      float next = pointCoverage(screen, center + vec2(neighbor.x, 0.0), resolution, spacing,
        phase, waveX, waveY, contrast, music, size, concavity, surface, amplitude, pixel, layout);
      coverage += next * (1.0 - coverage);
    }
    if (abs(edge.y) > 0.25) {
      float next = pointCoverage(screen, center + vec2(0.0, neighbor.y), resolution, spacing,
        phase, waveX, waveY, contrast, music, size, concavity, surface, amplitude, pixel, layout);
      coverage += next * (1.0 - coverage);
    }
    if (abs(edge.x) > 0.25 && abs(edge.y) > 0.25) {
      float next = pointCoverage(screen, center + neighbor, resolution, spacing,
        phase, waveX, waveY, contrast, music, size, concavity, surface, amplitude, pixel, layout);
      coverage += next * (1.0 - coverage);
    }
  }
  return coverage;
}

void main() {
  float pixelRatio = max(uPixelRatio, 0.001);
  vec2 screen = gl_FragCoord.xy / pixelRatio;
  vec2 resolution = max(uResolution / pixelRatio, vec2(1.0));
  float volumeScale = max(uVolumeScale, 0.1);
  vec3 angles = anglesAt(screen, uPhase, uWaveX, uWaveY);
  vec3 flow = sin(angles);
  vec4 audio = clamp(uAudio, vec4(0.0), vec4(1.0));
  float music = clamp(audio.x * 0.55 + audio.y * 0.20 + audio.w * 0.45, 0.0, 1.0);
  float depth = depthAt(flow, uContrast, music);

  // Cuatro masas entrelazadas comparten el movimiento, sin ordenar colores por altura.
  vec3 organic = flow + flow.yzx * flow.zxy * 0.55;
  vec4 masses = vec4(0.56 + organic.x * 0.32 - organic.y * 0.12,
    0.56 + organic.y * 0.32 - organic.z * 0.12,
    0.56 + organic.z * 0.32 - organic.x * 0.12,
    0.56 - dot(organic, vec3(0.20)));
  masses = max(masses, vec4(0.02));
  masses *= masses * masses;
  masses *= vec4(uColor0.w, uColor1.w, uColor2.w, uColor3.w);
  float richness = clamp(uStyle.y, 0.0, 1.0);
  masses.yzw *= richness;
  vec3 pigment = (uColor0.rgb * masses.x + uColor1.rgb * masses.y
    + uColor2.rgb * masses.z + uColor3.rgb * masses.w) / max(dot(masses, vec4(1.0)), 0.000001);

  float sparkle = 0.0;
  if (uSurface.y > 0.0) {
    float spacing = max(uSpacing, 6.0);
    float amplitude = sqrt(clamp(uStyle.x, 0.0, 4.0))
      * min(spacing * 3.0, min(resolution.x, resolution.y) * volumeScale * 0.018);
    vec2 offset = flow.xy * amplitude;
    // Una corrección del inverso encuentra la celda aunque su centro cruce varias celdas.
    vec2 gradient0 = cos(angles.x) * vec2(uWaveX.x, uWaveY.x) * amplitude;
    vec2 gradient1 = cos(angles.y) * vec2(uWaveX.y, uWaveY.y) * amplitude;
    vec2 inverseScreen = screen - offset + vec2(dot(gradient0, offset), dot(gradient1, offset));
    if (uStyle.x > 1.0) {
      for (int iteration = 0; iteration < 2; iteration++) {
        vec2 phase = anglesAt(inverseScreen, uPhase, uWaveX, uWaveY).xy;
        vec2 residual = inverseScreen + sin(phase) * amplitude - screen;
        vec2 g0 = cos(phase.x) * vec2(uWaveX.x, uWaveY.x) * amplitude;
        vec2 g1 = cos(phase.y) * vec2(uWaveX.y, uWaveY.y) * amplitude;
        float determinant = max(0.1, (1.0 + g0.x) * (1.0 + g1.y) - g0.y * g1.x);
        inverseScreen -= vec2((1.0 + g1.y) * residual.x - g0.y * residual.y,
          (1.0 + g0.x) * residual.y - g1.x * residual.x) / determinant;
      }
    }
    vec2 grid = screen / spacing;
    vec2 pixel = max(abs(dFdx(grid)) + abs(dFdy(grid)), vec2(0.0001));
    float first = cellSparkle(screen, inverseScreen, 0.0, resolution, spacing, uPhase, uWaveX, uWaveY, uContrast, music, uSize, uConcavity, uSurface, amplitude, pixel, uLayout, uStyle.x);
    float second = cellSparkle(screen, inverseScreen, 0.5, resolution, spacing, uPhase, uWaveX, uWaveY, uContrast, music, uSize, uConcavity, uSurface, amplitude, pixel, uLayout, uStyle.x);
    sparkle = first + second - first * second;
  }
  float relief = 0.14 + depth * depth * 0.96;
  relief *= mix(1.0 - music * 0.28, 1.0 + music * 0.85, depth) + audio.z * 0.18 * depth * depth;
  vec3 color = pigment * relief * (0.72 * uSurface.x + sparkle * 1.25 * uSurface.y) * uBrightness;
  float luma = dot(color, vec3(0.2126, 0.7152, 0.0722));
  color = max(vec3(0.0), mix(vec3(luma), color, uGrade.x));
  color *= max(0.0, 1.0 + (uGrade.y - 1.0) * (2.0 * clamp(luma, 0.0, 1.0) - 1.0));
  color /= max(1.0, max(color.r, max(color.g, color.b)));
  color *= backgroundMask(screen, resolution, flow, uLayout);
  // Dither espacial estable, menor de un nivel de 8 bits: sin ruido animado ni centelleo.
  float dither = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715)))) - 0.5;
  color += vec3(dither / 255.0) * min(1.0, dot(color, vec3(85.0)));
  outColor = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
