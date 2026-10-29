"""Current revision -> deterministic compiler inputs -> compiled output evidence.

Runtime reads the selected current commit; tests need no historic Git objects.
"""
import ast
import hashlib
import json
from pathlib import Path
import re
import subprocess

ROOT=Path(__file__).resolve().parents[2]
LIMIT=16*1024*1024
COPIES=('code/modules/visibility/los_context.dm','code/modules/visibility/root_light_snapshot.dm',
        'code/modules/visibility/root_tree_presenter.dm','tests/root_tree_presentation/fixture.dm')
ASSETS=('icons/effects/icon.png','icons/turf/areas.dmi','icons/turf/floors.dmi',
        'icons/obj/flora/bigtrees.dmi','icons/obj/flora/bigtrees_winter.dmi',
        'icons/obj/flora/deadtrees.dmi','icons/obj/flora/deadtrees_winter.dmi')
OVERLAY='code/modules/lighting/lighting_overlay.dm'
PLANE='code/_onclick/hud/plane_master.dm'
COVERAGE='code/modules/lighting/lighting_composition.dm'
PIN='tests/human_subtile/native_1688/guard_config.py'
TOOLS=tuple('tests/root_tree_presentation/'+p for p in ('prepare.py','provenance.py','protocol.py','compile.py'))
TEMPLATES=('tests/root_tree_presentation/fixture.dme.in','tests/root_tree_presentation/fixture.dmf.in')
SOURCES=COPIES+ASSETS+(OVERLAY,PLANE,COVERAGE,PIN)+TOOLS+TEMPLATES

class Invalid(RuntimeError):pass
def digest(data):return hashlib.sha256(data).hexdigest()
def describe(data):return dict(sha256=digest(data),bytes=len(data))
def read(path):
    if not path.is_file() or path.is_symlink() or path.stat().st_size>LIMIT:raise Invalid('Missing/oversized evidence: '+path.name)
    data=path.read_bytes()
    if len(data)>LIMIT:raise Invalid('Evidence grew beyond bound')
    return data
def _git(root,*args,input=None):
    result=subprocess.run(['git',*args],cwd=root,input=input,capture_output=True,timeout=20)
    if result.returncode:raise Invalid('Current source Git verification failed: '+args[0])
    return result.stdout

def revision(head,root=ROOT):
    """Read canonical blobs from this checkout's exact current HEAD."""
    if not re.fullmatch('[0-9a-f]{40}',head):raise Invalid('Full source revision required')
    if _git(root,'rev-parse','HEAD').decode().strip()!=head:raise Invalid('Requested head is not checkout HEAD')
    _git(root,'diff','--quiet','HEAD','--',*SOURCES)
    tree=_git(root,'rev-parse','HEAD^{tree}').decode().strip()
    output=_git(root,'cat-file','--batch',input=''.join(head+':'+p+'\n' for p in SOURCES).encode())
    sources={};offset=0
    for path in SOURCES:
        end=output.find(b'\n',offset);header=output[offset:end].split();offset=end+1
        if end<0 or len(header)!=3 or header[1]!=b'blob':raise Invalid('Missing committed source: '+path)
        size=int(header[2])
        if not 0<=size<=LIMIT or output[offset+size:offset+size+1]!=b'\n':raise Invalid('Bad source object size')
        sources[path]=output[offset:offset+size];offset+=size+1
    if offset!=len(output) or _git(root,'rev-parse','HEAD').decode().strip()!=head:raise Invalid('Source changed during verification')
    return dict(head=head,tree=tree,sources=sources)

def proc(data,signature):
    lines=data.decode().splitlines();starts=[i for i,l in enumerate(lines) if l.startswith(signature)]
    if len(starts)!=1:raise Invalid('Production procedure anchor changed')
    start=starts[0];end=next((i for i in range(start+1,len(lines)) if lines[i].startswith('/')),len(lines))
    return ('\n'.join(lines[start:end])+'\n').encode()

