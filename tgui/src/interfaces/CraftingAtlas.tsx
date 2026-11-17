import { useEffect, useState } from 'react';
import { NoticeBox } from 'tgui-core/components';
import type { Data, ScreenProps } from '../types';
import { list, str } from './common';
import { Pill } from './kit';

type Navigation = { route: 'open' | 'page' | 'resource' | 'reset'; query?: string; era?: string; processor?: string; recipe?: string; page?: number; resource?: string; scope?: string };
// The server accepts one atlas request per second per reader and drops the rest.
// Send at once when possible; otherwise deliver only the latest click when the window reopens.
const REQUEST_GAP = 1100;
let lastSent = -REQUEST_GAP, queued: ReturnType<typeof setTimeout> | undefined;
export const resetAtlasRequests = () => { lastSent = -REQUEST_GAP; if (queued) clearTimeout(queued); queued = undefined; };
const navigate = (ui: ScreenProps, params: Navigation) => {
  if (!ui.interactive) return;
  const send = () => { queued = undefined; lastSent = Date.now(); ui.act('atlas_navigate', { value: JSON.stringify(params) }); };
  if (queued) clearTimeout(queued);
  const wait = lastSent + REQUEST_GAP - Date.now();
  if (wait <= 0) send(); else queued = setTimeout(send, wait);
};
const eras = ['Stone Age', 'Bronze Age', 'Middle Ages', 'Imperial Age', 'Industrial Age', 'Early Modern Age', 'WW2', 'Cold War', 'Modern Age', 'Digital Age'];
const eraName = (label: unknown) => str(label).replace(/(^|\/ )\d+: /g, '$1').replace(/^Unknown \/ context dependent$/, '');
// How a recipe is carried out, in the player's terms. Unknown kinds keep their catalog label.
const methods: Record<string, [string, string]> = {
  'Material': ['Crafting menu', 'Hold the material and use it in your hand to open its crafting menu.'],
  'Native stack': ['Crafting menu', 'Hold the material and use it in your hand to open its crafting menu.'],
  'Anvil': ['Anvil', 'Use the heated metal on an anvil and pick the item.'],
  'Chemistry': ['Mixing', 'Combine the reagents in one container.'],
  'Cooking': ['Boiling', 'Boil it in a pot of water over a stove or fire.'],
  'Factory fabricator': ['Fabricator', 'Load the materials into a powered assembly fabricator.'],
  'Acquisition / processing': ['Gathering', 'Gathered or processed in the world.'],
};
// Where a reaction runs. Most happen in any container; the bench offers some and is the only place for a few.
const reactionHints: Record<string, string> = {
  '': 'Mix the reagents in one open container, such as a bucket or beaker. They react on their own.',
  bench: 'Mix the reagents in one open container and they react on their own. A laboratory reaction bench can also run it on demand in its secured beaker.',
  bench_only: 'Reacts only in the secured beaker of a laboratory reaction bench, or in a powered factory reaction vessel. Use the bench and pick the reaction.',
  bench_heated: 'Reacts only in the secured beaker of a laboratory reaction bench heated with a laboratory burner, or in a powered factory reaction vessel.',
};
const reagentList = (found: string) => Array.from(found.matchAll(/\('(\w+)', '([\d.]+)'\)/g)).map(match => match[2] + ' ' + match[1].replace(/_/g, ' ')).join(' and ');
const method = (kind: unknown) => { const name = str(kind); return methods[name.split(' / ')[0]] ?? methods[name] ?? [name, '']; };
const catalogName = (kind: unknown) => { const parts = str(kind).split(' / '); return parts[0] === 'Material' && parts[1] ? parts[1].replace(/_/g, ' ') : ''; };
// Generated bookkeeping that the layout already shows as research, time and era.
export function notes(conditions: unknown) {
  let rest = str(conditions);
  const facts: string[] = [];
  const time = /\btime (\d+) deciseconds\b/.exec(rest);
  if (time && Number(time[1]) > 0) facts.push('Takes about ' + Number(time[1]) / 10 + ' s');
  if (/\bone per turf 1\b/.test(rest)) facts.push('One per tile');
  const reaction = /Catalysts: \[(.*?)\]; inhibitors: \[(.*?)\]; additional can_happen\/process callbacks may apply\.\s*/.exec(rest);
  if (reaction) {
    if (reagentList(reaction[1])) facts.push('Needs ' + reagentList(reaction[1]) + ' in the container as a catalyst. It is not used up');
    if (reagentList(reaction[2])) facts.push('Does not react while the container holds ' + reagentList(reaction[2]));
    rest = rest.replace(reaction[0], '');
  }
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
  return <p><a href={href} target="_blank" rel="noreferrer">Catalog source: {str(file)}:{str(line)}</a></p>;
}
function Sprite({ image, title }: { image: unknown; title?: unknown }) {
  const src = typeof image === 'string' && /^atlas_[0-9a-f]{32}\.png$/.test(image) ? image : '';
  return src ? <img className="atlas-sprite" src={src} width={32} height={32} alt="" title={str(title)} /> : <span className="atlas-sprite atlas-sprite-empty" aria-hidden="true" />;
}
function Status({ row }: { row: Data }) {
  if (row.retired) return <Pill tone="warn" className="atlas-chip">Retired this era</Pill>;
  if (row.manual_hint) return <Pill tone="warn" className="atlas-chip">Needs manual</Pill>;
  if (row.research === 'needed') return <Pill tone="warn" className="atlas-chip">Needs research</Pill>;
  return null;
}
function Resource({ ui, resource }: { ui: ScreenProps; resource: Data }) {
  return <button type="button" className="atlas-tile" disabled={!ui.interactive} title="Show how to get this and what it is used for"
    onClick={() => navigate(ui, { route: 'resource', resource: String(resource.id) })}>
    <Sprite image={resource.image} title={resource.preview} />
    <span className="atlas-tile-name">{str(resource.name)}</span>
    {str(resource.quantity) !== '' && <span className="atlas-amount">({str(resource.quantity)})</span>}
  </button>;
}
function RecipeRow({ ui, row, selected, onPick }: { ui: ScreenProps; row: Data; selected: boolean; onPick: () => void }) {
  const dim = !!row.manual_hint || !!row.retired || !!row.elsewhere;
  const variants = Number(row.variant_count) > 1 ? str(row.variant_count) + (row.ways ? ' versions: ' + str(row.ways) : ' recipe variants') : str(row.needs);
  return <li data-result-type="recipe" className={selected ? 'atlas-selected' : undefined}>
    <button type="button" className={'atlas-row' + (dim ? ' atlas-dim' : '')} disabled={!ui.interactive} aria-current={selected ? 'true' : undefined} onClick={onPick}>
      <Sprite image={row.image} />
      <span className="atlas-row-text"><strong>{str(row.name)}</strong>
        <small>{[eraName(row.era_label), variants].filter(Boolean).join(' - ')}</small>
        {!!row.manual_hint && <small>{str(row.manual_hint)}</small>}
        {!!row.elsewhere && <small>Other maps only</small>}</span>
      <Status row={row} />
    </button>
  </li>;
}
function Recipe({ ui, recipe, choose, lead }: { ui: ScreenProps; recipe: Data; choose: (id: string) => void; lead?: string }) {
  const variants = list(recipe.variants);
  const familyVariants = list(recipe.family_variants);
  const research = list(recipe.research);
  const skill = recipe.skill as Data | null | undefined;
  const site = str(recipe.site);
  const [how, base] = method(recipe.kind);
  const hint = str(recipe.kind) === 'Chemistry' ? reactionHints[site] ?? base : base;
  const optional = site === 'bench';
  const { facts, rest } = notes(recipe.conditions);
  const until = Number(recipe.maximum_era);
  // Only recipes made from a held material have a Crafting window to open.
  const product = list(recipe.outputs)[0];
  const craftable = str(recipe.kind).split(' / ')[0] === 'Material' && !recipe.elsewhere && !recipe.retired && product && typeof product.id === 'string' ? product.id : '';
  return <article className="atlas-card" aria-label="Recipe">
    {!!lead && <p className="atlas-eyebrow">{lead}</p>}
    <h2 style={recipe.manual_hint ? { color: '#aaa' } : undefined}>{str(recipe.name)}</h2>
    <p className="atlas-chips">
      <Pill className="atlas-chip">{eraName(recipe.era_label) || 'Era varies'}</Pill>
      {recipe.station_id ? <button type="button" className="kit-pill atlas-chip atlas-chip-link" disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'resource', resource: String(recipe.station_id) })}>{optional ? 'Also at: ' : 'Made at: '}{str(recipe.station)}</button>
        : <Pill className="atlas-chip">{str(recipe.station) || how}</Pill>}
      {catalogName(recipe.kind) && !!recipe.elsewhere && <Pill tone="warn" className="atlas-chip">Other maps only: {catalogName(recipe.kind)}</Pill>}
      {!!recipe.retired && <Pill tone="warn" className="atlas-chip">Retired in the current era</Pill>}
    </p>
    {!!recipe.manual_hint && <p role="status" className="atlas-locked">{str(recipe.manual_hint)}</p>}
    {craftable && <p><button type="button" className="atlas-craft" disabled={!ui.interactive} onClick={() => ui.act('atlas_craft', { value: craftable })}>Craft this</button>
      <span className="atlas-craft-note">Opens the Crafting window on this recipe when its material is in your hands or beside you.</span></p>}
    {familyVariants.length > 1 && <label className="atlas-field">Recipe variant ({familyVariants.length} ways to make this)
      <select aria-label="Recipe variant" disabled={!ui.interactive} value={String(recipe.id)} onChange={event => choose(event.target.value)}>
        {familyVariants.map(variant => <option key={String(variant.id)} value={String(variant.id)}>{str(variant.label)}{variant.research === 'needed' ? ' - needs research' : ''}{variant.elsewhere ? ' - other maps' : ''}</option>)}
      </select></label>}
    <div className="atlas-flow" aria-label="Recipe dependency">
      <div><h3>You need</h3><ul>{list(recipe.inputs).map((resource, i) => <li key={i}><Resource ui={ui} resource={resource} /></li>)}</ul></div>
      <div className="atlas-arrow" aria-hidden="true">&rarr;</div>
      <div><h3>You get</h3><ul>{list(recipe.outputs).map((resource, i) => <li key={i}><Resource ui={ui} resource={resource} /></li>)}</ul></div>
    </div>
    <h3>Requirements</h3>
    <ul className="atlas-requirements">
      {hint && <li>{hint}</li>}
      {research.map((node, i) => <li key={i}>Research: <strong>{str(node.name)}</strong>{node.state === 'done' && <Pill tone="good" className="atlas-chip">Researched</Pill>}{node.state === 'needed' && <Pill tone="warn" className="atlas-chip">Not researched yet</Pill>}</li>)}
      {skill && <li>Skill: <strong>{str(skill.name)} {Number(skill.need)}</strong>{skill.have !== null && skill.have !== undefined && (skill.met ? <Pill tone="good" className="atlas-chip">Yours is {Number(skill.have)}</Pill> : <Pill tone="warn" className="atlas-chip">Yours is {Number(skill.have)}</Pill>)}</li>}
      {facts.map((fact, i) => <li key={'f' + i}>{fact}</li>)}
      {Number.isFinite(until) && recipe.maximum_era !== null && recipe.maximum_era !== undefined && until < 8 && <li>Can be made until the end of the {eras[until]}</li>}
      {rest && <li>{rest}</li>}
    </ul>
    <details className="atlas-technical"><summary>Catalog details</summary>
      <p>{str(recipe.kind)}. Unlock era: {str(recipe.era_label)}. {str(recipe.era_basis)}</p>
      {variants.length > 1 && <label className="atlas-field">Map recipe list
        <select aria-label="Transformation / catalog variant" disabled={!ui.interactive} value={String(recipe.id)} onChange={event => choose(event.target.value)}>
          {variants.map(variant => <option key={String(variant.id)} value={String(variant.id)}>{str(variant.kind)} (line {str(variant.line)})</option>)}
        </select></label>}
      <p>{str(recipe.conditions)}</p>
      <Source file={recipe.file} line={recipe.line} />
    </details>
  </article>;
}
// Things nobody crafts: say where they are instead of "no recipe".
const worldNotes: Record<string, string> = {
  'Animal': 'A living creature. Look for it in the wild on maps where it lives, or keep and breed a herd.',
  'Terrain': 'Part of the landscape. Look for this ground on the map.',
  'Natural feature': 'Grows or lies in the wild. Look for it on the map.',
  'Hostile person': 'A hostile character, met on some maps and events.',
  'Wall': 'Part of a building or the landscape.',
};
// Reference entries describe a type of thing; they never report what is in the world right now.
const referenceNote = 'Reference entry. It may be found on some maps, sold, issued to a role or built another way.';
const routeLabels: Record<string, string> = { tools: 'Tools', conditions: 'Conditions', era: 'Era', map_notes: 'Map notes', status: 'Review status' };
// Staff-only page: deliberately left out of the public atlas, web atlas and wiki.
function AdminGuidance({ guidance }: { guidance: Data }) {
  return <article className="atlas-card" aria-label="Admin-only entry">
    <h2 className="atlas-resource-title"><Sprite image={guidance.image} /><span>{str(guidance.name)}</span></h2>
    <p className="atlas-chips"><Pill tone="warn" className="atlas-chip">Admin only</Pill><Pill className="atlas-chip">Not in the public atlas</Pill></p>
    {!!guidance.desc && <p className="atlas-desc">{str(guidance.desc)}</p>}
    <h3 className="atlas-section">Staff note</h3>
    <p>{str(guidance.admin_note)}</p>
    <p className="atlas-footnote">Only admins see this entry. It is deliberately left out of the public atlas, the web atlas and the wiki; do not share it with players.</p>
    <details className="atlas-technical"><summary>Catalog details</summary><p>{str(guidance.id)}</p></details>
  </article>;
}
function Guidance({ ui, guidance }: { ui: ScreenProps; guidance: Data }) {
  if (guidance.admin_only) return <AdminGuidance guidance={guidance} />;
  const routes = list(guidance.routes), stats = list(guidance.stats), made = Number(guidance.made_by_count) || 0, inside = list(guidance.found_in);
  const world = worldNotes[str(guidance.kind)];
  return <article className="atlas-card" aria-label="Resource">
    <h2 className="atlas-resource-title"><Sprite image={guidance.image} /><span>{str(guidance.name)}</span></h2>
    {!!guidance.kind && <p className="atlas-chips"><Pill className="atlas-chip">{str(guidance.kind)}</Pill>
      {made > 0 && <Pill className="atlas-chip">Craftable</Pill>}
      {!!guidance.entity && <Pill className="atlas-chip">Reference</Pill>}
      {Number(guidance.used_in_count) > 0 && <Pill className="atlas-chip">Used in {str(guidance.used_in_count)} {Number(guidance.used_in_count) === 1 ? 'recipe' : 'recipes'}</Pill>}
      {Number(guidance.made_here_count) > 0 && <Pill className="atlas-chip">Workstation</Pill>}</p>}
    {!!guidance.desc && <p className="atlas-desc">{str(guidance.desc)}</p>}
    {stats.length > 0 && <dl className="atlas-stats">{stats.map((stat, i) => <div key={i}><dt>{str(stat.label)}</dt><dd>{str(stat.value)}</dd></div>)}</dl>}
    <h3 className="atlas-section">{str(guidance.heading)} {str(guidance.name)}</h3>
    {!routes.length && <p>{made > 0 ? 'Crafted. ' + (made === 1 ? 'Its recipe is shown below.' : 'The first of its ' + made + ' recipes is shown below, and the rest are listed under Made by.')
      : inside.length ? 'No recipe makes this. It comes inside the items below.'
      : world ?? (guidance.entity ? referenceNote : 'No recipe makes this and no gathering route is recorded. It is gathered, hunted, mined, traded for or found in the world.')}</p>}
    {inside.length > 0 && <div className="atlas-related"><span>Found in:</span>{inside.map((entry, i) => entry.id
      ? <Resource key={i} ui={ui} resource={{ ...entry, quantity: '' }} />
      : <Pill key={i} className="atlas-chip">{str(entry.name)}</Pill>)}</div>}
    {routes.map((route, i) => {
      const steps = list(route.steps), said = steps.map(step => str(step)).join(' ');
      // Some routes repeat their steps as the condition; say it once.
      const details = list(route.details).filter(detail => !(steps.length && (detail.label === 'steps' || str(detail.value) === said)));
      const plain = details.filter(detail => ['steps', 'tools', 'conditions'].includes(String(detail.label)));
      const fine = details.filter(detail => !plain.includes(detail));
      return <section key={i} className="atlas-route">
        <h3>{str(route.name)}</h3>
        {steps.length > 0 && <ol>{steps.map((step, j) => <li key={j}>{str(step)}</li>)}</ol>}
        {plain.map((detail, j) => <p key={j}><strong>{routeLabels[String(detail.label)] ?? str(detail.label)}:</strong> {str(detail.value)}</p>)}
        {['Needs', 'Can provide (conditional)'].map(heading => {
          const related = list(route.related).filter(entry => entry.heading === heading);
          return related.length > 0 && <div key={heading} className="atlas-related"><span>{heading}:</span>{related.map((entry, j) => <Resource key={j} ui={ui} resource={{ ...entry, quantity: '' }} />)}</div>;
        })}
        <details className="atlas-technical"><summary>Catalog details</summary>
          {fine.map((detail, j) => <p key={j}>{routeLabels[String(detail.label)] ?? str(detail.label)}: {str(detail.value)}</p>)}
          <Source file={route.file} line={route.line} revision={route.revision} />
        </details>
      </section>;
    })}
    {!!guidance.more && <p>More routes are available in the full web atlas.</p>}
    <p className="atlas-wiki"><a href={'https://civ13.github.io/civ13-wiki/?search=' + encodeURIComponent(str(guidance.name))} target="_blank" rel="noreferrer">Search the wiki for {str(guidance.name)}</a></p>
  </article>;
}
export function CraftingAtlas(ui: ScreenProps) {
  const { data } = ui;
  const graph = data.mode !== 'page';
  const guidance: Data | null = data.guidance ?? null;
  const scope = String(data.scope ?? '');
  const [query, setQuery] = useState(str(data.query));
  const [era, setEra] = useState(String(data.era ?? ''));
  const [processor, setProcessor] = useState(String(data.processor ?? ''));
  const [allResources, setAllResources] = useState(false);
  const resetDraft = () => { setQuery(str(data.query)); setEra(String(data.era ?? '')); setProcessor(String(data.processor ?? '')); setAllResources(false); };
  useEffect(resetDraft, [data]);
  useEffect(() => () => resetAtlasRequests(), []);
  const resources = list(data.resources), recipes = list(data.recipes), adminEntries = list(data.admin_entries);
  const families = Number(data.family_count ?? data.recipe_count), hidden = Number(data.hidden_count ?? 0);
  const open = (next: Partial<Navigation> = {}) => navigate(ui, { route: 'open', query, era, processor, ...next });
  const selectedId = data.detail ? String(data.detail.id) : '';
  const chooseVariant = (id: string) => navigate(ui, !graph ? { route: 'page', query: str(data.query), page: Number(data.page), recipe: id }
    : guidance ? { route: 'resource', resource: String(guidance.id), recipe: id }
      : { route: 'open', query: str(data.query), era: String(data.era ?? ''), processor: String(data.processor ?? ''), recipe: id });
  const counts = !graph ? str(data.recipe_count) + ' matching recipes. Page ' + str(data.page) + '.'
    : guidance ? str(guidance.made_by_count ?? 0) + (Number(guidance.made_by_count) === 1 ? ' recipe makes this, ' : ' recipes make this, ') + str(guidance.used_in_count ?? 0) + (Number(guidance.used_in_count) === 1 ? ' uses it' : ' use it') + (Number(guidance.made_here_count) > 0 ? ', ' + str(guidance.made_here_count) + ' made here.' : '.')
      : str(families) + (families === 1 ? ' recipe' : ' recipes') + (Number(data.recipe_count) > families ? ' (' + str(data.recipe_count) + ' with variants)' : '') + ', ' + str(data.resource_count) + (Number(data.resource_count) === 1 ? ' resource.' : ' resources.');
  const related = (title: string, rows: any[], total: unknown) => rows.length > 0 && <>
    <h3>{title} ({str(total)})</h3>
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
        {!graph && !!data.previous && <button type="button" className="atlas-link" disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'page', page: Number(data.page) - 1, query: str(data.query) })}>Previous</button>}
        {!graph && !!data.next && <button type="button" className="atlas-link" disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'page', page: Number(data.page) + 1, query: str(data.query) })}>Next</button>}
        <a href="https://civ13.github.io/Civ13/crafting/" target="_blank" rel="noreferrer">Full web atlas</a>
      </span>
    </p>
    {graph ? <div className="atlas-columns">
      <nav className="atlas-index" aria-label="Results">
        {guidance ? <>
          {related('Made by', list(guidance.made_by), guidance.made_by_count)}
          {related('Used in', list(guidance.used_in), guidance.used_in_count)}
          {related('Made here', list(guidance.made_here), guidance.made_here_count)}
          {!list(guidance.made_by).length && !list(guidance.used_in).length && !list(guidance.made_here).length && <p>No recipes on this map make or use it.</p>}
        </> : <>
          {resources.length > 0 && <><h3>Resources ({str(data.resource_count)})</h3><ul>{resources.slice(0, allResources ? resources.length : 4).map(resource => <li key={String(resource.id)} data-result-type="resource">
            <button type="button" className="atlas-row" disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'resource', resource: String(resource.id) })}>
              <Sprite image={resource.image} /><span className="atlas-row-text"><strong>{str(resource.name)}</strong><small>How to get it and what it makes</small></span>
            </button></li>)}</ul>
            {!allResources && resources.length > 4 && <button type="button" className="atlas-link atlas-more" onClick={() => setAllResources(true)}>Show all {resources.length} resources</button>}</>}
          {Number(data.resource_count) > 150 && <p>First 150 resource matches shown. Refine your search to find more.</p>}
          <h3>Recipes ({str(families)})</h3>
          <ul>{recipes.map(recipe => <RecipeRow key={String(recipe.family_id ?? recipe.id)} ui={ui} row={recipe} selected={String(recipe.id) === selectedId}
            onPick={() => navigate(ui, { route: 'open', query: str(data.query), era: String(data.era ?? ''), processor: String(data.processor ?? ''), recipe: String(recipe.id) })} />)}</ul>
          {families > 150 && <p>First 150 recipe families shown. Refine filters to find more.</p>}
          {adminEntries.length > 0 && <section className="atlas-admin" aria-label="Admin only"><h3>Admin only ({adminEntries.length})</h3>
            <p className="atlas-footnote">Deliberately left out of the public atlas. Only admins see this list.</p>
            <ul>{adminEntries.map(entry => <li key={String(entry.id)} data-result-type="admin">
              <button type="button" className="atlas-row" disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'resource', resource: String(entry.id) })}>
                <Sprite image={entry.image} /><span className="atlas-row-text"><strong>{str(entry.name)}</strong><small>{str(entry.note)}</small></span>
              </button></li>)}</ul></section>}
        </>}
      </nav>
      <div className="atlas-detail">
        {guidance && <Guidance ui={ui} guidance={guidance} />}
        {data.detail && <Recipe ui={ui} recipe={data.detail} choose={chooseVariant} lead={guidance ? 'Recipe' : undefined} />}
        {!data.detail && !guidance && <NoticeBox>{Number(data.resource_count) > 0 ? 'No matching recipes. Select a Resource result to view acquisition routes and related recipes.' : hidden > 0 ? 'No matching recipes on this map. Tick "Include other maps" to see ' + hidden + ' from other maps.' : 'No matching recipes or resources. Clear filters or search for an ingredient.'}</NoticeBox>}
        <p className="atlas-footnote">The atlas is a reference. Skills, tools, your map and faction still decide what you can craft.</p>
      </div>
    </div> : <div className="atlas-detail">{guidance && <Guidance ui={ui} guidance={guidance} />}{list(data.entries).map((recipe, i) => <Recipe key={i} ui={ui} recipe={recipe} choose={chooseVariant} />)}</div>}
  </div>;
}
