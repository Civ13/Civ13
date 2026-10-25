"""Pinned synthetic zone preparation, independent of canonical Git-dependent runner.
Never executes any native program. Original tracked source remains untouched.
"""
import hashlib,json,re,subprocess
from pathlib import Path
HEAD='8144be445fa0492a515b6bb47b9692e0edc1830b'
TREE='508e7e0677a8cdc45ab6eed100bcbb0d1fb283f3'
ADAPTER='zone-native-516.1688-v2-jobmaster'

def digest(data):return hashlib.sha256(data).hexdigest()
def blob(data):return hashlib.sha1(b'blob '+str(len(data)).encode()+b'\0'+data).hexdigest()
def replace(text,a,b):
 if text.count(a)!=1:raise ValueError('Unique adapter anchor changed: '+a)
 return text.replace(a,b,1)
def git(source,*args):
 return subprocess.check_output(['git',*args],cwd=source,timeout=30)
def source_inventory(source):
 if git(source,'rev-parse','HEAD').decode().strip()!=HEAD or git(source,'rev-parse','HEAD^{tree}').decode().strip()!=TREE:raise ValueError('Wrong source HEAD/tree')
 if git(source,'status','--porcelain','--untracked-files=no').strip():raise ValueError('Tracked source changes')
 raw=git(source,'ls-tree','-rz','--full-tree','HEAD');rows={};total=0
 for entry in raw.split(b'\0'):
  if not entry:continue
  info,name=entry.split(b'\t',1);mode,kind,sha=info.decode().split();name=name.decode()
  if kind!='blob' or mode not in ('100644','100755') or Path(name).is_absolute() or '..' in Path(name).parts:raise ValueError('Unsupported source member')
  file=source/name
  if file.is_symlink() or any(p.is_symlink() for p in file.parents if p!=source.parent):raise ValueError('Source symlink')
  data=file.read_bytes();total+=len(data)
  if total>1024**3 or len(data)>128*1024**2 or blob(data)!=sha:raise ValueError('Source byte binding failed: '+name)
  rows[name]={'blob':sha,'sha256':digest(data),'mode':mode,'size':len(data)}
 return rows

def adapt_probe(prefix,zone):
 prefix=prefix[:prefix.index('/world/New()')]
 zone=replace(zone,'get_area(locate(8,8,2)).persistence_zone_id','created_zone.persistence_zone_id')
 anchor='\t\t\t\t\t\tdurable_world_check(created_zone.persistence_zone_id'
 zone=replace(zone,anchor,'\t\t\t\t\t\tvar/area/created_zone = get_area(locate(8,8,2))\n'+anchor)
 start=zone.index('/proc/zone_fixture_remove_referenced_zone(');end=zone.index('\n/world',start)
 part=zone[start:end];assert part.count('spawn')==4
 part=part.replace('list/spawn)','list/spawn_row)').replace('spawn[','spawn_row[');zone=zone[:start]+part+zone[end:]
 # The synthetic world skips setup_everything; retain its real controller
 # construction without loading the full job roster or bypassing round restore.
 zone=replace(zone,'\t\tticker = new','\t\tjob_master = new /datum/controller/occupations()\n\t\tticker = new')
 zone=replace(zone,'\tvar/mode = world.params["zone_mode"]','\tvar/mode = world.params["zone_mode"]\n\tvar/rejection_reason = null\n\tvar/expected_rejection = null')
 zone=replace(zone,'\ttry\n\t\tOpenPort(19327)','\ttry\n\t\tdurable_world_check(world.byond_version == 516 && world.byond_build == 1688, "Wrong runtime version")\n\t\tOpenPort(19327)')
 zone=replace(zone,'text2file("closed", "probe-port-closed.txt")','text2file(json_encode(list("port" = world.port, "head" = "'+HEAD+'", "version" = "516.1688", "mode" = mode)), "probe-port-closed.json")')
 # Record independent pre-call prediction of the existing malformed inputs.
 anchor='\t\t\t\tF = null'
 prediction='''\t\t\t\tvar/list/expected_by_mode = list("duplicate-spawn" = "Duplicate or stale spawn zone", "stale-zone" = "Duplicate or stale spawn zone", "wrong-z" = "Spawn outside saved world", "fractional" = "Spawn outside saved world", "duplicate-zone" = "Invalid or duplicate zone identity", "absent-zone" = "Captured zone membership differs", "overlong" = "Captured zone membership differs")
\t\t\t\texpected_rejection = expected_by_mode[mode]
\t\t\t\tif(mode == "incomplete")
\t\t\t\t\tF.cd = "/zone_capture/[turf_ref]"
\t\t\t\t\texpected_rejection = (F.dir.len != 2 || !("index" in F.dir) || !("id" in F.dir)) ? "Missing captured membership" : "Captured zone membership differs"
\t\t\t\ttext2file(json_encode(list("mode" = mode, "expected" = expected_rejection)), "negative-prediction.json")
'''
 zone=replace(zone,anchor,prediction+anchor)
 anchor='\t\t\t\tdurable_world_check(!ticker.loadmap(), "Malformed topology was accepted")'
 zone=replace(zone,anchor,'\t\t\t\tworld.log << "ZONE_PHASE [mode] begin"\n'+anchor+'\n\t\t\t\trejection_reason = map_storage.last_error\n\t\t\t\tdurable_world_check(findtext(rejection_reason, "[expected_rejection] on ") == 1, "Unexpected rejection reason")\n\t\t\t\tworld.log << "ZONE_PHASE [mode] end"')
 zone=replace(zone,'list("mode" = mode, "checks" = durable_probe_checks, "failed" = durable_probe_failed)','list("mode" = mode, "checks" = durable_probe_checks, "failed" = durable_probe_failed, "head" = "'+HEAD+'", "version" = "516.1688", "rejection" = rejection_reason, "expected" = expected_rejection)')
 zone=zone.replace('ticker.loadmap()', 'zone_fixture_load_1688()').replace('map_storage.Save_World()', 'zone_fixture_save_1688()')
 result_anchor='"rejection" = rejection_reason, "expected" = expected_rejection)'
 zone=replace(zone,result_anchor,'"rejection" = rejection_reason, "expected" = expected_rejection, "save_calls" = zone_save_calls_1688, "load_calls" = zone_load_calls_1688, "load_successes" = zone_load_successes_1688)')
 instrumentation='var/zone_save_calls_1688 = 0\nvar/zone_load_calls_1688 = 0\nvar/zone_load_successes_1688 = 0\n/proc/zone_fixture_save_1688()\n\tzone_save_calls_1688++\n\treturn map_storage.Save_World()\n/proc/zone_fixture_load_1688()\n\tzone_load_calls_1688++\n\tvar/success = ticker.loadmap()\n\tif(success) zone_load_successes_1688++\n\treturn success\n'
 return prefix+instrumentation+zone

