<div align="center">
  <img src="docs/images/banner.png" alt="Matriz — fondo procedural para macOS con ondas, destellos y música" width="100%">
</div>

<h1 align="center">Matriz</h1>

<p align="center">
  <strong>Un fondo procedural para macOS:</strong> ondas de luz, destellos geométricos y color que reacciona a tu música.
</p>

<p align="center">
  <img alt="macOS 14+" src="https://img.shields.io/badge/macOS-14%2B-1d1d1f?logo=apple&logoColor=white">
  <img alt="Apple Silicon" src="https://img.shields.io/badge/Apple_Silicon-arm64-4a90d9?logo=apple&logoColor=white">
  <img alt="Versión 2.2.0" src="https://img.shields.io/badge/versi%C3%B3n-2.2.0-7a5cf0">
  <img alt="Idiomas 20" src="https://img.shields.io/badge/idiomas-20-2ea44f">
</p>

<p align="center">
  <a href="https://github.com/jesusjodar/Matriz/releases"><strong>⬇️ Descargar la última versión</strong></a>
</p>

---

Matriz dibuja detrás de los iconos del escritorio, en todas las pantallas. Un campo orgánico de luz, color y destellos se mueve despacio: la profundidad anima el tamaño de cada partícula y el flujo traslada sus centros sin deformar las figuras. No usa el ratón, ni sensores, ni clics. Si lo deseas, Matriz escucha la salida de audio del Mac y sustituye su paleta por los colores de la portada que esté sonando.

## Windows y componente web

