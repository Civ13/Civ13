import test from 'node:test';
import assert from 'node:assert/strict';
import { changelogLine, run, channel } from './publish.mjs';
import { checkQueues } from './check-queues.mjs';
import { checkPR } from './check-pr.mjs';
import { readFileSync, mkdtempSync, writeFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { spawnSync } from 'node:child_process';

// Exact malformed tail from PR #3184 before its description was corrected.
const incidentTail = 'Changelog: required\nLauncher update failures now include safe diagnostic codes to help identify connection problems without exposing private error text.';
const flattenedTail = 'Changelog: required  Player changelog: Nomads TEST gains automatic updates that save the world before restarting and restore the saved round afterward. Update failures stop the updater for investigation. Availability remains pending installation and runtime verification.';

test('actual edited PR event CLI rejects the incident and accepts corrected same-line text', () => {
  const dir = mkdtempSync(join(tmpdir(), 'changelog-pr-'));
  try {
    const eventPath = join(dir, 'event.json');
    for (const newline of ['\n', '\r\n', '\r\r\n']) {
      const invalid = incidentTail.replaceAll('\n', newline);
      const corrected = invalid.replace('required' + newline, '');
      for (const [body, status] of [[invalid, 1], [flattenedTail, 1], [corrected, 0], ['Changelog:', 0]]) {
        writeFileSync(eventPath, JSON.stringify({ action: 'edited', pull_request: { body } }));
        const result = spawnSync(process.execPath, ['tools/changelog/check-pr.mjs'], {
          env: { ...process.env, GITHUB_EVENT_PATH: eventPath }, encoding: 'utf8',
        });
        assert.equal(result.status, status, result.stderr);
        if (status === 1) assert.match(result.stderr, /placeholder/);
      }
    }
  } finally { rmSync(dir, { recursive: true, force: true }); }
});

test('publisher queue compatibility guard rejects dropped runs and unknown queue syntax', () => {
  const valid = 'concurrency:\n  group: discord-changelog\n  cancel-in-progress: false\n  queue: max\njobs:\n';
  const files = { 'changelog.yml': valid, 'changelog-merge.yml': valid };
  checkQueues(files);
  for (const invalid of [valid.replace('max', 'single'), valid.replace('false', 'true'), valid.replace('  queue: max\n', ''), valid.replace('discord-changelog', 'another-group')]) assert.throws(() => checkQueues({ ...files, 'changelog-merge.yml': invalid }));
  assert.throws(() => checkQueues({ ...files, 'other.yml': 'concurrency:\n  queue: nonsense\n' }));
});

test('only an explicit visible single line opts in', () => {
  for (const body of [null, '', 'Ordinary description', 'Changelog:', 'Changelog:  ', '<!-- Changelog: example -->', '```md\nChangelog: example\n```', '> Changelog: quoted', '    Changelog: code']) assert.equal(changelogLine(body), null);
  assert.equal(changelogLine('Details\r\nChangelog: Fixed crafting.\r\nMore details'), 'Fixed crafting.');
  for (const body of ['Changelog: one\nChangelog: two', 'Changelog: @everyone', 'Changelog: <@123>', 'Changelog: ' + 'x'.repeat(1501)]) assert.throws(() => changelogLine(body));
});

test('placeholder markers and template prompts fail the publisher and PR description check', () => {
  for (const marker of ['required', 'REQUIRED.', '**required**', '[TODO]', '`TBD`', 'to be determined',
    'FIXME', 'optional', 'placeholder', 'example', 'none', 'N/A', 'your changelog here',
    'Enter your changelog here', 'Describe the player-visible change', 'Replace the changelog text']) {
    const body = `Changelog: ${marker}\nLauncher update failures now include safe diagnostic codes.`;
    assert.throws(() => changelogLine(body), /placeholder/);
    assert.throws(() => checkPR({ pull_request: { body } }), /placeholder/);
  }
  const text = 'Launcher update failures now include safe diagnostic codes to help identify connection problems without exposing private error text.';
  assert.equal(checkPR({ pull_request: { body: `Changelog: ${text}\n\nVerification: offline checks passed.` } }), text);
  assert.equal(changelogLine('Changelog: Required tools are shown before crafting.'), 'Required tools are shown before crafting.');
  assert.equal(changelogLine('Changelog: Added a TODO list to the journal.'), 'Added a TODO list to the journal.');
  assert.throws(() => checkPR({}), /PR event/);
});

test('installed template and documented placeholder labels do not become announcements', () => {
  const template = readFileSync('.github/pull_request_template.md', 'utf8');
  assert.equal(checkPR({ pull_request: { body: template } }), null);
  assert.equal(changelogLine('## Changelog: required\n<!-- Changelog: TODO -->\n```text\nChangelog: required\n```'), null);
  const filled = template.replace(/Changelog:\s*$/, 'Changelog: Fixed crafting cancellation.');
  assert.equal(checkPR({ pull_request: { body: filled } }), 'Fixed crafting cancellation.');
});

test('flattened placeholder with a second player changelog label is rejected', () => {
  // The actual PR #3174 paragraph is not an opt-in; moving its field onto a
  // separate line must not make its required marker publishable.
  assert.equal(changelogLine('Description.  ' + flattenedTail), null);
  for (const body of [flattenedTail, flattenedTail.replace('required', '**TODO**'),
    flattenedTail.replace('required  Player changelog:', 'TBD. PLAYER CHANGELOG :')]) {
    assert.throws(() => changelogLine(body), /placeholder/);
    assert.throws(() => checkPR({ pull_request: { body } }), /placeholder/);
  }
});

const commit = 'b'.repeat(40);
const pr = { number: 42, merged: true, body: 'Changelog: Fixed crafting.', merge_commit_sha: commit, base: { ref: 'master', repo: { full_name: 'Civ13/Civ13' } } };
const event = () => ({ action: 'closed', number: 42, pull_request: structuredClone(pr) });
const env = { GITHUB_REPOSITORY: 'Civ13/Civ13', GITHUB_EVENT_NAME: 'pull_request_target', MERGE_CHANGELOG_ENABLED: 'true', DISCORD_CHANGELOG_WEBHOOK: 'https://discord.com/api/webhooks/123/token' };

test('repeated CR before LF preserves explicit single-line changelogs', () => {
  const newline = '\r\r\n'; // Windows text output can translate an existing CRLF again.
  assert.equal(changelogLine(`Details${newline}changelog: Fixed crafting.${newline}`), 'Fixed crafting.');
  assert.throws(() => changelogLine(`Changelog: one${newline}Changelog: two${newline}`), /only one/);
  assert.equal(changelogLine(`\`\`\`md${newline}Changelog: example${newline}\`\`\`${newline}`), null);
  assert.equal(changelogLine(`> Changelog: quoted${newline}`), null);
  assert.equal(changelogLine(`Changelog: first\rsecond${newline}`), null);
});

function harness() {
  let stored, posts = 0;
  const api = async (path, options) => {
    if (path === '') return { default_branch: 'master' };
    if (path === 'pulls/42') return pr;
    if (path.startsWith('compare/')) return { status: 'ahead' };
    if (path.startsWith('git/ref/')) return {};
    if (path === 'contents/receipts/pr-42.json?ref=discord-changelog-receipts') return stored ? { type: 'file', size: 100, sha: 'receipt', content: Buffer.from(JSON.stringify(stored)).toString('base64') } : null;
    if (path === 'contents/receipts/pr-42.json') { stored = JSON.parse(Buffer.from(JSON.parse(options.body).content, 'base64')); return { content: { sha: 'receipt' } }; }
    throw Error('Unexpected API path: ' + path);
  };
  const http = async (_, options) => {
    if (!options) return { type: 1, channel_id: channel, guild_id: '468979034571931648' };
    assert.equal(stored.messages[0].state, 'pending');
    assert.equal(JSON.parse(options.body).content, '- Fixed crafting.');
    assert.deepEqual(JSON.parse(options.body).allowed_mentions.parse, []);
    posts++; return { id: '123', channel_id: channel };
  };
  return { api, http, posts: () => posts };
}
test('merged PR sends once and rejects changed content on replay', async () => {
  const h = harness();
  await run(env, event(), h); await run(env, event(), h);
  assert.equal(h.posts(), 1);
  const changed = event(); changed.pull_request.body = 'Changelog: Different.';
  await assert.rejects(run(env, changed, h), /changed/);
  assert.equal(h.posts(), 1);
});
test('merged CRCRLF event uses the same guarded receipt and suppresses replay', async () => {
  const h = harness();
  const e = event();
  e.pull_request.body = 'Details\r\r\nchangelog: Fixed crafting.\r\r\n';
  await run(env, e, h);
  await run(env, e, h);
  assert.equal(h.posts(), 1);
});
test('absent or blank fields require no credentials or external effects', async () => {
  for (const body of [null, 'Description', 'Changelog:']) {
    const e = event(); e.pull_request.body = body;
    await run({ ...env, MERGE_CHANGELOG_ENABLED: '', DISCORD_CHANGELOG_WEBHOOK: '' }, e, { api: async path => { assert.equal(path, ''); return { default_branch: 'master' }; }, http: async () => { throw Error('Must not call Discord'); } });
  }
});

test('placeholder merge rejects before receipt writes, credential checks or Discord access', async () => {
  for (const body of [incidentTail, flattenedTail]) {
    const e = event(); e.pull_request.body = body;
    const calls = [];
    await assert.rejects(run({ ...env, MERGE_CHANGELOG_ENABLED: '', DISCORD_CHANGELOG_WEBHOOK: '' }, e, {
      api: async path => { calls.push(path); assert.equal(path, ''); return { default_branch: 'master' }; },
      http: async () => { throw Error('Must not contact Discord'); },
    }), /placeholder/);
    assert.deepEqual(calls, ['']);
  }
});
test('real API adapter uses the canonical repository URL without a trailing slash', async () => {
  const e = event(); e.pull_request.body = null;
  const calls = [];
  await run(env, e, { fetcher: async url => {
    calls.push(url);
    assert.equal(url, 'https://api.github.com/repos/Civ13/Civ13');
    return { ok: true, status: 200, json: async () => ({ default_branch: 'master' }) };
  } });
  assert.equal(calls.length, 1);
});
test('unmerged, foreign, wrong branch, stale merge and disabled publishing fail closed', async () => {
  for (const change of [{ merged: false }, { base: { ref: 'other', repo: pr.base.repo } }, { base: { ref: 'master', repo: { full_name: 'other/repo' } } }, { merge_commit_sha: 'c'.repeat(40) }]) {
    const e = event(); Object.assign(e.pull_request, change);
    const h = harness(); await assert.rejects(run(env, e, h)); assert.equal(h.posts(), 0);
  }
  await assert.rejects(run({ ...env, MERGE_CHANGELOG_ENABLED: 'false' }, event(), harness()), /disabled/);
});
