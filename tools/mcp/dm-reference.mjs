import { createHash } from 'node:crypto';

export const referenceUrl = 'https://www.byond.com/docs/ref/info.html';
const maxBytes = 8 * 1024 * 1024;
function plain(html) {
  const entities = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'", nbsp: ' ' };
  // Extract text tokens, rather than treating tag removal as HTML sanitization.
  // Entity-decoded examples remain plain reference text and must never be rendered as HTML.
  const tokens = [];
  for (const match of html.matchAll(/<!--[^]*?-->|<(script|style)\b[^>]*>[^]*?<\/\1\s*>|<[^>]*>|[^<]+|</gi)) {
    const token = match[0];
    if (/^<\s*(?:br|\/p|\/div|\/li|\/h[1-6]|\/pre|\/tr)\b/i.test(token)) tokens.push('\n');
    else if (!token.startsWith('<') || token === '<') tokens.push(token);
  }
  return tokens.join('').replace(/&(#x[\da-f]+|#\d+|\w+);/gi, (raw, key) => {
      if (!key.startsWith('#')) return entities[key] ?? raw;
      const n = key[1].toLowerCase() === 'x' ? parseInt(key.slice(2), 16) : Number(key.slice(1));
      return n > 0 && n <= 0x10ffff ? String.fromCodePoint(n) : raw;
    }).replace(/[ \t]+/g, ' ').replace(/\n\s*\n+/g, '\n\n').trim();
}
export function parseReference(html) {
  const anchors = [...html.matchAll(/<a\b[^>]*\bname\s*=\s*(?:"([^"<>]+)"|'([^'<>]+)'|([^\s<>]+))[^>]*>/gi)]
    .map(m => ({ topic: m[1] ?? m[2] ?? m[3], start: m.index, end: m.index + m[0].length }));
  const entries = new Map();
  for (let i = 0; i < anchors.length; i++) {
    const a = anchors[i];
    if (!a.topic.startsWith('/') || a.topic.length > 240) continue;
    if (entries.has(a.topic)) throw Error('Duplicate DM reference topic');
    entries.set(a.topic, plain(html.slice(a.end, anchors[i + 1]?.start ?? html.length)));
  }
  if (!entries.size) throw Error('Official DM reference contains no recognizable topics');
  return entries;
}
export function createReference(fetcher = fetch) {
  let cache, loading = false;
  return async function reference(args, signal) {
    if (signal?.aborted) throw Error('Cancelled');
    if (!cache || Date.now() - cache.loaded > 900000) {
      if (loading) throw Error('Official DM reference fetch already active; retry after it completes');
      loading = true;
      const controller = new AbortController();
      const cancel = () => controller.abort();
      signal?.addEventListener('abort', cancel, { once: true });
      const timer = setTimeout(cancel, 20000);
      try {
        const response = await fetcher(referenceUrl, { signal: controller.signal, redirect: 'error', credentials: 'omit' });
        if (!response.ok) throw Error(`Official DM reference HTTP ${response.status}`);
        if (!/text\/html/i.test(response.headers.get('content-type') ?? '')) throw Error('DM reference is not HTML');
        if (Number(response.headers.get('content-length')) > maxBytes) throw Error('DM reference exceeds size limit');
        const reader = response.body.getReader(); const chunks = []; let bytes = 0;
        try {
          for (;;) {
            const { done, value } = await reader.read(); if (done) break;
            bytes += value.byteLength;
            if (bytes > maxBytes) throw Error('DM reference exceeds size limit');
            chunks.push(Buffer.from(value));
          }
        } finally { await reader.cancel(); reader.releaseLock(); }
        if (controller.signal.aborted) throw Error('DM reference request cancelled or timed out');
        const content = Buffer.concat(chunks);
        cache = { entries: parseReference(content.toString('utf8')), loaded: Date.now(), sha256: createHash('sha256').update(content).digest('hex') };
      } finally { controller.abort(); loading = false; clearTimeout(timer); signal?.removeEventListener('abort', cancel); }
    }
    const provenance = { source: referenceUrl, fetchedAt: new Date(cache.loaded).toISOString(), sha256: cache.sha256,
      versionNote: 'Live official reference; may describe features newer than Civ13 BYOND 516.1681. Not compiler verification.' };
    if (args.topic !== undefined) {
      const text = cache.entries.get(args.topic);
      if (text === undefined) throw Error('Unknown topic; use dm_reference_search to find an exact topic');
      const start = args.start ?? 0, length = args.length ?? 12000;
      return { ...provenance, topic: args.topic, url: referenceUrl + '#' + encodeURI(args.topic), start,
        totalCharacters: text.length, text: text.slice(start, start + length), truncated: start + length < text.length };
    }
    const query = args.query.toLowerCase(); const matches = [];
    for (const [topic, text] of cache.entries) {
      if (topic.toLowerCase().includes(query) || text.toLowerCase().includes(query))
        matches.push({ topic, url: referenceUrl + '#' + encodeURI(topic), excerpt: text.slice(0, 220) });
    }
    matches.sort((a,b) => Number(!a.topic.toLowerCase().includes(query)) - Number(!b.topic.toLowerCase().includes(query)) || a.topic.localeCompare(b.topic));
    return { ...provenance, matches: matches.slice(0, args.limit ?? 20), totalMatches: matches.length };
  };
}
