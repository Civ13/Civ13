import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react';
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
    expect(ui.act).toHaveBeenLastCalledWith('study', { study: 'pottery' });
    fireEvent.click(screen.getByText('Research'));
    expect(ui.act).toHaveBeenLastCalledWith('assign', { assign: 'masonry' });
    fireEvent.click(screen.getByText('Write'));
    expect(ui.act).toHaveBeenLastCalledWith('write', { write: 'tools' });
    fireEvent.click(screen.getByText('Known'));
    expect([...document.querySelectorAll('.rs-row-main strong')].map(el => el.textContent)).toEqual(['Basic Toolmaking']);
  });
  it('shows groundwork and bench needs as met or missing, and walks the chain', () => {
    const ui = bench(); render(<Research {...ui} />);
    fireEvent.click(screen.getByText('Bronze Working'));
    const dialog = screen.getByRole('dialog');
    expect(dialog.querySelector('.rs-missing')?.textContent).toContain('Stone Masonry');
    fireEvent.click(within(dialog).getByText('Remove from queue'));
    expect(ui.act).toHaveBeenLastCalledWith('unqueue', { unqueue: 'bronze' });
    fireEvent.click(within(dialog).getByText('Stone Masonry'));
    const next = screen.getByRole('dialog');
    expect(next.getAttribute('aria-label')).toBe('Stone Masonry');
    expect(next.querySelector('.rs-ok')?.textContent).toContain('Basic Toolmaking');
    expect(next.querySelector('.rs-checks:last-of-type .rs-missing')?.textContent).toContain('Bench tier 1');
    expect(within(next).getByText(/about 17 minutes at your pace/)).toBeTruthy();
    expect(within(next).getByText('Bronze Working')).toBeTruthy();
    fireEvent.click(within(next).getByText('Add to queue'));
    expect(ui.act).toHaveBeenLastCalledWith('queue', { queue: 'masonry' });
    fireEvent.click(within(next).getByText('Research this here'));
    expect(ui.act).toHaveBeenLastCalledWith('assign', { assign: 'masonry' });
  });
  it('offers copy and write for a chapter from its detail', () => {
    const ui = bench(); render(<Research {...ui} />);
    fireEvent.click(screen.getByText('Pottery'));
    fireEvent.click(screen.getByText('Copy into the other book'));
    expect(ui.act).toHaveBeenLastCalledWith('copy', { copy: 'pottery' });
    fireEvent.keyDown(document, { key: 'Escape' });
    fireEvent.click(screen.getByText('Basic Toolmaking'));
    fireEvent.click(screen.getByText('Write it from memory (about 2 minutes)'));
    expect(ui.act).toHaveBeenLastCalledWith('write', { write: 'tools' });
  });
  it('shows progress, pace, the checklist and the queue for the current subject', () => {
    const ui = bench({ assigned: { id: 'masonry', name: 'Stone Masonry', percent: 40, ticks: 40, cost: 100, working: 1, eta_minutes: 10, supply: 0, supply_cap: 200, supply_text: 'Engineering supplies (wood, stone or metal)', library_bonus: 20,
      checks: [{ label: 'You are working on it', ok: 1 }, { label: 'Light to work by', ok: 0 }] }, queue: [{ id: 'bronze', name: 'Bronze Working' }] });
    render(<Research {...ui} />);
    expect(screen.getByRole('progressbar', { name: 'Research progress' }).getAttribute('aria-valuenow')).toBe('40');
    expect(screen.getByText(/about 10 minutes left at this pace/)).toBeTruthy();
    expect(screen.getByText(/half speed/)).toBeTruthy();
    expect(screen.getByText(/20% faster/)).toBeTruthy();
    expect(document.querySelector('.rs-checks .rs-missing')?.textContent).toContain('Light to work by');
    expect(screen.getByText('Being researched')).toBeTruthy();
    fireEvent.click(screen.getByText('Stop researching'));
    expect(ui.act).toHaveBeenLastCalledWith('stop_research', { stop_research: 1 });
    fireEvent.click(screen.getByLabelText('Remove Bronze Working from the queue'));
    expect(ui.act).toHaveBeenLastCalledWith('unqueue', { unqueue: 'bronze' });
    fireEvent.click(screen.getByText('Clear queue'));
    expect(ui.act).toHaveBeenLastCalledWith('clear_queue', { clear_queue: 1 });
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
