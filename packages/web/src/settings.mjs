import schema from '../../../shared/settings.json' with { type: 'json' }

export const settingsSchema = schema
export const defaultSettings = Object.freeze(Object.fromEntries([
  ['settingsVersion', schema.version], ...schema.settings.map(x => [x.key, Array.isArray(x.default) ? Object.freeze([...x.default]) : x.default]),
]))

export function sanitizeSettings(input = {}, base = defaultSettings) {
  if (!input || typeof input !== 'object' || Array.isArray(input)) throw new TypeError('Settings must be an object')
  const result = { settingsVersion: schema.version }
  for (const spec of schema.settings) {
    const value = input[spec.key]
    let clean = base[spec.key]
    if (spec.kind === 'boolean' && typeof value === 'boolean') clean = value
    if (spec.kind === 'color' && Array.isArray(value) && value.length === 3 && value.every(x => typeof x === 'number' && Number.isFinite(x))) clean = value.map(x => Math.max(0, Math.min(1, x)))
    if (typeof value === 'number' && Number.isFinite(value) && 'min' in spec) {
      clean = Math.max(spec.min, Math.min(spec.max, value))
      if (spec.kind === 'choice') clean = Math.round(clean)
    }
    result[spec.key] = Array.isArray(clean) ? [...clean] : clean
  }
  return result
}

export const palettes = [
  [[.06,.16,.6],[.10,.24,.68],[.04,.10,.36],[.08,.25,.55]],
  [[.10,.24,.68],[.24,.15,.55],[.025,.48,.63],[.14,.10,.44]],
  [[.10,.24,.68],[.025,.48,.63],[.08,.20,.48],[.08,.52,.53]],
  [[.08,.48,.32],[.10,.23,.46],[.30,.75,.52],[.08,.35,.45]],
  [[.76,.20,.12],[.42,.09,.43],[.97,.49,.20],[.75,.16,.36]],
  [[.63,.12,.45],[.30,.13,.56],[.94,.36,.57],[.49,.12,.52]],
  [[.67,.32,.06],[.38,.12,.035],[.96,.65,.22],[.60,.24,.05]],
  [[.44,.44,.44],[.30,.30,.30],[.70,.70,.70],[.22,.22,.22]],
]

export function manualPalette(settings) {
  const colors = settings.palette === 8 ? [settings.customLight,settings.customDeep,settings.customSoft,settings.customAccent] : palettes[settings.palette]
  const angle = settings.hue * Math.PI / 180, c = Math.cos(angle), s = Math.sin(angle) / Math.sqrt(3), t = (1-c)/3
  return colors.map(([r,g,b]) => {
    const sum = (r+g+b)*t
    const rgb = [r*c+s*(b-g)+sum,g*c+s*(r-b)+sum,b*c+s*(g-r)+sum].map(x => Math.max(0,x))
    return rgb.map(x => x / Math.max(1,...rgb))
  })
}


export function frameUniforms(s, width, height, ratio, time, audio = [0,0,0,0], palette = manualPalette(s)) {
  const phase = rate => (time * rate) % (Math.PI*2)
  const bx = Math.sin(phase(.025))*.65, by = Math.cos(phase(.025))*.65
  const kx = [5.8+bx,-4.3-by,8.2-bx], ky = [4+by,7.2+bx,-3.6-by]
  return {
    uResolution:[width,height], uPixelRatio:ratio, uBrightness:s.brightness,
    uPhase:[-phase(.5175)+.8-(kx[0]+ky[0])*.5/s.volumeScale,phase(.4095)-1.2-(kx[1]+ky[1])*.5/s.volumeScale,-phase(.3285)+2.4-(kx[2]+ky[2])*.5/s.volumeScale,0],
    uWaveX:[...kx.map(x => x*ratio/(width*s.volumeScale)),0],uWaveY:[...ky.map(y => y*ratio/(height*s.volumeScale)),0],
    uContrast:s.contrast,uSpacing:s.spacing,uSize:s.size,uVolumeScale:s.volumeScale,uConcavity:s.concavity,
    uAudio:audio,uSurface:[s.waveOpacity,s.sparkleOpacity,s.waveSizeInfluence,s.depthConcavity],uStyle:[s.deformation,s.paletteRichness],uGrade:[s.saturation,s.colorContrast],
    uColor0:[...palette[0],1],uColor1:[...palette[1],1],uColor2:[...palette[2],1],uColor3:[...palette[3],1],
    uLayout:[s.backgroundStyle,s.orbSize,s.sparkleShape,s.wavePosition],uOrb:[s.orbX,s.orbY,s.shadowLight,0],uColorBlur:s.colorBlur,
  }
}
