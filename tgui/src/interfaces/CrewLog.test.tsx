import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, render, screen, within } from '@testing-library/react';

vi.mock('tgui-core/components', () => ({
  Section: ({ children, title }: any) => <section><h2>{title}</h2>{children}</section>,
  NoticeBox: ({ children }: any) => <aside>{children}</aside>,
}));
import { CrewLog } from './CrewLog';
import type { ScreenProps } from '../types';

afterEach(cleanup);
const ui = (crew?: any): ScreenProps => ({ template: 'crew_log.tmpl', data: { crew }, interactive: true, act: vi.fn() });
describe('Crew Log snapshot', () => {
  it('preserves roster order, duplicate display names and every supplied job without actions', () => {
    const props = ui([{ name: 'Masked sailor', job: 'Sailor' }, { name: 'Captain', job: 'Captain' },
      { name: 'Masked sailor', job: 'Doctor' }, { name: 'NPC carpenter', job: 'Carpenter' }, { name: 'Unassigned', job: '' }]);
    render(<CrewLog {...props} />);
    const rows = within(screen.getByRole('table', { name: 'Crew log' })).getAllByRole('row');
    expect(rows).toHaveLength(6);
    props.data.crew.forEach((member: any, i: number) => {
      expect(within(rows[i + 1]).getByRole('rowheader').textContent).toBe(member.name);
      expect(within(rows[i + 1]).getByRole('cell').textContent).toBe(member.job);
    });
    expect(screen.queryByRole('button')).toBeNull();
    expect(screen.queryByRole('link')).toBeNull();
    expect(props.act).not.toHaveBeenCalled();
  });
  it('replaces old rows on refresh', () => {
    const view = render(<CrewLog {...ui([{ name: 'Old sailor', job: 'Sailor' }])} />);
    view.rerender(<CrewLog {...ui([{ name: 'New captain', job: 'Captain' }])} />);
    expect(screen.getByText('New captain')).toBeTruthy();
    expect(screen.queryByText('Old sailor')).toBeNull();
  });
  it.each([undefined, null, [], {}])('handles empty or absent data (%s)', crew => {
    render(<CrewLog {...ui(crew)} />);
    expect(screen.getByText('No crew are listed.')).toBeTruthy();
    expect(screen.queryByRole('table')).toBeNull();
  });
  it('renders escaped names/jobs as inert text', () => {
    const view = render(<CrewLog {...ui([{ name: '&lt;img src=x onerror=alert(1)&gt;', job: '&lt;script&gt;fictional&lt;/script&gt;' }])} />);
    expect(screen.getByText('<img src=x onerror=alert(1)>')).toBeTruthy();
    expect(screen.getByText('<script>fictional</script>')).toBeTruthy();
    expect(view.container.querySelector('img,script')).toBeNull();
  });
});
