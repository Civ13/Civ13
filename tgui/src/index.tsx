import { Component, type ReactNode, useEffect, useState, useSyncExternalStore } from 'react';
import { createRoot } from 'react-dom/client';
import { NoticeBox } from 'tgui-core/components';
import { interfaces } from './interfaces';
import { text } from './interfaces/common';
import { emptyState, updateState } from './state';
import { ResizeHandles, TitleBar, TitleBarSlot, useNativeTitleBar } from './titlebar';
import type { Params, State } from './types';
import './styles.scss';
let state: State = emptyState;
const listeners = new Set<() => void>();
function subscribe(listener: () => void) { listeners.add(listener); return () => { listeners.delete(listener); }; }
function receive(raw: string) {
  try {
    const next = updateState(state, raw);
    if (!window.Civ13Tgui.acceptSnapshot(next.config)) return;
    state = next;
    listeners.forEach(listener => listener());
  }
  catch { window.Civ13Tgui.fallback(); }
}
class Boundary extends Component<{ children: ReactNode }, { failed: boolean }> {
  state = { failed: false };
  static getDerivedStateFromError() { return { failed: true }; }
  componentDidCatch() { window.Civ13Tgui.fallback(); }
  render() { return this.state.failed ? <p className="kit-failed">This window could not be shown. Close it and open it again.</p> : this.props.children; }
}
function App() {
  const current = useSyncExternalStore(subscribe, () => state);
  useEffect(() => { window.Civ13Tgui.ready(); }, []);
  const { config, data } = current;
  const [slot, setSlot] = useState<HTMLElement | null>(null);
  // Hide BYOND's bar only once this screen has drawn its own; a page that
  // fails before then keeps BYOND's bar, and the server restores it on fallback.
  const ownTitleBar = config.title_bar === 1;
  useNativeTitleBar(config.window, ownTitleBar);
  const template = config.template ?? '';
  const Screen = interfaces[template];
  const interactive = config.status === 2;
  const act = (action: string, params: Params = {}) => {
    if (state.config.status === 2) window.Civ13Tgui.send(`act/${action}`, params);
  };
  const title = text(config.title) || 'Civilization 13';
  return <TitleBarSlot.Provider value={ownTitleBar ? slot : null}>
    {ownTitleBar && <TitleBar title={title} status={config.status} windowId={config.window} onSlot={setSlot} onClose={() => window.Civ13Tgui.send('close')} />}
    <main className="civ13-app">{!ownTitleBar && <header><h1>{title}</h1></header>}
    {config.status === 0 ? <NoticeBox>This interface is unavailable.</NoticeBox> : config.status === -1 ? <NoticeBox>This interface has closed.</NoticeBox> : <>
      {config.status === 1 && <NoticeBox>Read-only: interaction is unavailable.</NoticeBox>}
      {Screen ? <Screen key={template} template={template} data={data} act={act} interactive={interactive} /> : <NoticeBox>{template ? 'This window is not available.' : 'Waiting for interface data...'}</NoticeBox>}
    </>}
  </main>
    {ownTitleBar && <ResizeHandles windowId={config.window} />}
  </TitleBarSlot.Provider>;
}
window.receiveUpdateData = receive;
for (const raw of window.Civ13Tgui.queue.splice(0)) receive(raw);
const root = document.getElementById('root');
if (root) createRoot(root).render(<Boundary><App /></Boundary>);
else window.Civ13Tgui.fallback();
