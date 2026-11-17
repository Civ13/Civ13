import type { Data, ScreenProps } from '../types';
import { str } from './common';
import { SnapshotTable } from './kit';

// Only the existing browse_rsc basename is accepted, never a URL or path.
const symbolSource = (value: unknown) => typeof value === 'string' && /^flist_[^/\\:?#%."'<>\s]*\.png$/.test(value) ? encodeURIComponent(value) : '';

function Details(faction: Data) {
  return <><strong>{str(faction.name)}</strong>
    {faction.motto && <> - <em>{str(faction.motto)}</em></>}
    {faction.flavour && <p>{str(faction.flavour)}</p>}
    {faction.renamed && <p><em>{str(faction.renamed)}</em></p>}
    {!!faction.calling && <p><strong>Calling newcomers by smoke signal.</strong></p>}</>;
}
function Symbol(faction: Data) {
  const symbol = symbolSource(faction.symbol);
  return symbol ? <img src={symbol} width={32} height={32} alt="" /> : null;
}
export function FactionList({ data }: ScreenProps) {
  return <SnapshotTable label="Faction list" rows={data.factions} empty="No populated factions are available."
    hint="Snapshot of populated factions. Use Check Faction List again to refresh. A smoke signal from a lit fire lets you invite newcomers to start near you."
    columns={[{ label: 'Faction', cell: Details }, { label: 'Symbol', cell: Symbol },
      { label: 'Members', align: 'right', cell: faction => `${str(faction.members)} ${faction.members === 1 ? 'member' : 'members'}.` }]} />;
}
