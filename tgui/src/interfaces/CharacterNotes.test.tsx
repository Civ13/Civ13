import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, render, screen } from '@testing-library/react';
vi.mock('tgui-core/components', () => ({ Section: ({ children }: any) => <section>{children}</section> }));
import { CharacterNotes, notesText } from './CharacterNotes';
import type { Data, ScreenProps } from '../types';
afterEach(cleanup);
const run = (text: string, bold = 0, italic = 0) => ({ text, bold, italic });
const ui = (data: Data = {}): ScreenProps => ({ template: 'character_notes.tmpl', interactive: false, act: vi.fn(), data: {
  character: [run('Fictional observer')], sections: [{ title: [run('Role')], entries: [{ runs: [run('Guard ', 1), run('the gate', 1, 1), { br: 1 }, run('Second line.')] }] }],
  memory: [run('Saved &amp; private &lt;script&gt;inert&lt;/script&gt;')],
  discoveries: [{ br: 1 }, run('Discoveries', 1), { br: 1 }, run('No discoveries recorded.', 0, 1)], ...data,
} });
describe('Character Notes', () => {
  it('renders character, ordered sections and semantic emphasis/breaks without controls', () => {
    const props = ui(); const { container } = render(<CharacterNotes {...props} />);
    expect(container.textContent).toContain('You are Fictional observer');
    expect(screen.getByRole('heading', { name: 'Role' })).toBeTruthy();
    expect(screen.getByText('Guard').tagName).toBe('STRONG');
    expect(screen.getByText('the gate').closest('strong')).toBeTruthy();
    expect(screen.getByText('the gate').tagName).toBe('EM');
    expect(container.querySelectorAll('br')).toHaveLength(3);
    expect(container.querySelectorAll('button,a,input,textarea,select')).toHaveLength(0); expect(props.act).not.toHaveBeenCalled();
  });
  it('decodes exactly once and keeps encoded markup inert', () => {
    const { container } = render(<CharacterNotes {...ui({ memory: [run('&amp;lt;b&amp;gt; literal &lt;img src=x onerror=alert(1)&gt;')] })} />);
    expect(container.textContent).toContain('&lt;b&gt; literal <img src=x onerror=alert(1)>');
    expect(container.querySelectorAll('img,script,[onerror]')).toHaveLength(0);
  });
  it('retains multilingual/emoji text and literal ampersands without slicing', () => {
    const value = 'Исследование 日本語 😀 & something &amp; preserved.';
    render(<CharacterNotes {...ui({ memory: [run(value)] })} />);
    expect(screen.getByText('Исследование 日本語 😀 & something & preserved.')).toBeTruthy();
  });
  it('clears all old sections and private text on a new complete snapshot', () => {
    const { rerender, container } = render(<CharacterNotes {...ui()} />);
    rerender(<CharacterNotes {...ui({ character: [run('Second reader')], sections: [], memory: [run('No memories stored.')], discoveries: [run('No discoveries recorded.')] })} />);
    expect(container.textContent).toContain('Second reader'); expect(screen.queryByRole('heading', { name: 'Role' })).toBeNull();
    expect(container.textContent).not.toContain('Saved & private'); expect(container.textContent).not.toContain('the gate');
  });
  it('rejects unsupported entities, malformed flags and raw markup for cached-classic recovery', () => {
    for (const value of ['&copy;', '&#128;', '&#0;', '&#55296;', '&#1114112;', '&#x27;', '&amp', '&QuOt;', '<b>raw</b>', 'x\u0000y']) expect(() => notesText(value)).toThrow();
    for (const value of ['&amp;', '&AMP;', '&quot;', '&apos;', '&#39;', '&#128512;', 'plain & text']) expect(() => notesText(value)).not.toThrow();
    expect(() => render(<CharacterNotes {...ui({ memory: [{ text: 'private', bold: '1', italic: 0 }] })} />)).toThrow();
    expect(() => render(<CharacterNotes {...ui({ memory: [{ text: '<script>raw</script>', bold: 0, italic: 0 }] })} />)).toThrow();
  });
  it('rejects oversized Unicode or node payloads whole rather than rendering a truncated subset', () => {
    expect(() => render(<CharacterNotes {...ui({ memory: [run('😀'.repeat(40000))] })} />)).toThrow();
    expect(() => render(<CharacterNotes {...ui({ memory: Array.from({ length: 2049 }, () => run('x')) })} />)).toThrow();
  });
});
