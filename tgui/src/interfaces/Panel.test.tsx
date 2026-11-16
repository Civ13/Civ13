import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, screen } from '@testing-library/react';
import { render } from '../testing';
import { Panel } from './Panel';
afterEach(cleanup);
const data = { notes: ['Tom &amp; Ada keep this one.'], sections: [
  { title: 'Lock', rows: [{ label: 'Dial', value: 35, buttons: [{ label: '+', action: 'increment' }] }, { label: 'Door', value: 'Shut', tone: 'warn' }, { label: 'Odd', value: 'x', tone: 'nonsense' }], buttons: [{ label: 'Open', action: 'open' }, { label: 'No action' }] },
  { title: 'Contents', items: [{ name: 'Ledger', detail: 'Accounts', buttons: [{ label: 'Take', action: 'retrieve', id: '[0x2000001]' }, { label: 'Burn', action: 'burn', disabled: 1 }] }] },
  { title: 'Shelf', empty: 'Nothing here.' },
] };
describe('Panel', () => {
  it('shows notes, rows, items and empty sections from the snapshot', () => {
    const view = render(<Panel template="panel.tmpl" data={data} act={vi.fn()} interactive />);
    expect(view.container.textContent).toContain('Tom & Ada keep this one.');
    expect(screen.getByText('Shut').className).toContain('kit-pill-warn');
    expect(screen.getByText('x').className ?? '').not.toContain('kit-pill');
    expect(screen.getByRole('table', { name: 'Contents' }).textContent).toContain('LedgerAccounts');
    expect(screen.getByText('Nothing here.')).toBeTruthy();
    expect(screen.queryByText('No action')).toBeNull();
  });
  it('sends each button as its action with the id as the value', () => {
    const act = vi.fn();
    render(<Panel template="panel.tmpl" data={data} act={act} interactive />);
    fireEvent.click(screen.getByText('+')); fireEvent.click(screen.getByText('Open')); fireEvent.click(screen.getByText('Take')); fireEvent.click(screen.getByText('Burn'));
    expect(act.mock.calls).toEqual([['increment', { value: 1 }], ['open', { value: 1 }], ['retrieve', { value: '[0x2000001]' }]]);
  });
  it('shows a table with toned cells and a chart with one line per series', () => {
    const view = render(<Panel template="panel.tmpl" act={vi.fn()} interactive data={{ sections: [
      { title: 'Machines', empty: 'None.', table: { columns: ['Machine', 'State', 'Rate'], rows: [['Arm &amp; belt', { text: 'running', tone: 'good' }, 12], ['Press', { text: 'odd', tone: 'nonsense' }, 0]] } },
      { title: 'Last minute', chart: { slots: 60, top: '100 kW', left: 'one minute ago', right: 'now', series: [{ label: 'supply', tone: 'good', points: [100, 100, 100] }, { label: 'demand', tone: 'progress', points: [10, 20] }, { label: 'idle', points: [] }] } },
    ] }} />);
    const table = screen.getByRole('table', { name: 'Machines' });
    expect(table.textContent).toContain('MachineStateRateArm & beltrunning12Pressodd0');
    expect(screen.getByText('running').className).toContain('kit-pill-good');
    expect(screen.getByText('odd').className ?? '').not.toContain('kit-pill');
    expect(screen.queryByText('None.')).toBeNull();
    const lines = view.container.querySelectorAll('polyline');
    expect(lines.length).toBe(2);
    // The newest sample sits on the right edge and the highest value at the top of the plot.
    expect(lines[0].getAttribute('points')?.split(' ').pop()).toBe('360.0,20.0');
    expect(lines[1].getAttribute('class')).toContain('kit-chart-progress');
    expect(screen.getByRole('img', { name: 'supply and demand and idle' })).toBeTruthy();
    expect(view.container.textContent).toContain('one minute ago');
  });
  it('shows an item picture only for a bare file name', () => {
    const view = render(<Panel template="panel.tmpl" act={vi.fn()} interactive data={{ sections: [{ title: 'Styles', items: [
      { name: 'Style 1', image: 'pill1.png' }, { name: 'Remote', image: 'https://example.invalid/x.png' }, { name: 'Path', image: '../x.png' }] }] }} />);
    const images = view.container.querySelectorAll('img');
    expect(images.length).toBe(1);
    expect(images[0].getAttribute('src')).toBe('pill1.png');
  });
  it('sends a form as its action with the value and each typed field', () => {
    const act = vi.fn();
    const view = render(<Panel template="panel.tmpl" act={act} interactive data={{ sections: [{ title: 'Offers', empty: 'None.', forms: [
      { label: 'Dawn Mill', action: 'sell', id: 3, button: 'Sell', fields: [{ name: 'amt', label: 'Amount', kind: 'number', value: 40 }, { name: 'price', label: 'Price', kind: 'number', value: 10 },
        { name: 'cur', label: 'Currency', kind: 'choice', options: [{ id: 'standard', label: 'Standard Coins' }, { id: 'fiat_2', label: 'Marks' }] }, { name: 'Bad Name', label: 'Dropped', value: 1 }] }] }] }} />);
    expect(screen.queryByText('None.')).toBeNull();
    expect(view.container.querySelectorAll('input').length).toBe(2);
    fireEvent.change(screen.getByLabelText('Amount'), { target: { value: '25' } });
    fireEvent.change(screen.getByLabelText('Currency'), { target: { value: 'fiat_2' } });
    fireEvent.click(screen.getByText('Sell'));
    expect(act).toHaveBeenLastCalledWith('sell', { value: 3, amt: 25, price: 10, cur: 'fiat_2' });
    fireEvent.change(screen.getByLabelText('Price'), { target: { value: 'lots' } });
    fireEvent.click(screen.getByText('Sell'));
    expect(act).toHaveBeenCalledTimes(1);
  });
  it('is inert when read-only', () => {
    const act = vi.fn();
    render(<Panel template="panel.tmpl" data={data} act={act} interactive={false} />);
    fireEvent.click(screen.getByText('Open'));
    expect(act).not.toHaveBeenCalled();
  });
});
