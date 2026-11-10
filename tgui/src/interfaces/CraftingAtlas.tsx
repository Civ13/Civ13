import { useEffect, useState } from 'react';
import { NoticeBox } from 'tgui-core/components';
import type { Data, ScreenProps } from '../types';
import { list, text } from './common';

type Navigation = { route: 'open' | 'page' | 'resource' | 'reset'; query?: string; era?: string; processor?: string; recipe?: string; page?: number; resource?: string; scope?: string };
// The server accepts one atlas request per second per reader and drops the rest.
// Send at once when possible; otherwise deliver only the latest click when the window reopens.
const REQUEST_GAP = 1100;
let lastSent = -REQUEST_GAP, queued: ReturnType<typeof setTimeout> | undefined;
export const resetAtlasRequests = () => { lastSent = -REQUEST_GAP; if (queued) clearTimeout(queued); queued = undefined; };
const navigate = (ui: ScreenProps, params: Navigation) => {
  if (!ui.interactive) return;
  const send = () => { queued = undefined; lastSent = Date.now(); ui.act('atlas_navigate', { atlas_navigate: JSON.stringify(params) }); };
  if (queued) clearTimeout(queued);
  const wait = lastSent + REQUEST_GAP - Date.now();
  if (wait <= 0) send(); else queued = setTimeout(send, wait);
};
const eras = ['Stone Age', 'Bronze Age', 'Middle Ages', 'Imperial Age', 'Industrial Age', 'Early Modern Age', 'WW2', 'Cold War', 'Modern Age', 'Digital Age'];
const eraName = (label: unknown) => text(label).replace(/(^|\/ )\d+: /g, '$1').replace(/^Unknown \/ context dependent$/, '');
// How a recipe is carried out, in the player's terms. Unknown kinds keep their catalog label.
const methods: Record<string, [string, string]> = {
  'Material': ['Crafting menu', 'Hold the material and use it in your hand to open its crafting menu.'],
  'Native stack': ['Crafting menu', 'Hold the material and use it in your hand to open its crafting menu.'],
  'Anvil': ['Anvil', 'Use the heated metal on an anvil and pick the item.'],
  'Chemistry': ['Mixing', 'Combine the reagents in one container.'],
  'Cooking': ['Boiling', 'Boil it in a pot of water over a stove or fire.'],
  'Factory fabricator': ['Fabricator', 'Load the materials into a powered assembly fabricator.'],
  'Acquisition / processing': ['Gathering', 'Gathered or processed in the world rather than crafted from a menu.'],
};
const method = (kind: unknown) => { const name = text(kind); return methods[name.split(' / ')[0]] ?? methods[name] ?? [name, '']; };
const catalogName = (kind: unknown) => { const parts = text(kind).split(' / '); return parts[0] === 'Material' && parts[1] ? parts[1].replace(/_/g, ' ') : ''; };
// Generated bookkeeping that the layout already shows as research, time and era.
export function notes(conditions: unknown) {
  let rest = text(conditions);
  const facts: string[] = [];
  const time = /\btime (\d+) deciseconds\b/.exec(rest);
  if (time && Number(time[1]) > 0) facts.push('Takes about ' + Number(time[1]) / 10 + ' s');
  if (/\bone per turf 1\b/.test(rest)) facts.push('One per tile');
  rest = rest.replace(/Legacy research I\/M\/M: [^.]*?supplied material [^.;]*\.\s*/, '').replace(/Research-node and map gates also apply\.\s*/, '')
    .replace(/\s*Explicit research node: [\w, ]+\./g, '').replace(/Receiver\/context dependent; named constructor arguments retained in source\.\s*/, '')
    .replace(/Catalysts: \[\]; inhibitors: \[\]; additional can_happen\/process callbacks may apply\.\s*/, '').trim();
  return { facts, rest };
}
function Source({ file, line, revision = 'master' }: Data) {
  const ref = String(revision ?? '');
  if (!file || !line || !(ref === 'master' || /^[0-9a-f]{40}$/.test(ref))) return null;
  const segments = String(file).split('/');
  if (segments.some(segment => !segment || segment === '.' || segment === '..')) return null;
  const path = segments.map(encodeURIComponent).join('/');
  const href = 'https://github.com/Civ13/Civ13/blob/' + ref + '/' + path + '#L' + encodeURIComponent(String(line));
  return <p><a href={href} target="_blank" rel="noreferrer">Catalog source: {text(file)}:{text(line)}</a></p>;
}
function Sprite({ image, title }: { image: unknown; title?: unknown }) {
  const src = typeof image === 'string' && /^atlas_[0-9a-f]{32}\.png$/.test(image) ? image : '';
  return src ? <img className="atlas-sprite" src={src} width={32} height={32} alt="" title={text(title)} /> : <span className="atlas-sprite atlas-sprite-empty" aria-hidden="true" />;
}
function Status({ row }: { row: Data }) {
  if (row.retired) return <span className="atlas-chip atlas-warn">Retired this era</span>;
  if (row.manual_hint) return <span className="atlas-chip atlas-warn">Needs manual</span>;
  if (row.research === 'needed') return <span className="atlas-chip atlas-warn">Needs research</span>;
  return null;
}
function Resource({ ui, resource }: { ui: ScreenProps; resource: Data }) {
  return <button type="button" className="atlas-tile" disabled={!ui.interactive} title="Show how to get this and what it is used for"
    onClick={() => navigate(ui, { route: 'resource', resource: String(resource.id) })}>
    <Sprite image={resource.image} title={resource.preview} />
    <span className="atlas-tile-name">{text(resource.name)}</span>
    {text(resource.quantity) !== '' && <span className="atlas-amount">({text(resource.quantity)})</span>}
  </button>;
}
function RecipeRow({ ui, row, selected, onPick }: { ui: ScreenProps; row: Data; selected: boolean; onPick: () => void }) {
  const dim = !!row.manual_hint || !!row.retired || !!row.elsewhere;
  const variants = Number(row.variant_count) > 1 ? text(row.variant_count) + ' recipe variants' : text(row.needs);
  return <li data-result-type="recipe" className={selected ? 'atlas-selected' : undefined}>
    <button type="button" className={'atlas-row' + (dim ? ' atlas-dim' : '')} disabled={!ui.interactive} aria-current={selected ? 'true' : undefined} onClick={onPick}>
      <Sprite image={row.image} />
      <span className="atlas-row-text"><strong>{text(row.name)}</strong>
        <small>{[eraName(row.era_label), variants].filter(Boolean).join(' - ')}</small>
        {!!row.manual_hint && <small>{text(row.manual_hint)}</small>}
        {!!row.elsewhere && <small>Other maps only</small>}</span>
      <Status row={row} />
    </button>
  </li>;
}
function Recipe({ ui, recipe, choose }: { ui: ScreenProps; recipe: Data; choose: (id: string) => void }) {
  const variants = list(recipe.variants);
  const familyVariants = list(recipe.family_variants);
  const research = list(recipe.research);
  const [how, hint] = method(recipe.kind);
  const { facts, rest } = notes(recipe.conditions);
  const until = Number(recipe.maximum_era);
  return <article className="atlas-card" aria-label="Recipe">
    <h2 style={recipe.manual_hint ? { color: '#aaa' } : undefined}>{text(recipe.name)}</h2>
    <p className="atlas-chips">
      <span className="atlas-chip">{eraName(recipe.era_label) || 'Era varies'}</span>
      <span className="atlas-chip">{text(recipe.station) || how}</span>
      {catalogName(recipe.kind) && !!recipe.elsewhere && <span className="atlas-chip atlas-warn">Other maps only: {catalogName(recipe.kind)}</span>}
      {!!recipe.retired && <span className="atlas-chip atlas-warn">Retired in the current era</span>}
    </p>
    {!!recipe.manual_hint && <p role="status" className="atlas-locked">{text(recipe.manual_hint)}</p>}
    {familyVariants.length > 1 && <label className="atlas-field">Recipe variant ({familyVariants.length} ways to make this)
      <select aria-label="Recipe variant" disabled={!ui.interactive} value={String(recipe.id)} onChange={event => choose(event.target.value)}>
        {familyVariants.map(variant => <option key={String(variant.id)} value={String(variant.id)}>{text(variant.label)}{variant.research === 'needed' ? ' - needs research' : ''}{variant.elsewhere ? ' - other maps' : ''}</option>)}
      </select></label>}
    <div className="atlas-flow" aria-label="Recipe dependency">
      <div><h3>You need</h3><ul>{list(recipe.inputs).map((resource, i) => <li key={i}><Resource ui={ui} resource={resource} /></li>)}</ul></div>
      <div className="atlas-arrow" aria-hidden="true">&rarr;</div>
      <div><h3>You get</h3><ul>{list(recipe.outputs).map((resource, i) => <li key={i}><Resource ui={ui} resource={resource} /></li>)}</ul></div>
    </div>
    <h3>Requirements</h3>
    <ul className="atlas-requirements">
      {hint && <li>{hint}</li>}
      {research.map((node, i) => <li key={i}>Research: <strong>{text(node.name)}</strong>{node.state === 'done' && <span className="atlas-chip atlas-ok">Researched</span>}{node.state === 'needed' && <span className="atlas-chip atlas-warn">Not researched yet</span>}</li>)}
      {facts.map((fact, i) => <li key={'f' + i}>{fact}</li>)}
      {Number.isFinite(until) && recipe.maximum_era !== null && recipe.maximum_era !== undefined && until < 8 && <li>Can be made until the end of the {eras[until]}</li>}
      {rest && <li>{rest}</li>}
    </ul>
    <details className="atlas-technical"><summary>Catalog details</summary>
      <p>{text(recipe.kind)}. Unlock era: {text(recipe.era_label)}. {text(recipe.era_basis)}</p>
      {variants.length > 1 && <label className="atlas-field">Map recipe list
        <select aria-label="Transformation / catalog variant" disabled={!ui.interactive} value={String(recipe.id)} onChange={event => choose(event.target.value)}>
          {variants.map(variant => <option key={String(variant.id)} value={String(variant.id)}>{text(variant.kind)} (line {text(variant.line)})</option>)}
        </select></label>}
      <p>{text(recipe.conditions)}</p>
      <Source file={recipe.file} line={recipe.line} />
    </details>
  </article>;
}
const routeLabels: Record<string, string> = { tools: 'Tools', conditions: 'Conditions', era: 'Era', map_notes: 'Map notes', status: 'Review status' };
function Guidance({ ui, guidance }: { ui: ScreenProps; guidance: Data }) {
  const routes = list(guidance.routes);
  return <article className="atlas-card" aria-label="Resource">
    <h2 className="atlas-resource-title"><Sprite image={guidance.image} /><span>{text(guidance.heading) + ' ' + text(guidance.name)}</span></h2>
    {!routes.length && <NoticeBox>No gathering instructions are recorded for this resource. Recipes that make it are listed on the left.</NoticeBox>}
    {routes.map((route, i) => {
      const steps = list(route.steps), said = steps.map(step => text(step)).join(' ');
      // Some routes repeat their steps as the condition; say it once.
      const details = list(route.details).filter(detail => !(steps.length && (detail.label === 'steps' || text(detail.value) === said)));
      const plain = details.filter(detail => ['steps', 'tools', 'conditions'].includes(String(detail.label)));
      const fine = details.filter(detail => !plain.includes(detail));
      return <section key={i} className="atlas-route">
        <h3>{text(route.name)}</h3>
        {steps.length > 0 && <ol>{steps.map((step, j) => <li key={j}>{text(step)}</li>)}</ol>}
        {plain.map((detail, j) => <p key={j}><strong>{routeLabels[String(detail.label)] ?? text(detail.label)}:</strong> {text(detail.value)}</p>)}
        {['Needs', 'Can provide (conditional)'].map(heading => {
          const related = list(route.related).filter(entry => entry.heading === heading);
          return related.length > 0 && <div key={heading} className="atlas-related"><span>{heading}:</span>{related.map((entry, j) => <Resource key={j} ui={ui} resource={{ ...entry, quantity: '' }} />)}</div>;
        })}
        <details className="atlas-technical"><summary>Catalog details</summary>
          {fine.map((detail, j) => <p key={j}>{routeLabels[String(detail.label)] ?? text(detail.label)}: {text(detail.value)}</p>)}
          <Source file={route.file} line={route.line} revision={route.revision} />
        </details>
      </section>;
    })}
    {!!guidance.more && <p>More routes are available in the full web atlas.</p>}
  </article>;
}
export function CraftingAtlas(ui: ScreenProps) {
  const { data } = ui;
  const graph = data.mode !== 'page';
  const guidance: Data | null = data.guidance ?? null;
  const scope = String(data.scope ?? '');
  const [query, setQuery] = useState(text(data.query));
  const [era, setEra] = useState(String(data.era ?? ''));
  const [processor, setProcessor] = useState(String(data.processor ?? ''));
  const [allResources, setAllResources] = useState(false);
  const resetDraft = () => { setQuery(text(data.query)); setEra(String(data.era ?? '')); setProcessor(String(data.processor ?? '')); setAllResources(false); };
  useEffect(resetDraft, [data]);
  useEffect(() => () => resetAtlasRequests(), []);
  const resources = list(data.resources), recipes = list(data.recipes);
  const families = Number(data.family_count ?? data.recipe_count), hidden = Number(data.hidden_count ?? 0);
  const open = (next: Partial<Navigation> = {}) => navigate(ui, { route: 'open', query, era, processor, ...next });
  const selectedId = data.detail ? String(data.detail.id) : '';
  const chooseVariant = (id: string) => navigate(ui, !graph ? { route: 'page', query: text(data.query), page: Number(data.page), recipe: id }
    : guidance ? { route: 'resource', resource: String(guidance.id), recipe: id }
      : { route: 'open', query: text(data.query), era: String(data.era ?? ''), processor: String(data.processor ?? ''), recipe: id });
  const counts = !graph ? text(data.recipe_count) + ' matching recipes. Page ' + text(data.page) + '.'
    : guidance ? text(guidance.made_by_count ?? 0) + (Number(guidance.made_by_count) === 1 ? ' recipe makes this, ' : ' recipes make this, ') + text(guidance.used_in_count ?? 0) + (Number(guidance.used_in_count) === 1 ? ' uses it.' : ' use it.')
      : text(families) + (families === 1 ? ' recipe' : ' recipes') + (Number(data.recipe_count) > families ? ' (' + text(data.recipe_count) + ' with variants)' : '') + ', ' + text(data.resource_count) + (Number(data.resource_count) === 1 ? ' resource.' : ' resources.');
  const related = (title: string, rows: any[], total: unknown) => rows.length > 0 && <>
    <h3>{title} ({text(total)})</h3>
    <ul>{rows.map(row => <RecipeRow key={title + String(row.id)} ui={ui} row={row} selected={String(row.id) === selectedId} onPick={() => chooseVariant(String(row.id))} />)}</ul>
    {Number(total) > rows.length && <p>First {rows.length} shown.</p>}
  </>;
  return <div className="atlas">
    <form className="atlas-filter" role="search" onSubmit={event => { event.preventDefault(); if (graph) open(); else navigate(ui, { route: 'open', query }); }}>
      <label className="atlas-search">Search<input aria-label="Search" type="search" maxLength={64} placeholder="Item, ingredient or recipe name" disabled={!ui.interactive} value={query} onChange={event => setQuery(event.target.value)} /></label>
      {graph && <>
        <label>Unlock era<select aria-label="Unlock era" disabled={!ui.interactive} value={era} onChange={event => { setEra(event.target.value); open({ era: event.target.value }); }}>
          <option value="">All unlock eras</option>{eras.map((label, i) => <option key={i} value={String(i)}>{i}: {label}{Number(data.map_era) === i && data.map_era !== null && data.map_era !== undefined ? ' (current)' : ''}</option>)}
          <option value="multiple">Multiple eras</option><option value="unknown">Unknown / context dependent</option>
        </select></label>
        <label>Made at<select aria-label="Processor" disabled={!ui.interactive} value={processor} onChange={event => { setProcessor(event.target.value); open({ processor: event.target.value }); }}>
          <option value="">Anywhere</option><option value="sawmill">Sawmills</option><option value="grain_mill">Grain mills</option><option value="tanning_rack">Tanning racks</option>
        </select></label>
      </>}
      <button type="submit" disabled={!ui.interactive}>Search</button>
      <button type="button" disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'reset' })}>{graph ? 'Reset' : 'Return to dependency atlas'}</button>
    </form>
    <p className="atlas-status">{counts}
      {graph && (hidden > 0 || scope === 'all') && <label className="atlas-scope"><input type="checkbox" aria-label="Include other maps" disabled={!ui.interactive} checked={scope === 'all'}
        onChange={event => guidance ? navigate(ui, { route: 'resource', resource: String(guidance.id), scope: event.target.checked ? 'all' : '' }) : open({ scope: event.target.checked ? 'all' : '' })} />
        Include other maps{hidden > 0 ? ' (' + hidden + ' hidden)' : ''}</label>}
      <span className="atlas-links">
        <button type="button" className="atlas-link" disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'page', page: 1 })}>{graph ? 'Paginated list' : 'All recipes'}</button>
        {!graph && !!data.previous && <button type="button" className="atlas-link" disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'page', page: Number(data.page) - 1, query: text(data.query) })}>Previous</button>}
        {!graph && !!data.next && <button type="button" className="atlas-link" disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'page', page: Number(data.page) + 1, query: text(data.query) })}>Next</button>}
        <a href="https://civ13.github.io/Civ13/crafting/" target="_blank" rel="noreferrer">Full web atlas</a>
      </span>
    </p>
    {graph ? <div className="atlas-columns">
      <nav className="atlas-index" aria-label="Results">
        {guidance ? <>
          {related('Made by', list(guidance.made_by), guidance.made_by_count)}
          {related('Used in', list(guidance.used_in), guidance.used_in_count)}
          {!list(guidance.made_by).length && !list(guidance.used_in).length && <p>No recipes on this map make or use it.</p>}
        </> : <>
          {resources.length > 0 && <><h3>Resources ({text(data.resource_count)})</h3><ul>{resources.slice(0, allResources ? resources.length : 4).map(resource => <li key={String(resource.id)} data-result-type="resource">
            <button type="button" className="atlas-row" disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'resource', resource: String(resource.id) })}>
              <Sprite image={resource.image} /><span className="atlas-row-text"><strong>{text(resource.name)}</strong><small>How to get it and what it makes</small></span>
            </button></li>)}</ul>
            {!allResources && resources.length > 4 && <button type="button" className="atlas-link atlas-more" onClick={() => setAllResources(true)}>Show all {resources.length} resources</button>}</>}
          {Number(data.resource_count) > 150 && <p>First 150 resource matches shown. Refine your search to find more.</p>}
          <h3>Recipes ({text(families)})</h3>
          <ul>{recipes.map(recipe => <RecipeRow key={String(recipe.family_id ?? recipe.id)} ui={ui} row={recipe} selected={String(recipe.id) === selectedId}
            onPick={() => navigate(ui, { route: 'open', query: text(data.query), era: String(data.era ?? ''), processor: String(data.processor ?? ''), recipe: String(recipe.id) })} />)}</ul>
          {families > 150 && <p>First 150 recipe families shown. Refine filters to find more.</p>}
        </>}
      </nav>
      <div className="atlas-detail">
        {data.detail && <Recipe ui={ui} recipe={data.detail} choose={chooseVariant} />}
        {guidance && <Guidance ui={ui} guidance={guidance} />}
        {!data.detail && !guidance && <NoticeBox>{Number(data.resource_count) > 0 ? 'No matching recipes. Select a Resource result to view acquisition routes and related recipes.' : hidden > 0 ? 'No matching recipes on this map. Tick "Include other maps" to see ' + hidden + ' from other maps.' : 'No matching recipes or resources. Clear filters or search for an ingredient.'}</NoticeBox>}
        <p className="atlas-footnote">The atlas is a reference. Skills, tools, your map and faction still decide what you can craft.</p>
      </div>
    </div> : <div className="atlas-detail">{guidance && <Guidance ui={ui} guidance={guidance} />}{list(data.entries).map((recipe, i) => <Recipe key={i} ui={ui} recipe={recipe} choose={chooseVariant} />)}</div>}
  </div>;
}
