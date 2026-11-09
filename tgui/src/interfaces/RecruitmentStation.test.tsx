import React from 'react';
import { afterEach, describe, expect, it, vi } from 'vitest';
import { cleanup, fireEvent, render, screen } from '@testing-library/react';

vi.mock('tgui-core/components', () => ({
  Section: ({ children, title }: any) => <section><h2>{title}</h2>{children}</section>,
  NoticeBox: ({ children }: any) => <aside>{children}</aside>,
  Button: ({ children, onClick, disabled, selected }: any) => <button disabled={disabled} data-selected={selected ? 1 : 0} onClick={onClick}>{children}</button>,
}));
import { RecruitmentStation } from './RecruitmentStation';
import type { ScreenProps } from '../types';

afterEach(cleanup);
const ui = (data: ScreenProps['data'], interactive = true): ScreenProps => ({
  template: 'recruitment_station.tmpl', data, interactive, act: vi.fn(),
});

describe('Recruitment station', () => {
  it('lets only a leader designate an unbound station', () => {
    const props = ui({ station: 1, bound: 0, can_designate: 1, designate_faction: 'Iron &amp; Oak' });
    render(<RecruitmentStation {...props} />);
    expect(screen.getByText('You lead Iron & Oak.')).toBeTruthy();
    fireEvent.click(screen.getByText('Designate for my faction'));
    expect(props.act).toHaveBeenLastCalledWith('designate', { designate: 1 });
    cleanup();
    render(<RecruitmentStation {...ui({ station: 1, bound: 0, can_designate: 0 })} />);
    expect(screen.queryByRole('button')).toBeNull();
    expect(screen.getByText("Only a faction's leader can designate it.")).toBeTruthy();
  });
  it('shows an applicant the rules and an apply action', () => {
    const props = ui({ station: 1, bound: 1, supported: 1, faction: 'Oak', summary: 'every application is reviewed', expiry_days: 7,
      applicant: { text: 'Your application will be reviewed.', action: 'apply', results: ['Speaks Russian: not met'] } });
    render(<RecruitmentStation {...props} />);
    expect(screen.getByText('Speaks Russian: not met')).toBeTruthy();
    fireEvent.click(screen.getByText('Apply'));
    expect(props.act).toHaveBeenLastCalledWith('apply', { apply: 1 });
    expect(screen.queryByText('Applications')).toBeNull();
    expect(screen.queryByText('Rules (leader only)')).toBeNull();
  });
  it('confirms or withdraws an approved offer by its opaque id', () => {
    const props = ui({ station: 1, bound: 1, supported: 1, faction: 'Oak', applicant: { text: 'Offer', action: '',
      application: { id: 'app7', status: 'approved', status_text: 'Approved', expires: '6 days', reason: '' } } });
    render(<RecruitmentStation {...props} />);
    fireEvent.click(screen.getByText('Confirm and join'));
    expect(props.act).toHaveBeenLastCalledWith('confirm', { confirm: 'app7' });
    fireEvent.click(screen.getByText('Withdraw'));
    expect(props.act).toHaveBeenLastCalledWith('withdraw', { withdraw: 'app7' });
  });
  it('lets reviewers decide and leaders change rules', () => {
    const props = ui({ station: 0, bound: 1, supported: 1, faction: 'Oak', can_review: 1, queue: [
      { id: 'app3', name: 'Ann', status: 'pending', status_text: 'Waiting', submitted: '5 minutes', expires: '7 days', intro: 'hi', results: [] },
      { id: 'app4', name: 'Ben', status: 'approved', status_text: 'Approved', submitted: '1 hour', expires: '7 days', results: [] },
    ], policy: { mode: 'manual', open: 0, language: '', nonmatch: 'review', skills: [{ key: 'farming', label: 'Farming', level: 3 }] } });
    render(<RecruitmentStation {...props} />);
    fireEvent.click(screen.getByText('Approve'));
    expect(props.act).toHaveBeenLastCalledWith('approve', { approve: 'app3' });
    fireEvent.click(screen.getByText('Revoke offer'));
    expect(props.act).toHaveBeenLastCalledWith('revoke', { revoke: 'app4' });
    fireEvent.click(screen.getByText('Accept matching applicants at once'));
    expect(props.act).toHaveBeenLastCalledWith('set_mode', { set_mode: 'auto' });
    fireEvent.click(screen.getByText('Off'));
    expect(props.act).toHaveBeenLastCalledWith('set_open', { set_open: 1 });
    expect(screen.getByText(/Farming: 3/)).toBeTruthy();
  });
  it('keeps names, introductions and reasons inert', () => {
    const view = render(<RecruitmentStation {...ui({ station: 0, bound: 1, supported: 1, faction: '&lt;b&gt;Oak&lt;/b&gt;', can_review: 1, queue: [
      { id: 'app1', name: '&lt;img src=x onerror=alert(1)&gt;', status: 'pending', status_text: 'Waiting', submitted: '1 minute', expires: '7 days', intro: '&lt;script&gt;1&lt;/script&gt;', results: [] },
    ] })} />);
    expect(screen.getByText('<img src=x onerror=alert(1)>')).toBeTruthy();
    expect(screen.getByText('<script>1</script>')).toBeTruthy();
    expect(view.container.querySelector('img,script,b')).toBeNull();
  });
  it('disables actions when the window is not interactive', () => {
    render(<RecruitmentStation {...ui({ station: 1, bound: 1, supported: 1, faction: 'Oak', applicant: { text: 't', action: 'join', results: [] } }, false)} />);
    expect((screen.getByRole('button', { name: 'Join' }) as HTMLButtonElement).disabled).toBe(true);
  });
});
