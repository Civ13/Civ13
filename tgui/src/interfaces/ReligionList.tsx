import type { ReligionListData } from '../data';
import type { ScreenProps } from '../types';
import { SnapshotTable, cell } from './kit';

export function ReligionList({ data }: ScreenProps<ReligionListData>) {
  return <SnapshotTable label="Religion list" rows={data.religions} empty="No religions have been founded."
    hint="Snapshot of founded religions. Use Check Religion List again to refresh."
    columns={[{ label: 'Religion', cell: cell('name') }, { label: 'Points', align: 'right', cell: cell('points') }]} />;
}
