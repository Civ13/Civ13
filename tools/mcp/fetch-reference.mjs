// Explicit build/setup command only. Never imported by the MCP entrypoint.
import fs from 'node:fs/promises';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { ARTIFACT_DIRECTORY, SOURCES, manifest, validateManifest, decodeArtifact, loadArtifacts, ReferenceError } from './reference-artifacts.mjs';
import { createReference } from './atlas-reference.mjs';

export async function fetchArtifact(name, fetcher = fetch, pin = manifest) {
  validateManifest(pin);
  if (!Object.hasOwn(SOURCES, name)) throw new ReferenceError('artifact_manifest_invalid');
  const controller = new AbortController(), timer = setTimeout(() => controller.abort(), 10000);
  let response, reader;
  try {
    response = await fetcher(SOURCES[name].url, { redirect: 'manual', signal: controller.signal,
      headers: { Accept: 'application/json', 'User-Agent': 'Civ13-Reference-Artifact/1.0' } });
    if (response.status !== 200 || !/^application\/json(?:\s*;|$)/i.test(response.headers.get('content-type') ?? ''))
      throw new ReferenceError('artifact_fetch_unavailable');
    const expected = pin.files[name].bytes;
    const length = response.headers.get('content-length');
    if (length && (!/^\d+$/.test(length) || Number(length) > SOURCES[name].max)) throw new ReferenceError('artifact_size_invalid');
    if (!response.body) throw new ReferenceError('artifact_fetch_unavailable');
    reader = response.body.getReader();
    const bytes = Buffer.alloc(expected + 1); let offset = 0;
    while (true) {
      const read = await reader.read(); if (read.done) break;
      if (offset + read.value.byteLength > expected) throw new ReferenceError('artifact_size_invalid');
      bytes.set(read.value, offset); offset += read.value.byteLength;
    }
    const body = bytes.subarray(0, offset); decodeArtifact(body, name, pin); return body;
  } finally {
    clearTimeout(timer);
    if (reader) await reader.cancel().catch(() => {});
    else if (response?.body) await response.body.cancel().catch(() => {});
  }
}
export async function acquireArtifacts({ fetcher = fetch, directory = ARTIFACT_DIRECTORY, pin = manifest } = {}) {
  validateManifest(pin);
  directory = path.resolve(directory);
  let existing = false;
  try { await fs.lstat(directory); existing = true; }
  catch (error) { if (error.code !== 'ENOENT') throw new ReferenceError('artifact_unavailable'); }
  if (existing) {
    createReference(await loadArtifacts(directory, pin)); return { state: 'already_verified', revision: pin.revision };
  }
  // Never replace an existing invalid set; writes are distinct from download errors.
  const write = async operation => {
    try { return await operation(); }
    catch { throw new ReferenceError('artifact_write_failed'); }
  };
  const parent = path.dirname(directory), prefix = path.join(parent, '.reference-pending-');
  const temporary = await write(() => fs.mkdtemp(prefix));
  try {
    for (const name of Object.keys(SOURCES)) {
      const bytes = await fetchArtifact(name, fetcher, pin);
      await write(() => fs.writeFile(path.join(temporary, name), bytes, { flag: 'wx' }));
    }
    createReference(await loadArtifacts(temporary, pin));
    await write(() => fs.rename(temporary, directory));
    return { state: 'verified', revision: pin.revision };
  } finally {
    // Only the fresh mkdtemp child owned by this operation is cleaned up.
    if (path.dirname(temporary) !== parent || !temporary.startsWith(prefix)) throw new ReferenceError('artifact_path_invalid');
    await write(() => fs.rm(temporary, { recursive: true, force: true }));
  }
}
if (process.argv[1] && path.resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  if (process.argv.length !== 2) throw new ReferenceError('artifact_arguments_invalid');
  try { console.log(JSON.stringify(await acquireArtifacts())); }
  catch (error) { console.error(error instanceof ReferenceError ? error.code : 'artifact_fetch_unavailable'); process.exitCode = 1; }
}
