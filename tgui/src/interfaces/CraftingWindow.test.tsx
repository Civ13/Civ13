import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react';
import { CraftingWindow, matches, seconds } from './CraftingWindow';
import type { Data, ScreenProps } from '../types';

afterEach(cleanup);
const image = 'craft_' + 'a'.repeat(32) + '.png';
const row = (id: string, name: string, state: string, extra: Data = {}): Data => ({
  id, name, state, category: 'General', purpose: 'Building', pinned: 0, recent: 0, cost: '4 logs', why: '', tools: '', desc: '', built: 0, one_per_turf: 0, on_floor: 0,
  time: 140, makes: 1, batches: state === 'ready' ? 1 : 0, atlas: 0, image: '', ...extra,
});
const rows = () => [
  row('0:1:aaaaaaaa', 'campfire', 'ready', { built: 1, one_per_turf: 1, on_floor: 1, desc: 'A campfire made with wood logs.', image, atlas: 1 }),
  row('2:1:bbbbbbbb', '3x arrow shaft', 'ready', { category: 'weapons', purpose: 'Weapons', cost: '1 log', makes: 3, batches: 6, time: 40 }),
  row('0:2:cccccccc', 'travois', 'missing', { cost: '8 logs', why: 'Needs 8 logs, you have 6' }),
  row('3:1:dddddddd', 'hewn table (wooden pegs)', 'missing', { category: 'joinery', purpose: 'Furniture', batches: 1, why: 'Missing a tool, skill or second material', tools: 'Chisel and hammer/mallet equipped or at your feet.' }),
  row('2:2:eeeeeeee', 'shortbow', 'locked', { category: 'weapons', purpose: 'Weapons', cost: '8 logs', why: 'Needs the Archery manual' }),
];
const ui = (data: Data = {}, interactive = true): ScreenProps => ({
  template: 'crafting_window.tmpl', interactive, act: vi.fn(),
  data: { material: 'wood logs', unit: 'log', amount: 6, image, makeable_only: 0, categories: ['weapons', 'joinery'], purposes: ['Tools', 'Weapons', 'Building', 'Furniture', 'Other'], rows: rows(), working: null, more_images: 0, ...data },
});
const rowButton = (name: string) => screen.getByText(name).closest('button') as HTMLButtonElement;

