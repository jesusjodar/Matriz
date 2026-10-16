import { spawnSync } from 'node:child_process'
import { randomUUID } from 'node:crypto'

function signal(state, session) {
  try {
    spawnSync(__EXECUTABLE__, ['--agent-event', 'lmstudio', state, session], { stdio: 'ignore', timeout: 1000 })
  } catch { /* Color reporting must not change a prediction's result. */ }
}

// Use with your POST /api/v1/chat response. This does not monitor other clients or the desktop chat.
export async function* withMatriz(response, session = randomUUID()) {
  if (!response.ok || !response.body) { signal('error', session); throw new Error(`LM Studio HTTP ${response.status}`) }
  const decoder = new TextDecoder()
  let buffer = '', ended = false, failed = false, discarding = false
  try {
    for await (const chunk of response.body) {
      buffer += decoder.decode(chunk, { stream: true })
      let end
      while ((end = buffer.indexOf('\n')) !== -1) {
        const line = buffer.slice(0, end).replace(/\r$/, '')
        buffer = buffer.slice(end + 1)
        if (discarding) { discarding = false; continue }
        if (!line.startsWith('event:')) continue
        const event = line.slice(6).trim()
        if (['chat.start', 'model_load.start', 'prompt_processing.start'].includes(event)) signal('running', session)
        if (event === 'error') { failed = true; signal('error', session) }
        if (event === 'chat.end') { ended = true; if (!failed) signal('completed', session) }
      }
      // Only event headers matter; a long data line is discarded without retaining model text.
      if (buffer.length > 65536) { buffer = ''; discarding = true }
      yield chunk
    }
    if (!ended && !failed) { failed = true; signal('error', session) }
  } catch (error) {
    if (!failed) signal('error', session)
    failed = true
    throw error
  } finally {
    if (!ended && !failed) signal('idle', session)
  }
}
