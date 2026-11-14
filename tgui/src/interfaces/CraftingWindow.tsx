import { useEffect, useMemo, useState } from 'react';
import type { Data, ScreenProps } from '../types';
import { list, text } from './common';

// The Crafting window for a held material. The server decides what a row's
// state is and rechecks everything when a craft is requested; this screen only
// filters, selects and asks. A click selects a recipe. Nothing is spent until
// the Craft button (or a double click on a ready row) sends a request.

type Row = Data & { id: string; state: 'ready' | 'missing' | 'locked' };
const GROUPS: [Row['state'], string, string][] = [
  ['ready', 'Ready', 'craft-ok'],
  ['missing', 'Missing something', 'craft-miss'],
  ['locked', 'Not learned yet', 'craft-lock'],
];

export function matches(row: Data, words: string[], purpose: string, readyOnly: boolean) {
  if (readyOnly && row.state !== 'ready') return false;
  if (purpose && text(row.purpose) !== purpose) return false;
  const hay = (text(row.name) + ' ' + text(row.category)).toLowerCase();
  return words.every(word => hay.includes(word));
}
export function seconds(deciseconds: unknown) {
  const value = Number(deciseconds) || 0;
  if (value <= 0) return 'instant';
  const whole = Math.max(1, Math.round(value / 10));
  return whole === 1 ? '1 second' : whole + ' seconds';
}
function Sprite({ image, large = false }: { image: unknown; large?: boolean }) {
  const src = typeof image === 'string' && /^craft_[0-9a-f]{32}\.png$/.test(image) ? image : '';
  const size = large ? 64 : 32;
  const name = 'craft-sprite' + (large ? ' craft-sprite-large' : '');
  return src ? <img className={name} src={src} width={size} height={size} alt="" /> : <span className={name + ' craft-sprite-empty'} aria-hidden="true" />;
}
function Need({ met, children }: { met: boolean; children: React.ReactNode }) {
  return <li className={met ? 'craft-need craft-need-ok' : 'craft-need craft-need-no'}>
    <span className="craft-mark" aria-hidden="true">{met ? '✓' : '✗'}</span>
    <span><span className="craft-sr">{met ? 'Met: ' : 'Missing: '}</span>{children}</span>
  </li>;
}

