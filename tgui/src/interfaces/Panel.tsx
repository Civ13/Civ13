import { NoticeBox, Section } from 'tgui-core/components';
import type { PanelButton, PanelData } from '../data';
import type { ScreenProps } from '../types';
import { Action, list, str } from './common';
import { Pill, Row, Rows, type Tone } from './kit';

// One screen for every simple machine or menu: the server describes sections of
// notes, labelled rows, item lists and buttons, and the owner declares which
// actions those buttons may send. A window needs its own screen only when this
// one cannot show it.
const tones = new Set<string>(['good', 'warn', 'info', 'ready', 'progress', 'muted']);
function Buttons({ ui, rows }: { ui: ScreenProps; rows?: PanelButton[] }) {
  return <>{list(rows).map((button, i) => button.action
    ? <Action key={i} ui={ui} action={str(button.action)} value={button.id ?? 1} disabled={!!button.disabled} selected={!!button.selected}>{str(button.label)}</Action>
    : null)}</>;
}
export function Panel(ui: ScreenProps<PanelData>) {
  const { data } = ui;
  return <div className="kit-panel">
    {list(data.notes).map((note, i) => <p key={i} className="kit-note">{str(note)}</p>)}
    {list(data.sections).map((section, s) => {
      const rows = list(section.rows), items = list(section.items), buttons = list(section.buttons);
      return <Section key={s} title={section.title ? str(section.title) : undefined}>
        {list(section.notes).map((note, i) => <p key={i} className="kit-note">{str(note)}</p>)}
        {!!rows.length && <Rows>{rows.map((row, i) => <Row key={i} label={str(row.label)} buttons={list(row.buttons).length ? <Buttons ui={ui} rows={row.buttons} /> : undefined}>
          {row.tone && tones.has(row.tone) ? <Pill tone={row.tone as Tone}>{str(row.value)}</Pill> : str(row.value)}</Row>)}</Rows>}
        {!!items.length && <table className="kit-table" aria-label={section.title ? str(section.title) : 'Items'}><tbody>{items.map((item, i) => <tr key={i}>
          <th scope="row">{str(item.name)}{item.detail ? <p className="kit-hint">{str(item.detail)}</p> : null}</th>
          <td className="kit-right"><Buttons ui={ui} rows={item.buttons} /></td></tr>)}</tbody></table>}
        {!rows.length && !items.length && !!section.empty && <NoticeBox>{str(section.empty)}</NoticeBox>}
        {!!buttons.length && <div className="kit-actions"><Buttons ui={ui} rows={buttons} /></div>}
      </Section>;
    })}
  </div>;
}
