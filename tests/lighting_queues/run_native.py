"""Compile actual Civ13 lighting callbacks with normal startup/maps disabled."""
import argparse, hashlib, json, os, shutil, subprocess, tempfile, uuid
from pathlib import Path
from run import BASELINE
from sampling import observe

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--byond-bin',type=Path,required=True)
    p.add_argument('--baseline',action='store_true')
    p.add_argument('--compare',type=Path)
    p.add_argument('--output',type=Path,required=True)
    p.add_argument('--size',type=int,choices=(32,128),default=32)
    p.add_argument('--lights',type=int,choices=(200,2000),default=200)
    a=p.parse_args(); root=Path(__file__).resolve().parents[2]
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
    stem='.lighting_'+uuid.uuid4().hex
    files=[root/(stem+s) for s in ('.dme','_world.dm','_overlays.dm','_sources.dm','.dmb','.rsc')]
    flags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0
    try:
        world=(root/'code/world.dm').read_text(encoding='utf-8')
        start=world.index('/world/New()'); parent=world.index('\n\t..()',start)
        world=world[:parent]+world[parent:].replace('\n\t..()','',1)
        files[1].write_text(world.replace('/world/New()','/world/proc/unused_lighting_startup()',1),encoding='utf-8')
        source=(root/'civ13.dme').read_text(encoding='utf-8').replace('code\\world.dm',files[1].name)
        source='\n'.join(x for x in source.splitlines() if not x.strip().startswith('#include "maps\\'))
        for i,name in ((2,'overlays'),(3,'sources')):
            rel=f'code/processes/lighting/{name}.dm'
            text=subprocess.check_output(['git','show',f'{BASELINE}:{rel}'],cwd=root,text=True) if a.baseline else (root/rel).read_text(encoding='utf-8')
            files[i].write_text(text,encoding='utf-8'); source=source.replace(rel.replace('/','\\'),files[i].name)
        source+='\n#include "tests/lighting_queues/native_probe.dm"\n'
        files[0].write_text(source,encoding='utf-8')
        queue_hashes={f.name.rsplit('_',1)[-1]:hashlib.sha256(f.read_bytes()).hexdigest() for f in files[2:4]}
        with tempfile.TemporaryDirectory(prefix='civ13-lighting-native-') as tmp:
            out=Path(tmp)
            dm=a.byond_bin/('dm.exe' if os.name=='nt' else 'DreamMaker')
            dd=a.byond_bin/('dd.exe' if os.name=='nt' else 'DreamDaemon')
            build=subprocess.run([str(dm),str(files[0])],cwd=root,capture_output=True,text=True,timeout=120,creationflags=flags)
            print(build.stdout)
            if build.returncode or '0 errors, 0 warnings' not in build.stdout: raise RuntimeError('Compilation failed')
            for f in files[4:]: shutil.copy2(f,out/f.name)
            for rel in subprocess.check_output(['git','ls-files','config/names'],cwd=root,text=True).splitlines():
                dest=out/rel; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(root/rel,dest)
            (out/'config/config.txt').write_text('server_name Lighting fixture\n')
            with (out/'daemon.log').open('w') as log:
                cmd=[str(dd),str(out/files[4].name)]
                if os.name=='nt': cmd+=['-invisible','-close']
                cmd+=['-trusted','-params',f'size={a.size}&lights={a.lights}','-log','runtime.log']
                result=subprocess.Popen(cmd,cwd=out,stdout=log,stderr=log,creationflags=flags)
                memory=observe(result,180)
            log=(out/'runtime.log').read_text(errors='replace')
            completion=(out/'result.txt').read_text().strip() if (out/'result.txt').exists() else 'Missing completion'
            print((out/'daemon.log').read_text(errors='replace'))
            print('Entered:',(out/'startup.txt').exists())
            if result.returncode or completion!='PASS' or any(x in log for x in ('FAIL','Runtime in','runtime error','Bad ref')): raise RuntimeError(completion+'\n'+log)
            states=[json.loads(x) for x in (out/'states.jsonl').read_text(encoding='utf-8').splitlines()]
            if a.compare and states!=json.loads(a.compare.read_text(encoding='utf-8'))['states']: raise RuntimeError('Lighting parity differs')
            a.output.parent.mkdir(parents=True,exist_ok=True)
            rows=[json.loads(x) for x in (out/'metrics.jsonl').read_text().splitlines()]
            a.output.write_text(json.dumps(dict(head=head,baseline=BASELINE if a.baseline else None,size=a.size,lights=a.lights,queue_hashes=queue_hashes,states=states,metrics=rows,compile=build.stdout,log=log,**memory)))
            print(f'PASS: five production lighting cycles; output {a.output}')
    finally:
        for f in files: f.unlink(missing_ok=True)
if __name__=='__main__': main()
