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
import { PaperEditor, paperEditorModel, paperEditParams, paperBookData } from './PaperEditor';
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
it('requires a complete finite model and rejects unsupported legacy/crayon/metadata', () => {
  expect(paperEditorModel(data()).languages.map(x => x.id)).toEqual([EN,RU]);
  for (const mutate of [
    (d: Data) => d.view.legacy_body_html = '<table>Complete old view</table>',
    (d: Data) => d.draft_tool = 'crayon',
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
  expect(bookRuns(paperBookData([{text:raw,kind:'body',ink:'#ffffff'}]))[1].text).toBe(raw);
  expect(page.style.backgroundColor).toBe('rgb(255, 255, 255)');
  expect(page.querySelectorAll('span')[1].style.color).toBe('rgb(255, 255, 255)');
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
