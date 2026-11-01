import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, render, screen, within } from '@testing-library/react';

vi.mock('tgui-core/components', () => ({
  Section: ({ children, title }: any) => <section><h2>{title}</h2>{children}</section>,
  NoticeBox: ({ children }: any) => <aside>{children}</aside>,
}));
import { ShipStocks } from './ShipStocks';
import type { ScreenProps } from '../types';

afterEach(cleanup);
const stocks = [
  ['Treasury', 125, 'reales'], ['Wood', 0, 'logs'], ['Cloth', 12, 'sheets'],
  ['Rope', 8, 'coils'], ['Food', 40, 'doses'], ['Water', 12.5, 'units'],
  ['Cannon Ammo', 3, 'balls'], ['Musket Ammo', 60, 'projectiles'],
  ['Pistol Ammo', 24, 'projectiles'], ['Blunderbuss Ammo', 5, 'projectiles'],
].map(([label, amount, unit]) => ({ label, amount, unit }));
const ui = (data: ScreenProps['data'] = { stocks }): ScreenProps => ({
  template: 'ship_stocks.tmpl', data, interactive: true, act: vi.fn(),
});

describe('Ship Stocks snapshot', () => {
  it('shows every resource in ledger order with zero, fractional water and original units', () => {
    const props = ui(); render(<ShipStocks {...props} />);
    const rows = within(screen.getByRole('table', { name: 'Ship stocks' })).getAllByRole('row');
    expect(rows).toHaveLength(11);
    stocks.forEach((stock, i) => {
      expect(within(rows[i + 1]).getByRole('rowheader').textContent).toBe(stock.label);
      expect(within(rows[i + 1]).getByRole('cell').textContent).toBe(`${stock.amount} ${stock.unit}`);
    });
    expect(screen.queryByRole('button')).toBeNull();
    expect(screen.queryByRole('link')).toBeNull();
    expect(props.act).not.toHaveBeenCalled();
  });
  it('replaces the snapshot on reopen without retaining an old amount', () => {
    const props = ui(); const view = render(<ShipStocks {...props} />);
    view.rerender(<ShipStocks {...props} data={{ stocks: [{ label: 'Water', amount: 20, unit: 'units' }] }} />);
    expect(screen.getByText('20 units')).toBeTruthy();
    expect(screen.queryByText('12.5 units')).toBeNull();
    expect(screen.queryByText('Treasury')).toBeNull();
  });
  it.each([undefined, null, [], {}])('handles absent or empty stock data (%s)', stocks => {
    render(<ShipStocks {...ui({ stocks })} />);
    expect(screen.getByText('No stock snapshot is available.')).toBeTruthy();
    expect(screen.queryByRole('table')).toBeNull();
  });
  it('keeps labels, quantities and units inert even if supplied encoded markup', () => {
    const view = render(<ShipStocks {...ui({ stocks: [{
      label: '&lt;img src=x onerror=alert(1)&gt;', amount: '<script>1</script>', unit: '<b>units</b>',
    }] })} />);
    expect(screen.getByText('<img src=x onerror=alert(1)>')).toBeTruthy();
    expect(screen.getByText('<script>1</script> <b>units</b>')).toBeTruthy();
    expect(view.container.querySelector('img,script,b')).toBeNull();
  });
});
