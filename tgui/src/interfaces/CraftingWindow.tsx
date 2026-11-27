import { useEffect, useMemo, useState } from 'react';
import type { Data, ScreenProps } from '../types';
import { list, str } from './common';

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
  if (purpose && str(row.purpose) !== purpose) return false;
  const hay = (str(row.name) + ' ' + str(row.category)).toLowerCase();
  return words.every(word => hay.includes(word));
}
export function seconds(deciseconds: unknown) {
  const value = Number(deciseconds) || 0;
  if (value <= 0) return 'instant';
  const whole = Math.max(1, Math.round(value / 10));
  return whole === 1 ? '1 second' : whole + ' seconds';
}
// What each choice starts as: the game's default, a valid colour, or the first company.
export function startingAnswers(fields: Data[]) {
  const start: Record<string, string> = {};
  for (const field of fields) {
    const given = str(field.default);
    if (field.kind === 'color') start[str(field.field)] = /^#[0-9a-fA-F]{6}$/.test(given) ? given.toLowerCase() : '#000000';
    else if (field.kind === 'company') start[str(field.field)] = str(list(field.choices)[0] ?? '');
    else start[str(field.field)] = given;
  }
  return start;
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

// Work done in the world rather than from this menu: a tool used on the
// material, a station it goes into. The card says how and whether the player
// has the tool; there is no Craft button because the game does it on use.
export function processMatches(row: Data, words: string[], readyOnly: boolean) {
  if (readyOnly && row.state !== 'ready') return false;
  const hay = (str(row.name) + ' ' + list(row.makes).map(str).join(' ') + ' ' + list(row.tools).map(tool => str(tool.name)).join(' ')).toLowerCase();
  return words.every(word => hay.includes(word));
}
function ProcessCard({ ui, row, material }: { ui: ScreenProps; row: Data; material: string }) {
  const tools = list(row.tools);
  return <section className="craft-card" aria-label="Selected process">
    <div className="craft-card-top">
      <div className="craft-pic"><Sprite image={row.image} large /></div>
      <div>
        <h2>{str(row.name)}</h2>
        <p className="craft-meta">Makes {list(row.makes).map(str).join(', ') || 'something new'}</p>
      </div>
    </div>
    {tools.length > 0 && <>
      <h3>Tools</h3>
      <ul className="craft-needs">
        {tools.map((tool, i) => Number(tool.have) < 0
          ? <li key={i} className="craft-need"><span className="craft-mark" aria-hidden="true">•</span><span>{str(tool.name)}</span></li>
          : <Need key={i} met={Number(tool.have) > 0}>{str(tool.name)}{Number(tool.have) > 0 && tool.found ? <small> - {str(tool.found)}</small> : null}</Need>)}
      </ul>
    </>}
    <h3>How</h3>
    <ul className="craft-steps">{list(row.steps).map((step, i) => <li key={i}>{str(step)}</li>)}</ul>
    <p className="craft-place">Not made from this menu: do it in the world with the {str(material) || 'material'} and the tool.</p>
    {row.atlas ? <p className="craft-links"><button type="button" className="craft-link" disabled={!ui.interactive} onClick={() => ui.act('process_atlas', { value: str(row.id) })}>Open in Atlas</button></p> : null}
  </section>;
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
  // The server looks closely at the selected recipe only: exact unmet
  // requirements, and the choices it would otherwise ask in pop-ups.
  const detail: Data | null = data.detail && str(data.detail.id) === row.id ? data.detail : null;
  const needs = list(detail?.needs);
  const fields = list(detail?.fields);
  const [answers, setAnswers] = useState<Record<string, string>>({});
  useEffect(() => { setAnswers(startingAnswers(fields)); }, [row.id, fields.map(field => str(field.field) + str(field.default)).join('|')]);
  const answer = (field: Data) => answers[str(field.field)] ?? '';
  const set = (field: Data, value: string) => setAnswers({ ...answers, [str(field.field)]: value });
  const unanswered = fields.some(field => (field.kind === 'company' || !!field.required) && !answer(field).trim());
  const craft = () => {
    if (!ui.interactive || !ready || busy || unanswered) return;
    if (fields.length) ui.act('make', { value: row.id, quantity: amount, options: JSON.stringify(Object.fromEntries(fields.map(field => [str(field.field), answer(field)]))) });
    else ui.act('make', { value: row.id, quantity: amount });
  };
  return <section className="craft-card" aria-label="Selected recipe">
    <div className="craft-card-top">
      <div className="craft-pic"><Sprite image={row.image} large /></div>
      <div>
        <h2>{str(row.name)}</h2>
        {row.desc ? <p className="craft-desc">{str(row.desc)}</p> : null}
        <p className="craft-meta">{row.built ? 'Structure' : 'Item'} · takes {seconds(row.time)} · makes {str(row.makes)}</p>
      </div>
    </div>
    <h3>Needs</h3>
    <ul className="craft-needs">
      <Need met={batches > 0}>{str(row.cost)} <small>{data.where && str(data.where) !== 'in your hand' ? str(data.where) + ': ' : 'you have '}{str(data.amount)}</small></Need>
      {row.state === 'locked' && <Need met={false}>{str(row.why)}</Need>}
      {needs.map((need, i) => <Need key={i} met={!!need.met}>{str(need.label)}</Need>)}
      {row.state === 'missing' && batches > 0 && !needs.some(need => !need.met) && <Need met={false}>{str(row.why)}</Need>}
      {row.state === 'ready' && !needs.some(need => !need.met) && <Need met>Everything else is in place</Need>}
    </ul>
    {fields.length > 0 && <div className="craft-fields" role="group" aria-label="Choices">
      <h3>Choices</h3>
      {fields.map((field, i) => <label key={i} className="craft-field"><span>{str(field.question).replace(/:\s*$/, '')}{field.required || field.kind === 'company' ? ' (needed)' : ''}</span>
        {field.kind === 'color' ? <input type="color" disabled={busy} value={answer(field) || '#000000'} onChange={event => set(field, event.target.value)} />
          : field.kind === 'company' ? (list(field.choices).length
            ? <select disabled={busy} value={answer(field)} onChange={event => set(field, event.target.value)}>{list(field.choices).map((name, j) => <option key={j} value={str(name)}>{str(name)}</option>)}</select>
            : <em className="craft-note">You are not part of any company.</em>)
          : <input type="text" disabled={busy} maxLength={Math.min(1024, Number(field.max_length) || 256)} value={answer(field)} onChange={event => set(field, event.target.value)}
              onKeyDown={event => { if (event.key === 'Enter') event.preventDefault(); }} />}
      </label>)}
    </div>}
    {row.tools ? <p className="craft-tools">Tools: {str(row.tools)}</p> : null}
    {row.built ? <p className="craft-place">Builds on the tile you stand on, facing the way you face.
      {row.one_per_turf ? ' Only one per tile.' : ''}{row.on_floor ? ' Needs a floor under you.' : ''}</p> : null}
    <p className="craft-links">
      <button type="button" className="craft-link" aria-pressed={!!row.pinned} disabled={!ui.interactive || busy} onClick={() => ui.act('pin', { value: row.id })}>{row.pinned ? 'Unpin' : 'Pin this recipe'}</button>
      {row.atlas ? <button type="button" className="craft-link" disabled={!ui.interactive} onClick={() => ui.act('atlas', { value: row.id })}>Open in Atlas</button> : null}
      {row.state === 'locked' && row.tech_tree ? <button type="button" className="craft-link" disabled={!ui.interactive} onClick={() => ui.act('tech_tree', { value: row.id })}>View in tech tree</button> : null}
    </p>
    {mine && <div className="craft-progress" role="status">
      <p>Making {str(working?.name)}...</p>
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
      <button type="button" className="craft-go" disabled={!ui.interactive || !ready || busy || unanswered} onClick={craft}>{busy ? 'Working...' : 'Craft'}</button>
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
  const chosen = rows.find(row => row.id === selected) ?? null;
  // The Atlas can hand over a recipe: show it whatever tab or search was left open.
  useEffect(() => {
    const focus = str(data.focus);
    if (!focus || !rows.some(row => row.id === focus)) return;
    setSelected(focus); setQuery(''); setPurpose('');
    if (rows.find(row => row.id === focus)?.state === 'locked') setShowLocked(true);
  }, [data.focus_seq]);
  // A valid selection can change while the server declines requests during work.
  // Watch the eligible recipe rather than the whole snapshot to avoid duplicate requests.
  const detailRequest = ui.interactive && !working && chosen && data.detail?.id !== chosen.id ? chosen.id : '';
  useEffect(() => {
    if (detailRequest) ui.act('detail', { value: detailRequest });
  }, [detailRequest]);
  // Pictures arrive a batch at a time; ask for the next batch once per snapshot.
  useEffect(() => {
    if (data.more_images && !data.working && ui.interactive) ui.act('images');
  }, [data]);
  const words = useMemo(() => query.toLowerCase().trim().split(/\s+/).filter(Boolean).slice(0, 6), [query]);
  const visible = useMemo(() => rows.filter(row => matches(row, words, words.length ? '' : purpose, readyOnly)), [rows, words, purpose, readyOnly]);
  // Tabs come from what this material can make, in the server's fixed order.
  const tabs = useMemo(() => list(data.purposes).map(name => str(name))
    .map(name => [name, rows.filter(row => str(row.purpose) === name).length] as [string, number]).filter(tab => tab[1] > 0), [rows, data.purposes]);
  const active = words.length ? '' : purpose;
  const recent = useMemo(() => rows.filter(row => Number(row.recent) > 0).sort((a, b) => Number(a.recent) - Number(b.recent)).slice(0, 6), [rows]);
  const pinned = useMemo(() => rows.filter(row => !!row.pinned), [rows]);
  const chip = (row: Row) => <button key={row.id} type="button" className={'craft-chip' + (row.id === selected ? ' craft-chip-selected' : '')}
    title={str(row.name)} onClick={() => setSelected(row.id)}><Sprite image={row.image} /><span>{str(row.name)}</span></button>;
  const processing = list(data.processing);
  const shownProcesses = useMemo(() => processing.filter(row => processMatches(row, words, readyOnly)), [data.processing, words, readyOnly]);
  const process = chosen ? null : processing.find(row => str(row.id) === selected) ?? null;
  const moreProcesses = Math.max(0, (Number(data.processing_total) || 0) - processing.length);
  const toggleReady = (next: boolean) => { setReadyOnly(next); ui.act('makeable_only', { value: next ? 1 : 0 }); };
  const quick = (row: Row) => { if (ui.interactive && row.state === 'ready' && !working) ui.act('make', { value: row.id, quantity: 1 }); };
  return <div className="craft">
    <div className="craft-head">
      <Sprite image={data.image} />
      <h2>{str(data.material)}</h2>
      <span className="craft-amount">{str(data.amount)} {str(data.where) || 'in your hand'}</span>
      {data.station ? <span className="craft-station">At the {str(data.station)}</span> : null}
    </div>
    {!!data.reach && list(data.sources).length > 1 && <div className="craft-reach" role="group" aria-label="Materials within reach">
      <span className="craft-strip-label">In reach</span>
      {list(data.sources).map((source, i) => <button key={i} type="button" className={'craft-chip' + (source.current ? ' craft-chip-selected' : '')} aria-pressed={!!source.current}
        disabled={!ui.interactive || !!working} onClick={() => { if (!source.current) ui.act('source', { value: str(source.key) }); }}>
        <Sprite image={source.image} /><span>{str(source.name)}</span><small>{str(source.amount)} {str(source.where)}</small></button>)}
    </div>}
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
            // A material with no menu recipes, only tool work, skips the empty headings.
            if (!rows.length && processing.length) return null;
            // The old categories stay as sub-headings wherever a group mixes several.
            const mixed = new Set(group.map(row => str(row.category))).size > 1;
            const folded = state === 'locked' && !showLocked && !words.length && group.length > 0;
            return <div key={state} className="craft-group">
              <h3 className={tone}>{title} <small>{group.length} {group.length === 1 ? 'recipe' : 'recipes'}</small>
                {state === 'locked' && group.length > 0 && !words.length && <button type="button" className="craft-link" onClick={() => setShowLocked(!showLocked)}>{showLocked ? 'Hide' : 'Show'}</button>}</h3>
              {!folded && <ul>{group.map((row, i) => <li key={row.id}>
                {mixed && (i === 0 || str(group[i - 1].category) !== str(row.category)) && <h4 className="craft-sub">{str(row.category)}</h4>}
                <button type="button" className={'craft-row craft-row-' + row.state + (row.id === selected ? ' craft-row-selected' : '')}
                  aria-pressed={row.id === selected} onClick={() => setSelected(row.id)} onDoubleClick={() => quick(row)}>
                  <Sprite image={row.image} />
                  <span className="craft-row-text"><strong>{str(row.name)}</strong>{row.state !== 'ready' && <small>{str(row.why)}</small>}</span>
                  <span className="craft-cost">{str(row.cost)}</span>
                </button>
              </li>)}</ul>}
            </div>;
          })}
          {shownProcesses.length > 0 && <div className="craft-group">
            <h3 className="craft-process">Use a tool or station on it <small>{shownProcesses.length} {shownProcesses.length === 1 ? 'way' : 'ways'}</small></h3>
            <ul>{shownProcesses.map(row => <li key={str(row.id)}>
              <button type="button" className={'craft-row craft-row-' + str(row.state) + (str(row.id) === selected ? ' craft-row-selected' : '')}
                aria-pressed={str(row.id) === selected} onClick={() => setSelected(str(row.id))}>
                <Sprite image={row.image} />
                <span className="craft-row-text"><strong>{str(row.name)}</strong>
                  <small className="craft-row-tools">{list(row.tools).map(tool => (Number(tool.have) === 0 ? 'needs ' : '') + str(tool.name)).join(', ')}</small></span>
              </button>
            </li>)}</ul>
            {moreProcesses > 0 && !words.length && <p className="craft-hint">{moreProcesses} more in the Atlas.</p>}
          </div>}
          {visible.length === 0 && shownProcesses.length === 0 && <p className="craft-empty">No matching recipes. Try another name, another tab or untick Only what I can make.</p>}
        </div>
      </div>
      <div className="craft-right">
        {chosen ? <Card ui={ui} row={chosen} working={working} />
          : process ? <ProcessCard ui={ui} row={process} material={str(data.material)} />
          : <section className="craft-card craft-card-empty"><p>Pick a recipe to see what it needs. Nothing is spent until you press Craft.</p>
            <p className="craft-hint">Double-click a ready recipe to make one straight away.</p>
            {working && <p role="status">Making {str(working.name)}...</p>}</section>}
      </div>
    </div>
  </div>;
}
