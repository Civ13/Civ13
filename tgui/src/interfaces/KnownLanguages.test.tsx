import React from 'react';
import { afterEach, expect, it, vi } from 'vitest';
import { cleanup, screen } from '@testing-library/react';
import { render } from '../testing';
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

it('shows each language family with its daughters, the player\'s own languages and how close they are', () => {
  const ui = props({ current_default: 'Gallic', languages: [{ name: 'Gallic', prefix: ':ga', description: 'Mother tongue. Grew out of Latin.', is_default: 1 }, { name: 'Latin', prefix: ':l', description: 'Fluent.' }],
    families: [{ root: 'Latin', members: [
      { name: 'Latin', depth: 0, known: 1 },
      { name: 'Gallic', parent: 'Latin', nation: 'Franks &amp; Friends', era: 'Medieval Age', depth: 1, known: 1, mother: 1 },
      { name: 'Iberic', parent: 'Latin', nation: 'Iberians', era: 'Imperial Age', depth: 1 },
      { name: 'Lusic', parent: 'Iberic', nation: 'Lusians', era: 'Industrial Age', depth: 2, learning: 1 }],
    links: [{ a: 'Latin', b: 'Gallic', percent: 80 }, { a: 'Gallic', b: 'Iberic', percent: 60 }, { a: 'Gallic', b: 'Lusic', percent: 30 }, { a: 'Latin', b: 'Lusic', percent: 10 }] }] });
  render(<KnownLanguages {...ui} />);
  const tree = screen.getByRole('list', { name: 'Latin family' });
  const rows = Array.from(tree.querySelectorAll('li')).map(row => row.textContent);
  expect(rows).toHaveLength(4);
  expect(rows[0]).toContain('Latin You speak it - the old language');
  expect(rows[1]).toContain('Gallic Mother tongue - grew out of Latin among the Franks & Friends (Medieval Age)');
  expect(rows[2]).toContain('Iberic - grew out of Latin among the Iberians (Imperial Age)');
  expect(rows[2]).not.toMatch(/You speak it|Mother tongue|Learning/);
  expect(rows[3]).toContain('Lusic Learning - grew out of Iberic among the Lusians (Industrial Age)');
  expect(Array.from(tree.querySelectorAll('li')).map(row => (row as HTMLElement).style.paddingLeft)).toEqual(['0px', '20px', '20px', '40px']);
  const links = screen.getByRole('list', { name: 'How close the Latin family is' }).textContent;
  expect(links).toContain('Latin and Gallic speakers follow about 80% of each other - most of what is said.');
  expect(links).toContain('Gallic and Iberic speakers follow about 60% of each other - more than half.');
  expect(links).toContain('Gallic and Lusic speakers follow about 30% of each other - some of it.');
  expect(links).toContain('Latin and Lusic speakers follow about 10% of each other - only a little.');
  expect(document.body.textContent).not.toMatch(/drift|\u2014/i);
  expect(screen.queryAllByRole('button')).toHaveLength(0);
  expect(ui.act).not.toHaveBeenCalled();
});

it('shows no family block when no language of the player has relatives on this world', () => {
  render(<KnownLanguages {...props({ languages: [{ name: 'Common', prefix: ':c', description: 'A shared language.' }], families: [{ root: 'Common', members: [{ name: 'Common', depth: 0, known: 1 }], links: [] }] })} />);
  expect(screen.queryByText('Language families')).toBeNull();
  cleanup();
  render(<KnownLanguages {...props({ languages: [{ name: 'Common', prefix: ':c', description: 'A shared language.' }] })} />);
  expect(screen.queryByText('Language families')).toBeNull();
});

const saltmarsh = () => ({ name: 'Saltmarsh Kin', language: 'Latin', land: 'the Saltmarsh', lineage: [
  { name: 'Hearthlanders', language: 'Latin', formed: 0, year: 0, nation: '', homeland: '', parents: [] },
  { name: 'Saltmarsh Kin', language: 'Latin', formed: 1, year: 58800, nation: 'Iron Pact', homeland: 'the Saltmarsh', parents: ['Hearthlanders'] }],
kin: [{ name: 'Tidewater Folk', language: 'Latin', formed: 1, year: 58790, nation: '', homeland: 'the Tidewater', parents: ['Hearthlanders'], relation: 'shares your roots' },
  { name: 'Reed Children', language: 'Latin', formed: 1, year: 0, nation: '', homeland: '', parents: ['Saltmarsh Kin', 'Fjordfolk'], relation: 'grew from yours' }],
raised_among: ['Fjordfolk'], welcomed_by: [] as string[] });

