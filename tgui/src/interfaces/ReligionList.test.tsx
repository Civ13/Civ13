import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, render, screen, within } from '@testing-library/react';

vi.mock('tgui-core/components', () => ({
  Section: ({ children, title }: any) => <section><h2>{title}</h2>{children}</section>,
  NoticeBox: ({ children }: any) => <aside>{children}</aside>,
}));
import { ReligionList } from './ReligionList';
import type { ScreenProps } from '../types';

afterEach(cleanup);
const ui = (religions?: any): ScreenProps => ({
  template: 'religion_list.tmpl', data: { religions }, interactive: true, act: vi.fn(),
});
describe('Religion List snapshot', () => {
  it('retains source order, zero, negative and fractional points without exposing actions', () => {
    const props = ui([{ name: 'First', points: 0 }, { name: 'Second', points: -2 }, { name: 'Third', points: 12.5 }]);
    render(<ReligionList {...props} />);
    const rows = within(screen.getByRole('table', { name: 'Religion list' })).getAllByRole('row');
    expect(rows).toHaveLength(4);
    ['First', 'Second', 'Third'].forEach((name, i) => expect(within(rows[i + 1]).getByRole('rowheader').textContent).toBe(name));
    [0, -2, 12.5].forEach((points, i) => expect(within(rows[i + 1]).getByRole('cell').textContent).toBe(String(points)));
    expect(screen.queryByRole('button')).toBeNull();
    expect(screen.queryByRole('link')).toBeNull();
    expect(props.act).not.toHaveBeenCalled();
  });
  it('replaces old names and point totals with the newly opened snapshot', () => {
    const props = ui([{ name: 'Old name', points: 5 }]);
    const view = render(<ReligionList {...props} />);
    view.rerender(<ReligionList {...ui([{ name: 'Current name', points: 9 }])} />);
    expect(screen.getByText('Current name')).toBeTruthy();
    expect(screen.getByText('9')).toBeTruthy();
    expect(screen.queryByText('Old name')).toBeNull();
    expect(screen.queryByText('5')).toBeNull();
  });
  it.each([undefined, null, [], {}])('shows a useful empty state (%s)', religions => {
    render(<ReligionList {...ui(religions)} />);
    expect(screen.getByText('No religions have been founded.')).toBeTruthy();
    expect(screen.queryByRole('table')).toBeNull();
  });
  it('decodes server-escaped names only as text and keeps malformed point text inert', () => {
    const view = render(<ReligionList {...ui([{ name: '&lt;img src=x onerror=alert(1)&gt;', points: '<script>1</script>' }])} />);
    expect(screen.getByText('<img src=x onerror=alert(1)>')).toBeTruthy();
    expect(screen.getByText('<script>1</script>')).toBeTruthy();
    expect(view.container.querySelector('img,script')).toBeNull();
  });
});
