import { useState } from 'react';
import { NoticeBox, Section } from 'tgui-core/components';
import type { Data, ScreenProps } from '../types';
import { Action, list, str } from './common';
import { Pill } from './kit';
import { Bar, FilterChips, RecipeTags, matches, minutes, stateTone } from './researchShared';

type ChapterFilter = 'all' | 'study' | 'locked' | 'known';
const filters: [ChapterFilter, string][] = [['all', 'All'], ['study', 'Ready to study'], ['locked', 'Needs groundwork'], ['known', 'Known']];
const order: Record<string, number> = { study: 0, blocked: 1, locked: 2, known: 3 };
const labels: Record<string, string> = { study: 'Ready to study', blocked: 'Cannot study yet', locked: 'Needs groundwork', known: 'Known' };

// The window for a book that holds research: what is in it, what the reader
// can study now, what is still missing, and what they could write into it.
export function ResearchBook(ui: ScreenProps) {
  const { data } = ui;
  const [query, setQuery] = useState('');
  const [filter, setFilter] = useState<ChapterFilter>('all');
  const [expanded, setExpanded] = useState<string | null>(null);
  const chapters = list(data.chapters);
  const unfinished = list(data.unfinished);
  const writable = list(data.writable);
  const viewer: Data = data.viewer ?? {};
  const found = (row: Data) => matches(query, row.name, row.recipe_names, row.discipline, row.era_name, row.category);
  const counts: Record<string, number> = { all: 0 };
  for (const row of chapters) if (found(row)) { counts.all++; counts[row.state] = (counts[row.state] ?? 0) + 1; }
  const shown = chapters.filter(row => found(row) && (filter === 'all' || row.state === filter))
    .sort((a, b) => (order[a.state] ?? 9) - (order[b.state] ?? 9) || str(a.name).localeCompare(str(b.name)));
  const canWrite = !!viewer.pen && Number(viewer.sheets) > 0 && !viewer.write_hands_problem && !data.busy;
  const offered = writable.filter(row => matches(query, row.name, row.era_name));
  return <div className="rs-bookwin">
    <Section title={str(data.name) || 'Book'}>
      <p className="rs-dim">{data.author ? `By ${str(data.author)}. ` : ''}{chapters.length} research chapter{chapters.length === 1 ? '' : 's'}{unfinished.length ? `, ${unfinished.length} unfinished` : ''}.</p>
      {!!data.cipher_note && <p className="rs-bad">{str(data.cipher_note)}</p>}
      {!!data.has_text && <Action ui={ui} action="read">Read the written pages</Action>}
      <div className="rs-toolbar"><label className="rs-search">Find a chapter <input type="search" value={query} placeholder="Name, recipe or discipline" onChange={event => setQuery(event.target.value)} /></label></div>
      <FilterChips options={filters} value={filter} counts={counts} onChange={setFilter} />
    </Section>
    <Section title="Chapters">
      {!chapters.length && <NoticeBox>No finished chapters yet.</NoticeBox>}
      {!!chapters.length && !shown.length && <p className="rs-dim">Nothing matches.</p>}
      <div className="rs-list">{shown.map(row => {
        const isOpen = expanded === String(row.id);
        const missing = list(row.groundwork).filter(item => !item.known);
        const studyTime = Number(row.study_minutes) > 0 ? `about ${minutes(row.study_minutes)}` : 'less than a minute';
        return <div key={row.id} className="rs-row rs-row-wrap">
          <button type="button" className="rs-row-main" aria-expanded={isOpen} onClick={() => setExpanded(isOpen ? null : String(row.id))}>
            <strong>{str(row.name)}</strong>
            <small>{str(row.era_name)} - {str(row.discipline)}{row.state === 'locked' && missing.length ? ` - first learn ${missing.map(item => str(item.name)).join(', ')}` : ''}{row.read_problem ? ` - ${str(row.read_problem)}` : ''}{row.state === 'study' ? `${Number(row.read_percent) > 0 ? ` - ${row.read_percent}% read` : ''} - ${studyTime}${Number(row.read_percent) > 0 ? ' left' : ''}${row.tutor ? ` with ${str(row.tutor)} tutoring` : ''}` : ''}</small>
          </button>
          <Pill tone={stateTone(row.state)}>{labels[row.state] ?? str(row.state)}</Pill>
          <span className="rs-row-action">{row.state === 'study' && <Action ui={ui} action="study" value={row.id}>{Number(row.read_percent) > 0 ? 'Continue' : 'Study'}</Action>}{row.state === 'known' && !!data.held && <Action ui={ui} action="aloud" value={row.id} disabled={!!data.busy}>Read aloud</Action>}</span>
          {isOpen && <div className="rs-row-detail">
            <h3>Groundwork</h3>
            {list(row.groundwork).length ? <ul className="rs-checks">{list(row.groundwork).map(item => <li key={item.id} className={item.known ? 'rs-ok' : 'rs-missing'}><span aria-hidden="true">{item.known ? '✓' : '✗'}</span> {str(item.name)} <span className="rs-dim">{item.known ? 'known' : 'not known yet'}</span></li>)}</ul> : <p className="rs-dim">None required.</p>}
            <h3>Teaches {list(row.recipe_names).length} recipes</h3><RecipeTags names={row.recipe_names} />
            {!!row.effect && <><h3>Knowing it</h3><p>{str(row.effect)}</p></>}
            {!!data.held && <p><Action ui={ui} action="rip" value={row.id} disabled={!!data.busy}>Tear this chapter out</Action></p>}
          </div>}
        </div>;
      })}</div>
    </Section>
    {!!unfinished.length && <Section title="Unfinished research">
      {unfinished.map(row => <div key={row.id} className="rs-unfinished"><strong>{str(row.name)}</strong> <span className="rs-dim">{row.percent}% ({row.ticks}/{row.cost}){row.prototype ? ` - working ${str(row.prototype)} ${row.prototype_done ? 'recorded' : 'still needed'}` : ''}{Number(row.protos_made) > 0 ? ` - prototypes made ${row.protos_made} of ${row.protos_max}` : ''}</span><Bar value={row.percent} label={`${str(row.name)} progress`} /></div>)}
      <p className="rs-dim">Place the book on a research bench and choose the subject to carry on.</p>
    </Section>}
    <Section title="Write a chapter from memory">
      <p className="rs-you"><strong>You have:</strong> {viewer.pen ? <span className="tag">{str(viewer.pen)} in hand</span> : <span className="tag rs-warn">no pencil or pen in hand</span>}
        <span className={`tag ${viewer.sheets ? '' : 'rs-warn'}`}>{Number(viewer.sheets) || 0} blank sheet{Number(viewer.sheets) === 1 ? '' : 's'}</span>
        <span className="tag">stamina {viewer.stamina}</span>{!!viewer.desk && <span className="tag">writing desk beside you</span>}</p>
      {!!data.held && <p className="rs-dim">Writing takes both hands: put the book down beside you and Alt-click it to open this window, with a pencil or pen in one hand. A blank sheet is taken from your other hand or your bags.</p>}
      {!data.held && !!viewer.pen && !!viewer.write_hands_problem && <p className="rs-dim">{str(viewer.write_hands_problem)} Alt-click the book again after changing what you hold.</p>}
      {!writable.length ? <p className="rs-dim">Everything you know is already in this book.</p> : <div className="rs-list">{offered.map(row => <div key={row.id} className="rs-row">
        <span className="rs-row-main"><strong>{str(row.name)}</strong><small>{str(row.era_name)} - about {minutes(row.write_minutes)}, {row.stamina} stamina and one blank sheet</small></span>
        <span className="rs-row-action"><Action ui={ui} action="write" value={row.id} disabled={!canWrite || Number(viewer.stamina) < Number(row.stamina)}>Write</Action></span>
      </div>)}</div>}
    </Section>
  </div>;
}
