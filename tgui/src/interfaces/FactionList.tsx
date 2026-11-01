import { NoticeBox, Section } from 'tgui-core/components';
import type { ScreenProps } from '../types';
import { list, text } from './common';

// Only the existing browse_rsc basename is accepted, never a URL or path.
const symbolSource = (value: unknown) => typeof value === 'string' && /^flist_[^/\\:?#%."'<>\s]*\.png$/.test(value) ? encodeURIComponent(value) : '';

export function FactionList({ data }: ScreenProps) {
  const factions = list(data.factions);
  return <Section title="Faction List">
    <p>Snapshot of populated factions. Use Check Faction List again to refresh.</p>
    {factions.length ? <table className="inventory" aria-label="Faction list">
      <thead><tr><th scope="col">Symbol</th><th scope="col">Faction</th></tr></thead>
      <tbody>{factions.map((faction, i) => {
        const symbol = symbolSource(faction.symbol);
        return <tr key={i}>
          <td>{symbol && <img src={symbol} width={32} height={32} alt="" />}</td>
          <th scope="row"><strong>{text(faction.name)}</strong>
            {faction.motto && <> - <em>{text(faction.motto)}</em></>}
            {faction.flavour && <p>{text(faction.flavour)}</p>}
            <p>{text(faction.members)} {faction.members === 1 ? 'member' : 'members'}.</p>
          </th>
        </tr>;
      })}</tbody>
    </table> : <NoticeBox>No populated factions are available.</NoticeBox>}
  </Section>;
}
