import React from 'react';
import { afterEach, expect, it, vi } from 'vitest';
import { act as flush, cleanup, fireEvent, screen } from '@testing-library/react';
import { render } from '../testing';
vi.mock('tgui-core/components', () => ({
  Section: ({ children, title }: any) => <section><h2>{title}</h2>{children}</section>,
  NoticeBox: ({ children }: any) => <aside>{children}</aside>,
  Button: ({ children, onClick, disabled, selected }: any) => <button disabled={disabled} aria-pressed={selected ? 'true' : undefined} onClick={onClick}>{children}</button>,
}));
import { SEARCH_DELAY, SpawnMenu } from './SpawnMenu';
const props = (data: Record<string, unknown>, interactive = true) => ({ template: 'spawn_menu.tmpl', interactive, act: vi.fn(), data });
afterEach(() => { cleanup(); vi.useRealTimers(); });

it('sends the search once typing stops, not on every key', () => {
  vi.useFakeTimers();
  const ui = props({ query: '', results: [], types: 900 });
  render(<SpawnMenu {...ui} />);
  const box = screen.getByLabelText('Search types');
  fireEvent.change(box, { target: { value: 'ri' } });
  fireEvent.change(box, { target: { value: 'rifle' } });
  expect(ui.act).not.toHaveBeenCalled();
  flush(() => { vi.advanceTimersByTime(SEARCH_DELAY); });
  expect(ui.act).toHaveBeenCalledTimes(1);
  expect(ui.act).toHaveBeenCalledWith('search', { value: 'rifle' });
});

it('Enter searches at once and an unchanged search is not sent again', () => {
  const ui = props({ query: 'rifle', results: [] });
  render(<SpawnMenu {...ui} />);
  const box = screen.getByLabelText('Search types');
  fireEvent.keyDown(box, { key: 'Enter' });
  expect(ui.act).not.toHaveBeenCalled();
  fireEvent.change(box, { target: { value: 'sword' } });
  fireEvent.keyDown(box, { key: 'Enter' });
  expect(ui.act).toHaveBeenCalledWith('search', { value: 'sword' });
});

it('spawns the picked path with the clamped amount and places turfs', () => {
  const ui = props({ query: 'steel', matches: 300, max_amount: 50, results: [
    { path: '/obj/item/stack/material/steel', name: 'steel sheets', kind: 'obj' },
    { path: '/turf/floor/plating', name: 'plating', kind: 'turf' },
  ] });
  render(<SpawnMenu {...ui} />);
  expect(screen.getByText('Best 2 of 300 matches')).toBeTruthy();
  fireEvent.change(screen.getByLabelText('Amount'), { target: { value: '500' } });
  fireEvent.click(screen.getByText('Spawn 50'));
  expect(ui.act).toHaveBeenCalledWith('spawn', { value: '/obj/item/stack/material/steel', amount: 50 });
  expect(screen.getByText('Place')).toBeTruthy();
});

it('shows recent spawns or a hint when nothing is searched, and locks controls when not allowed', () => {
  const view = render(<SpawnMenu {...props({ query: '', results: [], types: 41873 }, false)} />);
  expect(screen.getByText(/search 41873 types/)).toBeTruthy();
  expect((screen.getByLabelText('Search types') as HTMLInputElement).disabled).toBe(true);
  view.unmount();
  render(<SpawnMenu {...props({ query: '', results: [{ path: '/obj/item/a', name: 'a', kind: 'obj' }] })} />);
  expect(screen.getByText('Recently spawned')).toBeTruthy();
});

it('renders names as inert text', () => {
  const view = render(<SpawnMenu {...props({ query: 'x', matches: 1, results: [{ path: '/obj/x', name: '<img src=x onerror=alert(1)>', kind: 'obj' }] })} />);
  expect(view.container.textContent).toContain('<img src=x onerror=alert(1)>');
  expect(view.container.querySelector('img')).toBeNull();
});