it('shows the player\'s people with its lineage, related peoples and who raised them, without actions', () => {
  const ui = props({ languages: [{ name: 'Latin', prefix: ':l', description: 'Mother tongue.' }], people: saltmarsh() });
  const view = render(<KnownLanguages {...ui} />);
  expect(screen.getByText('Your people', { selector: 'h2' })).toBeTruthy();
  expect(view.container.textContent).toContain('Saltmarsh Kin - mother tongue Latin - born in the Saltmarsh');
  const chain = Array.from(screen.getByRole('list', { name: 'Where the Saltmarsh Kin came from' }).querySelectorAll('li'));
  expect(chain.map(row => row.textContent)).toEqual(['Hearthlanders - an old people', '└ Saltmarsh Kin Your people - formed in year 58800 among the Iron Pact']);
  expect(chain.map(row => (row as HTMLElement).style.paddingLeft)).toEqual(['0px', '20px']);
  expect(chain.map(row => row.className)).toEqual(['', 'lang-own']);
  const kin = Array.from(screen.getByRole('list', { name: 'Related peoples' }).querySelectorAll('li')).map(row => row.textContent);
  expect(kin).toEqual(['Tidewater Folk - shares your roots, formed in year 58790 in the Tidewater.', 'Reed Children - grew from yours, formed, a blend of Saltmarsh Kin and Fjordfolk.']);
  expect(screen.getByText('Raised among: Fjordfolk')).toBeTruthy();
  expect(screen.queryByText('Welcomed by:', { exact: false })).toBeNull();
  expect(document.body.textContent).not.toMatch(/skin|members|\u2014/i);
  expect(screen.queryAllByRole('button')).toHaveLength(0);
  expect(ui.act).not.toHaveBeenCalled();
});

it('shows the welcomed line only when it has names and no chain for an old people on its own', () => {
  render(<KnownLanguages {...props({ languages: [], people: { name: 'Hearthlanders', language: 'Latin', land: '', lineage: [{ name: 'Hearthlanders', language: 'Latin', formed: 0, year: 0, parents: [] }], kin: [], raised_among: [], welcomed_by: ['Fjordfolk', 'Iron Kin', 'Reed Children'] } })} />);
  expect(screen.getByText('Welcomed by: Fjordfolk, Iron Kin and Reed Children')).toBeTruthy();
  expect(screen.queryByText('Raised among:', { exact: false })).toBeNull();
  expect(screen.queryByText('born in', { exact: false })).toBeNull();
  expect(screen.queryAllByRole('list', { name: /came from|Related peoples/ })).toHaveLength(0);
});

it('shows no people block when the viewer has no people', () => {
  render(<KnownLanguages {...props({ languages: [{ name: 'Common', prefix: ':c', description: 'A shared language.' }], people: null })} />);
  expect(screen.queryByText('Your people')).toBeNull();
  cleanup();
  render(<KnownLanguages {...props({ languages: [{ name: 'Common', prefix: ':c', description: 'A shared language.' }] })} />);
  expect(screen.queryByText('Your people')).toBeNull();
});

it('renders entity-encoded people names once, as inert text', () => {
  const people = saltmarsh();
  people.name = 'Salt &amp; Marsh &lt;b&gt;Kin&lt;/b&gt;'; people.land = 'Reed &amp;amp; Fen';
  people.lineage[1].name = people.name; people.lineage[1].nation = 'Iron &amp; Pact';
  people.kin[0].name = '&lt;img src=x onerror=alert(1)&gt;'; people.raised_among = ['Fjord &amp; folk'];
  const view = render(<KnownLanguages {...props({ languages: [], people })} />);
  const shown = view.container.textContent;
  expect(shown).toContain('Salt & Marsh <b>Kin</b> - mother tongue Latin - born in Reed &amp; Fen');
  expect(shown).toContain('among the Iron & Pact');
  expect(shown).toContain('<img src=x onerror=alert(1)> - shares your roots');
  expect(shown).toContain('Raised among: Fjord & folk');
  expect(view.container.querySelector('img,b,script')).toBeNull();
});