describe('Crafting window', () => {
  it('selects on a click and spends nothing until Craft is pressed', () => {
    const props = ui(); render(<CraftingWindow {...props} />);
    expect(screen.getByText(/Pick a recipe/)).toBeTruthy();
    fireEvent.click(rowButton('campfire'));
    expect(props.act).not.toHaveBeenCalled();
    const card = within(screen.getByLabelText('Selected recipe'));
    expect(card.getByText('A campfire made with wood logs.')).toBeTruthy();
    expect(card.getByText(/Structure · takes 14 seconds · makes 1/)).toBeTruthy();
    expect(card.getByText(/Only one per tile\. Needs a floor under you\./)).toBeTruthy();
    fireEvent.click(card.getByText('Craft'));
    expect(props.act).toHaveBeenCalledTimes(1);
    expect(props.act).toHaveBeenLastCalledWith('make', { make: '0:1:aaaaaaaa', quantity: 1 });
  });
  it('crafts one on a double click of a ready row only', () => {
    const props = ui(); render(<CraftingWindow {...props} />);
    fireEvent.doubleClick(rowButton('travois'));
    expect(props.act).not.toHaveBeenCalled();
    fireEvent.doubleClick(rowButton('campfire'));
    expect(props.act).toHaveBeenLastCalledWith('make', { make: '0:1:aaaaaaaa', quantity: 1 });
  });
  it('names what is missing and keeps Craft off', () => {
    const props = ui(); render(<CraftingWindow {...props} />);
    fireEvent.click(rowButton('travois'));
    let card = within(screen.getByLabelText('Selected recipe'));
    expect(card.getByText('Missing:', { exact: false }).parentElement?.textContent).toContain('8 logs');
    expect((card.getByText('Craft') as HTMLButtonElement).disabled).toBe(true);
    fireEvent.click(rowButton('hewn table (wooden pegs)'));
    card = within(screen.getByLabelText('Selected recipe'));
    expect(card.getByText('Missing a tool, skill or second material')).toBeTruthy();
    expect(card.getByText(/Tools: Chisel and hammer\/mallet/)).toBeTruthy();
    fireEvent.click(card.getByText('Craft'));
    expect(props.act).not.toHaveBeenCalled();
  });
  it('keeps unlearned recipes folded until asked or searched for', () => {
    render(<CraftingWindow {...ui()} />);
    expect(screen.queryByText('shortbow')).toBeNull();
    fireEvent.click(screen.getByText('Show'));
    expect(screen.getByText('Needs the Archery manual')).toBeTruthy();
    fireEvent.click(screen.getByText('Hide'));
    fireEvent.change(screen.getByLabelText('Search recipes'), { target: { value: 'short' } });
    expect(screen.getByText('shortbow')).toBeTruthy();
    expect(screen.queryByText('campfire')).toBeNull();
  });
  it('offers a tab for each purpose this material has, with counts', () => {
    render(<CraftingWindow {...ui()} />);
    const tabs = within(screen.getByRole('tablist')).getAllByRole('tab').map(tab => tab.textContent);
    expect(tabs).toEqual(['All 5', 'Weapons 2', 'Building 2', 'Furniture 1']);
    fireEvent.click(screen.getByRole('tab', { name: /Furniture/ }));
    expect(screen.getByText('hewn table (wooden pegs)')).toBeTruthy();
    expect(screen.queryByText('travois')).toBeNull();
    expect(screen.getByRole('tab', { name: /Furniture/ }).getAttribute('aria-selected')).toBe('true');
  });
  it('keeps the old categories as sub-headings where a group mixes them', () => {
    const view = render(<CraftingWindow {...ui()} />);
    expect(Array.from(view.container.querySelectorAll('.craft-sub')).map(node => node.textContent)).toEqual(['General', 'weapons', 'General', 'joinery']);
    fireEvent.click(screen.getByRole('tab', { name: /Building/ }));
    expect(view.container.querySelectorAll('.craft-sub').length).toBe(0);
  });
  it('lists recent and pinned recipes as shortcuts that only select', () => {
    const data = rows(); data[0].recent = 2; data[1].recent = 1; data[3].pinned = 1;
    const props = ui({ rows: data }); render(<CraftingWindow {...props} />);
    const recent = within(screen.getByRole('group', { name: 'Recent' }));
    expect(recent.getAllByRole('button').map(button => button.textContent)).toEqual(['3x arrow shaft', 'campfire']);
    fireEvent.click(within(screen.getByRole('group', { name: 'Pinned' })).getByText('hewn table (wooden pegs)'));
    expect(props.act).not.toHaveBeenCalled();
    const card = within(screen.getByLabelText('Selected recipe'));
    fireEvent.click(card.getByText('Unpin'));
    expect(props.act).toHaveBeenLastCalledWith('pin', { pin: '3:1:dddddddd' });
  });
  it('has no shortcut strip or tabs when there is nothing to put in them', () => {
    const data = rows().slice(0, 1);
    render(<CraftingWindow {...ui({ rows: data })} />);
    expect(screen.queryByRole('tablist')).toBeNull();
    expect(screen.queryByRole('group', { name: 'Recent' })).toBeNull();
    fireEvent.click(rowButton('campfire'));
    expect(within(screen.getByLabelText('Selected recipe')).getByText('Pin this recipe')).toBeTruthy();
  });
  it('offers the other materials within reach and asks the server to switch', () => {
    const sources = [
      { key: '[0x1]', name: 'wood logs', amount: 6, where: 'in your hand', current: 1, image },
      { key: '[0x2]', name: 'stone', amount: 12, where: 'next to you', current: 0, image: '' },
    ];
    const props = ui({ reach: 1, sources, where: 'in your hand' }); render(<CraftingWindow {...props} />);
    const reach = within(screen.getByRole('group', { name: 'Materials within reach' }));
    fireEvent.click(reach.getByText('wood logs'));
    expect(props.act).not.toHaveBeenCalled();
    fireEvent.click(reach.getByText('stone'));
    expect(props.act).toHaveBeenLastCalledWith('source', { source: '[0x2]' });
  });
  it('says where the material is and hides the picker with one source or outside reach mode', () => {
    render(<CraftingWindow {...ui({ reach: 1, where: 'next to you', sources: [{ key: '[0x1]', name: 'wood logs', amount: 6, where: 'next to you', current: 1, image }] })} />);
    expect(screen.getByText('6 next to you')).toBeTruthy();
    expect(screen.queryByRole('group', { name: 'Materials within reach' })).toBeNull();
    cleanup();
    render(<CraftingWindow {...ui()} />);
    expect(screen.getByText('6 in your hand')).toBeTruthy();
  });
  it('searches across tabs and never crafts from the search box', () => {
    const props = ui(); render(<CraftingWindow {...props} />);
    fireEvent.click(screen.getByRole('tab', { name: /Weapons/ }));
    expect(screen.queryByText('campfire')).toBeNull();
    expect(screen.getByText('3x arrow shaft')).toBeTruthy();
    const search = screen.getByLabelText('Search recipes');
    fireEvent.change(search, { target: { value: 'camp' } });
    expect(screen.getByText('campfire')).toBeTruthy();
    fireEvent.keyDown(search, { key: 'Enter' });
    expect(props.act).not.toHaveBeenCalled();
  });
  it('remembers Only what I can make on the server and hides the rest', () => {
    const props = ui(); render(<CraftingWindow {...props} />);
    fireEvent.click(screen.getByLabelText('Only what I can make'));
    expect(props.act).toHaveBeenLastCalledWith('makeable_only', { makeable_only: 1 });
    expect(screen.queryByText('travois')).toBeNull();
    expect(screen.queryByText('Not learned yet')).toBeNull();
    expect(screen.getByText('campfire')).toBeTruthy();
  });
  it('steps and caps batches, showing how many items come out', () => {
    const props = ui(); render(<CraftingWindow {...props} />);
    fireEvent.click(rowButton('3x arrow shaft'));
    const card = within(screen.getByLabelText('Selected recipe'));
    const out = () => card.getByLabelText('Quantity').querySelector('output')?.textContent;
    expect(out()).toBe('3');
    fireEvent.click(card.getByLabelText('More'));
    expect(out()).toBe('6');
    fireEvent.click(card.getByText('Max'));
    expect(out()).toBe('18');
    expect((card.getByLabelText('More') as HTMLButtonElement).disabled).toBe(true);
    fireEvent.click(card.getByText('Craft'));
    expect(props.act).toHaveBeenLastCalledWith('make', { make: '2:1:bbbbbbbb', quantity: 6 });
  });
  it('blocks further crafts and shows progress while one is under way', () => {
    const props = ui({ working: { id: '0:1:aaaaaaaa', name: 'campfire', time: 140 } }); render(<CraftingWindow {...props} />);
    expect(screen.getByText('Making campfire...')).toBeTruthy();
    fireEvent.click(rowButton('campfire'));
    const card = within(screen.getByLabelText('Selected recipe'));
    expect((card.getByText('Working...') as HTMLButtonElement).disabled).toBe(true);
    expect(card.getByText('Moving away cancels the work.')).toBeTruthy();
    fireEvent.doubleClick(rowButton('3x arrow shaft'));
    expect(props.act).not.toHaveBeenCalled();
  });
  it('asks once per snapshot for pictures that did not fit', () => {
    const props = ui({ more_images: 1 }); const view = render(<CraftingWindow {...props} />);
    expect(props.act).toHaveBeenCalledTimes(1);
    expect(props.act).toHaveBeenLastCalledWith('images', { images: 1 });
    view.rerender(<CraftingWindow {...props} />);
    expect(props.act).toHaveBeenCalledTimes(1);
    cleanup();
    const idle = ui(); render(<CraftingWindow {...idle} />);
    expect(idle.act).not.toHaveBeenCalled();
  });
  it('sends nothing when the window is read-only', () => {
    const props = ui({}, false); render(<CraftingWindow {...props} />);
    fireEvent.doubleClick(rowButton('campfire'));
    fireEvent.click(rowButton('campfire'));
    expect((within(screen.getByLabelText('Selected recipe')).getByText('Craft') as HTMLButtonElement).disabled).toBe(true);
    expect(props.act).not.toHaveBeenCalled();
  });
  it('shows only server-named preview files and decodes names as text', () => {
    const data = rows(); data[0].image = 'http://example.invalid/x.png'; data[1].name = 'a &lt;b&gt; shaft';
    const view = render(<CraftingWindow {...ui({ rows: data, image: '../x.png' })} />);
    expect(view.container.querySelectorAll('img').length).toBe(0);
    expect(screen.getByText('a <b> shaft')).toBeTruthy();
  });
});
describe('helpers', () => {
  it('matches every word against name and category', () => {
    const r = { name: 'wood spear', category: 'weapons', purpose: 'Weapons', state: 'missing' };
    expect(matches(r, ['spear', 'weap'], '', false)).toBe(true);
    expect(matches(r, ['spear', 'bow'], '', false)).toBe(false);
    expect(matches(r, [], 'Tools', false)).toBe(false);
    expect(matches(r, [], 'Weapons', false)).toBe(true);
    expect(matches(r, [], '', true)).toBe(false);
  });
  it('words build times for players', () => {
    expect(seconds(0)).toBe('instant'); expect(seconds(4)).toBe('1 second'); expect(seconds(140)).toBe('14 seconds');
  });
});
