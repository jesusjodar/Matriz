export interface MatrizSettings {
  settingsVersion: number
  speed:number; brightness:number; contrast:number; palette:number; hue:number; spacing:number; size:number; volumeScale:number; quality:number; concavity:number
  waveOpacity:number; sparkleOpacity:number; waveSizeInfluence:number; depthConcavity:number; shadowLight:number; deformation:number
  backgroundStyle:number; wavePosition:number; orbX:number; orbY:number; orbSize:number; sparkleShape:number; paletteRichness:number; colorBlur:number; saturation:number; colorContrast:number
  customDeep:RGB; customLight:RGB; customSoft:RGB; customAccent:RGB
}
export type RGB = [number,number,number]
export interface MatrizController {
  readonly settings:MatrizSettings
  update(settings:Partial<MatrizSettings>):void
  pause():void
  play():void
  destroy():void
}
export function createMatriz(canvas:HTMLCanvasElement,options?:{settings?:Partial<MatrizSettings>;onError?:(error:Error)=>void}):MatrizController
export function sanitizeSettings(settings?:Partial<MatrizSettings>,base?:MatrizSettings):MatrizSettings
export const defaultSettings:Readonly<MatrizSettings>
export const settingsSchema:{version:number;settings:Record<string,unknown>[]}
export class MatrizBackground extends HTMLElement {
  settings:Partial<MatrizSettings>
  pause():void
  play():void

}
declare global { interface HTMLElementTagNameMap { 'matriz-background':MatrizBackground } }
