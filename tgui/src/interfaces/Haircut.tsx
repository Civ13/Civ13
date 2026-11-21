import { useEffect, useRef, useState } from 'react';
import { Button, NoticeBox } from 'tgui-core/components';
import type { HaircutData, HaircutStyle } from '../data';
import type { ScreenProps } from '../types';
import { list, str } from './common';

// The Haircut window: pick a style by its picture, see it on the whole figure
// from every side, then start the cut. Choosing is local; only Start cutting
// sends anything, as one pair of styles.
type UI = ScreenProps<HaircutData>;
const CELL = 32;
const sides = ['front', 'east', 'back', 'west'] as const;
const lengths = [['all', 'All'], ['0', 'Shaven'], ['1', 'Short'], ['2', 'Medium'], ['3', 'Long']] as const;
const safeFile = (value: unknown) => /^[\w-]+\.png$/.test(str(value)) ? str(value) : '';
const safeColor = (value: unknown) => /^#[0-9a-f]{6}$/i.test(str(value)) ? str(value) : '#000000';
// Mid-back hair is filed with shoulder length: both are "Long" to a player.
const band = (style: HaircutStyle) => String(Math.min(3, Math.max(0, Number(style.length ?? 0))));

function usePicture(file: string) {
  const [picture, setPicture] = useState<HTMLImageElement | null>(null);
  useEffect(() => {
    setPicture(null);
    if (!file) return;
    let live = true;
    const image = new Image();
    image.onload = () => { if (live) setPicture(image); };
    image.src = file;
    return () => { live = false; };
  }, [file]);
  return picture;
}

// One cell of a sheet. A tinted cell has the hair colour added to it the way
// the game colours hair, without reading pixels back.
type Part = { picture: HTMLImageElement | null; row: number; tint?: string };
let scratch: HTMLCanvasElement | null = null;
function paint(canvas: HTMLCanvasElement | null, parts: Part[], side: number, left: number, top: number) {
  // The test browser has no canvas and only complains when asked for one.
  if (!canvas || /jsdom/i.test(navigator.userAgent)) return;
  let ctx: CanvasRenderingContext2D | null = null;
  try { ctx = canvas.getContext('2d'); } catch { return; }
  if (!ctx) return;
  ctx.clearRect(0, 0, canvas.width, canvas.height);
  for (const part of parts) {
    if (!part.picture) continue;
    const sx = side * CELL, sy = part.row * CELL;
    if (!part.tint) { ctx.drawImage(part.picture, sx, sy, CELL, CELL, -left, -top, CELL, CELL); continue; }
    scratch ??= document.createElement('canvas');
    scratch.width = CELL; scratch.height = CELL;
    const tinted = scratch.getContext('2d');
    if (!tinted) continue;
    tinted.drawImage(part.picture, sx, sy, CELL, CELL, 0, 0, CELL, CELL);
    tinted.globalCompositeOperation = 'lighter';
    tinted.fillStyle = part.tint;
    tinted.fillRect(0, 0, CELL, CELL);
    tinted.globalCompositeOperation = 'destination-in';
    tinted.drawImage(part.picture, sx, sy, CELL, CELL, 0, 0, CELL, CELL);
    tinted.globalCompositeOperation = 'source-over';
    ctx.drawImage(scratch, -left, -top);
  }
}
function Figure({ parts, side, left = 0, top = 0, width = CELL, height = CELL, label }: { parts: Part[]; side: number; left?: number; top?: number; width?: number; height?: number; label?: string }) {
  const canvas = useRef<HTMLCanvasElement>(null);
  const key = parts.map(part => `${part.picture ? 1 : 0}:${part.row}:${part.tint ?? ''}`).join('|');
  useEffect(() => paint(canvas.current, parts, side, left, top), [key, side, left, top]);
  return <canvas ref={canvas} width={width} height={height} role={label ? 'img' : undefined} aria-label={label} aria-hidden={label ? undefined : true} />;
}

function Tiles({ styles, current, chosen, choose, draw, label, disabled }: { styles: HaircutStyle[]; current: string; chosen: string; choose: (name: string) => void; draw: (style: HaircutStyle) => Part[]; label: string; disabled: boolean }) {
  return <div className="cut-tiles" role="group" aria-label={label}>
    {styles.map(style => {
      const name = str(style.name);
      return <button key={name} type="button" className={name === chosen ? 'cut-tile cut-tile-on' : 'cut-tile'} aria-pressed={name === chosen} disabled={disabled} onClick={() => choose(name)}>
        <span className="cut-thumb"><Figure parts={draw(style)} side={0} left={7} top={0} width={18} height={15} /></span>
        {name === current && <span className="cut-now">Now</span>}
        <span className="cut-name">{name}</span>
      </button>;
    })}
    {!styles.length && <span className="kit-hint">Nothing by that name.</span>}
  </div>;
}

