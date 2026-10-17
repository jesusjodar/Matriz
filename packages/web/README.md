# Matriz for the web

A WebGL2 background with no runtime dependencies, visible controls, music or agent integration. It shares the desktop apps' visual shader. Requires WebGL2; if unavailable, keep your CSS background and listen for `matriz-error` to provide a fallback.

## Direct use

Extract the web package and serve its files over HTTP. Open `example.html` to try it. Do not open the HTML through `file://`.

```html
<style>
  .hero { position: relative; isolation: isolate; min-height: 500px; background: #000; }
  .hero > .content { position: relative; }
</style>
<section class="hero">
  <matriz-background id="background"></matriz-background>
  <div class="content"><h1>Your content</h1></div>
</section>
<script type="module">
  import './dist/matriz-background.js';
  document.querySelector('#background').settings = {
    palette: 5, backgroundStyle: 0, speed: 0.7,
    brightness: 1, shadowLight: 0.32, colorBlur: 0.65,
    size: 1, deformation: 2, quality: 1
  };
</script>
```

Apply changes by assigning `element.settings = { ...values }`; omitted values are retained. You can also set a JSON attribute `settings='{"palette":5,"speed":0.7}'` before connecting the element. No forms, buttons or panels are created.

## In an npm project

```sh
npm install ./matriz-background-2.3.0.tgz
```

```js
import { createMatriz, defaultSettings } from '@matriz/background';
// The canvas needs an explicit CSS size, for example:
// canvas { width: 100%; height: 500px; display: block; }
const background = createMatriz(document.querySelector('canvas'), {
  settings: { ...defaultSettings, palette: 8,
    customLight: [0.63, 0.12, 0.45], customDeep: [0.30, 0.13, 0.56],
    customSoft: [0.94, 0.36, 0.57], customAccent: [0.49, 0.12, 0.52] },
  onError: console.error
});
background.update({ speed: 0.5 });
// When unmounting your view:
background.destroy();
```

The custom element releases its resources when removed from the DOM. The canvas API requires `destroy()`. Both support `pause()` and `play()`, respect Reduce Motion and suspend frames when hidden or offscreen. Each instance retains its own configuration. No network, cookies or storage are used. GPU usage depends on resolution and the number of instances.

## Common settings

| Setting | Options or range |
|---|---|
| `palette` | 0–7 presets; 8 custom |
| `customLight`, `customDeep`, `customSoft`, `customAccent` | RGB `[0…1, 0…1, 0…1]` |
| `backgroundStyle` | 0 full screen, 1 lower, 2 upper, 3 center, 4 orb, 5 inverse |
| `hue` / `colorBlur` | 0–360 / 0–1 |
| `speed` / `brightness` | 0.25–2 / 0–2 |
| `shadowLight` / `deformation` | 0–0.8 / 0–4 |
| `size` / `concavity` | 0.6–1.4 / 0–0.85 |
| `sparkleShape` | 0 star, 1 circle, 2 square |
| `quality` | 0 energy saving, 1 balanced, 2 high |

All values and limits are exported in `settingsSchema` and typed in `index.d.ts`. Values are automatically validated and clamped. The component is decorative, does not capture clicks and is hidden from screen readers.

For a classic script, load `dist/matriz-background.umd.cjs` with `<script src="…"></script>`; it exposes `window.Matriz`. This package is not published to the npm registry: use the downloadable `.tgz` archive.
