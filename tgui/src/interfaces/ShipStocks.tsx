import type { ShipStocksData } from '../data';
import type { ScreenProps } from '../types';
import { SnapshotTable, cell } from './kit';

export function ShipStocks({ data }: ScreenProps<ShipStocksData>) {
  return <SnapshotTable label="Ship stocks" rows={data.stocks} empty="No stock snapshot is available."
    hint="Snapshot from the ship inventory book. Use the book again to refresh."
    columns={[{ label: 'Resource', cell: cell('label') }, { label: 'Quantity', align: 'right', cell: cell('amount', 'unit') }]} />;
}
