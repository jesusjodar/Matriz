# Matriz · Agent integrations

1. Enable **AI agents → Use agent colors** in Matriz.
2. Install only the connector for the agent you use, following the table.
3. Preserve existing hooks when merging files. These files are examples prepared for this Matriz installation, not replacements for your complete configurations.

| Agent | Installation | What it observes |
|---|---|---|
| Local / desktop Codex | Merge `codex-hooks.json` into `~/.codex/hooks.json`. Review and trust hooks in Codex; installation does not authorize them. | Start, work, permissions, end of response, interruption and shutdown. `Stop` marks the end of a response; it does not certify success. The consulted catalog has no final error hook: emit `error` from your own client when a failure is known. |
| Claude Code | Merge the `hooks` property from `claude-hooks.json` into `~/.claude/settings.json` or `.claude/settings.json`. | Work, permission or human-input requests, tool or turn failures, completion and shutdown. Does not automatically cover Claude Desktop chat. |
| OpenCode 2 | Create `~/.config/opencode/plugins/matriz/tui.ts` using `opencode-v2-tui.ts` and restart the TUI. This is a local terminal plugin; it does not cover headless `opencode run`. | Execution events, permissions and forms; uses the v2 API installed on the development Mac. |
| OpenCode v1 | Copy `opencode-matriz.js` to `~/.config/opencode/plugins/` and restart OpenCode. | Session states, permissions, questions and errors. Do not install this v1 plugin in OpenCode 2. |
| Hermes | Merge `hermes-hooks.yaml` into `~/.hermes/config.yaml`. Review commands when Hermes asks. `hermes hooks doctor` checks installation. | Start, turns, tools, human waits and completion results. The base example uses hooks checked with Hermes 0.21.2 on the development Mac. New `on_human_input_request` and `on_human_input_resolved` hooks also observe questions, but require a version that includes them. |
| LM Studio API | Import `withMatriz` from `lmstudio-matriz.mjs` and consume `withMatriz(response)` instead of `response.body` for an SSE response from `POST /api/v1/chat`. | Only requests passing through that client: work, error and completion. An active server or loaded model does not mean generation is running. The example does not observe desktop chat or invent a permission state. |
| Any agent | Invoke the local command below from its API, callback or lifecycle hook. | The explicit state reported by the agent. |

## Universal command

```sh
# Typical path. Replace the executable if Matriz is installed elsewhere.
"$HOME/Applications/Matriz.app/Contents/MacOS/Matriz" --agent-event generic running my-session
"$HOME/Applications/Matriz.app/Contents/MacOS/Matriz" --agent-event generic permission my-session
"$HOME/Applications/Matriz.app/Contents/MacOS/Matriz" --agent-event generic completed my-session
```

States: `idle`, `running`, `permission`, `input`, `error`, `completed`. Providers: `codex`, `claude`, `opencode`, `hermes`, `lmstudio`, `generic`. Separate session IDs prevent concurrent jobs from overwriting one another. The command does not open windows.

Gray: idle. Blue: working. Amber: permission. Violet: human input. Red: error. Green: completed. Across sessions, priority is permission → input → error → running → completed → idle. Completion returns to idle after 15 seconds; errors expire after one minute. States without new events expire after 30 minutes: for longer waits, the client must renew the signal. Expiration restores your palette.

Matriz stores only the provider, state, date and a hashed session ID in `~/Library/Application Support/Matriz/AgentEvents/`, with a copy of that metadata in its Wallpaper extension container so it can also show states. Hooks return `{}` and do not authorize, deny or modify tools. The integration observes only the local session running the command; remote agents must transport events to the Mac through their own channel.

## Official documentation consulted · 2026-10-16

- [Codex: hooks](https://learn.chatgpt.com/docs/hooks)
- [Codex: packages and hook review](https://developers.openai.com/plugins/build/plugins)
- [Claude Code: hooks](https://code.claude.com/docs/en/hooks)
- [OpenCode: plugins](https://opencode.ai/docs/plugins/)
- [OpenCode 2: terminal plugins](https://dev.opencode.ai/v2/docs/build/plugins/cli)
- [OpenCode 2: plugin discovery](https://dev.opencode.ai/v2/docs/cli/plugins)
- [OpenCode 2: permission schemas](https://github.com/anomalyco/opencode/blob/dev/packages/schema/src/permission.ts) and [forms](https://github.com/anomalyco/opencode/blob/dev/packages/schema/src/form.ts)
- [Hermes: hooks and events](https://hermes-agent.nousresearch.com/docs/user-guide/features/hooks)
- [LM Studio: SSE events](https://lmstudio.ai/docs/developer/rest/streaming-events)
- [LM Studio: logs](https://lmstudio.ai/docs/cli/serve/log-stream) — not used: they include conversation content.
