# Cambios multiplataforma

- Matriz se mantiene para macOS, Windows y web. Todo cambio visual debe partir de `src/sparkles.frag`; Metal se genera con `scripts/metal.mjs` y Windows usa el mismo componente WebGL2 que las webs.
- `shared/settings.json` define el contrato de ajustes. Mantén sus límites, valores iniciales, presets y controles compatibles con los tres clientes. Una función exclusiva de un sistema debe declararse en la matriz de compatibilidad del README, sin anunciar paridad que no esté implementada.
- Ejecuta las pruebas compartidas y las compilaciones que afecte el cambio. La integración continua comprueba web, Windows y macOS. No presentes una compilación como una prueba física del escritorio, el audio o el bloqueo.
- Conserva siempre los ajustes existentes del usuario; no restablezcas preferencias ni cambies el fondo elegido para probar una actualización.
