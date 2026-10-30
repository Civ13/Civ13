import { test } from 'node:test';
import assert from 'node:assert/strict';
import { EventEmitter } from 'node:events';
import { PassThrough } from 'node:stream';
import path from 'node:path';
import fs from 'node:fs/promises';
import os from 'node:os';
import { createRuntimeAdapter } from './runtime-adapter.mjs';

const env = { CIV13_RUNTIME_ENABLED:'1', CIV13_RUNTIME_PYTHON:process.execPath,
  CIV13_RUNTIME_ROOT:path.resolve('fixture-root'), CIV13_RUNTIME_REVISION:'a'.repeat(40),
  CIV13_RUNTIME_SESSION:'b'.repeat(32), CIV13_RUNTIME_ROUND:'round-1', SECRET:'do-not-pass' };
function fakeSpawn(handler) {
 return (executable, args, options) => {
  const child = new EventEmitter(); child.stdout = new PassThrough();
  child.kill = () => { child.emit('close', null); };
  queueMicrotask(() => handler(child, executable, args, options)); return child;
 };
}
test('default off, fixed invocation, bounded output and isolated environment', async () => {
 const disabled = createRuntimeAdapter({}, 'bridge');
 assert.equal(disabled.enabled, false); await assert.rejects(disabled.run('recovery'), /disabled/);
 const run = createRuntimeAdapter(env, 'fixed-bridge', fakeSpawn((child, executable, args, options) => {
  assert.equal(executable, process.execPath); assert.deepEqual(args, ['-I','fixed-bridge','recovery']);
  assert.equal(options.shell, false); assert.equal(options.env.SECRET, undefined);
  assert.equal(options.env.CIV13_RUNTIME_ROOT, env.CIV13_RUNTIME_ROOT);
  child.stdout.write('{"ok":true,"ready":false}'); child.emit('close',0);
 }));
 assert.deepEqual(await run.run('recovery'), {ok:true,ready:false});
 await assert.rejects(run.run('https://example.invalid'), /method rejected/);
 const invalid = createRuntimeAdapter({...env,CIV13_RUNTIME_SESSION:'bad'}, 'fixed-bridge', () => { throw Error('must not spawn'); });
 await assert.rejects(invalid.run('recovery'), /configuration invalid/);
 const large = createRuntimeAdapter(env, 'fixed-bridge', fakeSpawn(child => child.stdout.write(Buffer.alloc(32769))));
 await assert.rejects(large.run('variables'), /unavailable/);
});

test('one request at a time and cancellation closes the owned child', async () => {
 let child;
 const adapter = createRuntimeAdapter(env, 'fixed-bridge', fakeSpawn(c => { child = c; }));
 const controller = new AbortController();
 const pending = adapter.run('recovery', controller.signal);
 await assert.rejects(adapter.run('variables'), /busy/);
 await new Promise(resolve => setImmediate(resolve));
 assert.ok(child); controller.abort();
 await assert.rejects(pending, /cancelled/);
});

test('unconfirmed child termination returns promptly and remains busy', async () => {
 let child;
 const spawn = () => {
  child = new EventEmitter(); child.stdout = new PassThrough(); child.kill = () => false; return child;
 };
 const adapter = createRuntimeAdapter(env, 'fixed-bridge', spawn);
 const controller = new AbortController();
 const pending = adapter.run('recovery', controller.signal);
 controller.abort();
 await assert.rejects(pending, /cancelled/);
 await assert.rejects(adapter.run('variables'), /busy/);
 child.emit('close', null);
});

test('closing the adapter cancels its owned child', async () => {
 let killed = false;
 const adapter = createRuntimeAdapter(env, 'fixed-bridge', () => {
  const child = new EventEmitter(); child.stdout = new PassThrough();
  child.kill = () => { killed = true; child.emit('close', null); }; return child;
 });
 const pending = adapter.run('variables'); adapter.close();
 await assert.rejects(pending, /cancelled/); assert.equal(killed, true);
});

const python = process.env.CIV13_MCP_TEST_PYTHON || (process.env.pythonLocation && path.join(
 process.env.pythonLocation, ...(process.platform === 'win32' ? ['python.exe'] : ['bin','python3'])));
test('real isolated Python bridge fails before transport when private configuration is absent', {skip: !python}, async () => {
 const dir = await fs.mkdtemp(path.join(os.tmpdir(), 'civ13-mcp-runtime-empty-'));
 try {
  const adapter = createRuntimeAdapter({...env,CIV13_RUNTIME_PYTHON:python,CIV13_RUNTIME_ROOT:dir},
   path.join(import.meta.dirname, 'runtime_bridge.py'));
  assert.deepEqual(await adapter.run('recovery'), {ok:false,error_code:'transport_unavailable'});
 } finally { await fs.rm(dir,{recursive:true,force:true}); }
});
