import { NoticeBox, Section } from 'tgui-core/components';
import type { ScreenProps } from '../types';
import { list, text } from './common';

export function CrewLog({ data }: ScreenProps) {
  const crew = list(data.crew);
  return <Section title="Crew Log">
    <p>Snapshot from the crew log book. Use the book again to refresh.</p>
    {crew.length ? <table className="inventory" aria-label="Crew log">
      <thead><tr><th scope="col">Name</th><th scope="col">Job</th></tr></thead>
      <tbody>{crew.map((member, i) => <tr key={i}>
        <th scope="row">{text(member.name)}</th>
        <td>{text(member.job)}</td>
      </tr>)}</tbody>
    </table> : <NoticeBox>No crew are listed.</NoticeBox>}
  </Section>;
}
