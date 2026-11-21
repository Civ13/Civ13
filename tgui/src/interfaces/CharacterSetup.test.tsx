// @vitest-environment jsdom
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen, within } from '@testing-library/react';
afterEach(cleanup);
import type { CharacterSetupData } from '../data';
import type { ScreenProps } from '../types';
import { screens } from '../fixtures.mts';
import { CharacterSetup } from './CharacterSetup';

const sample = screens.find(fixture => fixture.name === 'character-setup')!.data as CharacterSetupData;
const open = (data: CharacterSetupData, interactive = true) => {
  const ui: ScreenProps<CharacterSetupData> = { template: 'character_setup.tmpl', interactive, act: vi.fn(), data };
  render(<CharacterSetup {...ui} />);
  return ui;
};

describe('character setup', () => {
  it('sends appearance choices as single typed actions', () => {
    const ui = open(sample);
    fireEvent.click(screen.getByText('Male'));
    expect(ui.act).toHaveBeenLastCalledWith('gender', { value: 'male' });
    fireEvent.click(within(screen.getByRole('group', { name: 'Hair colour' })).getByRole('button', { name: 'Red' }));
    expect(ui.act).toHaveBeenLastCalledWith('hair_color', { value: 'Red' });
    fireEvent.click(screen.getByText('Topknot'));
    expect(ui.act).toHaveBeenLastCalledWith('hair_style', { value: 'Topknot' });
    const age = screen.getByLabelText('Age');
    fireEvent.change(age, { target: { value: '41' } });
    fireEvent.blur(age);
    expect(ui.act).toHaveBeenLastCalledWith('age', { value: 41 });
    const name = screen.getByLabelText('Name');
    fireEvent.change(name, { target: { value: 'Ada Reed' } });
    fireEvent.keyDown(name, { key: 'Enter' });
    expect(ui.act).toHaveBeenLastCalledWith('name', { value: 'Ada Reed' });
  });

  it('does not send an unchanged or empty box', () => {
    const ui = open(sample);
    const name = screen.getByLabelText('Name');
    fireEvent.change(name, { target: { value: '  ' } });
    fireEvent.blur(name);
    fireEvent.change(name, { target: { value: 'Maren Holt' } });
    fireEvent.blur(name);
    expect(ui.act).not.toHaveBeenCalled();
  });

  it('shows the point balance and offers take, swap and remove', () => {
    const ui = open({ ...sample, tab: 'traits' });
    expect(screen.getByRole('status').textContent).toContain('Points over2');
    expect(screen.getByRole('status').textContent).toContain('Take 2 more points of drawbacks');
    fireEvent.click(screen.getByRole('button', { name: 'Remove Agile' }));
    expect(ui.act).toHaveBeenLastCalledWith('trait_remove', { value: 'Agile' });
    // Another playstyle replaces the chosen one; a paired trait swaps and says what goes.
    fireEvent.click(screen.getAllByText('Choose instead')[0]);
    expect(ui.act).toHaveBeenLastCalledWith('trait_swap', { value: 'Tinkerer' });
    expect(screen.getByText('Replaces Agile')).toBeTruthy();
    fireEvent.click(screen.getAllByText('Swap in')[0]);
    expect(ui.act).toHaveBeenLastCalledWith('trait_swap', { value: 'Slowness' });
    fireEvent.click(screen.getAllByText('Take')[0]);
    expect(ui.act).toHaveBeenLastCalledWith('trait_add', { value: 'Naturalist' });
    // A trait that cannot change yet says why and offers nothing.
    expect(screen.getByText('You can choose again in 5 days.')).toBeTruthy();
    expect(screen.getByText('A new field can be chosen 7 days after the last change.')).toBeTruthy();
  });

  it('narrows the picker by text, kind and category', () => {
    open({ ...sample, tab: 'traits' });
    fireEvent.change(screen.getByLabelText('Find a trait'), { target: { value: 'bleed' } });
    expect(screen.getByText('Hemophilia')).toBeTruthy();
    expect(screen.queryByText('Tinkerer')).toBeNull();
    fireEvent.change(screen.getByLabelText('Find a trait'), { target: { value: '' } });
    fireEvent.click(within(screen.getByRole('group', { name: 'Kind of trait' })).getByText('Drawbacks'));
    expect(screen.queryByText('Tall')).toBeNull();
    expect(screen.getByText('Short')).toBeTruthy();
    fireEvent.click(within(screen.getByRole('group', { name: 'Kind of trait' })).getByText('All'));
    fireEvent.click(screen.getByRole('button', { name: /^Senses and speech/ }));
    expect(screen.queryByText('Tall')).toBeNull();
    expect(screen.getByText('Stutter')).toBeTruthy();
  });

  it('keeps a living character to settings', () => {
    const ui = open({ ...sample, locked: 1, tab: 'traits' });
    expect(screen.getByText('You can change your character and traits once this one has died.')).toBeTruthy();
    for (const button of screen.getAllByText('Take')) expect(button.closest('.Button')!.className).toContain('Button--disabled');
    fireEvent.click(screen.getByRole('tab', { name: 'Settings' }));
    fireEvent.click(screen.getByText('Hide'));
    expect(ui.act).toHaveBeenLastCalledWith('toggle_off', { value: 'CHAT_OOC' });
  });

  it('copes with an empty snapshot', () => {
    open({});
    fireEvent.click(screen.getByRole('tab', { name: /Traits/ }));
    expect(screen.getByText('No trait matches.')).toBeTruthy();
  });
  it('lets a verified player choose a sign or leave it to the stars', () => {
    const ui = open({ ...sample, tab: 'chart' });
    fireEvent.click(within(screen.getByRole('group', { name: 'Signs' })).getAllByText('Choose')[1]);
    expect(ui.act).toHaveBeenLastCalledWith('birth_chart', { value: 'owl' });
    fireEvent.click(screen.getByText('Leave it to the stars'));
    expect(ui.act).toHaveBeenLastCalledWith('birth_chart', { value: 'random' });
    expect(screen.queryByText('Verify Discord')).toBeNull();
  });

  it('offers verification instead of a choice to an unverified player', () => {
    const ui = open({ ...sample, tab: 'chart', chart: { ...sample.chart, verified: 0 } });
    for (const button of within(screen.getByRole('group', { name: 'Signs' })).getAllByText('Choose')) fireEvent.click(button);
    expect(ui.act).not.toHaveBeenCalled();
    fireEvent.click(screen.getByText('Verify Discord'));
    expect(ui.act).toHaveBeenLastCalledWith('verify_discord', { value: 1 });
  });

  it('shows a living character its own sign', () => {
    open({ ...sample, tab: 'chart', locked: 1, chart: { ...sample.chart, current: 'owl' } }, false);
    expect(screen.getByText(/born under The Owl/)).toBeTruthy();
    expect(screen.queryByText('Leave it to the stars')).toBeNull();
  });
  it('shows a sign glyph only from a plain resource name', () => {
    const signs = [{ id: 'ox', name: 'The Ox', image: 'birth_sign_ox.png' }, { id: 'owl', name: 'The Owl', image: 'http://example.com/x.png' }];
    const { container } = render(<CharacterSetup template="character_setup.tmpl" interactive act={vi.fn()} data={{ ...sample, tab: 'chart', chart: { ...sample.chart, signs } }} />);
    const images = container.querySelectorAll('img.setup-chart-glyph');
    expect(images.length).toBe(1);
    expect(images[0].getAttribute('src')).toBe('birth_sign_ox.png');
  });
});
