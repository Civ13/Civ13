import React from 'react';
import { afterEach, beforeEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react';
vi.mock('tgui-core/components', () => ({
  NoticeBox: ({ children }: any) => <aside>{children}</aside>,
}));
import { CraftingAtlas, notes, resetAtlasRequests } from './CraftingAtlas';
import type { Data, ScreenProps } from '../types';
beforeEach(() => { vi.useFakeTimers(); resetAtlasRequests(); });
afterEach(() => { cleanup(); resetAtlasRequests(); vi.useRealTimers(); });
// The reader may send one request a second; step past the gap between clicks.
const settle = () => vi.advanceTimersByTime(1200);
const recipe = {
  id: 'r2', name: 'Fictional planks', kind: 'Material / camp', file: 'config/crafting/material_recipes_camp.txt', line: 27,
  conditions: 'Map &amp; faction gates', era_label: '3: Imperial Age / 4: Industrial Age', era_basis: 'Research node',
  inputs: [{ id: '/material/wood', name: 'Log', quantity: '1', image: 'atlas_' + 'a'.repeat(32) + '.png', preview: 'Inherited default; overlays can differ.' }],
  outputs: [{ id: '/obj/plank', name: 'Planks', quantity: '4 nominal', image: '' }],
  variants: [{ id: 'r1', kind: 'Material / global', line: 12 }, { id: 'r2', kind: 'Material / camp', line: 27 }],
};
const ui = (data: Data = {}, interactive = true): ScreenProps => ({
  template: 'crafting_atlas.tmpl', data: { mode: 'graph', query: 'wood', era: 'multiple', processor: 'sawmill', recipe_count: 1, resource_count: 1, recipes: [{ id: 'r2', name: 'Same name', era_label: '3: Imperial Age' }], resources: [{ id: 'wood_id', name: 'Same name' }], detail: recipe, ...data },
  interactive, act: vi.fn(),
});
const sent = (props: ScreenProps) => {
  const call = vi.mocked(props.act).mock.calls.at(-1);
  expect(call?.[0]).toBe('atlas_navigate');
  expect(Object.keys(call?.[1] ?? {})).toEqual(['atlas_navigate']);
  return JSON.parse(String(call?.[1]?.atlas_navigate));
};
describe('Crafting Atlas navigation', () => {
  it('keeps typed search local until submit and applies era and station choices at once', () => {
    const props = ui(); render(<CraftingAtlas {...props} />);
    fireEvent.change(screen.getByRole('searchbox'), { target: { value: 'new query' } });
    expect(props.act).not.toHaveBeenCalled();
    fireEvent.click(screen.getByRole('button', { name: 'Search' }));
    expect(sent(props)).toEqual({ route: 'open', query: 'new query', era: 'multiple', processor: 'sawmill' });
    settle();
    fireEvent.change(screen.getByLabelText('Unlock era'), { target: { value: 'unknown' } });
    expect(sent(props)).toEqual({ route: 'open', query: 'new query', era: 'unknown', processor: 'sawmill' });
    settle();
    fireEvent.change(screen.getByLabelText('Processor'), { target: { value: 'tanning_rack' } });
    expect(sent(props)).toEqual({ route: 'open', query: 'new query', era: 'unknown', processor: 'tanning_rack' });
    expect((screen.getByRole('searchbox') as HTMLInputElement).maxLength).toBe(64);
  });
  it('sends only the latest click made inside the one-second server window', () => {
    const props = ui({ recipes: [{ id: 'r2', name: 'First' }, { id: 'r5', name: 'Second' }, { id: 'r7', name: 'Third' }] });
    render(<CraftingAtlas {...props} />);
    fireEvent.click(screen.getByText('First'));
    fireEvent.click(screen.getByText('Second'));
    fireEvent.click(screen.getByText('Third'));
    expect(props.act).toHaveBeenCalledTimes(1);
    expect(sent(props).recipe).toBe('r2');
    settle();
    expect(props.act).toHaveBeenCalledTimes(2);
    expect(sent(props).recipe).toBe('r7');
  });
  it('separates resource identity from recipe identity and resets filters for resource navigation', () => {
    const props = ui(); const view = render(<CraftingAtlas {...props} />);
    const resource = view.container.querySelector('[data-result-type="resource"]')!;
    const recipeResult = view.container.querySelector('[data-result-type="recipe"]')!;
    fireEvent.click(within(resource as HTMLElement).getByText('Same name'));
    expect(sent(props)).toEqual({ route: 'resource', resource: 'wood_id' });
    settle();
    fireEvent.click(within(recipeResult as HTMLElement).getByText('Same name'));
    expect(sent(props)).toEqual({ route: 'open', query: 'wood', era: 'multiple', processor: 'sawmill', recipe: 'r2' });
    settle();
    fireEvent.click(screen.getByText('Log'));
    expect(sent(props)).toEqual({ route: 'resource', resource: '/material/wood' });
  });
  it('retains selected variant source, quantities and applied filters', () => {
    const props = ui(); render(<CraftingAtlas {...props} />);
    expect(screen.getByText('(4 nominal)')).toBeTruthy();
    expect(screen.getAllByText('Map & faction gates').length).toBeGreaterThan(0);
    expect(screen.getByText('Imperial Age / Industrial Age')).toBeTruthy();
    expect(screen.getByRole('link', { name: /Catalog source/ }).getAttribute('href')).toBe('https://github.com/Civ13/Civ13/blob/master/config/crafting/material_recipes_camp.txt#L27');
    fireEvent.change(screen.getByLabelText('Transformation / catalog variant'), { target: { value: 'r1' } });
    expect(sent(props)).toEqual({ route: 'open', query: 'wood', era: 'multiple', processor: 'sawmill', recipe: 'r1' });
  });
  it('preserves explicit page navigation, selection context and deliberate reset routes', () => {
    const props = ui({ mode: 'page', page: 2, previous: true, next: true, entries: [recipe] });
    render(<CraftingAtlas {...props} />);
    expect(screen.queryByLabelText('Unlock era')).toBeNull();
    fireEvent.click(screen.getByText('Previous')); expect(sent(props)).toEqual({ route: 'page', page: 1, query: 'wood' }); settle();
    fireEvent.click(screen.getByText('Next')); expect(sent(props)).toEqual({ route: 'page', page: 3, query: 'wood' }); settle();
    fireEvent.change(screen.getByLabelText('Transformation / catalog variant'), { target: { value: 'r1' } });
    expect(sent(props)).toEqual({ route: 'page', page: 2, query: 'wood', recipe: 'r1' }); settle();
    fireEvent.click(screen.getByText('All recipes')); expect(sent(props)).toEqual({ route: 'page', page: 1 }); settle();
    fireEvent.click(screen.getByText('Return to dependency atlas')); expect(sent(props)).toEqual({ route: 'reset' }); settle();
    fireEvent.click(screen.getByRole('button', { name: 'Search' })); expect(sent(props)).toEqual({ route: 'open', query: 'wood' });
  });
  it('keeps acquisition conditions, reviewed provenance and related-resource navigation', () => {
    const props = ui({ detail: null, guidance: { id: 'sand', name: 'Sand', heading: 'Gathering from', more: true, routes: [{ name: 'Shovel', steps: ['Dig the tile', 'Collect the stack'], details: [{ label: 'steps', value: 'Dig the tile; Collect the stack' }, { label: 'conditions', value: 'Non-harm intent' }, { label: 'status', value: 'source reviewed' }], related: [{ id: 'clay', name: 'Clay', heading: 'Can provide (conditional)' }], file: 'code/example.dm', line: 8, revision: 'b'.repeat(40) }] } });
    const view = render(<CraftingAtlas {...props} />);
    expect(screen.getByText('Gathering from Sand')).toBeTruthy();
    expect(view.container.querySelectorAll('ol li')).toHaveLength(2);
    expect(screen.getByText('Non-harm intent')).toBeTruthy();
    expect(screen.getByText(/Review status: source reviewed/)).toBeTruthy();
    expect(screen.getByText(/Can provide \(conditional\)/)).toBeTruthy();
    expect(screen.getByText('More routes are available in the full web atlas.')).toBeTruthy();
    expect(screen.getAllByRole('link', { name: /Catalog source/ }).some(link => link.getAttribute('href')?.includes('/' + 'b'.repeat(40) + '/'))).toBe(true);
    fireEvent.click(screen.getByText('Clay')); expect(sent(props)).toEqual({ route: 'resource', resource: 'clay' });
  });
  it('lists exactly what makes and uses a resource and keeps a picked recipe on that page', () => {
    const props = ui({ query: '', detail: null, guidance: { id: '/material/leather', name: 'leather', heading: 'How to obtain', routes: [], made_by_count: 1, used_in_count: 91,
      made_by: [{ id: 'r40', name: 'Tan a dry hide', era_label: '1: Bronze Age', needs: '1 x dry hide' }],
      used_in: [{ id: 'r41', name: 'leather bandages', era_label: '0: Stone Age', needs: '1 x leather', research: 'needed' }] } });
    render(<CraftingAtlas {...props} />);
    expect(screen.getByText('1 recipe makes this, 91 use it.')).toBeTruthy();
    expect(screen.getByText('Made by (1)')).toBeTruthy();
    expect(screen.getByText('Used in (91)')).toBeTruthy();
    expect(screen.getByText('First 1 shown.')).toBeTruthy();
    expect(screen.getByText('Needs research')).toBeTruthy();
    expect((screen.getByRole('searchbox') as HTMLInputElement).value).toBe('');
    fireEvent.click(screen.getByText('leather bandages'));
    expect(sent(props)).toEqual({ route: 'resource', resource: '/material/leather', recipe: 'r41' });
  });
  it('hides other maps by default and asks the server for them only on request', () => {
    const props = ui({ hidden_count: 12, scope: '' }); const view = render(<CraftingAtlas {...props} />);
    const box = screen.getByLabelText('Include other maps') as HTMLInputElement;
    expect(box.checked).toBe(false);
    expect(screen.getByText(/12 hidden/)).toBeTruthy();
    fireEvent.click(box);
    expect(sent(props)).toEqual({ route: 'open', query: 'wood', era: 'multiple', processor: 'sawmill', scope: 'all' });
    view.rerender(<CraftingAtlas {...ui({ hidden_count: 0, scope: 'all', detail: { ...recipe, elsewhere: true } })} />);
    expect((screen.getByLabelText('Include other maps') as HTMLInputElement).checked).toBe(true);
    expect(screen.getByText('Other maps only: camp')).toBeTruthy();
    view.rerender(<CraftingAtlas {...ui({ hidden_count: 0, scope: '' })} />);
    expect(screen.queryByLabelText('Include other maps')).toBeNull();
    view.rerender(<CraftingAtlas {...ui({ hidden_count: 3, scope: '', recipes: [], resources: [], detail: null, recipe_count: 0, resource_count: 0 })} />);
    expect(screen.getByText(/No matching recipes on this map/)).toBeTruthy();
  });
  it('shows research names and the reader\'s own progress without inferring it', () => {
    const view = render(<CraftingAtlas {...ui({ map_era: 3, detail: { ...recipe, kind: 'Material / global', maximum_era: 4, retired: false,
      conditions: 'Legacy research I/M/M: 0/0/0; maximum era ordinal 4; time 200 deciseconds; category none; one per turf 1; floor 1; supplied material null. Research-node and map gates also apply. Tools equipped or at your feet: chisel. Explicit research node: furriery.',
      research: [{ id: 'furriery', name: 'Furriery', state: 'needed' }, { id: 'weaving', name: 'Weaving', state: 'done' }, { id: 'x', name: 'Unknown reader', state: '' }] } })} />);
    const requirements = view.container.querySelector('.atlas-requirements')!.textContent!;
    expect(requirements).toContain('Research: FurrieryNot researched yet');
    expect(requirements).toContain('Research: WeavingResearched');
    expect(requirements).toMatch(/Research: Unknown reader(?!Researched|Not)/);
    expect(requirements).toContain('Takes about 20 s');
    expect(requirements).toContain('One per tile');
    expect(requirements).toContain('Can be made until the end of the Industrial Age');
    expect(requirements).toContain('Tools equipped or at your feet: chisel.');
    expect(requirements).not.toContain('Legacy research');
    expect(requirements).toContain('Hold the material and use it in your hand');
    expect(screen.getByRole('option', { name: '3: Imperial Age (current)' })).toBeTruthy();
    // The unedited catalog text stays available.
    expect(view.container.querySelector('.atlas-technical')!.textContent).toContain('Legacy research I/M/M');
  });
  it('presents an item page as a small wiki entry with facts, its recipe, its workstation role and a wiki link', () => {
    const props = ui({ query: '', detail: { ...recipe, station: 'iron anvil', station_id: '/obj/structure/anvil' }, guidance: { id: '/obj/structure/anvil', name: 'iron anvil', heading: 'How to obtain', routes: [],
      kind: 'Structure', desc: 'A heavy iron anvil &amp; work tool.', stats: [{ label: 'Size', value: 'Large' }, { label: 'Armor', value: 'melee 5' }],
      made_by_count: 2, used_in_count: 1, made_here_count: 244, made_by: [], used_in: [], made_here: [{ id: 'r9', name: 'Sword blade', era_label: '1: Bronze Age', needs: '2 x iron' }] } });
    render(<CraftingAtlas {...props} />);
    const page = screen.getByRole('article', { name: 'Resource' });
    expect(within(page).getByRole('heading', { level: 2 }).textContent).toBe('iron anvil');
    expect(page.textContent).toContain('A heavy iron anvil & work tool.');
    expect(within(page).getByText('Structure')).toBeTruthy();
    expect(within(page).getByText('Workstation')).toBeTruthy();
    expect(within(page).getByText('Large').previousElementSibling?.textContent).toBe('Size');
    expect(page.textContent).toContain('The first of its 2 recipes is shown below');
    expect(within(page).getByRole('link', { name: 'Search the wiki for iron anvil' }).getAttribute('href')).toBe('https://civ13.github.io/civ13-wiki/?search=iron%20anvil');
    // The item comes first, then how to make it.
    const cards = screen.getAllByRole('article');
    expect(cards.map(card => card.getAttribute('aria-label'))).toEqual(['Resource', 'Recipe']);
    expect(screen.getByRole('heading', { name: 'Made here (244)' })).toBeTruthy();
    fireEvent.click(within(cards[1]).getByRole('button', { name: 'Made at: iron anvil' }));
    expect(sent(props)).toEqual({ route: 'resource', resource: '/obj/structure/anvil' });
  });
  it('says plainly when nothing makes an item', () => {
    render(<CraftingAtlas {...ui({ query: '', detail: null, guidance: { id: '/material/iron', name: 'iron', heading: 'How to obtain', routes: [], kind: 'Material', made_by_count: 0, used_in_count: 3, made_by: [], used_in: [] } })} />);
    const page = screen.getByRole('article', { name: 'Resource' });
    expect(page.textContent).toContain('No recipe makes this and no gathering route is recorded.');
    expect(within(page).queryByText('Craftable')).toBeNull();
    expect(within(page).getByText('Used in 3 recipes')).toBeTruthy();
  });
  it('clears stale detail, guidance, symbols and draft state on a new empty response', () => {
    const props = ui({ guidance: { name: 'Old', heading: 'How to obtain', routes: [] } });
    const view = render(<CraftingAtlas {...props} />);
    fireEvent.change(screen.getByRole('searchbox'), { target: { value: 'unsent' } });
    view.rerender(<CraftingAtlas {...ui({ query: '', recipes: [], resources: [], detail: null, guidance: null, recipe_count: 0, resource_count: 0 })} />);
    expect(screen.queryByText('Fictional planks')).toBeNull();
    expect(screen.queryByText('How to obtain Old')).toBeNull();
    expect(view.container.querySelector('img')).toBeNull();
    expect((screen.getByRole('searchbox') as HTMLInputElement).value).toBe('');
    expect(screen.getByText(/No matching recipes or resources/)).toBeTruthy();
  });
  it('preserves resource-only and independent result-bound notices', () => {
    render(<CraftingAtlas {...ui({ recipe_count: 151, resource_count: 151, detail: null })} />);
    expect(screen.getByText('First 150 resource matches shown. Refine your search to find more.')).toBeTruthy();
    expect(screen.getByText('First 150 recipe families shown. Refine filters to find more.')).toBeTruthy();
    expect(screen.getByText(/Select a Resource result/)).toBeTruthy();
  });
  it('folds a long resource list until asked without another request', () => {
    const props = ui({ resource_count: 6, resources: Array.from({ length: 6 }, (_, i) => ({ id: 'res' + i, name: 'Resource ' + i })) });
    const view = render(<CraftingAtlas {...props} />);
    expect(view.container.querySelectorAll('[data-result-type="resource"]')).toHaveLength(4);
    fireEvent.click(screen.getByText('Show all 6 resources'));
    expect(view.container.querySelectorAll('[data-result-type="resource"]')).toHaveLength(6);
    expect(props.act).not.toHaveBeenCalled();
  });
  it('keeps rich-looking text inert and rejects nonlocal symbol URLs and unsafe source paths', () => {
    const view = render(<CraftingAtlas {...ui({ recipes: [], resources: [], detail: { ...recipe, name: '&lt;script&gt;inert&lt;/script&gt;', file: '../../settings', inputs: [{ id: 'x', name: '&lt;img src=x&gt;', quantity: '<b>1</b>', image: 'https://example.com/x.png' }] } })} />);
    expect(screen.getByText('<script>inert</script>')).toBeTruthy();
    expect(screen.getByText('<img src=x>')).toBeTruthy();
    expect(view.container.querySelector('script,img')).toBeNull();
    expect(screen.queryByRole('link', { name: /Catalog source/ })).toBeNull();
  });
  it('blocks every navigation and form action when the owner state is not interactive', () => {
    const props = ui({ hidden_count: 2 }, false); render(<CraftingAtlas {...props} />);
    for (const button of screen.getAllByRole('button')) fireEvent.click(button);
    fireEvent.submit(screen.getByRole('search'));
    settle();
    expect(props.act).not.toHaveBeenCalled();
    expect((screen.getByRole('searchbox') as HTMLInputElement).disabled).toBe(true);
    expect((screen.getByLabelText('Unlock era') as HTMLSelectElement).disabled).toBe(true);
    expect((screen.getByLabelText('Include other maps') as HTMLInputElement).disabled).toBe(true);
  });

  it('shows one family on the left and canonical recipe choices on the right', () => {
    const family = [{ id: 'r2', label: '1 x log makes 4 x planks' },
                    { id: 'r9', label: '2 x log makes 2 x planks', research: 'needed' }];
    const props = ui({ family_count: 1, recipe_count: 2,
      recipes: [{ id: 'r2', family_id: 'family_explicit', name: 'Plank family', variant_count: 2, era_label: 'Multiple unlock eras' }],
      detail: { ...recipe, family_variants: family } });
    const view = render(<CraftingAtlas {...props} />);
    expect(view.container.querySelectorAll('[data-result-type="recipe"]')).toHaveLength(1);
    expect(view.container.querySelectorAll('.atlas-selected')).toHaveLength(1);
    expect(screen.getByText(/1 recipe \(2 with variants\), 1 resource\./)).toBeTruthy();
    expect(screen.getByText('Multiple unlock eras - 2 recipe variants')).toBeTruthy();
    const select = screen.getByLabelText('Recipe variant') as HTMLSelectElement;
    expect(select.value).toBe('r2');
    expect(within(select).getAllByRole('option')).toHaveLength(2);
    expect(screen.getByRole('option', { name: '2 x log makes 2 x planks - needs research' })).toBeTruthy();
    fireEvent.change(select, { target: { value: 'r9' } });
    expect(sent(props)).toEqual({ route: 'open', query: 'wood', era: 'multiple', processor: 'sawmill', recipe: 'r9' });
    // Existing per-catalog equivalents remain independently selectable.
    expect(screen.getByLabelText('Transformation / catalog variant')).toBeTruthy();
  });
  it('updates costs, outputs, requirements, sources and exact selected IDs with the server response', () => {
    const family = [{ id: 'r2', label: 'Brown coat' }, { id: 'r9', label: 'Black coat - higher cost' }];
    const view = render(<CraftingAtlas {...ui({ family_count: 1, detail: { ...recipe, family_variants: family } })} />);
    const next = { ...recipe, id: 'r9', kind: 'Material / global', file: 'config/crafting/material_recipes_global.txt', line: 81,
      conditions: 'Requires locked research and 9 hides', era_label: 'Stone Age', era_basis: 'Explicit node',
      inputs: [{ id: 'hide', name: 'Hide', quantity: '9', image: '' }],
      outputs: [{ id: 'coat/black', name: 'Black coat', quantity: '2', image: '' }],
      variants: [], family_variants: family };
    view.rerender(<CraftingAtlas {...ui({ family_count: 1, detail: next })} />);
    expect((screen.getByLabelText('Recipe variant') as HTMLSelectElement).value).toBe('r9');
    expect(screen.getByText('(9)')).toBeTruthy();
    expect(screen.getByText('(2)')).toBeTruthy();
    expect(screen.getAllByText('Requires locked research and 9 hides').length).toBeGreaterThan(0);
    expect(screen.queryByText('(4 nominal)')).toBeNull();
    expect(screen.queryByText('Map & faction gates')).toBeNull();
    expect(screen.queryByLabelText('Transformation / catalog variant')).toBeNull();
    expect(screen.getByRole('link', { name: /Catalog source/ }).getAttribute('href')).toContain('material_recipes_global.txt#L81');
  });
  it('does not regroup identical names, hide returned locked variants or infer availability', () => {
    const props = ui({ family_count: 2, recipe_count: 3,
      recipes: [{ id: 'r2', family_id: 'family_one', name: 'Shared label', variant_count: 2, era_label: 'Unknown' },
                { id: 'r8', family_id: 'family_two', name: 'Shared label', variant_count: 1, era_label: 'Stone Age' }],
      detail: { ...recipe, family_variants: [{ id: 'r2', label: 'Known requirements' }, { id: 'r8', label: 'Unknown research', elsewhere: true }] } });
    const view = render(<CraftingAtlas {...props} />);
    expect(view.container.querySelectorAll('[data-result-type="recipe"]')).toHaveLength(2);
    expect(view.container.querySelector('.atlas-chip.atlas-ok')).toBeNull();
    expect(screen.getByRole('option', { name: 'Unknown research - other maps' })).toBeTruthy();
    fireEvent.change(screen.getByLabelText('Recipe variant'), { target: { value: 'r8' } });
    expect(sent(props).recipe).toBe('r8');
  });
  it('clears excluded family options and uses the independent family result bound', () => {
    const props = ui({ family_count: 2, recipe_count: 500, detail: { ...recipe,
      family_variants: [{ id: 'r2', label: 'First' }, { id: 'r9', label: 'Filtered out later' }] } });
    const view = render(<CraftingAtlas {...props} />);
    expect(screen.queryByText('First 150 recipe families shown. Refine filters to find more.')).toBeNull();
    view.rerender(<CraftingAtlas {...ui({ family_count: 1, recipe_count: 1, detail: { ...recipe, family_variants: [] } })} />);
    expect(screen.queryByLabelText('Recipe variant')).toBeNull();
    expect(screen.queryByRole('option', { name: 'Filtered out later' })).toBeNull();
    view.rerender(<CraftingAtlas {...ui({ family_count: 151, recipe_count: 700 })} />);
    expect(screen.getByText('First 150 recipe families shown. Refine filters to find more.')).toBeTruthy();
  });
  it('keeps family labels inert and blocks variant changes when interaction is disabled', () => {
    const props = ui({ recipes: [], resources: [], family_count: 1, detail: { ...recipe,
      family_variants: [{ id: 'r2', label: '&lt;img src=x onerror=bad&gt;' }, { id: 'r9', label: 'Other variant' }] } }, false);
    const view = render(<CraftingAtlas {...props} />);
    const select = screen.getByLabelText('Recipe variant') as HTMLSelectElement;
    expect(select.disabled).toBe(true);
    expect(screen.getByRole('option', { name: '<img src=x onerror=bad>' })).toBeTruthy();
    expect(view.container.querySelectorAll('img')).toHaveLength(1); // Existing validated local resource symbol only.
    fireEvent.change(select, { target: { value: 'r9' } });
    settle();
    expect(props.act).not.toHaveBeenCalled();
  });
});

describe('Crafting Atlas requirement notes', () => {
  it('lifts time and placement out of generated bookkeeping and keeps real notes', () => {
    expect(notes('Legacy research I/M/M: 0/0/0; maximum era ordinal 8; time 80 deciseconds; category none; one per turf 0; floor 1; supplied material null. Research-node and map gates also apply. Explicit research node: weaving.'))
      .toEqual({ facts: ['Takes about 8 s'], rest: '' });
    expect(notes('Catalysts: []; inhibitors: []; additional can_happen/process callbacks may apply.')).toEqual({ facts: [], rest: '' });
    expect(notes('Boiling water and pot/stove conditions apply. Explicit research node: pottery_storage.').rest).toBe('Boiling water and pot/stove conditions apply.');
    expect(notes('Catalysts: [(&#39;water&#39;, &#39;1&#39;)]; inhibitors: []; additional can_happen/process callbacks may apply.').rest).toContain("Catalysts: [('water', '1')]");
    expect(notes(undefined)).toEqual({ facts: [], rest: '' });
  });
});

describe('Crafting Atlas personal manuals', () => {
  it('keeps locked recipes inspectable and refreshes on learning, reopening and reader changes', () => {
    const locked = { ...recipe, manual_hint: 'Needs the Woodworking manual' };
    const props = ui({ detail: locked });
    const view = render(<CraftingAtlas {...props} />);
    expect(screen.getByRole('status').textContent).toBe('Needs the Woodworking manual');
    fireEvent.click(screen.getByText('Log'));
    expect(sent(props)).toEqual({ route: 'resource', resource: '/material/wood' });
    view.rerender(<CraftingAtlas {...ui({ detail: recipe })} />);
    expect(screen.queryByRole('status')).toBeNull();
    view.rerender(<CraftingAtlas {...ui({ detail: locked, recipes: [{ id: 'r2', name: 'Same name', manual_hint: 'Needs the Woodworking manual' }] })} />);
    expect(screen.getByRole('status')).toBeTruthy();
    expect(screen.getByText('Needs manual')).toBeTruthy();
    view.rerender(<CraftingAtlas {...ui({ mode: 'page', entries: [locked] })} />);
    expect(screen.getByRole('status')).toBeTruthy();
    fireEvent.click(screen.getByText('Return to dependency atlas'));
    view.rerender(<CraftingAtlas {...ui({ detail: recipe })} />);
    expect(screen.queryByRole('status')).toBeNull();
    view.unmount();
    render(<CraftingAtlas {...ui({ detail: locked })} />);
    expect(screen.getByRole('status').textContent).toBe('Needs the Woodworking manual');
  });
});
