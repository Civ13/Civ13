import test from 'node:test';
import assert from 'node:assert/strict';
import { format, deliver, request, run, channel } from './publish.mjs';
const manifest = () => ({ schema: 1, id: 'example', commit: 'a'.repeat(40), heading: '', entries: ['Fixed crafting.'], skip: '' });
const response = (status, body, headers = {}) => ({ status, ok: status < 300, json: async () => body, headers: new Headers(headers) });
test('format, skip and negative controls', () => {
  assert.deepEqual(format(manifest()), ['- Fixed crafting.']);
  assert.deepEqual(format({ ...manifest(), entries: [], skip: 'Internal tooling only' }), []);
  for (const entry of ['@everyone', '<@123>', 'one\ntwo', 'x'.repeat(1501)])
    assert.throws(() => format({ ...manifest(), entries: [entry] }));
  assert.throws(() => format({ ...manifest(), entries: [] }));
  assert.throws(() => format({ ...manifest(), skip: 'Skip' }));
});
test('chunking is bounded and deterministic', () => {
  const m = { ...manifest(), heading: 'Crafting', entries: Array(40).fill('x'.repeat(1000)) };
  const chunks = format(m);
  assert.equal(chunks.length, 40);
  assert.ok(chunks.every(x => x.length <= 1900));
  assert.deepEqual(format(m), chunks);
});
test('durable reservation, duplicate suppression, changed content rejection', async () => {
  let stored, posts = 0;
  const adapters = { load: async () => stored, save: async (_, value) => { stored = structuredClone(value); },
    verify: async () => {}, post: async () => { assert.equal(stored.messages.at(-1).state, 'pending'); posts++; return { id: '123', channel_id: channel }; } };
  await deliver(manifest(), adapters);
  await deliver(manifest(), adapters);
  assert.equal(posts, 1);
  await assert.rejects(deliver({ ...manifest(), entries: ['Changed'] }, adapters), /changed/);
});
test('ambiguous transport and receipt failure block replay', async () => {
  for (const failAfterSend of [false, true]) {
    let stored, posts = 0;
    const adapters = { load: async () => stored, save: async (_, value) => {
      if (failAfterSend && value.messages[0]?.state === 'sent') throw Error('storage failed');
      stored = structuredClone(value);
    }, verify: async () => {}, post: async () => { posts++; if (!failAfterSend) throw Error('timeout'); return { id: '123', channel_id: channel }; } };
    await assert.rejects(deliver(manifest(), adapters));
    await assert.rejects(deliver(manifest(), adapters), /Uncertain/);
    assert.equal(posts, 1);
  }
});
test('skip sends nothing and resumes confirmed partial chunks', async () => {
  let stored, posts = 0;
  const adapters = { load: async () => stored, save: async (_, v) => { stored = structuredClone(v); }, verify: async () => {}, post: async () => { posts++; return { id: String(posts), channel_id: channel }; } };
  await deliver({ ...manifest(), entries: [], skip: 'Internal' }, adapters);
  assert.equal(posts, 0);
  stored = undefined;
  const m = { ...manifest(), entries: ['x'.repeat(1500), 'y'.repeat(1500)] };
  await deliver(m, adapters);
  stored.messages.pop();
  await deliver(m, adapters);
  assert.equal(posts, 3);
});
test('429 honors fractional retry-after; GET 5xx retries; POST 5xx stops', async () => {
  const waits = [], responses = [response(429, { retry_after: .25 }), response(200, { id: '1' })];
  assert.deepEqual(await request('https://example.invalid', { method: 'POST' }, { fetcher: async () => responses.shift(), sleep: async x => waits.push(x) }), { id: '1' });
  assert.deepEqual(waits, [250]);
  let calls = 0;
  await request('https://example.invalid', {}, { fetcher: async () => ++calls === 1 ? response(503, {}) : response(200, {}), sleep: async () => {} });
  assert.equal(calls, 2);
  calls = 0;
  await assert.rejects(request('https://example.invalid', { method: 'POST' }, { fetcher: async () => { calls++; return response(503, {}); } }));
  assert.equal(calls, 1);
});
const env = { GITHUB_REPOSITORY: 'Civ13/Civ13', GITHUB_EVENT_NAME: 'workflow_dispatch', GITHUB_REF: 'refs/heads/master' };
const event = { inputs: { manifest: 'example', commit: 'a'.repeat(40), dry_run: 'false', confirm_live: 'true' } };
const api = async path => {
  if (path === '') return { default_branch: 'master' };
  if (path.startsWith('compare/')) return { status: 'ahead' };
  if (path.startsWith('contents/')) return { type: 'file', size: 100, content: Buffer.from(JSON.stringify(manifest())).toString('base64') };
  throw Error('Unexpected API call');
};
test('missing activation/secret fails before webhook and receipt access', async () => {
  await assert.rejects(run(env, event, { api }), /disabled/);
  await assert.rejects(run({ ...env, CHANGELOG_ENABLED: 'true' }, event, { api }), /Missing/);
});
test('untrusted branches, refs, SHA and absent live confirmation rejected', async () => {
  await assert.rejects(run({ ...env, GITHUB_REF: 'refs/heads/attacker' }, event, { api }), /default branch/);
  await assert.rejects(run(env, { inputs: { ...event.inputs, commit: 'master' } }, { api }), /Full SHA/);
  await assert.rejects(run(env, { inputs: { ...event.inputs, confirm_live: 'false' } }, { api }), /confirmation/);
  await assert.rejects(run(env, event, { api: async p => p.startsWith('compare/') ? { status: 'diverged' } : api(p) }), /history/);
});
test('dry run needs no secrets and writes no receipt', async () => {
  await run(env, { inputs: { ...event.inputs, dry_run: 'true', confirm_live: 'false' } }, { api });
});
