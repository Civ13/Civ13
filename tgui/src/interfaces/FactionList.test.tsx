import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, render, screen, within } from '@testing-library/react';
vi.mock('tgui-core/components', () => ({
  Section: ({ children, title }: any) => <section><h2>{title}</h2>{children}</section>,
  NoticeBox: ({ children }: any) => <aside>{children}</aside>,
}));
import { FactionList } from './FactionList';
import type { ScreenProps } from '../types';
afterEach(cleanup);
const ui = (factions?: any): ScreenProps => ({
  template: 'faction_list.tmpl', data: { factions }, interactive: true, act: vi.fn(),
});
describe('Faction List snapshot', () => {
  it('retains order, details, member grammar and optional delivered symbols without actions', () => {
    const props = ui([
      { name: 'First', motto: 'Together', flavour: 'Fictional coast', members: 1, symbol: 'flist_first.png' },
      { name: 'Second', members: 12, symbol: '' },
    ]);
    const view = render(<FactionList {...props} />);
    const rows = within(screen.getByRole('table', { name: 'Faction list' })).getAllByRole('row');
    expect(rows).toHaveLength(3);
    expect(within(rows[1]).getByRole('rowheader').textContent).toContain('First');
    expect(within(rows[2]).getByRole('rowheader').textContent).toContain('Second');
    expect(screen.getByText('1 member.')).toBeTruthy();
    expect(screen.getByText('12 members.')).toBeTruthy();
    expect(screen.getByText('Together').tagName).toBe('EM');
    expect(screen.getByText('Fictional coast')).toBeTruthy();
    const images = view.container.querySelectorAll('img');
    expect(images).toHaveLength(1);
    expect(images[0].getAttribute('src')).toBe('flist_first.png');
    expect(images[0].getAttribute('alt')).toBe('');
    expect(images[0].width).toBe(32);
    expect(screen.queryByRole('button')).toBeNull();
    expect(screen.queryByRole('link')).toBeNull();
    expect(props.act).not.toHaveBeenCalled();
  });
  it('replaces a previous snapshot without retaining old symbols or details', () => {
    const view = render(<FactionList {...ui([{ name: 'Old', motto: 'Old motto', members: 1, symbol: 'flist_old.png' }])} />);
    view.rerender(<FactionList {...ui([{ name: 'Current', members: 2 }])} />);
    expect(screen.queryByText('Old')).toBeNull();
    expect(screen.queryByText('Old motto')).toBeNull();
    expect(screen.getByText('Current')).toBeTruthy();
    expect(view.container.querySelector('img')).toBeNull();
  });
  it.each([undefined, null, [], {}])('shows a useful empty state (%s)', factions => {
    render(<FactionList {...ui(factions)} />);
    expect(screen.getByText('No populated factions are available.')).toBeTruthy();
    expect(screen.queryByRole('table')).toBeNull();
  });
  it('keeps encoded rich-looking text inert and accepts only local symbol basenames', () => {
    const invalid = ['https://example.com/a.png', '//example.com/a.png', 'data:image/png,a', '../flist_a.png',
      'flist_../a.png', 'flist_a.png?x=1', 'flist_a%2fb.png', 'flist_a\\b.png', 'flist_a.png#x', 'flist_a b.png'];
    const view = render(<FactionList {...ui([
      { name: '&lt;img src=x onerror=alert(1)&gt;', motto: '&lt;script&gt;one&lt;/script&gt;', flavour: '&amp; coast', members: 3, symbol: 'flist_кириллица.png' },
      ...invalid.map(symbol => ({ name: 'Invalid', members: 1, symbol })),
    ])} />);
    expect(screen.getByText('<img src=x onerror=alert(1)>')).toBeTruthy();
    expect(screen.getByText('<script>one</script>')).toBeTruthy();
    expect(screen.getByText('& coast')).toBeTruthy();
    expect(view.container.querySelector('script')).toBeNull();
    expect(view.container.querySelectorAll('img')).toHaveLength(1);
    expect(view.container.querySelector('img')?.getAttribute('src')).toBe(encodeURIComponent('flist_кириллица.png'));
  });
});
