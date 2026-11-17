import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, screen, within } from '@testing-library/react';
import { render } from '../testing';
vi.mock('tgui-core/components', () => ({
  Button: ({ children, onClick, disabled, selected }: any) => <button disabled={disabled} onClick={onClick} aria-pressed={selected}>{children}</button>,
  Section: ({ children, title, buttons }: any) => <section><h2>{title}</h2>{buttons}{children}</section>,
  NoticeBox: ({ children }: any) => <aside>{children}</aside>,
}));
import { Research, filterKey } from './Research';
import { matches, minutes, nodeState } from './researchShared';
import type { ScreenProps } from '../types';
afterEach(cleanup);
const node = (id: string, name: string, state: string, extra: Record<string, unknown> = {}) => ({ id, name, state, state_label: state, cost_ticks: 100, mode_text: 'Passive study', era_name: 'Stone Age', discipline: 'Engineering', groundwork: [], research_needs: [], recipe_names: [], study_minutes: 1, research_minutes: 17, write_minutes: 2, ...extra });
const bench = (extra: Record<string, unknown> = {}): ScreenProps => ({ template: 'research_bench.tmpl', interactive: true, act: vi.fn(), data: { book_mode: 1, bench_tier: 0, max_tier: 8, books: [], viewer: { tool: null, sheets: 0, skills: [{ name: 'Engineering', level: 14 }, { name: 'Medicine', level: 0 }] },
  trees: [
    { idx: 0, tree_name: 'Main', layers: [{ layer_name: 'Industrial', nodes: [
      node('tools', 'Basic Toolmaking', 'known', { can_write: 1 }),
      node('masonry', 'Stone Masonry', 'ready', { prereq_ids: 'tools', assignable: 1, queueable: 1, recipe_names: ['stone wall', 'kiln'], groundwork: [{ id: 'tools', name: 'Basic Toolmaking', known: 1 }], research_needs: [{ label: 'Bench tier 1 (this bench is tier 0)', ok: 0 }] }),
      node('pottery', 'Pottery', 'study', { can_study: 1, can_copy: 1, holder: 1 }),
      node('bronze', 'Bronze Working', 'locked', { prereq_ids: 'masonry', groundwork: [{ id: 'masonry', name: 'Stone Masonry', known: 0 }], queue_pos: 1 }),
    ] }] },
    { idx: 1, tree_name: 'Agriculture', layers: [{ layer_name: 'Agriculture', nodes: [node('farming', 'Basic Agriculture', 'blocked', { discipline: 'Agriculture', recipe_names: ['plough'] })] }] },
  ], ...extra } });
