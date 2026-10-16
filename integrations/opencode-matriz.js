import { spawnSync } from 'node:child_process'

// OpenCode v1 plugin API. Payloads deliberately omit prompts, arguments and errors.
export const MatrizStatus = async () => ({
  event: async ({ event }) => {
    if (!['session.created', 'session.deleted', 'session.status', 'session.idle', 'session.error',
      'permission.asked', 'permission.replied', 'question.asked', 'question.replied', 'question.rejected'].includes(event.type)) return
    const properties = event.properties ?? {}
    const payload = { type: event.type, properties: {
      sessionID: properties.sessionID ?? properties.info?.id ?? 'main',
      status: { type: properties.status?.type },
    } }
    try {
      spawnSync(__EXECUTABLE__, ['--agent-hook', 'opencode'], {
        input: JSON.stringify(payload), stdio: ['pipe', 'ignore', 'ignore'], timeout: 1000,
      })
    } catch { /* A color indicator must never interrupt the agent. */ }
  },
})
