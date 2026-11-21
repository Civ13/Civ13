import { NoticeBox, Section } from 'tgui-core/components';
import type { KnownLanguagesData } from '../data';
import type { ScreenProps } from '../types';
import { list, str } from './common';
import { Card, Pill } from './kit';

type Family = NonNullable<KnownLanguagesData['families']>[number];
type Member = NonNullable<Family['members']>[number];

// How much of each other's speech two related languages follow, in plain words.
function followWords(percent: number) {
  if (percent >= 75) return 'most of what is said';
  if (percent >= 50) return 'more than half';
  if (percent >= 25) return 'some of it';
  return 'only a little';
}
function Standing({ member }: { member: Member }) {
  const [tone, label] = member.mother ? ['good', 'Mother tongue'] as const : member.known ? ['info', 'You speak it'] as const
    : member.learning ? ['progress', 'Learning'] as const : [null, ''] as const;
  return tone ? <>{' '}<Pill tone={tone}>{label}</Pill></> : null;
}
// One family: the old language, the languages that grew out of it, and how close they still are.
function FamilyCard({ family }: { family: Family }) {
  const members = list(family.members), links = list(family.links);
  return <Card>
    <strong>{str(family.root)} family</strong>
    <ul className="lang-tree" aria-label={`${str(family.root)} family`}>{members.map((member, index) => {
      const depth = Math.min(Math.max(Number(member.depth) || 0, 0), 4);
      const own = !!(member.mother || member.known || member.learning);
      return <li key={index} className={own ? 'lang-own' : undefined} style={{ paddingLeft: `${depth * 20}px` }}>
        {depth > 0 && <span className="lang-branch" aria-hidden="true">{'└ '}</span>}
        <strong>{str(member.name)}</strong><Standing member={member} />
        <span className="lang-origin">{member.parent
          ? ` - grew out of ${str(member.parent)}${member.nation ? ` among the ${str(member.nation)}` : ''}${member.era ? ` (${str(member.era)})` : ''}`
          : ' - the old language'}</span>
      </li>;
    })}</ul>
    {links.length > 0 && <ul className="lang-links" aria-label={`How close the ${str(family.root)} family is`}>{links.map((link, index) => {
      const percent = Math.min(Math.max(Number(link.percent) || 0, 0), 100);
      return <li key={index}><strong>{str(link.a)}</strong> and <strong>{str(link.b)}</strong> speakers follow about {percent}% of each other - {followWords(percent)}.</li>;
    })}</ul>}
  </Card>;
}

export function KnownLanguages({ data }: ScreenProps<KnownLanguagesData>) {
  const languages = list(data.languages);
  const families = list(data.families).filter(family => list(family.members).length > 1);
  return <>
    <Section title="Known Languages">
      {data.current_default && <p>Current default language: <strong>{str(data.current_default)}</strong></p>}
      {languages.length ? <ul>{languages.map((language, index) => <li key={index} aria-current={language.is_default ? 'true' : undefined}>
        <strong>{str(language.name)} ({str(language.prefix)})</strong>{language.is_default ? ' - default' : ''}
        <p>{str(language.description)}</p>
      </li>)}</ul> : <NoticeBox>No known languages are available.</NoticeBox>}
    </Section>
    {families.length > 0 && <Section title="Language families">
      <p className="kit-hint">Languages that grew apart on this world. Speakers of related languages still follow part of each other's speech.</p>
      {families.map((family, index) => <FamilyCard key={index} family={family} />)}
    </Section>}
  </>;
}
