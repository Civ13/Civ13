import { NoticeBox, Section } from 'tgui-core/components';
import type { ScreenProps } from '../types';
import { list, text } from './common';

export function ReligionList({ data }: ScreenProps) {
  const religions = list(data.religions);
  return <Section title="Religion List">
    <p>Snapshot of founded religions. Use Check Religion List again to refresh.</p>
    {religions.length ? <table className="inventory" aria-label="Religion list">
      <thead><tr><th scope="col">Religion</th><th scope="col">Points</th></tr></thead>
      <tbody>{religions.map((religion, i) => <tr key={i}>
        <th scope="row">{text(religion.name)}</th>
        <td>{text(religion.points)}</td>
      </tr>)}</tbody>
    </table> : <NoticeBox>No religions have been founded.</NoticeBox>}
  </Section>;
}
