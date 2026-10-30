import { Button } from 'tgui-core/components';
import type { ReactNode } from 'react';
import type { ScreenProps, Params } from '../types';
export function list(value: unknown): any[] { return Array.isArray(value) ? value : []; }
// Server-produced text may already be entity encoded. Decode as text, never insert HTML.
export function text(value: unknown): string {
  const raw = String(value ?? '');
  return raw.replace(/&(#\d+|#x[\da-f]+|amp|lt|gt|quot|apos);/gi, (match, entity: string) => {
    const named: Record<string,string> = { amp: '&', lt: '<', gt: '>', quot: '"', apos: "'" };
    if (entity[0] !== '#') return named[entity.toLowerCase()] ?? match;
    const number = entity[1].toLowerCase() === 'x' ? parseInt(entity.slice(2), 16) : parseInt(entity.slice(1), 10);
    return number > 0 && number <= 0x10ffff ? String.fromCodePoint(number) : match;
  });
}
export function Action({ ui, action, value = 1, params = {}, disabled = false, selected = false, children }: {
  ui: ScreenProps; action: string; value?: string | number; params?: Params; disabled?: boolean; selected?: boolean; children: ReactNode;
}) {
  return <Button disabled={!ui.interactive || disabled} selected={selected}
    onClick={() => ui.act(action, { [action]: value, ...params })}>{children}</Button>;
}
