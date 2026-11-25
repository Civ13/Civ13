import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, screen, within } from '@testing-library/react';
import { render } from '../testing';
vi.mock('tgui-core/components', () => ({
  Button: ({ children, onClick, disabled, selected }: any) => <button disabled={disabled} onClick={onClick} aria-pressed={selected}>{children}</button>,
  Section: ({ children, title, buttons }: any) => <section><h2>{title}</h2>{buttons}{children}</section>,
  NoticeBox: ({ children }: any) => <aside>{children}</aside>,
}));
import { ResearchBook } from './ResearchBook';
import type { ScreenProps } from '../types';
afterEach(cleanup);
const book = (extra: Record<string, unknown> = {}): ScreenProps => ({ template: 'research_book.tmpl', interactive: true, act: vi.fn(), data: {
  name: 'Founding book', author: 'Mira', has_text: 1, held: 1, busy: 0,
  chapters: [
    { id: 'tools', name: 'Basic Toolmaking', state: 'known', era_name: 'Stone Age', discipline: 'Engineering', groundwork: [], study_minutes: 1, recipe_names: ['hatchet'] },
    { id: 'pottery', name: 'Pottery', state: 'study', era_name: 'Stone Age', discipline: 'Engineering', groundwork: [{ id: 'tools', name: 'Basic Toolmaking', known: 1 }], study_minutes: 1, tutor: 'Odo', recipe_names: ['clay pot', 'kiln'] },
    { id: 'bronze', name: 'Bronze Working', state: 'locked', era_name: 'Bronze Age', discipline: 'Natural Science', groundwork: [{ id: 'masonry', name: 'Stone Masonry', known: 0 }], study_minutes: 1.5, recipe_names: [] },
  ],
  unfinished: [{ id: 'masonry', name: 'Stone Masonry', percent: 30, ticks: 30, cost: 100, prototype: 'copper pickaxe', prototype_done: 0 }],
  writable: [{ id: 'fire', name: 'Firemaking', era_name: 'Stone Age', write_minutes: 2, stamina: 15 }],
  viewer: { pen: 'pencil', sheets: 3, stamina: 80, desk: 1, skills: [] }, ...extra } });
