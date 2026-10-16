# Matriz para Windows

Aplicación de escritorio con ajustes nativos WinUI 3 y fondo WebGL2 alojado en WebView2. Comparte shader, valores visuales y paletas con macOS y el componente web; las integraciones de música y agentes pertenecen solo a las aplicaciones de escritorio.

## Instalar

1. Descarga el ZIP **x64** para Intel/AMD o **ARM64** para Windows en ARM y comprueba su SHA-256 con `Get-FileHash .\Matriz-Windows-x64.zip -Algorithm SHA256`.
2. Extrae **toda** la carpeta en una ubicación estable, por ejemplo `%LOCALAPPDATA%\Programs\Matriz`. No ejecutes el programa dentro del ZIP ni copies únicamente el `.exe`.
3. Abre `Matriz.exe`. Requiere Windows 10 1809 o posterior, Explorer y [Microsoft Edge WebView2 Runtime](https://developer.microsoft.com/en-us/microsoft-edge/webview2/). .NET y Windows App SDK van incluidos.

Es una aplicación portable sin firma comercial. Windows puede mostrar SmartScreen; revisa el origen del archivo antes de permitir su ejecución. No requiere permisos de administrador. Cierra la app antes de sustituir sus archivos al actualizar; no borres `%LOCALAPPDATA%\Matriz` si quieres conservar ajustes.

## Ajustes e integraciones

El panel utiliza navegación superior, controles WinUI 3, tarjetas, selectores de color y una línea de matiz. Las preferencias se guardan de forma atómica en `%LOCALAPPDATA%\Matriz\settings.json`, separadas de las del Mac.

- **Música:** activa la captura WASAPI loopback desde Música. Analiza la salida predeterminada, sin micrófono, grabación ni transmisión. Para las portadas, autoriza el acceso a las sesiones multimedia: el reproductor debe publicar su carátula mediante los controles multimedia de Windows. Se procesan en memoria y no se guardan.
- **Agentes:** activa la opción y pulsa **Open setup files**. Se exportan los mismos conectores de [la guía de agentes](../integrations/README.md), con la ruta de tu ejecutable y un adaptador PowerShell local para hooks. Añádelos a tu configuración existente sin reemplazar otros hooks. No se instalan automáticamente ni se modifican los agentes.
- **Estado genérico:** cualquier agente puede ejecutar `Matriz.exe --agent-event generic running mi-sesion`. Los estados válidos son `idle`, `running`, `input`, `permission`, `error` y `completed`. No se guardan mensajes, nombres de archivos ni contenido del trabajo. Las sesiones se identifican mediante SHA-256 y los eventos caducan.
- **Pausa:** la animación se suspende al bloquear, usar una sesión remota o detectar una aplicación a pantalla completa. Respeta Reducir movimiento del sistema y reduce calidad en ahorro de batería.

Cerrar el panel cierra Matriz y retira el fondo. No inicia automáticamente con Windows. Un error al insertar el fondo o cargar WebView2 se muestra en el panel; el botón de General permite reintentarlo.

## Compatibilidad y límites

El fondo se inserta detrás de los iconos mediante el contenedor WorkerW de Explorer. **WorkerW es un comportamiento no documentado de Explorer**: una actualización de Windows o un escritorio alternativo puede impedirlo. No cambia el fondo guardado por Windows. Esta versión abarca el escritorio virtual completo; todas las pantallas comparten la misma composición.

No incluye salvapantallas `.scr` ni fondo animado para la pantalla de bloqueo de Windows. La extensión Wallpaper de macOS es específica de Apple y no se presenta como equivalente en Windows. Audio y portadas requieren comprobarse con tus dispositivos y reproductores; el ejecutable incorpora `--self-test` para validar ajustes, persistencia, conectores y recursos sin modificar tu configuración.

## Compilar

En Windows, con Node 22 y Visual Studio con MSBuild, Windows SDK y herramientas WinUI:

```powershell
npm ci
npm run windows:prepare
msbuild windows/Matriz/Matriz.csproj /restore /t:Publish /p:Configuration=Release /p:Platform=x64 /p:RuntimeIdentifier=win-x64 /p:PublishDir="$PWD/publish/win-x64/"
```

Para ARM64 cambia `x64` por `ARM64` y `win-x64` por `win-arm64`. La integración continua compila ambas arquitecturas. [Flujo multiplataforma](https://github.com/jesusjodar/Matriz/actions/workflows/multiplatform.yml).
