import { Component, type ReactNode, useEffect, useSyncExternalStore } from 'react';
import { createRoot } from 'react-dom/client';
import { Button, NoticeBox } from 'tgui-core/components';
import { interfaces } from './interfaces';
import { text } from './interfaces/common';
import { emptyState, updateState } from './state';
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
  render() { return this.state.failed ? <p>Switching to classic interface...</p> : this.props.children; }
}
function App() {
  const current = useSyncExternalStore(subscribe, () => state);
  useEffect(() => { window.Civ13Tgui.ready(); }, []);
  const { config, data } = current;
  const template = config.template ?? '';
  const Screen = interfaces[template];
  const interactive = config.status === 2;
  const act = (action: string, params: Params = {}) => {
    if (state.config.status === 2) window.Civ13Tgui.send(`act/${action}`, params);
  };
  return <main className="civ13-app"><header><h1>{text(config.title) || 'Civilization 13'}</h1><Button onClick={() => window.Civ13Tgui.fallback()}>Classic interface</Button></header>
    {config.status === 0 ? <NoticeBox>This interface is unavailable.</NoticeBox> : config.status === -1 ? <NoticeBox>This interface has closed.</NoticeBox> : <>
      {config.status === 1 && <NoticeBox>Read-only: interaction is unavailable.</NoticeBox>}
      {Screen ? <Screen key={template} template={template} data={data} act={act} interactive={interactive} /> : <NoticeBox>{template ? 'Unsupported interface. Use the classic interface.' : 'Waiting for interface data...'}</NoticeBox>}
    </>}
  </main>;
}
window.receiveUpdateData = receive;
for (const raw of window.Civ13Tgui.queue.splice(0)) receive(raw);
const root = document.getElementById('root');
if (root) createRoot(root).render(<Boundary><App /></Boundary>);
else window.Civ13Tgui.fallback();
