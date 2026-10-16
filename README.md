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
  <img alt="Versión 2.0.0" src="https://img.shields.io/badge/versi%C3%B3n-2.0.0-7a5cf0">
  <img alt="Idiomas 20" src="https://img.shields.io/badge/idiomas-20-2ea44f">
</p>

<p align="center">
  <a href="https://github.com/jesusjodar/Matriz/releases"><strong>⬇️ Descargar la última versión</strong></a>
</p>

---

Matriz dibuja detrás de los iconos del escritorio, en todas las pantallas. Un campo orgánico de luz, color y destellos se mueve despacio: la profundidad anima el tamaño de cada partícula y el flujo traslada sus centros sin deformar las figuras. No usa el ratón, ni sensores, ni clics. Si lo deseas, Matriz escucha la salida de audio del Mac y sustituye su paleta por los colores de la portada que esté sonando.

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
- **Nueve paletas y color a medida.** Cuatro pigmentos que se entrelazan con interferencias suaves; también puedes elegir tus propios colores.
- **Destellos con carácter.** Estrellas, círculos o cuadrados; tamaño según la profundidad, concavidad ajustable y desplazamiento de hasta el 400 %.
- **Música en color.** Con tu permiso, Matriz analiza el audio del sistema y toma la paleta de la portada de Música o Spotify, con transiciones interrumpibles.
- **Salvapantallas incluido.** El mismo estilo visual cuando el Mac está inactivo, con los ajustes compartidos.
- **20 idiomas completos**, incluidos árabe y hebreo con disposición de derecha a izquierda.
- **Sin cuentas, sin telemetría y sin servicios en segundo plano.** Todo ocurre en tu Mac.

## Galería de estilos

En **Apariencia → Composición** puedes elegir entre seis estilos. Sus bordes siguen el mismo campo de movimiento: se difuminan y reducen suavemente los destellos cercanos, sin cortes rectos.

| | |
|:---:|:---:|
| ![Pantalla completa](docs/images/estilo-1-pantalla-completa.png) <br> **Pantalla completa** — el estilo inicial: ondas y destellos llenan todo el fondo. | ![Onda inferior](docs/images/estilo-2-onda-inferior.png) <br> **Onda inferior** — centro más bajo y laterales elevados, con borde orgánico. |
| ![Onda superior](docs/images/estilo-3-onda-superior.png) <br> **Onda superior** — la composición inversa de la onda inferior. | ![Onda central](docs/images/estilo-4-onda-central.png) <br> **Onda central** — una franja horizontal de bordes cambiantes. |
| ![Orbe](docs/images/estilo-5-orbe.png) <br> **Orbe** — una forma redondeada con contorno difuminado, escalable del 20 % al 600 %. | ![Orbe inverso](docs/images/estilo-6-orbe-inverso.png) <br> **Orbe inverso** — un hueco central con las mismas características y control de tamaño. |

En **Destellos → Forma de las partículas** eliges estrellas, círculos o cuadrados. Los controles de concavidad solo aparecen con las estrellas y sus valores se conservan al cambiar de figura.

## El panel de ajustes

Al abrir Matriz desde Finder aparece su panel, con controles nativos y ocho grupos plegables. Cada cambio se aplica al momento, también al salvapantallas, que comparte los mismos ajustes.

| Apariencia y color | Música y portadas |
|:---:|:---:|
| <img src="docs/images/panel-apariencia.png" width="340" alt="Panel de ajustes: Apariencia"> | <img src="docs/images/panel-musica.png" width="340" alt="Panel de ajustes: Música y portadas"> |

- **Apariencia** — composición, paleta (o colores de portada), variedad de tonos, matiz, brillo, saturación, contraste, forma de las partículas, densidad, tamaño y opacidades.
- **Movimiento** — ritmo, tamaño de las ondas y desplazamiento de las partículas.
- **Comportamiento** — profundidad, tamaño según la profundidad y concavidad dinámica de las estrellas.
- **Música** — reacción al audio del Mac (sensibilidad, intensidad, suavidad) y colores de portada.
- **Pantalla de bloqueo** — cuándo pedir la contraseña, gestionado por macOS.
- **Salvapantallas** — activación y estilo compartido con el fondo de escritorio.
- **Rendimiento** — Ahorro de energía, Equilibrado o Máxima nitidez.
- **Acerca de** — autor, enlaces y versión instalada.

Matriz también respeta **Reducir movimiento** de macOS, que deja una imagen fija, y el **modo de bajo consumo**, que fuerza el perfil de Ahorro. El botón **Restablecer…** solo afecta a Matriz.

## Instalación

### Requisitos

