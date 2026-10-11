import test from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const read = name => readFileSync(new URL('../../.github/workflows/' + name, import.meta.url), 'utf8').replace(/\r\n/g, '\n');
function job(source, name) {
  const jobs = source.slice(source.indexOf('\njobs:\n') + 7);
  const sections = jobs.split(/(?=^  [\w-]+:\n)/m);
  const section = sections.find(value => value.startsWith('  ' + name + ':\n'));
  assert.ok(section, 'Missing job ' + name);
  return section;
}
function permissions(section, indentation) {
  const indent = ' '.repeat(indentation);
  const lines = section.split('\n');
  const index = lines.indexOf(indent + 'permissions:');
  assert.notEqual(index, -1, 'Explicit permission block required');
  const values = {};
  for (const line of lines.slice(index + 1)) {
    const match = new RegExp('^' + indent + '  ([\\w-]+): (read|write|none)$').exec(line);
    if (!match) break;
    values[match[1]] = match[2];
  }
  return values;
}
function ceiling(caller, callee) {
  const rank = { none: 0, read: 1, write: 2 };
  for (const [scope, value] of Object.entries(callee)) {
    assert.ok(rank[value] <= rank[caller[scope] ?? 'none'], scope + ' exceeds caller ceiling');
  }
}
test('reusable publish ceiling is sufficient while identify and model stay read-only', () => {
  const caller = read('comment-review.yml');
  const worker = read('comment-review-worker.yml');
  const maximum = permissions(job(caller, 'review'), 4);
  const model = permissions(job(worker, 'review'), 4);
  const publisher = permissions(job(worker, 'publish'), 4);
  ceiling(maximum, model);
  ceiling(maximum, publisher);
  for (const value of Object.values(model)) assert.equal(value, 'read');
  for (const value of Object.values(permissions(caller, 0))) assert.equal(value, 'read');
  // This models the configuration that GitHub rejected at startup.
  assert.throws(() => ceiling({ ...maximum, issues: 'read' }, publisher));
  assert.match(job(caller, 'identify'), /github\.event_name != 'workflow_dispatch'/);
});

function triggerNames(source) {
  const block = source.match(/^on:\n([\s\S]*?)(?=^permissions:)/m)?.[1];
  assert.ok(block, 'Missing on mapping');
  return [...block.matchAll(/^  ([\w-]+):/gm)].map(match => match[1]).sort();
}
test('dormant listeners register only manual smokes and never execute them', () => {
  for (const [file, role] of [['comment-review.yml', 'identify'], ['comment-review-events.yml', 'collect']]) {
    const source = read(file);
    assert.deepEqual(triggerNames(source), ['workflow_dispatch']);
    assert.match(job(source, role), /vars\.CODEX_COMMENT_REVIEW_ENABLED == 'true' && github\.event_name != 'workflow_dispatch'/);
    // Regression: the old disabled-by-job route still registered a pre-job event.
    const old = source.replace('  workflow_dispatch:\n', '  workflow_dispatch:\n  workflow_run:\n    types: [completed]\n');
    assert.notDeepEqual(triggerNames(old), ['workflow_dispatch']);
  }
});
test('activation examples preserve intended events without activating installed files', () => {
  const example = JSON.parse(readFileSync(new URL('active-events.example.json', import.meta.url), 'utf8'));
  assert.deepEqual(example['comment-review.yml'].workflow_run, { workflows: ['Comment review intake'], types: ['completed'] });
  assert.deepEqual(example['comment-review.yml'].issue_comment.types, ['created', 'edited']);
  assert.deepEqual(example['comment-review-events.yml'].pull_request_review.types, ['submitted', 'edited']);
  assert.deepEqual(example['comment-review-events.yml'].pull_request_review_comment.types, ['created', 'edited']);
  for (const name of ['comment-review.yml', 'comment-review-events.yml']) {
    assert.deepEqual(triggerNames(read(name)), ['workflow_dispatch']);
  }
});
