import { NoticeBox, Section } from 'tgui-core/components';
import type { ScreenProps } from '../types';
import { Action, list, str } from './common';
import { Card, CheckList, Choice, Pill, Row, Rows } from './kit';

// Server text is entity encoded; str() decodes it for display only. Actions
// carry opaque application ids or fixed values, never names or free text.
const MODES: [string, string][] = [['closed', 'Closed'], ['manual', 'Review every application'], ['auto', 'Accept matching applicants at once']];

// The server ends each rule line with "met" or "not met"; anything else stays a plain line.
function Results({ results }: { results: unknown }) {
  return <CheckList rows={list(results).map(line => { const label = str(line); return { ok: /: not met$/.test(label) ? false : /: met$/.test(label) ? true : null, label }; })} />;
}

export function RecruitmentStation(ui: ScreenProps) {
  const { data } = ui;
  const faction = str(data.faction);
  if (data.station && !data.bound) {
    return <Section title="Recruitment Station">
      <p>This station has not been designated for a faction.</p>
      {data.can_designate
        ? <><p>You lead {str(data.designate_faction)}.</p><Action ui={ui} action="designate">Designate for my faction</Action></>
        : <NoticeBox>Only a faction's leader can designate it.</NoticeBox>}
    </Section>;
  }
  const applicant = data.applicant;
  const application = applicant?.application;
  const outcome = applicant?.outcome;
  const queue = list(data.queue);
  const policy = data.policy;
  return <>
    <Section title={faction ? `${faction} recruitment` : 'Recruitment'} buttons={data.can_unbind ? <Action ui={ui} action="unbind">Release this station</Action> : null}>
      {data.motto && <p className="kit-motto">{str(data.motto)}</p>}
      {!data.supported && <NoticeBox>This faction is not recruiting here.</NoticeBox>}
      <p>{str(data.summary)}</p>
      <p className="kit-hint">Applications and approved offers expire after {str(data.expiry_days)} days.</p>
    </Section>
    {applicant && <Section title="Join">
      <p>{str(applicant.text)}</p>
      {!application && outcome && <>
        <p>Last decision: <Pill tone="info">{str(outcome.status_text)}</Pill></p>
        {outcome.reason && <p>Reason: {str(outcome.reason)}</p>}
      </>}
      <Results results={applicant.results} />
      {applicant.action === 'join' && <Action ui={ui} action="apply">Join</Action>}
      {applicant.action === 'apply' && <Action ui={ui} action="apply">Apply</Action>}
      {application && <>
        <p><Pill tone={application.status === 'approved' ? 'good' : 'info'}>{str(application.status_text)}</Pill> <span className="kit-hint">Expires in {str(application.expires)}.</span></p>
        {application.reason && <p>Reason: {str(application.reason)}</p>}
        {application.status === 'approved' && <Action ui={ui} action="confirm" value={String(application.id)}>Confirm and join</Action>}
        <Action ui={ui} action="withdraw" value={String(application.id)}>Withdraw</Action>
      </>}
    </Section>}
    {data.can_review ? <Section title="Applications">
      {queue.length ? queue.map((entry, i) => <Card key={i}>
        <div className="kit-card-head">
          <div><strong>{str(entry.name)}</strong> <Pill tone={entry.status === 'approved' ? 'good' : 'info'}>{str(entry.status_text)}</Pill>
            {entry.exception ? <> <Pill tone="warn">Exception to the rules</Pill></> : null}
            <div className="kit-hint">Applied {str(entry.submitted)} ago, expires in {str(entry.expires)}.</div></div>
          <div className="kit-card-actions">
            {entry.status === 'pending' && <><Action ui={ui} action="approve" value={String(entry.id)}>Approve</Action>
              <Action ui={ui} action="reject" value={String(entry.id)}>Reject</Action></>}
            {entry.status === 'approved' && <Action ui={ui} action="revoke" value={String(entry.id)}>Revoke offer</Action>}
          </div>
        </div>
        {entry.intro && <p className="kit-quote">{str(entry.intro)}</p>}
        {list(entry.results).length ? <><p className="kit-hint">Rules when submitted:</p><Results results={entry.results} /></> : null}
      </Card>) : <NoticeBox>No open applications.</NoticeBox>}
    </Section> : null}
    {policy && <Section title="Rules (leader only)">
      <Rows>
        <Row label="Mode"><Choice ui={ui} action="set_mode" value={policy.mode} options={MODES} label="Mode" /></Row>
        <Row label="Open recruitment (anyone eligible)"><Choice ui={ui} action="set_open" value={policy.open ? 1 : 0} options={[[1, 'On'], [0, 'Off']]} label="Open recruitment" /></Row>
        <Row label="Known language" buttons={<Action ui={ui} action="set_language">Change...</Action>}>{str(policy.language) || 'none'}</Row>
        {list(policy.skills).map((skill, i) => <Row key={i} label={<>Minimum {str(skill.label)} <span className="kit-hint">(0-10)</span></>}
          buttons={<Action ui={ui} action="set_skill" value={String(skill.key)}>Change...</Action>}>{skill.level ? `Level ${str(skill.level)} or higher` : <span className="kit-hint">No rule</span>}</Row>)}
        <Row label="Applicants who don't meet the rules"><Choice ui={ui} action="set_nonmatch" value={policy.nonmatch} options={[['review', 'Send for review'], ['refuse', 'Cannot apply']]} label="Applicants who don't meet the rules" /></Row>
      </Rows>
      {list(data.audit).length ? <details className="kit-details"><summary>Recent changes ({list(data.audit).length})</summary><ul>{list(data.audit).map((line, i) => <li key={i}>{str(line)}</li>)}</ul></details> : null}
    </Section>}
  </>;
}
