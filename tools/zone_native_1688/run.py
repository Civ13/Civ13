"""Proposed exact-head Linux native controller; defaults to source preparation.
Execution requires a separately reviewed --reviewed-native invocation. No QEMU.
"""
import argparse,hashlib,json,os,re,shutil,sys,time,zipfile
from pathlib import Path
from prepare import HEAD,TREE,prepare,verify_fixture,digest
from owned_process_1688 import run_bounded,proc_identity
from oracle import MODES,NEGATIVE,FATAL,verify_result,verify_aux_logs
ARCHIVE='16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9'
COMPILE={'cpu':150,'as':2*1024**3,'file':128*1024**2,'fds':256}
RUNTIME={'cpu':60,'as':1024**3,'file':16*1024**2,'fds':128}
FILES=('map.txt','round.json','1.sav','2.sav','save_complete.txt')
LIMIT=4*1024**2

def read(path,limit=LIMIT):
 if path.is_symlink() or not path.is_file() or path.stat().st_size>=limit:raise ValueError('Missing/oversized/symlink evidence: '+str(path))
 return path.read_text(encoding='utf-8-sig',errors='strict')
def dump(path,data):path.write_text(json.dumps(data,indent=2))
def binaries(directory,archive):
 if archive.is_symlink() or digest(archive.read_bytes())!=ARCHIVE:raise ValueError('Wrong official-observed archive bytes')
 rows={}
 with zipfile.ZipFile(archive) as z:
  if len(z.namelist())!=len(set(z.namelist())):raise ValueError('Duplicate archive members')
  for name in ('DreamMaker','DreamDaemon','libbyond.so','libext.so'):
   expected=digest(z.read('byond/bin/'+name));p=directory/name
   if p.is_symlink() or not p.is_file() or digest(p.read_bytes())!=expected:raise ValueError('Runtime member mismatch: '+name)
   rows[name]=expected
 return rows

def generation(source,destination):
 # Caller supplies only fixed controller paths, never manifest-provided paths.
 if source.is_symlink() or not source.is_dir() or any(p.is_symlink() for p in source.iterdir()):raise ValueError('Invalid generation directory')
 if {p.name for p in source.iterdir()}!=set(FILES):raise ValueError('Generation file inventory differs')
 destination.mkdir();rows={}
 for name in FILES:
  p=source/name
  if p.stat().st_size>16*1024**2:raise ValueError('Oversized synthetic save')
  data=p.read_bytes();(destination/name).write_bytes(data);rows[name]=digest(data)
 if (destination/'save_complete.txt').read_text()!= (source/'save_complete.txt').read_text():raise ValueError('Completion copy differs')
 state=json.loads(read(destination/'round.json',16*1024**2));marker=(destination/'save_complete.txt').read_text().strip()
 if not re.fullmatch(r'round-v[12]:[0-9a-f]{32}',marker) or state.get('generation')!=marker:raise ValueError('Generation identity differs from completion marker')
 return rows

def listener_ack(work,mode):
 state={'acknowledged':False}
 def sample(pid,identity,observed):
  # Bound fixture outputs throughout the process, not only after exit.
  count=0;size=0
  for path in work.rglob('*'):
   if path.is_symlink():raise ValueError('Unexpected fixture output symlink')
   if path.is_file() and path.name not in ('zone-1688.dmb','zone-1688.rsc'):
    count+=1;size+=path.stat().st_size
  if count>2048 or size>256*1024**2:raise ValueError('Aggregate fixture output bound exceeded')
  if state['acknowledged']:return
  ready=work/'probe-port-closed.json'
  if not ready.exists():return
  if (work/'probe-port-closed.ack').exists():raise ValueError('Preexisting listener acknowledgement')
  value=json.loads(read(ready));current=proc_identity(pid)
  if current is None or current['start_ticks']!=identity['start_ticks'] or current['state'] in ('Z','X'):raise ValueError('Leader not alive at census')
  if value!={'port':0,'head':HEAD,'version':'516.1688','mode':mode} or type(value['port']) is not int:raise ValueError('Wrong closure readiness')
  sockets=set();seen=[]
  for child,old in observed.items():
   now=proc_identity(child)
   if now is None or now['start_ticks']!=old['start_ticks']:raise ValueError('Owned identity vanished during census')
   if now['state'] in ('Z','X'):continue
   for fd in Path(f'/proc/{child}/fd').iterdir():
    try:link=os.readlink(fd)
    except FileNotFoundError:raise ValueError('FD inventory raced during census')
    if link.startswith('socket:['):sockets.add(link[8:-1])
   seen.append(now)
  listeners=[]
  for table in ('tcp','tcp6'):
   for line in Path(f'/proc/{pid}/net/{table}').read_text().splitlines()[1:]:
    fields=line.split()
    if fields[3]=='0A' and fields[9] in sockets:listeners.append({'table':table,'local':fields[1],'inode':fields[9]})
  if listeners:raise ValueError('Owned listening socket at closure census')
  current=proc_identity(pid)
  if current is None or current['start_ticks']!=identity['start_ticks'] or current['state'] in ('Z','X'):raise ValueError('Leader exited during census')
  dump(work/'listener-census.json',{'leader':identity,'owned':seen,'listeners':listeners,'port':0})
  (work/'probe-port-closed.ack').write_text('closed after owned-process census\n');state['acknowledged']=True
 return sample,state

