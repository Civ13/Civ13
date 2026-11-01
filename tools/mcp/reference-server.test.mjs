import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { spawn } from 'node:child_process';
import { once } from 'node:events';
import { Writable } from 'node:stream';
import { Client } from '@modelcontextprotocol/sdk/client/index.js';
import { StdioClientTransport } from '@modelcontextprotocol/sdk/client/stdio.js';
import { fixture } from './reference-fixtures.mjs';
import { MAX_REQUEST_BYTES, MAX_RESPONSE_BYTES, boundedOutput } from './reference-server.mjs';

async function entrypoint({ failure = null, wide = false, unexpected = false } = {}) {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'civ13-reference-protocol-'));
  const entry = path.join(directory, 'entry.mjs');
  const data = fixture(); if (wide) data.atlas.recipes[0].conditions = 'x'.repeat(typeof wide === 'number' ? wide : 7000);
  await fs.writeFile(entry,
    `import {createReference} from ${JSON.stringify(new URL('atlas-reference.mjs', import.meta.url).href)};\n`
    + `import {startReferenceStdio} from ${JSON.stringify(new URL('reference-server.mjs', import.meta.url).href)};\n`
    + (failure ? `await startReferenceStdio({failure:${JSON.stringify(failure)}});\n`
      : `const reference=createReference(${JSON.stringify(data)});\n`
        + (unexpected ? `reference.search=()=>{throw new TypeError('PRIVATE_PATH');};\n` : '')
        + `await startReferenceStdio({reference});\n`));
  return { entry, cleanup: () => fs.rm(directory, { recursive: true, force: true }) };
}
const environment = () => ({ ...process.env, NODE_OPTIONS: '', CIV13_DM_COMPILER: 'MUST_NOT_RUN',
  CIV13_RUNTIME_ENABLED: '1', CIV13_RUNTIME_ROOT: 'MUST_NOT_READ', CIV13_RUNTIME_PYTHON: 'MUST_NOT_RUN' });
