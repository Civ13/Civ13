"""Bounded native protocol. Imports/tests never launch BYOND or clients."""
from datetime import datetime, timezone
from pathlib import Path
import hashlib
import json
import math

LIMITS = dict(map=[64,64,1], view='15x15', events=800, recorded=640,
              roots=512, light_roots=64, run_seconds=180, compile_seconds=120,
              cleanup_seconds=30, rss_bytes=1920*1024**2, watcher_bytes=128*1024**2,
              evidence_bytes=16*1024**2, processes=3, repetitions=3)
CLASSES = ('audit','viewer_move','opaque_move','queued_light')
CASES = tuple(dict(id=i+1, viewers=v, roots=n, mode=m)
              for i,(v,n,m) in enumerate((v,n,m) for v in (1,2)
                                         for n in (64,256) for m in ('root','fallback')))

def require(ok, why):
    if not ok: raise ValueError(why)

def digest(raw): return hashlib.sha256(raw).hexdigest()

def same_tick_ms(row):
    """Use source TICK_DELTA_TO_MS, never turn a yield/negative delta into zero."""
    keys=('start_tick','end_tick','start_usage','end_usage','tick_lag')
    require(all(type(row.get(k)) in (int,float) and math.isfinite(row[k]) for k in keys),
            'Missing/nonfinite native timer endpoint')
    if row['start_tick'] != row['end_tick'] or row['end_usage'] < row['start_usage']:
        return None
    require(row['tick_lag'] > 0, 'Invalid tick_lag')
    return (row['end_usage']-row['start_usage'])*row['tick_lag']

def admit(head, manifest, reviewed, deadline, environment, now=None):
    require(len(head)==40 and all(x in '0123456789abcdef' for x in head),'Full source SHA')
    require(reviewed==digest(manifest),'Independent review must name exact prepared manifest hash')
    end=datetime.fromisoformat(deadline.replace('Z','+00:00'))
    require(end.tzinfo is not None,'Explicit authorization timezone')
    cap=datetime.fromisoformat(json.loads(Path(__file__).with_name('request.json').read_text(encoding='utf-8-sig'))['authorized_until_utc'].replace('Z','+00:00'))
    require(end <= cap,'Requested deadline exceeds current user authorization window')
    now=now or datetime.now(timezone.utc)
    require(now.timestamp()+LIMITS['compile_seconds']+LIMITS['run_seconds']+2*LIMITS['cleanup_seconds']+30 < end.timestamp(),
            'Insufficient remaining authorized window including cleanup')
    require(environment.get('RUNNER_ENVIRONMENT')=='github-hosted' and environment.get('RUNNER_OS')=='Windows'
            and environment.get('GITHUB_REPOSITORY')=='Civ13/Civ13'
            and environment.get('GITHUB_EVENT_NAME')=='workflow_dispatch'
            and environment.get('GITHUB_RUN_ATTEMPT')=='1'
            and environment.get('GITHUB_SHA')==head and environment.get('GITHUB_WORKFLOW_SHA')==head,
            'Execution only on exact-head fresh hosted Windows manual attempt1; no desktop/live fallback')
    return end.timestamp()

