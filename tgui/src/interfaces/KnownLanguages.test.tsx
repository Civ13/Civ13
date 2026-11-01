import React from 'react';
import { afterEach, expect, it, vi } from 'vitest';
import { cleanup, render, screen } from '@testing-library/react';
vi.mock('tgui-core/components', () => ({
  Section: ({ children, title }: any) => <section><h2>{title}</h2>{children}</section>,
  NoticeBox: ({ children }: any) => <aside>{children}</aside>,
}));
import { KnownLanguages } from './KnownLanguages';
const props = (data: Record<string, unknown>) => ({ template: 'known_languages.tmpl', interactive: false, act: vi.fn(), data });
afterEach(cleanup);

it('shows known-language descriptions, prefixes and one explicit default marker without actions', () => {
  const ui = props({ current_default: 'Common', languages: [
    { name: 'Common', prefix: ':c', description: 'A shared language.', is_default: 1 },
    { name: 'Español', prefix: ':s', description: 'Una lengua conocida.', is_default: 0 },
  ] });
  render(<KnownLanguages {...ui} />);
  expect(screen.getByText('Common (:c)')).toBeTruthy();
  expect(screen.getByText('Una lengua conocida.')).toBeTruthy();
  expect(screen.getAllByRole('listitem').filter(item => item.getAttribute('aria-current') === 'true')).toHaveLength(1);
  expect(screen.queryAllByRole('button')).toHaveLength(0);
  expect(ui.act).not.toHaveBeenCalled();
});

it('handles an empty list for observers/nonliving owners without a default', () => {
  render(<KnownLanguages {...props({ languages: [], current_default: '' })} />);
  expect(screen.getByText('No known languages are available.')).toBeTruthy();
  expect(screen.queryByText('Current default language:', { exact: false })).toBeNull();
});

it('renders entity-encoded names and descriptions as inert text', () => {
  const view = render(<KnownLanguages {...props({ languages: [{ name: '&lt;img src=x onerror=alert(1)&gt;', prefix: ':&lt;', description: '&lt;script&gt;alert(1)&lt;/script&gt;' }] })} />);
  expect(view.container.textContent).toContain('<img src=x onerror=alert(1)>');
  expect(view.container.textContent).toContain('<script>alert(1)</script>');
  expect(view.container.querySelector('img,script')).toBeNull();
});