function Card({ ui, row, working }: { ui: ScreenProps; row: Row; working: Data | null }) {
  const { data } = ui;
  const batches = Math.max(0, Number(row.batches) || 0);
  const [quantity, setQuantity] = useState(1);
  useEffect(() => { setQuantity(1); }, [row.id]);
  const amount = Math.min(Math.max(1, quantity), Math.max(1, batches));
  const busy = !!working;
  const mine = busy && String(working?.id) === row.id;
  const ready = row.state === 'ready';
  const craft = () => { if (ui.interactive && ready && !busy) ui.act('make', { make: row.id, quantity: amount }); };
  return <section className="craft-card" aria-label="Selected recipe">
    <div className="craft-card-top">
      <div className="craft-pic"><Sprite image={row.image} large /></div>
      <div>
        <h2>{text(row.name)}</h2>
        {row.desc ? <p className="craft-desc">{text(row.desc)}</p> : null}
        <p className="craft-meta">{row.built ? 'Structure' : 'Item'} · takes {seconds(row.time)} · makes {text(row.makes)}</p>
      </div>
    </div>
    <h3>Needs</h3>
    <ul className="craft-needs">
      <Need met={batches > 0}>{text(row.cost)} <small>you have {text(data.amount)}</small></Need>
      {row.state === 'locked' && <Need met={false}>{text(row.why)}</Need>}
      {row.state === 'missing' && batches > 0 && <Need met={false}>{text(row.why)}</Need>}
      {row.state === 'ready' && <Need met>Everything else is in place</Need>}
    </ul>
    {row.tools ? <p className="craft-tools">Tools: {text(row.tools)}</p> : null}
    {row.built ? <p className="craft-place">Builds on the tile you stand on, facing the way you face.
      {row.one_per_turf ? ' Only one per tile.' : ''}{row.on_floor ? ' Needs a floor under you.' : ''}</p> : null}
    <p className="craft-links">
      <button type="button" className="craft-link" aria-pressed={!!row.pinned} disabled={!ui.interactive || busy} onClick={() => ui.act('pin', { pin: row.id })}>{row.pinned ? 'Unpin' : 'Pin this recipe'}</button>
      {row.atlas ? <button type="button" className="craft-link" disabled={!ui.interactive} onClick={() => ui.act('atlas', { atlas: row.id })}>Open in Atlas</button> : null}
    </p>
    {mine && <div className="craft-progress" role="status">
      <p>Making {text(working?.name)}...</p>
      <div className="craft-track"><div key={row.id} className="craft-fill" style={{ animationDuration: Math.max(0.1, (Number(working?.time) || 0) / 10) + 's' }} /></div>
      <p className="craft-hint">Moving away cancels the work.</p>
    </div>}
    <div className="craft-foot">
      {batches > 1 && <div className="craft-qty" role="group" aria-label="Quantity">
        <button type="button" aria-label="Fewer" disabled={amount <= 1 || busy} onClick={() => setQuantity(amount - 1)}>-</button>
        <output aria-live="polite">{amount * (Number(row.makes) || 1)}</output>
        <button type="button" aria-label="More" disabled={amount >= batches || busy} onClick={() => setQuantity(amount + 1)}>+</button>
        <button type="button" className="craft-max" disabled={amount >= batches || busy} onClick={() => setQuantity(batches)}>Max</button>
      </div>}
      {!ready && <span className="craft-note">{row.state === 'locked' ? 'Not learned yet' : 'Missing something'}</span>}
      <button type="button" className="craft-go" disabled={!ui.interactive || !ready || busy} onClick={craft}>{busy ? 'Working...' : 'Craft'}</button>
    </div>
  </section>;
}

