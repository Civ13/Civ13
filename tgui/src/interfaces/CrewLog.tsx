import type { ScreenProps } from '../types';
import { SnapshotTable, cell } from './kit';

export function CrewLog({ data }: ScreenProps) {
  return <SnapshotTable label="Crew log" rows={data.crew} empty="No crew are listed."
    hint="Snapshot from the crew log book. Use the book again to refresh."
    columns={[{ label: 'Name', cell: cell('name') }, { label: 'Job', align: 'right', cell: cell('job') }]} />;
}
