import React from 'react';
import { afterEach, expect, it, vi } from 'vitest';
import { cleanup, render } from '@testing-library/react';
vi.mock('tgui-core/components', () => ({ Section: ({ children }: any) => <section>{children}</section> }));
import { CharacterFlavor, flavorText } from './CharacterFlavor';
import type { ScreenProps } from '../types';
afterEach(cleanup);
const props = (value = 'First\nSecond'): ScreenProps => ({ template: 'character_flavor.tmpl', interactive: false, act: vi.fn(), data: { name: 'Fictional reader', text: value } });
it('keeps literal stored LF as breaks but encoded LF as whitespace text', () => {
  const ui = props('First\nSecond &#10; same line\n');
  const { container } = render(<CharacterFlavor {...ui} />);
  expect(container.querySelectorAll('br')).toHaveLength(2);
  expect(container.querySelector('article')?.textContent).toBe('FirstSecond \n same line');
  expect(container.querySelectorAll('button,a,input,textarea,script')).toHaveLength(0);
  expect(ui.act).not.toHaveBeenCalled();
});
it('decodes exactly once and renders encoded markup as inert text', () => {
  const { container } = render(<CharacterFlavor {...props('An &amp;lt;b&amp;gt; &lt;img src=x onerror=alert(1)&gt;')} />);
  expect(container.textContent).toContain('An &lt;b&gt; <img src=x onerror=alert(1)>');
  expect(container.querySelectorAll('img,script,[onerror]')).toHaveLength(0);
});
it('preserves multilingual text, empty text and full replacement on reopen', () => {
  const value = '\u041f\u0440\u0438\u0432\u0435\u0442 \u65e5\u672c\u8a9e \ud83d\ude00';
  const { container, rerender } = render(<CharacterFlavor {...props(value)} />);
  expect(container.textContent).toContain(value);
  rerender(<CharacterFlavor {...props('')} />);
  expect(container.querySelector('article')?.textContent).toBe('');
  expect(container.textContent).not.toContain(value);
});
it('rejects raw/malformed/unknown content whole for cached classic fallback', () => {
  for (const value of ['<b>raw</b>', '&copy;', '&amp', '&QuOt;', '&#x41;', '&#0;', '&#55296;', '&#128;', 'x\u0000y']) expect(() => flavorText(value)).toThrow();
  for (const value of ['&amp;', '&LT;', '&#39;', '&#128512;', 'plain & text']) expect(() => flavorText(value)).not.toThrow();
  expect(() => render(<CharacterFlavor {...props('safe\n<bad>')} />)).toThrow();
});
it('rejects complete oversized or excessive-line snapshots without truncation', () => {
  expect(() => render(<CharacterFlavor {...props('\ud83d\ude00'.repeat(40000))} />)).toThrow();
  expect(() => render(<CharacterFlavor {...props('\n'.repeat(2048))} />)).toThrow();
  expect(() => render(<CharacterFlavor {...props('\n'.repeat(2047))} />)).not.toThrow();
});
