import type { Data, State } from './types';
// Server text may arrive entity encoded. Decode it as text; nothing here is ever inserted as HTML.
export function decode(value: unknown): string {
  const raw = String(value ?? '');
  if (!raw.includes('&')) return raw;
  return raw.replace(/&(#\d+|#x[\da-f]+|amp|lt|gt|quot|apos);/gi, (match, entity: string) => {
    const named: Record<string, string> = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" };
    if (entity[0] !== '#') return named[entity.toLowerCase()] ?? match;
    const number = entity[1].toLowerCase() === 'x' ? parseInt(entity.slice(2), 16) : parseInt(entity.slice(1), 10);
    return number > 0 && number <= 0x10ffff ? String.fromCodePoint(number) : match;
  });
}
// Identifiers go back to the server unchanged, so they are never decoded.
const identifier = /^(id|key)$|_id$/;
// One pass over a snapshot: every display string decoded once, so screens render fields as they are.
export function decodeData<T>(value: T, key = ''): T {
  if (typeof value === 'string') return (identifier.test(key) ? value : decode(value)) as T;
  if (Array.isArray(value)) return value.map(item => decodeData(item, key)) as T;
  if (value && typeof value === 'object') return Object.fromEntries(Object.entries(value as Data).map(([k, v]) => [k, decodeData(v, k)])) as T;
  return value;
}
// Document windows validate and lay out their own content, so their snapshots stay exactly as sent.
export const documentTemplates = new Set(['book_reader.tmpl', 'paper_editor.tmpl', 'character_notes.tmpl', 'character_flavor.tmpl', 'photo_viewer.tmpl']);
export const emptyState: State = { config: {}, data: {} };
export function updateState(previous: State, raw: string): State {
  const message = JSON.parse(raw);
  if (!message || typeof message !== 'object' || Array.isArray(message)) throw new Error('Invalid UI update');
  if (message.config && (typeof message.config !== 'object' || Array.isArray(message.config))) throw new Error('Invalid config');
  if (message.data != null && (typeof message.data !== 'object' || Array.isArray(message.data))) throw new Error('Invalid data');
  const config = { ...previous.config, ...message.config };
  if (message.data == null) return { config, data: previous.data };
  return { config, data: documentTemplates.has(String(config.template ?? '')) ? message.data : decodeData(message.data) };
}
