import { describe, expect, it } from 'vitest';
import { emptyState, updateState } from './state';
describe('NanoUI data transport', () => {
  it('preserves data on status-only update and replaces full payload on refresh', () => {
    const first = updateState(emptyState, JSON.stringify({ config: { status: 2 }, data: { old: 1 } }));
    expect(updateState(first, '{"config":{"status":1}}')).toEqual({ config: { status: 1 }, data: { old: 1 } });
    expect(updateState(first, '{"data":{"new":2}}').data).toEqual({ new: 2 });
  });
  it.each(['broken', 'null', '[]', '{"config":[]}', '{"data":3}'])('rejects malformed updates %s', raw => {
    expect(() => updateState(emptyState, raw)).toThrow();
  });
});
