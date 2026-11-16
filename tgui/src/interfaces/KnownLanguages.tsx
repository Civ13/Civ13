import { NoticeBox, Section } from 'tgui-core/components';
import type { KnownLanguagesData } from '../data';
import type { ScreenProps } from '../types';
import { list, str } from './common';

export function KnownLanguages({ data }: ScreenProps<KnownLanguagesData>) {
  const languages = list(data.languages);
  return <Section title="Known Languages">
    {data.current_default && <p>Current default language: <strong>{str(data.current_default)}</strong></p>}
    {languages.length ? <ul>{languages.map((language, index) => <li key={index} aria-current={language.is_default ? 'true' : undefined}>
      <strong>{str(language.name)} ({str(language.prefix)})</strong>{language.is_default ? ' - default' : ''}
      <p>{str(language.description)}</p>
    </li>)}</ul> : <NoticeBox>No known languages are available.</NoticeBox>}
  </Section>;
}
