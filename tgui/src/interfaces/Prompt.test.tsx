import React from 'react';
import { afterEach, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';
vi.mock('tgui-core/components', () => ({
  Button: ({ children, onClick, disabled }: any) => <button disabled={disabled} onClick={onClick}>{children}</button>,
  Section: ({ children }: any) => <section>{children}</section>,
}));
import { Prompt } from './Prompt';
import { interfaces } from './index';
const props = (data: Record<string, unknown>, interactive = true) => ({ template: 'prompt.tmpl', interactive, act: vi.fn(), data });
afterEach(cleanup);

it('is registered for the prompt template', () => {
  expect(interfaces['prompt.tmpl']).toBe(Prompt);
});

it('shows the notice and answers with the 1-based index of the choice', () => {
  const ui = props({ message: 'You feel rested.', choices: ['Continue'] });
  render(<Prompt {...ui} />);
  expect(screen.getByText('You feel rested.')).toBeTruthy();
  fireEvent.click(screen.getByText('Continue'));
  expect(ui.act).toHaveBeenCalledWith('answer', { answer: 1 });
});

it('maps each choice to its own index', () => {
  const ui = props({ message: 'Pick one', choices: ['Yes', 'No'] });
  render(<Prompt {...ui} />);
  fireEvent.click(screen.getByText('No'));
  expect(ui.act).toHaveBeenLastCalledWith('answer', { answer: 2 });
});

it('disables answers when the window is not interactive', () => {
  const ui = props({ message: 'Read only', choices: ['Continue'] }, false);
  render(<Prompt {...ui} />);
  const button = screen.getByText('Continue') as HTMLButtonElement;
  expect(button.disabled).toBe(true);
});

it('renders entity-encoded server text as inert text, keeping line breaks', () => {
  const view = render(<Prompt {...props({ message: 'Line one\n&lt;img src=x onerror=alert(1)&gt;', choices: ['&lt;b&gt;OK&lt;/b&gt;'] })} />);
  expect(view.container.textContent).toContain('<img src=x onerror=alert(1)>');
  expect(view.container.querySelector('.civ13-prompt-message')?.textContent).toContain('Line one\n');
  expect(screen.getByText('<b>OK</b>')).toBeTruthy();
  expect(view.container.querySelector('img,b,script')).toBeNull();
});

it('tolerates missing data before the first snapshot', () => {
  const view = render(<Prompt {...props({})} />);
  expect(view.container.querySelectorAll('button')).toHaveLength(0);
});
