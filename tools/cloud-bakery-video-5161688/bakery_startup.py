"""Bounded existing startup witnesses; metadata success alone is not readiness."""
import hashlib
import math
from pathlib import Path
import re
from materialize import _plain_ancestors

PHASES = ('minimal client before native New', 'minimal observer Login',
          'minimal client after native New', 'minimal guest engine 516.1688')


def read_existing(source, name):
    path = Path(source)/name
    _plain_ancestors(path.parent)
    if not path.exists(): return None, {'status':'missing'}
    if path.is_symlink() or not path.is_file() or path.stat().st_size >= 65536:
        raise ValueError('Unusable startup witness')
    raw = path.read_bytes()
    if len(raw) >= 65536: raise ValueError('Startup witness grew beyond cap')
    return raw.decode('utf-8'), {'status':'retained_source','bytes':len(raw),
                               'sha256':hashlib.sha256(raw).hexdigest()}


def observe(source, debug, alive):
    result = {'schema':1,'profile':'minimal-world-control','ready_checkpoints_observed':False,
              'alive_at_observation_end':alive is True,'startup_verified':False,
              'status':'PENDING_CLEANUP_REVIEW','witnesses':{},'errors':[]}
    try:
        checks, result['witnesses']['intro-checks.txt'] = read_existing(source,'intro-checks.txt')
        client, result['witnesses']['cloud-client.txt'] = read_existing(source,'cloud-client.txt')
        labels = [m[1] for line in (checks or '').splitlines()
                  if (m:=re.fullmatch(r'[0-9]+(?:\.[0-9]+)? (.+)',line))]
        positions = [labels.index(p) for p in PHASES if labels.count(p)==1]
        result['ready_checkpoints_observed'] = (len(positions)==len(PHASES) and
            positions==sorted(positions) and client in
            ('guest=1;version=516;build=1688','guest=1;version=516;build=1688\n',
             'guest=1;version=516;build=1688\r\n'))
        elapsed = debug.get('observation_seconds')
        result['survived_observation'] = (type(elapsed) in (int,float) and math.isfinite(elapsed) and
            elapsed>=5 and debug.get('outcome')=='five_second_limit' and
            debug.get('exit_seen') is False and debug.get('errors')==[] and alive is True)
    except (OSError,ValueError,UnicodeError):
        result['errors'].append('startup_witness_unavailable_or_malformed')
        result['survived_observation'] = False
    return result


def finalize(observation, debug, cleanup):
    result = dict(observation or {'schema':1,'profile':'minimal-world-control',
                                 'status':'NOT_OBSERVED','startup_verified':False})
    roles = {row.get('role'):row for row in cleanup}
    clean = (set(roles)=={'compiler','server','client'} and len(cleanup)==3 and
             all(row.get('all_exited') is True for row in cleanup))
    client_exits = roles.get('client',{}).get('exits',[])
    intentional_exit = (len(client_exits)==1 and client_exits[0].get('exit_code')==1 and
                        client_exits[0].get('debug_events_drained') is True and
                        debug.get('exit_during_cleanup') is True and debug.get('errors')==[])
    result['owned_cleanup_verified'] = clean
    result['intentional_observer_stop_verified'] = intentional_exit
    result['startup_verified'] = False  # This remains a staged diagnostic, not acceptance.
    result['native_acceptance'] = False
    if debug.get('outcome')=='unhandled_exception':
        result['status'] = 'CLIENT_CRASH_REPRODUCED'
    elif (result.get('ready_checkpoints_observed') is True and
          type(result.get('sampled_at_seconds')) in (int,float) and
          0<=result['sampled_at_seconds']<5 and
          result.get('survived_observation') is True and clean and intentional_exit):
        result['status'] = 'STARTUP_OBSERVED_REVIEW_REQUIRED'
    else:
        result['status'] = 'INCONCLUSIVE_STARTUP_CONTROL'
    return result


def sample_within_observation(source, started, now):
    result = observe(source,{},False)
    result['sampled_at_seconds'] = now()-started
    if not 0<=result['sampled_at_seconds']<5:
        result['ready_checkpoints_observed'] = False
    return result


def end_observation(sample, debug, alive):
    result = dict(sample or {'schema':1,'profile':'minimal-world-control','errors':['no_in_window_sample']})
    elapsed = debug.get('observation_seconds')
    result['alive_at_observation_end'] = alive is True
    result['survived_observation'] = (type(elapsed) in (int,float) and math.isfinite(elapsed) and
        elapsed>=5 and debug.get('outcome')=='five_second_limit' and
        debug.get('exit_seen') is False and debug.get('errors')==[] and alive is True)
    return result
