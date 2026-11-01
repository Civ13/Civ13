import fs from 'node:fs/promises';
import path from 'node:path';
import { createHash } from 'node:crypto';
import { SOURCES } from './reference-artifacts.mjs';

export function fixture() {
  const revision = 'a'.repeat(40), audit = 'b'.repeat(40);
  const atlas = { sha: revision, sources: { audit_commit: audit }, limitations: ['Fixture source reference, not live availability.'],
    recipes: [{ id: 'r_global', name: 'Flintlock assembly', kind: 'Material / global',
      inputs: [{ id: '/material/wood', name: 'wood', quantity: '2 iron OR 1 steel (alternatives)' }],
      outputs: [{ id: '/obj/item/flintlock', name: 'flintlock', quantity: '1' }],
      conditions: 'Research node and actual material gate; knife is not consumed. Map availability unknown.',
      maximum_era: 8, unlock_eras: [1], era_status: 'known', era_label: 'Bronze Age', era_basis: 'Fixture research node',
      file: 'config/global.txt', line: 10, raw: 'not exposed', variants: [
        { id: 'r_global', kind: 'Material / global', file: 'config/global.txt', line: 10, raw: 'not exposed' },
        { id: 'r_nomads', kind: 'Material / Nomads', file: 'config/nomads.txt', line: 20, raw: 'not exposed' },
      ] }, { id: 'r_enzyme', name: 'Proteolytic enzyme extraction', kind: 'Processing',
      inputs: [{ id: '/material/wood', name: 'wood', quantity: '0' }],
      outputs: [{ id: 'proteolytic_enzyme', name: 'proteolytic enzyme', quantity: '1 conditional' }],
      conditions: 'Unknown research; tools and heat still required.', unlock_eras: [], era_status: 'unknown',
      file: 'code/extraction.dm', line: 30 }],
    resources: { '/material/wood': { type: '/obj/item/wood', label: 'Fixture appearance' },
      '/obj/item/flintlock': { type: '/obj/item/flintlock' }, proteolytic_enzyme: { type: 'proteolytic_enzyme' } },
    acquisition: { proteolytic_enzyme: [{ name: 'Conditional extraction', file: 'code/extraction.dm', line: 8,
      inputs: ['/material/wood'], outputs: ['proteolytic_enzyme'], tools: ['knife (not consumed)'],
      steps: ['<script>untrusted reference, never execute</script>'], conditions: 'Map and research gates remain.',
      status: 'source reviewed, gameplay unverified', audit_commit: audit, source_sha256: 'c'.repeat(64) }] },
    production_sites: [{ admin_setup: 'not a player acquisition route' }] };
  const docs = [{ label: 'datum/callback/proc/Invoke', url: 'datum/callback.html#proc/Invoke' },
    { label: 'code/callback.dm', url: 'code/callback.html' }];
  const build = { head_sha: revision };
  return repin({ atlas, docs, build });
}
export function repin(data) {
  const bodies = { 'atlas.json': Buffer.from(JSON.stringify(data.atlas)), 'docs-index.json': Buffer.from(JSON.stringify(data.docs)),
    'build.json': Buffer.from(JSON.stringify(data.build)) };
  const pin = { schema: 1, revision: data.atlas.sha, files: Object.fromEntries(Object.entries(bodies).map(([name, bytes]) =>
    [name, { url: SOURCES[name].url, bytes: bytes.length, sha256: createHash('sha256').update(bytes).digest('hex') }])) };
  return { ...data, bodies, pin };
}
export async function writeArtifacts(directory, data = fixture()) {
  await fs.mkdir(directory, { recursive: true });
  for (const [name, bytes] of Object.entries(data.bodies)) await fs.writeFile(path.join(directory, name), bytes);
  return data;
}
