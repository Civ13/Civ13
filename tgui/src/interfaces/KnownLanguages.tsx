import { NoticeBox, Section } from 'tgui-core/components';
import type { ScreenProps } from '../types';
import { list, text } from './common';

export function KnownLanguages({ data }: ScreenProps) {
  const languages = list(data.languages);
  return <Section title="Known Languages">
    {data.current_default && <p>Current default language: <strong>{text(data.current_default)}</strong></p>}
    {languages.length ? <ul>{languages.map((language, index) => <li key={index} aria-current={language.is_default ? 'true' : undefined}>
      <strong>{text(language.name)} ({text(language.prefix)})</strong>{language.is_default ? ' - default' : ''}
      <p>{text(language.description)}</p>
    </li>)}</ul> : <NoticeBox>No known languages are available.</NoticeBox>}
  </Section>;
}
