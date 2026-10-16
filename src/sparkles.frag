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
// x,y: centro del orbe en unidades normalizadas.
uniform vec4 uOrb;
uniform float uColorBlur;
out vec4 outColor;

float sparkleCoverage(vec2 cell, float radius, float concavity, vec2 pixel) {
  float filteredRadius = max(radius, max(pixel.x, pixel.y) * 1.5);
  float area = radius * radius / (filteredRadius * filteredRadius);
  vec2 bounds = 1.0 - smoothstep(vec2(filteredRadius) - pixel * 0.5, vec2(filteredRadius) + pixel * 0.5, cell);
  if (bounds.x == 0.0 || bounds.y == 0.0) return 0.0;
  float curve = cell.x + cell.y - filteredRadius
    + concavity * (filteredRadius * filteredRadius - dot(cell, cell)) / (2.0 * filteredRadius);
  vec2 gradient = max(vec2(0.0), 1.0 - concavity * cell / filteredRadius);
  float width = max(dot(gradient, pixel) * 0.5, 0.0001);
  float interior = 1.0 - smoothstep(-width, width, curve);
  return min(interior, bounds.x * bounds.y) * area;
}

vec3 anglesAt(vec2 position, vec4 phase, vec4 waveX, vec4 waveY) {
  return position.x * waveX.xyz + position.y * waveY.xyz + phase.xyz;
}

float depthAt(vec3 flow, float contrast, float music) {
  // Interferencias cruzadas forman volúmenes, en lugar de bandas paralelas.
  vec3 volume = flow + flow.yzx * flow.zxy * 0.38;
  float signal = dot(volume, vec3(0.42, 0.34, 0.24)) * contrast * (1.0 + music * 0.45);
  // Una curva sin mesetas evita regiones enteras de negro o de blanco.
  return 0.5 + 0.5 * signal / sqrt(0.55 + signal * signal);
}

float backgroundMask(vec2 position, vec2 resolution, vec3 flow, vec4 layout, vec4 orb) {
  if (layout.x < 0.5) return 1.0;
  vec2 uv = position / resolution;
  if (layout.x < 2.5) {
    float side = (uv.x - 0.5) * 2.0;
    // El signo unifica "+ sube la onda" en la inferior y la superior.
    float rise = layout.x < 1.5 ? layout.w : -layout.w;
    float edge = 0.43 + rise + (layout.y - 1.0) * 0.12 + 0.24 * side * side * (1.0 + side * 0.20)
      + flow.x * 0.045 + flow.z * 0.025;
    float y = layout.x < 1.5 ? uv.y : 1.0 - uv.y;
    return 1.0 - smoothstep(edge - 0.09, edge + 0.09, y);
  }
  if (layout.x < 3.5) {
    float center = 0.5 + layout.w + flow.x * 0.045 + flow.z * 0.025;
    float width = 0.16 * layout.y + flow.y * 0.025;
    return 1.0 - smoothstep(width - 0.075, width + 0.075, abs(uv.y - center));
  }
  vec2 point = (position - resolution * 0.5) / min(resolution.x, resolution.y) - orb.xy;
  float irregular = sin(point.x * 11.0 + flow.z) * sin(point.y * 9.0 + flow.y);
  float radius = 0.34 * layout.y * (1.0 + flow.x * (0.055 + orb.w * 0.13)
    + flow.y * (0.035 + orb.w * 0.10) + irregular * orb.w * 0.09);
  float feather = 0.08 * clamp(layout.y, 0.6, 2.0);
  float coverage = 1.0 - smoothstep(radius - feather, radius + feather, length(point));
  return layout.x < 4.5 ? coverage : 1.0 - coverage;
}

float geometricCoverage(vec2 cell, float radius, float concavity, vec2 pixel, float shape) {
  if (shape < 0.5) return sparkleCoverage(cell, radius, concavity, pixel);
  float filtered = max(radius, max(pixel.x, pixel.y) * 1.5);
  float area = radius * radius / (filtered * filtered);
  float distance = shape < 1.5 ? length(cell) : max(cell.x, cell.y);
  float width = max(max(pixel.x, pixel.y) * 0.5, 0.0001);
  return (1.0 - smoothstep(filtered - width, filtered + width, distance)) * area;
}

vec2 particleOffset(vec3 angles, float contrast, float music, float amplitude) {
  float light = smoothstep(0.22, 0.85, depthAt(sin(angles), contrast, music));
  // Las sombras se mueven menos; el desfase suaviza el arrastre de las crestas.
  vec2 drift = mix(sin(angles.xy), sin(angles.xy - vec2(0.32, 0.24)), light * 0.65);
  return drift * amplitude * (0.12 + 0.88 * light * light);
}

