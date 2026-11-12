import { useState } from 'react';
import type { Data } from '../types';
import { list, text } from './common';

// One vocabulary for both research modes. Book research sends `state`; the
// faction tree only sends status_text, which maps onto the same names.
export type NodeState = 'known' | 'study' | 'study_locked' | 'progress' | 'ready' | 'blocked' | 'locked';
const legacyStates: Record<string, NodeState> = { Done: 'known', 'In Progress': 'progress', Available: 'ready', Locked: 'locked' };
export function nodeState(node: Data): NodeState {
  return (node.state as NodeState) ?? legacyStates[String(node.status_text)] ?? 'locked';
}
// What to look at first: things the reader can act on, then the rest.
export const stateOrder: NodeState[] = ['study', 'ready', 'progress', 'study_locked', 'blocked', 'locked', 'known'];
export const stateRank = (node: Data) => stateOrder.indexOf(nodeState(node));
const shortLabels: Record<NodeState, string> = { known: 'Known', study: 'Study', study_locked: 'Chapter', progress: 'In progress', ready: 'Research', blocked: 'Blocked', locked: 'Locked' };
export function StateBadge({ node, long = false }: { node: Data; long?: boolean }) {
  const state = nodeState(node);
  return <span className={`rs-badge rs-${state}`}>{long ? text(node.state_label ?? node.status_text ?? shortLabels[state]) : shortLabels[state]}</span>;
}
export function minutes(value: unknown): string {
  const n = Number(value) || 0;
  if (n >= 90) return `${Math.round(n / 6) / 10} hours`;
  return `${n} minute${n === 1 ? '' : 's'}`;
}
export function Bar({ value, label }: { value: unknown; label?: string }) {
  const percent = Math.max(0, Math.min(100, Number(value) || 0));
  return <div className="rs-bar" role="progressbar" aria-valuemin={0} aria-valuemax={100} aria-valuenow={percent} aria-label={label}><div style={{ width: `${percent}%` }} /></div>;
}
// A requirement list: each line says plainly whether it is met.
export function FieldWork({ rows }: { rows: unknown }) {
  const items = list(rows);
  if (!items.length) return null;
  return <><h3>Field work</h3><p className="rs-dim">Optional. Someone who has done the work stands at the bench and it is written into the book.</p>
    <ul className="rs-checks">{items.map((row, i) => <li key={i} className={row.done ? 'rs-ok' : 'rs-dim'}>
      <span aria-hidden="true">{row.done ? '✓' : '○'}</span> {text(row.label)}: {row.percent}% of the work
      <span className="rs-dim"> ({row.done ? 'in the book' : `you have ${row.have} of ${row.needed}`})</span>
    </li>)}</ul></>;
}

export function Checks({ rows }: { rows: unknown }) {
  const items = list(rows);
  if (!items.length) return null;
  return <ul className="rs-checks">{items.map((row, i) => <li key={i} className={row.ok ? 'rs-ok' : 'rs-missing'}>
    <span aria-hidden="true">{row.ok ? '✓' : '✗'}</span> {text(row.label)}<span className="rs-sr"> ({row.ok ? 'met' : 'not met'})</span>
  </li>)}</ul>;
}
// Long recipe lists stay short until asked for.
export function RecipeTags({ names, limit = 18 }: { names: unknown; limit?: number }) {
  const all = list(names);
  const [open, setOpen] = useState(false);
  if (!all.length) return <span className="rs-dim">Nothing yet</span>;
  const shown = open ? all : all.slice(0, limit);
  return <>{shown.map((name, i) => <span className="tag" key={i}>{text(name)}</span>)}
    {all.length > limit && <button type="button" className="rs-link" onClick={() => setOpen(!open)}>{open ? 'Show fewer' : `and ${all.length - limit} more`}</button>}</>;
}
export function matches(query: string, ...fields: unknown[]): boolean {
  const words = query.toLowerCase().split(/\s+/).filter(Boolean);
  if (!words.length) return true;
  const hay = fields.flat(2).map(field => text(field).toLowerCase()).join('\n');
  return words.every(word => hay.includes(word));
}
export function FilterChips<T extends string>({ options, value, counts, onChange }: {
  options: [T, string][]; value: T; counts: Record<string, number>; onChange: (next: T) => void;
}) {
  return <div className="rs-chips" role="group" aria-label="Show">{options.map(([key, label]) =>
    <button type="button" key={key} className={`rs-chip ${value === key ? 'rs-chip-on' : ''}`} aria-pressed={value === key} onClick={() => onChange(key)}>
      {label} <span className="rs-count">{counts[key] ?? 0}</span>
    </button>)}</div>;
}
