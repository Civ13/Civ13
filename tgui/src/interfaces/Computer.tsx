import { type ComponentType, type ReactNode, useEffect, useRef, useState } from 'react';
import type { ComputerData, ComputerFile, ComputerFiles } from '../data';
import type { Params, ScreenProps } from '../types';
import { list, str } from './common';

// The modular computer. One window for every machine: data.shell picks the
// look and each shell reads the same snapshot and sends the same actions.
// Only the 1969 command-line shell exists so far; add "desktop" and "mobile"
// to the shells table below when they are built.
type UI = ScreenProps<ComputerData>;
// The server refuses an action payload over 8192 bytes; a save that would not
// fit is stopped here with a plain message instead of vanishing.
export const PAYLOAD_LIMIT = 8000;
const bytes = (value: string) => typeof TextEncoder === 'function' ? new TextEncoder().encode(value).length : unescape(encodeURIComponent(value)).length;
const on = (value: unknown) => value === true || value === 1;
const kb = (value: unknown) => `${Number(value) || 0} KB`;

// A command on the screen: a server action when it has one, otherwise a local step.
function Cmd({ ui, action, value = 1, params, disabled = false, current = false, onClick, children }: {
  ui: UI; action?: string; value?: string | number; params?: Params; disabled?: boolean; current?: boolean; onClick?: () => void; children: ReactNode;
}) {
  return <button type="button" className="computer-cmd" aria-current={current ? 'true' : undefined} disabled={disabled || (!!action && !ui.interactive)}
    onClick={() => { onClick?.(); if (action) ui.act(action, { value, ...params }); }}>{children}</button>;
}
// Deleting takes two presses: the first asks, the second sends.
function Delete({ ui, action, value, name }: { ui: UI; action: string; value: number; name: string }) {
  const [asking, setAsking] = useState(false);
  if (!asking) return <Cmd ui={ui} disabled={!ui.interactive} onClick={() => setAsking(true)}>DELETE</Cmd>;
  return <span role="group" aria-label={`Delete ${name}?`}>
    <Cmd ui={ui} action={action} value={value} onClick={() => setAsking(false)}>CONFIRM DELETE</Cmd>
    <Cmd ui={ui} onClick={() => setAsking(false)}>KEEP</Cmd>
  </span>;
}
function FileTable({ label, rows, empty, buttons }: { label: string; rows: ComputerFile[]; empty: string; buttons: (file: ComputerFile, name: string) => ReactNode }) {
  if (!rows.length) return <p className="computer-dim">{empty}</p>;
  return <table className="computer-table" aria-label={label}>
    <thead><tr><th scope="col">NAME</th><th scope="col" className="computer-num">SIZE</th><th scope="col">COMMANDS</th></tr></thead>
    <tbody>{rows.map((file, i) => { const name = str(file.name) || 'UNNAMED'; return <tr key={`${file.index}:${name}:${i}`}>
      <th scope="row">{name}</th><td className="computer-num">{kb(file.size_kb)}</td><td>{buttons(file, name)}</td></tr>; })}</tbody>
  </table>;
}
// The draft stays in the window and reaches the server only on Save. A new
// snapshot replaces the draft only when the server's own copy has changed.
function Editor({ ui, files, say }: { ui: UI; files: ComputerFiles; say: (line: string) => void }) {
  const open = files.open ?? {};
  const index = Number(open.index) || 0, savedName = str(open.name), savedBody = str(open.body);
  const [name, setName] = useState(savedName), [body, setBody] = useState(savedBody);
  const seen = useRef({ name: savedName, body: savedBody });
  useEffect(() => {
    if (seen.current.name !== savedName) setName(savedName);
    if (seen.current.body !== savedBody) setBody(savedBody);
    seen.current = { name: savedName, body: savedBody };
  }, [savedName, savedBody]);
  const maxChars = Number(files.max_chars) || 4000, maxName = Number(files.max_name) || 24;
  const changed = name !== savedName || body !== savedBody;
  const title = name.trim();
  const save = () => {
    if (!title) return say('Give the file a name before saving.');
    if (!files.drive) return say('No drive installed: nothing to save to.');
    const params = { value: index, name: title, body };
    if (bytes(JSON.stringify(params)) > PAYLOAD_LIMIT) return say('This file is too long to send. Shorten it and save again.');
    say('');
    ui.act('save_file', params);
  };
  return <section aria-label="File editor">
    <p>{index ? `EDITING ${savedName || 'UNNAMED'}` : 'NEW FILE'} <span className="computer-dim">- {changed ? 'not saved' : 'saved'}</span></p>
    <label className="computer-field">NAME <input type="text" value={name} maxLength={maxName} disabled={!ui.interactive} autoFocus={!index}
      onChange={event => setName(event.target.value)} /></label>
    <textarea className="computer-text" aria-label="File text" rows={9} spellCheck={false} value={body} maxLength={maxChars} disabled={!ui.interactive} autoFocus={!!index}
      onChange={event => setBody(event.target.value)} />
    <p className="computer-dim">{body.length} of {maxChars} characters</p>
    <p className="computer-prompt"><span aria-hidden="true">&gt;</span>
      <Cmd ui={ui} disabled={!ui.interactive} onClick={save}>SAVE</Cmd>
      {files.printer && index > 0 && <Cmd ui={ui} action="print_file" value={index} disabled={changed || !(Number(files.printer.paper) > 0)}>PRINT</Cmd>}
      <Cmd ui={ui} action="close_file">{changed ? 'CLOSE WITHOUT SAVING' : 'CLOSE'}</Cmd>
    </p>
    {files.printer && index > 0 && changed && <p className="computer-dim">Save before printing: the printer prints the saved copy.</p>}
  </section>;
}
function Files({ ui, files, say }: { ui: UI; files: ComputerFiles; say: (line: string) => void }) {
  if (files.open) return <Editor key={Number(files.open.index) || 0} ui={ui} files={files} say={say} />;
  const drive = files.drive, disk = files.disk, printer = files.printer;
  const paper = Number(printer?.paper) || 0;
  return <section aria-label="Files">
    <p>FILES {drive ? <span className="computer-dim">- {str(drive.name)}: {Number(drive.used_kb) || 0} of {kb(drive.capacity_kb)} used</span> : null}</p>
    {!drive ? <p>NO DRIVE INSTALLED. Fit a storage drive to keep files.</p> : <FileTable label="Files on the drive" rows={list(files.list)} empty="NO FILES." buttons={(file, name) => <>
      <Cmd ui={ui} action="open_file" value={Number(file.index)}>OPEN</Cmd>
      {printer && <Cmd ui={ui} action="print_file" value={Number(file.index)} disabled={!paper}>PRINT</Cmd>}
      {disk && <Cmd ui={ui} action="copy_to_disk" value={Number(file.index)}>COPY TO DISK</Cmd>}
      <Delete ui={ui} action="delete_file" value={Number(file.index)} name={name} />
    </>} />}
    <p>{disk ? <>DISK <span className="computer-dim">- {str(disk.name)}: {Number(disk.used_kb) || 0} of {kb(disk.capacity_kb)} used</span></> : <span className="computer-dim">NO DISK IN THE READER.</span>}</p>
    {disk && <FileTable label="Files on the disk" rows={list(disk.list)} empty="THE DISK IS EMPTY." buttons={(file, name) => <>
      {drive && <Cmd ui={ui} action="copy_from_disk" value={Number(file.index)}>COPY TO DRIVE</Cmd>}
      <Delete ui={ui} action="delete_disk_file" value={Number(file.index)} name={name} />
    </>} />}
    <p className="computer-dim">{printer ? `PRINTER READY - ${paper} ${paper === 1 ? 'sheet' : 'sheets'} of paper${paper ? '' : '. Load paper to print.'}` : 'NO PRINTER ATTACHED.'}</p>
    <p className="computer-prompt"><span aria-hidden="true">&gt;</span>
      {drive && <Cmd ui={ui} action="new_file">NEW FILE</Cmd>}
      {disk && <Cmd ui={ui} action="eject_disk">EJECT DISK</Cmd>}
      <Cmd ui={ui} action="home">HOME</Cmd>
    </p>
  </section>;
}
function Hardware({ ui }: { ui: UI }) {
  const { data } = ui;
  const open = on(data.case_open);
  const parts = list(data.hardware), empty = list(data.empty_slots);
  return <section aria-label="Hardware">
    <p>HARDWARE <span className="computer-dim">- {str(data.name)}</span></p>
    <p>{open ? 'CASE OPEN. Parts can be removed.' : 'CASE CLOSED. Open the case with a screwdriver to remove parts.'}</p>
    {parts.length || empty.length ? <table className="computer-table" aria-label="Installed parts">
      <thead><tr><th scope="col">SLOT</th><th scope="col">PART</th><th scope="col">DETAIL</th><th scope="col">{open ? 'COMMANDS' : ''}</th></tr></thead>
      <tbody>
        {parts.map((part, i) => <tr key={`part${i}`}><th scope="row">{str(part.slot_label) || str(part.slot)}</th><td>{str(part.name)}</td><td>{str(part.detail) || '-'}</td>
          <td>{open && <Cmd ui={ui} action="remove_module" value={Number(part.index)}>REMOVE</Cmd>}</td></tr>)}
        {empty.map((slot, i) => <tr key={`empty${i}`}><th scope="row">{str(slot.slot_label) || str(slot.slot)}</th><td className="computer-dim">(empty)</td><td>-</td><td /></tr>)}
      </tbody>
    </table> : <p>NO PARTS FOUND.</p>}
  </section>;
}
function Home({ ui, help, run }: { ui: UI; help: boolean; run: (line: string) => void }) {
  const { data } = ui;
  const programs = list(data.programs);
  return <section aria-label="Terminal">
    <div className="computer-log" role="log" aria-label="Start-up messages">{list(data.boot_lines).map((line, i) => <div key={i}>{str(line)}</div>)}</div>
    {programs.length ? <ul className="computer-programs" aria-label="Programs">{programs.map((program, i) => <li key={i}>
      {str(program.name).toUpperCase()} - {str(program.desc)}{on(program.available) ? '' : ` [NOT AVAILABLE${program.reason ? `: ${str(program.reason)}` : ''}]`}</li>)}</ul>
      : <p>NO PROGRAMS INSTALLED.</p>}
    {help && <div className="computer-help" aria-label="Help">
      <div>RUN name - start a program</div><div>HARDWARE - list the parts inside</div><div>OFF - switch the machine off</div>
      <div>Press a command below, or type it and press Enter.</div>
    </div>}
    <p className="computer-prompt"><span aria-hidden="true">&gt;</span>
      {programs.map((program, i) => <Cmd key={i} ui={ui} action="open_program" value={str(program.id)} disabled={!on(program.available)}>RUN {str(program.name).toUpperCase()}</Cmd>)}
      <Cmd ui={ui} onClick={() => run('HELP')}>HELP</Cmd>
    </p>
  </section>;
}
function CliShell(ui: UI) {
  const { data } = ui;
  const [tab, setTab] = useState(str(data.tab) === 'hardware' ? 'hardware' : 'terminal');
  const [help, setHelp] = useState(false);
  const [note, setNote] = useState('');
  const [typed, setTyped] = useState('');
  const active = str(data.active);
  const files = active === 'files' && data.files ? data.files : null;
  // Typed commands are shortcuts for the buttons; anything else is answered here.
  const run = (line: string) => {
    const words = line.trim().toUpperCase().split(/\s+/).filter(Boolean);
    setNote('');
    if (!words.length) return;
    const rest = words.slice(1).join(' ');
    if (words[0] === 'HELP') { setTab('terminal'); setHelp(true); if (active) ui.act('home', { value: 1 }); return; }
    if (words[0] === 'HARDWARE') return setTab('hardware');
    if (words[0] === 'TERMINAL') return setTab('terminal');
    if (words[0] === 'HOME') { setTab('terminal'); if (active) ui.act('home', { value: 1 }); return; }
    if (words[0] === 'OFF' || line.trim().toUpperCase() === 'POWER OFF') return ui.act('power', { value: 1 });
    if (words[0] === 'RUN') {
      const program = list(data.programs).find(row => str(row.name).toUpperCase() === rest || str(row.id).toUpperCase() === rest);
      if (!program) return setNote(`NO PROGRAM CALLED ${rest || '(nothing)'}. TYPE HELP.`);
      if (!on(program.available)) return setNote(`${str(program.name).toUpperCase()} IS NOT AVAILABLE${program.reason ? `: ${str(program.reason)}` : '.'}`);
      setTab('terminal');
      return ui.act('open_program', { value: str(program.id) });
    }
    setNote(`UNKNOWN COMMAND ${words[0]}. TYPE HELP.`);
  };
  if (!on(data.powered)) return <div className="computer computer-cli"><p role="status">NO POWER.</p><p className="computer-dim">The machine is switched off or has no electricity.</p></div>;
  const status = note || str(data.status);
  return <div className="computer computer-cli">
    <div className="computer-bar">
      <span className="computer-title">{str(data.os_name).toUpperCase()} <span className="computer-dim">{str(data.os_version)}</span></span>
      <span role="group" aria-label="Views">
        <Cmd ui={ui} current={tab === 'terminal'} onClick={() => setTab('terminal')}>{tab === 'terminal' ? '> ' : ''}TERMINAL</Cmd>
        <Cmd ui={ui} current={tab === 'hardware'} onClick={() => setTab('hardware')}>{tab === 'hardware' ? '> ' : ''}HARDWARE</Cmd>
      </span>
      <Cmd ui={ui} action="power">POWER OFF</Cmd>
    </div>
    {tab === 'hardware' ? <Hardware ui={ui} />
      : files ? <Files ui={ui} files={files} say={setNote} />
      : active ? <section><p>{active.toUpperCase()} cannot be shown on this screen.</p><p className="computer-prompt"><span aria-hidden="true">&gt;</span><Cmd ui={ui} action="home">HOME</Cmd></p></section>
      : <Home ui={ui} help={help} run={run} />}
    <p className="computer-status" role="status">{status ? `* ${status}` : ''}</p>
    {!files?.open && <label className="computer-typed"><span aria-hidden="true">&gt;</span><input type="text" aria-label="Type a command" placeholder="TYPE A COMMAND, E.G. HELP" maxLength={40}
      spellCheck={false} value={typed} disabled={!ui.interactive} onChange={event => setTyped(event.target.value)}
      onKeyDown={event => { if (event.key === 'Enter') { run(typed); setTyped(''); } }} /></label>}
  </div>;
}
const shells: Record<string, ComponentType<UI>> = { cli: CliShell };
export function Computer(ui: UI) {
  const Shell = shells[str(ui.data.shell)] ?? CliShell;
  return <Shell {...ui} />;
}