float particleConcavity(float radius, float base, float influence) {
  return mix(base, mix(0.88, 0.04, smoothstep(0.65, 2.8, radius)), influence);
}

float pointCoverage(vec2 screen, vec2 center, vec2 resolution,
  float spacing, vec4 phase, vec4 waveX, vec4 waveY, float contrast, float music,
  float size, float concavity, vec4 surface, float amplitude, vec2 pixel, vec4 layout, vec4 orb) {
  vec3 flow = sin(anglesAt(center, phase, waveX, waveY));
  float depth = depthAt(flow, contrast, music);
  vec2 position = center + particleOffset(anglesAt(center, phase, waveX, waveY), contrast, music, amplitude);
  float radius = min(spacing * 0.32, max(0.65, 2.1 * size
    * clamp(1.0 + surface.z * (depth - 0.55) * 0.55, 0.35, 1.9)));
  // Fuera de esta caja la cobertura es exactamente cero: margen conservador sobre las saturaciones.
  float reach = radius + 2.0 * max(pixel.x, pixel.y) * spacing + 0.001 * spacing;
  if (max(abs(screen.x - position.x), abs(screen.y - position.y)) > reach) return 0.0;
  float mask = backgroundMask(position, resolution, flow, layout, orb);
  if (mask == 0.0) return 0.0;
  radius *= smoothstep(0.0, 0.75, mask);
  float curve = 0.88;
  if (layout.z < 0.5) {
    curve = particleConcavity(radius, concavity, surface.w);
  }
  return geometricCoverage(abs(screen - position) / spacing, radius / spacing, curve, pixel, layout.z)
    * (0.4 + depth * 0.6);
}

