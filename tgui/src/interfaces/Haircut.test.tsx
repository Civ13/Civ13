// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react';
afterEach(cleanup);
import type { HaircutData } from '../data';
import type { ScreenProps } from '../types';
import { screens } from '../fixtures.mts';
import { Haircut } from './Haircut';

// jsdom has no canvas; the window must work as a list of named buttons without one.
const sample = screens.find(fixture => fixture.name === 'haircut')!.data as HaircutData;
const open = (data: HaircutData = sample, interactive = true) => {
  const ui: ScreenProps<HaircutData> = { template: 'haircut.tmpl', interactive, act: vi.fn(), data };
  render(<Haircut {...ui} />);
  return ui;
};
const hairTiles = () => within(screen.getByRole('group', { name: 'Hair styles' }));
const beardTiles = () => within(screen.getByRole('group', { name: 'Facial hair styles' }));
const look = (name: string) => fireEvent.click(within(screen.getByRole('group', { name: 'Which look to show' })).getByText(name));
const start = () => screen.getByText('Start cutting').closest('.Button')!;

describe('haircut window', () => {
  it('opens on the current styles with nothing to cut and sends nothing while browsing', () => {
    const ui = open();
    expect(hairTiles().getByRole('button', { name: /Shoulder-length Hair/ }).getAttribute('aria-pressed')).toBe('true');
    expect(hairTiles().getAllByRole('button')[0].textContent).toContain('Now');
    expect(start().className).toContain('Button--disabled');
    fireEvent.click(start());
    fireEvent.click(hairTiles().getByRole('button', { name: 'Mohawk' }));
    fireEvent.click(screen.getByLabelText('Turn right'));
    look('Now');
    expect(ui.act).not.toHaveBeenCalled();
  });

  it('sends the chosen pair once, keeping the style that was not changed', () => {
    const ui = open();
    fireEvent.click(hairTiles().getByRole('button', { name: 'Mohawk' }));
    fireEvent.click(start());
    expect(ui.act).toHaveBeenLastCalledWith('cut', { value: 'Mohawk', beard: 'Full Beard' });
    fireEvent.click(beardTiles().getByRole('button', { name: 'Goatee' }));
    fireEvent.click(start());
    expect(ui.act).toHaveBeenLastCalledWith('cut', { value: 'Mohawk', beard: 'Goatee' });
    fireEvent.click(screen.getByText('Cancel'));
    expect(ui.act).toHaveBeenLastCalledWith('cancel');
  });

  it('says what will change and turns the figure through four sides', () => {
    open();
    fireEvent.click(beardTiles().getByRole('button', { name: 'Shaved' }));
    const changes = document.querySelector('.cut-changes')!;
    expect(changes.textContent).toContain('Shoulder-length Hair (no change)');
    expect(changes.querySelector('s')!.textContent).toBe('Full Beard');
    expect(changes.querySelector('b')!.textContent).toBe('Shaved');
    const figure = () => screen.getByRole('img').getAttribute('aria-label');
    expect(figure()).toBe('You from the front, after the cut');
    fireEvent.click(screen.getByLabelText('Turn right'));
    fireEvent.click(screen.getByLabelText('Turn right'));
    expect(figure()).toBe('You from the back, after the cut');
    look('Now');
    expect(figure()).toBe('You from the back, as now');
    fireEvent.click(hairTiles().getByRole('button', { name: 'Bald' }));
    expect(figure()).toBe('You from the back, after the cut');
  });

  it('narrows hair by length and by name', () => {
    open();
    fireEvent.click(within(screen.getByRole('group', { name: 'Hair length' })).getByText('Shaven'));
    expect(hairTiles().getAllByRole('button').map(tile => tile.textContent)).toEqual(['Bald', 'Skinhead']);
    fireEvent.click(within(screen.getByRole('group', { name: 'Hair length' })).getByText('All'));
    fireEvent.change(screen.getByLabelText('Find a hair style'), { target: { value: 'cut' } });
    expect(hairTiles().getAllByRole('button').map(tile => tile.textContent)).toEqual(['Buzzcut', 'Cut Hair', 'Crewcut', 'Undercut']);
    fireEvent.change(screen.getByLabelText('Find a hair style'), { target: { value: 'zzz' } });
    expect(screen.getByText('Nothing by that name.')).toBeTruthy();
  });

  it('names the other person when barbering and hides facial hair that cannot change', () => {
    const ui = open(screens.find(fixture => fixture.name === 'haircut-barber')!.data as HaircutData);
    expect(screen.getByText(/Cutting Tomas Reed's hair\./)).toBeTruthy();
    expect(screen.queryByRole('group', { name: 'Facial hair styles' })).toBeNull();
    expect(screen.getByText(/stay beside them/)).toBeTruthy();
    fireEvent.click(hairTiles().getByRole('button', { name: 'Bald' }));
    fireEvent.click(start());
    expect(ui.act).toHaveBeenLastCalledWith('cut', { value: 'Bald', beard: 'Full Beard' });
  });

  it('falls back to the current style when the picked one stops being offered', () => {
    const ui: ScreenProps<HaircutData> = { template: 'haircut.tmpl', interactive: true, act: vi.fn(), data: sample };
    const { rerender } = render(<Haircut {...ui} />);
    fireEvent.click(hairTiles().getByRole('button', { name: 'Mohawk' }));
    rerender(<Haircut {...ui} data={{ ...sample, hair: 'Bald', hair_styles: [{ name: 'Bald', length: 0, row: 0, tint: 1 }] }} />);
    expect(start().className).toContain('Button--disabled');
  });

  it('ignores picture names and colours that are not plain', () => {
    open({ ...sample, sheet: 'https://example.com/x.png', body: '../x.png', hair_color: 'red;background:url(x)' });
    expect(document.querySelectorAll('img')).toHaveLength(0);
    expect(hairTiles().getAllByRole('button').length).toBe(18);
  });

  it('cannot act when the window is not interactive', () => {
    const ui = open(sample, false);
    expect((hairTiles().getByRole('button', { name: 'Mohawk' }) as HTMLButtonElement).disabled).toBe(true);
    fireEvent.click(screen.getByText('Cancel'));
    expect(ui.act).not.toHaveBeenCalled();
  });
});
