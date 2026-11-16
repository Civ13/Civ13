import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, render } from '@testing-library/react';
import { screens } from './fixtures.mts';
import { interfaces } from './interfaces';
import { emptyState, updateState } from './state';
afterEach(cleanup);
const needsBrowser = new Set(['book_reader.tmpl', 'paper_editor.tmpl']);
describe('shared window fixtures', () => {
  it('cover every registered window, each under its own name', () => {
    expect([...new Set(screens.map(screen => screen.template))].sort()).toEqual(Object.keys(interfaces).sort());
    expect(new Set(screens.map(screen => screen.name)).size).toBe(screens.length);
    for (const screen of screens) expect(screen.width > 0 && screen.height > 0 && screen.title.length > 0, screen.name).toBe(true);
  });
  it.each(screens.map(screen => [screen.name, screen] as const))('%s renders from its snapshot the way the app receives it', (_name, screen) => {
    // The same path as a live window: JSON over the wire, then updateState().
    const { data } = updateState(emptyState, JSON.stringify({ config: { template: screen.template, title: screen.title, status: 2 }, data: screen.data }));
    const Screen = interfaces[screen.template], act = vi.fn();
    // The book and paper pages refuse to draw without real layout support; the screenshot script covers them in Chromium.
    if (needsBrowser.has(screen.template)) { expect(() => render(<Screen template={screen.template} data={data} act={act} interactive />)).toThrow(/Unsupported/); return; }
    const view = render(<Screen template={screen.template} data={data} act={act} interactive />);
    expect(view.container.textContent?.trim().length).toBeGreaterThan(0);
    // Opening a window is not an action; only the crafting window may ask for its next batch of pictures.
    for (const call of act.mock.calls) expect(['images', 'detail']).toContain(call[0]);
  });
});