def plan(head):
    state=revision(head)
    if state['head']!=head or set(state['sources'])!=set(SOURCES):raise Invalid('Source revision mismatch/incomplete snapshot')
    src=state['sources'];files={Path(p).name:src[p] for p in COPIES}
    files.update({p:src[p] for p in ASSETS})
    files['production-light-update.dm']=(proc(src[OVERLAY],'/proc/copylist(')+
        proc(src[OVERLAY],'/atom/movable/lighting_overlay/proc/update_overlay(')+
        proc(src[PLANE],'/obj/screen/plane_master/light_mask/backdrop(')+
        proc(src[PLANE],'/mob/proc/update_lighting_plane(')+src[COVERAGE])
    files.update({'fixture.dme':src[TEMPLATES[0]],'fixture.dmf':src[TEMPLATES[1]]})
    manifest=dict(schema=3,head=head,tree=state['tree'],
        source_objects={p:dict(describe(data),git_blob=hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()) for p,data in src.items()},
        files={p:describe(data) for p,data in files.items()})
    binaries=next(ast.literal_eval(n.value) for n in ast.parse(src[PIN]).body
        if isinstance(n,ast.Assign) and any(isinstance(t,ast.Name) and t.id=='BINARIES' for t in n.targets))
    manifest['compiler_sha256']=binaries['dm.exe']
    return manifest,files

def validate_stage(root,head):
    root=Path(root).resolve();expected,files=plan(head)
    raw=read(root/'source-manifest.json')
    if json.loads(raw)!=expected:raise Invalid('Stage manifest is not the specified source revision')
    for path,data in files.items():
        if read(root/path)!=data:raise Invalid('Stage differs from committed/generated input: '+path)
    return dict(head=head,tree=expected['tree'],manifest_sha256=digest(raw),files=expected['files'],compiler_sha256=expected['compiler_sha256'])

def output_artifacts(root):return {p:describe(read(Path(root)/p)) for p in ('fixture.dmb','fixture.rsc')}

def require_fresh_outputs(root):
    if any((Path(root)/name).exists() for name in ('fixture.dmb','fixture.rsc','compile.receipt.json','compile.log','compile-supervisor.json')):
        raise Invalid('Fresh stage required; retain stale compiler outputs/evidence')

def validate_compile(root,head):
    """Require producer receipt, actual compiler log and retained exit audit."""
    root=Path(root).resolve();inputs=validate_stage(root,head)
    raw=read(root/'compile.receipt.json');receipt=json.loads(raw)
    if (receipt.get('schema')!=3 or receipt.get('kind')!='root_tree_compile' or
        receipt.get('head')!=head or receipt.get('input_binding')!=inputs or
        receipt.get('passed') is not True or receipt.get('exit_code')!=0 or
        receipt.get('compile_only') is not True or receipt.get('runtime_executed') is not False or
        receipt.get('compiler_sha256')!=inputs['compiler_sha256'] or receipt.get('artifacts')!=output_artifacts(root)):
        raise Invalid('Compiler receipt does not bind this source to these outputs')
    log=read(root/'compile.log');audit=read(root/'compile-supervisor.json')
    if receipt.get('compiler_log_sha256')!=digest(log) or receipt.get('supervisor_sha256')!=digest(audit):raise Invalid('Compiler evidence changed')
    text=log.decode(errors='replace')
    if 'DM compiler version 516.1688' not in text or '0 errors, 0 warnings' not in text:raise Invalid('Compiler did not accept fixture')
    supervisor=json.loads(audit);phases=supervisor.get('phases',[])
    if supervisor.get('head')!=head or supervisor.get('failed') is not False or len(phases)!=1:raise Invalid('Wrong compiler supervisor')
    phase=phases[0];final=phase.get('final',{});cleanup=phase.get('cleanup',{})
    if (phase.get('argv')!=receipt.get('command') or len(phase.get('argv',[]))!=4 or
        Path(phase['argv'][0]).name.lower()!='dm.exe' or phase['argv'][1:3]!=['-max_errors','0'] or
        phase['argv'][-1]!=receipt.get('dme') or phase.get('cwd')!=str(Path(receipt['dme']).parent)):
        raise Invalid('Compiler command/source entry point mismatch')
    if (phase.get('phase')!='compile' or phase.get('accepted') is not True or
        phase.get('owned_exit_evidence_complete') is not True or final.get('exit_code')!=0 or
        final.get('total_processes')!=1 or final.get('active_processes')!=0 or
        cleanup.get('all_retained_exited') is not True or cleanup.get('total_assigned')!=1 or
        cleanup.get('errors')!=[] or cleanup.get('captured_unexpected')!=[] or
        len(cleanup.get('exits',[]))!=1 or cleanup['exits'][0].get('exit_code')!=0):raise Invalid('Compiler ownership/exit evidence incomplete')
    if not phase.get('samples') or any(s.get('sockets')!=[] or s.get('total')!=1 or s.get('retained')!=1 for s in phase['samples']):raise Invalid('Compiler observation evidence incomplete')
    return dict(input_binding=inputs,compile_receipt_sha256=digest(raw),artifacts=receipt['artifacts'])
