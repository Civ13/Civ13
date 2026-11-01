import { useEffect, useState } from 'react';
import { Button, NoticeBox, Section } from 'tgui-core/components';
import type { Data, ScreenProps } from '../types';
import { list, text } from './common';

type Navigation = { route: 'open' | 'page' | 'resource' | 'reset'; query?: string; era?: string; processor?: string; recipe?: string; page?: number; resource?: string };
const navigate = (ui: ScreenProps, params: Navigation) => {
  if (ui.interactive) ui.act('atlas_navigate', { atlas_navigate: JSON.stringify(params) });
};
const eras = ['Stone Age', 'Bronze Age', 'Middle Ages', 'Imperial Age', 'Industrial Age', 'Early Modern Age', 'WW2', 'Cold War', 'Modern Age'];
function Source({ file, line, revision = 'master' }: Data) {
  const ref = String(revision ?? '');
  if (!file || !line || !(ref === 'master' || /^[0-9a-f]{40}$/.test(ref))) return null;
  const segments = String(file).split('/');
  if (segments.some(segment => !segment || segment === '.' || segment === '..')) return null;
  const path = segments.map(encodeURIComponent).join('/');
  const href = 'https://github.com/Civ13/Civ13/blob/' + ref + '/' + path + '#L' + encodeURIComponent(String(line));
  return <p><a href={href} target="_blank" rel="noreferrer">Catalog source: {text(file)}:{text(line)}</a></p>;
}
function Resource({ ui, resource }: { ui: ScreenProps; resource: Data }) {
  const image = typeof resource.image === 'string' && /^atlas_[0-9a-f]{32}\.png$/.test(resource.image) ? resource.image : '';
  return <span className="atlas-resource">
    {image && <img src={image} width={32} height={32} alt="" title={text(resource.preview)} />}
    <span><Button disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'resource', resource: String(resource.id) })}>{text(resource.name)}</Button> ({text(resource.quantity)})</span>
  </span>;
}
function Recipe({ ui, recipe, graph }: { ui: ScreenProps; recipe: Data; graph: boolean }) {
  const variants = list(recipe.variants);
  const chooseVariant = (id: string) => navigate(ui, graph
    ? { route: 'open', query: text(ui.data.query), era: String(ui.data.era ?? ''), processor: String(ui.data.processor ?? ''), recipe: id }
    : { route: 'page', query: text(ui.data.query), page: Number(ui.data.page), recipe: id });
  return <Section title={text(recipe.name)}>
    {variants.length > 0 && <p><label>Transformation / catalog variant <select aria-label="Transformation / catalog variant" disabled={!ui.interactive} value={String(recipe.id)} onChange={event => chooseVariant(event.target.value)}>
      {variants.map(variant => <option key={String(variant.id)} value={String(variant.id)}>{text(variant.kind)} (line {text(variant.line)})</option>)}
    </select></label></p>}
    {variants.length > 0 && <p>Equivalent recipe definitions in alternative catalogs. Map and faction gates still apply.</p>}
    <p>{text(recipe.kind)}</p>
    <div className="atlas-dependency" aria-label="Recipe dependency">
      <div><h3>Inputs</h3><ul>{list(recipe.inputs).map((resource, i) => <li key={i}><Resource ui={ui} resource={resource} /></li>)}</ul></div>
      <div><h3>Transformation</h3><p>{text(recipe.kind)}</p></div>
      <div><h3>Outputs</h3><ul>{list(recipe.outputs).map((resource, i) => <li key={i}><Resource ui={ui} resource={resource} /></li>)}</ul></div>
    </div>
    {graph && <p>Unlock era: {text(recipe.era_label)}. {text(recipe.era_basis)}</p>}
    <p>{text(recipe.conditions)}</p>
    <Source file={recipe.file} line={recipe.line} />
  </Section>;
}
function Guidance({ ui, guidance }: { ui: ScreenProps; guidance: Data }) {
  const routes = list(guidance.routes);
  return <Section title={text(guidance.heading) + ' ' + text(guidance.name)}>
    {!routes.length && <NoticeBox>No reviewed gathering instructions for this resource. Producer recipes below may provide processing routes; their requirements still apply.</NoticeBox>}
    {routes.map((route, i) => <article key={i}>
      <h3>{text(route.name)}</h3>
      {list(route.details).map((detail, j) => <p key={j}>{text(detail.label)}: {text(detail.value)}</p>)}
      {list(route.related).map((related, j) => <p key={j}>{text(related.heading)}: <Button disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'resource', resource: String(related.id) })}>{text(related.name)}</Button></p>)}
      <Source file={route.file} line={route.line} revision={route.revision} />
    </article>)}
    {!!guidance.more && <p>More routes are available in the full web atlas.</p>}
  </Section>;
}
export function CraftingAtlas(ui: ScreenProps) {
  const { data } = ui;
  const graph = data.mode !== 'page';
  const [query, setQuery] = useState(text(data.query));
  const [era, setEra] = useState(String(data.era ?? ''));
  const [processor, setProcessor] = useState(String(data.processor ?? ''));
  const resetDraft = () => { setQuery(text(data.query)); setEra(String(data.era ?? '')); setProcessor(String(data.processor ?? '')); };
  useEffect(resetDraft, [data]);
  const resources = list(data.resources), recipes = list(data.recipes);
  const counts = text(data.recipe_count) + ' matching recipes' + (graph ? ', sorted by unlock era. ' + text(data.resource_count) + ' matching resources.' : '. Page ' + text(data.page) + '.');
  return <>
    <Section title="Crafting Atlas">
      <form className="atlas-filter" onSubmit={event => { event.preventDefault(); navigate(ui, graph ? { route: 'open', query, era, processor } : { route: 'open', query }); }}>
        <label>Search<input aria-label="Search" type="search" maxLength={64} disabled={!ui.interactive} value={query} onChange={event => setQuery(event.target.value)} /></label>
        {graph && <>
          <label>Unlock era<select aria-label="Unlock era" disabled={!ui.interactive} value={era} onChange={event => setEra(event.target.value)}>
            <option value="">All unlock eras</option>{eras.map((label, i) => <option key={i} value={String(i)}>{i}: {label}</option>)}
            <option value="multiple">Multiple eras</option><option value="unknown">Unknown / context dependent</option>
          </select></label>
          <label>Processor<select aria-label="Processor" disabled={!ui.interactive} value={processor} onChange={event => setProcessor(event.target.value)}>
            <option value="">All processors and recipes</option><option value="sawmill">Sawmills</option><option value="grain_mill">Grain mills</option><option value="tanning_rack">Tanning racks</option>
          </select></label>
        </>}
        <button type="submit" disabled={!ui.interactive}>{graph ? 'Filter' : 'Search'}</button>
        <button type="button" disabled={!ui.interactive} onClick={resetDraft}>Cancel filter edits</button>
      </form>
      <p>{counts}</p>
      <p>{graph && 'Search a resource name or identifier for Resource results; filters apply to recipes. Research tiers can be ahead of map era; unknown and multiple-era records remain explicit. '}Map, faction, skills, research, tools and other requirements still apply; alternative catalogs are included.</p>
      <Button disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'reset' })}>{graph ? 'Reset atlas' : 'Return to dependency atlas'}</Button>
      <Button disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'page', page: 1 })}>{graph ? 'Paginated list' : 'All recipes'}</Button>
      {!graph && <>
        {!!data.previous && <Button disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'page', page: Number(data.page) - 1, query: text(data.query) })}>Previous</Button>}
        {!!data.next && <Button disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'page', page: Number(data.page) + 1, query: text(data.query) })}>Next</Button>}
      </>}
      <p><a href="https://civ13.github.io/Civ13/crafting/" target="_blank" rel="noreferrer">Full web atlas</a></p>
    </Section>
    {data.guidance && <Guidance ui={ui} guidance={data.guidance} />}
    {graph ? <div className="atlas-columns">
      <Section title="Results">
        {resources.length > 0 && <><h3>Resources</h3><ul>{resources.map(resource => <li key={String(resource.id)} data-result-type="resource"><Button disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'resource', resource: String(resource.id) })}>{text(resource.name)}</Button><br /><small>Resource: {text(resource.id)}</small></li>)}</ul></>}
        {Number(data.resource_count) > 150 && <p>First 150 resource matches shown. Refine your search to find more.</p>}
        <h3>Recipes</h3><ul>{recipes.map(recipe => <li key={String(recipe.id)} data-result-type="recipe"><Button disabled={!ui.interactive} onClick={() => navigate(ui, { route: 'open', query: text(data.query), era: String(data.era ?? ''), processor: String(data.processor ?? ''), recipe: String(recipe.id) })}>{text(recipe.name)}</Button><br /><small>Recipe: {text(recipe.era_label)}</small></li>)}</ul>
        {Number(data.recipe_count) > 150 && <p>First 150 recipe matches shown. Refine filters to find more.</p>}
      </Section>
      <div>{data.detail ? <Recipe ui={ui} recipe={data.detail} graph /> : <NoticeBox>{Number(data.resource_count) > 0 ? 'No matching recipes. Select a Resource result to view acquisition routes and related recipes.' : 'No matching recipes or resources. Clear filters or search for an ingredient.'}</NoticeBox>}</div>
    </div> : list(data.entries).map((recipe, i) => <Recipe key={i} ui={ui} recipe={recipe} graph={false} />)}
  </>;
}
