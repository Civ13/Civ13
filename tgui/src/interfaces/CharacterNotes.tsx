import { Fragment, type ReactNode } from 'react';
import { Section } from 'tgui-core/components';
import type { Data, ScreenProps } from '../types';
import { text } from './common';

const named = new Set(['amp', 'lt', 'gt', 'quot', 'apos', 'AMP', 'LT', 'GT', 'QUOT']);
export function notesText(encoded: string): string {
  if (encoded.includes('<') || /[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(encoded)) throw new Error('Unsupported Notes text');
  for (const match of encoded.matchAll(/&(?=[A-Za-z#])/g)) {
    const start = match.index + 1, end = encoded.indexOf(';', start);
    if (end < 0 || end - start > 16) throw new Error('Unsupported Notes entity');
    const entity = encoded.slice(start, end);
    if (named.has(entity)) continue;
    if (!/^#[0-9]{1,7}$/.test(entity)) throw new Error('Unsupported Notes entity');
    const point = Number(entity.slice(1));
    if (point <= 0 || point > 0x10ffff || (point >= 0xd800 && point <= 0xdfff) || (point >= 127 && point <= 159) || (point < 32 && ![9, 10, 13].includes(point))) throw new Error('Unsupported Notes entity');
  }
  // Exactly one pure text decode. Never insert HTML or decode a second time.
  return text(encoded);
}
const flag = (value: unknown): boolean => {
  if (value === true || value === 1) return true;
  if (value === false || value === 0) return false;
  throw new Error('Invalid Notes formatting flag');
};
function parseView(data: Data) {
  let nodes = 0, units = 0;
  const take = () => { if (++nodes > 2048) throw new Error('Notes node budget'); };
  const array = (value: unknown): any[] => { if (!Array.isArray(value) || value.length > 2048) throw new Error('Invalid Notes array'); return value; };
  const runs = (value: unknown): ReactNode[] => array(value).map((run, index) => {
    take(); if (!run || typeof run !== 'object' || Array.isArray(run)) throw new Error('Invalid Notes run');
    if (Object.keys(run).length === 1 && (run.br === true || run.br === 1)) return <br key={index} />;
    if (Object.keys(run).sort().join(',') !== 'bold,italic,text' || typeof run.text !== 'string') throw new Error('Invalid Notes run');
    units += run.text.length; if (units > 65536) throw new Error('Notes text budget');
    let content: ReactNode = notesText(run.text);
    if (flag(run.italic)) content = <em>{content}</em>;
    if (flag(run.bold)) content = <strong>{content}</strong>;
    return <Fragment key={index}>{content}</Fragment>;
  });
  const character = runs(data.character);
  const sections = array(data.sections).map(section => {
    take(); if (!section || typeof section !== 'object') throw new Error('Invalid Notes section');
    const title = runs(section.title);
    const entries = array(section.entries).map(entry => { take(); if (!entry || typeof entry !== 'object') throw new Error('Invalid Notes entry'); return runs(entry.runs); });
    return { title, entries };
  });
  return { character, sections, memory: runs(data.memory), discoveries: runs(data.discoveries) };
}
export function CharacterNotes({ data }: ScreenProps) {
  // Complete validation precedes rendering. Existing application boundary sends
  // malformed/out-of-budget snapshots to the server's cached classic fallback.
  const view = parseView(data);
  return <Section><article className="character-notes" aria-label="Character notes">
    <p><strong>You are {view.character}</strong></p><hr />
    {view.sections.map((section, index) => <section key={index}>
      <h2>{section.title}</h2>
      {section.entries.map((entry, entryIndex) => <Fragment key={entryIndex}><em>{entry}</em>{entryIndex < section.entries.length - 1 && <br />}</Fragment>)}
    </section>)}
    <section><h2>Memories</h2><em>{view.memory}</em></section>
    <section aria-label="Discoveries">{view.discoveries}</section>
    <p><em>Use the 'Notes' verb in the 'IC' tab to re-open this window.</em></p>
  </article></Section>;
}
