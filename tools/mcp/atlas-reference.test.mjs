import { test } from 'node:test';
import assert from 'node:assert/strict';
import { createReference } from './atlas-reference.mjs';
import { fixture } from './reference-fixtures.mjs';

test('resource normalization reuses canonical labels without guessed aliases', () => {
  const reference = createReference(fixture());
  const a = reference.search({ query: '  PROTEOLYTIC__enzyme  ' });
  assert.deepEqual(a.entries.map(row => row.kind), ['resource', 'recipe']);
  assert.equal(a.entries[0].id, 'proteolytic_enzyme');
  assert.deepEqual(reference.search({ query: 'Digestive Protease' }).entries, []);
  assert.ok(reference.search({ query: ' ' }).entries.every(row => row.kind === 'recipe'));
});
test('matching variants and retained old IDs preserve quantities, material and research gates', () => {
  const reference = createReference(fixture());
  const found = reference.search({ query: 'nomads' }).entries[0];
  assert.equal(found.id, 'r_global'); assert.equal(found.variant_id, 'r_nomads');
  const result = reference.recipe({ id: found.id, variant_id: found.variant_id });
  assert.equal(result.recipe.source.file, 'config/nomads.txt'); assert.equal(result.recipe.source.line, 20);
  assert.deepEqual(result.recipe.inputs, fixture().atlas.recipes[0].inputs);
  assert.equal(result.recipe.maximum_era, 8); assert.deepEqual(result.recipe.unlock_eras, [1]);
  assert.match(result.recipe.conditions, /knife is not consumed/);
  assert.equal(reference.recipe({ id: 'r_nomads' }).recipe.selected_variant_id, 'r_nomads');
  assert.throws(() => reference.recipe({ id: 'r_global', variant_id: 'r_enzyme' }), /unknown_variant/);
  assert.equal(JSON.stringify(result).includes('not exposed'), false);
});
test('resource routes retain separate historical audit provenance and exclude raw production sites', () => {
  const reference = createReference(fixture()), result = reference.resource({ id: 'proteolytic_enzyme' });
  assert.equal(result.provenance.revision, 'a'.repeat(40));
  assert.equal(result.entries[0].route.audit_revision, 'b'.repeat(40));
  assert.match(result.entries[0].route.source.url, new RegExp('/' + 'b'.repeat(40) + '/code/extraction.dm#L8'));
  assert.match(result.entries[0].route.steps[0], /<script>/); // Returned as data only.
  assert.equal(JSON.stringify(result).includes('admin_setup'), false);
  assert.equal(result.entries[1].direction, 'produces');
});
test('paging is explicit and no recursive graph expansion occurs', () => {
  const data = fixture();
  for (let index = 0; index < 30; index++) {
    const row = structuredClone(data.atlas.recipes[1]); row.id = 'extra_' + index; data.atlas.recipes.push(row);
  }
  const reference = createReference(data);
  const first = reference.resource({ id: 'proteolytic_enzyme', limit: 3 });
  assert.equal(first.entries.length, 3); assert.equal(first.next_offset, 3); assert.equal(first.truncated, true);
  const last = reference.resource({ id: 'proteolytic_enzyme', offset: first.total, limit: 3 });
  assert.deepEqual(last.entries, []); assert.equal(last.next_offset, null);
  assert.equal(reference.search({ query: 'extraction', limit: 20 }).entries.length, 20);
});
test('bounds, unknown fields, IDs, cancellation and source-URL traversal fail explicitly', () => {
  const reference = createReference(fixture());
  for (const args of [{ query: 'x'.repeat(121) }, { limit: 21 }, { offset: -1 }, { offset: 10001 },
    { path: '../../.env' }, { url: 'https://example.test' }, { query: '\ud800' }]) assert.throws(() => reference.search(args));
  assert.throws(() => reference.recipe({ id: 'missing' }), /unknown_recipe/);
  assert.throws(() => reference.resource({ id: 'missing' }), /unknown_resource/);
  const controller = new AbortController(); controller.abort();
  assert.throws(() => reference.search({}, controller.signal), /cancelled/);
  for (const url of ['https://other.test/a', '../outside.html', 'javascript:alert(1)', '//other.test/', 'code\\a.html']) {
    const data = fixture(); data.docs[0].url = url; assert.throws(() => createReference(data), /artifact_schema_invalid/);
  }
  const data = fixture(); data.atlas.recipes[0].variants[0].file = '../private.txt';
  assert.throws(() => createReference(data), /artifact_schema_invalid/);
});
test('inconsistent variants and malformed corpus do not become partial plausible data', () => {
  for (const mutate of [data => data.atlas.recipes[0].variants[1].inputs = [],
    data => data.atlas.recipes[1].id = 'r_global', data => data.atlas.recipes[0].outputs[0].quantity = Infinity,
    data => data.atlas.recipes[0].unlock_eras = 'always unlocked',
    data => data.atlas.resources = {}, data => data.docs[0].label = '\ud800']) {
    const data = fixture(); mutate(data); assert.throws(() => createReference(data), /artifact_schema_invalid/);
  }
});
test('oversized detail is an error, never an ingredient/quantity truncation', () => {
  const data = fixture(); data.atlas.recipes[0].conditions = 'x'.repeat(28000);
  const reference = createReference(data);
  assert.throws(() => reference.recipe({ id: 'r_global' }), /result_too_large/);
  assert.equal(data.atlas.recipes[0].inputs[0].quantity, '2 iron OR 1 steel (alternatives)');
});
test('docs lookup returns safe existing labels/links and explicit pinned hashes', () => {
  const result = createReference(fixture()).docs({ query: '/callback Invoke' });
  assert.equal(result.entries.length, 1); assert.match(result.entries[0].url, /^https:\/\/civ13.github.io\/Civ13\//);
  assert.match(result.provenance.docs_sha256, /^[a-f0-9]{64}$/);
  assert.match(result.provenance.scope, /untrusted/);
  assert.deepEqual(createReference(fixture()).docs({ query: '///' }).entries, []);
});
test('admitted corpus and relationship counts cannot produce unreachable pagination cursors', () => {
  const data = fixture();
  data.atlas.resources = Object.fromEntries(Array.from({ length: 9999 }, (_, index) => ['resource_' + index, {}]));
  assert.throws(() => createReference(data), /artifact_schema_invalid/);
});
