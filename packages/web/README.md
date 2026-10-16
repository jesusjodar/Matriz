# Matriz para webs

Fondo WebGL2 sin dependencias de ejecución, sin controles visibles, sin música y sin integración con agentes. Comparte el shader visual de las aplicaciones de escritorio. Requiere WebGL2; si no está disponible, conserva tu fondo CSS y escucha `matriz-error` para ofrecer una alternativa.

## Uso directo

Extrae el paquete web y sirve sus archivos por HTTP. Abre `example.html` para probarlo. No abras el HTML mediante `file://`.

```html
<style>
  .hero { position: relative; isolation: isolate; min-height: 500px; background: #000; }
  .hero > .content { position: relative; }
</style>
<section class="hero">
  <matriz-background id="fondo"></matriz-background>
  <div class="content"><h1>Tu contenido</h1></div>
</section>
<script type="module">
  import './dist/matriz-background.js';
  document.querySelector('#fondo').settings = {
    palette: 5, backgroundStyle: 0, speed: 0.7,
    brightness: 1, shadowLight: 0.32, colorBlur: 0.65,
    size: 1, deformation: 2, quality: 1
  };
</script>
```

Los cambios se aplican asignando `element.settings = { ...valores }`; los valores omitidos se conservan. También puedes definir un atributo JSON `settings='{"palette":5,"speed":0.7}'` antes de conectar el elemento. No se crean formularios, botones ni paneles.

## Con un proyecto npm

```sh
npm install ./matriz-background-2.2.0.tgz
```

```js
import { createMatriz, defaultSettings } from '@matriz/background';
const fondo = createMatriz(document.querySelector('canvas'), {
  settings: { ...defaultSettings, palette: 8,
    customLight: [0.63, 0.12, 0.45], customDeep: [0.30, 0.13, 0.56],
    customSoft: [0.94, 0.36, 0.57], customAccent: [0.49, 0.12, 0.52] },
  onError: console.error
});
fondo.update({ speed: 0.5 });
// Al desmontar tu vista:
fondo.destroy();
```

El componente personalizado libera sus recursos al retirarlo del DOM. La API de canvas requiere `destroy()`. Ambos permiten `pause()` y `play()`, respetan Reducir movimiento y suspenden los fotogramas al ocultarse o salir de la pantalla. Cada instancia conserva su propia configuración. No se usan red, cookies ni almacenamiento. El uso de GPU depende de la resolución y del número de instancias.

## Valores habituales

| Valor | Opciones o intervalo |
|---|---|
| `palette` | 0–7 predefinidas; 8 personalizada |
| `customLight`, `customDeep`, `customSoft`, `customAccent` | RGB `[0…1, 0…1, 0…1]` |
| `backgroundStyle` | 0 completa, 1 inferior, 2 superior, 3 central, 4 orbe, 5 inverso |
| `hue` / `colorBlur` | 0–360 / 0–1 |
| `speed` / `brightness` | 0.25–2 / 0–2 |
| `shadowLight` / `deformation` | 0–0.8 / 0–4 |
| `size` / `concavity` | 0.6–1.4 / 0–0.85 |
| `sparkleShape` | 0 estrella, 1 círculo, 2 cuadrado |
| `quality` | 0 ahorro, 1 equilibrada, 2 alta |

Todos los valores y sus límites se exportan en `settingsSchema` y están tipados en `index.d.ts`. Los valores se validan y limitan automáticamente. El componente es decorativo, no captura clics y queda oculto para lectores de pantalla.

Para un script clásico puedes cargar `dist/matriz-background.umd.cjs` con `<script src="…"></script>`; expone `window.Matriz`. No se ha publicado este paquete en el registro npm: utiliza el archivo `.tgz` descargable.
