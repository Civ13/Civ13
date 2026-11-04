import { afterEach, expect, it, vi } from 'vitest';
import { act, cleanup, fireEvent, render, screen } from '@testing-library/react';
// Form tests isolate controls from core layout and native visual support.
// The real Book page/parser still render; full CSS guards are browser-tested.
vi.mock('tgui-core/components', () => ({
  Section: ({ children }: any) => <section>{children}</section>,
  NoticeBox: ({ children }: any) => <aside>{children}</aside>,
}));
vi.mock('./BookReader', async () => {
  const actual = await vi.importActual<any>('./BookReader');
  return { ...actual, BookReader: ({ data }: any) => <actual.BookPage runs={actual.bookRuns(data)} /> };
});
import { PaperEditor, paperEditorModel, paperEditParams, paperBookData, legacyPieces, sectionPieces } from './PaperEditor';
import { bookRuns } from './BookReader';
import type { Data, ScreenProps } from '../types';
const EN = 'civ13:english:v1', RU = 'civ13:russian:v1';
function data(): Data {
  return { lease: 'a'.repeat(32), document_id: null, revision: 0, free_space: 3072,
    languages: [{ id: EN, name: 'English' },{ id: RU, name: 'Russian' }], default_language_id: EN,
    view: { legacy_name: 'Public item', legacy_body_html: '', sections: [] },
    draft_ink: 'white', draft_tool: 'pen', response_serial: 0, result: 'ready' };
}
function committed(original: Data, text = 'Saved', result = 'saved'): Data {
  return { ...original, lease: 'c'.repeat(32), document_id: 'b'.repeat(32), revision: 1, response_serial: 1, result,
    view: { ...original.view, revision: 1, legacy_policy: 'legacy_unclassified',
      sections: [{ id: 'section-1', kind: 'body', language_id: EN, text, ink: '#ffffff', tool: 'pen' }] } };
}
function props(value = data()): ScreenProps { return { data: value, template: 'paper_editor.tmpl', interactive: true, act: vi.fn() }; }
const sent = (ui: ScreenProps, index = 0) => JSON.parse(String(vi.mocked(ui.act).mock.calls[index][1]?.paper_edit));
afterEach(() => { cleanup(); vi.useRealTimers(); });
it('requires a complete finite model and rejects unsupported metadata', () => {
  expect(paperEditorModel(data()).languages.map(x => x.id)).toEqual([EN,RU]);
  for (const mutate of [
    (d: Data) => d.view.legacy_body_html = 7,
    (d: Data) => d.view.legacy_body_html = 'x'.repeat(65537),
    (d: Data) => d.draft_tool = 'brush',
    (d: Data) => d.view.sections = [{ id: 'x', kind:'body', language_id:EN, text:'x',ink:'white',tool:'quill' }],
    (d: Data) => d.extra = 'HIDDEN_ORIGINAL',
    (d: Data) => d.default_language_id = 'civ13:unknown:v1',
    (d: Data) => d.languages.push(d.languages[0]),
    (d: Data) => d.revision = 0.5,
    (d: Data) => d.draft_ink = 'transparent',
    (d: Data) => d.view.sections = [{ id: 'x', kind:'body', language_id:EN, text:'x',ink:'white',tool:'pen',original:'SECRET' }],
  ]) { const d = data(); mutate(d); expect(() => paperEditorModel(d)).toThrow(); }
});
it('preserves raw Unicode/entity text as inert text through the reused page parser', () => {
  const raw = '&lt;img src=x&gt; <script>literal</script> \u65e5\u672c\u8a9e \ud83d\udea2';
  const d = committed(data(), raw);
  const ui = props(d); const { container } = render(<PaperEditor {...ui} />);
  const page = container.querySelector('article')!;
  expect(page.textContent).toBe(raw); expect(page.querySelector('script,img')).toBeNull();
  expect(bookRuns(paperBookData([{text:raw,kind:'body',ink:'#ffffff'}]))[0].text).toBe(raw);
  expect(page.style.backgroundColor).toBe('rgb(255, 255, 255)');
  expect(page.querySelectorAll('span')[0].style.color).toBe('rgb(255, 255, 255)');
  expect(page.querySelectorAll('[title],[aria-label],[aria-describedby],[hidden],button,input,textarea').length).toBe(0);
});
it('sends one bounded append with current language/identity and blocks duplicate clicks', () => {
  const ui = props(); const { rerender } = render(<PaperEditor {...ui} />);
  fireEvent.change(screen.getByLabelText('Writing language'), { target: { value: RU } });
  fireEvent.change(screen.getByLabelText('Writing text'), { target: { value: 'New writing' } });
  fireEvent.click(screen.getByRole('button', { name: 'Write' }));
  expect(ui.act).toHaveBeenCalledTimes(1); expect(vi.mocked(ui.act).mock.calls[0][0]).toBe('paper_edit');
  expect(sent(ui)).toEqual({operation:'append',lease:'a'.repeat(32),document_id:null,revision:0,language_id:RU,kind:'body',value:'New writing'});
  fireEvent.click(screen.getByRole('button',{name:'Write'})); expect(ui.act).toHaveBeenCalledTimes(1);
  rerender(<PaperEditor {...ui} data={committed(ui.data,'New writing')} />);
  expect((screen.getByLabelText('Writing text') as HTMLTextAreaElement).value).toBe('');
  expect(screen.getByText('Writing saved.')).toBeTruthy();
});
it('keeps rejected draft text and updates removed language choices from the server', () => {
  const ui=props();const {rerender}=render(<PaperEditor {...ui} />);
  fireEvent.change(screen.getByLabelText('Writing language'),{target:{value:RU}});
  fireEvent.change(screen.getByLabelText('Writing text'),{target:{value:'Keep draft'}});
  fireEvent.click(screen.getByRole('button',{name:'Write'}));
  const next={...ui.data,languages:[ui.data.languages[0]],response_serial:1,result:'rejected'};
  rerender(<PaperEditor {...ui} data={next} />);
  expect((screen.getByLabelText('Writing text') as HTMLTextAreaElement).value).toBe('Keep draft');
  expect((screen.getByLabelText('Writing language') as HTMLSelectElement).value).toBe(EN);
  expect(screen.queryByRole('option',{name:'Russian'})).toBeNull();
});
it('never replays an unconfirmed append and uses read-only refresh to recover', () => {
  vi.useFakeTimers();const ui=props();const {rerender}=render(<PaperEditor {...ui} />);
  fireEvent.change(screen.getByLabelText('Writing text'),{target:{value:'Possibly saved'}});
  fireEvent.click(screen.getByRole('button',{name:'Write'}));
  act(()=>vi.advanceTimersByTime(10001));expect(ui.act).toHaveBeenCalledTimes(1);
  expect((screen.getByRole('button',{name:'Write'}) as HTMLButtonElement).disabled).toBe(true);
  expect(screen.getByText('Writing is not confirmed. Refresh to check before trying again.')).toBeTruthy();
  fireEvent.click(screen.getByRole('button',{name:'Refresh'}));
  expect(sent(ui,1)).toEqual({operation:'refresh',lease:'a'.repeat(32)});
  act(()=>vi.advanceTimersByTime(30000));expect(ui.act).toHaveBeenCalledTimes(2);
  rerender(<PaperEditor {...ui} data={committed(ui.data,'Possibly saved','refreshed')} />);
  expect((screen.getByLabelText('Writing text') as HTMLTextAreaElement).value).toBe('');
});
it('signs with no client-supplied signature text and keeps cancel finite', () => {
  const ui=props();render(<PaperEditor {...ui} />);
  fireEvent.change(screen.getByLabelText('Writing section'),{target:{value:'signature'}});
  expect(screen.queryByLabelText('Writing text')).toBeNull();
  fireEvent.click(screen.getByRole('button',{name:'Sign'}));
  expect(sent(ui).kind).toBe('signature');expect(sent(ui).value).toBe('');
  expect(paperEditParams(paperEditorModel(data()),'cancel')).toEqual({paper_edit:JSON.stringify({operation:'cancel',lease:'a'.repeat(32)})});
});
it('does not truncate escaped payloads to fit the transport limit', () => {
  const ui=props();render(<PaperEditor {...ui} />);
  fireEvent.change(screen.getByLabelText('Writing text'),{target:{value:'\\'.repeat(3072)}});
  fireEvent.click(screen.getByRole('button',{name:'Write'}));
  expect(ui.act).not.toHaveBeenCalled();expect(screen.getByText('This text cannot fit in one submission.')).toBeTruthy();
});
it('enforces read-only and remaining-capacity controls without disabling refresh', () => {
  const ui=props({...data(),free_space:0});render(<PaperEditor {...ui} />);
  fireEvent.change(screen.getByLabelText('Writing text'),{target:{value:'Too long'}});
  expect((screen.getByRole('button',{name:'Write'}) as HTMLButtonElement).disabled).toBe(true);
  expect((screen.getByRole('button',{name:'Refresh'}) as HTMLButtonElement).disabled).toBe(false);
  fireEvent.submit(screen.getByLabelText('Writing text').closest('form')!);expect(ui.act).not.toHaveBeenCalled();
});

