import { Fragment } from 'react';
import { Section } from 'tgui-core/components';
import type { ScreenProps } from '../types';
import { text } from './common';

// No formatting dialect. Reject ambiguous legacy text for whole-view fallback.
export function flavorText(value: unknown): string {
  if (typeof value !== 'string' || /[<\u0000-\u0008\u000b\u000c\u000e-\u001f\u007f]/.test(value)) throw new Error('Unsupported flavor text');
  for (const match of value.matchAll(/&(?=[A-Za-z#])/g)) {
    const start = match.index + 1, end = value.indexOf(';', start);
    if (end < 0 || end - start > 16) throw new Error('Unsupported flavor entity');
    const entity = value.slice(start, end);
    if (['amp', 'lt', 'gt', 'quot', 'apos', 'AMP', 'LT', 'GT', 'QUOT'].includes(entity)) continue;
    if (!/^#[0-9]{1,7}$/.test(entity)) throw new Error('Unsupported flavor entity');
    const point = Number(entity.slice(1));
    if (point <= 0 || point > 0x10ffff || (point >= 0xd800 && point <= 0xdfff) || (point >= 127 && point <= 159) || (point < 32 && ![9, 10, 13].includes(point))) throw new Error('Unsupported flavor entity');
  }
  return text(value);
}
export function CharacterFlavor({ data }: ScreenProps) {
  if (typeof data.name !== 'string' || typeof data.text !== 'string' || data.name.length + data.text.length > 65536) throw new Error('Unsupported flavor snapshot');
  const name = flavorText(data.name);
  // Only literal stored LF becomes BR, matching replacetext before HTML decode.
  // An encoded &#10; remains whitespace text, not an invented hard line break.
  const lines = data.text.split('\n');
  if (lines.length > 2048) throw new Error('Flavor line budget');
  const decoded = lines.map(flavorText); // Validate all lines before rendering.
  return <Section><article aria-label={`Character description: ${name}`} className="character-flavor">
    {decoded.map((line, index) => <Fragment key={index}>{index > 0 && <br />}{line}</Fragment>)}
  </article></Section>;
}
