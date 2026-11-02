import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react';
vi.mock('tgui-core/components', () => ({
  Section: ({ children, title }: any) => <section><h2>{title}</h2>{children}</section>,
  NoticeBox: ({ children }: any) => <aside>{children}</aside>,
  Button: ({ children, disabled, onClick }: any) => <button disabled={disabled} onClick={onClick}>{children}</button>,
}));
import { CraftingAtlas } from './CraftingAtlas';
import type { Data, ScreenProps } from '../types';
afterEach(cleanup);
const recipe = {
  id: 'r2', name: 'Fictional planks', kind: 'Material / camp', file: 'config/crafting/material_recipes_camp.txt', line: 27,
  conditions: 'Map &amp; faction gates', era_label: '3 / 4', era_basis: 'Research node',
  inputs: [{ id: '/material/wood', name: 'Log', quantity: '1', image: 'atlas_' + 'a'.repeat(32) + '.png', preview: 'Inherited default; overlays can differ.' }],
  outputs: [{ id: '/obj/plank', name: 'Planks', quantity: '4 nominal', image: '' }],
  variants: [{ id: 'r1', kind: 'Material / global', line: 12 }, { id: 'r2', kind: 'Material / camp', line: 27 }],
};
const ui = (data: Data = {}, interactive = true): ScreenProps => ({
  template: 'crafting_atlas.tmpl', data: { mode: 'graph', query: 'wood', era: 'multiple', processor: 'sawmill', recipe_count: 1, resource_count: 1, recipes: [{ id: 'r2', name: 'Same name', era_label: '3 / 4' }], resources: [{ id: 'wood_id', name: 'Same name' }], detail: recipe, ...data },
  interactive, act: vi.fn(),
});
const sent = (props: ScreenProps) => {
  const call = vi.mocked(props.act).mock.calls.at(-1);
  expect(call?.[0]).toBe('atlas_navigate');
  expect(Object.keys(call?.[1] ?? {})).toEqual(['atlas_navigate']);
  return JSON.parse(String(call?.[1]?.atlas_navigate));
};
describe('Crafting Atlas navigation', () => {
  it('keeps search/filter edits local until submit and cancels without navigation', () => {
    const props = ui(); render(<CraftingAtlas {...props} />);
    fireEvent.change(screen.getByRole('searchbox'), { target: { value: 'new query' } });
    fireEvent.change(screen.getByLabelText('Unlock era'), { target: { value: '0' } });
    expect(props.act).not.toHaveBeenCalled();
    fireEvent.click(screen.getByText('Cancel filter edits'));
    expect((screen.getByRole('searchbox') as HTMLInputElement).value).toBe('wood');
    expect((screen.getByLabelText('Unlock era') as HTMLSelectElement).value).toBe('multiple');
    expect(props.act).not.toHaveBeenCalled();
    fireEvent.change(screen.getByLabelText('Unlock era'), { target: { value: 'unknown' } });
    fireEvent.change(screen.getByLabelText('Processor'), { target: { value: 'tanning_rack' } });
    fireEvent.click(screen.getByText('Filter'));
    expect(sent(props)).toEqual({ route: 'open', query: 'wood', era: 'unknown', processor: 'tanning_rack' });
    expect((screen.getByRole('searchbox') as HTMLInputElement).maxLength).toBe(64);
  });
  it('separates resource identity from recipe identity and resets filters for resource navigation', () => {
    const props = ui(); const view = render(<CraftingAtlas {...props} />);
    const resource = view.container.querySelector('[data-result-type="resource"]')!;
    const recipeResult = view.container.querySelector('[data-result-type="recipe"]')!;
    fireEvent.click(within(resource as HTMLElement).getByText('Same name'));
    expect(sent(props)).toEqual({ route: 'resource', resource: 'wood_id' });
    fireEvent.click(within(recipeResult as HTMLElement).getByText('Same name'));
    expect(sent(props)).toEqual({ route: 'open', query: 'wood', era: 'multiple', processor: 'sawmill', recipe: 'r2' });
    fireEvent.click(screen.getByText('Log'));
    expect(sent(props)).toEqual({ route: 'resource', resource: '/material/wood' });
  });
  it('retains selected variant source, quantities and applied filters', () => {
    const props = ui(); render(<CraftingAtlas {...props} />);
    expect(screen.getByText('(4 nominal)')).toBeTruthy();
    expect(screen.getByText('Map & faction gates')).toBeTruthy();
    expect(screen.getByRole('link', { name: /Catalog source/ }).getAttribute('href')).toBe('https://github.com/Civ13/Civ13/blob/master/config/crafting/material_recipes_camp.txt#L27');
    fireEvent.change(screen.getByLabelText('Transformation / catalog variant'), { target: { value: 'r1' } });
    expect(sent(props)).toEqual({ route: 'open', query: 'wood', era: 'multiple', processor: 'sawmill', recipe: 'r1' });
  });
  it('preserves explicit page navigation, selection context and deliberate reset routes', () => {
    const props = ui({ mode: 'page', page: 2, previous: true, next: true, entries: [recipe] });
    render(<CraftingAtlas {...props} />);
    expect(screen.queryByLabelText('Unlock era')).toBeNull();
    fireEvent.click(screen.getByText('Previous')); expect(sent(props)).toEqual({ route: 'page', page: 1, query: 'wood' });
    fireEvent.click(screen.getByText('Next')); expect(sent(props)).toEqual({ route: 'page', page: 3, query: 'wood' });
    fireEvent.change(screen.getByLabelText('Transformation / catalog variant'), { target: { value: 'r1' } });
    expect(sent(props)).toEqual({ route: 'page', page: 2, query: 'wood', recipe: 'r1' });
    fireEvent.click(screen.getByText('All recipes')); expect(sent(props)).toEqual({ route: 'page', page: 1 });
    fireEvent.click(screen.getByText('Return to dependency atlas')); expect(sent(props)).toEqual({ route: 'reset' });
    fireEvent.click(screen.getByRole('button', { name: 'Search' })); expect(sent(props)).toEqual({ route: 'open', query: 'wood' });
  });
  it('keeps acquisition conditions, reviewed provenance and related-resource navigation', () => {
    const props = ui({ guidance: { name: 'Sand', heading: 'Gathering from', more: true, routes: [{ name: 'Shovel', details: [{ label: 'conditions', value: 'Non-harm intent' }], related: [{ id: 'clay', name: 'Clay', heading: 'Can provide (conditional)' }], file: 'code/example.dm', line: 8, revision: 'b'.repeat(40) }] } });
    render(<CraftingAtlas {...props} />);
    expect(screen.getByText('Gathering from Sand')).toBeTruthy();
    expect(screen.getByText('conditions: Non-harm intent')).toBeTruthy();
    expect(screen.getByText(/Can provide \(conditional\)/)).toBeTruthy();
    expect(screen.getByText('More routes are available in the full web atlas.')).toBeTruthy();
    expect(screen.getAllByRole('link', { name: /Catalog source/ }).some(link => link.getAttribute('href')?.includes('/' + 'b'.repeat(40) + '/'))).toBe(true);
    fireEvent.click(screen.getByText('Clay')); expect(sent(props)).toEqual({ route: 'resource', resource: 'clay' });
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
  it('keeps rich-looking text inert and rejects nonlocal symbol URLs and unsafe source paths', () => {
    const view = render(<CraftingAtlas {...ui({ detail: { ...recipe, name: '&lt;script&gt;inert&lt;/script&gt;', file: '../../settings', inputs: [{ id: 'x', name: '&lt;img src=x&gt;', quantity: '<b>1</b>', image: 'https://example.com/x.png' }] } })} />);
    expect(screen.getByText('<script>inert</script>')).toBeTruthy();
    expect(screen.getByText('<img src=x>')).toBeTruthy();
    expect(view.container.querySelector('script,img')).toBeNull();
    expect(screen.queryByRole('link', { name: /Catalog source/ })).toBeNull();
  });
  it('blocks every navigation and form action when the owner state is not interactive', () => {
    const props = ui({}, false); render(<CraftingAtlas {...props} />);
    for (const button of screen.getAllByRole('button')) fireEvent.click(button);
    expect(props.act).not.toHaveBeenCalled();
    expect((screen.getByRole('searchbox') as HTMLInputElement).disabled).toBe(true);
    expect((screen.getByLabelText('Unlock era') as HTMLSelectElement).disabled).toBe(true);
  });

  it('shows one family on the left and canonical recipe choices on the right', () => {
    const family = [{ id: 'r2', label: '4 x planks / Material / camp / Bronze (line 27)' },
                    { id: 'r9', label: '2 x planks / Material / global / Stone (line 81)' }];
    const props = ui({ family_count: 1, recipe_count: 2,
      recipes: [{ id: 'r2', family_id: 'family_explicit', name: 'Plank family', variant_count: 2, era_label: 'Multiple unlock eras' }],
      detail: { ...recipe, family_variants: family } });
    const view = render(<CraftingAtlas {...props} />);
    expect(view.container.querySelectorAll('[data-result-type="recipe"]')).toHaveLength(1);
    expect(screen.getByText(/1 recipe family \/ 2 matching recipes/)).toBeTruthy();
    expect(screen.getByText('2 recipe variants / Multiple unlock eras')).toBeTruthy();
    const select = screen.getByLabelText('Recipe variant') as HTMLSelectElement;
    expect(select.value).toBe('r2');
    expect(within(select).getAllByRole('option')).toHaveLength(2);
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
    expect(screen.getByText('Requires locked research and 9 hides')).toBeTruthy();
    expect(screen.queryByText('(4 nominal)')).toBeNull();
    expect(screen.queryByText('Map & faction gates')).toBeNull();
    expect(screen.queryByLabelText('Transformation / catalog variant')).toBeNull();
    expect(screen.getByRole('link', { name: /Catalog source/ }).getAttribute('href')).toContain('material_recipes_global.txt#L81');
  });
  it('does not regroup identical names, hide returned locked variants or infer availability', () => {
    const props = ui({ family_count: 2, recipe_count: 3,
      recipes: [{ id: 'r2', family_id: 'family_one', name: 'Shared label', variant_count: 2, era_label: 'Unknown' },
                { id: 'r8', family_id: 'family_two', name: 'Shared label', variant_count: 1, era_label: 'Stone Age' }],
      detail: { ...recipe, family_variants: [{ id: 'r2', label: 'Known requirements' }, { id: 'r8', label: 'Unavailable on another map; unknown research' }] } });
    const view = render(<CraftingAtlas {...props} />);
    expect(view.container.querySelectorAll('[data-result-type="recipe"]')).toHaveLength(2);
    expect(screen.getByRole('option', { name: 'Unavailable on another map; unknown research' })).toBeTruthy();
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
    const props = ui({ family_count: 1, detail: { ...recipe,
      family_variants: [{ id: 'r2', label: '&lt;img src=x onerror=bad&gt;' }, { id: 'r9', label: 'Other variant' }] } }, false);
    const view = render(<CraftingAtlas {...props} />);
    const select = screen.getByLabelText('Recipe variant') as HTMLSelectElement;
    expect(select.disabled).toBe(true);
    expect(screen.getByRole('option', { name: '<img src=x onerror=bad>' })).toBeTruthy();
    expect(view.container.querySelectorAll('img')).toHaveLength(1); // Existing validated local resource symbol only.
    fireEvent.change(select, { target: { value: 'r9' } });
    expect(props.act).not.toHaveBeenCalled();
  });
});
