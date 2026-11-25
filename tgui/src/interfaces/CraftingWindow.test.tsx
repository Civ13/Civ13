import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, screen, within } from '@testing-library/react';
import { render } from '../testing';
import { CraftingWindow, matches, processMatches, seconds, startingAnswers } from './CraftingWindow';
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
  row('2:2:eeeeeeee', 'shortbow', 'locked', { category: 'weapons', purpose: 'Weapons', cost: '8 logs', why: 'Needs the Archery manual', tech_tree: 1 }),
];
const ui = (data: Data = {}, interactive = true): ScreenProps => ({
  template: 'crafting_window.tmpl', interactive, act: vi.fn(),
  data: { material: 'wood logs', unit: 'log', amount: 6, image, makeable_only: 0, categories: ['weapons', 'joinery'], purposes: ['Tools', 'Weapons', 'Building', 'Furniture', 'Other'], rows: rows(), working: null, more_images: 0, ...data },
});
// Selecting a row asks the server for its details; that request spends nothing.
const others = (props: ScreenProps) => (props.act as ReturnType<typeof vi.fn>).mock.calls.filter(call => call[0] !== 'detail');
const rowButton = (name: string) => screen.getByText(name).closest('button') as HTMLButtonElement;

describe('Crafting window', () => {
  it('selects on a click and spends nothing until Craft is pressed', () => {
    const props = ui(); render(<CraftingWindow {...props} />);
    expect(screen.getByText(/Pick a recipe/)).toBeTruthy();
    fireEvent.click(rowButton('campfire'));
    expect(others(props)).toEqual([]);
    const card = within(screen.getByLabelText('Selected recipe'));
    expect(card.getByText('A campfire made with wood logs.')).toBeTruthy();
    expect(card.getByText(/Structure · takes 14 seconds · makes 1/)).toBeTruthy();
    expect(card.getByText(/Only one per tile\. Needs a floor under you\./)).toBeTruthy();
    fireEvent.click(card.getByText('Craft'));
    expect(others(props).length).toBe(1);
    expect(props.act).toHaveBeenLastCalledWith('make', { value: '0:1:aaaaaaaa', quantity: 1 });
  });
  it('crafts one on a double click of a ready row only', () => {
    const props = ui(); render(<CraftingWindow {...props} />);
    fireEvent.doubleClick(rowButton('travois'));
    expect(others(props)).toEqual([]);
    fireEvent.doubleClick(rowButton('campfire'));
    expect(props.act).toHaveBeenLastCalledWith('make', { value: '0:1:aaaaaaaa', quantity: 1 });
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
    expect(others(props)).toEqual([]);
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
  it('opens the tech tree on the node an unlearned recipe needs', () => {
    const props = ui(); render(<CraftingWindow {...props} />);
    fireEvent.click(rowButton('campfire'));
    expect(within(screen.getByLabelText('Selected recipe')).queryByText('View in tech tree')).toBeNull();
    fireEvent.click(screen.getByText('Show'));
    fireEvent.click(rowButton('shortbow'));
    fireEvent.click(within(screen.getByLabelText('Selected recipe')).getByText('View in tech tree'));
    expect(props.act).toHaveBeenLastCalledWith('tech_tree', { value: '2:2:eeeeeeee' });
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
    expect(others(props)).toEqual([]);
    const card = within(screen.getByLabelText('Selected recipe'));
    fireEvent.click(card.getByText('Unpin'));
    expect(props.act).toHaveBeenLastCalledWith('pin', { value: '3:1:dddddddd' });
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
    expect(others(props)).toEqual([]);
    fireEvent.click(reach.getByText('stone'));
    expect(props.act).toHaveBeenLastCalledWith('source', { value: '[0x2]' });
  });
  it('says where the material is and hides the picker with one source or outside reach mode', () => {
    render(<CraftingWindow {...ui({ reach: 1, where: 'next to you', sources: [{ key: '[0x1]', name: 'wood logs', amount: 6, where: 'next to you', current: 1, image }] })} />);
    expect(screen.getByText('6 next to you')).toBeTruthy();
    expect(screen.queryByRole('group', { name: 'Materials within reach' })).toBeNull();
    cleanup();
    render(<CraftingWindow {...ui()} />);
    expect(screen.getByText('6 in your hand')).toBeTruthy();
  });
  it('selects the recipe the Atlas handed over, even an unlearned one behind another tab', () => {
    const props = ui(); const view = render(<CraftingWindow {...props} />);
    fireEvent.click(screen.getByRole('tab', { name: /Furniture/ }));
    view.rerender(<CraftingWindow {...ui({ focus: '2:2:eeeeeeee', focus_seq: 1 })} />);
    expect(within(screen.getByLabelText('Selected recipe')).getByText('Needs the Archery manual')).toBeTruthy();
    expect(screen.getByRole('tab', { name: /All/ }).getAttribute('aria-selected')).toBe('true');
    expect(view.container.querySelector('.craft-row-selected')?.textContent).toContain('shortbow');
    expect(others(props)).toEqual([]);
    // A later click is not undone by the same hand-off arriving again in a refresh.
    fireEvent.click(rowButton('travois'));
    view.rerender(<CraftingWindow {...ui({ focus: '2:2:eeeeeeee', focus_seq: 1, amount: 5 })} />);
    expect(view.container.querySelector('.craft-row-selected')?.textContent).toContain('travois');
  });
  it('asks for the selected recipe and lists each exact unmet requirement', () => {
    const props = ui(); const view = render(<CraftingWindow {...props} />);
    fireEvent.click(rowButton('hewn table (wooden pegs)'));
    expect(props.act).toHaveBeenLastCalledWith('detail', { value: '3:1:dddddddd' });
    const detail = { id: '3:1:dddddddd', needs: [{ label: 'You need a chisel in your other hand.', met: 0 }, { label: 'You must stand on a floor.', met: 0 }], fields: [] };
    view.rerender(<CraftingWindow {...ui({ detail })} />);
    const card = within(screen.getByLabelText('Selected recipe'));
    expect(card.getByText('You need a chisel in your other hand.')).toBeTruthy();
    expect(card.getByText('You must stand on a floor.')).toBeTruthy();
    expect(card.queryByText('Missing a tool, skill or second material')).toBeNull();
    // Details for another row are never shown on this one.
    view.rerender(<CraftingWindow {...ui({ detail: { ...detail, id: '0:1:aaaaaaaa' } })} />);
    expect(within(screen.getByLabelText('Selected recipe')).getByText('Missing a tool, skill or second material')).toBeTruthy();
  });
  it('loads a recipe selected during a craft when it finishes, without repeating for equivalent snapshots', () => {
    const working = { id: '0:1:aaaaaaaa', name: 'campfire', time: 140 };
    const props = ui({ working });
    const view = render(<CraftingWindow {...props} />);
    fireEvent.click(rowButton('hewn table (wooden pegs)'));
    expect(props.act).not.toHaveBeenCalled();
    view.rerender(<CraftingWindow {...ui({ amount: 2 })} act={props.act} />);
    expect(props.act).toHaveBeenCalledExactlyOnceWith('detail', { value: '3:1:dddddddd' });
    view.rerender(<CraftingWindow {...ui({ amount: 3 })} act={props.act} />);
    expect(props.act).toHaveBeenCalledTimes(1);
    view.rerender(<CraftingWindow {...ui({ detail: {
      id: '3:1:dddddddd', needs: [{ label: 'You need a chisel in your other hand.', met: 0 }], fields: [],
    } })} act={props.act} />);
    expect(within(screen.getByLabelText('Selected recipe')).getByText('You need a chisel in your other hand.')).toBeTruthy();
    expect(props.act).toHaveBeenCalledTimes(1);
  });
  it('loads missing selected details when a read-only window becomes interactive', () => {
    const props = ui({}, false);
    const view = render(<CraftingWindow {...props} />);
    fireEvent.click(rowButton('campfire'));
    expect(props.act).not.toHaveBeenCalled();
    view.rerender(<CraftingWindow {...ui()} act={props.act} />);
    expect(props.act).toHaveBeenCalledExactlyOnceWith('detail', { value: '0:1:aaaaaaaa' });
  });
  it('shows a recipe choices as fields and sends the answers with the craft', () => {
    const fields = [
      { field: 'name', kind: 'text', question: 'Choose a name for this sign:', default: '', required: 0, max_length: 40 },
      { field: 'color', kind: 'color', question: 'Choose a color:', default: '#FFFFFF', required: 1, max_length: 256 },
      { field: 'company', kind: 'company', question: 'Which company will own this sign?', default: '', required: 0, max_length: 256, choices: ['Acme &amp; Sons', 'Rivermill'] },
    ];
    const detail = { id: '0:1:aaaaaaaa', needs: [], fields };
    const props = ui({ detail }); render(<CraftingWindow {...props} />);
    fireEvent.click(rowButton('campfire'));
    const choices = within(screen.getByRole('group', { name: 'Choices' }));
    const name = choices.getByLabelText('Choose a name for this sign') as HTMLInputElement;
    expect(name.maxLength).toBe(40);
    fireEvent.change(name, { target: { value: 'The Old Oak' } });
    fireEvent.change(choices.getByLabelText(/Which company/), { target: { value: 'Rivermill' } });
    fireEvent.click(within(screen.getByLabelText('Selected recipe')).getByText('Craft'));
    expect(props.act).toHaveBeenLastCalledWith('make', { value: '0:1:aaaaaaaa', quantity: 1, options: JSON.stringify({ name: 'The Old Oak', color: '#ffffff', company: 'Rivermill' }) });
  });
  it('keeps Craft off until a needed choice is answered or when no company can own it', () => {
    const text = { field: 'label', kind: 'text', question: 'Name it:', default: '', required: 1, max_length: 20 };
    const props = ui({ detail: { id: '0:1:aaaaaaaa', needs: [], fields: [text] } }); const view = render(<CraftingWindow {...props} />);
    fireEvent.click(rowButton('campfire'));
    const craft = () => within(screen.getByLabelText('Selected recipe')).getByText('Craft') as HTMLButtonElement;
    expect(craft().disabled).toBe(true);
    fireEvent.change(screen.getByLabelText('Name it (needed)'), { target: { value: 'Hearth' } });
    expect(craft().disabled).toBe(false);
    view.rerender(<CraftingWindow {...ui({ detail: { id: '0:1:aaaaaaaa', needs: [], fields: [{ field: 'company', kind: 'company', question: 'Owner:', default: '', choices: [] }] } })} />);
    expect(screen.getByText('You are not part of any company.')).toBeTruthy();
    expect(craft().disabled).toBe(true);
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
    expect(others(props)).toEqual([]);
  });
  it('remembers Only what I can make on the server and hides the rest', () => {
    const props = ui(); render(<CraftingWindow {...props} />);
    fireEvent.click(screen.getByLabelText('Only what I can make'));
    expect(props.act).toHaveBeenLastCalledWith('makeable_only', { value: 1 });
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
    expect(props.act).toHaveBeenLastCalledWith('make', { value: '2:1:bbbbbbbb', quantity: 6 });
  });
  it('names the station when a workstation opened the window', () => {
    const props = ui({ station: 'iron anvil', material: 'iron', rows: [row('a1b2c3d4e5f60718', 'Conical Helmet', 'ready', { category: 'Helmets', purpose: 'Armor', cost: '5 iron', time: 50 })] });
    render(<CraftingWindow {...props} />);
    expect(screen.getByText('At the iron anvil')).toBeTruthy();
    fireEvent.click(rowButton('Conical Helmet'));
    fireEvent.click(within(screen.getByLabelText('Selected recipe')).getByText('Craft'));
    expect(props.act).toHaveBeenLastCalledWith('make', { value: 'a1b2c3d4e5f60718', quantity: 1 });
    cleanup();
    render(<CraftingWindow {...ui()} />);
    expect(screen.queryByText(/^At the/)).toBeNull();
  });

  it('blocks further crafts and shows progress while one is under way', () => {
    const props = ui({ working: { id: '0:1:aaaaaaaa', name: 'campfire', time: 140 } }); render(<CraftingWindow {...props} />);
    expect(screen.getByText('Making campfire...')).toBeTruthy();
    fireEvent.click(rowButton('campfire'));
    const card = within(screen.getByLabelText('Selected recipe'));
    expect((card.getByText('Working...') as HTMLButtonElement).disabled).toBe(true);
    expect(card.getByText('Moving away cancels the work.')).toBeTruthy();
    fireEvent.doubleClick(rowButton('3x arrow shaft'));
    expect(others(props)).toEqual([]);
  });
  it('asks once per snapshot for pictures that did not fit', () => {
    const props = ui({ more_images: 1 }); const view = render(<CraftingWindow {...props} />);
    expect(props.act).toHaveBeenCalledTimes(1);
    expect(props.act).toHaveBeenLastCalledWith('images');
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
    expect(others(props)).toEqual([]);
  });
  it('shows only server-named preview files and decodes names as text', () => {
    const data = rows(); data[0].image = 'http://example.invalid/x.png'; data[1].name = 'a &lt;b&gt; shaft';
    const view = render(<CraftingWindow {...ui({ rows: data, image: '../x.png' })} />);
    expect(view.container.querySelectorAll('img').length).toBe(0);
    expect(screen.getByText('a <b> shaft')).toBeTruthy();
  });
});
describe('Tool and station work', () => {
  const scrape = (have: number): Data => ({ id: 'p1', name: 'Scrape raw hide into a prepared hide', state: have ? 'ready' : 'missing', makes: ['prepared hairless hide'],
    tools: [{ name: 'sharp tool', have, found: have ? 'flint knife' : '' }], steps: ['Apply a held sharp tool to a nearby raw hide.', 'One piece becomes one prepared hide.'], atlas: 1, image: '' });
  const hide = (have: number, extra: Data = {}) => ui({ material: 'raw hide piece', rows: [], processing: [scrape(have)], processing_total: 1, ...extra });
  it('lists what a tool turns a material with no recipes into', () => {
    const props = hide(1); render(<CraftingWindow {...props} />);
    expect(screen.queryByText(/No matching recipes/)).toBeNull();
    expect(screen.queryByText('Ready')).toBeNull();
    fireEvent.click(rowButton('Scrape raw hide into a prepared hide'));
    const card = within(screen.getByLabelText('Selected process'));
    expect(card.getByText(/Makes prepared hairless hide/)).toBeTruthy();
    expect(card.getByText('Met:', { exact: false }).parentElement?.textContent).toContain('sharp tool - flint knife');
    expect(card.queryByText('Craft')).toBeNull();
    expect(props.act).not.toHaveBeenCalled();
    fireEvent.click(card.getByText('Open in Atlas'));
    expect(props.act).toHaveBeenLastCalledWith('process_atlas', { value: 'p1' });
  });
  it('says when the tool is missing and hides it under Only what I can make', () => {
    render(<CraftingWindow {...hide(0)} />);
    expect(screen.getByText('needs sharp tool')).toBeTruthy();
    fireEvent.click(rowButton('Scrape raw hide into a prepared hide'));
    expect(within(screen.getByLabelText('Selected process')).getByText('Missing:', { exact: false })).toBeTruthy();
    cleanup();
    render(<CraftingWindow {...hide(0, { makeable_only: 1 })} />);
    expect(screen.queryByText('Scrape raw hide into a prepared hide')).toBeNull();
  });
  it('sits under the recipes and says how many more the Atlas has', () => {
    render(<CraftingWindow {...ui({ processing: [scrape(1)], processing_total: 31 })} />);
    expect(screen.getByText('Ready')).toBeTruthy();
    expect(screen.getByText('30 more in the Atlas.')).toBeTruthy();
  });
  it('matches search words against name, products and tools', () => {
    expect(processMatches(scrape(1), ['scrape', 'sharp'], false)).toBe(true);
    expect(processMatches(scrape(1), ['hairless'], false)).toBe(true);
    expect(processMatches(scrape(1), ['saw'], false)).toBe(false);
    expect(processMatches(scrape(0), [], true)).toBe(false);
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
  it('starts choices from the game defaults', () => {
    expect(startingAnswers([{ field: 'a', kind: 'color', default: '#AbCdEf' }, { field: 'b', kind: 'color', default: 'red' },
      { field: 'c', kind: 'company', choices: ['One', 'Two'] }, { field: 'd', kind: 'text', default: 'Sign' }])).toEqual({ a: '#abcdef', b: '#000000', c: 'One', d: 'Sign' });
  });
  it('words build times for players', () => {
    expect(seconds(0)).toBe('instant'); expect(seconds(4)).toBe('1 second'); expect(seconds(140)).toBe('14 seconds');
  });
});
