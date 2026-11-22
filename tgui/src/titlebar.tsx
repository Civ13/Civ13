import { createContext, type PointerEvent as ReactPointerEvent, useEffect, useRef } from 'react';

// The window's own title bar, drawn in place of BYOND's: the status light, the
// title, a slot a screen can put its buttons in, and a close button. Dragging
// the bar moves the window; the edges and corner resize it. Both talk to the
// Dream Seeker window through byond://winget and byond://winset.

// A screen's layout portals its title bar buttons here (see layouts/index.tsx).
export const TitleBarSlot = createContext<HTMLElement | null>(null);

const MIN_WIDTH = 160;
const MIN_HEIGHT = 100;

function byondCall(path: string, params: Record<string, string>) {
  const query = Object.entries(params).map(([key, value]) => `${encodeURIComponent(key)}=${encodeURIComponent(value)}`).join('&');
  const url = `byond://${path}?${query}`;
  try {
    const bridge = (window as unknown as { cef_to_byond?: (url: string) => void }).cef_to_byond;
    if (bridge) bridge(url);
    else window.location.href = url;
  }
  catch { /* No bridge outside BYOND; the window just stays where it is. */ }
}

export function winset(id: string, params: Record<string, string>) {
  byondCall('winset', { id, ...params });
}

type Point = { x: number; y: number };
let callbacks = 0;
// One property of a window, as BYOND reports it ({x, y} for pos and size).
export function winget(id: string, property: string): Promise<Point | null> {
  return new Promise(resolve => {
    const name = `civ13Winget${++callbacks}`;
    const target = window as unknown as Record<string, unknown>;
    target[name] = (props: Record<string, unknown>) => {
      delete target[name];
      const value = props?.[property] as Point | undefined;
      resolve(value && Number.isFinite(value.x) && Number.isFinite(value.y) ? value : null);
    };
    byondCall('winget', { id, property, callback: name });
  });
}

// Hides BYOND's own title bar and resize border while the window draws its
// own, and gives them back if the player turns the built-in bar off.
export function useNativeTitleBar(windowId: string | undefined, own: boolean) {
  const hidden = useRef(false);
  useEffect(() => {
    if (!windowId || own === hidden.current) return;
    hidden.current = own;
    winset(windowId, { titlebar: own ? 'false' : 'true', 'can-resize': own ? 'false' : 'true' });
  }, [windowId, own]);
}

type Edge = { x: number; y: number };
// Moves (edge null) or resizes the window while the pointer is held. Screen
// coordinates are CSS pixels; BYOND's are device pixels.
function startGesture(windowId: string, event: ReactPointerEvent<HTMLElement>, edge: Edge | null) {
  if (event.button !== 0) return;
  const target = event.target as HTMLElement;
  if (!edge && target.closest('button, input, select, textarea, a, .civ13-titlebar__slot')) return;
  event.preventDefault();
  const handle = event.currentTarget;
  const ratio = window.devicePixelRatio || 1;
  const start = { x: event.screenX * ratio, y: event.screenY * ratio };
  let base: Point | null = null;
  let latest: Point | null = null;
  let frame = 0;
  const apply = () => {
    frame = 0;
    if (!base || !latest) return;
    const dx = latest.x - start.x, dy = latest.y - start.y;
    if (!edge) winset(windowId, { pos: `${Math.round(base.x + dx)},${Math.round(base.y + dy)}` });
    else winset(windowId, { size: `${Math.max(MIN_WIDTH, Math.round(base.x + dx * edge.x))}x${Math.max(MIN_HEIGHT, Math.round(base.y + dy * edge.y))}` });
  };
  const schedule = () => { if (!frame) frame = window.requestAnimationFrame(apply); };
  winget(windowId, edge ? 'size' : 'pos').then(value => { base = value; schedule(); });
  const move = (moved: PointerEvent) => { latest = { x: moved.screenX * ratio, y: moved.screenY * ratio }; schedule(); };
  const end = () => {
    handle.removeEventListener('pointermove', move);
    handle.removeEventListener('pointerup', end);
    handle.removeEventListener('pointercancel', end);
  };
  try { handle.setPointerCapture(event.pointerId); } catch { /* Keeps working while the pointer stays inside. */ }
  handle.addEventListener('pointermove', move);
  handle.addEventListener('pointerup', end);
  handle.addEventListener('pointercancel', end);
}

const STATUS = {
  2: ['good', 'Interactive'],
  1: ['warn', 'Read-only'],
} as const;

type TitleBarProps = { title: string; status?: number; windowId?: string; onSlot: (slot: HTMLElement | null) => void; onClose: () => void };

export function TitleBar({ title, status, windowId, onSlot, onClose }: TitleBarProps) {
  const [tone, label] = STATUS[status as 1 | 2] ?? ['bad', 'Unavailable'];
  return <div className="civ13-titlebar" onPointerDown={windowId ? event => startGesture(windowId, event, null) : undefined}>
    <span className={`civ13-titlebar__status civ13-titlebar__status--${tone}`} title={label} aria-label={label} role="img">{'●'}</span>
    <h1 className="civ13-titlebar__title">{title}</h1>
    <div className="civ13-titlebar__slot" ref={onSlot} />
    <button type="button" className="civ13-titlebar__close" title="Close" aria-label="Close" onClick={onClose}>{'×'}</button>
  </div>;
}

const EDGES: [string, Edge][] = [['e', { x: 1, y: 0 }], ['s', { x: 0, y: 1 }], ['se', { x: 1, y: 1 }]];

export function ResizeHandles({ windowId }: { windowId?: string }) {
  if (!windowId) return null;
  return <>{EDGES.map(([name, edge]) => <div key={name} className={`civ13-resize civ13-resize--${name}`} aria-hidden="true"
    onPointerDown={event => startGesture(windowId, event, edge)} />)}</>;
}
