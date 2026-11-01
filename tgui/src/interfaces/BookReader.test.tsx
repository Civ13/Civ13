import { afterEach, expect, it } from 'vitest';
import { cleanup, render } from '@testing-library/react';
import { BookPage, bookRuns, bookText, bookRenderingSupported } from './BookReader';
afterEach(cleanup);
const run = (text = 'Hidden') => ({ text, face: 'times', ink: '#ffffff', bold: false, italic: false });
it('renders validated white ink once as ordinary selectable text on opaque white', () => {
  const { container } = render(<BookPage runs={bookRuns({ runs: [run()] })} />);
  const page = container.querySelector('article')!, span = page.querySelector('span')!;
  expect(page.style.backgroundColor).toBe('rgb(255, 255, 255)');
  expect(page.style.color).toBe('rgb(0, 0, 0)'); expect(page.style.userSelect).toBe('text');
  expect(span.style.color).toBe('rgb(255, 255, 255)');expect(span.textContent).toBe('Hidden');
  expect(container.textContent).toBe('Hidden');
  expect(container.querySelectorAll('[aria-label],[aria-describedby],[title],[hidden],button,a,input,textarea,script,style').length).toBe(0);
});
it('decodes text once without creating HTML or changing Unicode', () => {
  const { container } = render(<BookPage runs={bookRuns({ runs: [run('&lt;img src=x&gt; &amp;lt; 🚢 &#65;')] })} />);
  expect(container.textContent).toBe('<img src=x> &lt; 🚢 A'); expect(container.querySelector('img')).toBeNull();
});
it('rejects the complete model for any extra or invalid node metadata', () => {
  for (const bad of [{ ...run(), title: 'reveal' },{ ...run(), ink: 'white' },{ ...run(), ink: '#fff' },{ ...run(), face: 'Arial' },{ ...run(), bold: 2 },{ ...run(), br: true },null])
    expect(() => bookRuns({ runs: [run('Prefix'),bad,run('Suffix')] })).toThrow();
  expect(() => bookRuns({ runs: [], summary: 'Hidden' })).toThrow();
});
it('fails closed for malformed entities, controls, surrogate fragments and oversized data', () => {
  for (const value of ['<b>x</b>','&unknown;','&#x41;','&#0;','&#55296;','\u0000','\ud800','\udfff']) expect(() => bookText(value)).toThrow();
  expect(() => bookRuns({ runs: [run('x'.repeat(65537))] })).toThrow();
  expect(() => bookRuns({ runs: Array.from({ length: 2049 }, () => run('')) })).toThrow();
});
it('retains explicit run ink/font/emphasis and line break context', () => {
  const { container } = render(<BookPage runs={bookRuns({ runs: [run(),{ br: true, ink: '#Ab12Ef',face:'verdana',bold:1,italic:1 }] })} />);
  const span=container.querySelectorAll('span')[1];
  expect(span.style.color).toBe('rgb(171, 18, 239)');expect(span.style.fontFamily).toBe('Verdana');
  expect(span.style.fontWeight).toBe('700');expect(span.style.fontStyle).toBe('italic');expect(span.querySelector('br')).not.toBeNull();
});
it('does not claim visual acceptance in an unsupported DOM environment', () => {
  const { container } = render(<BookPage runs={[]} />);
  expect(bookRenderingSupported(container.querySelector('article')!,[])).toBe(false);
});
