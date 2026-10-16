import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import vm from 'node:vm'

function template(file, extra = {}) {
  const calls = []
  const context = vm.createContext({ TextDecoder, randomUUID: () => 'test-session',
    spawnSync: (...args) => { calls.push(args); return { status: 0 } }, ...extra })
  const source = readFileSync(new URL(`../integrations/${file}`, import.meta.url), 'utf8')
    .replace(/^import .*\n/gm, '').replaceAll('__EXECUTABLE__', '"/Applications/Matriz.app/Contents/MacOS/Matriz"')
    .replace('export const MatrizStatus', 'var MatrizStatus').replace('export async function*', 'async function*')
    .replace('export default Plugin.define(', 'var plugin = Plugin.define(')
  vm.runInContext(source, context)
  return { context, calls }
}

test('OpenCode 1 strips conversation data and reports the right session', async () => {
  const { context, calls } = template('opencode-matriz.js')
  const plugin = await context.MatrizStatus()
  await plugin.event({ event: { type: 'session.status', properties: {
    sessionID: 'abc', status: { type: 'busy' }, prompt: 'private', arguments: { secret: true },
  } } })
  const payload = JSON.parse(calls[0][2].input)
  assert.deepEqual(payload, { type: 'session.status', properties: { sessionID: 'abc', status: { type: 'busy' } } })
  await plugin.event({ event: { type: 'message.updated', properties: { text: 'private' } } })
  assert.equal(calls.length, 1)
})

test('OpenCode 2 uses its local TUI lifecycle and preserves unsubscribe', () => {
  let listener
  const unsubscribe = () => {}
  const { context, calls } = template('opencode-v2-tui.ts', { Plugin: { define: value => value } })
  assert.equal(context.plugin.setup({ data: { listen: fn => { listener = fn; return unsubscribe } } }), unsubscribe)
  listener({ details: { type: 'session.execution.started', data: { sessionID: 's', text: 'private' } } })
  listener({ details: { type: 'form.created', data: { form: { sessionID: 's', question: 'private' } } } })
  listener({ details: { type: 'session.execution.failed', data: {} } })
  assert.equal(calls.length, 2)
  assert.deepEqual(JSON.parse(calls[1][2].input), { type: 'form.created', properties: { sessionID: 's' } })
})

test('LM Studio observes chunked SSE without changing bytes or masking errors', async () => {
  const { context, calls } = template('lmstudio-matriz.mjs')
  const chunks = ['eve', 'nt: chat.start\r\ndata: {"secret":true}\n\nevent: error\n\n', 'event: chat.end\n\n'].map(x => new TextEncoder().encode(x))
  const response = { ok: true, body: (async function* () { yield* chunks })() }
  const output = []
  for await (const chunk of context.withMatriz(response)) output.push(chunk)
  assert.deepEqual(output, chunks)
  assert.deepEqual(calls.map(x => x[1][2]), ['running', 'error'])
  assert.ok(calls.every(x => x[2].stdio === 'ignore'))
})

test('LM Studio completes, clears cancellation and rejects truncated streams', async () => {
  for (const [input, expected] of [
    ['event: chat.start\n\nevent: chat.end\n\n', ['running', 'completed']],
    ['event: chat.start\n\n', ['running', 'error']],
    ['data: ' + 'x'.repeat(70000) + '\nevent: chat.start\n\nevent: chat.end\n\n', ['running', 'completed']],
  ]) {
    const { context, calls } = template('lmstudio-matriz.mjs')
    const bytes = new TextEncoder().encode(input)
    const body = (async function* () { yield bytes.slice(0, 67000); yield bytes.slice(67000) })()
    for await (const _ of context.withMatriz({ ok: true, body })) {}
    assert.deepEqual(calls.map(x => x[1][2]), expected)
  }
  const { context, calls } = template('lmstudio-matriz.mjs')
  const body = (async function* () { yield new TextEncoder().encode('event: chat.start\n\n'); yield new Uint8Array() })()
  for await (const _ of context.withMatriz({ ok: true, body })) break
  assert.deepEqual(calls.map(x => x[1][2]), ['running', 'idle'])
})
