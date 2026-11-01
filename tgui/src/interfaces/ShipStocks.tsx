import { NoticeBox, Section } from 'tgui-core/components';
import type { ScreenProps } from '../types';
import { list, text } from './common';

export function ShipStocks({ data }: ScreenProps) {
  const stocks = list(data.stocks);
  return <Section title="Ship Stocks">
    <p>Snapshot from the ship inventory book. Use the book again to refresh.</p>
    {stocks.length ? <table className="inventory" aria-label="Ship stocks">
      <thead><tr><th scope="col">Resource</th><th scope="col">Quantity</th></tr></thead>
      <tbody>{stocks.map((stock, i) => <tr key={i}>
        <th scope="row">{text(stock.label)}</th>
        <td>{text(stock.amount)} {text(stock.unit)}</td>
      </tr>)}</tbody>
    </table> : <NoticeBox>No stock snapshot is available.</NoticeBox>}
  </Section>;
}
