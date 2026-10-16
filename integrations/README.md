# Matriz · Integraciones de agentes

1. Activa **Agentes de IA → Usar colores de agentes** en Matriz.
2. Instala únicamente el conector del agente que uses, siguiendo la tabla.
3. Conserva los hooks existentes al combinar los archivos. Estos archivos son ejemplos preparados para esta instalación de Matriz, no sustitutos de tus configuraciones completas.

| Agente | Instalación | Qué observa |
|---|---|---|
| Codex local / escritorio | Combina `codex-hooks.json` con `~/.codex/hooks.json`. Revisa y confía en los hooks desde Codex; instalarlos no los autoriza. | Inicio, trabajo, permisos, fin de respuesta, interrupción y cierre. El hook `Stop` indica fin de respuesta; no certifica éxito. No hay un hook de error final en el catálogo consultado: emite `error` desde un cliente propio cuando conozca el fallo. |
| Claude Code | Combina la propiedad `hooks` de `claude-hooks.json` con `~/.claude/settings.json` o `.claude/settings.json`. | Trabajo, peticiones de permiso o respuesta humana, fallos de herramienta o del turno, fin y cierre. No cubre automáticamente el chat de Claude Desktop. |
| OpenCode 2 | Crea `~/.config/opencode/plugins/matriz/tui.ts` con el contenido de `opencode-v2-tui.ts` y reinicia el TUI. Es un plugin local del terminal; no cubre `opencode run` sin interfaz. | Eventos de ejecución, permisos y formularios; usa la API v2 instalada en este Mac. |
| OpenCode v1 | Copia `opencode-matriz.js` a `~/.config/opencode/plugins/` y reinicia OpenCode. | Estados de sesión, permisos, preguntas y errores. No instales este plugin v1 en OpenCode 2. |
| Hermes | Combina `hermes-hooks.yaml` con `~/.hermes/config.yaml`. Revisa los comandos cuando Hermes los solicite. `hermes hooks doctor` comprueba la instalación. | Inicio, turnos, herramientas, esperas humanas y resultado de finalización. El ejemplo base usa los hooks comprobados en Hermes 0.21.2 de este Mac. Los hooks nuevos `on_human_input_request` y `on_human_input_resolved` permiten observar también las preguntas, pero requieren una versión que los incluya. |
| LM Studio API | Importa `withMatriz` de `lmstudio-matriz.mjs` y consume `withMatriz(response)` en lugar de `response.body` para una respuesta SSE de `POST /api/v1/chat`. | Solo las peticiones que pasan por ese cliente: trabajo, error y finalización. El servidor activo o un modelo cargado no equivalen a una generación. El ejemplo no observa el chat de escritorio ni inventa un estado de permiso. |
| Cualquier agente | Invoca el comando local indicado abajo desde su API, callback o hook de ciclo de vida. | El estado explícito que comunique el agente. |

## Comando universal

```sh
# Ruta habitual. Sustituye el ejecutable si instalaste Matriz en otra carpeta.
"$HOME/Applications/Matriz.app/Contents/MacOS/Matriz" --agent-event generic running mi-sesion
"$HOME/Applications/Matriz.app/Contents/MacOS/Matriz" --agent-event generic permission mi-sesion
"$HOME/Applications/Matriz.app/Contents/MacOS/Matriz" --agent-event generic completed mi-sesion
```

Estados: `idle`, `running`, `permission`, `input`, `error`, `completed`. Proveedores: `codex`, `claude`, `opencode`, `hermes`, `lmstudio`, `generic`. Una sesión distinta evita que trabajos simultáneos se sobrescriban. El comando no abre ventanas.

Gris: reposo. Azul: trabajando. Ámbar: permiso. Violeta: respuesta humana. Rojo: error. Verde: finalizado. Entre sesiones manda permiso → respuesta → error → trabajo → finalizado → reposo. La finalización vuelve a reposo a los 15 segundos; el error caduca al minuto. Los estados sin nuevos eventos caducan a los 30 minutos: para esperas más largas, el cliente debe renovar la señal. Al caducar recuperas tu paleta.

Matriz guarda solo proveedor, estado, fecha y un identificador de sesión convertido a hash, en `~/Library/Application Support/Matriz/AgentEvents/`, con una copia de esos metadatos en el contenedor de su extensión de Wallpaper para que también pueda mostrar los estados. Los hooks devuelven `{}` y no autorizan, deniegan ni modifican herramientas. La integración observa únicamente la sesión local donde ejecuta el comando; los agentes remotos deben transportar sus eventos al Mac mediante un canal propio.

## Documentación oficial consultada · 16/10/2026

- [Codex: hooks](https://learn.chatgpt.com/docs/hooks)
- [Codex: paquetes y revisión de hooks](https://developers.openai.com/plugins/build/plugins)
- [Claude Code: hooks](https://code.claude.com/docs/en/hooks)
- [OpenCode: plugins](https://opencode.ai/docs/plugins/)
- [OpenCode 2: plugins de terminal](https://dev.opencode.ai/v2/docs/build/plugins/cli)
- [OpenCode 2: descubrimiento de plugins](https://dev.opencode.ai/v2/docs/cli/plugins)
- [OpenCode 2: esquemas de permisos](https://github.com/anomalyco/opencode/blob/dev/packages/schema/src/permission.ts) y [formularios](https://github.com/anomalyco/opencode/blob/dev/packages/schema/src/form.ts)
- [Hermes: hooks y eventos](https://hermes-agent.nousresearch.com/docs/user-guide/features/hooks)
- [LM Studio: eventos SSE](https://lmstudio.ai/docs/developer/rest/streaming-events)
- [LM Studio: logs](https://lmstudio.ai/docs/cli/serve/log-stream) — no se usan: incluyen contenido de las conversaciones.
