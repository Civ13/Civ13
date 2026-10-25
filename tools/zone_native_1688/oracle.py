"""Pure offline result/log oracles. No native calls."""
import re
from prepare import HEAD
NEGATIVE={'duplicate-spawn':'Duplicate or stale spawn zone','stale-zone':'Duplicate or stale spawn zone','wrong-z':'Spawn outside saved world','fractional':'Spawn outside saved world','duplicate-zone':'Invalid or duplicate zone identity','absent-zone':'Captured zone membership differs','incomplete':None,'overlong':'Captured zone membership differs'}
MODES=('write','read','write-sequence','read-sequence','legacy-write','legacy-read',*NEGATIVE)
FATAL=re.compile(r'\b(?:FAIL:|BUG:|RUNTIME:|warning:|error:)|runtime error|Runtime in|unexpected runtime|bad ref|bad loc|segmentation|fatal error|out of memory|access violation|infinite loop|##\s*ERROR|cleanup failed|restoration failed|import failed|export failed',re.I)

def integer(value):return type(value) is int

def expected_reason(mode,prediction):
 if prediction.get('mode')!=mode:raise ValueError('Wrong negative prediction mode')
 value=prediction.get('expected')
 if mode=='incomplete':
  if value not in ('Missing captured membership','Captured zone membership differs'):raise ValueError('Invalid savefile-null prediction')
 elif value!=NEGATIVE[mode]:raise ValueError('Wrong negative prediction')
 return value

def verify_result(mode,result,runtime,prediction=None):
 if result.get('head')!=HEAD or result.get('version')!='516.1688' or result.get('mode')!=mode:raise ValueError('Unbound native result')
 if not integer(result.get('failed')) or result['failed']!=0 or not integer(result.get('checks')) or result['checks']<4:raise ValueError('Failed or incomplete native result')
 counts={'write':(1,0,0),'read':(0,2,2),'write-sequence':(3,0,0),'read-sequence':(0,6,6),'legacy-write':(1,0,0),'legacy-read':(0,1,1)}
 expected=counts.get(mode,(0,1,0));actual=tuple(result.get(k) for k in ('save_calls','load_calls','load_successes'))
 if any(not integer(x) for x in actual) or actual!=expected:raise ValueError('Native save/load phase coverage differs')
 if FATAL.search(runtime):raise ValueError('Native runtime diagnostic')
 opened=re.findall(r'World opened on network port (\d+) for address ([^\s]+)\.',runtime)
 if len(opened)>1 or any(host!='127.0.0.1' for port,host in opened):raise ValueError('Unexpected listener bind')
 if opened:
  closed=runtime.find('World no longer opened to new users.')
  if closed<runtime.find('World opened on network port'):raise ValueError('Missing immediate closure')
 if mode in NEGATIVE:
  reason=expected_reason(mode,prediction or {})
  rejection=result.get('rejection')
  if result.get('expected')!=reason or not isinstance(rejection,str) or not re.fullmatch(re.escape(reason)+r' on [^\r\n]+\.dm:\d+',rejection):raise ValueError('Unexpected rejection location/reason')
  begin='ZONE_PHASE '+mode+' begin';end='ZONE_PHASE '+mode+' end'
  if runtime.count(begin)!=1 or runtime.count(end)!=1 or runtime.index(begin)>=runtime.index(end):raise ValueError('Negative phase markers differ')
  before,rest=runtime.split(begin);inside,after=rest.split(end)
  rejected='World-save preflight rejected: '+rejection
  if inside.count(rejected)!=1 or 'preflight rejected:' in before+after:raise ValueError('Rejection outside expected phase')
  if runtime.count('World-save preflight rejected:')!=1:raise ValueError('Extra rejection')
 else:
  if result.get('rejection') is not None or result.get('expected') is not None or 'ZONE_PHASE ' in runtime or 'preflight rejected:' in runtime:raise ValueError('Unexpected positive rejection')
 return True

def verify_aux_logs(logs,mode,result):
 for name,text in logs.items():
  if FATAL.search(text):raise ValueError('Diagnostic in '+name)
  phase_bounds=None
  if 'ZONE_PHASE ' in text:
   if mode not in NEGATIVE:raise ValueError('Unexpected auxiliary phase')
   begin='ZONE_PHASE '+mode+' begin';end='ZONE_PHASE '+mode+' end'
   if text.count(begin)!=1 or text.count(end)!=1 or text.count('ZONE_PHASE ')!=2 or text.index(begin)>=text.index(end):raise ValueError('Auxiliary phase markers differ')
   phase_bounds=(text.index(begin)+len(begin),text.index(end))
   for marker in ('World-save preflight rejected:','Save rejected before clearing the world:'):
    for match in re.finditer(re.escape(marker),text):
     if not phase_bounds[0]<=match.start()<phase_bounds[1]:raise ValueError('Auxiliary rejection outside phase')
  # No blanket ignore of the stub errors list or all preflight messages.
  if 'World-save preflight rejected:' in text:
   if mode not in NEGATIVE:raise ValueError('Unexpected rejection in '+name)
   if name in ('daemon.log','runtime.log'):verify_result(mode,result,text,{'mode':mode,'expected':result['expected']})
   if text.count('World-save preflight rejected:')!=1:raise ValueError('Repeated auxiliary preflight rejection')
   reason=result['rejection']
   for line in text.splitlines():
    if 'World-save preflight rejected:' in line and not line.endswith('World-save preflight rejected: '+reason):raise ValueError('Mismatched rejection in '+name)
  if 'Save rejected before clearing the world:' in text:
   if mode not in NEGATIVE:raise ValueError('Unexpected admin rejection')
   if text.count('Save rejected before clearing the world:')!=1:raise ValueError('Repeated admin rejection')
   for line in text.splitlines():
    if 'Save rejected before clearing the world:' in line:
     suffix=line.split('Save rejected before clearing the world:',1)[1]
     if suffix not in (' '+result['expected'],' '+result['expected']+'</span></span>'):raise ValueError('Mismatched admin rejection')
