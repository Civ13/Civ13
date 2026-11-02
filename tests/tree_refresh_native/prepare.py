"""Exact-source preparation only; no engine/compiler/client launch."""
import argparse, ast, importlib.util, json, re, subprocess
from pathlib import Path
from protocol import LIMITS, CASES, digest, require
ROOT=Path(__file__).resolve().parents[2]
HERE=Path(__file__).resolve().parent

def load(name,path):
    spec=importlib.util.spec_from_file_location(name,path);m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m);return m

def proc(text, header):
    require(text.count(header+'\n')==1,'Procedure selector drift: '+header)
    start=text.index(header+'\n');end=start+len(header)+1
    while end<len(text):
        line=text[end:text.find('\n',end)+1] if '\n' in text[end:] else text[end:]
        if line.strip() and not line.startswith(('\t','#','//')):break
        end+=len(line)
    return start,end,text[start:end]

def instrument(text, header, name):
    start,end,body=proc(text,header);lines=body.splitlines(True);out=[lines[0], '\tvar/list/tree_native_clock = tree_native_begin("'+name+'", src)\n']
    for line in lines[1:]:
        if re.match(r'^\t+return(?:\s|$)',line):
            out.append(line[:len(line)-len(line.lstrip('\t'))]+'tree_native_end(tree_native_clock)\n')
        out.append(line)
    out.append('\ttree_native_end(tree_native_clock)\n')
    return text[:start]+''.join(out)+text[end:]

def once(text, old, new):
    require(text.count(old)==1,'Instrumentation anchor drift: '+old[:70]);return text.replace(old,new,1)

SPANS={
 'code/game/mob/mob_movement.dm':[],
 'code/modules/visibility/los_context.dm':[('/datum/los_context/proc/capture(presentation = FALSE)','capture')],
 'code/modules/visibility/los_lifecycle.dm':[('/client/proc/reconcile_geometric_los()','reconcile'),('/proc/los_refresh_moved_viewer(atom/movable/A, force_refresh = FALSE, list/previous_contexts)','postmove')],
 'code/modules/visibility/root_tree_presenter.dm':[('/datum/root_tree_presenter/proc/refresh(datum/los_snapshot/S)','root_refresh'),('/proc/root_tree_light_changed(turf/root)','light_notify')],
 'code/modules/visibility/los_presenter.dm':[('/datum/los_presenter/proc/refresh(datum/los_snapshot/S)','los_refresh')],
}

def adapt(relative,text):
    for header,name in SPANS.get(relative,[]):text=instrument(text,header,name)
    if relative=='code/game/mob/mob_movement.dm':
        start,end,body=proc(text,'/atom/movable/Move(newloc, direct)');lines=[]
        for line in body.splitlines(True):
            lines.append(line)
            if re.match(r'^\t+\. = \.\.\(',line):
                indent=line[:len(line)-len(line.lstrip('\t'))]
                lines.append(indent+'tree_native_engine_return(src, .)\n')
        require(len(lines)>len(body.splitlines(True)),'Native parent boundary drift')
        text=text[:start]+''.join(lines)+text[end:]
        text=once(text,'\tlos_move_contexts = los_invalidate_movement(src)\n','\tlos_move_contexts = los_invalidate_movement(src)\n\ttree_native_affected("pre", los_move_contexts)\n')
    if relative=='code/datums/observation/moved.dm':
        text=once(text,'\tlos_invalidate(am)\n','\tlos_invalidate(am)\n\ttree_native_checkpoint("entered", am)\n')
    if relative=='code/modules/visibility/los_lifecycle.dm':
        text=once(text,'\tvar/mob/M = null\n','\ttree_native_affected("post_union", affected)\n\tvar/mob/M = null\n')
        text=once(text,'/proc/los_refresh_moved_viewer(atom/movable/A, force_refresh = FALSE, list/previous_contexts)\n','/proc/los_refresh_moved_viewer(atom/movable/A, force_refresh = FALSE, list/previous_contexts)\n\ttree_native_checkpoint("postmove", A)\n')
    if relative=='code/modules/visibility/root_tree_presenter.dm':
        text=once(text,'\t\t\t\tframe = icon(T.icon, T.icon_state, T.dir)\n','\t\t\t\ttree_native_count("bakes", src)\n\t\t\t\tframe = icon(T.icon, T.icon_state, T.dir)\n')
        text=once(text,'\t\tif(!frame_inputs_unchanged(T, rgb, source_appearance))\n','\t\tvar/tree_native_cache_hit = frame_inputs_unchanged(T, rgb, source_appearance)\n\t\tif(tree_native_cache_hit)\n\t\t\ttree_native_count("frame_cache_hits", src)\n\t\tif(!tree_native_cache_hit)\n')
        text=once(text,'\t\t\troot_tree_set_frame(I, T, frame)\n','\t\t\ttree_native_count("frame_assignments", src)\n\t\t\troot_tree_set_frame(I, T, frame)\n')
        text=once(text,'\tif(light_keys[T] == key)\n\t\treturn light_values[T]','\tif(light_keys[T] == key)\n\t\ttree_native_count("light_cache_hits", src)\n\t\treturn light_values[T]')
        text=once(text,'\tfor(var/datum/root_tree_presenter/P in root_tree_presenters)\n','\tfor(var/datum/root_tree_presenter/P in root_tree_presenters)\n\t\ttree_native_count("notification_presenters", P)\n')
        text=once(text,'\t\tfor(var/obj/structure/wild/T in P.images)\n','\t\tfor(var/obj/structure/wild/T in P.images)\n\t\t\ttree_native_count("notification_root_keys", P)\n')
    if relative=='code/modules/visibility/root_light_snapshot.dm':
        text=once(text,'\tvar/rgb = mask.GetPixel(16, 16)\n','\ttree_native_count("rgb_samples", viewer.client)\n\tvar/rgb = mask.GetPixel(16, 16)\n')
    if relative in ('code/modules/visibility/root_tree_presenter.dm','code/modules/visibility/los_presenter.dm'):
        lines=[];mutation=0
        for line in text.splitlines(True):
            if re.match(r'^\t+owner.images [|+\-]= ',line):
                mutation+=1;indent=line[:len(line)-len(line.lstrip('\t'))]
                local='tree_native_image_before_'+str(mutation)
                lines.append(indent+'var/'+local+' = length(owner.images)\n')
                lines.append(line);lines.append(indent+'tree_native_image_delta(src, '+local+')\n');continue
            if re.match(r'^\t+I = image\(',line):
                indent=line[:len(line)-len(line.lstrip('\t'))];lines.append(indent+'tree_native_count("image_allocations", src)\n')
            lines.append(line)
        text=''.join(lines)
    return text