test('real stdio SDK discovery exposes exactly four read-only data tools despite privileged environment variables', async () => {
  const fixture = await entrypoint(), client = new Client({ name: 'reference-contract', version: '1' });
  const transport = new StdioClientTransport({ command: process.execPath, args: [fixture.entry], env: environment(), stderr: 'pipe' });
  try {
    await client.connect(transport);
    const tools = (await client.listTools()).tools;
    assert.deepEqual(tools.map(tool => tool.name).sort(), ['atlas_recipe', 'atlas_resource', 'atlas_search', 'docs_search']);
    assert.ok(tools.every(tool => tool.annotations.readOnlyHint && !tool.annotations.destructiveHint && !tool.annotations.openWorldHint));
    const call = (name, args = {}) => client.callTool({ name, arguments: args });
    const search = await call('atlas_search', { query: 'nomads' }); assert.equal(search.isError, undefined);
    const selected = search.structuredContent.entries[0]; assert.equal(selected.variant_id, 'r_nomads');
    const recipe = await call('atlas_recipe', { id: selected.id, variant_id: selected.variant_id });
    assert.equal(recipe.structuredContent.recipe.source.file, 'config/nomads.txt');
    assert.equal(recipe.structuredContent.recipe.inputs[0].quantity, '2 iron OR 1 steel (alternatives)');
    assert.equal((await call('atlas_resource', { id: 'proteolytic_enzyme' })).structuredContent.entries[0].route.audit_revision, 'b'.repeat(40));
    assert.equal((await call('docs_search', { query: 'Invoke' })).structuredContent.entries.length, 1);
    for (const args of [{ limit: 21 }, { query: 'x'.repeat(121) }, { offset: 10001 }, { path: '../../.env' }, { url: 'http://127.0.0.1/' }])
      assert.equal((await call('atlas_search', args)).isError, true);
    assert.equal((await call('atlas_recipe', { id: 'missing' })).structuredContent.error, 'unknown_recipe');
    assert.equal((await call('compiler_info')).isError, true);
    assert.equal((await call('runtime_recovery')).isError, true);
    await client.ping();
  } finally { await client.close(); await fixture.cleanup(); }
});
test('missing/stale artifacts allow discovery but fail lookup explicitly without runtime fetching', async () => {
  for (const failure of ['artifact_missing', 'artifact_hash_mismatch', 'artifact_revision_mismatch']) {
  const fixture = await entrypoint({ failure }), client = new Client({ name: 'missing-reference', version: '1' });
  try {
    await client.connect(new StdioClientTransport({ command: process.execPath, args: [fixture.entry], env: environment(), stderr: 'pipe' }));
    assert.equal((await client.listTools()).tools.length, 4);
    const result = await client.callTool({ name: 'atlas_search', arguments: { query: 'wood' } });
    assert.equal(result.isError, true); assert.equal(result.structuredContent.error, failure);
    assert.match(result.structuredContent.instruction, /No automatic network refresh/); await client.ping();
  } finally { await client.close(); await fixture.cleanup(); }
  }
});
async function raw(options) {
  const fixture = await entrypoint(options);
  const child = spawn(process.execPath, [fixture.entry], { windowsHide: true, env: environment(), stdio: ['pipe', 'pipe', 'pipe'] });
  child.stdin.on('error', () => {}); // Expected when testing transport closure.
  let buffer = '', diagnostic = ''; const messages = [], waits = new Map();
  child.stdout.on('data', chunk => {
    buffer += chunk.toString('utf8');
    while (buffer.includes('\n')) {
      const boundary = buffer.indexOf('\n'), line = buffer.slice(0, boundary); buffer = buffer.slice(boundary + 1);
      assert.ok(Buffer.byteLength(line + '\n') <= MAX_RESPONSE_BYTES);
      const message = JSON.parse(line); messages.push(message); const waiting = waits.get(message.id);
      if (waiting) { waits.delete(message.id); clearTimeout(waiting.timer); waiting.resolve(message); }
    }
  });
  child.stderr.on('data', chunk => { diagnostic += chunk.toString('utf8'); });
  const wait = id => new Promise((resolve, reject) => {
    const previous = messages.find(message => message.id === id); if (previous) { resolve(previous); return; }
    const timer = setTimeout(() => reject(new Error('Protocol response timeout')), 5000); waits.set(id, { resolve, timer });
  });
  const send = message => child.stdin.write(JSON.stringify(message) + '\n');
  return { child, messages, wait, send, diagnostic: () => diagnostic,
    async close() {
      child.stdin.end();
      if (child.exitCode === null) {
        const timer = setTimeout(() => child.kill(), 3000);
        try { await once(child, 'exit'); } finally { clearTimeout(timer); }
      }
      await fixture.cleanup();
    } };
}
async function initialize(peer) {
  peer.send({ jsonrpc: '2.0', id: 1, method: 'initialize', params: {
    protocolVersion: '2025-11-25', capabilities: {}, clientInfo: { name: 'raw-reference-test', version: '1' } } });
  assert.equal((await peer.wait(1)).result.serverInfo.name, 'civ13-reference');
  peer.send({ jsonrpc: '2.0', method: 'notifications/initialized' });
}
test('SDK rejects malformed envelopes/JSON and unknown methods without dispatching privileged tools or echoing diagnostics', async () => {
  const peer = await raw();
  try {
    await initialize(peer);
    peer.send({ jsonrpc: '2.0', id: 2, method: 'unsupported', params: {} }); assert.equal((await peer.wait(2)).error.code, -32601);
    peer.child.stdin.write('{bad PRIVATE_MARKER}\n');
    peer.send({ jsonrpc: '2.0', id: { invalid: 'PRIVATE_MARKER' }, method: 'tools/call', params: { name: 'atlas_search', arguments: {} } });
    peer.send({ jsonrpc: '2.0', id: 3, method: 'unsupported', params: 'invalid' });
    peer.send({ jsonrpc: '2.0', method: 'notifications/unknown' });
    peer.send({ jsonrpc: '2.0', id: 4, method: 'ping' }); await peer.wait(4);
    assert.equal(peer.messages.some(message => typeof message.id === 'object'), false);
    assert.equal(peer.messages.some(message => message.id === 3), false);
    assert.match(peer.diagnostic(), /reference_protocol_error/); assert.equal(peer.diagnostic().includes('PRIVATE_MARKER'), false);
  } finally { await peer.close(); }
});
test('full duplicated result, escaping and request ID size produce explicit result_too_large', async () => {
  const peer = await raw({ wide: 14000 });
  try {
    await initialize(peer);
    for (const id of [3, 'i'.repeat(15000)]) {
      peer.send({ jsonrpc: '2.0', id, method: 'tools/call', params: { name: 'atlas_recipe', arguments: { id: 'r_global' } } });
      const result = await peer.wait(id); assert.equal(result.id, id);
      assert.equal(result.result.isError, true); assert.equal(result.result.structuredContent.error, 'result_too_large');
    }
    peer.send({ jsonrpc: '2.0', id: 2, method: 'ping' }); await peer.wait(2);
  } finally { await peer.close(); }
});
test('the independent final wire guard retains the request ID without truncating an SDK response', async () => {
  const written = [];
  const output = new Writable({ write(chunk, _encoding, callback) { written.push(chunk.toString()); callback(); } });
  const guard = boundedOutput(output);
  guard.end(JSON.stringify({ jsonrpc: '2.0', id: 7, result: { text: 'x'.repeat(MAX_RESPONSE_BYTES) } }));
  await once(guard, 'finish');
  assert.equal(written.length, 1); assert.ok(Buffer.byteLength(written[0]) <= MAX_RESPONSE_BYTES);
  const result = JSON.parse(written[0]); assert.equal(result.id, 7); assert.equal(result.error.code, -32603);
});
test('unexpected lookup exceptions produce safe internal_error rather than artifact or argument guidance', async () => {
  const peer = await raw({ unexpected: true });
  try {
    await initialize(peer);
    peer.send({ jsonrpc: '2.0', id: 2, method: 'tools/call', params: { name: 'atlas_search', arguments: {} } });
    const result = (await peer.wait(2)).result;
    assert.equal(result.isError, true); assert.equal(result.structuredContent.error, 'internal_error');
    assert.match(result.structuredContent.instruction, /internal lookup error/);
    assert.equal(JSON.stringify(result).includes('PRIVATE_PATH'), false);
    peer.send({ jsonrpc: '2.0', id: 3, method: 'ping' }); await peer.wait(3);
  } finally { await peer.close(); }
});
test('oversized input and malformed UTF-8 close their bounded sessions', { timeout: 15000 }, async () => {
  for (const input of [Buffer.alloc(MAX_REQUEST_BYTES + 1, 32), Buffer.from([0xff, 10])]) {
    const peer = await raw();
    try {
      peer.child.stdin.write(input);
      let timer;
      try { await Promise.race([once(peer.child, 'exit'), new Promise((_resolve, reject) => { timer = setTimeout(() => reject(Error('Session did not close')), 5000); })]); }
      finally { clearTimeout(timer); }
      assert.equal(peer.messages.length, 0); assert.match(peer.diagnostic(), /reference_(protocol_error|invalid_utf8)/);
    } finally { await peer.close(); }
  }
});
