import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react';
// These tests isolate our screen logic from tgui-core's layout/tooltip machinery.
vi.mock('tgui-core/components', () => ({
  Button: ({ children, onClick, disabled, selected }: any) => <button disabled={disabled} onClick={onClick} aria-pressed={selected}>{children}</button>,
  Section: ({ children, title, buttons }: any) => <section><h2>{title}</h2>{buttons}{children}</section>,
  NoticeBox: ({ children }: any) => <aside>{children}</aside>,
}));
import { Faction, lineCells, strokeChunks } from './Faction';
import { Research, lockedAncestors } from './Research';
import type { ScreenProps } from '../types';
const faction = (): ScreenProps => ({ template: 'faction_symbol.tmpl', interactive: true, data: { grid: Array(1024).fill('#ffffff'), tool: 'paint', color: '#ff0000' }, act: vi.fn() });
afterEach(() => { cleanup(); vi.useRealTimers(); });
describe('faction parity', () => {
  it('interpolates and chunks a drag without losing or duplicating cells', () => {
    expect(lineCells(1, 1, 3, 3)).toEqual(['1,1', '2,2', '3,3']);
    const cells = Array.from({ length: 121 }, (_, i) => `${i % 32 + 1},${Math.floor(i / 32) + 1}`);
    expect(strokeChunks(cells).map(x => x.split('_').length)).toEqual([60, 60, 1]);
    expect(strokeChunks(cells).join('_')).toBe(cells.join('_'));
  });
  it('serializes chunks and blocks undo until the final navigation settles', () => {
    vi.useFakeTimers();
    const ui = faction(); render(<Faction {...ui} />);
    fireEvent.mouseDown(screen.getByLabelText('Pixel 1,1'), { button: 0, buttons: 1 });
    fireEvent.mouseOver(screen.getByLabelText('Pixel 32,1'), { buttons: 1 });
    fireEvent.mouseOver(screen.getByLabelText('Pixel 32,32'), { buttons: 1 });
    fireEvent.mouseUp(document);
    expect(ui.act).toHaveBeenCalledTimes(1);
    fireEvent.click(screen.getByText('Undo'));
    expect(ui.act).toHaveBeenCalledTimes(1);
    act(() => vi.advanceTimersByTime(250));
    expect(ui.act).toHaveBeenCalledTimes(2);
    expect(vi.mocked(ui.act).mock.calls[1][1]?.stroke_continue).toBe(1);
    act(() => vi.advanceTimersByTime(250));
    fireEvent.click(screen.getByText('Undo'));
    expect(ui.act).toHaveBeenLastCalledWith('undo', { undo: 1 });
  });
  it('cancels remaining chunks when interaction is revoked', () => {
    vi.useFakeTimers();
    const ui = faction(); const view = render(<Faction {...ui} />);
    fireEvent.mouseDown(screen.getByLabelText('Pixel 1,1'), { button: 0, buttons: 1 });
    fireEvent.mouseOver(screen.getByLabelText('Pixel 32,1'), { buttons: 1 });
    fireEvent.mouseOver(screen.getByLabelText('Pixel 32,32'), { buttons: 1 });
    fireEvent.mouseUp(document);
    view.rerender(<Faction {...ui} interactive={false} />);
    act(() => vi.runAllTimers());
    expect(ui.act).toHaveBeenCalledTimes(1);
  });
});
describe('research parity', () => {
  it('highlights only Locked ancestors while traversing all prerequisites, as the legacy script does', () => {
    const nodes = [
      { id: 'target', prereq_ids: 'active,done', status_text: 'Locked' },
      { id: 'active', prereq_ids: 'locked', status_text: 'Studying' },
      { id: 'done', prereq_ids: 'other', status_text: 'Done' },
      { id: 'locked', prereq_ids: '', status_text: 'Locked' },
      { id: 'other', prereq_ids: '', status_text: 'Locked' },
    ];
    expect([...lockedAncestors(nodes, 'target')].sort()).toEqual(['locked', 'other']);
  });
  it('preserves selected tree and open detail across updates and dismisses with Escape', () => {
    const ui: ScreenProps = { template: 'research_bench.tmpl', interactive: true, act: vi.fn(), data: { trees: [
      { idx: 0, tree_name: 'First', layers: [{ layer_name: 'Base', nodes: [{ id: 'a', name: 'First tech' }] }] },
      { idx: 1, tree_name: 'Second', layers: [{ layer_name: 'Base', nodes: [{ id: 'b', name: 'Second tech', assignable: 1 }] }] },
    ] } };
    const view = render(<Research {...ui} />);
    fireEvent.click(screen.getByText('Second'));
    fireEvent.click(screen.getByText('Second tech'));
    expect(screen.getByRole('dialog')).toBeTruthy();
    view.rerender(<Research {...ui} data={{ ...ui.data, bench_tier: 2 }} />);
    expect(screen.getByRole('dialog')).toBeTruthy();
    fireEvent.click(screen.getByText('Assign this bench'));
    expect(ui.act).toHaveBeenCalledWith('assign', { assign: 'b' });
    fireEvent.keyDown(document, { key: 'Escape' });
    expect(screen.queryByRole('dialog')).toBeNull();
    expect(screen.getByText('Second tech')).toBeTruthy();
    expect(screen.queryByText('First tech')).toBeNull();
  });
});

