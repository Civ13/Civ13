import type { ReactNode } from 'react';
import { NoticeBox, Section } from 'tgui-core/components';
import type { Data, ScreenProps } from '../types';
import { Action, list, text } from './common';

// Shared parts for Civ13 screens. Build a screen from these before writing new
// markup or CSS; colours come from the --civ-* palette in styles.scss.

// One table for every read-only list. The first column is the row header.
export type Column = { label: string; align?: 'right'; cell: (row: Data) => ReactNode };
export function SnapshotTable({ label, rows, columns, hint, empty }: { label: string; rows: unknown; columns: Column[]; hint?: string; empty: string }) {
  const items = list(rows);
  return <Section>
    {hint && <p className="kit-hint">{hint}</p>}
    {items.length ? <table className="kit-table" aria-label={label}>
      <thead><tr>{columns.map((column, c) => <th key={c} scope="col" className={column.align === 'right' ? 'kit-right' : undefined}>{column.label}</th>)}</tr></thead>
      <tbody>{items.map((item, i) => <tr key={i}>{columns.map((column, c) => c === 0
        ? <th key={c} scope="row">{column.cell(item)}</th>
        : <td key={c} className={column.align === 'right' ? 'kit-right' : undefined}>{column.cell(item)}</td>)}</tr>)}</tbody>
    </table> : <NoticeBox>{empty}</NoticeBox>}
  </Section>;
}
// A short state label. Tone carries meaning: good, warn, info or plain.
export function Pill({ tone = 'plain', children }: { tone?: 'plain' | 'good' | 'warn' | 'info'; children: ReactNode }) {
  return <span className={`kit-pill kit-pill-${tone}`}>{children}</span>;
}
// Mutually exclusive choices sent as one action; the current one is marked.
export function Choice({ ui, action, value, options, label }: { ui: ScreenProps; action: string; value: unknown; options: [string | number, string][]; label?: string }) {
  return <span className="kit-choice" role="group" aria-label={label}>{options.map(([key, name]) =>
    <Action key={key} ui={ui} action={action} value={key} selected={value === key}>{name}</Action>)}</span>;
}
// Requirement lines that say plainly whether each is met.
export function CheckList({ rows }: { rows: { ok: boolean | null; label: ReactNode }[] }) {
  if (!rows.length) return null;
  return <ul className="kit-checks">{rows.map((row, i) => <li key={i} className={row.ok === null ? undefined : row.ok ? 'kit-ok' : 'kit-no'}>
    {row.ok !== null && <span aria-hidden="true">{row.ok ? '✓ ' : '✗ '}</span>}{row.label}</li>)}</ul>;
}
// Label and value pairs with an optional control on the right.
export function Rows({ children }: { children: ReactNode }) { return <dl className="kit-rows">{children}</dl>; }
export function Row({ label, buttons, children }: { label: ReactNode; buttons?: ReactNode; children: ReactNode }) {
  return <div className="kit-row"><dt>{label}</dt><dd>{children}</dd>{buttons ? <dd className="kit-row-buttons">{buttons}</dd> : null}</div>;
}
export function Card({ children }: { children: ReactNode }) { return <div className="kit-card">{children}</div>; }
export const cell = (key: string, unit?: string) => (row: Data) => unit ? `${text(row[key])} ${text(row[unit])}` : text(row[key]);
