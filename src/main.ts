import './style.css'
import { createMatriz } from '../packages/web/src/index.mjs'

const canvas = document.querySelector<HTMLCanvasElement>('#canvas')!
try { createMatriz(canvas) }
catch (error) { document.body.textContent = error instanceof Error ? error.message : String(error) }