import { Appearance, Chemistry, Vending, Warehouse } from './Standard';
import { interfaces } from './index';
describe('standard screen parity', () => {
  it('registers the existing ten templates, Known Languages and Faction List', () => {
    expect(Object.keys(interfaces).sort()).toEqual([
      'appearance_changer.tmpl',
      'chem_disp.tmpl',
      'faction_creation.tmpl',
      'faction_list.tmpl',
      'faction_symbol.tmpl',
      'known_languages.tmpl',
      'research_bench.tmpl',
      'vending_machine.tmpl',
      'vending_machine2.tmpl',
      'vending_machine_gulag.tmpl',
      'vending_machine_taotd.tmpl',
      'warehouse_book.tmpl',
    ]);
  });
  it('keeps chemistry command payloads, vessel state, and amount controls', () => {
    const ui: ScreenProps = { template: 'chem_disp.tmpl', interactive: true, act: vi.fn(), data: {
      amount: 10, glass: 1, isBeakerLoaded: 1, beakerCurrentVolume: 20, beakerMaxVolume: 50,
      chemicals: [{ title: 'Water (5)', commands: { dispense: 'water' } }], beakerContents: [{ volume: 20, name: 'Water' }],
    } };
    render(<Chemistry {...ui} />);
    fireEvent.click(screen.getByText('Water (5)'));
    expect(ui.act).toHaveBeenLastCalledWith('dispense', { dispense: 'water' });
    fireEvent.click(screen.getByText('30'));
    expect(ui.act).toHaveBeenLastCalledWith('amount', { amount: 30 });
    fireEvent.click(screen.getByText('Eject Glass'));
    expect(ui.act).toHaveBeenLastCalledWith('ejectBeaker', { ejectBeaker: 1 });
    expect(screen.getByText('20 units of Water')).toBeTruthy();
  });
  it('preserves sales purchase, payment cancel and withdrawal, without allowing sold-out purchases', () => {
    const ui: ScreenProps = { template: 'vending_machine2.tmpl', interactive: true, act: vi.fn(), data: {
      mode: 0, company: 'Company', moneyin: 20, currency_short: 's', products: [
        { key: 1, name: 'Bread', amount: 1, price: 5 }, { key: 2, name: 'Empty', amount: 0, price: 0 },
      ],
    } };
    const view = render(<Vending {...ui} />);
    fireEvent.click(screen.getByText('Buy (5 s)'));
    expect(ui.act).toHaveBeenLastCalledWith('vend', { vend: 1 });
    fireEvent.click(screen.getByText('Vend'));
    expect(ui.act).toHaveBeenCalledTimes(1);
    view.rerender(<Vending {...ui} data={{ ...ui.data, mode: 1, product: 'Bread', price: 5 }} />);
    fireEvent.click(screen.getByText('Cancel'));
    expect(ui.act).toHaveBeenLastCalledWith('cancelpurchase', { cancelpurchase: 1 });
    fireEvent.click(screen.getByText('20 s'));
    expect(ui.act).toHaveBeenLastCalledWith('remove_money', { remove_money: 1 });
  });
  it('renders entity-encoded user text as text rather than executable markup', () => {
    const view = render(<Warehouse template="warehouse_book.tmpl" interactive={false} act={vi.fn()}
      data={{ items: [{ name: '&lt;img src=x onerror=alert(1)&gt;', amount: 3 }] }} />);
    expect(screen.getByText('<img src=x onerror=alert(1)>')).toBeTruthy();
    expect(view.container.querySelector('img')).toBeNull();
  });
  it('respects appearance flags and sends chosen values', () => {
    const ui: ScreenProps = { template: 'appearance_changer.tmpl', interactive: true, act: vi.fn(), data: {
      change_gender: 1, genders: [{ gender_name: 'Female', gender_key: 'female' }], change_eye_color: 1,
    } };
    render(<Appearance {...ui} />);
    fireEvent.click(screen.getByText('Female'));
    expect(ui.act).toHaveBeenLastCalledWith('gender', { gender: 'female' });
    fireEvent.click(screen.getByText('Change eye color'));
    expect(ui.act).toHaveBeenLastCalledWith('eye_color', { eye_color: 1 });
    expect(screen.queryByText('Species')).toBeNull();
  });
});