describe('research book window', () => {
  it('sorts chapters by what the reader can do and says what locked ones need', () => {
    render(<ResearchBook {...book()} />);
    expect([...document.querySelectorAll('button.rs-row-main strong')].map(el => el.textContent)).toEqual(['Pottery', 'Bronze Working', 'Basic Toolmaking']);
    expect(screen.getByText(/first learn Stone Masonry/)).toBeTruthy();
    expect(screen.getByText(/about 1 minute with Odo tutoring/)).toBeTruthy();
    expect(screen.getByText('3 research chapters, 1 unfinished.', { exact: false })).toBeTruthy();
  });
  it('studies, reads and tears out with one click', () => {
    const ui = book(); render(<ResearchBook {...ui} />);
    fireEvent.click(screen.getByText('Study'));
    expect(ui.act).toHaveBeenLastCalledWith('study', { value: 'pottery' });
    fireEvent.click(screen.getByText('Read the written pages'));
    expect(ui.act).toHaveBeenLastCalledWith('read', { value: 1 });
    fireEvent.click(screen.getByText('Pottery'));
    expect(screen.getByText('Teaches 2 recipes')).toBeTruthy();
    expect(screen.getByText('kiln')).toBeTruthy();
    fireEvent.click(screen.getByText('Tear this chapter out'));
    expect(ui.act).toHaveBeenLastCalledWith('rip', { value: 'pottery' });
  });
  it('filters by state and searches recipes', () => {
    render(<ResearchBook {...book()} />);
    const chips = screen.getByRole('group', { name: 'Show' });
    expect(within(chips).getByText('Needs groundwork').textContent).toBe('Needs groundwork 1');
    fireEvent.click(within(chips).getByText('Known'));
    expect([...document.querySelectorAll('button.rs-row-main strong')].map(el => el.textContent)).toEqual(['Basic Toolmaking']);
    fireEvent.click(within(chips).getByText('All'));
    fireEvent.change(screen.getByRole('searchbox'), { target: { value: 'clay' } });
    expect([...document.querySelectorAll('button.rs-row-main strong')].map(el => el.textContent)).toEqual(['Pottery']);
  });
  it('shows unfinished work and what a prototype chapter still needs', () => {
    render(<ResearchBook {...book()} />);
    expect(screen.getByText(/30% \(30\/100\) - working copper pickaxe still needed/)).toBeTruthy();
    expect(screen.getByRole('progressbar', { name: 'Stone Masonry progress' }).getAttribute('aria-valuenow')).toBe('30');
  });
  it('counts the prototypes a book has recorded for an unfinished chapter', () => {
    const ui = book();
    render(<ResearchBook {...ui} data={{ ...ui.data, unfinished: [{ id: 'bronze', name: 'Bronze Working', percent: 45, ticks: 45, cost: 100, protos_made: 3, protos_max: 5 }] }} />);
    expect(screen.getByText(/45% \(45\/100\) - prototypes made 3 of 5/)).toBeTruthy();
  });
  it('writes a known chapter only with a pen, a sheet and the stamina for it', () => {
    const ui = book(); const view = render(<ResearchBook {...ui} />);
    fireEvent.click(screen.getByText('Write'));
    expect(ui.act).toHaveBeenLastCalledWith('write', { value: 'fire' });
    for (const viewer of [{ pen: null, sheets: 3, stamina: 80 }, { pen: 'pencil', sheets: 0, stamina: 80 }, { pen: 'pencil', sheets: 3, stamina: 5 }]) {
      view.rerender(<ResearchBook {...ui} data={{ ...ui.data, viewer }} />);
      expect((screen.getByText('Write') as HTMLButtonElement).disabled).toBe(true);
    }
    view.rerender(<ResearchBook {...ui} data={{ ...ui.data, writable: [] }} />);
    expect(screen.getByText('Everything you know is already in this book.')).toBeTruthy();
  });
  it('blocks writing with occupied hands and restores it when the refreshed book permits it', () => {
    const ui = book(); const view = render(<ResearchBook {...ui} />);
    for (const [held, problem] of [
      [1, 'Put the book down beside you first.'],
      [0, 'Free the hand opposite your pen, or hold a blank sheet in it.'],
    ] as const) {
      view.rerender(<ResearchBook {...ui} data={{ ...ui.data, held, viewer: { ...ui.data.viewer, write_hands_problem: problem } }} />);
      const write = screen.getByText('Write') as HTMLButtonElement;
      expect(write.disabled).toBe(true);
      fireEvent.click(write);
      expect(ui.act).not.toHaveBeenCalled();
    }
    expect(screen.getByText(/Free the hand opposite your pen/)).toBeTruthy();
    view.rerender(<ResearchBook {...ui} data={{ ...ui.data, held: 0 }} />);
    const write = screen.getByText('Write') as HTMLButtonElement;
    expect(write.disabled).toBe(false);
    fireEvent.click(write);
    expect(ui.act).toHaveBeenLastCalledWith('write', { value: 'fire' });
  });
  it('explains language blocks without offering Continue or counting them as ready', () => {
    const ui = book();
    const readable = ui.data.chapters[1];
    const languageBlocked = { ...readable, id: 'paper', name: 'Pulp and Paper',
      state: 'blocked', read_percent: 40,
      read_problem: "This chapter is written in Norse, and you can't follow enough Norse to study it." };
    render(<ResearchBook {...ui} data={{ ...ui.data, chapters: [readable, languageBlocked] }} />);
    const row = screen.getByText('Pulp and Paper').closest('.rs-row') as HTMLElement;
    expect(within(row).getByText(/written in Norse/)).toBeTruthy();
    expect(within(row).queryByText('Study')).toBeNull();
    expect(within(row).queryByText('Continue')).toBeNull();
    const chips = screen.getByRole('group', { name: 'Show' });
    expect(within(chips).getByText('Ready to study').textContent).toBe('Ready to study 1');
    fireEvent.click(within(chips).getByText('Ready to study'));
    expect(screen.queryByText('Pulp and Paper')).toBeNull();
    expect(screen.getByText('Pottery')).toBeTruthy();
  });
  it('uses the supplied estimate for an interrupted tutored chapter, including short waits', () => {
    const ui = book();
    const chapter = { ...ui.data.chapters[1], read_percent: 80, study_minutes: 0 };
    const view = render(<ResearchBook {...ui} data={{ ...ui.data, chapters: [chapter] }} />);
    expect(screen.getByText(/80% read - less than a minute left with Odo tutoring/)).toBeTruthy();
    fireEvent.click(screen.getByText('Continue'));
    expect(ui.act).toHaveBeenLastCalledWith('study', { value: 'pottery' });
    view.rerender(<ResearchBook {...ui} data={{ ...ui.data, chapters: [{ ...chapter, study_minutes: 2.5 }] }} />);
    expect(screen.getByText(/about 2.5 minutes left with Odo tutoring/)).toBeTruthy();
  });

});
