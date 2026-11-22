import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, screen } from '@testing-library/react';
import { render } from '../testing';
import { Computer, PAYLOAD_LIMIT } from './Computer';
import type { ComputerData } from '../data';
import type { ScreenProps } from '../types';
afterEach(cleanup);
const base: ComputerData = {
  name: 'minicomputer', shell: 'cli', os_name: 'Unga OS', os_version: '1969 edition', boot_lines: ['UNGA OS 1969 EDITION', 'MEMORY CHECK OK'], powered: 1, case_open: 0, status: '',
  hardware: [{ index: 3, slot: 'cpu', slot_label: 'Processor', name: 'transistor logic board', detail: 'tier 1', icon: 'cpu_chip' }],
  empty_slots: [{ slot: 'expansion', slot_label: 'Expansion' }],
  programs: [{ id: 'files', name: 'Files', desc: 'Write, read, print and copy text files.', available: 1, reason: '' },
    { id: 'ledger', name: 'Ledger', desc: 'Accounts.', available: 0, reason: 'Needs a tier 2 processor.' }],
  active: '', files: null,
};
const files = (extra: NonNullable<ComputerData['files']> = {}): ComputerData => ({ ...base, active: 'files', files: {
  drive: { name: 'tape drive', used_kb: 1.2, capacity_kb: 16 }, list: [{ index: 1, name: 'NOTES', size_kb: 0.4 }], open: null,
  disk: { name: 'data diskette', used_kb: 0.4, capacity_kb: 4, list: [{ index: 2, name: 'MAP', size_kb: 0.4 }] }, printer: { paper: 12 }, max_chars: 4000, max_name: 24, ...extra } });
const ui = (data: ComputerData = base, interactive = true): ScreenProps<ComputerData> => ({ template: 'computer.tmpl', interactive, act: vi.fn(), data });
const press = (name: string) => fireEvent.click(screen.getByRole('button', { name }));
const type = (line: string) => { const box = screen.getByLabelText('Type a command'); fireEvent.change(box, { target: { value: line } }); fireEvent.keyDown(box, { key: 'Enter' }); };