- macOS 14 Sonoma o posterior. La reacción al audio requiere macOS 14.2 o posterior.
- Mac con Apple Silicon. La release está compilada para arm64; en Macs Intel puedes [compilar desde el código fuente](#desarrollo).
- No se necesita ninguna cuenta ni conexión permanente a internet.

### Descarga y verificación

Descarga el archivo desde la [página de releases](https://github.com/jesusjodar/Matriz/releases) y comprueba su integridad:

```sh
curl -L -o Matriz-2.0.0.zip https://github.com/jesusjodar/Matriz/releases/download/v2.0.0/Matriz-2.0.0.zip

shasum -a 256 Matriz-2.0.0.zip
# Debe mostrar:
# 9066fa0a57ab41cdd6a55956bbede342ed3f9a9ee827c47c4e9af24d17d50d38
```

### Quitar la cuarentena de macOS

Matriz está firmada localmente y no está notarizada por Apple, así que macOS marca la descarga como en cuarentena. Retírala con un comando antes de abrirla (si no, verás «no se puede abrir» o «está dañada»):

```sh
unzip -q Matriz-2.0.0.zip
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

### Todo en un solo comando

```sh
curl -L -o Matriz-2.0.0.zip https://github.com/jesusjodar/Matriz/releases/download/v2.0.0/Matriz-2.0.0.zip \
  && unzip -q Matriz-2.0.0.zip \
  && xattr -dr com.apple.quarantine Matriz.app Matriz.saver \
  && mkdir -p ~/Applications "$HOME/Library/Screen Savers" \
  && cp -R Matriz.app ~/Applications/ \
  && cp -R Matriz.saver "$HOME/Library/Screen Savers/" \
  && open ~/Applications/Matriz.app
```

## Primeros pasos

1. Abre Matriz: aparece un icono de destellos en la barra de menús y el fondo comienza a animarse detrás de los iconos del escritorio.
2. Ve a **Ajustes…** en el menú de la barra de menús (o vuelve a abrir Matriz desde Finder) para elegir composición, paleta y movimiento.
3. Elige Matriz como salvapantallas en **Ajustes del Sistema → Salvapantallas** si quieres el mismo estilo cuando el Mac esté inactivo.

Desde el menú de la barra de menús puedes **pausar la animación**, abrir los **ajustes**, abrir los **ajustes de salvapantallas**, consultar cómo funciona el **bloqueo** o **salir y retirar el fondo**. Al salir, reaparece tu fondo habitual sin modificar las preferencias del sistema.

## Música y portadas

Matriz puede reaccionar al sonido que sale del Mac y tomar prestados los colores de la portada del disco que esté sonando:

1. Activa **Reacción al audio del Mac** en Música y pulsa **Activar o reintentar el audio**.
2. Activa **Usar los colores de la portada** dentro de Música → Portadas de álbumes.
3. Con Música o Spotify de escritorio ya abiertos, pulsa **Autorizar reproductores abiertos**.

Así funciona:

- **Nada de micrófono.** Core Audio Taps analiza la salida predeterminada del sistema: graves, medios, agudos y energía. El audio no se graba, no se guarda y no se envía a ningún sitio.
- **Los reproductores no se abren solos.** Cada dos segundos se comprueban los reproductores que ya estén abiertos y autorizados; si ambos suenan, se mantiene el seleccionado para evitar cambios continuos.
- **Portadas locales.** De Música se lee la portada mediante Apple Events públicos; de Spotify solo se descarga la imagen por HTTPS. Los colores se extraen en tu Mac (hasta cuatro tonos dominantes, en OKLab) y nunca se guardan.
- **Transiciones suaves.** Al cambiar de canción o de reproductor, la paleta se funde desde el color visible, sin saltos. Si no hay portada o se detiene la reproducción, vuelve a tu paleta elegida.
- **Se apaga cuando no hace falta.** La captura y las consultas se liberan al desactivar, pausar, dormir, bloquear o salir. Reducir movimiento suspende ambas funciones.

Nota: Música no garantiza portada en emisiones de streaming o radio, y los reproductores remotos (Spotify Connect, navegadores) pueden aportar sonido pero no una portada.

## Salvapantallas y pantalla de bloqueo

- **Salvapantallas:** selecciona Matriz en Ajustes del Sistema → Salvapantallas. Comparte tu apariencia y tu movimiento; las funciones de música y portadas solo están activas en la app de escritorio, mientras que el salvapantallas mantiene la paleta que elijas.
- **Bloqueo:** para proteger la sesión, configura **Solicitar contraseña → Inmediatamente** en Pantalla de bloqueo. Matriz no modifica ajustes de seguridad; el formulario de contraseña, el inicio de sesión y FileVault los controla macOS.

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
Matriz no modifica tu fondo del sistema: dibuja su propia capa animada delante de él mientras se ejecuta. Al salir, la capa desaparece y reaparece tu fondo habitual.

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

1. Sal de Matriz desde su menú de la barra de menús.
2. Elimina los dos bundles instalados:

```sh
rm -rf ~/Applications/Matriz.app "$HOME/Library/Screen Savers/Matriz.saver"
```

macOS puede conservar los permisos concedidos; revócalos en **Ajustes del Sistema → Privacidad y seguridad** si lo deseas.

## Desarrollo

El proyecto combina una versión web de vista previa (Vite, TypeScript y WebGL2) con la app nativa (AppKit, SwiftUI y Metal). El shader GLSL es la única fuente visual: la versión Metal se genera a partir de él al compilar, de modo que web y app comparten ecuaciones.

Requiere Node con npm y, para la parte nativa, macOS 14+ con herramientas de Xcode.

```sh
npm install          # dependencias de desarrollo
npm run dev          # vista web con el shader en vivo
npm run build        # compila la web en dist/
npm test             # pruebas de animación y localización
npm run macos:build  # compila Matriz.app y Matriz.saver
npm run macos:check  # verificación Metal completa + capturas de los estilos
npm run macos:install # instala las compilaciones en tu sesión
```

`macos:check` valida el renderizado real, el determinismo, los ajustes, las seis composiciones, las tres geometrías, el desplazamiento al 400 %, la comunicación entre procesos, el DSP y la extracción de color. Además guarda en `~/Library/Application Support/Matriz/Build/` las capturas `Matriz-style-N.png` de cada estilo y `Matriz-styles-preview.png` con el contacto de los seis.

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
