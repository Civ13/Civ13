import { useEffect, useRef, useState } from 'react';
import { NoticeBox, Section } from 'tgui-core/components';
import { BookReader, BookPage, bookRuns } from './BookReader';
import { text } from './common';
import type { Data, Params, ScreenProps } from '../types';

type Kind = 'body' | 'title' | 'signature';
type Run = { text: string; kind: string; ink: string };
export type PaperEditorModel = {
  lease: string; document_id: string | null; revision: number; free_space: number;
  languages: { id: string; name: string }[]; default_language_id: string | null;
  name: string; runs: Run[]; draft_ink: string; response_serial: number; result: string;
};
const names: Record<string, string> = {
  black: '#000000', blue: '#0000ff', red: '#ff0000', white: '#ffffff', yellow: '#ffff00',
  lime: '#00ff00', pink: '#ffc0cb', orange: '#ffa500', cyan: '#00ffff', grey: '#808080',
  gray: '#808080', green: '#008000', purple: '#800080', brown: '#a52a2a',
};
function ink(value: unknown): string {
  if (typeof value !== 'string') throw new Error('Invalid paper ink');
  const color = value.toLowerCase();
  if (names[color]) return names[color];
  if (!/^#[0-9a-f]{6}$/.test(color)) throw new Error('Invalid paper ink');
  return color;
}
function object(value: unknown): asserts value is Record<string, any> {
  if (!value || typeof value !== 'object' || Array.isArray(value)) throw new Error('Invalid paper object');
}
function keys(value: unknown, expected: string[]) {
  object(value);
  if (Object.keys(value).sort().join(',') !== expected.sort().join(',')) throw new Error('Invalid paper fields');
}
function integer(value: unknown, maximum: number): asserts value is number {
  if (typeof value !== 'number' || !Number.isSafeInteger(value) || value < 0 || value > maximum) throw new Error('Invalid paper count');
}
const language = (value: unknown): value is string => typeof value === 'string' && /^civ13:[a-z]+:v1$/.test(value);
const token = (value: unknown): value is string => typeof value === 'string' && /^[0-9a-f]{32}$/.test(value);
export function paperEditorModel(data: Data): PaperEditorModel {
  keys(data, ['lease','document_id','revision','free_space','languages','default_language_id','view','draft_ink','draft_tool','response_serial','result']);
  if (!token(data.lease) || (data.document_id !== null && !token(data.document_id))) throw new Error('Invalid paper identity');
  integer(data.revision, 1048575); integer(data.free_space, 3072); integer(data.response_serial, 1048575);
  if ((data.document_id === null) !== (data.revision === 0)) throw new Error('Invalid paper revision');
  if (!['ready','saved','rejected','refreshed'].includes(data.result) || data.draft_tool !== 'pen') throw new Error('Unsupported paper editor');
  if (!Array.isArray(data.languages) || !data.languages.length || data.languages.length > 64) throw new Error('Invalid paper languages');
  const seen = new Set<string>();
  const languages = data.languages.map(choice => {
    keys(choice, ['id','name']);
    if (!language(choice.id) || typeof choice.name !== 'string' || choice.name.length > 128 || seen.has(choice.id)) throw new Error('Invalid language choice');
    seen.add(choice.id); return { id: choice.id, name: choice.name };
  });
  if (data.default_language_id !== null && !seen.has(data.default_language_id)) throw new Error('Invalid language default');
  object(data.view);
  const view = data.view;
  const viewKeys = ['legacy_name','legacy_body_html','sections'];
  if (Object.hasOwn(view, 'revision')) {
    viewKeys.push('revision','legacy_policy');
    if (view.revision !== data.revision || view.legacy_policy !== 'legacy_unclassified') throw new Error('Invalid paper view');
  }
  keys(view, viewKeys);
  // No partial conversion, raw HTML insertion, editable legacy href cache or
  // flattened substitute. The server supplies the complete read-only fallback.
  if (view.legacy_body_html !== '' || typeof view.legacy_name !== 'string' || view.legacy_name.length > 256 || !Array.isArray(view.sections) || view.sections.length > 128) throw new Error('Unsupported paper view');
  let units = 0;
  const ids = new Set<string>();
  const runs = view.sections.map(section => {
    keys(section, ['id','kind','language_id','text','ink','tool']);
    if (typeof section.id !== 'string' || !section.id.length || section.id.length > 64 || ids.has(section.id) || !language(section.language_id) || !['body','title','signature','field_label','field_answer'].includes(section.kind) || section.tool !== 'pen' || typeof section.text !== 'string' || (units += section.text.length) > 6144) throw new Error('Unsupported paper section');
    ids.add(section.id);
    return { text: section.text, kind: section.kind, ink: ink(section.ink) };
  });
  return { lease: data.lease, document_id: data.document_id, revision: data.revision, free_space: data.free_space,
    languages, default_language_id: data.default_language_id, name: text(view.legacy_name), runs,
    draft_ink: ink(data.draft_ink), response_serial: data.response_serial, result: data.result };
}
const encode = (value: string) => value.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&#39;');
export function paperBookData(runs: Run[]): Data {
  return { runs: runs.flatMap(run => [
    { br: true, face: 'verdana', ink: run.ink, bold: false, italic: false },
    { text: encode(run.text), face: run.kind === 'signature' ? 'times' : 'verdana', ink: run.ink, bold: false, italic: run.kind === 'signature' },
  ]) };
}
export function paperEditParams(model: PaperEditorModel, operation: 'append' | 'refresh' | 'cancel', languageId = '', kind: Kind = 'body', value = ''): Params {
  const request: Record<string, unknown> = { operation, lease: model.lease };
  if (operation === 'append') Object.assign(request, { document_id: model.document_id, revision: model.revision, language_id: languageId, kind, value });
  const params = { paper_edit: JSON.stringify(request) };
  if (JSON.stringify(params).length > 8192) throw new Error('Paper request exceeds transport limit');
  return params;
}
export function PaperEditorForm({ model, act, interactive, template }: { model: PaperEditorModel } & Pick<ScreenProps,'act'|'interactive'|'template'>) {
  const [languageId, setLanguage] = useState(model.default_language_id ?? model.languages[0].id);
  const [kind, setKind] = useState<Kind>('body'), [draft, setDraft] = useState('');
  const [pending, setPending] = useState(false), [uncertain, setUncertain] = useState(false), [notice, setNotice] = useState('');
  const serial = useRef(model.response_serial), submittedLease = useRef<string | null>(null), submittedKind = useRef<Kind | null>(null);
  useEffect(() => {
    if (!model.languages.some(choice => choice.id === languageId)) setLanguage(model.default_language_id ?? model.languages[0].id);
  }, [model.languages, model.default_language_id, languageId]);
  useEffect(() => {
    if (serial.current === model.response_serial) return;
    serial.current = model.response_serial;
    const saved = model.result === 'saved' || (submittedLease.current !== null && submittedLease.current !== model.lease);
    if (saved && submittedKind.current !== 'signature') setDraft('');
    setPending(false); setUncertain(false); submittedLease.current = null; submittedKind.current = null;
    setNotice(saved ? 'Writing saved.' : model.result === 'rejected' ? 'Writing was not saved. Check the document before trying again.' : 'Document refreshed.');
  }, [model.response_serial, model.lease, model.result]);
  useEffect(() => {
    if (!pending) return;
    const timer = setTimeout(() => { setPending(false); setUncertain(true); setNotice('Writing is not confirmed. Refresh to check before trying again.'); }, 10000);
    return () => clearTimeout(timer);
  }, [pending]);
  const send = (operation: 'append' | 'refresh' | 'cancel') => {
    try {
      const params = paperEditParams(model, operation, languageId, kind, kind === 'signature' ? '' : draft);
      if (operation === 'append') { submittedLease.current = model.lease; submittedKind.current = kind; }
      setPending(true); setNotice(''); act('paper_edit', params);
    } catch { setNotice('This text cannot fit in one submission.'); }
  };
  const tooLong = draft.length > model.free_space;
  let previewRuns: ReturnType<typeof bookRuns> = [];
  let invalidDraft = false;
  try {
    previewRuns = bookRuns(paperBookData([{ text: kind === 'signature' ? 'Signature from the held pen' : draft, kind, ink: model.draft_ink }]));
  } catch { invalidDraft = true; }
  const canWrite = interactive && !pending && !uncertain && !invalidDraft && model.free_space > 0 && (kind === 'signature' || (!!draft.length && !tooLong));
  return <Section><h2>{model.name}</h2>
    <section aria-label="Document">
      <BookReader template={template} interactive={false} act={act} data={paperBookData(model.runs)} />
    </section>
    <form onSubmit={event => { event.preventDefault(); if (canWrite) send('append'); }}>
      <label>Language <select aria-label="Writing language" value={languageId} disabled={!interactive || pending || uncertain} onChange={event => setLanguage(event.currentTarget.value)}>
        {model.languages.map(choice => <option key={choice.id} value={choice.id}>{choice.name}</option>)}
      </select></label>
      <label>Section <select aria-label="Writing section" value={kind} disabled={!interactive || pending || uncertain} onChange={event => setKind(event.currentTarget.value as Kind)}>
        <option value="body">Body</option><option value="title">Written title</option><option value="signature">Signature</option>
      </select></label>
      {kind !== 'signature' && <label>Text <textarea aria-label="Writing text" value={draft} maxLength={3072} disabled={!interactive || pending || uncertain} onChange={event => setDraft(event.currentTarget.value)} /></label>}
      <p>Plain text. Signature text comes from the held pen.</p>
      <p>{model.free_space} space remaining.</p>
      <section aria-label="Draft preview">
        <BookPage runs={previewRuns} />
      </section>
      {tooLong && kind !== 'signature' && <NoticeBox>This text exceeds the remaining space.</NoticeBox>}
      {invalidDraft && <NoticeBox>Some characters cannot be previewed. Edit the text before writing.</NoticeBox>}
      {notice && <NoticeBox>{notice}</NoticeBox>}
      <button type="submit" disabled={!canWrite}>{kind === 'signature' ? 'Sign' : 'Write'}</button>
      <button type="button" disabled={!interactive || pending} onClick={() => send('refresh')}>Refresh</button>
      <button type="button" disabled={!interactive || pending} onClick={() => send('cancel')}>Cancel</button>
    </form>
  </Section>;
}
export function PaperEditor({ data, ...props }: ScreenProps) {
  return <PaperEditorForm {...props} model={paperEditorModel(data)} />;
}