export function Haircut(ui: UI) {
  const { data } = ui;
  const hairStyles = list(data.hair_styles), beardStyles = list(data.beard_styles);
  const nowHair = str(data.hair), nowBeard = str(data.beard);
  const [pickedHair, setHair] = useState<string | null>(null);
  const [pickedBeard, setBeard] = useState<string | null>(null);
  const [side, setSide] = useState(0);
  const [after, setAfter] = useState(true);
  const [length, setLength] = useState('all');
  const [find, setFind] = useState('');
  // A style that stopped being offered (the hair changed meanwhile) falls back to the current one.
  const hair = pickedHair !== null && hairStyles.some(style => style.name === pickedHair) ? pickedHair : nowHair;
  const beard = pickedBeard !== null && beardStyles.some(style => style.name === pickedBeard) ? pickedBeard : nowBeard;
  const sheet = usePicture(safeFile(data.sheet)), body = usePicture(safeFile(data.body));
  const hairColor = safeColor(data.hair_color), beardColor = safeColor(data.beard_color);
  const part = (styles: HaircutStyle[], name: string, color: string): Part[] => {
    const style = styles.find(entry => entry.name === name);
    return style ? [{ picture: sheet, row: Number(style.row ?? 0), tint: style.tint ? color : undefined }] : [];
  };
  const under: Part = { picture: body, row: 0 }, over: Part = { picture: body, row: 1 };
  const shownHair = after ? hair : nowHair, shownBeard = after ? beard : nowBeard;
  const whole = [under, ...part(beardStyles, shownBeard, beardColor), ...part(hairStyles, shownHair, hairColor), over];

  const order = (styles: HaircutStyle[], current: string) => [...styles].sort((a, b) => Number(b.name === current) - Number(a.name === current));
  const bands = lengths.filter(([key]) => key === 'all' || hairStyles.some(style => band(style) === key));
  const shownStyles = order(hairStyles, nowHair).filter(style => (length === 'all' || band(style) === length) && str(style.name).toLowerCase().includes(find.toLowerCase()));
  const changed = hair !== nowHair || beard !== nowBeard;
  const self = !!data.self, name = str(data.name);
  const change = (label: string, from: string, to: string) => <>
    <dt>{label}</dt>
    <dd>{from === to ? <>{from} <span className="cut-same">(no change)</span></> : <><s>{from}</s> <span aria-hidden="true">&rarr;</span><span className="cut-sr"> becomes </span> <b>{to}</b></>}</dd>
  </>;

  return <div className="cut">
    <p className="cut-lead">{self ? 'Cutting your own hair.' : `Cutting ${name}'s hair.`} Pick a style to see it; nothing changes until you start the cut.</p>
    <div className="cut-columns">
      <div className="cut-side">
        <div className="setup-stage cut-stage"><Figure parts={whole} side={side} label={`${self ? 'You' : name} from the ${sides[side]}, ${after ? 'after the cut' : 'as now'}`} /></div>
        <div className="setup-turn">
          <button type="button" className="setup-turn-button" aria-label="Turn left" onClick={() => setSide((side + 3) % 4)}>&#9664;</button>
          <span>{sides[side]}</span>
          <button type="button" className="setup-turn-button" aria-label="Turn right" onClick={() => setSide((side + 1) % 4)}>&#9654;</button>
        </div>
        <span className="kit-choice" role="group" aria-label="Which look to show">
          <Button selected={!after} onClick={() => setAfter(false)}>Now</Button>
          <Button selected={after} onClick={() => setAfter(true)}>After the cut</Button>
        </span>
        <dl className="cut-changes">
          {change('Hair', nowHair, hair)}
          {beardStyles.length > 1 && change('Facial hair', nowBeard, beard)}
        </dl>
        <p className="kit-hint cut-foot">Shown without headwear.</p>
      </div>
      <div className="cut-main">
        <section className="cut-panel cut-panel-hair" aria-label="Hair">
          <div className="cut-head">
            <h2>Hair</h2>
            {bands.length > 2 && <span className="kit-choice" role="group" aria-label="Hair length">{bands.map(([key, label]) =>
              <Button key={key} selected={length === key} onClick={() => setLength(key)}>{label}</Button>)}</span>}
            {hairStyles.length > 12 && <input className="setup-field cut-find" type="text" placeholder="Find a style" aria-label="Find a hair style" value={find} onChange={event => setFind(event.target.value)} />}
          </div>
          <Tiles styles={shownStyles} current={nowHair} chosen={hair} label="Hair styles" disabled={!ui.interactive}
            choose={picked => { setHair(picked); setAfter(true); }} draw={style => [under, ...part(hairStyles, str(style.name), hairColor)]} />
        </section>
        {beardStyles.length > 1 && <section className="cut-panel cut-panel-beard" aria-label="Facial hair">
          <div className="cut-head"><h2>Facial hair</h2></div>
          <Tiles styles={order(beardStyles, nowBeard)} current={nowBeard} chosen={beard} label="Facial hair styles" disabled={!ui.interactive}
            choose={picked => { setBeard(picked); setAfter(true); }} draw={style => [under, ...part(beardStyles, str(style.name), beardColor)]} />
        </section>}
      </div>
    </div>
    {hairStyles.length <= 1 && beardStyles.length <= 1 && <NoticeBox>There is nothing shorter to cut to yet.</NoticeBox>}
    <div className="cut-actions">
      <p className="kit-hint">A razor only cuts shorter; longer styles come back as hair grows. The cut takes about {Number(data.seconds ?? 8)} seconds{self ? '' : ' and you must stay beside them'}.</p>
      <Button className="cut-cancel" disabled={!ui.interactive} onClick={() => ui.act('cancel')}>Cancel</Button>
      <Button className="cut-go" disabled={!ui.interactive || !changed} onClick={() => ui.act('cut', { value: hair, beard })}>Start cutting</Button>
    </div>
  </div>;
}
