import { test } from 'node:test';
import assert from 'node:assert/strict';
import fs from 'node:fs/promises';
import path from 'node:path';
import os from 'node:os';
import { createHash } from 'node:crypto';
import { fixture, repin, writeArtifacts } from './reference-fixtures.mjs';
import { loadArtifacts, decodeArtifact, validateManifest } from './reference-artifacts.mjs';
import { acquireArtifacts, fetchArtifact } from './fetch-reference.mjs';

async function temporary(run) {
  const directory = await fs.mkdtemp(path.join(os.tmpdir(), 'civ13-reference-artifacts-'));
  try { return await run(directory); } finally { await fs.rm(directory, { recursive: true, force: true }); }
}
test('only the complete hash-pinned revision-consistent artifact set is admitted', async () => temporary(async root => {
  const data = await writeArtifacts(root);
  assert.equal((await loadArtifacts(root, data.pin)).atlas.sha, data.pin.revision);
  await fs.writeFile(path.join(root, 'atlas.json'), Buffer.alloc(data.pin.files['atlas.json'].bytes, 32));
  await assert.rejects(loadArtifacts(root, data.pin), /artifact_hash_mismatch/);
  await fs.writeFile(path.join(root, 'atlas.json'), '{}');
  await assert.rejects(loadArtifacts(root, data.pin), /artifact_size_invalid/);
}));
test('missing artifacts and mismatched build provenance have explicit failures', async () => temporary(async root => {
  await assert.rejects(loadArtifacts(path.join(root, 'missing'), fixture().pin), /artifact_missing/);
  const data = fixture(); data.build.head_sha = 'd'.repeat(40); const pinned = repin(data);
  await writeArtifacts(root, pinned);
  await assert.rejects(loadArtifacts(root, pinned.pin), /artifact_revision_mismatch/);
}));
test('links at artifact directory/components are rejected without following them', async () => temporary(async root => {
  const actual = path.join(root, 'actual'), linked = path.join(root, 'linked'), data = await writeArtifacts(actual);
  await fs.symlink(actual, linked, process.platform === 'win32' ? 'junction' : 'dir');
  await assert.rejects(loadArtifacts(linked, data.pin), /artifact_path_invalid/);
}));
test('trusted linked ancestry resolves to a canonical artifact root with exact hash checks', async () => temporary(async root => {
  const parent = path.join(root, 'actual'), linked = path.join(root, 'alias');
  const data = await writeArtifacts(path.join(parent, 'artifacts'));
  await fs.symlink(parent, linked, process.platform === 'win32' ? 'junction' : 'dir');
  const directory = path.join(linked, 'artifacts');
  assert.equal((await loadArtifacts(directory, data.pin)).atlas.sha, data.pin.revision);
  await fs.writeFile(path.join(parent, 'artifacts', 'atlas.json'), Buffer.alloc(data.pin.files['atlas.json'].bytes, 32));
  await assert.rejects(loadArtifacts(directory, data.pin), /artifact_hash_mismatch/);
}));
test('fixed corpus files cannot redirect outside the canonical root', async context => temporary(async root => {
  const directory = path.join(root, 'artifacts'), data = await writeArtifacts(directory);
  const realpath = fs.realpath;
  context.mock.method(fs, 'realpath', async candidate => path.basename(candidate) === 'atlas.json'
    ? path.join(root, 'outside.json') : realpath(candidate));
  await assert.rejects(loadArtifacts(directory, data.pin), /artifact_path_invalid/);
}));
test('a linked corpus file is rejected even when its target has the exact pinned bytes', async context => temporary(async root => {
  const directory = path.join(root, 'artifacts'), data = await writeArtifacts(directory);
  const file = path.join(directory, 'atlas.json'), outside = path.join(root, 'outside.json');
  await fs.rename(file, outside);
  try { await fs.symlink(outside, file, 'file'); }
  catch (error) {
    if (process.platform === 'win32' && error.code === 'EPERM') {
      context.skip('Windows file-symlink privilege unavailable; no security setting changed'); return;
    }
    throw error;
  }
  await assert.rejects(loadArtifacts(directory, data.pin), /artifact_path_invalid/);
}));
test('JSON and UTF-8 validation remain strict even when test pins match malformed bytes', () => {
  for (const bytes of [Buffer.from('{'), Buffer.from([0xff])]) {
    const data = fixture(), name = 'build.json';
    data.pin.files[name].bytes = bytes.length < 2 ? 2 : bytes.length;
    const body = bytes.length < 2 ? Buffer.concat([bytes, Buffer.from(' ')]) : bytes;
    data.pin.files[name].sha256 = createHash('sha256').update(body).digest('hex');
    assert.throws(() => decodeArtifact(body, name, data.pin), /artifact_json_invalid/);
  }
});
test('manifest cannot supply a new origin, extra artifact or oversized allocation', () => {
  for (const change of [pin => pin.files['atlas.json'].url = 'http://127.0.0.1/',
    pin => pin.files['extra.json'] = pin.files['atlas.json'], pin => pin.files['atlas.json'].bytes = 16 * 1024 * 1024 + 1]) {
    const data = fixture(); change(data.pin); assert.throws(() => validateManifest(data.pin), /artifact_manifest_invalid/);
  }
});
test('explicit acquisition uses exactly fixed JSON sources once and promotes atomically', async () => temporary(async root => {
  const data = fixture(), directory = path.join(root, 'output'), calls = [];
  const fetcher = async (url, options) => {
    calls.push(url); assert.equal(options.redirect, 'manual');
    const name = Object.keys(data.pin.files).find(key => data.pin.files[key].url === url);
    assert.ok(name); return new Response(data.bodies[name], { headers: { 'Content-Type': 'application/json; charset=utf-8' } });
  };
  assert.equal((await acquireArtifacts({ directory, fetcher, pin: data.pin })).state, 'verified');
  assert.equal(calls.length, 3);
  assert.equal((await acquireArtifacts({ directory, fetcher, pin: data.pin })).state, 'already_verified');
  assert.equal(calls.length, 3);
  assert.equal((await fs.readdir(root)).some(name => name.startsWith('.reference-pending-')), false);
}));
test('failed fetch never replaces an existing set or promotes partially downloaded files', async () => temporary(async root => {
  const data = fixture(), directory = path.join(root, 'output'); let calls = 0;
  const fetcher = async () => { calls++; return new Response(null, { status: 302, headers: { Location: 'https://other.test/' } }); };
  await assert.rejects(acquireArtifacts({ directory, fetcher, pin: data.pin }), /artifact_fetch_unavailable/);
  assert.equal(calls, 1); assert.deepEqual(await fs.readdir(root), []);
  await fs.mkdir(directory);
  await assert.rejects(acquireArtifacts({ directory, fetcher, pin: data.pin }), /artifact_missing/);
  assert.equal(calls, 1);
}));
test('staging, write and rename failures have a safe storage-specific error and no partial promotion', async context => temporary(async root => {
  const data = fixture();
  const fetcher = async url => {
    const name = Object.keys(data.pin.files).find(key => data.pin.files[key].url === url);
    return new Response(data.bodies[name], { headers: { 'Content-Type': 'application/json' } });
  };
  for (const operation of ['mkdtemp', 'writeFile', 'rename']) {
    context.mock.method(fs, operation, async () => { throw Object.assign(new Error('PRIVATE_PATH'), { code: 'ENOSPC' }); });
    try { await assert.rejects(acquireArtifacts({ directory: path.join(root, operation), fetcher, pin: data.pin }), /^Error: artifact_write_failed$/); }
    finally { context.mock.restoreAll(); }
    assert.deepEqual(await fs.readdir(root), []);
  }
}));
test('fetch rejects wrong MIME, size overflow, malformed body and hash drift without retries', async () => {
  const data = fixture();
  for (const make of [() => new Response(data.bodies['atlas.json'], { headers: { 'Content-Type': 'text/plain' } }),
    () => new Response(data.bodies['atlas.json'], { headers: { 'Content-Type': 'application/json', 'Content-Length': String(16 * 1024 * 1024 + 1) } }),
    () => new Response(Buffer.alloc(data.pin.files['atlas.json'].bytes + 1), { headers: { 'Content-Type': 'application/json' } }),
    () => new Response(Buffer.alloc(data.pin.files['atlas.json'].bytes, 32), { headers: { 'Content-Type': 'application/json' } })]) {
    let calls = 0;
    await assert.rejects(fetchArtifact('atlas.json', async () => { calls++; return make(); }, data.pin)); assert.equal(calls, 1);
  }
});
test('the fixed download deadline aborts a stalled request', async context => {
  context.mock.timers.enable({ apis: ['setTimeout'] });
  const pending = fetchArtifact('atlas.json', async (_url, options) => new Promise((_resolve, reject) => {
    options.signal.addEventListener('abort', () => reject(new Error('aborted')));
  }), fixture().pin);
  context.mock.timers.tick(10000); await assert.rejects(pending, /aborted/);
});