def run_native(source,output,receipt,binary,archive,summary):
 summary['compiler_attempted']=True;dump(output/'result.json',summary)
 deadline=time.monotonic()+1200;runtime_hashes=binaries(binary,archive);dump(output/'runtime-binding.json',runtime_hashes)
 root=output/'source'
 def run(command,work,role,profile,wall,callback=None):
  family='compiler' if role=='compile' else 'daemon'
  phase={'role':family,'mode':None if role=='compile' else work.name,'attempted':True,'started':False,'completed':False}
  summary['phases'].append(phase);summary[family+'_attempted']=True;dump(output/'result.json',summary)
  remaining=min(wall,deadline-time.monotonic())
  if remaining<=0:raise ValueError('Aggregate 20-minute deadline reached')
  verify_fixture(output,receipt)
  for name,h in receipt['controller_sha256'].items():
   if digest(Path(__file__).with_name(name).read_bytes())!=h:raise ValueError('Controller source changed')
  if binaries(binary,archive)!=runtime_hashes:raise ValueError('Runtime changed')
  for name in ('home','tmp'):(work/name).mkdir()
  env={'HOME':str(work/'home'),'TMPDIR':str(work/'tmp'),'LANG':'C','LC_ALL':'C','TZ':'UTC','BYOND_SYSTEM':str(binary.parent),'LD_LIBRARY_PATH':str(binary)}
  dump(work/(role+'-start.json'),{'command':command,'limits':profile,'wall_seconds':remaining,'head':HEAD})
  def started(pid,identity):
   # Called only after successful Popen, before any identity/census admission.
   phase.update(started=True,pid=pid,initial_identity=identity)
   summary[family+'_started']=True;summary['native_executed']=True
   dump(work/(role+'-started.json'),{'pid':pid,'identity':identity,'head':HEAD,'command':command})
   dump(output/'result.json',summary)
  try:r=run_bounded(command,work,work/(role+'.log'),remaining,LIMIT,env,profile,callback,started)
  except BaseException as e:
   phase['error']=str(e)
   dump(work/(role+'-process.json'),{'error':str(e),'cleanup_verified':False,'phase':phase});dump(output/'result.json',summary);raise
  phase.update(completed=True,exit_code=r['exit_code'])
  if family=='compiler':summary['compiler_completed']=True
  else:summary['daemon_completed']=sum(p['role']=='daemon' and p['completed'] for p in summary['phases'])==len(MODES)
  dump(work/(role+'-process.json'),r);dump(output/'result.json',summary)
  if r['exit_code']!=0 or r['stop_reason'] or r['log_truncated'] or not r['cleanup_no_observed_live_descendants'] or not r['cleanup_process_group_absent']:raise ValueError('Process or cleanup failed: '+role)
  return read(work/(role+'.log'))
 log=run([str(binary/'DreamMaker'),'-max_errors','0','zone-1688.dme'],root,'compile',COMPILE,180)
 if 'DM compiler version 516.1688' not in log or '0 errors, 0 warnings' not in log or re.search(r'\berror:|\bwarning:|invalid file',log,re.I):raise ValueError('Pinned clean native compile required')
 compiled={}
 for name in ('zone-1688.dmb','zone-1688.rsc'):
  p=root/name
  if p.is_symlink() or not p.is_file() or p.stat().st_size>128*1024**2:raise ValueError('Invalid compiled artifact')
  compiled[name]=digest(p.read_bytes())
 dump(output/'compiled.json',compiled)
 results={};runs=output/'runs';runs.mkdir()
 for mode in MODES:
  work=runs/mode;work.mkdir()
  for name,h in compiled.items():
   data=(root/name).read_bytes()
   if digest(data)!=h:raise ValueError('Compiled artifact changed')
   (work/name).write_bytes(data)
  # Only fixed synthetic config payload required by canonical fixture.
  (work/'config').mkdir();shutil.copyfile(root/'config/tips.txt',work/'config/tips.txt');shutil.copytree(root/'config/names',work/'config/names')
  copied={}
  if mode in ('read',*NEGATIVE):copied=generation(runs/'write/map_saves',work/'map_saves')
  elif mode=='legacy-read':copied=generation(runs/'legacy-write/map_saves',work/'map_saves')
  elif mode=='read-sequence':
   (work/'zone-fixtures').mkdir()
   for stage in ('baseline','changed','deleted'):copied[stage]=generation(runs/'write-sequence/zone-fixtures'/stage,work/'zone-fixtures'/stage)
   manifest=runs/'write-sequence/zone-fixtures/manifest.json';read(manifest);shutil.copyfile(manifest,work/'zone-fixtures/manifest.json');copied['manifest']=digest(manifest.read_bytes())
  dump(work/'input-hashes.json',copied)
  sample,state=listener_ack(work,mode)
  run([str(binary/'DreamDaemon'),'zone-1688.dmb','-ip','127.0.0.1','-invisible','-close','-trusted','-nowebclient','-params','zone_mode='+mode,'-log','runtime.log'],work,'daemon',RUNTIME,90,sample)
  for name,h in compiled.items():
   if digest((work/name).read_bytes())!=h:raise ValueError('Runtime changed compiled artifact')
  for p in work.rglob('*'):
   if p.is_symlink():raise ValueError('Symlink output at process exit')
  if not state['acknowledged'] or (work/'zone-failure.txt').exists():raise ValueError('Missing closure or fixture failure')
  result=json.loads(read(work/'zone-result.json'));runtime=read(work/'runtime.log');prediction=json.loads(read(work/'negative-prediction.json')) if mode in NEGATIVE else None
  verify_result(mode,result,runtime,prediction)
  logs={};total=0
  for p in work.rglob('*.log'):
   text=read(p);total+=len(text.encode())
   if total>16*1024**2:raise ValueError('Aggregate per-mode log cap')
   logs[str(p.relative_to(work))]=text
  verify_aux_logs(logs,mode,result)
  if mode=='absent-zone':
   proof=json.loads(read(work/'zone-negative-setup.json'))
   if type(proof.get('removed_rows')) is not int or proof['removed_rows']!=1 or type(proof.get('spawn_still_references')) is not int or proof['spawn_still_references']!=1 or type(proof.get('membership_cells_still_referencing')) is not int or proof['membership_cells_still_referencing']<=0:raise ValueError('Absent-zone control proof missing')
  results[mode]=result;dump(output/'mode-results.json',results)
  dump(work/'output-hashes.json',{str(p.relative_to(work)):digest(p.read_bytes()) for p in work.rglob('*') if p.is_file() and p.name not in compiled})
 return results

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('--source',required=True,type=Path);p.add_argument('--output',required=True,type=Path);p.add_argument('--byond-bin',type=Path);p.add_argument('--byond-archive',type=Path);p.add_argument('--reviewed-native',action='store_true');a=p.parse_args()
 receipt=prepare(a.source,a.output)
 receipt['controller_sha256']={name:digest(Path(__file__).with_name(name).read_bytes()) for name in ('run.py','prepare.py','oracle.py','owned_process_1688.py')}
 dump(a.output/'preparation.json',receipt)
 summary={'head':HEAD,'tree':TREE,'status':'prepared-only','native_executed':False,'compiler_attempted':False,'compiler_started':False,'compiler_completed':False,'daemon_attempted':False,'daemon_started':False,'daemon_completed':False,'phases':[]}
 try:
  if a.reviewed_native:
   if sys.platform!='linux' or not a.byond_bin or not a.byond_archive:raise ValueError('Reviewed native Linux runtime inputs required')
   summary.update(status='native-requested');dump(a.output/'result.json',summary)
   summary['modes']=run_native(a.source,a.output.resolve(),receipt,a.byond_bin.resolve(strict=True),a.byond_archive.resolve(strict=True),summary);summary['status']='passed'
 except BaseException as e:summary.update(status='failed',error=str(e));raise
 finally:dump(a.output/'result.json',summary)
if __name__=='__main__':main()
