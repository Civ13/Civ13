"""Measure actual production daylight/weather sweeps in an isolated BYOND world."""
import argparse, json, os, shutil, subprocess, tempfile, uuid
from pathlib import Path

def main():
    p=argparse.ArgumentParser()
    p.add_argument('--byond-bin',required=True,type=Path)
    p.add_argument('--baseline',action='store_true')
    p.add_argument('--compare',type=Path)
    p.add_argument('--output-metadata',type=Path)
    p.add_argument('--compare-metadata',type=Path)
    p.add_argument('--negative-control',choices=('yield','overlap'))
    p.add_argument('--size',type=int,choices=(128,256,384),default=256)
    p.add_argument('--areas',type=int,choices=(256,4096),default=4096)
    a=p.parse_args(); root=Path(__file__).resolve().parents[2]
    if a.baseline and (a.compare or a.compare_metadata or a.negative_control):
        p.error('Baseline cannot compare or mutate current source')
    if a.compare_metadata:
        previous=json.loads(a.compare_metadata.read_text(encoding='utf-8'))
        if previous['size']!=a.size or previous['areas']!=a.areas or not previous['baseline']:
            p.error('Baseline dimensions or mode differ')
        a.compare=Path(previous['evidence'])/'weather_states.jsonl'
    out=Path(tempfile.mkdtemp(prefix='civ13-environment-')); print(f'Evidence: {out}',flush=True)
    stem='.environment_'+uuid.uuid4().hex
    files=[root/(stem+s) for s in ('.dme','_world.dm','_day.dm','_weather.dm','.dmb','.rsc','_globals.dm','_helpers.dm','_lighting.dm')]
    flags=subprocess.CREATE_NO_WINDOW if os.name=='nt' else 0
    try:
        world=(root/'code/world.dm').read_text(encoding='utf-8')
        start=world.index('/world/New()'); parent=world.index('\n\t..()',start)
        world=world[:parent]+world[parent:].replace('\n\t..()','',1)
        files[1].write_text(world.replace('/world/New()','/world/proc/unused_environment_startup()',1),encoding='utf-8')
        source=(root/'civ13.dme').read_text(encoding='utf-8').replace('code\\world.dm',files[1].name)
        source='\n'.join(line for line in source.splitlines() if not line.strip().startswith('#include "maps\\'))
        globals_source=(root/'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        target='gvars_datum_in_built_vars = exclude_these.vars + list('
        if globals_source.count(target) not in (0,1): raise RuntimeError('Global adapter target changed')
        if target not in globals_source and 'for(var/variable_name in exclude_these.vars)' not in globals_source:
            raise RuntimeError('Fixed global name snapshot anchor changed')
        globals_source=globals_source.replace(target,'gvars_datum_in_built_vars = list()\n\tfor(var/key in exclude_these.vars)\n\t\tgvars_datum_in_built_vars += key\n\tgvars_datum_in_built_vars += list(')
        files[6].write_text(globals_source,encoding='utf-8')
        source=source.replace('code\\controllers\\mc\\globals.dm',files[6].name)
        if a.negative_control=='yield':
            helper=(root/'code/_helpers/game.dm').read_text(encoding='utf-8')
            target='\t\tsleep(world.tick_lag)\n\t\treturn TRUE'
            if helper.count(target)!=1: raise RuntimeError('Yield mutation target changed')
            files[7].write_text(helper.replace(target,'\t\treturn TRUE'),encoding='utf-8')
            source=source.replace('code\\_helpers\\game.dm',files[7].name)
        for index,relative in ((2,'code/processes/time_of_day_change.dm'),(3,'code/modules/1713/weather.dm'),(8,'code/modules/lighting/lighting_system.dm')):
            text=subprocess.check_output(['git','show','9ea42a6c5269d4970672655460ca96a3a7ec07f6:'+relative],cwd=root,text=True) if a.baseline else (root/relative).read_text(encoding='utf-8')
            if index==2:
                if a.baseline:
                    text=text.replace('\tvar/O_time_of_day', '\tenvironment_lighting_enter()\n\tvar/O_time_of_day',1)
                    text+='\n\tenvironment_lighting_active--\n'
                else:
                    if a.negative_control=='overlap':
                        target='\tif (updating_lighting)\n\t\treturn'
                        if text.count(target)!=1: raise RuntimeError('Overlap mutation target changed')
                        text=text.replace(target,'',1)
                    text=text.replace('\tupdating_lighting = TRUE','\tupdating_lighting = TRUE\n\tenvironment_lighting_enter()',1)
                    text=text.replace('\t\tupdating_lighting = FALSE','\t\tenvironment_lighting_active--\n\t\tupdating_lighting = FALSE')
                    text=text.replace('\n\tupdating_lighting = FALSE','\n\tenvironment_lighting_active--\n\tupdating_lighting = FALSE')
                text=text.replace('\t\tCHECK_TICK','\t\tenvironment_probe_work()\n\t\tCHECK_TICK')
                if not a.baseline and 'environment_sweep_pause' in text:
                    text=text.replace('\t\tif (environment_sweep_pause','\t\tenvironment_probe_work()\n\t\tif (environment_sweep_pause')
            elif index==3:
                if a.baseline:
                    text=text.replace('\tfor (var/area/caribbean/A in area_list)', '\tenvironment_weather_enter()\n\tfor (var/area/caribbean/A in area_list)',1)
                    text=text.replace('\n/*\n\tif (old_weather', '\n\tenvironment_weather_active--\n/*\n\tif (old_weather',1)
                else:
                    text=text.replace('\tenvironment_weather_running = TRUE','\tenvironment_weather_running = TRUE\n\tenvironment_weather_enter()',1)
                    text=text.replace('\t\tenvironment_weather_running = FALSE','\t\tenvironment_weather_active--\n\t\tenvironment_weather_running = FALSE')
                    text=text.replace('\n\tenvironment_weather_running = FALSE','\n\tenvironment_weather_active--\n\tenvironment_weather_running = FALSE')
                if a.baseline:
                    text=text.replace('\tfor (var/area/caribbean/A in area_list)\n','\tfor (var/area/caribbean/A in area_list)\n\t\tenvironment_probe_work()\n',1)
                else:
                    text=text.replace('\t\t\tfor (var/area/caribbean/A in area_list)\n','\t\t\tfor (var/area/caribbean/A in area_list)\n\t\t\t\tenvironment_probe_work()\n',1)
            files[index].write_text(text,encoding='utf-8')
            source=source.replace(relative.replace('/','\\'),files[index].name)
        source+='\n#include "tests/environment_sweeps/probe.dm"\n'
        if a.baseline: source='#define ENVIRONMENT_BASELINE\n'+source
        files[0].write_text(source,encoding='utf-8')
        head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=root,text=True).strip()
        (out/'tested.patch').write_text(subprocess.check_output(['git','diff','HEAD'],cwd=root,text=True))
        metadata={'commit':head,'baseline':a.baseline,'size':a.size,'areas':a.areas,'byond':'516.1681','evidence':str(out),'baseline_commit':'9ea42a6c5269d4970672655460ca96a3a7ec07f6' if a.baseline else None}
        (out/'metadata.json').write_text(json.dumps(metadata),encoding='utf-8')
        compiler=a.byond_bin/('dm.exe' if os.name=='nt' else 'DreamMaker')
        daemon=a.byond_bin/('dd.exe' if os.name=='nt' else 'DreamDaemon')
        build=subprocess.run([str(compiler),str(files[0])],cwd=root,capture_output=True,text=True,timeout=90,creationflags=flags)
        output=build.stdout+build.stderr; (out/'compile.log').write_text(output); print(output,flush=True)
        if build.returncode or 'DM compiler version 516.1681' not in output or '0 errors, 0 warnings' not in output: raise RuntimeError('Pinned compilation failed')
        for f in files[4:6]: shutil.copy2(f,out/f.name)
        for rel in subprocess.check_output(['git','ls-files','config/names'],cwd=root,text=True).splitlines():
            dest=out/rel; dest.parent.mkdir(parents=True,exist_ok=True); shutil.copy2(root/rel,dest)
        (out/'config/config.txt').write_text('')
        cmd=[str(daemon),str(out/files[4].name)]
        if os.name=='nt': cmd+=['-invisible','-close']
        cmd+=['-safe','-params',f'size={a.size}&areas={a.areas}','-log','runtime.log']
        with (out/'daemon.log').open('w') as log:
            result=subprocess.run(cmd,cwd=out,stdout=log,stderr=subprocess.STDOUT,timeout=600,creationflags=flags)
        runtime=(out/'runtime.log').read_text(errors='replace')
        completion=(out/'result.txt').read_text(encoding='utf-8').strip(); print(completion,flush=True)
        if result.returncode or 'BUG:' in runtime or 'runtime error:' in runtime.lower(): raise RuntimeError('Environment runtime failed')
        if a.negative_control:
            expected='FAIL: one daylight worker' if a.negative_control=='overlap' else 'FAIL: bounded sweep batch'
            if completion!=expected: raise RuntimeError('Mutation did not fail the expected contract')
            print(f'PASS: {a.negative_control} mutation detected',flush=True)
            return
        if not completion.startswith('PASS:'): raise RuntimeError('Environment assertions failed')
        if a.compare:
            expected=[json.loads(row) for row in a.compare.read_text().splitlines()]
            actual=[json.loads(row) for row in (out/'weather_states.jsonl').read_text().splitlines()]
            if actual!=expected: raise RuntimeError('Weather state differs from production baseline')
            print('PASS: weather state digests match baseline',flush=True)
        if a.output_metadata:
            a.output_metadata.write_text(json.dumps(metadata),encoding='utf-8')
        rows=[json.loads(row) for row in (out/'metrics.jsonl').read_text().splitlines()]
        lights=[row for row in rows if row['phase'].startswith('lighting')]
        print(json.dumps({'lighting':lights,'weather_phases':len(rows)-len(lights),'max_weather_tick_percent':max(row['peak_tick_percent'] for row in rows if row['phase'].startswith('weather'))}),flush=True)
    finally:
        for f in files: f.unlink(missing_ok=True)

if __name__=='__main__': main()
