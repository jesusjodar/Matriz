import { createMatriz as createRenderer } from './renderer.mjs'
export function createMatriz(canvas,{settings,onError} = {}) { return createRenderer(canvas,{settings,onError}) }
export { defaultSettings, settingsSchema, sanitizeSettings } from './settings.mjs'

export class MatrizBackground extends (globalThis.HTMLElement ?? class {}) {
  static observedAttributes = ['settings','paused']
  #renderer
  #settings = {}
  connectedCallback() {
    if (this.#renderer) return
    if (!this.shadowRoot) {
      const root = this.attachShadow({mode:'open'})
      const style = document.createElement('style')
      style.textContent = ':host{display:block;position:absolute;inset:0;overflow:hidden;pointer-events:none;background:#08000d}canvas{display:block;width:100%;height:100%}'
      root.append(style,document.createElement('canvas'))
    }
    if (!this.hasAttribute('aria-hidden')) this.setAttribute('aria-hidden','true')
    try {
      const settings = this.hasAttribute('settings') ? JSON.parse(this.getAttribute('settings')) : this.#settings
      this.#renderer = createMatriz(this.shadowRoot.querySelector('canvas'),{settings,onError:error => this.#error(error)})
      if (this.hasAttribute('paused')) this.#renderer.pause()
    } catch (error) { this.#error(error) }
  }
  disconnectedCallback() { this.#settings = this.settings; this.#renderer?.destroy(); this.#renderer = undefined }
  attributeChangedCallback(name,oldValue,newValue) {
    if (oldValue === newValue || !this.#renderer) return
    try {
      if (name === 'settings') this.settings = newValue ? JSON.parse(newValue) : {}
      else if (newValue === null) this.play(); else this.pause()
    } catch (error) { this.#error(error) }
  }
  #error(error) { this.dispatchEvent(new CustomEvent('matriz-error',{detail:error,bubbles:true,composed:true})) }
  get settings() { return this.#renderer?.settings ?? {...this.#settings} }
  set settings(value) { this.#settings = value; this.#renderer?.update(value) }
  pause() { this.#renderer?.pause() }
  play() { this.#renderer?.play() }

}

if (typeof customElements !== 'undefined' && !customElements.get('matriz-background')) customElements.define('matriz-background',MatrizBackground)
