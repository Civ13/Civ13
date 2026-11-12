import { useEffect, useLayoutEffect, useMemo, useRef, useState } from 'react';
import { Button, Section, NoticeBox } from 'tgui-core/components';
import type { Data, ScreenProps } from '../types';
import { Action, list, text } from './common';
import { Bar, Checks, FilterChips, RecipeTags, StateBadge, matches, minutes, nodeState, stateRank } from './researchShared';
export function lockedAncestors(nodes: Data[], id: string): Set<string> {
  const byId = new Map(nodes.map(node => [String(node.id), node]));
  const visited = new Set<string>();
  const locked = new Set<string>();
  const visit = (key: string) => {
    for (const parent of String(byId.get(key)?.prereq_ids ?? '').split(',')) {
      if (!parent || visited.has(parent)) continue;
      const node = byId.get(parent);
      visited.add(parent);
      if (node?.status_text === 'Locked') locked.add(parent);
      if (node) visit(parent);
    }
  };
  visit(id);
  return locked;
}
type FilterKey = 'all' | 'study' | 'ready' | 'progress' | 'known' | 'locked';
// Chapters that need groundwork, a better bench or more skill all read as "not yet".
export function filterKey(node: Data): FilterKey {
  const state = nodeState(node);
  return state === 'study_locked' || state === 'blocked' ? 'locked' : state;
}
const bookFilters: [FilterKey, string][] = [['all', 'All'], ['study', 'Ready to study'], ['ready', 'Can research'], ['progress', 'In progress'], ['known', 'Known'], ['locked', 'Not yet']];
const factionFilters: [FilterKey, string][] = [['all', 'All'], ['ready', 'Available'], ['progress', 'In progress'], ['known', 'Done'], ['locked', 'Locked']];
function costLine(node: Data, book: boolean): string {
  if (node.mode_text === 'Book only') return 'Book only';
  if (book && node.state_label) return text(node.state_label);
  return `${node.cost_ticks} ticks${node.mode_text === 'Prototype' ? ' + prototype' : ''}`;
}