export function CraftingWindow(ui: ScreenProps) {
  const { data } = ui;
  const rows = list(data.rows) as Row[];
  const working: Data | null = data.working ?? null;
  const [query, setQuery] = useState('');
  const [purpose, setPurpose] = useState('');
  const [readyOnly, setReadyOnly] = useState(!!data.makeable_only);
  const [selected, setSelected] = useState('');
  const [showLocked, setShowLocked] = useState(false);
  // Pictures arrive a batch at a time; ask for the next batch once per snapshot.
  useEffect(() => {
    if (data.more_images && !data.working && ui.interactive) ui.act('images', { images: 1 });
  }, [data]);
  const words = useMemo(() => query.toLowerCase().trim().split(/\s+/).filter(Boolean).slice(0, 6), [query]);
  const visible = useMemo(() => rows.filter(row => matches(row, words, words.length ? '' : purpose, readyOnly)), [rows, words, purpose, readyOnly]);
  // Tabs come from what this material can make, in the server's fixed order.
  const tabs = useMemo(() => list(data.purposes).map(name => text(name))
    .map(name => [name, rows.filter(row => text(row.purpose) === name).length] as [string, number]).filter(tab => tab[1] > 0), [rows, data.purposes]);
  const active = words.length ? '' : purpose;
  const recent = useMemo(() => rows.filter(row => Number(row.recent) > 0).sort((a, b) => Number(a.recent) - Number(b.recent)).slice(0, 6), [rows]);
  const pinned = useMemo(() => rows.filter(row => !!row.pinned), [rows]);
  const chip = (row: Row) => <button key={row.id} type="button" className={'craft-chip' + (row.id === selected ? ' craft-chip-selected' : '')}
    title={text(row.name)} onClick={() => setSelected(row.id)}><Sprite image={row.image} /><span>{text(row.name)}</span></button>;
  const chosen = rows.find(row => row.id === selected) ?? null;
  const toggleReady = (next: boolean) => { setReadyOnly(next); ui.act('makeable_only', { makeable_only: next ? 1 : 0 }); };
  const quick = (row: Row) => { if (ui.interactive && row.state === 'ready' && !working) ui.act('make', { make: row.id, quantity: 1 }); };
  return <div className="craft">
    <div className="craft-head">
      <Sprite image={data.image} />
      <h2>{text(data.material)}</h2>
      <span className="craft-amount">{text(data.amount)} in your hand</span>
    </div>
    <div className="craft-columns">
      <div className="craft-left">
        <div className="craft-tools-bar">
          <input type="search" aria-label="Search recipes" placeholder="Search recipes..." maxLength={64} value={query}
            onChange={event => setQuery(event.target.value)}
            onKeyDown={event => { if (event.key === 'Enter') event.preventDefault(); if (event.key === 'Escape') setQuery(''); }} />
          <label className="craft-tick"><input type="checkbox" checked={readyOnly} disabled={!ui.interactive} onChange={event => toggleReady(event.target.checked)} /> Only what I can make</label>
        </div>
        {tabs.length > 1 && <div className="craft-tabs" role="tablist" aria-label="What it is for">
          {[['', rows.length] as [string, number], ...tabs].map(([name, count]) => <button key={name || 'all'} type="button" role="tab" aria-selected={active === name}
            className={'craft-tab' + (active === name ? ' craft-tab-on' : '')} onClick={() => { setQuery(''); setPurpose(name); }}>{name || 'All'} <small>{count}</small></button>)}
        </div>}
        {(recent.length > 0 || pinned.length > 0) && <div className="craft-strip">
          {recent.length > 0 && <div className="craft-strip-row" role="group" aria-label="Recent"><span className="craft-strip-label">Recent</span>{recent.map(chip)}</div>}
          {pinned.length > 0 && <div className="craft-strip-row" role="group" aria-label="Pinned"><span className="craft-strip-label">Pinned</span>{pinned.map(chip)}</div>}
        </div>}
        <div className="craft-list">
          {GROUPS.map(([state, title, tone]) => {
            const group = visible.filter(row => row.state === state);
            if (readyOnly && state !== 'ready') return null;
            // The old categories stay as sub-headings wherever a group mixes several.
            const mixed = new Set(group.map(row => text(row.category))).size > 1;
            const folded = state === 'locked' && !showLocked && !words.length && group.length > 0;
            return <div key={state} className="craft-group">
              <h3 className={tone}>{title} <small>{group.length} {group.length === 1 ? 'recipe' : 'recipes'}</small>
                {state === 'locked' && group.length > 0 && !words.length && <button type="button" className="craft-link" onClick={() => setShowLocked(!showLocked)}>{showLocked ? 'Hide' : 'Show'}</button>}</h3>
              {!folded && <ul>{group.map((row, i) => <li key={row.id}>
                {mixed && (i === 0 || text(group[i - 1].category) !== text(row.category)) && <h4 className="craft-sub">{text(row.category)}</h4>}
                <button type="button" className={'craft-row craft-row-' + row.state + (row.id === selected ? ' craft-row-selected' : '')}
                  aria-pressed={row.id === selected} onClick={() => setSelected(row.id)} onDoubleClick={() => quick(row)}>
                  <Sprite image={row.image} />
                  <span className="craft-row-text"><strong>{text(row.name)}</strong>{row.state !== 'ready' && <small>{text(row.why)}</small>}</span>
                  <span className="craft-cost">{text(row.cost)}</span>
                </button>
              </li>)}</ul>}
            </div>;
          })}
          {visible.length === 0 && <p className="craft-empty">No matching recipes. Try another name, another tab or untick Only what I can make.</p>}
        </div>
      </div>
      <div className="craft-right">
        {chosen ? <Card ui={ui} row={chosen} working={working} />
          : <section className="craft-card craft-card-empty"><p>Pick a recipe to see what it needs. Nothing is spent until you press Craft.</p>
            <p className="craft-hint">Double-click a ready recipe to make one straight away.</p>
            {working && <p role="status">Making {text(working.name)}...</p>}</section>}
      </div>
    </div>
  </div>;
}
