"""Measure actual production daylight/weather sweeps in an isolated BYOND world."""
import argparse, json, os, shutil, subprocess, tempfile, time, uuid
from pathlib import Path

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--byond-bin',required=True,type=Path)
    p.add_argument('--baseline',action='store_true')
    p.add_argument('--size',type=int,choices=(128,256,384),default=256)
    p.add_argument('--areas',type=int,choices=(256,4096),default=4096)
    a=p.parse_args(); root=Path(__file__).resolve().parents[2]
    out=Path(tempfile.mkdtemp(prefix='civ13-environment-')); print(f'Evidence: {out}',flush=True)
    stem='.environment_'+uuid.uuid4().hex
    files=[root/(stem+s) for s in ('.dme','_world.dm','_day.dm','_weather.dm','.dmb','.rsc')]
    flags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0
    try:
        world=(root/'code/world.dm').read_text(encoding='utf-8')
        start=world.index('/world/New()'); parent=world.index('\n\t..()',start)
        world=world[:parent]+world[parent:].replace('\n\t..()','',1)
        files[1].write_text(world.replace('/world/New()','/world/proc/unused_environment_startup()',1),encoding='utf-8')
        source=(root/'civ13.dme').read_text(encoding='utf-8').replace('code\\world.dm',files[1].name)
        source='\n'.join(line for line in source.splitlines() if not line.strip().startswith('#include "maps\\'))
        for index,relative in ((2,'code/processes/time_of_day_change.dm'),(3,'code/modules/1713/weather.dm')):
            text=subprocess.check_output(['git','show','9ea42a6c5269d4970672655460ca96a3a7ec07f6:'+relative],cwd=root,text=True) if a.baseline else (root/relative).read_text(encoding='utf-8')
            if index==2:
                text=text.replace('\t\tCHECK_TICK','\t\tenvironment_probe_work()\n\t\tCHECK_TICK')
                if not a.baseline and 'environment_sweep_pause' in text:
                    text=text.replace('\t\tif (environment_sweep_pause','\t\tenvironment_probe_work()\n\t\tif (environment_sweep_pause')
            else:
                text=text.replace('\tfor (var/area/caribbean/A in area_list)\n','\tfor (var/area/caribbean/A in area_list)\n\t\tenvironment_probe_work()\n',1)
            files[index].write_text(text,encoding='utf-8')
            source=source.replace(relative.replace('/','\\'),files[index].name)
        source+='\n#include "tests/environment_sweeps/probe.dm"\n'
        if a.baseline: source='#define ENVIRONMENT_BASELINE\n'+source
        files[0].write_text(source,encoding='utf-8')
        head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
        (out/'tested.patch').write_text(subprocess.check_output(['git','diff','HEAD'],cwd=root,text=True))
        (out/'metadata.json').write_text(json.dumps({'commit':head,'baseline':a.baseline,'size':a.size,'areas':a.areas,'byond':'516.1681'}))
        compiler=a.byond_bin/('dm.exe' if os.name=='nt' else 'DreamMaker')
        daemon=a.byond_bin/('dd.exe' if os.name=='nt' else 'DreamDaemon')
        build=subprocess.run([str(compiler),str(files[0])],cwd=root,capture_output=True,text=True,timeout=90,creationflags=flags)
        output=build.stdout+build.stderr; (out/'compile.log').write_text(output); print(output,flush=True)
        if build.returncode or 'DM compiler version 516.1681' not in output or '0 errors, 0 warnings' not in output: raise RuntimeError('Pinned compilation failed')
        for f in files[4:]: shutil.copy2(f,out/f.name)
        for rel in subprocess.check_output(['git','ls-files','config/names'],cwd=root,text=True).splitlines():
            dest=out/rel; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(root/rel,dest)
        (out/'config/config.txt').write_text('')
        cmd=[str(daemon),str(out/files[4].name)]
        if os.name=='nt': cmd+=['-invisible','-close']
        cmd+=['-safe','-params',f'size={a.size}&areas={a.areas}','-log','runtime.log']
        with (out/'daemon.log').open('w') as log:
            result=subprocess.run(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=240,creationflags=flags)
        runtime=(out/'runtime.log').read_text(errors='replace')
        completion=(out/'result.txt').read_text(encoding='utf-8').strip(); print(completion,flush=True)
        if result.returncode or 'runtime error:' in runtime.lower() or not completion.startswith('PASS:'): raise RuntimeError('Environment probe failed')
        print((out/'metrics.jsonl').read_text(encoding='utf-8'),flush=True)
    finally:
        for f in files: f.unlink(missing_ok=True)

if __name__=='__main__': main()
