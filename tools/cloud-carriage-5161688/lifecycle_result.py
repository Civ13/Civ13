"""Offline result contract; invocation/ownership evidence must come from guarded runner."""
import json, math
from collections import Counter
SOURCE='5260b60f0efef2c0af70fae204b1180106ef50b3'
EXPECTED={
 'omit_moved_release':'Carriage glide fixture: real forced removal restores cargo',
 'omit_stop_retirement':'Carriage fixture: scheduled wake retires final stopped leg',
}

REQUIRED_COUNTS={
 'idle has no lease':1,
 'production handoff and reboard contracts completed':1,
 'deletion fixture owns real lease':1,
 'real qdel removes member registrations':1,
 'deletion lease fully retired':1,
 'omission control detects absent removal listener':1,
 'omission control fully cleaned':1,
 'preroll preserves original route and actors':1,
 'native captured movement interval':2,
 'exact two native legs':2,
 'previous leg retired before next step':1,
 'production step owns all four atoms':2,
 'production aligned member glide':8,
 'actual consecutive leg cadence':1,
 'stop retains unfinished native leg':1,
 'scheduled wake retires final stopped leg':1,
 'completed leg has no registry references':2,
 'stopped member restored and unowned':4,
}

def need(ok, why):
    if not ok: raise ValueError(why)

def validate_positive(result, log):
    need(result.get('probe')=='production_lease_v1' and result.get('source')==SOURCE,'wrong source/probe')
    need(result.get('complete')==1 and type(result.get('assertions')) is int and result['assertions']==sum(REQUIRED_COUNTS.values()),'incomplete native assertions')
    legs=result.get('legs');need(type(legs) is list and len(legs)==2,'missing consecutive legs')
    need(all(type(t) in (int,float) and math.isfinite(t) and t>=0 for t in legs) and legs[1]-legs[0]==21,'wrong native cadence')
    rows=[]
    for line in log.splitlines():
        try: row=json.loads(line)
        except (ValueError,TypeError): continue
        if type(row) is dict and row.get('probe')=='production_lease_v1' and 'check' in row:rows.append(row)
    need(len(rows)==result['assertions'],'assertion receipt count mismatch')
    need(all(row.get('pass')==1 and type(row.get('tick')) in (int,float) and math.isfinite(row['tick']) for row in rows),'invalid assertion witness')
    need(Counter(row['check'] for row in rows)==REQUIRED_COUNTS,'missing, duplicated or unexpected lifecycle coverage')
    return {'status':'NATIVE_LIFECYCLE_ASSERTIONS_PASSED_PIXELS_PENDING','assertions':len(rows),'accepted_for_marketing':False}

def classify_control(variant, *, compiler_ok, native_runtime_errors, timed_out, cleanup_confirmed, stop_reason, positive_completed):
    need(variant in EXPECTED,'unknown mutation')
    # An infrastructure failure is NEVER a successful omission control.
    need(compiler_ok is True and native_runtime_errors==0 and timed_out is False and cleanup_confirmed is True,'control infrastructure failed')
    need(positive_completed is False,'mutant unexpectedly completed')
    label=EXPECTED[variant]
    phase='preparation failed: ' if variant=='omit_moved_release' else 'take failed: '
    need(stop_reason==phase+label,'wrong or absent control assertion')
    return {'status':'EXPECTED_OMISSION_ASSERTION_OBSERVED','variant':variant,'expected_assertion':label}
