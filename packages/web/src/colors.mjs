export function toLab([r,g,b]) {
  const l=Math.cbrt(.4122214708*r+.5363325363*g+.0514459929*b),m=Math.cbrt(.2119034982*r+.6806995451*g+.1073969566*b),s=Math.cbrt(.0883024619*r+.2817188376*g+.6299787005*b)
  return [.2104542553*l+.793617785*m-.0040720468*s,1.9779984951*l-2.428592205*m+.4505937099*s,.0259040371*l+.7827717662*m-.808675766*s]
}
export function fromLab([x,y,z]) {
  const convert = scale => {
    const l=(x+(.3963377774*y+.2158037573*z)*scale)**3,m=(x-(.1055613458*y+.0638541728*z)*scale)**3,s=(x-(.0894841775*y+1.291485548*z)*scale)**3
    return [4.0767416621*l-3.3077115913*m+.2309699292*s,-1.2684380046*l+2.6097574011*m-.3413193965*s,-.0041960863*l-.7034186147*m+1.707614701*s]
  }
  const valid = c => c.every(v => v >= -.00001 && v <= 1.00001)
  let color=convert(1)
  if (!valid(color)) {
    let low=0,high=1
    for (let i=0;i<10;i++) { const mid=(low+high)/2; if (valid(convert(mid))) low=mid; else high=mid }
    color=convert(low)
  }
  return color.map(v => Math.min(1,Math.max(0,v)))
}
export function mixColor(a,b,t) {
  const x=toLab(a),y=toLab(b)
  return fromLab(x.map((v,i) => v+(y[i]-v)*t))
}
export function extractPixels(pixels) {
  const weights=Array(125).fill(0),sums=Array.from({length:125},() => [0,0,0])
  const linear = x => x <= .04045 ? x/12.92 : ((x+.055)/1.055)**2.4
  for (let i=0;i<pixels.length;i+=4) {
    const alpha=pixels[i+3]/255
    if (alpha < .8) continue
    const rgb=[0,1,2].map(c => linear(pixels[i+c]/(255*alpha))),lab=toLab(rgb)
    const hue=Math.min(23,Math.max(0,Math.floor((Math.atan2(lab[2],lab[1])+Math.PI)/(2*Math.PI)*24)))
    const light=Math.min(4,Math.max(0,Math.floor(lab[0]*5))),chroma=Math.hypot(lab[1],lab[2]),bucket=chroma < .035 ? 120+light : hue*5+light
    const weight=alpha*(1+Math.min(chroma,.3)*2)
    weights[bucket]+=weight; for(let c=0;c<3;c++) sums[bucket][c]+=rgb[c]*weight
  }
  const minimum=Math.max(1,weights.reduce((a,b) => a+b,0)*.005),colors=[]
  for (const i of weights.map((_,i)=>i).sort((a,b) => weights[b]-weights[a] || a-b)) {
    if(weights[i]<=minimum) continue
    const rgb=sums[i].map(x => x/weights[i]),lab=toLab(rgb)
    if (colors.every(c => Math.hypot(...toLab(c).map((x,i) => x-lab[i])) >= .085)) colors.push(rgb)
    if(colors.length===4) break
  }
  return colors.length ? colors : null
}
export async function extractArtwork(blob) {
  if (!(blob instanceof Blob) || !blob.type.startsWith('image/') || blob.size > 8*1024*1024) throw new TypeError('Artwork must be an image Blob up to 8 MB')
  const image=await createImageBitmap(blob,{resizeWidth:64,resizeHeight:64})
  try {
    const canvas=typeof OffscreenCanvas==='undefined' ? Object.assign(document.createElement('canvas'),{width:64,height:64}) : new OffscreenCanvas(64,64)
    const context=canvas.getContext('2d',{willReadFrequently:true})
    context.drawImage(image,0,0,64,64)
    return extractPixels(context.getImageData(0,0,64,64).data)
  } finally { image.close() }
}
