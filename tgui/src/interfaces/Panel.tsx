import { NoticeBox, Section } from 'tgui-core/components';
import type { PanelButton, PanelCell, PanelData, PanelSection } from '../data';
import type { ScreenProps } from '../types';
import { Action, list, str } from './common';
import { Pill, Row, Rows, type Tone } from './kit';

// One screen for every simple machine or menu: the server describes sections of
// notes, labelled rows, item lists and buttons, and the owner declares which
// actions those buttons may send. A window needs its own screen only when this
// one cannot show it.
// Only a bare file name the server sent beforehand; never a URL.
const picture = /^[\w-]+\.png$/;
const tones = new Set<string>(['good', 'warn', 'info', 'ready', 'progress', 'muted']);
function Buttons({ ui, rows }: { ui: ScreenProps; rows?: PanelButton[] }) {
  return <>{list(rows).map((button, i) => button.action
    ? <Action key={i} ui={ui} action={str(button.action)} value={button.id ?? 1} disabled={!!button.disabled} selected={!!button.selected}>{str(button.label)}</Action>
    : null)}</>;
}
const toned = (tone: unknown, text: unknown) => typeof tone === 'string' && tones.has(tone) ? <Pill tone={tone as Tone}>{str(text)}</Pill> : str(text);
function Cell({ cell }: { cell: PanelCell }) {
  return <>{cell !== null && typeof cell === 'object' ? toned(cell.tone, cell.text) : str(cell)}</>;
}
// Lines over a fixed number of time slots; a short series sits against the right edge.
const W = 360, H = 120;
function Chart({ chart }: { chart: NonNullable<PanelSection['chart']> }) {
  const series = list(chart.series).map(line => ({ ...line, points: list(line.points).map(Number).filter(Number.isFinite) }));
  const slots = Math.max(2, Number(chart.slots) || 2, ...series.map(line => line.points.length));
  const top = Math.max(1, ...series.flatMap(line => line.points));
  return <figure className="kit-chart">
    <svg viewBox={`0 0 ${W} ${H}`} role="img" aria-label={series.map(line => str(line.label)).join(' and ')}>
      <line x1={0} y1={H - 1} x2={W} y2={H - 1} className="kit-chart-axis" />
      {series.map((line, i) => line.points.length ? <polyline key={i} className={`kit-chart-line kit-chart-${tones.has(str(line.tone)) ? str(line.tone) : 'info'}`}
        points={line.points.map((value, p) => `${((slots - line.points.length + p) * W / (slots - 1)).toFixed(1)},${(H - 1 - (value / top) * (H - 21)).toFixed(1)}`).join(' ')} /> : null)}
    </svg>
    <figcaption><span>{str(chart.left)}</span><span>{series.map((line, i) => <span key={i} className={`kit-chart-key kit-chart-${tones.has(str(line.tone)) ? str(line.tone) : 'info'}`}>{str(line.label)}</span>)}{chart.top ? ` (top ${str(chart.top)})` : ''}</span><span>{str(chart.right)}</span></figcaption>
  </figure>;
}
export function Panel(ui: ScreenProps<PanelData>) {
  const { data } = ui;
  return <div className="kit-panel">
    {list(data.notes).map((note, i) => <p key={i} className="kit-note">{str(note)}</p>)}
    {list(data.sections).map((section, s) => {
      const rows = list(section.rows), items = list(section.items), buttons = list(section.buttons), lines = list(section.table?.rows);
      return <Section key={s} title={section.title ? str(section.title) : undefined}>
        {list(section.notes).map((note, i) => <p key={i} className="kit-note">{str(note)}</p>)}
        {!!rows.length && <Rows>{rows.map((row, i) => <Row key={i} label={str(row.label)} buttons={list(row.buttons).length ? <Buttons ui={ui} rows={row.buttons} /> : undefined}>
          {toned(row.tone, row.value)}</Row>)}</Rows>}
        {!!items.length && <table className="kit-table" aria-label={section.title ? str(section.title) : 'Items'}><tbody>{items.map((item, i) => <tr key={i}>
          <th scope="row">{picture.test(str(item.image)) ? <img className="kit-item-image" src={str(item.image)} width={32} height={32} alt="" /> : null}{str(item.name)}{item.detail ? <p className="kit-hint">{str(item.detail)}</p> : null}</th>
          <td className="kit-right"><Buttons ui={ui} rows={item.buttons} /></td></tr>)}</tbody></table>}
        {!!lines.length && <table className="kit-table" aria-label={section.title ? str(section.title) : 'Table'}>
          <thead><tr>{list(section.table?.columns).map((column, c) => <th key={c} scope="col">{str(column)}</th>)}</tr></thead>
          <tbody>{lines.map((line, i) => <tr key={i}>{list(line).map((cell, c) => c === 0 ? <th key={c} scope="row"><Cell cell={cell} /></th> : <td key={c}><Cell cell={cell} /></td>)}</tr>)}</tbody></table>}
        {section.chart ? <Chart chart={section.chart} /> : null}
        {!rows.length && !items.length && !lines.length && !!section.empty && <NoticeBox>{str(section.empty)}</NoticeBox>}
        {!!buttons.length && <div className="kit-actions"><Buttons ui={ui} rows={buttons} /></div>}
      </Section>;
    })}
  </div>;
}
