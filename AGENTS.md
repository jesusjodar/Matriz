# Cambios multiplataforma

- Matriz se mantiene para macOS, Windows y web. Todo cambio visual debe partir de `src/sparkles.frag`; Metal se genera con `scripts/metal.mjs` y Windows usa el mismo componente WebGL2 que las webs.
- `shared/settings.json` define el contrato visual y `shared/native-settings.json` las integraciones de escritorio. Mantén sus límites, valores iniciales, presets y controles compatibles con los clientes correspondientes. Una función exclusiva de un sistema debe declararse en la matriz de compatibilidad del README, sin anunciar paridad que no esté implementada.
- El componente web es solo visual: sin IA, música ni controles visibles. Sus valores se configuran en código; no expongas las integraciones de escritorio en su API ni en sus tipos.
- Ejecuta las pruebas compartidas y las compilaciones que afecte el cambio. La integración continua comprueba web, Windows y macOS. No presentes una compilación como una prueba física del escritorio, el audio o el bloqueo.
- Conserva siempre los ajustes existentes del usuario; no restablezcas preferencias ni cambies el fondo elegido para probar una actualización.
- Los ZIP de macOS deben incluir plataforma, arquitectura real y versión: `Matriz-macOS-arm64-2.3.0.zip`. Actualiza conjuntamente enlaces, notas de release y `SHA256SUMS` al renombrarlos.