def validate(receipt, rows, head, binding):
    require(receipt.get('head')==head and receipt.get('binding')==binding,'Native receipt source binding')
    require(receipt.get('engine')==[516,1688] and receipt.get('error') is None,'Engine/build/native failure')
    require(type(receipt.get('cleanup')) is int and receipt['cleanup']==1 and receipt.get('events')==800,'Native completion/cleanup')
    require(type(receipt.get('pixels_verified')) is int and receipt['pixels_verified']==0,'Server state cannot certify client pixels')
    require(len(rows)==800,'Missing/extra raw native events')
    unresolved=[]; result=[]
    for case in CASES:
        group=[r for r in rows if r.get('case')==case['id']]
        require(len(group)==100,'Case event count')
        for kind in CLASSES:
            selected=[r for r in group if r.get('class')==kind]
            require([r.get('iteration') for r in selected]==list(range(1,26)),'Warm/recorded sequence')
            for r in selected:
                require(r.get('viewers')==case['viewers'] and r.get('roots')==case['roots'] and r.get('mode')==case['mode'],'Case identity')
                require(type(r.get('scene_valid')) is int and r['scene_valid']==1 and type(r.get('safe')) is int and r['safe']==1,'Admission/visibility/ownership witness')
                if kind=='opaque_move' and case['viewers']==2:
                    require(r.get('other_sync_captures')==0,'Unrelated dirty viewer synchronously refreshed')
                before=r.get('before',[]); after=r.get('after',[])
                require(len(before)==len(after)==case['viewers'],'Real connected viewer census')
                for state in before+after:
                    require(state['discovered']==case['roots'],'Actual discovered-root density')
                    front=state['identities'][0]
                    require(front['image'] and front['native_icon_present']==1 and front['in_client_images']==1,'Visible blocker lacks owned native image')
                    if case['mode']=='root': require(state['scene_active']==1 and front['published_frame'],'Root publication missing')
                    else: require(state['scene_active']==0 and state['fallback_reason']=='native foreground or mixed-layer appearance','Wrong intentional fallback')
                phases=r.get('phases',[])
                if kind=='viewer_move':
                    require(any(x.get('phase')=='entered' for x in phases),'Actual native Entered not witnessed')
                    require(any(x.get('phase')=='postmove' for x in phases),'Actual native post-move callback missing')
                    require(any(x.get('result')==2 and (x.get('sx') or x.get('sy')) for x in r.get('native_returns',[])),'No actual native fractional movement return')
                    entered=next(x for x in phases if x.get('phase')=='entered')['clients'][0]['identities'][0]
                    old=before[0]['identities'][0];new=after[0]['identities'][0]
                    if case['mode']=='root':
                        require(entered['published_frame'] is None and entered['native_icon_present']==0,'Entered did not withdraw root frame')
                        require(old['image']==new['image'],'Root image identity unexpectedly changed')
                    else:
                        require(entered['image'] is None,'Entered retained fallback allowed copy')
                        require(old['image']!=new['image'],'Fallback identity replacement not witnessed')
                    if r['iteration']==1:
                        failed=r.get('capture_failed',[])
                        require(failed and all(x['published_frame'] is None and x['native_icon_present']==0 for x in failed[0]['identities']),'Actual unavailable capture kept stale admission')
                if case['viewers']==2 and kind in ('viewer_move','opaque_move'):
                    require(before[1]['identities']==after[1]['identities'],'Unrelated viewer publication changed synchronously')
                if kind=='queued_light':
                    require(r.get('pending_committed')==before,'Pending committed light withdrew/mutated image state')
                require(bool(r.get('timings')),'No actual native span samples')
                for sample in r.get('timings',[]):
                    ms=same_tick_ms(sample)
                    if ms is None: unresolved.append([case['id'],kind,r['iteration'],sample.get('name')])
                    else: require(ms < sample['tick_lag']*100,'Whole-tick callback cost')
            samples=[same_tick_ms(r['event_timer']) for r in selected[5:]]
            for r,ms in zip(selected[5:],samples):
                if ms is None:unresolved.append([case['id'],kind,r['iteration'],'event'])
            valid=sorted(x for x in samples if x is not None)
            result.append(dict(case=case['id'],kind=kind,n=len(valid),median=valid[len(valid)//2] if valid else None,
                               p95=valid[math.ceil(.95*len(valid))-1] if valid else None,maximum=max(valid) if valid else None))
    per_client=[];over_budget=[]
    for case in CASES:
        for kind in CLASSES:
            selected=[r for r in rows if r['case']==case['id'] and r['class']==kind and r['iteration']>5]
            allowance=min(r['allowance_ms'] for r in selected)
            require(type(allowance) in (int,float) and allowance>0,'Missing actual visibility allowance')
            for client in range(1,case['viewers']+1):
                values=[same_tick_ms(t) for r in selected for t in r['timings'] if t['name']=='reconcile' and t['client']==client]
                valid=sorted(v for v in values if v is not None)
                if valid:
                    p95=valid[math.ceil(.95*len(valid))-1]
                    item=dict(case=case['id'],kind=kind,client=client,samples=len(valid),p95_ms=p95,allowance_ms=allowance)
                    per_client.append(item)
                    if p95>allowance:over_budget.append(item)
    return dict(native_dispatch_validated=True,pixels_verified=False,cost_accepted=not unresolved and not over_budget,
                per_client_reconcile=per_client,over_budget=over_budget,
                reason='Unresolved timings prevent cost acceptance' if unresolved else 'p95 exceeds recorded visibility allowance' if over_budget else 'Bounded instrumented fixture samples within recorded allowance; no production speedup claim',
                unresolved=unresolved,summaries=result)