def prepare(root,out,head,toolchain=None):
    require(re.fullmatch('[0-9a-f]{40}',head),'Full exact head')
    git=lambda *a:subprocess.check_output(['git','-c','safe.directory='+root.as_posix(),'-C',str(root),*a])
    require(git('rev-parse','HEAD').decode().strip()==head and not git('status','--porcelain').strip(),'Committed clean exact head required')
    stager=load('tree_native_stager',root/'tests/human_subtile/run-npc.py')
    m=stager.prepare_source(root,out);stage=out/'stage';changes={}
    def write(rel,data):
        p=stage/rel;before=p.read_bytes() if p.exists() else b'';p.parent.mkdir(parents=True,exist_ok=True);p.write_bytes(data)
        changes[rel]=dict(before=digest(before),after=digest(data))
    for rel in set(SPANS)|{'code/datums/observation/moved.dm','code/modules/visibility/root_light_snapshot.dm'}:
        original=(stage/rel).read_text(encoding='utf-8');write(rel,adapt(rel,original).encode())
    # Replace only fixture startup/login/Topic boundaries, never native Move/Entered,
    # capture, visibility decisions, presenter admissions or frame baking.
    rel='code/modules/client/client_procs.dm';text=(stage/rel).read_text(encoding='utf-8')
    for header in ('/client/New(TopicData)','/client/Topic(href, href_list, hsrc)','/client/Del()'):
        start,end,body=proc(text,header);text=text[:start]+text[end:]
    write(rel,text.encode())
    for name in ('probe.dm','fixture.dmf'):
        write('tests/tree_refresh_native/'+name,git('show',head+':tests/tree_refresh_native/'+name))
    dme=(out/m['dme']).read_text(encoding='utf-8')
    dme=re.sub(r'^#include ".*\.dmf"\s*$','',dme,flags=re.M)
    dme=dme.replace('#include "tests\\human_subtile\\mining.dm"','').replace('#include "tests\\human_subtile\\probe.dm"','')
    # Reuse only the proven isolated initialization helper, not the old world/client.
    old=git('show',head+':tests/human_subtile/probe.dm').decode();_,_,initializer=proc(old,'/proc/human_subtile_fixture_initialize()')
    write('tests/tree_refresh_native/initialize.dm',initializer.encode())
    dme+='#include "tests\\tree_refresh_native\\initialize.dm"\n#include "tests\\tree_refresh_native\\probe.dm"\n#include "tests\\tree_refresh_native\\fixture.dmf"\n'
    write('tree_refresh.dme',('#define TREE_NATIVE_HEAD "'+head+'"\n'+dme).encode())
    pin_raw=git('show',head+':tools/byond/version.json');pin=json.loads(pin_raw)
    require(pin['version']=='516.1688','Review canonical pin advance')
    if toolchain:
        require(toolchain['version']==pin['version'] and toolchain['installer_sha256']==pin['sha256'] and toolchain['installer_bytes']==pin['bytes'],'Toolchain does not bind current canonical pin')
    m.update(kind='tree-refresh-native',schema=1,head=head,dme='stage/tree_refresh.dme',limits=LIMITS,cases=CASES,
             toolchain=toolchain,canonical_pin_sha256=digest(pin_raw),stage_adaptations=changes,prepared_only=True,native_executed=False,pixels_verified=False,
             input_files={p.relative_to(stage).as_posix():dict(bytes=p.stat().st_size,sha256=digest(p.read_bytes())) for p in stage.rglob('*') if p.is_file()})
    raw=(json.dumps(m,indent=2,sort_keys=True)+'\n').encode();(out/'tree-native-manifest.json').write_bytes(raw)
    return m

if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);p.add_argument('--source-commit',required=True);p.add_argument('--toolchain-manifest',type=Path);a=p.parse_args()
    m=prepare(ROOT,a.output.resolve(),a.source_commit,json.loads(a.toolchain_manifest.read_text()) if a.toolchain_manifest else None);print(json.dumps(dict(head=m['head'],prepared_only=True,files=len(m['input_files']),native_executed=False)))
