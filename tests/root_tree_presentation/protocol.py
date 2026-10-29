"""Fail-closed evidence gate for the existing capture owner; launches nothing.

An acknowledgment proves settled admission, never pixel correctness. The owner
must scan its actual owned runtime/stderr logs and provide normalized map pixel
bytes plus independent pixel-oracle results before finish() can succeed.
"""
import hashlib
import importlib.util
import json
from pathlib import Path
import re
import uuid
spec=importlib.util.spec_from_file_location('tree_gate_provenance',Path(__file__).with_name('provenance.py'))
provenance=importlib.util.module_from_spec(spec);spec.loader.exec_module(provenance)

LIMIT=16*1024*1024
IDENTITY_CHECKS=frozenset(['helper_null','tree_default','tree_null','tree_identity',
    'plane_default','plane_null','plane_identity','plane_restore',
    'plane_constructor_identity','plane_refresh_identity']+
    ['tree_'+x for x in ('translate','scale','shear','rotate')]+
    ['plane_'+stage+'_'+x for stage in ('constructor','refresh') for x in ('translate','scale','shear','rotate')])
PIXEL_CHECKS=frozenset(('identity','root_rgb','overlap','hidden_root','movement',
    'deletion','view','weather','bypass','fullbright','shutter','negative_neighbor','negative_visibility'))

class Rejected(RuntimeError):pass
class Pending(RuntimeError):pass

def bounded(path):
    if not path.is_file() or path.is_symlink() or path.stat().st_size>LIMIT:
        raise Rejected('Missing/oversized evidence: '+path.name)
    data=path.read_bytes()
    if len(data)>LIMIT:raise Rejected('Evidence grew beyond bound')
    return data

def digest(data):return hashlib.sha256(data).hexdigest()

def validate_inputs(root,head):
    try:return provenance.validate_stage(root,head)['manifest_sha256']
    except (provenance.Invalid,ValueError,KeyError,OSError) as error:raise Rejected(str(error)) from error

def compiled_binding(root,head):
    try:return provenance.validate_compile(root,head)
    except (provenance.Invalid,ValueError,KeyError,OSError) as error:raise Rejected(str(error)) from error

def authorization_digest(root,authorized_session):
    path=Path(root)/'authorized-identity.txt'
    if type(authorized_session) is not bool:raise Rejected('Explicit approved-session Boolean required')
    if not authorized_session:
        if path.exists():raise Rejected('Existing session file needs explicit approved-session opt-in')
        return None
    data=bounded(path)
    if not data.strip() or len(data)>256:raise Rejected('One approved local fixture identity required')
    return digest(data)

def initialize(root,head,*,failure_control=None,authorized_session=False):
    """Call once in a fresh prepared/compiled stage before the owner launches it."""
    root=Path(root).resolve()
    if not re.fullmatch('[0-9a-f]{40}',head) or failure_control not in (None,'runtime','admission'):
        raise Rejected('Explicit source head and known control required')
    reserved=('run.binding.json','client-ready.txt','phase.request','phase.ready.json','fixture.failed.json','complete.txt')
    for name in reserved+tuple('phase-'+str(n)+'.ready.json' for n in range(1,10)):
        if (root/name).exists():raise Rejected('Fresh run directory required: '+name)
    accepted=compiled_binding(root,head)
    if failure_control is not None and accepted['input_binding']['renderer_control'] is not None:
        raise Rejected('Run one control at a time')
    binding=dict(schema=2,run=uuid.uuid4().hex,head=head,
        manifest=accepted['input_binding']['manifest_sha256'],compile_binding=accepted,failure_control=failure_control,
        renderer_control=accepted['input_binding']['renderer_control'],
        authorized_session=authorized_session,authorized_identity_sha256=authorization_digest(root,authorized_session))
    with (root/'run.binding.json').open('x',encoding='utf-8') as stream:
        json.dump(binding,stream)
    return binding

