import { useEffect, useRef, useState } from 'react';
import { Section, NoticeBox } from 'tgui-core/components';
import type { ScreenProps } from '../types';
import { Action, list, text } from './common';
export function lineCells(x0: number, y0: number, x1: number, y1: number): string[] {
  const cells: string[] = [];
  const dx = Math.abs(x1 - x0), dy = Math.abs(y1 - y0), sx = x0 < x1 ? 1 : -1, sy = y0 < y1 ? 1 : -1;
  let error = dx - dy;
  while (true) {
    cells.push(`${x0},${y0}`);
    if (x0 === x1 && y0 === y1) break;
    const twice = 2 * error;
    if (twice > -dy) { error -= dy; x0 += sx; }
    if (twice < dx) { error += dx; y0 += sy; }
  }
  return cells;
}
// JSON and percent-encoding consume more URL bytes than old NanoUI hrefs.
export const STROKE_CHUNK = 60;
export function strokeChunks(cells: string[]): string[] {
  const chunks: string[] = [];
  for (let offset = 0; offset < cells.length; offset += STROKE_CHUNK) chunks.push(cells.slice(offset, offset + STROKE_CHUNK).join('_'));
  return chunks;
}
export function Faction(ui: ScreenProps) {
  const { data } = ui;
  const founding = ui.template === 'faction_creation.tmpl';
  const [overlay, setOverlay] = useState<Record<string, string>>({});
  const [busy, setBusy] = useState(false);
  const stroke = useRef<{ cells: Set<string>; x: number; y: number; color: string } | null>(null);
  const timer = useRef<ReturnType<typeof setTimeout> | undefined>(undefined);
  const inFlight = useRef(false);
  const latest = useRef(ui); latest.current = ui;
  const end = useRef<() => void>(() => {});
  const cancel = () => { stroke.current = null; if (timer.current) clearTimeout(timer.current); timer.current = undefined; inFlight.current = false; setBusy(false); setOverlay({}); };
  end.current = () => {
    const current = stroke.current;
    stroke.current = null;
    if (!current || !latest.current.interactive) return;
    const chunks = strokeChunks(Array.from(current.cells));
    if (!chunks.length) return;
    inFlight.current = true; setBusy(true);
    const send = (index: number) => {
      if (!latest.current.interactive) { cancel(); return; }
      latest.current.act('stroke', { stroke: 1, cells: chunks[index], ...(index ? { stroke_continue: 1 } : {}) });
      // Keep controls serialized until the final navigation has had time to land.
      timer.current = setTimeout(() => {
        if (index + 1 < chunks.length) send(index + 1);
        else { timer.current = undefined; inFlight.current = false; setBusy(false); setOverlay({}); }
      }, 250);
    };
    send(0);
  };
  useEffect(() => {
    const finish = () => end.current();
    document.addEventListener('mouseup', finish);
    window.addEventListener('blur', finish);
    return () => { document.removeEventListener('mouseup', finish); window.removeEventListener('blur', finish); if (timer.current) clearTimeout(timer.current); stroke.current = null; };
  }, []);
  useEffect(() => { if (!ui.interactive) cancel(); }, [ui.interactive]);
  useEffect(() => { if (!stroke.current && !inFlight.current) setOverlay({}); }, [data.grid]);
  const paint = (x: number, y: number) => {
    const current = stroke.current;
    if (!current) return;
    const patch: Record<string, string> = {};
    for (const cell of lineCells(current.x, current.y, x, y)) { current.cells.add(cell); patch[cell] = current.color; }
    current.x = x; current.y = y;
    setOverlay(previous => ({ ...previous, ...patch }));
  };
  const locked = { ...ui, interactive: ui.interactive && !busy && !stroke.current };
  return <>
    {founding && <Section title="Found a new faction"><p><strong>{text(data.name) || '(no name chosen yet)'}</strong> <Action ui={locked} action="set_name">Choose a name...</Action></p>
      <p>Both words are optional and shown in the server's Faction List.</p><p>Motto: {text(data.motto) || '(none)'} <Action ui={locked} action="set_motto">Set motto...</Action></p>
      <p>Flavour text: {text(data.flavour) || '(none)'} <Action ui={locked} action="set_flavour">Set flavour text...</Action></p></Section>}
    <Section title={founding ? "Draw your faction's symbol" : "Design your faction's symbol"}>
      <p>32x32 pixels, shown on your faction's banners.{founding && ' Your faction colors are taken from this drawing.'}</p>
      <div className="faction-tools"><span className="swatch" style={{ backgroundColor: data.color }} /><Action ui={locked} action="pick_color">Pick color</Action>
        <Action ui={locked} action="set_tool" value="paint" selected={data.tool === 'paint'}>Paint</Action><Action ui={locked} action="set_tool" value="bucket" selected={data.tool === 'bucket'}>Bucket fill</Action>
        <Action ui={locked} action="stamp">Stamp a shape...</Action><Action ui={locked} action="undo">Undo</Action><Action ui={locked} action="clear">Clear to blank</Action>{!founding && <Action ui={locked} action="save">Save</Action>}
      </div>
      {busy && <NoticeBox>Sending brush stroke...</NoticeBox>}
      <div className="faction-canvas" role="group" aria-label="Faction symbol pixels" onDragStart={event => event.preventDefault()}>
        {Array.from({ length: 1024 }, (_, i) => {
          const x = i % 32 + 1, y = Math.floor(i / 32) + 1, key = `${x},${y}`;
          return <button type="button" key={key} aria-label={`Pixel ${x},${y}`} className="faction-cell" tabIndex={-1} disabled={!ui.interactive || busy}
            style={{ backgroundColor: overlay[key] ?? list(data.grid)[i] ?? '#FFFFFF' }}
            onMouseDown={event => {
              if (event.button !== 0 || !ui.interactive || inFlight.current) return;
              event.preventDefault();
              if (stroke.current) { end.current(); return; }
              if (data.tool === 'bucket') { ui.act('paint', { paint: 1, x, y }); return; }
              stroke.current = { cells: new Set(), x, y, color: data.color || '#000000' }; paint(x, y);
            }} onMouseEnter={event => { if (stroke.current && event.buttons === 0) end.current(); else if (stroke.current) paint(x, y); }} />;
        })}
      </div>
      <p>Click and drag to draw an unbroken line. Undo takes back the whole drag. Stamp seeds an editable classic shape. {founding ? 'A blank canvas uses the plain shape. Closing abandons this draft.' : 'Nothing is visible on your banner until you Save.'}</p>
    </Section>
    {founding && <Section title="Found it"><Action ui={locked} action="found">Found the faction</Action> You become its Leader. Closing this window abandons the draft.</Section>}
  </>;
}
