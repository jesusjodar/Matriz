import { Plugin } from '@opencode/plugin/tui'
import { spawnSync } from 'node:child_process'

// Runs on the Mac hosting the TUI, including when its OpenCode server is remote.
export default Plugin.define({
  id: 'matriz.status',
  setup(context) {
    return context.data.listen(({ details }) => {
      if (!['session.execution.started', 'session.execution.succeeded', 'session.execution.failed',
        'session.execution.interrupted', 'permission.asked', 'permission.replied', 'permission.rejected',
        'form.created', 'form.replied', 'form.cancelled'].includes(details.type)) return
      const data = details.data ?? {}
      const sessionID = data.sessionID ?? data.form?.sessionID
      if (typeof sessionID !== 'string') return
      try {
        spawnSync(__EXECUTABLE__, ['--agent-hook', 'opencode'], {
          input: JSON.stringify({ type: details.type, properties: { sessionID } }),
          stdio: ['pipe', 'ignore', 'ignore'], timeout: 1000,
        })
      } catch { /* A color indicator must never interrupt the agent. */ }
    })
  },
})
