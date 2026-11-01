import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { createHash } from 'node:crypto';

export const ARTIFACT_DIRECTORY = fileURLToPath(new URL('.reference-artifacts/', import.meta.url));
export const SOURCES = Object.freeze({
  'atlas.json': { url: 'https://civ13.github.io/Civ13/crafting/crafting-data.json', max: 16 * 1024 * 1024 },
  'docs-index.json': { url: 'https://civ13.github.io/Civ13/search-index.json', max: 256 * 1024 },
  'build.json': { url: 'https://civ13.github.io/Civ13/build.json', max: 8192 },
});
export const manifest = JSON.parse(await fs.readFile(new URL('reference-sources.json', import.meta.url), 'utf8'));
export class ReferenceError extends Error {
  constructor(code) { super(code); this.code = code; }
}
export function validateManifest(pin) {
  if (!pin || pin.schema !== 1 || !/^[a-f0-9]{40}$/.test(pin.revision ?? '')
    || !pin.files || Object.keys(pin.files).sort().join('|') !== Object.keys(SOURCES).sort().join('|'))
    throw new ReferenceError('artifact_manifest_invalid');
  for (const [name, source] of Object.entries(SOURCES)) {
    const file = pin.files[name];
    if (!file || file.url !== source.url || !Number.isInteger(file.bytes) || file.bytes < 2 || file.bytes > source.max
      || !/^[a-f0-9]{64}$/.test(file.sha256 ?? '')) throw new ReferenceError('artifact_manifest_invalid');
  }
}
export function decodeArtifact(bytes, name, pin = manifest) {
  validateManifest(pin);
  const entry = pin.files[name];
  if (!entry || bytes.byteLength !== entry.bytes || bytes.byteLength > SOURCES[name].max
    || createHash('sha256').update(bytes).digest('hex') !== entry.sha256)
    throw new ReferenceError('artifact_hash_mismatch');
  try { return JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(bytes)); }
  catch { throw new ReferenceError('artifact_json_invalid'); }
}
async function noLinks(absolute) {
  let current = absolute;
  while (true) {
    const stat = await fs.lstat(current);
    if (stat.isSymbolicLink()) throw new ReferenceError('artifact_path_invalid');
    const parent = path.dirname(current);
    if (parent === current) break;
    current = parent;
  }
}
// A fixed three-file artifact set, read only at initialization. No tool supplies
// a path, URL or manifest. An injected directory/pin is a test/composition seam.
export async function loadArtifacts(directory = ARTIFACT_DIRECTORY, pin = manifest) {
  validateManifest(pin);
  try {
    const absolute = path.resolve(directory);
    if (absolute.startsWith('\\\\')) throw new ReferenceError('artifact_path_invalid');
    await noLinks(absolute);
    const result = {};
    for (const name of Object.keys(SOURCES)) {
      const file = path.join(absolute, name);
      await noLinks(file);
      const handle = await fs.open(file, 'r');
      try {
        const stat = await handle.stat();
        if (!stat.isFile() || stat.size !== pin.files[name].bytes || stat.size > SOURCES[name].max)
          throw new ReferenceError('artifact_size_invalid');
        const bytes = Buffer.alloc(stat.size + 1);
        let offset = 0;
        while (offset < bytes.length) {
          const read = await handle.read(bytes, offset, bytes.length - offset, offset);
          if (!read.bytesRead) break;
          offset += read.bytesRead;
        }
        result[name] = decodeArtifact(bytes.subarray(0, offset), name, pin);
      } finally { await handle.close(); }
    }
    if (result['atlas.json']?.sha !== pin.revision || result['build.json']?.head_sha !== pin.revision)
      throw new ReferenceError('artifact_revision_mismatch');
    return { atlas: result['atlas.json'], docs: result['docs-index.json'], build: result['build.json'], pin };
  } catch (error) {
    if (error instanceof ReferenceError) throw error;
    throw new ReferenceError(error.code === 'ENOENT' ? 'artifact_missing' : 'artifact_unavailable');
  }
}