describe('research helpers', () => {
  it('maps faction statuses and book states onto one vocabulary', () => {
    expect(nodeState({ status_text: 'Done' })).toBe('known');
    expect(nodeState({ status_text: 'In Progress' })).toBe('progress');
    expect(nodeState({ status_text: 'Available', state: 'study' })).toBe('study');
    expect(nodeState({})).toBe('locked');
    expect(filterKey({ state: 'blocked' })).toBe('locked');
    expect(filterKey({ state: 'study_locked' })).toBe('locked');
  });
  it('matches every search word across name, recipes and discipline', () => {
    expect(matches('stone wall', 'Stone Masonry', ['stone wall', 'kiln'])).toBe(true);
    expect(matches('kiln agric', 'Stone Masonry', ['kiln'], 'Engineering')).toBe(false);
    expect(matches('  ', 'anything')).toBe(true);
    expect(minutes(1)).toBe('1 minute');
    expect(minutes(120)).toBe('2 hours');
  });
});
describe('research bench in book mode', () => {
  it('counts states on the filter chips and narrows them with the search', () => {
    render(<Research {...bench()} />);
    const chips = screen.getByRole('group', { name: 'Show' });
    expect(within(chips).getByText('Ready to study').textContent).toBe('Ready to study 1');
    expect(within(chips).getByText('Not yet').textContent).toBe('Not yet 2');
    fireEvent.change(screen.getByRole('searchbox'), { target: { value: 'kiln' } });
    expect(within(chips).getByText('All').textContent).toBe('All 1');
    expect(within(chips).getByText('Can research').textContent).toBe('Can research 1');
    expect(screen.getByText('Agriculture (0)')).toBeTruthy();
  });
  it('lists matches from every tree with a one-click action in list view', () => {
    const ui = bench(); render(<Research {...ui} />);
    fireEvent.click(screen.getByText('List'));
    expect(screen.getByText('Basic Agriculture')).toBeTruthy();
    const names = [...document.querySelectorAll('.rs-row-main strong')].map(el => el.textContent);
    expect(names).toEqual(['Pottery', 'Stone Masonry', 'Basic Agriculture', 'Bronze Working', 'Basic Toolmaking']);
    fireEvent.click(screen.getByText('Study'));
    expect(ui.act).toHaveBeenLastCalledWith('study', { value: 'pottery' });
    fireEvent.click(screen.getByText('Research'));
    expect(ui.act).toHaveBeenLastCalledWith('assign', { value: 'masonry' });
    fireEvent.click(screen.getByText('Write'));
    expect(ui.act).toHaveBeenLastCalledWith('write', { value: 'tools' });
    fireEvent.click(screen.getByText('Known'));
    expect([...document.querySelectorAll('.rs-row-main strong')].map(el => el.textContent)).toEqual(['Basic Toolmaking']);
  });
  it('shows groundwork and bench needs as met or missing, and walks the chain', () => {
    const ui = bench(); render(<Research {...ui} />);
    fireEvent.click(screen.getByText('Bronze Working'));
    const dialog = screen.getByRole('dialog');
    expect(dialog.querySelector('.rs-missing')?.textContent).toContain('Stone Masonry');
    fireEvent.click(within(dialog).getByText('Remove from queue'));
    expect(ui.act).toHaveBeenLastCalledWith('unqueue', { value: 'bronze' });
    fireEvent.click(within(dialog).getByText('Stone Masonry'));
    const next = screen.getByRole('dialog');
    expect(next.getAttribute('aria-label')).toBe('Stone Masonry');
    expect(next.querySelector('.rs-ok')?.textContent).toContain('Basic Toolmaking');
    expect(next.querySelector('.rs-checks:last-of-type .rs-missing')?.textContent).toContain('Bench tier 1');
    expect(within(next).getByText(/about 17 minutes at your pace/)).toBeTruthy();
    expect(within(next).getByText('Bronze Working')).toBeTruthy();
    fireEvent.click(within(next).getByText('Add to queue'));
    expect(ui.act).toHaveBeenLastCalledWith('queue', { value: 'masonry' });
    fireEvent.click(within(next).getByText('Research this here'));
    expect(ui.act).toHaveBeenLastCalledWith('assign', { value: 'masonry' });
  });
  it('offers copy and write for a chapter from its detail', () => {
    const ui = bench(); render(<Research {...ui} />);
    fireEvent.click(screen.getByText('Pottery'));
    fireEvent.click(screen.getByText('Copy into the other book'));
    expect(ui.act).toHaveBeenLastCalledWith('copy', { value: 'pottery' });
    fireEvent.keyDown(document, { key: 'Escape' });
    fireEvent.click(screen.getByText('Basic Toolmaking'));
    fireEvent.click(screen.getByText('Write it from memory (about 2 minutes)'));
    expect(ui.act).toHaveBeenLastCalledWith('write', { value: 'tools' });
  });
  it('shows progress, pace, the checklist and the queue for the current subject', () => {
    const ui = bench({ assigned: { id: 'masonry', name: 'Stone Masonry', percent: 40, ticks: 40, cost: 100, working: 1, eta_minutes: 10, supply: 0, supply_cap: 200, supply_text: 'Engineering supplies (wood, stone or metal)', library_bonus: 20,
      checks: [{ label: 'You are working on it', ok: 1 }, { label: 'Light to work by', ok: 0 }] }, queue: [{ id: 'bronze', name: 'Bronze Working' }] });
    render(<Research {...ui} />);
    expect(screen.getByRole('progressbar', { name: 'Research progress' }).getAttribute('aria-valuenow')).toBe('40');
    expect(screen.getByText(/about 10 minutes left at this pace/)).toBeTruthy();
    expect(screen.getByText(/Half speed until some are used/)).toBeTruthy();
    expect(screen.getByText(/20% faster/)).toBeTruthy();
    expect(document.querySelector('.rs-checks .rs-missing')?.textContent).toContain('Light to work by');
    expect(screen.getByText('Being researched')).toBeTruthy();
    fireEvent.click(screen.getByText('Stop researching'));
    expect(ui.act).toHaveBeenLastCalledWith('stop_research', { value: 1 });
    fireEvent.click(screen.getByLabelText('Remove Bronze Working from the queue'));
    expect(ui.act).toHaveBeenLastCalledWith('unqueue', { value: 'bronze' });
    fireEvent.click(screen.getByText('Clear queue'));
    expect(ui.act).toHaveBeenLastCalledWith('clear_queue', { value: 1 });
  });
  it('names what sets the speed and what counts as practice', () => {
    const ui = bench({ assigned: { id: 'masonry', name: 'Stone Masonry', percent: 40, ticks: 40, cost: 100, working: 1, supply: 5, supply_cap: 200, supply_text: 'Engineering supplies', library_bonus: 20, checks: [],
      factors: [{ label: "Ada's scholarship", effect: 'x1.2', ok: 1 }, { label: 'Supplies on the bench', effect: 'half speed until some are set out', ok: 0 }],
      field_work: [{ label: 'Make 12 things taught by Basic Toolmaking', percent: 25, done: 0, have: 3, needed: 12, examples: ['flint axe', 'stone hammer', '4 more'] }] } });
    render(<Research {...ui} />);
    expect(screen.getByText('Speed right now')).toBeTruthy();
    expect(screen.getByText('x1.2')).toBeTruthy();
    expect(document.querySelector('.rs-checks .rs-missing')?.textContent).toContain('half speed until some are set out');
    expect(screen.getByText('Without waiting')).toBeTruthy();
    expect(screen.getByText(/you have 3 of 12/)).toBeTruthy();
    expect(screen.getByText('Any of: flint axe, stone hammer, 4 more')).toBeTruthy();
    expect(screen.getByText(/Full speed while they last/)).toBeTruthy();
    expect(screen.queryByText(/Library nearby/)).toBeNull();
    expect(screen.getByText(/between two benches/)).toBeTruthy();
  });
  it('warns when the scholar holds no writing tool or sheets', () => {
    render(<Research {...bench()} />);
    expect(screen.getByText('no pencil, pen or slate in hand')).toBeTruthy();
    expect(screen.getByText('0 blank sheets')).toBeTruthy();
    expect(screen.getByText('Engineering 14')).toBeTruthy();
    expect(screen.queryByText(/Medicine/)).toBeNull();
  });
  it('sends nothing when the screen is read-only', () => {
    const ui = { ...bench(), interactive: false }; render(<Research {...ui} />);
    fireEvent.click(screen.getByText('List'));
    fireEvent.click(screen.getByText('Study'));
    expect(ui.act).not.toHaveBeenCalled();
  });
});
describe('tech tree opened from a recipe', () => {
  const tech = (extra: Record<string, unknown> = {}): ScreenProps => ({ template: 'tech_tree.tmpl', interactive: true, act: vi.fn(), data: { tech_tree: 1, book_research: 1,
    trees: [
      { idx: 0, tree_name: 'Main', layers: [{ layer_name: 'Industrial', nodes: [
        node('tools', 'Basic Toolmaking', 'ready', { status_text: 'Available', state_label: 'Ready to learn' }),
        node('masonry', 'Stone Masonry', 'locked', { status_text: 'Locked', state_label: 'Needs groundwork', prereq_ids: 'tools', groundwork: [{ id: 'tools', name: 'Basic Toolmaking', known: 0 }], recipe_names: ['stone pillar'] }),
      ] }] },
      { idx: 1, tree_name: 'Agriculture', layers: [{ layer_name: 'Agriculture', nodes: [node('farming', 'Basic Agriculture', 'known', { status_text: 'Done', state_label: 'You know this' })] }] },
    ], ...extra } });
  it('jumps to the asked-for node on its tree and outlines the groundwork', () => {
    const ui = tech(); const view = render(<Research {...ui} />);
    fireEvent.click(screen.getByText('Agriculture'));
    fireEvent.change(screen.getByRole('searchbox'), { target: { value: 'plough' } });
    view.rerender(<Research {...tech({ focus: 'masonry', focus_seq: 1 })} />);
    expect((screen.getByRole('searchbox') as HTMLInputElement).value).toBe('');
    const focused = document.querySelector('.research-node.focused');
    expect(focused?.textContent).toContain('Stone Masonry');
    expect(document.querySelector('.research-node.ancestor')?.textContent).toContain('Basic Toolmaking');
    expect(screen.getByText(/Outlined in orange: the technology you need first/)).toBeTruthy();
    expect(screen.queryByRole('dialog')).toBeNull();
    fireEvent.click(screen.getByText('Details'));
    const dialog = within(screen.getByRole('dialog'));
    expect(dialog.getByText('Basic Toolmaking')).toBeTruthy();
    expect(dialog.getByText('stone pillar')).toBeTruthy();
  });
  it('shows no bench controls and sends nothing', () => {
    const ui = tech({ focus: 'masonry', focus_seq: 1 }); render(<Research {...ui} />);
    expect(screen.queryByText(/Research bench|Books on the bench|Assign/)).toBeNull();
    const chips = screen.getByRole('group', { name: 'Show' });
    expect(within(chips).getByText('Can learn now').textContent).toBe('Can learn now 1');
    fireEvent.click(screen.getByText('List'));
    fireEvent.click(document.querySelector('.rs-row-main') as HTMLElement);
    expect(ui.act).not.toHaveBeenCalled();
  });
});
