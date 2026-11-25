import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, screen, within } from '@testing-library/react';
import { render } from '../testing';

vi.mock('tgui-core/components', () => ({
  Button: ({ children, onClick, disabled, className }: any) => <button type="button" className={className} disabled={disabled} onClick={onClick}>{children}</button>,
  Section: ({ children, title }: any) => <section><h2>{title}</h2>{children}</section>,
  NoticeBox: ({ children }: any) => <aside>{children}</aside>,
}));
import { StorageWindow, refusal } from './StorageWindow';
import { screens } from '../fixtures.mts';
import type { ScreenProps } from '../types';

afterEach(cleanup);
const fixture = screens.find(screen => screen.template === 'storage_window.tmpl')!;
const ui = (data: ScreenProps['data'] = fixture.data, interactive = true): ScreenProps => ({ template: 'storage_window.tmpl', data, interactive, act: vi.fn() });

describe('Storage window', () => {
  it('lists your things and the things nearby with room and moves', () => {
    render(<StorageWindow {...ui()} />);
    const you = screen.getByLabelText('You');
    expect(within(you).getByText('flint knife')).toBeTruthy();
    expect(within(you).getByText('Right hand')).toBeTruthy();
    expect(within(you).getByText('10 / 16 space')).toBeTruthy();
    const near = screen.getByLabelText('Nearby');
    expect(within(near).getByText('wheat grain')).toBeTruthy();
    expect(within(near).getByText('Locked')).toBeTruthy();
    expect(within(near).queryByText('Take all', { selector: '[aria-label="hewn log chest"] *' })).toBeNull();
    expect(screen.getByText(/Moving/).textContent).toContain('2');
    expect(screen.getByText('Cancel all')).toBeTruthy();
  });
  it('moves a selection with Move here and sends the ids', () => {
    const props = ui(); render(<StorageWindow {...props} />);
    fireEvent.click(screen.getByText('wheat grain').closest('button')!);
    fireEvent.click(screen.getByText('clay bowl').closest('button')!);
    const backpack = screen.getByLabelText('leather backpack');
    fireEvent.click(within(backpack).getByText('Move here'));
    expect(props.act).toHaveBeenCalledWith('move', { value: 'i6,i7', to: 'worn:b' });
  });
  it.each(['click', 'drag', 'keyboard', 'hands'])('retains an oversized selection for %s and can retry at the server limit', action => {
    const entries = Array.from({ length: 41 }, (_, i) => ({ id: `i${i}`, name: `Item ${i}` }));
    const props = ui({ move_limit: 40, hands_id: 'hands', hands: [{ side: 'left' }], near: [
      ...Array.from({ length: 5 }, (_, i) => ({ id: `crate${i}`, kind: 'near', name: `Crate ${i}`, items: entries.slice(i * 9, i * 9 + 9) })),
      { id: 'floor', kind: 'floor', name: 'Floor', items: [] },
    ] });
    render(<StorageWindow {...props} />);
    const item = (i: number) => screen.getByTitle(`Item ${i}`);
    const floor = screen.getByLabelText('Floor');
    if (action === 'keyboard') {
      fireEvent.click(item(0));
      fireEvent.click(within(floor).getByText('Move here'));
      vi.mocked(props.act).mockClear();
    }
    for (let i = 0; i < 41; i++) fireEvent.click(item(i));
    const message = 'Move up to 40 items at a time. Deselect items to continue.';
    expect(screen.getByRole('status').textContent).toBe(message);
    if (action === 'click') fireEvent.click(within(floor).getByText('Move here'));
    else if (action === 'keyboard') fireEvent.keyDown(item(0), { key: 'Enter' });
    else if (action === 'hands') fireEvent.click(screen.getByText('To hands'));
    else {
      const dataTransfer = { setData: vi.fn(), effectAllowed: '' };
      fireEvent.dragStart(item(0), { dataTransfer });
      fireEvent.dragOver(floor, { dataTransfer });
      fireEvent.drop(floor, { dataTransfer });
    }
    expect(props.act).not.toHaveBeenCalled();
    expect(screen.getAllByRole('button', { pressed: true })).toHaveLength(41);
    fireEvent.click(item(40));
    expect(screen.queryByRole('status')).toBeNull();
    fireEvent.click(within(floor).getByText('Move here'));
    expect(props.act).toHaveBeenCalledExactlyOnceWith('move', {
      value: entries.slice(0, 40).map(entry => entry.id).join(','), to: 'floor',
    });
  });
  it('uses the snapshot limit even when it is below 40', () => {
    const props = ui({ ...fixture.data, move_limit: 1 });
    render(<StorageWindow {...props} />);
    fireEvent.click(screen.getByTitle('wheat grain'));
    fireEvent.click(screen.getByTitle('clay bowl'));
    fireEvent.click(within(screen.getByLabelText('leather backpack')).getByText('Move here'));
    expect(props.act).not.toHaveBeenCalled();
    expect(screen.getByRole('status').textContent).toContain('up to 1 item');
  });
  it('asks before dumping and then dumps', () => {
    const props = ui(); render(<StorageWindow {...props} />);
    const basket = screen.getByLabelText('woven basket');
    fireEvent.click(within(basket).getByText('Dump out'));
    expect(props.act).not.toHaveBeenCalled();
    const ask = within(basket).getByRole('group', { name: 'Dump out' });
    fireEvent.click(within(ask).getByText('Dump out'));
    expect(props.act).toHaveBeenCalledWith('dump', { value: 'near:c' });
  });
  it('filters by name and says how many are shown', () => {
    render(<StorageWindow {...ui()} />);
    fireEvent.change(screen.getByLabelText('Find'), { target: { value: 'grain' } });
    expect(screen.getByTitle('wheat grain').querySelector('mark')?.textContent).toBe('grain');
    expect(screen.queryByText('clay bowl')).toBeNull();
    expect(screen.getByText('of 11 things shown', { exact: false })).toBeTruthy();
  });
  it('shows what is not seen yet as size boxes and searches on request', () => {
    const props = ui(); render(<StorageWindow {...props} />);
    const sling = screen.getByLabelText('hide sling bag');
    expect(within(sling).getByText('bone needle')).toBeTruthy();
    expect(within(sling).getByText('Searching... 2 of 5')).toBeTruthy();
    expect(within(sling).getByText('3 not seen yet')).toBeTruthy();
    expect(within(sling).queryByText('Dump out')).toBeNull();
    expect(within(sling).queryByText('Search')).toBeNull();
    const jar = screen.getByLabelText('clay storage jar');
    expect(within(jar).getByText('2 things are inside. Search it to see what.')).toBeTruthy();
    fireEvent.click(within(jar).getByText('Search'));
    expect(props.act).toHaveBeenCalledWith('search', { value: 'near:g' });
  });
  it('counts a crate in things, not space', () => {
    render(<StorageWindow {...ui()} />);
    expect(within(screen.getByLabelText('wooden crate')).getByText('1 / 10 things')).toBeTruthy();
  });
  it('explains a refusal before the drop', () => {
    const jar = { id: 'j', kind: 'near', max_size: 2, slots: 6, space: 12, used: 0, items: [] };
    expect(refusal(jar, [{ id: 'x', name: 'wood log', size_class: 4, cost: 8 }], 1)).toBeTruthy();
    expect(refusal(jar, [{ id: 'x', name: 'flint', size_class: 1, cost: 1 }], 1)).toBeNull();
    expect(refusal({ kind: 'hands' }, [{ id: 'x' }], 0)).toBeTruthy();
    expect(refusal({ kind: 'near', locked: 1 }, [{ id: 'x' }], 1)).toBe('It is locked.');
  });
  it.each([undefined, null, {}])('copes with an empty snapshot (%s)', data => {
    render(<StorageWindow {...ui(data ?? {})} />);
    expect(screen.getByLabelText('You')).toBeTruthy();
    expect(screen.queryByText('Cancel all')).toBeNull();
  });
  it('keeps names inert', () => {
    const view = render(<StorageWindow {...ui({ near: [{ id: 'n', kind: 'near', name: '<b>x</b>', items: [{ id: 'q', name: '<img src=x>' }] }] })} />);
    expect(screen.getByText('<img src=x>')).toBeTruthy();
    expect(view.container.querySelector('b img, img[src="x"]')).toBeNull();
  });
});
