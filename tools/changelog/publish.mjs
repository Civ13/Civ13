import { createHash } from 'node:crypto';
import { readFileSync, readdirSync } from 'node:fs';
import { pathToFileURL } from 'node:url';

export const channel = '468980578289713176';
const guild = '468979034571931648';
const shaPattern = /^[a-f0-9]{40}$/;
const idPattern = /^[a-z0-9][a-z0-9-]{0,79}$/;
const hash = x => createHash('sha256').update(JSON.stringify(x)).digest('hex');
function requireValue(ok, message) { if (!ok) throw new Error(message); }
export function format(m) {
  requireValue(m && m.schema === 1 && idPattern.test(m.id) && shaPattern.test(m.commit), 'Invalid manifest identity/commit');
  requireValue(Array.isArray(m.entries) && m.entries.length <= 40, 'Invalid entries');
  requireValue(typeof m.skip === 'string' && m.skip.length <= 300, 'skip must be a reason string');
  requireValue((m.entries.length === 0) === (m.skip.length > 0), 'Use entries OR an explicit skip reason');
  requireValue(typeof m.heading === 'string' && m.heading.length <= 120, 'Invalid heading');
  const safe = s => typeof s === 'string' && s.length > 0 && s.length <= 1500 && !/[\r\n\x00-\x1f\x7f@<>\u202e\u202d]/u.test(s);
  requireValue(!m.heading || safe(m.heading), 'Unsafe heading');
  requireValue(m.entries.every(safe), 'Unsafe/oversized entry; mentions and multiline entries are forbidden');
  if (!m.entries.length) return [];
  const chunks = [];
  let current = m.heading ? '## ' + m.heading : '';
  for (const entry of m.entries) {
    const line = '- ' + entry;
    if (current && current.length + line.length + 1 > 1900) { chunks.push(current); current = ''; }
    current += (current ? '\n' : '') + line;
  }
  if (current) chunks.push(current);
  return chunks;
}
export async function request(url, options = {}, { fetcher = fetch, sleep = ms => new Promise(r => setTimeout(r, ms)) } = {}) {
  for (let attempt = 0; attempt < 5; attempt++) {
    let response;
    try { response = await fetcher(url, { ...options, redirect: 'error', signal: AbortSignal.timeout(15000) }); }
    catch { throw new Error('Transport failed; delivery may be uncertain. Inspect receipt before retrying.'); }
    const body = await response.json().catch(() => null);
    if (response.status === 429) {
      const seconds = Number(body?.retry_after ?? response.headers.get('retry-after'));
      requireValue(Number.isFinite(seconds) && seconds > 0 && seconds <= 60, 'Rate limit requires later reconciliation');
      await sleep(Math.ceil(seconds * 1000)); continue;
    }
    if (response.status >= 500 && (!options.method || options.method === 'GET')) {
      await sleep(1000 * 2 ** attempt); continue;
    }
    requireValue(response.ok, 'HTTP ' + response.status + '; inspect receipt before retrying');
    return body;
  }
  throw new Error('Retry budget exhausted; inspect receipt');
}
export async function deliver(m, { load, save, post, verify }) {
  const chunks = format(m), digest = hash(m);
  let receipt = await load(m.id);
  if (receipt) {
    requireValue(receipt.digest === digest, 'Manifest changed after delivery began');
    requireValue(receipt.messages.every(x => x.state === 'sent'), 'Uncertain delivery: reconcile pending receipt manually');
  } else receipt = { schema: 1, digest, commit: m.commit, messages: [], skip: m.skip };
  if (!chunks.length) { await save(m.id, receipt); return receipt; }
  if (receipt.messages.length === chunks.length) return receipt;
  await verify();
  for (let i = receipt.messages.length; i < chunks.length; i++) {
    receipt.messages.push({ state: 'pending', chunk: i, contentHash: hash(chunks[i]) });
    await save(m.id, receipt); // Durable reservation BEFORE external side effect.
    const message = await post(chunks[i]);
    requireValue(/^\d+$/.test(message?.id) && message.channel_id === channel, 'Invalid Discord confirmation; delivery uncertain');
    receipt.messages[i] = { ...receipt.messages[i], state: 'sent', id: message.id };
    await save(m.id, receipt); // Failure leaves pending and forbids automatic replay.
  }
  return receipt;
}
export async function run(env, event, deps = {}) {
  requireValue(env.GITHUB_REPOSITORY === 'Civ13/Civ13', 'Unexpected repository');
  const api = deps.api ?? ((path, options) => request('https://api.github.com/repos/Civ13/Civ13/' + path, {
    ...options, headers: { Authorization: 'Bearer ' + env.GITHUB_TOKEN, Accept: 'application/vnd.github+json', 'X-GitHub-Api-Version': '2022-11-28', 'Content-Type': 'application/json' }
  }));
  const repo = await api('');
  const branch = repo.default_branch;
  let commit, name;
  const dry = env.GITHUB_EVENT_NAME === 'workflow_dispatch' && event.inputs?.dry_run !== 'false';
  if (env.GITHUB_EVENT_NAME === 'workflow_dispatch') {
    requireValue(env.GITHUB_REF === 'refs/heads/' + branch, 'Dispatch must run on default branch');
    commit = event.inputs?.commit; name = event.inputs?.manifest;
    requireValue(dry || event.inputs?.confirm_live === 'true', 'Explicit live confirmation required');
  } else {
    requireValue(env.GITHUB_EVENT_NAME === 'deployment_status' && event.deployment_status?.state === 'success', 'Not a successful deployment');
    const deployment = await api('deployments/' + event.deployment?.id);
    requireValue(deployment.environment === 'production' && deployment.production_environment === true, 'Not production');
    requireValue(deployment.ref === branch && deployment.task === 'deploy', 'Untrusted deployment ref/task');
    const statuses = await api('deployments/' + deployment.id + '/statuses');
    requireValue(statuses[0]?.id === event.deployment_status.id && statuses[0]?.state === 'success', 'Stale deployment event');
    commit = deployment.sha;
    name = deployment.payload?.changelog;
  }
  requireValue(shaPattern.test(commit) && idPattern.test(name), 'Full SHA and manifest ID required');
  const comparison = await api('compare/' + commit + '...' + encodeURIComponent(branch));
  requireValue(['ahead', 'identical'].includes(comparison.status), 'Commit must be on default branch history');
  const file = await api('contents/changelogs/' + name + '.json?ref=' + encodeURIComponent(branch));
  requireValue(file.type === 'file' && file.size <= 70000, 'Manifest must be a bounded file');
  const m = JSON.parse(Buffer.from(file.content, 'base64').toString('utf8'));
  requireValue(m.id === name && m.commit === commit, 'Manifest/ship commit mismatch');
  const chunks = format(m);
  if (dry) { console.log(JSON.stringify({ dry_run: true, manifest: name, commit, chunks, skip: m.skip }, null, 2)); return; }
  requireValue(env.CHANGELOG_ENABLED === 'true', 'Publishing disabled');
  requireValue(env.DISCORD_CHANGELOG_WEBHOOK, 'Missing DISCORD_CHANGELOG_WEBHOOK');
  const url = new URL(env.DISCORD_CHANGELOG_WEBHOOK);
  requireValue(url.protocol === 'https:' && url.hostname === 'discord.com' && /^\/api\/webhooks\/\d+\/[A-Za-z0-9_-]+$/.test(url.pathname) && !url.search && !url.hash && !url.username && !url.password, 'Invalid webhook URL');
  const stateBranch = 'discord-changelog-receipts';
  // Branch must be explicitly provisioned. Never silently fall back to ephemeral state.
  await api('git/ref/heads/' + stateBranch);
  let fileSha;
  const load = async id => {
    const directory = await api('contents/receipts?ref=' + stateBranch);
    requireValue(Array.isArray(directory), 'Invalid receipt directory');
    if (!directory.some(x => x.name === id + '.json')) return null;
    const f = await api('contents/receipts/' + id + '.json?ref=' + stateBranch);
    fileSha = f.sha;
    return JSON.parse(Buffer.from(f.content, 'base64').toString('utf8'));
  };
  const save = async (id, value) => {
    const result = await api('contents/receipts/' + id + '.json', { method: 'PUT', body: JSON.stringify({
      branch: stateBranch, message: 'Record changelog delivery ' + id,
      content: Buffer.from(JSON.stringify(value, null, 2) + '\n').toString('base64'), ...(fileSha ? { sha: fileSha } : {})
    }) });
    fileSha = result.content.sha;
  };
  const receipt = await deliver(m, {
    load, save,
    verify: async () => {
      const webhook = await request(url.href);
      requireValue(webhook.type === 1 && webhook.channel_id === channel && webhook.guild_id === guild, 'Webhook destination mismatch');
    },
    post: content => request(url.href + '?wait=true', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ content, allowed_mentions: { parse: [], users: [], roles: [], replied_user: false } }) })
  });
  console.log(JSON.stringify({ manifest: name, commit, receipt }));
}
if (process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href) {
  try {
    if (process.argv.includes('--validate')) {
      for (const file of readdirSync('changelogs').filter(x => x.endsWith('.json'))) {
        const m = JSON.parse(readFileSync('changelogs/' + file, 'utf8'));
        requireValue(file === m.id + '.json', 'Filename/ID mismatch'); format(m);
      }
    } else await run(process.env, JSON.parse(readFileSync(process.env.GITHUB_EVENT_PATH, 'utf8')));
  } catch (error) { console.error(error.message); process.exitCode = 1; }
}

