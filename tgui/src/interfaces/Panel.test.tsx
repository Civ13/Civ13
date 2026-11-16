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
  it('is inert when read-only', () => {
    const act = vi.fn();
    render(<Panel template="panel.tmpl" data={data} act={act} interactive={false} />);
    fireEvent.click(screen.getByText('Open'));
    expect(act).not.toHaveBeenCalled();
  });
});
