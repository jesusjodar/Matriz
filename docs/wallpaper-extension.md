# Matriz como fondo del sistema y del bloqueo

Matriz incluye `MatrizWallpaper.appex`, un proveedor del punto de extensión `com.apple.wallpaper`, dentro de `Matriz.app/Contents/Extensions/`. Publica una colección **Matriz** para los selectores de fondo y salvapantallas. El renderizado utiliza el mismo shader Metal de la app, en un proceso alojado por macOS.

1. Instala y abre Matriz para que LaunchServices registre la extensión.
2. Abre **Ajustes del Sistema → Fondo de pantalla** y elige **Matriz** en su colección.
3. En **Salvapantallas…**, selecciona el mismo fondo si quieres usarlo también en reposo. El `.saver` independiente sigue disponible en el selector de salvapantallas personalizados.

La extensión recibe el tamaño de cada superficie y las actualizaciones de actividad del sistema. Mantiene los contextos gráficos durante las reconexiones entre escritorio y bloqueo, pausa al invalidarse y libera la superficie después de un breve margen. Respeta Reducir movimiento y la resolución del perfil energético. La app publica una copia de sus ajustes visuales en el contenedor de la extensión; no restablece ni migra el dominio de preferencias del usuario para instalarla.

La captura musical y las consultas de carátulas pertenecen a la app de escritorio. Los hooks de agentes publican sus estados también en el contenedor, por lo que sus colores pueden funcionar con la extensión aunque cierres la app. La extensión usa los ajustes visuales publicados; no inicia capturas ni pide acceso a Música o Spotify en la pantalla de bloqueo. El módulo `.saver` también mantiene la paleta elegida.

## Compatibilidad

`ExtensionFoundation` es pública, pero el protocolo específico de `WallpaperExtensionKit` y `CAContext` es **privado**. Por tanto, esta integración puede requerir adaptaciones tras una actualización de macOS. Se carga el framework en tiempo de ejecución, se comprueban las clases y los campos utilizados y se rechazan conexiones XPC cuyo emisor no tenga firma de Apple. No se modifican los ficheros del sistema, los vídeos Aerial de Apple, los ajustes de contraseña ni FileVault.

El fondo del bloqueo de una sesión y la interfaz de autenticación previa al arranque de FileVault son superficies distintas. Esta extensión se dirige a la sesión del usuario; no garantiza un fondo personalizado antes del desbloqueo inicial del disco.

Elegir un proveedor de Wallpaper conserva su selección aunque se cierre la app Matriz: macOS controla el proceso de la extensión. Para volver al fondo anterior, selecciónalo en Ajustes del Sistema. La capa de escritorio tradicional de Matriz sigue retirándose al salir de la app.

## Validación

`npm run macos:check` comprueba el catálogo contra las clases reales del macOS instalado, renderiza una miniatura Metal y valida la creación del contexto remoto y de la captura IOSurface. Las pruebas no bloquean la sesión ni introducen contraseñas. El ciclo físico bloqueo → desbloqueo se comprueba aparte.

## Fuentes consultadas

- [Apple: ExtensionFoundation](https://developer.apple.com/documentation/extensionfoundation)
- [Apple: ExtensionKit y vistas alojadas](https://developer.apple.com/documentation/extensionkit/including-extension-based-ui-in-your-interface)
- [Apple: configurar el salvapantallas](https://support.apple.com/en-au/guide/mac-help/mchl4b68853d/mac)
- [Apple: ScreenSaver](https://developer.apple.com/documentation/screensaver)
- [Phosphene: proveedor Wallpaper y renderizado remoto](https://github.com/kageroumado/phosphene) — investigación de interoperabilidad con licencia MIT; atribución incluida en `macos/ThirdPartyNotices.txt` y en la extensión.

Se contrastó también el SDK local: `WallpaperExtensionKit` está en `PrivateFrameworks`, sin un módulo Swift público para desarrollar proveedores de terceros.