float cellSparkle(vec2 screen, vec2 inverseGrid, float stagger, vec2 resolution,
  float spacing, vec4 phase, vec4 waveX, vec4 waveY, float contrast, float music,
  float size, float concavity, vec4 surface, float amplitude, vec2 pixel, vec4 layout, float displacement, vec4 orb) {
  vec2 grid = inverseGrid + stagger;
  vec2 center = (floor(grid) + 0.5 - stagger) * spacing;
  float coverage = pointCoverage(screen, center, resolution, spacing, phase, waveX, waveY,
    contrast, music, size, concavity, surface, amplitude, pixel, layout, orb);
  // La compresión puede acercar ambas vecinas: comprueba la caja completa sin umbrales que recorten figuras.
  if (displacement > 1.0) {
    for (int y = -1; y <= 1; y++) {
      for (int x = -1; x <= 1; x++) {
        if (x != 0 || y != 0) {
          float next = pointCoverage(screen, center + vec2(float(x), float(y)) * spacing, resolution, spacing,
            phase, waveX, waveY, contrast, music, size, concavity, surface, amplitude, pixel, layout, orb);
          coverage += next * (1.0 - coverage);
        }
      }
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
  float music = clamp(audio.x * 0.70 + audio.y * 0.18 + audio.z * 0.32, 0.0, 1.0);
  vec4 layout = uLayout;
  vec4 orb = uOrb;
  if (layout.x < 3.5) layout.y = 1.0 + audio.x * 0.70 + audio.y * 0.22;
  else layout.y *= 1.0 + audio.x * 0.28;
  orb.w = audio.z;
  float mask = backgroundMask(screen, resolution, flow, layout, orb);
  // Las derivadas quedan bajo el gate uniforme de uSurface.y (flujo uniforme, como antes).
  float spacing = max(uSpacing, 6.0);
  vec2 pixel = vec2(0.0001);
  if (uSurface.y > 0.0) {
    vec2 grid = screen / spacing;
    pixel = max(abs(dFdx(grid)) + abs(dFdy(grid)), vec2(0.0001));
  }
  vec3 color = vec3(0.0);
  if (mask > 0.0) {
    float depth = depthAt(flow, uContrast, music);

    // El relieve guía el color; el ruido cruzado rompe sus contornos regulares.
    float blur = clamp(uColorBlur, 0.0, 1.0);
    vec3 broad = sin(angles.yzx + flow.zxy * 0.85);
    vec3 detail = sin(angles * 2.0 + flow.yzx * 1.4);
    // Filtrado gaussiano por frecuencia: suaviza el ruido sin desenfocar las partículas.
    float noise = dot(broad, vec3(0.08, 0.06, -0.07)) * exp(-2.0 * blur * blur)
      + dot(detail, vec3(0.035)) * exp(-12.0 * blur * blur);
    float colorDepth = clamp(depth + noise, 0.0, 1.0);
    vec4 distance = vec4(colorDepth) - vec4(0.80, 0.20, 0.45, 0.65);
    float width = mix(0.08, 0.24, blur);
    vec4 masses = exp(-distance * distance / (2.0 * width * width));
    masses *= vec4(uColor0.w, uColor1.w, uColor2.w, uColor3.w);
    float richness = clamp(uStyle.y, 0.0, 1.0);
    masses.yzw *= richness;
    vec3 pigment = (uColor0.rgb * masses.x + uColor1.rgb * masses.y
      + uColor2.rgb * masses.z + uColor3.rgb * masses.w) / max(dot(masses, vec4(1.0)), 1e-30);

    float sparkle = 0.0;
    if (uSurface.y > 0.0) {
      float amplitude = sqrt(clamp(uStyle.x, 0.0, 4.0))
        * min(spacing * 3.0, min(resolution.x, resolution.y) * volumeScale * 0.018);
      amplitude *= 1.0 + audio.x * 0.06 + audio.z * 0.04;
      // Iteración inversa con el mismo campo que desplaza los centros.
      vec2 inverseScreen = screen;
      for (int iteration = 0; iteration < 4; iteration++) {
        vec2 offset = particleOffset(anglesAt(inverseScreen, uPhase, uWaveX, uWaveY), uContrast, music, amplitude);
        vec2 dx = (particleOffset(anglesAt(inverseScreen + vec2(0.5, 0.0), uPhase, uWaveX, uWaveY), uContrast, music, amplitude) - offset) * 2.0;
        vec2 dy = (particleOffset(anglesAt(inverseScreen + vec2(0.0, 0.5), uPhase, uWaveX, uWaveY), uContrast, music, amplitude) - offset) * 2.0;
        vec2 residual = inverseScreen + offset - screen;
        float determinant = max(0.1, (1.0 + dx.x) * (1.0 + dy.y) - dy.x * dx.y);
        inverseScreen -= vec2((1.0 + dy.y) * residual.x - dy.x * residual.y,
          (1.0 + dx.x) * residual.y - dx.y * residual.x) / determinant;
      }
      vec2 inverseGrid = inverseScreen / spacing;
      float first = cellSparkle(screen, inverseGrid, 0.0, resolution, spacing, uPhase, uWaveX, uWaveY, uContrast, music, uSize * (1.0 + audio.z * 0.18), uConcavity, uSurface, amplitude, pixel, layout, uStyle.x, orb);
      float second = cellSparkle(screen, inverseGrid, 0.5, resolution, spacing, uPhase, uWaveX, uWaveY, uContrast, music, uSize * (1.0 + audio.z * 0.18), uConcavity, uSurface, amplitude, pixel, layout, uStyle.x, orb);
      sparkle = first + second - first * second;
    }
    float relief = mix(orb.z, 1.12, depth);
    relief *= 1.0 + audio.x * 0.30 * depth + audio.z * 0.22 * depth * depth;
    // El contraste actúa sobre luz positiva, sin recortar las sombras.
    relief = pow(max(relief, 0.00001), uGrade.y);
    float luma = dot(pigment, vec3(0.2126, 0.7152, 0.0722));
    vec3 chromaDelta = (pigment - vec3(luma)) * uGrade.x;
    // Comprime el croma dentro de la gama conservando el matiz y la luminancia.
    float gamut = 1.0;
    if (chromaDelta.r < 0.0) gamut = min(gamut, luma / -chromaDelta.r);
    if (chromaDelta.g < 0.0) gamut = min(gamut, luma / -chromaDelta.g);
    if (chromaDelta.b < 0.0) gamut = min(gamut, luma / -chromaDelta.b);
    pigment = max(vec3(0.0), vec3(luma) + chromaDelta * gamut);
    color = pigment * relief * (0.82 * uSurface.x + sparkle * 1.15 * uSurface.y) * uBrightness;
    float peak = max(color.r, max(color.g, color.b));
    // Hombro suave: conserva detalle y proporciones RGB sin mesetas quemadas.
    float mapped = peak <= 0.65 ? peak : 0.65 + 0.32 * (1.0 - exp(-(peak - 0.65) / 0.32));
    color *= mapped / max(peak, 0.000001);
    color *= mask;
  }
  // Dither espacial estable, menor de un nivel de 8 bits: sin ruido animado ni centelleo.
  float dither = fract(52.9829189 * fract(dot(gl_FragCoord.xy, vec2(0.06711056, 0.00583715)))) - 0.5;
  color += vec3(dither / 255.0) * min(1.0, dot(color, vec3(85.0)));
  outColor = vec4(clamp(color, vec3(0.0), vec3(1.0)), 1.0);
}
