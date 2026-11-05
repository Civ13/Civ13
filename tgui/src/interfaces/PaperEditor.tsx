import { useEffect, useLayoutEffect, useRef, useState } from 'react';
import { NoticeBox, Section } from 'tgui-core/components';
import { BookReader, BookPage, bookRuns, type Face } from './BookReader';
import { text } from './common';
import type { Data, Params, ScreenProps } from '../types';

type Kind = 'body' | 'title' | 'signature';
type Tool = 'pen' | 'crayon';
type Run = { text: string; kind: string; ink: string; tool?: Tool };
// Unencoded display pieces; paperBookData encodes them for the Book parser.
export type PaperPiece = { text?: string; br?: true; ink: string; face: Face; bold: boolean; italic: boolean };
export type PaperEditorModel = {
  lease: string; document_id: string | null; revision: number; free_space: number;
  languages: { id: string; name: string }[]; default_language_id: string | null;
  name: string; legacy: PaperPiece[]; runs: Run[]; draft_ink: string; draft_tool: Tool; draft_signature: string; response_serial: number; result: string;
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
// Older papers store pencode output as HTML. Parse it in an inert DOMParser
// document (no scripts, no resource loads) and keep only text, line breaks and
// a small whitelist of styling. Nothing from the stored HTML is ever inserted.
const LEGACY_BLOCKS = new Set(['P','DIV','CENTER','H1','H2','H3','H4','H5','H6','UL','OL','LI','TABLE','TR','HR','BLOCKQUOTE','PRE']);
const LEGACY_SKIP = new Set(['SCRIPT','STYLE','TEMPLATE','NOSCRIPT','IFRAME','OBJECT','EMBED','TITLE','HEAD','SVG','MATH']);
const LEGACY_PIECES = 1536, LEGACY_UNITS = 65536;
function cleanText(value: string): string {
  return value.replace(/[\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/g, '')
    .replace(/[\ud800-\udbff](?![\udc00-\udfff])|(?<![\ud800-\udbff])[\udc00-\udfff]/g, '�');
}
function legacyFace(value: string | null, current: Face): Face {
  const face = (value ?? '').toLowerCase();
  if (face.includes('comic')) return 'comic';
  if (face.includes('times')) return 'times';
  if (face.includes('verdana')) return 'verdana';
  return current;
}
function legacyInk(value: string | null, current: string): string {
  try { return value ? ink(value.trim().replace(/^["']|["']$/g, '')) : current; } catch { return current; }
}
export function legacyPieces(html: string): PaperPiece[] {
  if (!html) return [];
  if (typeof DOMParser !== 'function') throw new Error('Unsupported legacy paper');
  const body = new DOMParser().parseFromString(html, 'text/html').body;
  const pieces: PaperPiece[] = [];
  let units = 0;
  const push = (piece: PaperPiece) => {
    const last = pieces[pieces.length - 1];
    if (piece.text !== undefined) {
      if (!piece.text) return;
      if ((units += piece.text.length) > LEGACY_UNITS) throw new Error('Legacy paper budget');
      if (last && last.text !== undefined && last.ink === piece.ink && last.face === piece.face && last.bold === piece.bold && last.italic === piece.italic) { last.text += piece.text; return; }
    }
    if (pieces.length >= LEGACY_PIECES) throw new Error('Legacy paper budget');
    pieces.push(piece);
  };
  const lineBreak = (style: Omit<PaperPiece, 'text' | 'br'>) => {
    const last = pieces[pieces.length - 1];
    if (last && !last.br) push({ br: true, ...style });
  };
  const walk = (node: Node, style: Omit<PaperPiece, 'text' | 'br'>, depth: number) => {
    if (depth > 64) throw new Error('Legacy paper depth');
    if (node.nodeType === 3) { push({ text: cleanText(node.nodeValue ?? ''), ...style }); return; }
    if (node.nodeType !== 1) return;
    const element = node as Element, tag = element.tagName.toUpperCase();
    if (LEGACY_SKIP.has(tag)) return;
    if (tag === 'BR') { push({ br: true, ...style }); return; }
    if (tag === 'IMG') { push({ text: '[stamp]', ...style, italic: true }); return; }
    const next = { ...style };
    if (tag === 'B' || tag === 'STRONG' || /^H[1-6]$/.test(tag)) next.bold = true;
    if (tag === 'I' || tag === 'EM') next.italic = true;
    if (tag === 'FONT') { next.ink = legacyInk(element.getAttribute('color'), next.ink); next.face = legacyFace(element.getAttribute('face'), next.face); }
    const block = LEGACY_BLOCKS.has(tag);
    if (block) lineBreak(style);
    if (tag === 'LI') push({ text: '• ', ...next });
    if (tag === 'HR') push({ text: '―'.repeat(12), ...next });
    for (const child of Array.from(element.childNodes)) walk(child, next, depth + 1);
    if (tag === 'TD' || tag === 'TH') push({ text: ' ', ...style });
    if (block) lineBreak(style);
  };
  walk(body, { ink: '#000000', face: 'times', bold: false, italic: false }, 0);
  while (pieces.length && pieces[pieces.length - 1].br) pieces.pop();
  return pieces;
}
// New sections are plain text. [b], [i] and [br] are the only formatting
// applied when shown; the server expands [sign], [date] and [time] on write.
// Written titles are bold, like the classic reader.
export function sectionPieces(run: Run): PaperPiece[] {
  const crayon = run.tool === 'crayon', signature = run.kind === 'signature', title = run.kind === 'title';
  const face: Face = signature ? 'times' : crayon ? 'comic' : 'verdana';
  let bold = crayon || title, italic = signature;
  const pieces: PaperPiece[] = [{ br: true, ink: run.ink, face, bold, italic }];
  const tokens = signature ? [run.text] : run.text.split(/(\[\/?[bi]\]|\[br\]|\n)/);
  for (const token of tokens) {
    if (!signature && (token === '\n' || token === '[br]')) pieces.push({ br: true, ink: run.ink, face, bold, italic });
    else if (!signature && token === '[b]') bold = true;
    else if (!signature && token === '[/b]') bold = crayon || title;
    else if (!signature && token === '[i]') italic = true;
    else if (!signature && token === '[/i]') italic = false;
    else if (token) pieces.push({ text: token, ink: run.ink, face, bold, italic });
  }
  return pieces;
}
export function paperEditorModel(data: Data): PaperEditorModel {
  keys(data, ['lease','document_id','revision','free_space','languages','default_language_id','view','draft_ink','draft_tool','draft_signature','response_serial','result']);
  if (!token(data.lease) || (data.document_id !== null && !token(data.document_id))) throw new Error('Invalid paper identity');
  integer(data.revision, 1048575); integer(data.free_space, 3072); integer(data.response_serial, 1048575);
  if ((data.document_id === null) !== (data.revision === 0)) throw new Error('Invalid paper revision');
  if (!['ready','saved','rejected','refreshed'].includes(data.result) || !['pen','crayon'].includes(data.draft_tool)) throw new Error('Unsupported paper editor');
  if (typeof data.draft_signature !== 'string' || data.draft_signature.length > 256) throw new Error('Invalid paper signature');
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
  // Legacy HTML is only read through legacyPieces; no raw insertion and no
  // editable href cache. Parse failures use the server's read-only fallback.
  if (typeof view.legacy_body_html !== 'string' || view.legacy_body_html.length > LEGACY_UNITS || typeof view.legacy_name !== 'string' || view.legacy_name.length > 256 || !Array.isArray(view.sections) || view.sections.length > 128) throw new Error('Unsupported paper view');
  let units = 0;
  const ids = new Set<string>();
  const runs = view.sections.map(section => {
    keys(section, ['id','kind','language_id','text','ink','tool']);
    if (typeof section.id !== 'string' || !section.id.length || section.id.length > 64 || ids.has(section.id) || !language(section.language_id) || !['body','title','signature','field_label','field_answer'].includes(section.kind) || !['pen','crayon'].includes(section.tool) || typeof section.text !== 'string' || (units += section.text.length) > 6144) throw new Error('Unsupported paper section');
    ids.add(section.id);
    return { text: section.text, kind: section.kind, ink: ink(section.ink), tool: section.tool as Tool };
  });
  return { lease: data.lease, document_id: data.document_id, revision: data.revision, free_space: data.free_space,
    languages, default_language_id: data.default_language_id, name: text(view.legacy_name), legacy: legacyPieces(view.legacy_body_html), runs,
    draft_ink: ink(data.draft_ink), draft_tool: data.draft_tool as Tool, draft_signature: cleanText(data.draft_signature), response_serial: data.response_serial, result: data.result };
}
const encode = (value: string) => value.replaceAll('&','&amp;').replaceAll('<','&lt;').replaceAll('>','&gt;').replaceAll('"','&quot;').replaceAll("'",'&#39;');
export function paperBookData(runs: Run[], legacy: PaperPiece[] = []): Data {
  const pieces = [...legacy, ...runs.flatMap(sectionPieces)];
  if (!legacy.length && pieces[0]?.br) pieces.shift();
  return { runs: pieces.map(piece => piece.br
    ? { br: true, face: piece.face, ink: piece.ink, bold: piece.bold, italic: piece.italic }
    : { text: encode(piece.text ?? ''), face: piece.face, ink: piece.ink, bold: piece.bold, italic: piece.italic }) };
}
export function paperEditParams(model: PaperEditorModel, operation: 'append' | 'refresh' | 'cancel', languageId = '', kind: Kind = 'body', value = ''): Params {
  const request: Record<string, unknown> = { operation, lease: model.lease };
  if (operation === 'append') Object.assign(request, { document_id: model.document_id, revision: model.revision, language_id: languageId, kind, value });
  const params = { paper_edit: JSON.stringify(request) };
  if (JSON.stringify(params).length > 8192) throw new Error('Paper request exceeds transport limit');
  return params;
}
const DRAFT_LIMIT = 3072;
// Toolbar insertions wrap the current textarea selection; nothing is sent.
const TOOLS: { label: string; title: string; before: string; after?: string }[] = [
  { label: 'B', title: 'Bold', before: '[b]', after: '[/b]' },
  { label: 'I', title: 'Italic', before: '[i]', after: '[/i]' },
  { label: 'Sign', title: 'Insert your signature', before: '[sign]' },
  { label: 'Date', title: 'Insert the date', before: '[date]' },
  { label: 'Time', title: 'Insert the time', before: '[time]' },
];
export function PaperEditorForm({ model, act, interactive, template }: { model: PaperEditorModel } & Pick<ScreenProps,'act'|'interactive'|'template'>) {
  const [languageId, setLanguage] = useState(model.default_language_id ?? model.languages[0].id);
  const [kind, setKind] = useState<Kind>('body'), [draft, setDraft] = useState('');
  const [pending, setPending] = useState(false), [uncertain, setUncertain] = useState(false), [notice, setNotice] = useState('');
  const serial = useRef(model.response_serial), submittedLease = useRef<string | null>(null), submittedKind = useRef<Kind | null>(null);
  const textarea = useRef<HTMLTextAreaElement>(null), cursor = useRef<[number, number] | null>(null);
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
  // Restore the caret after a toolbar insertion re-renders the controlled textarea.
  useLayoutEffect(() => {
    const area = textarea.current, next = cursor.current;
    cursor.current = null;
    if (area && next) { area.focus(); area.setSelectionRange(next[0], next[1]); }
  }, [draft]);
  const send = (operation: 'append' | 'refresh' | 'cancel') => {
    try {
      const params = paperEditParams(model, operation, languageId, kind, kind === 'signature' ? '' : draft);
      if (operation === 'append') { submittedLease.current = model.lease; submittedKind.current = kind; }
      setPending(true); setNotice(''); act('paper_edit', params);
    } catch { setNotice('This text cannot fit in one submission.'); }
  };
  const insert = (before: string, after = '') => {
    const area = textarea.current;
    const start = area?.selectionStart ?? draft.length, end = area?.selectionEnd ?? start;
    const next = draft.slice(0, start) + before + draft.slice(start, end) + after + draft.slice(end);
    if (next.length > DRAFT_LIMIT) return;
    // Wrapping a selection keeps it selected; an empty selection lands between the tags.
    cursor.current = start === end ? [start + before.length, start + before.length] : [start + before.length, end + before.length];
    setDraft(next);
  };
  const editable = interactive && !pending && !uncertain;
  const signing = kind === 'signature', full = model.free_space <= 0;
  const remaining = model.free_space - (signing ? 0 : draft.length), tooLong = !signing && remaining < 0;
  let previewRuns: ReturnType<typeof bookRuns> = [];
  let invalidDraft = false;
  try {
    previewRuns = bookRuns(paperBookData([{ text: signing ? (model.draft_signature || 'Signature from the held pen') : draft, kind, ink: model.draft_ink, tool: model.draft_tool }]));
  } catch { invalidDraft = true; }
  const canWrite = editable && !invalidDraft && !full && (signing || (!!draft.length && !tooLong));
  const blank = !model.runs.length && !model.legacy.length;
  return <Section><div className="paper-editor"><h2>{model.name}</h2>
    <section aria-label="Document">
      <BookReader template={template} interactive={false} act={act} data={paperBookData(model.runs, model.legacy)} />
    </section>
    {blank && <p className="paper-hint">Nothing is written on this paper yet.</p>}
    <form onSubmit={event => { event.preventDefault(); if (canWrite) send('append'); }}>
      <div className="paper-controls">
        <label>Language <select aria-label="Writing language" value={languageId} disabled={!editable} onChange={event => setLanguage(event.currentTarget.value)}>
          {model.languages.map(choice => <option key={choice.id} value={choice.id}>{choice.name}</option>)}
        </select></label>
        <label>Section <select aria-label="Writing section" value={kind} disabled={!editable} onChange={event => setKind(event.currentTarget.value as Kind)}>
          <option value="body">Body</option><option value="title">Written title</option><option value="signature">Signature</option>
        </select></label>
      </div>
      {!signing && <>
        <div className="paper-tools" role="toolbar" aria-label="Formatting">
          {TOOLS.map(tool => <button key={tool.label} type="button" title={tool.title} aria-label={tool.title} disabled={!editable} onClick={() => insert(tool.before, tool.after)}>{tool.label}</button>)}
        </div>
        <label>Text <textarea ref={textarea} aria-label="Writing text" rows={6} value={draft} maxLength={DRAFT_LIMIT} disabled={!editable}
          placeholder={kind === 'title' ? 'Write a title for this document' : 'Write on the paper'}
          onChange={event => setDraft(event.currentTarget.value)}
          onKeyDown={event => { if (event.key === 'Enter' && (event.ctrlKey || event.metaKey) && canWrite) { event.preventDefault(); send('append'); } }} /></label>
        <p className="paper-hint">Press Enter for a new line and Ctrl+Enter to write. [b]bold[/b] and [i]italic[/i] are shown as formatting; [sign], [date] and [time] are filled in when written.</p>
      </>}
      {signing && <p className="paper-hint">Signing writes the name from the held pen; nothing is typed.</p>}
      <p className={'paper-space' + (tooLong ? ' paper-over' : '')}>{full ? 'This paper is full.' : tooLong ? `${-remaining} characters over the remaining space.` : `${remaining} of ${model.free_space} characters remaining after this writing.`}</p>
      {(signing || draft.length > 0) && <section aria-label="Draft preview">
        <h3>Preview</h3>
        <BookPage runs={previewRuns} />
      </section>}
      {tooLong && <NoticeBox danger>This text exceeds the remaining space.</NoticeBox>}
      {invalidDraft && <NoticeBox danger>Some characters cannot be previewed. Edit the text before writing.</NoticeBox>}
      {pending && <NoticeBox info>Sending to the paper...</NoticeBox>}
      {notice === 'Writing saved.' && <NoticeBox success>{notice}</NoticeBox>}
      {notice === 'Document refreshed.' && <NoticeBox info>{notice}</NoticeBox>}
      {notice && notice !== 'Writing saved.' && notice !== 'Document refreshed.' && <NoticeBox danger>{notice}</NoticeBox>}
      <div className="paper-actions">
        <button type="submit" className="paper-write" disabled={!canWrite}>{signing ? 'Sign' : 'Write'}</button>
        <button type="button" disabled={!interactive || pending} onClick={() => send('refresh')}>Refresh</button>
        <button type="button" disabled={!interactive || pending} onClick={() => send('cancel')}>Close</button>
      </div>
    </form>
  </div></Section>;
}
export function PaperEditor({ data, ...props }: ScreenProps) {
  return <PaperEditorForm {...props} model={paperEditorModel(data)} />;
}