class PhaseGate:
    def __init__(self,root,head,*,runtime_logs):
        self.root=Path(root).resolve()
        self.binding=json.loads(bounded(self.root/'run.binding.json'))
        if self.binding.get('schema')!=2 or self.binding.get('head')!=head:
            raise Rejected('Run source identity mismatch')
        self.logs=[Path(p).resolve() for p in runtime_logs]
        if not self.logs:
            raise Rejected('Actual owned runtime/stderr logs required')
        self.frames={}
        self.input_identity()

    def input_identity(self):
        accepted=compiled_binding(self.root,self.binding['head'])
        if (accepted!=self.binding.get('compile_binding') or accepted['input_binding']['manifest_sha256']!=self.binding['manifest'] or
            accepted['input_binding']['renderer_control']!=self.binding.get('renderer_control')):
            raise Rejected('Source/compiled binding changed')

    def healthy(self):
        if authorization_digest(self.root,self.binding['authorized_session'])!=self.binding['authorized_identity_sha256']:
            raise Rejected('Approved fixture identity changed during run')
        if (self.root/'fixture.failed.json').exists():raise Rejected('Native fixture failure retained')
        for path in self.logs:
            log=bounded(path).decode('utf-8',errors='replace')
            if re.search(r'runtime\s+(?:error|in\b)|unhandled\s+exception',log,re.I):
                raise Rejected('Native runtime error in '+path.name)

    def phase(self,expected):
        """Poll Pending; treat Rejected as terminal. Recheck after each capture."""
        if type(expected) is not int or not 1<=expected<=9:raise Rejected('Known phase required')
        self.healthy()
        path=self.root/('phase-'+str(expected)+'.ready.json')
        if not path.exists():raise Pending('No settled acknowledgment yet')
        try:ack=json.loads(bounded(path))
        except json.JSONDecodeError as error:
            if error.msg=='Extra data':raise Rejected('Multiple acknowledgment records') from error
            raise Pending('Acknowledgment write incomplete') from error
        if ack.get('phase')!=expected:raise Pending('Waiting for requested phase')
        for field in ('schema','run','manifest','head','renderer_control'):
            if ack.get(field)!=self.binding[field]:raise Rejected('Stale/foreign phase binding: '+field)
        active=0 if expected==1 else 1
        rendered=0 if expected in (1,9) else 3 if expected<5 else 2
        if self.binding['renderer_control']=='visibility' and expected not in (1,9):rendered+=1
        for field,value in dict(status='denied' if expected==9 else 'ready',
                                renderer_active=active,rendered=rendered,shutter=1 if expected==9 else 0).items():
            if ack.get(field)!=value:raise Rejected('Failed phase witness: '+field)
        if expected>1:
            controls=ack.get('identity_controls')
            if not isinstance(controls,dict) or set(controls)!=IDENTITY_CHECKS or any(type(v) not in (int,bool) or v!=1 for v in controls.values()):
                raise Rejected('Native identity/nonidentity controls incomplete')
        self.healthy()
        return ack

    def record_pixels(self,phase,pixels):
        """Owner supplies normalized map RGB(A), excluding labels/decorations."""
        if phase!=len(self.frames)+1 or not isinstance(pixels,bytes) or not 0<len(pixels)<=LIMIT:
            raise Rejected('Ordered nonempty bounded map pixels required')
        self.phase(phase)
        fingerprint=digest(pixels)
        if phase in (3,4,5,7,8,9) and fingerprint==self.frames[phase-1]:
            raise Rejected('Required visual transition has identical map pixels')
        self.healthy()
        self.frames[phase]=fingerprint

    def finish(self,pixel_checks,*,cleanup_verified=False):
        self.input_identity();self.phase(9)
        if self.binding['failure_control'] is not None or self.binding['renderer_control'] is not None:
            raise Rejected('Negative control must fail, never pass')
        if set(self.frames)!=set(range(1,10)):raise Rejected('Nine ordered map captures required')
        if not isinstance(pixel_checks,dict) or set(pixel_checks)!=PIXEL_CHECKS or any(v is not True for v in pixel_checks.values()):
            raise Rejected('Independent pixel oracles and both negative controls required')
        if bounded(self.root/'complete.txt').decode().strip()!='COMPLETE':raise Rejected('Native sequence incomplete')
        if cleanup_verified is not True:raise Rejected('Existing owner must verify all retained process exits')
        self.healthy()
        return dict(status='passed',head=self.binding['head'],run=self.binding['run'],
                    manifest=self.binding['manifest'],frames=dict(self.frames),pixel_checks=dict(pixel_checks),owned_cleanup_verified=True)

    def renderer_control_result(self,*,oracle_passed,cleanup_verified=False):
        """Record an independently observed expected defect, never acceptance."""
        control=self.binding['renderer_control']
        if control not in provenance.RENDERER_CONTROLS or self.binding['failure_control'] is not None:
            raise Rejected('A bound renderer-only control is required')
        target=3 if control=='neighbor' else 2
        self.input_identity();self.phase(target)
        if set(self.frames)!=set(range(1,target+1)) or oracle_passed is not False:
            raise Rejected('Ordered control captures and an independently failed pixel oracle required')
        if cleanup_verified is not True:raise Rejected('Existing owner must verify all retained process exits')
        self.healthy()
        return dict(status='control_detected',acceptance=False,head=self.binding['head'],run=self.binding['run'],
            renderer_control=control,failed_oracle='negative_'+control,frames=dict(self.frames),owned_cleanup_verified=True)

    def failure_control_result(self,*,cleanup_verified=False):
        """Verify expected phase-2 failure after the existing owner cleans up."""
        self.input_identity()
        control=self.binding['failure_control']
        if control not in ('runtime','admission') or self.binding['renderer_control'] is not None:
            raise Rejected('A bound runtime/admission-only control is required')
        if authorization_digest(self.root,self.binding['authorized_session'])!=self.binding['authorized_identity_sha256']:
            raise Rejected('Approved fixture identity changed during run')
        failure=json.loads(bounded(self.root/'fixture.failed.json'))
        reason='native_runtime' if control=='runtime' else 'root_admission'
        if failure.get('schema')!=2 or failure.get('run')!=self.binding['run'] or failure.get('reason')!=reason or failure.get('status')!='failed':
            raise Rejected('Expected bound native failure was not observed')
        if not (self.root/'phase-1.ready.json').is_file() or any((self.root/('phase-'+str(n)+'.ready.json')).exists() for n in range(2,10)) or (self.root/'complete.txt').exists():
            raise Rejected('Control must stop before phase-2 acknowledgment')
        baseline=json.loads(bounded(self.root/'phase-1.ready.json'))
        if any(baseline.get(k)!=self.binding[k] for k in ('schema','run','head','manifest','renderer_control')) or any(baseline.get(k)!=v for k,v in dict(phase=1,status='ready',renderer_active=0,rendered=0,shutter=0).items()):
            raise Rejected('Bound phase-1 baseline required')
        logs=[bounded(p).decode('utf-8',errors='replace') for p in self.logs]
        if control=='runtime' and not any(re.search(r'runtime\s+(?:error|in\b)',log,re.I) for log in logs):
            raise Rejected('Actual native runtime diagnostic required')
        if control=='admission' and any(re.search(r'runtime\s+(?:error|in\b)|unhandled\s+exception',log,re.I) for log in logs):
            raise Rejected('Admission control had an unrelated native runtime error')
        if cleanup_verified is not True:raise Rejected('Existing owner must verify all retained process exits')
        return dict(status='control_detected',acceptance=False,head=self.binding['head'],run=self.binding['run'],
            failure_control=control,reason=reason,owned_cleanup_verified=True)
