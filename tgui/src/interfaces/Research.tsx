import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { Button, Section, NoticeBox } from 'tgui-core/components';
import type { Data, ScreenProps } from '../types';
import { Action, list, text } from './common';
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
function Progress({ value }: { value: unknown }) {
  return <progress max={100} value={Math.max(0, Math.min(100, Number(value) || 0))} />;
}
export function Research(ui: ScreenProps) {
  const { data } = ui;
  const trees = list(data.trees);
  const [active, setActive] = useState(0);
  const [selected, setSelected] = useState<string | null>(null);
  const [query, setQuery] = useState('');
  const tree = trees.find(item => Number(item.idx) === active) ?? trees[0];
  const nodes = trees.flatMap(t => list(t.layers).flatMap(layer => list(layer.nodes).map(node => ({ ...node, layer_name: layer.layer_name }))));
  const detail = nodes.find(node => String(node.id) === selected);
  const ancestors = selected ? lockedAncestors(nodes, selected) : new Set();
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
  }, [data.trees, active, query]);
  useEffect(() => {
    const close = (event: KeyboardEvent) => { if (event.key === 'Escape') setSelected(null); };
    document.addEventListener('keydown', close);
    return () => document.removeEventListener('keydown', close);
  }, []);
  return <>
    <Section title="Research bench"><p>Bench tier: {data.bench_tier} / {data.max_tier}</p>
      {!!data.tier_upgrade_cost && <p>Upgrade progress: {data.tier_progress}/{data.tier_upgrade_cost} silver in coins fed</p>}
      {!!data.era_capped && <NoticeBox>Capped at tier {data.era_max_tier} until your civilization reaches the next era.</NoticeBox>}
      <p>Owned by: {text(data.bench_faction) || 'Unclaimed'}</p>
      {!!data.has_faction && <><p>Viewing as: {text(data.viewer_role)} of the {text(data.viewer_faction)}</p><p>Your faction's benches: {data.viewer_bench_count} / {data.viewer_cap}</p></>}
      {data.can_claim ? <Action ui={ui} action="claim">Claim this bench for your faction</Action> : !!data.bench_faction && !data.owns_bench && <NoticeBox>This bench belongs to another faction. You can only observe it.</NoticeBox>}
    </Section>
    {!!data.owns_bench && (!!data.is_leader || !!data.is_director) && <Section title="Research staff">
      {!!data.is_leader && <>{data.has_director ? <><Action ui={ui} action="appoint_director">Reassign {text(data.director_title)}</Action><Action ui={ui} action="set_director_title">Rename role</Action><Action ui={ui} action="dismiss_director">Dismiss {text(data.director_title)}</Action></> : <Action ui={ui} action="appoint_director">Appoint a Research Director</Action>}</>}
      <Action ui={ui} action="appoint_researcher">Appoint a Researcher</Action><Action ui={ui} action="dismiss_researcher">Dismiss a Researcher</Action>
    </Section>}
    {!!data.assigned_name && <Section title={`Currently researching: ${text(data.assigned_name)}`}>{data.assigned_done ? 'Completed! Open any completed tech below to write research notes or a book on it.' : text(data.assigned_status_text)}</Section>}
    {!!list(data.queue_names).length && <Section title="Queued next">{list(data.queue_names).map((name, i) => <span className="tag" key={i}>{text(name)}</span>)}{!!data.can_queue && <Action ui={ui} action="clear_queue">Clear queue</Action>}</Section>}
    <Section title="Research trees"><div role="tablist">{trees.map(item => <Button key={item.idx} selected={item === tree} onClick={() => setActive(Number(item.idx))}>{text(item.tree_name)}</Button>)}</div>
      <label>Find technology <input value={query} onChange={event => setQuery(event.target.value)} /></label>
      <div className="research-scroll"><div className="research-graph" ref={graph}>
        <svg className="research-lines" width={lines.width} height={lines.height} aria-hidden="true">{lines.paths.map((path, i) => <path key={i} d={path} />)}</svg>
        {list(tree?.layers).map((layer, i) => <section key={i}><h3>{text(layer.layer_name)}</h3><div className="research-layer">{list(layer.nodes).map(node => {
          const match = !query || text(node.name).toLowerCase().includes(query.toLowerCase());
          return <button key={node.id} type="button" data-node={node.id} data-prereqs={node.prereq_ids} className={`research-node ${node.status_text === 'Done' ? 'done' : node.status_text === 'Locked' ? 'locked' : ''} ${ancestors.has(String(node.id)) ? 'ancestor' : ''} ${selected === String(node.id) ? 'selected' : ''} ${match ? '' : 'muted'}`} style={{ gridColumn: Math.max(1, Number(node.grid_col) || 1) }} onClick={() => setSelected(String(node.id))}>
            <strong>{text(node.name)}{!!node.is_era_changing && <span title="Advances the era"> ★</span>}</strong><small>{node.mode_text === 'Book only' ? 'Book only' : `${node.cost_ticks} ticks${node.mode_text === 'Prototype' ? ' + prototype' : ''}`}</small><Progress value={node.progress_percent} />
          </button>;
        })}</div></section>)}
      </div></div>
    </Section>
    {detail && <div className="modal-backdrop" onClick={() => setSelected(null)}><section role="dialog" aria-modal="true" aria-label={text(detail.name)} className="detail-modal" onClick={event => event.stopPropagation()}>
      <Button onClick={() => setSelected(null)}>Close</Button><h2>{text(detail.name)}{!!detail.is_era_changing && ' ★'}</h2>
      <p>{text(detail.layer_name)} - era {detail.era_tier} - {text(detail.mode_text)}{!!detail.is_era_changing && ' - advances the era'}</p>
      <h3>Status</h3><p>{text(detail.status_text)} - {text(detail.detail)}</p>
      {detail.mode_text !== 'Book only' && <><Progress value={detail.progress_percent} />{detail.mode_text === 'Prototype' && <p>Also requires a working {text(detail.prototype_name) || 'prototype'} fed to the bench - the full study alone will not finish it.</p>}</>}
      <p>Minimum bench tier: {detail.min_bench_tier}</p><h3>Requires</h3><p>{text(detail.prereq_names)}</p>
      <h3>Unlocks {list(detail.recipe_names).length} recipes</h3>{list(detail.recipe_names).length ? list(detail.recipe_names).map((name, i) => <span className="tag" key={i}>{text(name)}</span>) : 'None yet'}
      <div>{!!detail.assignable && <Action ui={ui} action="assign" value={detail.id}>Assign this bench</Action>}{!!detail.can_write_notes && <Action ui={ui} action="write_notes" value={detail.id}>Write Research Notes (quick, boosts a buyer)</Action>}{!!detail.can_write_book && <Action ui={ui} action="write_book" value={detail.id}>Write Research Book (slow, completes for a buyer)</Action>}{!!detail.queueable && <Action ui={ui} action="queue" value={detail.id}>Add to research queue</Action>}</div>
    </section></div>}
  </>;
}
