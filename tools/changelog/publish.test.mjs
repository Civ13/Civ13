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
const github = 'https://api.github.com/repos/Civ13/Civ13';
const discord = 'https://discord.com/api/webhooks/1/token?wait=true';
test('GitHub primary 403 observes the reset before retrying a proven-rejected write', async () => {
  const now = 1_700_000_000_000, waits = [];
  const replies = [
    response(403, {}, { 'x-ratelimit-remaining': '0', 'x-ratelimit-reset': String(now / 1000 + 75), 'Retry-After': '60' }),
    response(200, { content: { sha: 'written' } })
  ];
  const result = await request(github, { method: 'PUT' }, {
    now: () => now, sleep: async delay => waits.push(delay), fetcher: async () => replies.shift()
  });
  assert.equal(result.content.sha, 'written');
  assert.deepEqual(waits, [76_000]);
});
test('GitHub secondary 403 backs off exponentially; permission 403 is not retried', async () => {
  const waits = [];
  let calls = 0;
  await assert.rejects(request(github, {}, {
    sleep: async delay => waits.push(delay),
    fetcher: async () => { calls++; return response(403, { message: 'You have exceeded a secondary rate limit.' }); }
  }), /GitHub rate limit/);
  assert.equal(calls, 3);
  assert.deepEqual(waits, [60_000, 120_000]);
  calls = 0;
  await assert.rejects(request(github, {}, {
    sleep: async () => assert.fail('ordinary permission errors should not wait'),
    fetcher: async () => { calls++; return response(403, { message: 'Resource not accessible by integration' }); }
  }), /HTTP 403/);
  assert.equal(calls, 1);
});
test('Discord honors a Retry-After date and stops instead of exceeding a shared wait budget', async () => {
  const now = Date.parse('Wed, 25 Nov 2026 10:00:00 GMT'), waits = [];
  const rateBudget = { remaining: 180_000 };
  const replies = [
    response(429, {}, { 'Retry-After': new Date(now + 75_000).toUTCString() }),
    response(200, {}),
    response(429, { retry_after: 106 })
  ];
  const deps = { now: () => now, sleep: async delay => waits.push(delay), fetcher: async () => replies.shift(), rateBudget };
  await request(discord, {}, deps);
  await assert.rejects(request(discord, { method: 'POST' }, deps), /Discord rate limit/);
  assert.deepEqual(waits, [75_000]);
  assert.equal(rateBudget.remaining, 105_000);
  assert.equal(replies.length, 0);
});
test('a definitively rejected Discord chunk releases only its own reservation for replay', async () => {
  const m = { ...manifest(), entries: ['x'.repeat(1500), 'y'.repeat(1500)] };
  let stored, sent = 0, attempts = 0;
  const http = async () => {
    attempts++;
    if (attempts === 2) return response(429, { retry_after: 181 });
    return response(200, { id: String(++sent), channel_id: channel });
  };
  const adapters = { load: async () => stored, save: async (_, value) => { stored = structuredClone(value); },
    verify: async () => {}, post: async () => request(discord, { method: 'POST' }, { fetcher: http }) };
  await assert.rejects(deliver(m, adapters), /rate limit/);
  assert.deepEqual(stored.messages.map(({ state, id }) => [state, id]), [['sent', '1']]);
  await deliver(m, adapters);
  await deliver(m, adapters);
  assert.deepEqual(stored.messages.map(({ state, id }) => [state, id]), [['sent', '1'], ['sent', '2']]);
  assert.equal(attempts, 3);
});
test('an ambiguous POST after a throttle, or a failed cleanup write, still blocks replay', async () => {
  for (const cleanupFails of [false, true]) {
    let stored, calls = 0;
    const adapters = { load: async () => stored, save: async (_, value) => {
      if (cleanupFails && value.messages.length === 0) throw Error('receipt write failed');
      stored = structuredClone(value);
    }, verify: async () => {}, post: async () => request(discord, { method: 'POST' }, {
      sleep: async () => {}, fetcher: async () => {
        calls++;
        if (cleanupFails) return response(429, { retry_after: 181 });
        if (calls === 1) return response(429, { retry_after: .25 });
        return response(500, {});
      }
    }) };
    await assert.rejects(deliver(manifest(), adapters), cleanupFails ? /receipt write failed/ : /HTTP 500/);
    await assert.rejects(deliver(manifest(), adapters), /Uncertain delivery/);
    assert.equal(stored.messages[0].state, 'pending');
    assert.equal(calls, cleanupFails ? 1 : 2);
  }
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
test('destination mismatch prevents POST; valid destination suppresses mentions', async () => {
  const live = { ...env, CHANGELOG_ENABLED: 'true', DISCORD_CHANGELOG_WEBHOOK: 'https://discord.com/api/webhooks/123/token' };
  for (const wrong of [true, false]) {
    let posts = 0, stored;
    const liveApi = async (path, options) => {
      if (path.startsWith('git/ref/')) return {};
      if (path.includes('.json?ref=discord-changelog-receipts')) return null;
      if (path.startsWith('contents/receipts/')) { stored = JSON.parse(Buffer.from(JSON.parse(options.body).content, 'base64')); return { content: { sha: 'receipt-sha' } }; }
      return api(path);
    };
    const http = async (url, options) => {
      if (!options) return { type: 1, guild_id: '468979034571931648', channel_id: wrong ? '999' : channel };
      posts++;
      assert.equal(stored.messages[0].state, 'pending');
      assert.ok(url.endsWith('?wait=true'));
      assert.deepEqual(JSON.parse(options.body).allowed_mentions.parse, []);
      return { id: '123', channel_id: channel };
    };
    if (wrong) await assert.rejects(run(live, event, { api: liveApi, http }), /destination/);
    else await run(live, event, { api: liveApi, http });
    assert.equal(posts, wrong ? 0 : 1);
  }
});
test('production events require trusted deployment and latest successful status', async () => {
  const deploymentEvent = { deployment: { id: 42 }, deployment_status: { id: 43, state: 'success' } };
  const production = { environment: 'production', production_environment: true, ref: 'master', task: 'deploy', sha: 'a'.repeat(40), payload: { changelog: 'example' } };
  for (const override of [{ ref: 'attacker' }, { environment: 'preview' }, { production_environment: false }]) {
    await assert.rejects(run({ ...env, GITHUB_EVENT_NAME: 'deployment_status' }, deploymentEvent, { api: async p => p === 'deployments/42' ? { ...production, ...override } : api(p) }));
  }
  await assert.rejects(run({ ...env, GITHUB_EVENT_NAME: 'deployment_status' }, deploymentEvent, { api: async p => p === 'deployments/42' ? production : p.endsWith('/statuses') ? [{ id: 44, state: 'success' }] : api(p) }), /Stale/);
});
test('malformed webhook fails without external request', async () => {
  for (const url of ['http://discord.com/api/webhooks/1/token', 'https://evil.invalid/api/webhooks/1/token', 'https://discord.com/api/webhooks/1/token?wait=true']) {
    await assert.rejects(run({ ...env, CHANGELOG_ENABLED: 'true', DISCORD_CHANGELOG_WEBHOOK: url }, event, { api, http: async () => { throw Error('Should not call'); } }), /Invalid webhook/);
  }
});
