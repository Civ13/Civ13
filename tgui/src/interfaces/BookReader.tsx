import { useLayoutEffect, useRef, useState, type CSSProperties, type RefObject } from 'react';
import type { Data, ScreenProps } from '../types';
import { text } from './common';

type Face = 'times' | 'verdana';
export type BookRun = { text?: string; br?: true; ink: string; face: Face; bold: boolean; italic: boolean };
const faces: Record<Face, string> = { times: '"Times New Roman", serif', verdana: 'Verdana' };
const named = new Set(['amp', 'lt', 'gt', 'quot', 'apos', 'AMP', 'LT', 'GT', 'QUOT']);
export function bookText(encoded: unknown): string {
  if (typeof encoded !== 'string' || /[<\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(encoded)) throw new Error('Unsupported book text');
  for (let i = 0; i < encoded.length; i++) {
    const code = encoded.charCodeAt(i);
    if (code >= 0xd800 && code <= 0xdbff) {
      const next = encoded.charCodeAt(++i);
      if (!(next >= 0xdc00 && next <= 0xdfff)) throw new Error('Unsupported book Unicode');
    } else if (code >= 0xdc00 && code <= 0xdfff) throw new Error('Unsupported book Unicode');
  }
  for (const match of encoded.matchAll(/&(?=[A-Za-z#])/g)) {
    const start = match.index + 1, end = encoded.indexOf(';', start);
    if (end < 0 || end - start > 16) throw new Error('Unsupported book entity');
    const entity = encoded.slice(start, end);
    if (named.has(entity)) continue;
    if (!/^#[0-9]{1,7}$/.test(entity)) throw new Error('Unsupported book entity');
    const point = Number(entity.slice(1));
    if (point <= 0 || point > 0x10ffff || (point >= 0xd800 && point <= 0xdfff) || (point >= 127 && point <= 159) || (point < 32 && ![9, 10, 13].includes(point))) throw new Error('Unsupported book entity');
  }
  return text(encoded); // One pure text decode; never HTML insertion.
}
const flag = (value: unknown): boolean => {
  if (value === true || value === 1) return true;
  if (value === false || value === 0) return false;
  throw new Error('Unsupported book flag');
};
export function bookRuns(data: Data): BookRun[] {
  if (Object.keys(data).sort().join(',') !== 'runs' || !Array.isArray(data.runs) || data.runs.length > 2048) throw new Error('Unsupported book snapshot');
  let units = 0;
  return data.runs.map(run => {
    if (!run || typeof run !== 'object' || Array.isArray(run)) throw new Error('Unsupported book node');
    const hasBreak = run.br === true || run.br === 1;
    const expected = hasBreak ? 'bold,br,face,ink,italic' : 'bold,face,ink,italic,text';
    if (Object.keys(run).sort().join(',') !== expected || !['times', 'verdana'].includes(run.face) || typeof run.ink !== 'string' || !/^#[0-9a-f]{6}$/i.test(run.ink)) throw new Error('Unsupported book metadata');
    const bold = flag(run.bold), italic = flag(run.italic);
    if (hasBreak) return { br: true, ink: run.ink.toLowerCase(), face: run.face, bold, italic };
    if (typeof run.text !== 'string' || (units += run.text.length) > 65536) throw new Error('Book text budget');
    return { text: bookText(run.text), ink: run.ink.toLowerCase(), face: run.face, bold, italic };
  });
}
const pageStyle: CSSProperties = {
  backgroundColor: '#FFFFFF', backgroundImage: 'none', color: '#000000', colorScheme: 'only light',
  fontFamily: faces.times, fontSize: '16px', fontStyle: 'normal', fontWeight: 400,
  lineHeight: 'normal', letterSpacing: 'normal', wordSpacing: 'normal', fontVariant: 'normal',
  textTransform: 'none', textDecoration: 'none', textShadow: 'none',
  whiteSpace: 'normal', wordBreak: 'normal', overflowWrap: 'normal', textIndent: 0,
  opacity: 1, filter: 'none', mixBlendMode: 'normal', WebkitTextFillColor: '#000000', WebkitTextStrokeWidth: 0,
  userSelect: 'text', WebkitUserSelect: 'text', padding: '8px', minHeight: '32px', overflow: 'auto',
};
export function BookPage({ runs, pageRef }: { runs: BookRun[]; pageRef?: RefObject<HTMLElement | null> }) {
  // Ordinary DOM text stays selectable and accessible, including white ink.
  // No hidden-text summary, title, aria label, copy/search/reveal control.
  return <article ref={pageRef} className="book-page" style={pageStyle}>
    {runs.map((run, index) => <span key={index} data-book-run={index} style={{
      color: run.ink, WebkitTextFillColor: run.ink, WebkitTextStrokeWidth: 0,
      fontFamily: faces[run.face], fontSize: '16px', fontWeight: run.bold ? 700 : 400,
      fontStyle: run.italic ? 'italic' : 'normal', lineHeight: 'normal',
      textShadow: 'none', textTransform: 'none', textDecoration: 'none', letterSpacing: 'normal', wordSpacing: 'normal',
      backgroundColor: 'transparent', backgroundImage: 'none', opacity: 1, filter: 'none', mixBlendMode: 'normal',
    }}>{run.br ? <br /> : run.text}</span>)}
  </article>;
}
const rgb = (ink: string) => `rgb(${parseInt(ink.slice(1, 3), 16)}, ${parseInt(ink.slice(3, 5), 16)}, ${parseInt(ink.slice(5, 7), 16)})`;
export function bookRenderingSupported(page: HTMLElement, runs: BookRun[]): boolean {
  const w = page.ownerDocument.defaultView;
  if (!w || typeof w.matchMedia !== 'function' || w.matchMedia('(forced-colors: active)').matches || w.matchMedia('print').matches) return false;
  const clean = (s: CSSStyleDeclaration) => s.opacity === '1' && s.filter === 'none' && s.mixBlendMode === 'normal' && s.textShadow === 'none';
  const p = w.getComputedStyle(page);
  if (!clean(p) || p.backgroundColor !== 'rgb(255, 255, 255)' || p.backgroundImage !== 'none' || p.color !== 'rgb(0, 0, 0)' || p.webkitTextFillColor !== 'rgb(0, 0, 0)' || p.webkitTextStrokeWidth !== '0px' || p.fontSize !== '16px' || p.userSelect !== 'text' || page.scrollWidth > page.clientWidth) return false;
  for (let ancestor = page.parentElement; ancestor; ancestor = ancestor.parentElement) {
    const s = w.getComputedStyle(ancestor);
    if (s.opacity !== '1' || s.filter !== 'none' || s.mixBlendMode !== 'normal' || s.transform !== 'none') return false;
  }
  const elements = [...page.querySelectorAll<HTMLElement>('[data-book-run]')];
  if (elements.length !== runs.length) return false;
  return elements.every((element, index) => {
    const run = runs[index], s = w.getComputedStyle(element), family = s.fontFamily.split(',')[0].replaceAll('"', '').trim().toLowerCase();
    return clean(s) && s.color === rgb(run.ink) && s.webkitTextFillColor === rgb(run.ink) && s.webkitTextStrokeWidth === '0px'
      && s.backgroundColor === 'rgba(0, 0, 0, 0)' && s.backgroundImage === 'none' && s.fontSize === '16px'
      && family === (run.face === 'times' ? 'times new roman' : 'verdana')
      && s.fontWeight === (run.bold ? '700' : '400') && s.fontStyle === (run.italic ? 'italic' : 'normal');
  });
}
export function BookReader({ data }: ScreenProps) {
  const runs = bookRuns(data), page = useRef<HTMLElement>(null), [invalid, setInvalid] = useState(false);
  useLayoutEffect(() => {
    const element = page.current;
    if (!element || typeof MutationObserver !== 'function' || typeof ResizeObserver !== 'function') { setInvalid(true); return; }
    let active = true;
    const verify = () => { if (active && !bookRenderingSupported(element, runs)) setInvalid(true); };
    // Layout effect runs before browser paint. Unsupported engines use the
    // original authorized snapshot, without attempting partial rendering.
    if (!bookRenderingSupported(element, runs)) { setInvalid(true); return; }
    const observer = new MutationObserver(verify);
    observer.observe(element, { subtree: true, childList: true, attributes: true, attributeFilter: ['class', 'style'] });
    for (let ancestor = element.parentElement; ancestor; ancestor = ancestor.parentElement) observer.observe(ancestor, { attributes: true, attributeFilter: ['class', 'style'] });
    observer.observe(document.head, { subtree: true, childList: true, characterData: true, attributes: true });
    const resize = new ResizeObserver(verify); resize.observe(element);
    const forced = window.matchMedia('(forced-colors: active)'), print = window.matchMedia('print');
    forced.addEventListener('change', verify); print.addEventListener('change', verify); window.addEventListener('resize', verify);
    document.head.addEventListener('load', verify, true);
    return () => { active = false; observer.disconnect(); resize.disconnect(); forced.removeEventListener('change', verify); print.removeEventListener('change', verify); window.removeEventListener('resize', verify); document.head.removeEventListener('load', verify, true); };
  }, [runs]);
  if (invalid) throw new Error('Unsupported book rendering conditions');
  return <BookPage runs={runs} pageRef={page} />;
}
