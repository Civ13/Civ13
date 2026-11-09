import { NoticeBox, Section } from 'tgui-core/components';
import type { ScreenProps } from '../types';
import { Action, list, text } from './common';

// Server text is entity encoded; text() decodes it for display only. Actions
// carry opaque application ids or fixed values, never names or free text.
const MODES: [string, string][] = [['closed', 'Closed'], ['manual', 'Review every application'], ['auto', 'Accept matching applicants at once']];

function Results({ results }: { results: unknown }) {
  const lines = list(results);
  return lines.length ? <ul>{lines.map((line, i) => <li key={i}>{text(line)}</li>)}</ul> : null;
}

export function RecruitmentStation(ui: ScreenProps) {
  const { data } = ui;
  const faction = text(data.faction);
  if (data.station && !data.bound) {
    return <Section title="Recruitment Station">
      <p>This station has not been designated for a faction.</p>
      {data.can_designate
        ? <><p>You lead {text(data.designate_faction)}.</p><Action ui={ui} action="designate">Designate for my faction</Action></>
        : <NoticeBox>Only a faction's leader can designate it.</NoticeBox>}
    </Section>;
  }
  const applicant = data.applicant;
  const application = applicant?.application;
  const queue = list(data.queue);
  const policy = data.policy;
  return <>
    <Section title={faction ? `${faction} recruitment` : 'Recruitment'}>
      {data.motto && <p><em>{text(data.motto)}</em></p>}
      {!data.supported && <NoticeBox>This faction is not recruiting here.</NoticeBox>}
      <p>{text(data.summary)}</p>
      <p>Applications and approved offers expire after {text(data.expiry_days)} days.</p>
      {data.can_unbind ? <Action ui={ui} action="unbind">Release this station</Action> : null}
    </Section>
    {applicant && <Section title="Join">
      <p>{text(applicant.text)}</p>
      <Results results={applicant.results} />
      {applicant.action === 'join' && <Action ui={ui} action="apply">Join</Action>}
      {applicant.action === 'apply' && <Action ui={ui} action="apply">Apply</Action>}
      {application && <>
        <p>Status: {text(application.status_text)}. Expires in {text(application.expires)}.</p>
        {application.reason && <p>Reason: {text(application.reason)}</p>}
        {application.status === 'approved' && <Action ui={ui} action="confirm" value={String(application.id)}>Confirm and join</Action>}
        <Action ui={ui} action="withdraw" value={String(application.id)}>Withdraw</Action>
      </>}
    </Section>}
    {data.can_review ? <Section title="Applications">
      {queue.length ? queue.map((entry, i) => <div key={i} className="item">
        <p><strong>{text(entry.name)}</strong>: {text(entry.status_text)}. Applied {text(entry.submitted)} ago, expires in {text(entry.expires)}.
          {entry.exception ? ' Approved as an exception to the rules.' : ''}</p>
        {entry.intro && <p><em>{text(entry.intro)}</em></p>}
        <p>Rules when submitted:</p>
        <Results results={entry.results} />
        {entry.status === 'pending' && <><Action ui={ui} action="approve" value={String(entry.id)}>Approve</Action>
          <Action ui={ui} action="reject" value={String(entry.id)}>Reject</Action></>}
        {entry.status === 'approved' && <Action ui={ui} action="revoke" value={String(entry.id)}>Revoke offer</Action>}
      </div>) : <NoticeBox>No open applications.</NoticeBox>}
    </Section> : null}
    {policy && <Section title="Rules (leader only)">
      <p>Mode: {MODES.map(([mode, label]) => <Action key={mode} ui={ui} action="set_mode" value={mode} selected={policy.mode === mode}>{label}</Action>)}</p>
      <p>Open recruitment (anyone eligible): <Action ui={ui} action="set_open" value={policy.open ? 0 : 1} selected={!!policy.open}>{policy.open ? 'On' : 'Off'}</Action></p>
      <p>Known language: {text(policy.language) || 'none'} <Action ui={ui} action="set_language">Change...</Action></p>
      <p>Minimum skill levels (0-10, from Skill Progress):</p>
      <ul>{list(policy.skills).map((skill, i) => <li key={i}>{text(skill.label)}: {skill.level ? text(skill.level) : 'no rule'} <Action ui={ui} action="set_skill" value={String(skill.key)}>Change...</Action></li>)}</ul>
      <p>Applicants who don't meet the rules: <Action ui={ui} action="set_nonmatch" value="review" selected={policy.nonmatch === 'review'}>Send for review</Action>
        <Action ui={ui} action="set_nonmatch" value="refuse" selected={policy.nonmatch === 'refuse'}>Cannot apply</Action></p>
      {list(data.audit).length ? <><p>Recent changes:</p><ul>{list(data.audit).map((line, i) => <li key={i}>{text(line)}</li>)}</ul></> : null}
    </Section>}
  </>;
}