function BenchSummary({ ui }: { ui: ScreenProps }) {
  const { data } = ui;
  return <Section title="Research bench"><p>Bench tier: {data.bench_tier} / {data.max_tier}</p>
    {!!data.tier_upgrade_cost && <p>Upgrade progress: {data.tier_progress}/{data.tier_upgrade_cost} silver in coins fed</p>}
    {!!data.era_capped && <NoticeBox>Capped at tier {data.era_max_tier} until your civilization reaches the next era.</NoticeBox>}
    <p>Owned by: {text(data.bench_faction) || 'Unclaimed'}</p>
    {!!data.has_faction && <><p>Viewing as: {text(data.viewer_role)} of the {text(data.viewer_faction)}</p><p>Your faction's benches: {data.viewer_bench_count} / {data.viewer_cap}</p></>}
    {data.can_claim ? <Action ui={ui} action="claim">Claim this bench for your faction</Action> : !!data.bench_faction && !data.owns_bench && <NoticeBox>This bench belongs to another faction. You can only observe it.</NoticeBox>}
  </Section>;
}

// Book research: the books lying on the bench, with every chapter one click away.
function BookShelf({ ui, open }: { ui: ScreenProps; open: (id: string) => void }) {
  const { data } = ui;
  const books = list(data.books);
  const viewer: Data = data.viewer ?? {};
  return <Section title="Books on the bench">
    <p className="rs-dim">Bench tier {data.bench_tier} / {data.max_tier}
      {!!data.tier_upgrade_cost && <> - next tier: {data.tier_progress}/{data.tier_upgrade_cost} silver in coins used on the bench</>}
      {!!data.era_capped && <> - the highest tier this era allows</>}</p>
    {!books.length && <NoticeBox>None. Place a book on the bench; research done here is written into it.</NoticeBox>}
    <div className="rs-books">{books.map(book => <div key={String(book.idx)} className={`rs-book ${book.is_target ? 'rs-book-target' : ''}`}>
      <div className="rs-book-head"><strong>{text(book.name)}</strong>
        <span className="rs-dim">{book.is_target ? 'Research is written here' : 'Second book'}</span>
        <span className="rs-book-actions">{!book.is_target && !!data.can_swap && <Action ui={ui} action="swap_books">Write research here</Action>}
          <Action ui={ui} action="take_book" value={Number(book.idx)}>Take</Action></span></div>
      {list(book.chapters).length ? <div className="rs-chapters">{list(book.chapters).map(chapter =>
        <button type="button" key={chapter.id} className={`rs-chapter rs-${chapter.state}`} title={chapter.state === 'known' ? 'You know this chapter' : chapter.state === 'study' ? 'You can study this chapter now' : 'You need its groundwork first'} onClick={() => open(String(chapter.id))}>
          {text(chapter.name)}{chapter.state === 'study' && <em> - study</em>}
        </button>)}</div> : <p className="rs-dim">No finished chapters yet.</p>}
      {list(book.unfinished).map(item => <div key={item.id} className="rs-unfinished">
        <button type="button" className="rs-link" onClick={() => open(String(item.id))}>{text(item.name)}</button> <span className="rs-dim">{item.percent}% written</span><Bar value={item.percent} label={`${text(item.name)} progress`} /></div>)}
      {Number(book.copy_missing) > 0 && <Action ui={ui} action="copy_all" value={Number(book.idx)}>Copy {book.copy_missing === 1 ? 'the 1 chapter' : `all ${book.copy_missing} chapters`} {text(book.other_name)} lacks</Action>}
    </div>)}</div>
    {!!data.book_room && !!books.length && <p className="rs-dim">There's room for one more book. With two, chapters can be copied between them.</p>}
    <p className="rs-you"><strong>You have:</strong> {viewer.tool ? <span className="tag">{text(viewer.tool)} in hand</span> : <span className="tag rs-warn">no pencil, pen or slate in hand</span>}
      <span className={`tag ${viewer.sheets ? '' : 'rs-warn'}`}>{Number(viewer.sheets) || 0} blank sheet{Number(viewer.sheets) === 1 ? '' : 's'}</span>
      {!!viewer.desk && <span className="tag">writing desk beside you</span>}
      {list(viewer.skills).filter(skill => Number(skill.level) > 0).map((skill, i) => <span className="tag" key={i}>{text(skill.name)} {skill.level}</span>)}</p>
  </Section>;
}

function Assigned({ ui, open }: { ui: ScreenProps; open: (id: string) => void }) {
  const { data } = ui;
  const assigned: Data | null = data.assigned ?? null;
  const queue = list(data.queue);
  if (!assigned && !queue.length) return null;
  return <Section title={assigned ? `Currently researching: ${text(assigned.name)}` : 'Research queue'}>
    {assigned && (assigned.done ? <>
      <p className="rs-good">The chapter is finished. Study it from the book to learn it.</p>
      {!!assigned.can_study && <Action ui={ui} action="study" value={assigned.id}>Study this chapter</Action>}
    </> : <>
      <div className="rs-progress-row"><Bar value={assigned.percent} label="Research progress" /><strong>{assigned.percent}%</strong></div>
      <p>{assigned.ticks} of {assigned.cost} points written into the book.{' '}
        {assigned.working ? <span className="rs-good">Work is going on{assigned.eta_minutes ? `: about ${minutes(assigned.eta_minutes)} left at this pace` : ''}.</span> : <span className="rs-bad">Nobody is working on it right now.</span>}</p>
      <Checks rows={assigned.checks} />
      <p className={Number(assigned.supply) >= 1 ? 'rs-dim' : 'rs-bad'}>{text(assigned.supply_text)}: {assigned.supply}/{assigned.supply_cap}{Number(assigned.supply) < 1 && ' - research runs at half speed until some are used on the bench'}</p>
      {!!assigned.library_bonus && <p className="rs-dim">Library nearby: research is {assigned.library_bonus}% faster.</p>}
      <Button onClick={() => open(String(assigned.id))}>Details</Button><Action ui={ui} action="stop_research">Stop researching</Action>
    </>)}
    {!!queue.length && <div className="rs-queue"><strong>Queued next:</strong> {queue.map((item, i) => <span className="tag" key={item.id}>{i + 1}. <button type="button" className="rs-link" onClick={() => open(String(item.id))}>{text(item.name)}</button> <button type="button" className="rs-link" disabled={!ui.interactive} aria-label={`Remove ${text(item.name)} from the queue`} onClick={() => ui.act('unqueue', { unqueue: item.id })}>x</button></span>)}
      <Action ui={ui} action="clear_queue">Clear queue</Action></div>}
  </Section>;
}

export function Research(ui: ScreenProps) {
  const { data } = ui;
  const book = !!data.book_mode;
  const trees = list(data.trees);
  const [active, setActive] = useState(0);
  const [selected, setSelected] = useState<string | null>(null);
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<FilterKey>('all');
  const [view, setView] = useState<'tree' | 'list'>('tree');
  const tree = trees.find(item => Number(item.idx) === active) ?? trees[0];
  const nodes = useMemo(() => trees.flatMap(t => list(t.layers).flatMap(layer => list(layer.nodes).map(node => ({ ...node, layer_name: layer.layer_name, tree_name: t.tree_name, tree_idx: t.idx })))), [data.trees]);
  const detail = nodes.find(node => String(node.id) === selected);
  const ancestors = selected ? lockedAncestors(nodes, selected) : new Set();
  const found = (node: Data) => matches(query, node.name, node.recipe_names, node.discipline, node.era_name, node.layer_name);
  const shown = (node: Data) => (filter === 'all' || filterKey(node) === filter) && found(node);
  const counts: Record<string, number> = { all: 0 };
  for (const node of nodes) if (found(node)) { counts.all++; const key = filterKey(node); counts[key] = (counts[key] ?? 0) + 1; }
  const narrowed = !!query.trim() || filter !== 'all';
  const hits = nodes.filter(shown);
  const open = (id: string) => {
    const node = nodes.find(item => String(item.id) === id);
    if (!node) return;
    setActive(Number(node.tree_idx) || 0);
    setSelected(id);
  };
  const graph = useRef<HTMLDivElement>(null);
  const [lines, setLines] = useState<{ paths: string[]; width: number; height: number }>({ paths: [], width: 0, height: 0 });
  useLayoutEffect(() => {
    const draw = () => {
      const wrap = graph.current;
      if (!wrap) return;
      const rect = wrap.getBoundingClientRect();
      const elements = Array.from(wrap.querySelectorAll<HTMLElement>('[data-node]'));
      const byId = new Map(elements.map(el => [el.dataset.node, el]));
      const paths: string[] = [];
      for (const child of elements) {
        for (const id of (child.dataset.prereqs ?? '').split(',')) {
          const parent = byId.get(id);
          if (!parent) continue;
          const p = parent.getBoundingClientRect(), c = child.getBoundingClientRect();
          const x1 = p.right - rect.left, y1 = p.top + p.height / 2 - rect.top;
          const x2 = c.left - rect.left, y2 = c.top + c.height / 2 - rect.top, mid = (x1 + x2) / 2;
          paths.push(`M${x1},${y1} C${mid},${y1} ${mid},${y2} ${x2},${y2}`);
        }
      }
      setLines({ paths, width: wrap.scrollWidth, height: wrap.scrollHeight });
    };
    draw();
    const observer = typeof ResizeObserver !== 'undefined' ? new ResizeObserver(draw) : null;
    if (graph.current) observer?.observe(graph.current);
    window.addEventListener('resize', draw);
    return () => { observer?.disconnect(); window.removeEventListener('resize', draw); };
  }, [data.trees, active, query, filter, view]);
  useEffect(() => {
    const close = (event: KeyboardEvent) => { if (event.key === 'Escape') setSelected(null); };
    document.addEventListener('keydown', close);
    return () => document.removeEventListener('keydown', close);
  }, []);
  const assignedId = book ? String(data.assigned?.id ?? '') : '';
  const quick = (node: Data) => {
    if (node.can_study) return <Action ui={ui} action="study" value={node.id}>Study</Action>;
    if (node.assignable && String(node.id) !== assignedId && nodeState(node) !== 'known') return <Action ui={ui} action="assign" value={node.id}>{book ? 'Research' : 'Assign'}</Action>;
    if (node.can_write) return <Action ui={ui} action="write" value={node.id}>Write</Action>;
    return null;
  };
  return <>
    {book ? <BookShelf ui={ui} open={open} /> : <BenchSummary ui={ui} />}
    {!!data.owns_bench && (!!data.is_leader || !!data.is_director) && <Section title="Research staff">
      {!!data.is_leader && <>{data.has_director ? <><Action ui={ui} action="appoint_director">Reassign {text(data.director_title)}</Action><Action ui={ui} action="set_director_title">Rename role</Action><Action ui={ui} action="dismiss_director">Dismiss {text(data.director_title)}</Action></> : <Action ui={ui} action="appoint_director">Appoint a Research Director</Action>}</>}
      <Action ui={ui} action="appoint_researcher">Appoint a Researcher</Action><Action ui={ui} action="dismiss_researcher">Dismiss a Researcher</Action>
    </Section>}
    {book ? <Assigned ui={ui} open={open} /> : <>
      {!!data.assigned_name && <Section title={`Currently researching: ${text(data.assigned_name)}`}>{data.assigned_done ? 'Completed! Open any completed tech below to write research notes or a book on it.' : text(data.assigned_status_text)}</Section>}
      {!!list(data.queue_names).length && <Section title="Queued next">{list(data.queue_names).map((name, i) => <span className="tag" key={i}>{text(name)}</span>)}{!!data.can_queue && <Action ui={ui} action="clear_queue">Clear queue</Action>}</Section>}
    </>}
    <Section title="Research trees">
      <div className="rs-toolbar">
        <label className="rs-search">Find technology <input type="search" value={query} placeholder="Name, recipe or discipline" onChange={event => setQuery(event.target.value)} /></label>
        <div role="group" aria-label="Layout"><Button selected={view === 'tree'} onClick={() => setView('tree')}>Tree</Button><Button selected={view === 'list'} onClick={() => setView('list')}>List</Button></div>
      </div>
      <FilterChips options={book ? bookFilters : factionFilters} value={filter} counts={counts} onChange={setFilter} />
      {view === 'tree' ? <>
        <div role="tablist">{trees.map(item => {
          const inTree = hits.filter(node => node.tree_idx === item.idx).length;
          return <Button key={item.idx} selected={item === tree} onClick={() => setActive(Number(item.idx))}>{text(item.tree_name)}{narrowed && ` (${inTree})`}</Button>;
        })}</div>
        <div className="research-scroll"><div className="research-graph" ref={graph}>
          <svg className="research-lines" width={lines.width} height={lines.height} aria-hidden="true">{lines.paths.map((path, i) => <path key={i} d={path} />)}</svg>
          {list(tree?.layers).map((layer, i) => <section key={i}><h3>{text(layer.layer_name)}</h3><div className="research-layer">{list(layer.nodes).map(node => {
            const state = nodeState(node);
            const percent = Number(node.progress_percent) || 0;
            return <button key={node.id} type="button" data-node={node.id} data-prereqs={node.prereq_ids} className={`research-node rs-${state} ${state === 'known' ? 'done' : state === 'locked' ? 'locked' : ''} ${ancestors.has(String(node.id)) ? 'ancestor' : ''} ${selected === String(node.id) ? 'selected' : ''} ${shown({ ...node, layer_name: layer.layer_name }) ? '' : 'muted'}`} style={{ gridColumn: Math.max(1, Number(node.grid_col) || 1) }} onClick={() => setSelected(String(node.id))}>
              <strong>{text(node.name)}{!!node.is_era_changing && <span title="Advances the era"> ★</span>}</strong><small>{costLine(node, book)}</small>
              {Number(node.queue_pos) > 0 && <small className="rs-queued">Queued #{node.queue_pos}</small>}
              {String(node.id) === assignedId && <small className="rs-queued">Being researched</small>}
              {percent > 0 && percent < 100 && <Bar value={percent} />}
            </button>;
          })}</div></section>)}
        </div></div>
      </> : <div className="rs-list">
        {!hits.length && <p className="rs-dim">Nothing matches.</p>}
        {[...hits].sort((a, b) => stateRank(a) - stateRank(b) || Number(a.era_tier) - Number(b.era_tier) || text(a.name).localeCompare(text(b.name))).map(node => <div key={node.id} className="rs-row">
          <button type="button" className="rs-row-main" onClick={() => open(String(node.id))}>
            <strong>{text(node.name)}{!!node.is_era_changing && ' ★'}</strong>
            <small>{text(node.tree_name)} - {text(node.layer_name)}{node.era_name ? ` - ${text(node.era_name)}` : ''}{node.discipline ? ` - ${text(node.discipline)}` : ''}</small>
          </button>
          <StateBadge node={node} long />
          <span className="rs-row-action">{quick(node)}</span>
        </div>)}
      </div>}
    </Section>
    {detail && <div className="modal-backdrop" onClick={() => setSelected(null)}><section role="dialog" aria-modal="true" aria-label={text(detail.name)} className="detail-modal" onClick={event => event.stopPropagation()}>
      <Button onClick={() => setSelected(null)}>Close</Button><h2>{text(detail.name)}{!!detail.is_era_changing && ' ★'}</h2>
      <p>{text(detail.layer_name)} - {detail.era_name ? text(detail.era_name) : `era ${detail.era_tier}`}{detail.discipline ? ` - ${text(detail.discipline)}` : ''} - {text(detail.mode_text)}{!!detail.is_era_changing && ' - advances the era'}</p>
      {book ? <>
        <p><StateBadge node={detail} long /></p>
        <div className="rs-actions">
          {!!detail.can_study && <Action ui={ui} action="study" value={detail.id}>{Number(detail.read_percent) > 0 ? `Continue this chapter (${detail.read_percent}% read, about ${minutes(detail.study_minutes)} left)` : `Study this chapter (about ${minutes(detail.study_minutes)})`}</Action>}
          {!!detail.assignable && String(detail.id) !== assignedId && <Action ui={ui} action="assign" value={detail.id}>Research this here</Action>}
          {String(detail.id) === assignedId && !data.assigned?.done && <Action ui={ui} action="stop_research">Stop researching</Action>}
          {!!detail.queueable && <Action ui={ui} action="queue" value={detail.id}>Add to queue</Action>}
          {Number(detail.queue_pos) > 0 && <Action ui={ui} action="unqueue" value={detail.id}>Remove from queue</Action>}
          {!!detail.can_copy && <Action ui={ui} action="copy" value={detail.id}>Copy into the other book</Action>}
          {!!detail.can_write && <Action ui={ui} action="write" value={detail.id}>Write it from memory (about {minutes(detail.write_minutes)})</Action>}
        </div>
        {nodeState(detail) === 'progress' && <><Bar value={detail.progress_percent} label="Research progress" /><p className="rs-dim">{detail.progress_percent}% written into the research book.</p></>}
        <h3>Groundwork</h3>
        {list(detail.groundwork).length ? <ul className="rs-checks">{list(detail.groundwork).map(item => <li key={item.id} className={item.known ? 'rs-ok' : 'rs-missing'}>
          <span aria-hidden="true">{item.known ? '✓' : '✗'}</span> <button type="button" className="rs-link" onClick={() => open(String(item.id))}>{text(item.name)}</button> <span className="rs-dim">{item.known ? 'known' : 'not known yet'}</span></li>)}</ul> : <p className="rs-dim">None. Anyone can study or research this.</p>}
        {nodeState(detail) !== 'known' && detail.mode_text !== 'Book only' && <><h3>To research it at this bench</h3>
          <Checks rows={detail.research_needs} />
          <p className="rs-dim">{detail.cost_ticks} points of work, about {minutes(detail.research_minutes)} at your pace with supplies. Studying a finished chapter takes about {minutes(detail.study_minutes)}.</p></>}
      </> : <>
        <h3>Status</h3><p>{text(detail.status_text)} - {text(detail.detail)}</p>
        {detail.mode_text !== 'Book only' && <><Bar value={detail.progress_percent} label="Research progress" />{detail.mode_text === 'Prototype' && <p>Also requires a working {text(detail.prototype_name) || 'prototype'} fed to the bench - the full study alone will not finish it.</p>}</>}
        <p>Minimum bench tier: {detail.min_bench_tier}</p><h3>Requires</h3><p>{text(detail.prereq_names)}</p>
      </>}
      {(() => {
        const next = nodes.filter(node => String(node.prereq_ids ?? '').split(',').includes(String(detail.id)));
        return !!next.length && <><h3>Leads to</h3><p>{next.map(node => <button type="button" key={node.id} className="rs-link rs-lead" onClick={() => open(String(node.id))}>{text(node.name)}</button>)}</p></>;
      })()}
      <h3>Unlocks {list(detail.recipe_names).length} recipes</h3>{list(detail.recipe_names).length ? <RecipeTags names={detail.recipe_names} /> : 'None yet'}
      {!!detail.effect && <><h3>Knowing it</h3><p>{text(detail.effect)}</p></>}
      {!book && <div>{!!detail.assignable && <Action ui={ui} action="assign" value={detail.id}>Assign this bench</Action>}{!!detail.can_write_notes && <Action ui={ui} action="write_notes" value={detail.id}>Write Research Notes (quick, boosts a buyer)</Action>}{!!detail.can_write_book && <Action ui={ui} action="write_book" value={detail.id}>Write Research Book (slow, completes for a buyer)</Action>}{!!detail.queueable && <Action ui={ui} action="queue" value={detail.id}>Add to research queue</Action>}</div>}
    </section></div>}
  </>;
}
