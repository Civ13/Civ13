import { useState } from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
import { Window } from './layouts';
import { TitleBar, TitleBarSlot, useNativeTitleBar, winget } from './titlebar';

afterEach(() => { cleanup(); delete (window as { cef_to_byond?: unknown }).cef_to_byond; });

function capture() {
  const urls: URL[] = [];
  (window as { cef_to_byond?: unknown }).cef_to_byond = (url: string) => { urls.push(new URL(url)); };
  return urls;
}

function Native({ id, own }: { id: string; own: boolean }) { useNativeTitleBar(id, own); return null; }

describe('window title bar', () => {
  it('hides BYOND\'s bar only while the window draws its own, and gives it back', () => {
    const urls = capture();
    const view = render(<Native id="w1" own={false} />);
    expect(urls).toHaveLength(0);
    view.rerender(<Native id="w1" own />);
    expect(urls.map(url => [url.host, url.searchParams.get('id'), url.searchParams.get('titlebar'), url.searchParams.get('can-resize')])).toEqual([['winset', 'w1', 'false', 'false']]);
    view.rerender(<Native id="w1" own />);
    view.rerender(<Native id="w1" own={false} />);
    expect(urls.map(url => url.searchParams.get('titlebar'))).toEqual(['false', 'true']);
  });

  it('shows the title and status, and closes through the server', () => {
    const close = vi.fn();
    render(<TitleBar title="Integrated Circuit" status={1} windowId="w1" onSlot={() => {}} onClose={close} />);
    expect(screen.getByRole('heading', { name: 'Integrated Circuit' })).toBeTruthy();
    expect(screen.getByRole('img', { name: 'Read-only' })).toBeTruthy();
    fireEvent.click(screen.getByRole('button', { name: 'Close' }));
    expect(close).toHaveBeenCalledOnce();
  });

  it('moves the window by the distance the pointer travels from where BYOND says it is', async () => {
    const urls = capture();
    const frames: FrameRequestCallback[] = [];
    vi.spyOn(window, 'requestAnimationFrame').mockImplementation(callback => { frames.push(callback); return frames.length; });
    render(<TitleBar title="Moving" status={2} windowId="w1" onSlot={() => {}} onClose={() => {}} />);
    const bar = screen.getByRole('heading', { name: 'Moving' }).parentElement!;
    fireEvent.pointerDown(bar, { button: 0, pointerId: 1, screenX: 100, screenY: 50 });
    const ask = urls.at(-1)!;
    expect([ask.host, ask.searchParams.get('property')]).toEqual(['winget', 'pos']);
    (window as unknown as Record<string, (props: unknown) => void>)[ask.searchParams.get('callback')!]({ pos: { x: 300, y: 200 } });
    await Promise.resolve();
    fireEvent.pointerMove(bar, { pointerId: 1, screenX: 130, screenY: 40 });
    frames.splice(0).forEach(frame => frame(0));
    expect(urls.at(-1)!.searchParams.get('pos')).toBe('330,190');
    fireEvent.pointerUp(bar, { pointerId: 1 });
    fireEvent.pointerMove(bar, { pointerId: 1, screenX: 500, screenY: 500 });
    frames.splice(0).forEach(frame => frame(0));
    expect(urls.at(-1)!.searchParams.get('pos')).toBe('330,190');
    vi.restoreAllMocks();
  });

  it('does not start a drag from a button in the bar', () => {
    const urls = capture();
    render(<TitleBar title="Buttons" status={2} windowId="w1" onSlot={() => {}} onClose={() => {}} />);
    fireEvent.pointerDown(screen.getByRole('button', { name: 'Close' }), { button: 0, pointerId: 1 });
    expect(urls).toHaveLength(0);
  });

  it('ignores a winget answer without the property', async () => {
    capture();
    const answer = winget('w1', 'size');
    const name = Object.keys(window).find(key => key.startsWith('civ13Winget'))!;
    (window as unknown as Record<string, (props: unknown) => void>)[name]({});
    await expect(answer).resolves.toBeNull();
  });

  it('puts a layout\'s buttons in the title bar when the window has one', () => {
    function Harness({ own }: { own: boolean }) {
      const [slot, setSlot] = useState<HTMLElement | null>(null);
      return <TitleBarSlot.Provider value={own ? slot : null}>
        <TitleBar title="Circuit" status={2} windowId="w1" onSlot={setSlot} onClose={() => {}} />
        <Window buttons={<button type="button">Save</button>}><p>canvas</p></Window>
      </TitleBarSlot.Provider>;
    }
    const view = render(<Harness own />);
    expect(screen.getByRole('button', { name: 'Save' }).closest('.civ13-titlebar')).toBeTruthy();
    view.rerender(<Harness own={false} />);
    expect(screen.getByRole('button', { name: 'Save' }).closest('.civ13-titlebar')).toBeNull();
    expect(screen.getByRole('button', { name: 'Save' }).closest('.wiremod-window__buttons')).toBeTruthy();
  });
});