it('retains an unsupported draft without writing or triggering document fallback', () => {
  const ui=props();render(<PaperEditor {...ui} />);
  fireEvent.change(screen.getByLabelText('Writing text'),{target:{value:'Bad \ud800 draft'}});
  expect((screen.getByLabelText('Writing text') as HTMLTextAreaElement).value).toBe('Bad \ud800 draft');
  expect(screen.getByText('Some characters cannot be previewed. Edit the text before writing.')).toBeTruthy();
  expect((screen.getByRole('button',{name:'Write'}) as HTMLButtonElement).disabled).toBe(true);
  expect(ui.act).not.toHaveBeenCalled();
});

it('keeps a separate body draft when a signature is saved', () => {
  const ui=props();const {rerender}=render(<PaperEditor {...ui} />);
  fireEvent.change(screen.getByLabelText('Writing text'),{target:{value:'Unsent body'}});
  fireEvent.change(screen.getByLabelText('Writing section'),{target:{value:'signature'}});
  fireEvent.click(screen.getByRole('button',{name:'Sign'}));
  rerender(<PaperEditor {...ui} data={committed(ui.data,'Actual signature')} />);
  fireEvent.change(screen.getByLabelText('Writing section'),{target:{value:'body'}});
  expect((screen.getByLabelText('Writing text') as HTMLTextAreaElement).value).toBe('Unsent body');
});

