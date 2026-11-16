import { useEffect, useRef, useState } from 'react';
import { NoticeBox, Section } from 'tgui-core/components';
import type { SpawnMenuData } from '../data';
import type { ScreenProps } from '../types';
import { Action, list, str } from './common';
import { Choice, Pill, SnapshotTable } from './kit';

// The admin Spawn picker. The server keeps the type list and searches it; this
// screen sends the typed words a moment after typing stops and shows the best
// matches it gets back. An empty search lists this admin's recent spawns.
export const SEARCH_DELAY = 250;
const kinds: [string, string][] = [['all', 'All'], ['obj', 'Objects'], ['mob', 'Mobs'], ['turf', 'Turfs'], ['area', 'Areas']];
export function SpawnMenu(ui: ScreenProps<SpawnMenuData>) {
  const { data } = ui;
  const [typed, setTyped] = useState(str(data.query));
  const [amount, setAmount] = useState('1');
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const sent = useRef(str(data.query));
  useEffect(() => () => { if (timer.current) clearTimeout(timer.current); }, []);
  const send = (value: string) => {
    if (timer.current) clearTimeout(timer.current);
    timer.current = undefined;
    if (value.trim() === sent.current.trim()) return;
    sent.current = value;
    ui.act('search', { value });
  };
  const type = (value: string) => {
    setTyped(value);
    if (timer.current) clearTimeout(timer.current);
    timer.current = setTimeout(() => send(value), SEARCH_DELAY);
  };
  const max = Number(data.max_amount) || 50;
  const count = Math.min(max, Math.max(1, Math.round(Number(amount)) || 1));
  const results = list(data.results);
  const query = str(data.query).trim();
  const matches = Number(data.matches) || 0;
  const searching = typed.trim() !== query;
  const summary = !query ? (results.length ? 'Recently spawned' : '')
    : matches > results.length ? `Best ${results.length} of ${matches} matches` : `${matches} ${matches === 1 ? 'match' : 'matches'}`;
  return <Section>
    <div className="spawn-bar">
      <input type="search" className="spawn-search" aria-label="Search types" placeholder="Search by path or name, e.g. rifle or /obj/item/stack"
        maxLength={100} autoFocus value={typed} disabled={!ui.interactive}
        onChange={event => type(event.target.value)} onKeyDown={event => { if (event.key === 'Enter') send(typed); }} />
      <label className="spawn-amount">Amount <input type="text" inputMode="numeric" maxLength={3} value={amount} disabled={!ui.interactive}
        onChange={event => setAmount(event.target.value)} /></label>
    </div>
    <div className="spawn-bar">
      <Choice ui={ui} action="kind" value={str(data.kind) || 'all'} options={kinds} label="Type of atom" />
      {searching ? <Pill tone="progress">Searching...</Pill> : summary ? <Pill>{summary}</Pill> : null}
    </div>
    {data.last ? <p className="kit-hint">Last spawned: {str(data.last)}</p> : null}
    {!query && !results.length
      ? <NoticeBox>Type part of a type path or name to search {Number(data.types) || 0} types. Words narrow the search: "steel sheet" finds paths and names with both.</NoticeBox>
      : <SnapshotTable label="Matching types" rows={results} empty="No type matches that search." columns={[
        { label: 'Name', cell: row => str(row.name) || '-' },
        { label: 'Path', cell: row => <code className="spawn-path">{str(row.path)}</code> },
        { label: '', align: 'right', cell: row => <Action ui={ui} action="spawn" value={str(row.path)} params={{ amount: count }}>
          {str(row.kind) === 'turf' ? 'Place' : count > 1 ? `Spawn ${count}` : 'Spawn'}</Action> },
      ]} />}
  </Section>;
}