describe('Computer, command-line shell', () => {
  it('shows the boot lines and programs, and runs one from its command', () => {
    const props = ui(); const { container } = render(<Computer {...props} />);
    expect(screen.getByRole('log').textContent).toContain('MEMORY CHECK OK');
    expect(container.textContent).toContain('FILES - Write, read, print and copy text files.');
    expect(container.textContent).toContain('[NOT AVAILABLE: Needs a tier 2 processor.]');
    expect((screen.getByRole('button', { name: 'RUN LEDGER' }) as HTMLButtonElement).disabled).toBe(true);
    expect(props.act).not.toHaveBeenCalled();
    press('RUN FILES');
    expect(props.act).toHaveBeenCalledWith('open_program', { value: 'files' });
    press('POWER OFF');
    expect(props.act).toHaveBeenLastCalledWith('power', { value: 1 });
  });
  it('accepts typed commands and answers unknown ones in words without calling the server', () => {
    const props = ui(); const { container } = render(<Computer {...props} />);
    type('run files');
    expect(props.act).toHaveBeenCalledWith('open_program', { value: 'files' });
    type('dance');
    expect(screen.getByRole('status').textContent).toBe('* UNKNOWN COMMAND DANCE. TYPE HELP.');
    type('run ledger');
    expect(screen.getByRole('status').textContent).toContain('LEDGER IS NOT AVAILABLE: Needs a tier 2 processor.');
    expect(props.act).toHaveBeenCalledTimes(1);
    type('help');
    expect(container.textContent).toContain('RUN name - start a program');
    type('hardware');
    expect(screen.getByRole('table', { name: 'Installed parts' })).toBeTruthy();
  });
  it('says there is no power and offers nothing to press', () => {
    const { container } = render(<Computer {...ui({ ...base, powered: 0 })} />);
    expect(screen.getByRole('status').textContent).toBe('NO POWER.');
    expect(container.querySelectorAll('button,input,textarea')).toHaveLength(0);
  });
  it('falls back to the command-line shell for a shell it does not know, and copes with an empty snapshot', () => {
    render(<Computer {...ui({ ...base, shell: 'desktop' })} />);
    expect(screen.getByRole('button', { name: 'RUN FILES' })).toBeTruthy();
    cleanup();
    expect(() => render(<Computer {...ui({ powered: 1 })} />)).not.toThrow();
  });
  it('lists parts and empty slots, and offers Remove only with the case open', () => {
    const closed = ui(); const view = render(<Computer {...closed} />);
    press('HARDWARE');
    expect(view.container.textContent).toContain('Open the case with a screwdriver to remove parts');
    expect(view.container.textContent).toContain('Expansion(empty)');
    expect(screen.queryByRole('button', { name: 'REMOVE' })).toBeNull();
    const open = ui({ ...base, case_open: 1 });
    view.rerender(<Computer {...open} />);
    press('REMOVE');
    expect(open.act).toHaveBeenCalledWith('remove_module', { value: 3 });
  });
  it('starts on the Hardware tab when the snapshot asks for it', () => {
    render(<Computer {...ui({ ...base, tab: 'hardware' })} />);
    expect(screen.getByRole('button', { name: '> HARDWARE' }).getAttribute('aria-current')).toBe('true');
  });
  it('sends each file command with the row index', () => {
    const props = ui(files()); render(<Computer {...props} />);
    const send = (name: string, action: string, value: number | string) => { press(name); expect(props.act).toHaveBeenLastCalledWith(action, { value }); };
    send('OPEN', 'open_file', 1); send('PRINT', 'print_file', 1); send('COPY TO DISK', 'copy_to_disk', 1); send('COPY TO DRIVE', 'copy_from_disk', 2);
    send('NEW FILE', 'new_file', 1); send('EJECT DISK', 'eject_disk', 1); send('HOME', 'home', 1);
    expect(screen.getByRole('table', { name: 'Files on the drive' }).textContent).toContain('NOTES0.4 KB');
  });
  it('deletes only after a second press', () => {
    const props = ui(files()); render(<Computer {...props} />);
    fireEvent.click(screen.getAllByRole('button', { name: 'DELETE' })[0]);
    expect(props.act).not.toHaveBeenCalled();
    press('KEEP');
    fireEvent.click(screen.getAllByRole('button', { name: 'DELETE' })[1]);
    press('CONFIRM DELETE');
    expect(props.act).toHaveBeenCalledTimes(1);
    expect(props.act).toHaveBeenCalledWith('delete_disk_file', { value: 2 });
  });
  it('explains missing drive, disk, printer and paper in words', () => {
    const { container, rerender } = render(<Computer {...ui(files({ drive: null, disk: null, printer: null }))} />);
    expect(container.textContent).toContain('NO DRIVE INSTALLED');
    expect(container.textContent).toContain('NO DISK IN THE READER.');
    expect(container.textContent).toContain('NO PRINTER ATTACHED.');
    expect(screen.queryByRole('button', { name: 'NEW FILE' })).toBeNull();
    rerender(<Computer {...ui(files({ printer: { paper: 0 } }))} />);
    expect(container.textContent).toContain('Load paper to print.');
    expect((screen.getByRole('button', { name: 'PRINT' }) as HTMLButtonElement).disabled).toBe(true);
  });
  it('keeps the draft in the window through updates and sends it only on Save', () => {
    const data = files({ open: { index: 1, name: 'NOTES', body: 'first' } });
    const props = ui(data); const view = render(<Computer {...props} />);
    const text = screen.getByLabelText('File text') as HTMLTextAreaElement;
    expect(text.maxLength).toBe(4000);
    expect((screen.getByLabelText('NAME') as HTMLInputElement).maxLength).toBe(24);
    fireEvent.change(text, { target: { value: 'first & second' } });
    expect(props.act).not.toHaveBeenCalled();
    expect(view.container.textContent).toContain('not saved');
    expect((screen.getByRole('button', { name: 'PRINT' }) as HTMLButtonElement).disabled).toBe(true);
    // An unrelated update (the status line) leaves the draft alone.
    view.rerender(<Computer {...props} data={{ ...data, status: 'Printer out of paper.' }} />);
    expect((screen.getByLabelText('File text') as HTMLTextAreaElement).value).toBe('first & second');
    expect(screen.getByRole('status').textContent).toBe('* Printer out of paper.');
    press('SAVE');
    expect(props.act).toHaveBeenCalledTimes(1);
    expect(props.act).toHaveBeenCalledWith('save_file', { value: 1, name: 'NOTES', body: 'first & second' });
    // The server's saved copy replaces the draft once it changes.
    view.rerender(<Computer {...props} data={files({ open: { index: 1, name: 'NOTES', body: 'first &amp; second' } })} />);
    expect((screen.getByLabelText('File text') as HTMLTextAreaElement).value).toBe('first & second');
    expect(view.container.textContent).not.toContain('not saved');
    press('CLOSE');
    expect(props.act).toHaveBeenLastCalledWith('close_file', { value: 1 });
  });
  it('saves a new file as index 0 and refuses a nameless or oversized one with a message', () => {
    const props = ui(files({ open: { index: 0, name: '', body: '' } })); render(<Computer {...props} />);
    fireEvent.change(screen.getByLabelText('File text'), { target: { value: 'hello' } });
    press('SAVE');
    expect(props.act).not.toHaveBeenCalled();
    expect(screen.getByRole('status').textContent).toContain('Give the file a name');
    fireEvent.change(screen.getByLabelText('NAME'), { target: { value: ' LOG ' } });
    press('SAVE');
    expect(props.act).toHaveBeenCalledWith('save_file', { value: 0, name: 'LOG', body: 'hello' });
    fireEvent.change(screen.getByLabelText('File text'), { target: { value: '日'.repeat(PAYLOAD_LIMIT / 3) } });
    press('SAVE');
    expect(props.act).toHaveBeenCalledTimes(1);
    expect(screen.getByRole('status').textContent).toContain('too long to send');
    expect(screen.queryByRole('button', { name: 'PRINT' })).toBeNull();
  });
  it('disables server commands when the window is read-only', () => {
    const props = ui(files(), false); render(<Computer {...props} />);
    for (const name of ['OPEN', 'NEW FILE', 'HOME', 'POWER OFF']) expect((screen.getByRole('button', { name }) as HTMLButtonElement).disabled).toBe(true);
    expect(props.act).not.toHaveBeenCalled();
  });
});