it('shows old pencode HTML as inert styled text and appends new writing after it', () => {
  const legacy = '<font face="Verdana" color=blue><b>Orders</b><BR>March <i>north</i><img src=x onerror=alert(1)><script>alert(1)</script>'
    + '<span class="paper_field"></span><table><tr><td>a</td><td>b</td></tr></table><ul><li>one</li></ul></font>'
    + '<font face="Comic Sans MS" color=#ff0000><b>crayon</b></font><font face="Times New Roman"><i>Signed Name</i></font>';
  const pieces = legacyPieces(legacy);
  expect(pieces.map(p => p.br ? '|' : p.text).join('')).toBe('Orders|March north[stamp]|a b |\u2022 one|crayonSigned Name');
  expect(pieces[0]).toEqual({ text: 'Orders', ink: '#0000ff', face: 'verdana', bold: true, italic: false });
  expect(pieces.find(p => p.text === 'crayon')).toEqual({ text: 'crayon', ink: '#ff0000', face: 'comic', bold: true, italic: false });
  expect(pieces.find(p => p.text === 'Signed Name')).toMatchObject({ face: 'times', italic: true });
  const d = committed(data(), 'New line'); d.view.legacy_body_html = legacy;
  const ui = props(d); const { container } = render(<PaperEditor {...ui} />);
  const page = container.querySelector('article')!;
  expect(page.textContent).toBe('OrdersMarch north[stamp]a b \u2022 onecrayonSigned NameNew line');
  expect(page.querySelector('script,img,table,font,li')).toBeNull();
  expect(screen.getByLabelText('Writing text')).toBeTruthy();
});
it('drops unknown colours and faces, and keeps hostile markup inert', () => {
  const pieces = legacyPieces('<font color="javascript:x" face="Wingdings">a</font><style>b{}</style><iframe>c</iframe>&lt;d&gt;');
  expect(pieces).toEqual([{ text: 'a<d>', ink: '#000000', face: 'times', bold: false, italic: false }]);
  expect(legacyPieces('')).toEqual([]);
  expect(() => legacyPieces('<br>'.repeat(2000))).toThrow();
});
it('renders crayon writing bold in Comic Sans and accepts a crayon draft', () => {
  const d = committed(data(), 'Waxy'); d.draft_tool = 'crayon'; d.view.sections[0].tool = 'crayon';
  const model = paperEditorModel(d);
  expect(model.draft_tool).toBe('crayon');
  const runs = bookRuns(paperBookData(model.runs));
  expect(runs).toEqual([{ text: 'Waxy', ink: '#ffffff', face: 'comic', bold: true, italic: false }]);
  const ui = props(d); render(<PaperEditor {...ui} />);
  fireEvent.change(screen.getByLabelText('Writing text'), { target: { value: 'More wax' } });
  fireEvent.click(screen.getByRole('button', { name: 'Write' }));
  expect(sent(ui).value).toBe('More wax');
});
it('keeps line breaks and applies only [b], [i] and [br] to new writing', () => {
  const pieces = sectionPieces({ text: 'a\n[b]b[/b][br][i]c[/i] [u]d[/u]', kind: 'body', ink: '#000000', tool: 'pen' });
  expect(pieces.map(p => p.br ? '|' : `${p.text}${p.bold ? '!' : ''}${p.italic ? '/' : ''}`).join(',')).toBe('|,a,|,b!,|,c/, [u]d[/u]');
  const signature = sectionPieces({ text: '[b]Name', kind: 'signature', ink: '#000000', tool: 'pen' });
  expect(signature[1]).toEqual({ text: '[b]Name', ink: '#000000', face: 'times', bold: false, italic: true });
});
