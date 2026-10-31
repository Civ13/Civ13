import type { State } from './types';
export const emptyState: State = { config: {}, data: {} };
export function updateState(previous: State, raw: string): State {
  const message = JSON.parse(raw);
  if (!message || typeof message !== 'object' || Array.isArray(message)) throw new Error('Invalid UI update');
  if (message.config && (typeof message.config !== 'object' || Array.isArray(message.config))) throw new Error('Invalid config');
  if (message.data != null && (typeof message.data !== 'object' || Array.isArray(message.data))) throw new Error('Invalid data');
  return { config: { ...previous.config, ...message.config }, data: message.data == null ? previous.data : message.data };
}
