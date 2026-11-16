import { describe, expect, it } from 'vitest';
import { decode, decodeData, emptyState, updateState } from './state';
describe('NanoUI data transport', () => {
  it('preserves data on status-only update and replaces full payload on refresh', () => {
    const first = updateState(emptyState, JSON.stringify({ config: { status: 2 }, data: { old: 1 } }));
    expect(updateState(first, '{"config":{"status":1}}')).toEqual({ config: { status: 1 }, data: { old: 1 } });
    expect(updateState(first, '{"data":{"new":2}}').data).toEqual({ new: 2 });
  });
  it.each(['broken', 'null', '[]', '{"config":[]}', '{"data":3}'])('rejects malformed updates %s', raw => {
    expect(() => updateState(emptyState, raw)).toThrow();
  });
  it('decodes display text once per snapshot and leaves identifiers and numbers alone', () => {
    const raw = { config: { template: 'crew_log.tmpl' }, data: { name: 'O&#39;Brien &amp; Sons', id: 'a&amp;b', station_id: '&lt;x&gt;', count: 3,
      rows: [{ key: 'k&amp;1', label: '&lt;b&gt;bold&lt;/b&gt;', nested: { note: '&amp;lt;', flag: null } }] } };
    const { data } = updateState(emptyState, JSON.stringify(raw));
    expect(data).toEqual({ name: "O'Brien & Sons", id: 'a&amp;b', station_id: '&lt;x&gt;', count: 3,
      rows: [{ key: 'k&amp;1', label: '<b>bold</b>', nested: { note: '&lt;', flag: null } }] });
    // A status-only update keeps the already decoded snapshot; it is not decoded a second time.
    expect(updateState({ config: raw.config, data }, '{"config":{"status":1}}').data).toBe(data);
  });
  it.each(['book_reader.tmpl', 'paper_editor.tmpl', 'character_notes.tmpl', 'character_flavor.tmpl', 'photo_viewer.tmpl'])('hands %s its snapshot exactly as sent', template => {
    const data = { content: '&lt;p&gt;kept&lt;/p&gt; &amp;amp;' };
    expect(updateState(emptyState, JSON.stringify({ config: { template }, data })).data).toEqual(data);
  });
  it('decodes only known entities and never to markup-bearing structures', () => {
    expect(decode('&amp;&lt;&gt;&quot;&apos;&#65;&#x42;&bogus;&#0;&#x110000;')).toBe('&<>"\'AB&bogus;&#0;&#x110000;');
    expect(decode(null)).toBe('');
    expect(decodeData(['&amp;', 2, { a: '&lt;' }])).toEqual(['&', 2, { a: '<' }]);
  });
});
