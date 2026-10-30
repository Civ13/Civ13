export type Params = Record<string, string | number>;
export type Data = Record<string, any>;
export type ScreenProps = { data: Data; act: (action: string, params?: Params) => void; interactive: boolean; template: string };
export type Config = { title?: string; status?: number; template?: string; ref?: string; window?: string; generation?: number };
export type State = { config: Config; data: Data };
declare global {
  interface Window {
    receiveUpdateData: (raw: string) => void;
    Civ13Tgui: { queue: string[]; send: (type: string, payload?: Params) => void; ready: () => void; fallback: () => void };
  }
}
