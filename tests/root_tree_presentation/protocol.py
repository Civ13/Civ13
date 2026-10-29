"""Fail-closed evidence gate for the existing capture owner; launches nothing.

An acknowledgment proves settled admission, never pixel correctness. The owner
must scan its actual owned runtime/stderr logs and provide normalized map pixel
bytes plus independent pixel-oracle results before finish() can succeed.
"""
import hashlib
import json
from pathlib import Path
import re
import uuid

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

def validate_inputs(root):
    manifest=bounded(root/'source-manifest.json')
    metadata=json.loads(manifest)
    for source,entry in metadata['inputs'].items():
        target=(root/source if source.startswith('icons/') else root/Path(source).name).resolve()
        if not target.is_relative_to(root):raise Rejected('Input escapes owned stage')
        if digest(bounded(target))!=entry['sha256']:raise Rejected('Staged input changed: '+target.name)
    # prepare.py hashes normalized extracted production text, not Windows CRLF.
    production=bounded(root/'production-light-update.dm').decode().replace('\r\n','\n').encode()
    if digest(production)!=metadata['production_light_update_sha256']:
        raise Rejected('Extracted production input changed')
    return digest(manifest)

def initialize(root,head,*,failure_control=None):
    """Call once in a fresh prepared/compiled stage before the owner launches it."""
    root=Path(root).resolve()
    if not re.fullmatch('[0-9a-f]{40}',head) or failure_control not in (None,'runtime','admission'):
        raise Rejected('Explicit source head and known control required')
    for name in ('run.binding.json','client-ready.txt','phase.request','phase.ready.json','fixture.failed.json','complete.txt'):
        if (root/name).exists():raise Rejected('Fresh run directory required: '+name)
    binding=dict(schema=2,run=uuid.uuid4().hex,head=head,manifest=validate_inputs(root),
        compiled_sha256=digest(bounded(root/'fixture.dmb')),
        resources_sha256=digest(bounded(root/'fixture.rsc')),failure_control=failure_control)
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
        if (validate_inputs(self.root)!=self.binding['manifest'] or
            digest(bounded(self.root/'fixture.dmb'))!=self.binding['compiled_sha256'] or
            digest(bounded(self.root/'fixture.rsc'))!=self.binding['resources_sha256']):
            raise Rejected('Source/compiled binding changed')

    def healthy(self):
        if (self.root/'fixture.failed.json').exists():raise Rejected('Native fixture failure retained')
        for path in self.logs:
            log=bounded(path).decode('utf-8',errors='replace')
            if re.search(r'runtime\s+(?:error|in\b)|unhandled\s+exception',log,re.I):
                raise Rejected('Native runtime error in '+path.name)

    def phase(self,expected):
        """Poll Pending; treat Rejected as terminal. Recheck after each capture."""
        if type(expected) is not int or not 1<=expected<=9:raise Rejected('Known phase required')
        self.healthy()
        path=self.root/'phase.ready.json'
        if not path.exists():raise Pending('No settled acknowledgment yet')
        try:ack=json.loads(bounded(path))
        except json.JSONDecodeError as error:raise Pending('Acknowledgment write incomplete') from error
        if ack.get('phase')!=expected:raise Pending('Waiting for requested phase')
        for field in ('schema','run','manifest','head'):
            if ack.get(field)!=self.binding[field]:raise Rejected('Stale/foreign phase binding: '+field)
        active=0 if expected==1 else 1
        rendered=0 if expected in (1,9) else 3 if expected<5 else 2
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
        if self.binding['failure_control'] is not None:raise Rejected('Negative control must fail, never pass')
        if set(self.frames)!=set(range(1,10)):raise Rejected('Nine ordered map captures required')
        if not isinstance(pixel_checks,dict) or set(pixel_checks)!=PIXEL_CHECKS or any(v is not True for v in pixel_checks.values()):
            raise Rejected('Independent pixel oracles and both negative controls required')
        if bounded(self.root/'complete.txt').decode().strip()!='COMPLETE':raise Rejected('Native sequence incomplete')
        if cleanup_verified is not True:raise Rejected('Existing owner must verify all retained process exits')
        self.healthy()
        return dict(status='passed',head=self.binding['head'],run=self.binding['run'],
                    manifest=self.binding['manifest'],frames=dict(self.frames),pixel_checks=dict(pixel_checks),owned_cleanup_verified=True)