def prepare(source,output):
 source=source.resolve(strict=True);output=output.absolute()
 if output.exists() or source==output or source in output.parents:raise ValueError('Fresh output outside checkout required')
 rows=source_inventory(source);output.mkdir(parents=True);root=output/'source';root.mkdir()
 for name,row in rows.items():
  p=root/name;p.parent.mkdir(parents=True,exist_ok=True);data=(source/name).read_bytes()
  if digest(data)!=row['sha256']:raise ValueError('Source changed during copy')
  p.write_bytes(data);p.chmod(0o755 if row['mode']=='100755' else 0o644)
 src=(root/'civ13.dme').read_text();src=re.sub(r'^#include ".*\.dmm"\s*$','',src,flags=re.M)
 generated={}
 for i,rel in enumerate(('code/world.dm','code/controllers/mc/globals.dm')):
  text=(root/rel).read_text()
  if rel=='code/world.dm':
   start=text.index('/world/New()');parent=text.index('\n\t..()',start)
   text=text[:parent]+text[parent:].replace('\n\t..()','',1);text=replace(text,'/world/New()','/world/proc/unused_durable_startup()');marker='/datum/global_init/New()\n'
  else:marker='/datum/controller/global_vars/New()\n'
  text=replace(text,marker,marker+'\treturn\n');name=f'zone-1688-startup-{i}.dm';(root/name).write_text(text);generated[name]=digest((root/name).read_bytes());src=replace(src,rel.replace('/',chr(92)),name)
 probe=adapt_probe((root/'tests/world_save/durable_world_probe.dm').read_text(),(root/'tests/zone_persistence/probe.dm').read_text())
 (root/'zone-1688-probe.dm').write_text(probe);src+='\n#include "zone-1688-probe.dm"\n';(root/'zone-1688.dme').write_text(src)
 for name in ('zone-1688-probe.dm','zone-1688.dme'):generated[name]=digest((root/name).read_bytes())
 receipt={'head':HEAD,'tree':TREE,'version':'516.1688','adapter':ADAPTER,'source':rows,'generated':generated,'native_executed':False,'canonical_runner_executed':False,'dimensions':[8,8,2]}
 (output/'preparation.json').write_text(json.dumps(receipt,indent=2));return receipt

def verify_fixture(output,receipt):
 root=output/'source'
 for name,row in receipt['source'].items():
  p=root/name
  if p.is_symlink() or digest(p.read_bytes())!=row['sha256']:raise ValueError('Source changed: '+name)
 for name,h in receipt['generated'].items():
  p=root/name
  if p.is_symlink() or digest(p.read_bytes())!=h:raise ValueError('Adapter changed: '+name)
