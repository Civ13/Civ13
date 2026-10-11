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