Matriz también dispone de una [aplicación Windows con ajustes nativos WinUI 3](windows/README.md) para x64 y ARM64 y un [componente web listo para integrar](packages/web/README.md). Los paquetes se generan en el [flujo multiplataforma](https://github.com/jesusjodar/Matriz/actions/workflows/multiplatform.yml), en sus artefactos de cada compilación correcta.

La web es exclusivamente visual: **sin música, IA ni ajustes visibles**. Configura los valores directamente en JavaScript o en el atributo `settings`. Incluye un [ejemplo completo](packages/web/example.html), tipos TypeScript, módulos ESM y un script clásico.

| Función | macOS | Windows | Web |
|---|---|---|---|
| Shader, paletas y ajustes visuales | Metal | WebGL2 | WebGL2 |
| Panel nativo | SwiftUI / Liquid Glass | WinUI 3 | Configuración por código |
| Audio del sistema | Core Audio Taps | WASAPI loopback | — |
| Paleta de portada | Música / Spotify | Sesiones multimedia de Windows | — |
| Estados de agentes | Hooks locales | Hooks locales | — |
| Escritorio | Todas las pantallas | Escritorio virtual de Explorer | Fondo de un contenedor HTML |
| Salvapantallas | `.saver` y extensión | — | — |
| Extensión Wallpaper / bloqueo | macOS 26+, API privada | — | — |

Los cambios futuros mantienen los tres clientes mediante un shader común, un contrato de valores en `shared/` y compilaciones de las tres plataformas. Las integraciones propias de cada sistema se mantienen fuera de la API web. La compilación automatizada de Windows no sustituye una prueba física de Explorer, sonido y reproductores.

El resto de esta guía describe la aplicación de **macOS**; consulta las guías enlazadas para instalar Windows o integrar la web.

## Índice

- [Qué es Matriz](#qué-es-matriz)
- [Galería de estilos](#galería-de-estilos)
- [El panel de ajustes](#el-panel-de-ajustes)
- [Instalación](#instalación)
- [Primeros pasos](#primeros-pasos)
- [Música y portadas](#música-y-portadas)
- [Salvapantallas y pantalla de bloqueo](#salvapantallas-y-pantalla-de-bloqueo)
- [Rendimiento](#rendimiento)
- [Privacidad](#privacidad)
- [Preguntas frecuentes](#preguntas-frecuentes)
- [Desinstalación](#desinstalación)
- [Desarrollo](#desarrollo)
- [Autor](#autor)

## Qué es Matriz

- **Fondo de escritorio animado.** Se coloca detrás de los iconos y del Finder, en todas tus pantallas, sin interferir con tu trabajo.
- **Seis composiciones.** Desde la pantalla completa hasta orbes con bordes difuminados que pueden ocupar todo el monitor.
- **Nueve paletas y color a medida.** Cuatro pigmentos ligados al relieve, con ruido orgánico y suavizado regulable; también puedes elegir tus propios colores.
- **Destellos con carácter.** Estrellas, círculos o cuadrados; tamaño según la profundidad, concavidad ajustable y desplazamiento de hasta el 400 %.
- **Música en color.** Con tu permiso, Matriz analiza el audio del sistema y toma la paleta de la portada de Música o Spotify, con transiciones interrumpibles.
- **Salvapantallas incluido.** El mismo estilo visual cuando el Mac está inactivo, con los ajustes compartidos.
- **20 idiomas completos**, incluidos árabe y hebreo con disposición de derecha a izquierda.
- **Sin cuentas, sin telemetría y sin servicios en segundo plano.** Todo ocurre en tu Mac.

## Galería de estilos

En **Apariencia → Composición** puedes elegir entre seis estilos. Sus bordes siguen el mismo campo de movimiento: se difuminan y reducen suavemente los destellos cercanos, sin cortes rectos.

| | |
|:---:|:---:|
| ![Pantalla completa](docs/images/estilo-1-pantalla-completa.png) <br> **Pantalla completa** — ondas y destellos llenan todo el fondo. | ![Onda inferior](docs/images/estilo-2-onda-inferior.png) <br> **Onda inferior** — el estilo inicial: centro más bajo y laterales elevados, con borde orgánico. |
| ![Onda superior](docs/images/estilo-3-onda-superior.png) <br> **Onda superior** — la composición inversa de la onda inferior. | ![Onda central](docs/images/estilo-4-onda-central.png) <br> **Onda central** — una franja horizontal de bordes cambiantes. |
| ![Orbe](docs/images/estilo-5-orbe.png) <br> **Orbe** — una forma redondeada con contorno difuminado, escalable del 20 % al 600 % y con centro desplazable. | ![Orbe inverso](docs/images/estilo-6-orbe-inverso.png) <br> **Orbe inverso** — un hueco central con las mismas características y controles de posición y tamaño. |

La **posición de la onda** se ajusta en los estilos inferior, superior y central (hacia arriba o hacia abajo); en los orbes se ajusta el **centro** en ambos ejes.

En **Destellos → Forma de las partículas** eliges estrellas, círculos o cuadrados. Los controles de concavidad solo aparecen con las estrellas y sus valores se conservan al cambiar de figura.

## El panel de ajustes

Al abrir Matriz desde Finder aparece su panel, con fondo negro, navegación nativa Liquid Glass y seis pestañas. Cada cambio se aplica al momento, también al salvapantallas, que comparte los mismos ajustes.

| Apariencia y color | Música y portadas |
|:---:|:---:|
| <img src="docs/images/panel-apariencia.png" width="340" alt="Panel de ajustes: Apariencia"> | <img src="docs/images/panel-musica.png" width="340" alt="Panel de ajustes: Música y portadas"> |

- **Apariencia** — composición, posición de ondas y orbes, paleta, variedad, suavizado del ruido de color, matiz, brillo, saturación y contraste.
- **Partículas** — forma, densidad, tamaño, opacidades, profundidad, luz en sombras y cambios graduales de tamaño y concavidad: los destellos pequeños tienen curvas más profundas y los grandes, menos.
- **Movimiento** — ritmo, tamaño de los volúmenes y desplazamiento, más contenido en sombras y con arrastre suave en las crestas.
- **Música** — reacción al audio, sensibilidad, intensidad, suavidad y colores de portada. La saturación de portada parte del 100 % en ajustes nuevos.
- **Agentes de IA** — paleta por estado y conectores para Codex, Claude Code, OpenCode, Hermes, LM Studio y otros agentes.
- **General** — rendimiento, salvapantallas, bloqueo y acerca de.

Las altas luces se comprimen con una curva suave antes de llegar al límite SDR. El color conserva sus proporciones y el tramado estable reduce las bandas de cuantización.

Matriz también respeta **Reducir movimiento** de macOS, que deja una imagen fija, y el **modo de bajo consumo**, que fuerza el perfil de Ahorro. El botón **Restablecer…** solo afecta a Matriz.

## Instalación

### Requisitos

- macOS 14 Sonoma o posterior. La reacción al audio requiere macOS 14.2 o posterior; la extensión de Wallpaper, macOS 26 o posterior.
- Mac con Apple Silicon. La release está compilada para arm64; en Macs Intel puedes [compilar desde el código fuente](#desarrollo).
- No se necesita ninguna cuenta ni conexión permanente a internet.

### Descarga y verificación

Descarga el archivo desde la [página de releases](https://github.com/jesusjodar/Matriz/releases) y comprueba su integridad:

```sh
curl --fail --location -o Matriz-2.2.0.zip https://github.com/jesusjodar/Matriz/releases/download/v2.2.0/Matriz-2.2.0.zip

curl --fail --location -o SHA256SUMS https://github.com/jesusjodar/Matriz/releases/download/v2.2.0/SHA256SUMS
shasum -a 256 -c SHA256SUMS
# Debe mostrar: Matriz-2.2.0.zip: OK
# SHA-256:
# 026a3d3df7bd808b000f59fbfddb00c0dd09fbf62bdc5383d824dd13facc762a
```

### Quitar la cuarentena de macOS

Matriz está firmada localmente y no está notarizada por Apple, así que macOS marca la descarga como en cuarentena. Retírala con un comando antes de abrirla (si no, verás «no se puede abrir» o «está dañada»):

```sh
unzip -q Matriz-2.2.0.zip
xattr -dr com.apple.quarantine Matriz.app Matriz.saver
```

### Instalar y abrir

La app va a `~/Applications` y el salvapantallas a `~/Library/Screen Savers`:

```sh
mkdir -p ~/Applications "$HOME/Library/Screen Savers"
cp -R Matriz.app ~/Applications/
cp -R Matriz.saver "$HOME/Library/Screen Savers/"
open ~/Applications/Matriz.app
```

### Actualizar desde una versión anterior

Consulta los [comandos completos de la versión 2.2.0](docs/releases/v2.2.0.md#instalar-o-actualizar-y-retirar-la-cuarentena): guardan los bundles anteriores como copia de seguridad antes de sustituirlos. Las preferencias existentes se conservan.

## Primeros pasos

1. Abre Matriz: aparece un icono de destellos en la barra de menús y el fondo comienza a animarse detrás de los iconos del escritorio.
2. Ve a **Ajustes…** en el menú de la barra de menús (o vuelve a abrir Matriz desde Finder) para elegir composición, paleta y movimiento.
3. En macOS 26 o posterior, elige **Matriz** en **Ajustes del Sistema → Fondo de pantalla** para usar la extensión. Desde **Salvapantallas…** puedes elegirla también para el reposo; el módulo independiente sigue disponible entre los salvapantallas personalizados.

Desde el menú de la barra de menús puedes **pausar la animación**, abrir los **ajustes**, abrir los **ajustes de salvapantallas**, consultar cómo funciona el **bloqueo** o **salir y retirar el fondo**. Al salir, se retira la capa de escritorio. Si has elegido la extensión en Fondo de pantalla, macOS conserva esa selección.

## Música y portadas

Matriz puede reaccionar al sonido que sale del Mac y tomar prestados los colores de la portada del disco que esté sonando:

1. Activa **Reacción al audio del Mac** en Música y pulsa **Activar o reintentar el audio**.
2. Activa **Usar los colores de la portada** dentro de Música → Portadas de álbumes.
3. Con Música o Spotify de escritorio ya abiertos, pulsa **Autorizar reproductores abiertos**.

Así funciona:

- **Nada de micrófono.** Core Audio Taps analiza la salida predeterminada del sistema: graves, medios, agudos y energía. El audio no se graba, no se guarda y no se envía a ningún sitio.
- **Los reproductores no se abren solos.** Cada dos segundos se comprueban los reproductores que ya estén abiertos y autorizados; si ambos suenan, se mantiene el seleccionado para evitar cambios continuos.
- **Portadas locales.** De Música se lee la portada mediante Apple Events públicos; de Spotify solo se descarga la imagen por HTTPS. Los colores se extraen en tu Mac (hasta cuatro tonos representativos, incluidos blancos, negros, grises y pasteles, en OKLab) y nunca se guardan.
- **Reacción por frecuencias.** Los graves expanden la altura de las ondas, el ancho de la franja central y el tamaño de los orbes. Los agudos modifican el contorno de los orbes y los detalles de las partículas; cada banda tiene su propia referencia de nivel.
- **Transiciones suaves.** Al cambiar de canción o de reproductor, la paleta se funde desde el color visible, sin saltos. Si no hay portada o se detiene la reproducción, vuelve a tu paleta elegida.
- **Se apaga cuando no hace falta.** La captura y las consultas se liberan al desactivar, pausar, dormir, bloquear o salir. Reducir movimiento suspende ambas funciones.

Nota: Música no garantiza portada en emisiones de streaming o radio, y los reproductores remotos (Spotify Connect, navegadores) pueden aportar sonido pero no una portada.

## Salvapantallas y pantalla de bloqueo

La app incluye una **extensión de Wallpaper** para ofrecer Matriz en **Ajustes del Sistema → Fondo de pantalla**, tanto para el escritorio como para el bloqueo y el salvapantallas del sistema. Usa el shader Metal original y recibe una copia de tus ajustes visuales. La selección del fondo del sistema persiste aunque cierres Matriz.

El módulo independiente `Matriz.saver` sigue disponible y comparte las preferencias de apariencia. La música y las carátulas se procesan únicamente en la app de escritorio.

La extensión utiliza interfaces privadas de `WallpaperExtensionKit`: una actualización de macOS puede exigir adaptaciones. No cambia contraseñas ni FileVault. Consulta la [guía de Wallpaper y bloqueo](docs/wallpaper-extension.md) y la [guía de agentes y sus fuentes oficiales](integrations/README.md).

## Rendimiento

- Una sola pasada de dibujo, sin texturas de ruido ni recursos externos, con un pipeline SDR.
- Un dispositivo, una cola y un pipeline Metal compartidos por todas las pantallas.
- Paletas y parámetros estáticos preparados en CPU al cambiar ajustes; las máscaras se omiten cuando su opacidad es cero.
- **Ahorro:** 30 FPS y escala 1×. **Equilibrado:** 60 FPS y 1,5×. **Máxima:** 60 FPS y 2×. La escala nunca supera la de tu pantalla y el modo de bajo consumo fuerza Ahorro.
- El reloj y las fases están acotados para evitar saltos al cambiar la velocidad, pausar o recrear pantallas.

Estas cifras describen el perfil de trabajo, no una garantía de cadencia para todas las GPU.

## Privacidad

- El audio **nunca se graba ni se transmite**; solo se analiza su energía y su reparto de frecuencias en memoria.
- No se guardan portadas, títulos ni audio.
- No hay cuentas, inicio de sesión, telemetría ni analítica.
- Los únicos permisos posibles (grabación de audio del sistema y automatización de reproductores) se solicitan solo cuando pulsas su botón correspondiente, y puedes revocarlos en **Privacidad y seguridad**.

## Preguntas frecuentes

**¿Matriz graba el micrófono o el sonido del Mac?**
No. Analiza la salida de audio del sistema con las API de captura de macOS, en memoria y sin conservar nada. Nunca enciende el micrófono.

**¿Por qué al salir de la app vuelve mi fondo de siempre?**
La app dibuja una capa que desaparece al salir. Además puedes elegir su extensión como fondo del sistema: esa selección la conserva macOS hasta que elijas otro fondo.

**¿Funciona en un Mac Intel?**
La release está compilada para Apple Silicon. En Intel puedes compilar el proyecto desde el código fuente; solo necesita las herramientas de Xcode.

**¿Puedo usar solo el salvapantallas?**
Sí. Instala `Matriz.saver` y selecciónalo en Ajustes del Sistema → Salvapantallas. Los ajustes de apariencia y movimiento se comparten con la app.

**¿Dónde se guardan mis ajustes?**
En las preferencias del módulo `com.matriz.screensaver`. El botón Restablecer solo afecta a Matriz; tu fondo y tus ajustes de macOS quedan intactos.

**¿Hay versión web?**
El mismo shader funciona en navegadores con WebGL2 como vista de desarrollo (`npm run dev`). La experiencia completa —panel, guardado, audio y salvapantallas— es la app nativa.

**¿Por qué mi app dice que no se puede abrir?**
Es la cuarentena de Gatekeeper con las apps no notarizadas: ejecuta `xattr -dr com.apple.quarantine Matriz.app Matriz.saver` y ábrela de nuevo.

## Desinstalación

1. Si elegiste la extensión, selecciona otro fondo en Ajustes del Sistema.
2. Sal de Matriz y elimina los dos bundles instalados:

```sh
rm -rf ~/Applications/Matriz.app "$HOME/Library/Screen Savers/Matriz.saver"
```

macOS puede conservar los permisos concedidos; revócalos en **Ajustes del Sistema → Privacidad y seguridad** si lo deseas.

## Desarrollo

El proyecto combina una versión web de vista previa (Vite, TypeScript y WebGL2) con la app nativa (AppKit, SwiftUI y Metal). El shader GLSL es la única fuente visual: la versión Metal se genera a partir de él al compilar, de modo que web y app comparten ecuaciones.

Requiere Node con npm y herramientas de Xcode. La compilación completa y las comprobaciones de la extensión de Wallpaper requieren un SDK de macOS 26 o posterior y un sistema compatible.

```sh
npm install          # dependencias de desarrollo
npm run dev          # vista web con el shader en vivo
npm run build        # compila la web en dist/
npm test             # pruebas de animación y localización
npm run macos:build  # compila Matriz.app y Matriz.saver
npm run macos:check  # verificación Metal completa + capturas de los estilos
npm run macos:install # instala las compilaciones en tu sesión
```

`macos:check` valida además el catálogo Wallpaper, el contexto remoto y la captura IOSurface. Comprueba el renderizado real, el determinismo, los ajustes, las seis composiciones, las tres geometrías, el desplazamiento al 400 %, la comunicación entre procesos, el DSP y la extracción de color. Además guarda en `~/Library/Application Support/Matriz/Build/` las capturas `Matriz-style-N.png` de cada estilo y `Matriz-styles-preview.png` con el contacto de los seis.

Estructura:

- `src/` — shader GLSL (`sparkles.frag`), página web y estilos.
- `macos/` — app, salvapantallas, renderizador Metal, audio, portadas y panel de ajustes.
- `scripts/` — compilación nativa y localización.
- `tests/` — pruebas de animación y de los 20 idiomas.
- `docs/` — imágenes del README y notas de desarrollo.
- `design/` — fuentes de diseño del icono.

Las 20 localizaciones parten de `macos/Localizable.xcstrings` y se empaquetan como recursos `.lproj` nativos. El icono está en `macos/Assets/Matriz.icon` y se compila con `actool`.

## Autor

**Jesús Jódar Piernas** — artista 3D, desarrollador y entusiasta de la tecnología.

[GitHub](https://github.com/jesusjodar) · [Portfolio](https://jesusjodar.github.io) · [LinkedIn](https://linkedin.com/in/jesujopi/) · [X](https://x.com/jesujopi3D) · [Email](mailto:jesusjodarpiernas@gmail.com)

<p align="center">Hecho con ❤️ desde España 🇪🇸</p>
