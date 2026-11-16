import { Button } from 'tgui-core/components';
import type { ReactNode } from 'react';
import type { ScreenProps, Params } from '../types';
import { decode } from '../state';
export function list(value: unknown): any[] { return Array.isArray(value) ? value : []; }
// Screens receive decoded snapshots (see decodeData), so a field is shown as it is.
export function str(value: unknown): string { return String(value ?? ''); }
// Document windows keep their snapshot untouched and decode the few plain fields themselves.
export const text = decode;
export function Action({ ui, action, value = 1, params = {}, disabled = false, selected = false, children }: {
  ui: ScreenProps; action: string; value?: string | number; params?: Params; disabled?: boolean; selected?: boolean; children: ReactNode;
}) {
  return <Button disabled={!ui.interactive || disabled} selected={selected}
    onClick={() => ui.act(action, { value, ...params })}>{children}</Button>;
}
