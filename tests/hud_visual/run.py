"""Prepare separately; launch only with a parent-issued exact-packet UTC lease."""
import argparse
import datetime as dt
import hashlib
import json
import re
import shutil
import subprocess
import time
from pathlib import Path

from guard_config import BINARIES, LIMITS, digest

BASE = '41e2d02fe1f9130e0987aee0efd2eba0ca7b3bf1'
ROOT = Path(__file__).resolve().parents[2]
BIN = Path('C:/Program Files (x86)/BYOND/bin')

def git(*args):
    return subprocess.check_output(['git', *args], cwd=ROOT, text=True).strip()

def prepare(out):
    if out.exists():
        raise RuntimeError('Fresh packet directory required')
    if git('diff', 'HEAD') or git('diff', '--cached'):
        raise RuntimeError('Commit the reviewed fixture before freezing')
    out.mkdir(parents=True)
    source = (ROOT / 'civ13.dme').read_text()
    world = (ROOT / 'code/world.dm').read_text()
    anchor = world.index('/world/New()')
    parent = world.index('\n\t..()', anchor)
    world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
    world = world.replace('/world/New()', '/world/proc/unused_hud_probe_startup()', 1)
    world_path = ROOT / '.hud_visual_world.dm'
    dme = ROOT / '.hud_visual_fixture.dme'
    if world_path.exists() or dme.exists():
        raise RuntimeError('Preserve existing generated inputs')
    world_path.write_text(world)
    source = source.replace('code\\world.dm', world_path.name)
    source = re.sub(r'^#include\s+"[^"\n]+\.dmm"\s*$', '', source, flags=re.M)
    source += '\n#include "tests/hud_visual/probe.dm"\n'
    dme.write_text(source)
    generated = {str(p.relative_to(ROOT)): digest(p) for p in (dme,world_path)}
    harness = {str(p.relative_to(ROOT)): digest(p) for p in (ROOT/'tests/hud_visual').glob('*.py')}
    production = {}
    for name in ('civ13.dme','code/world.dm','code/_onclick/hud/base_screen_objects.dm',
                 'code/game/mob/living/carbon/human/human_hud.dm','code/game/mob/living/carbon/human/human_life.dm',
                 'code/game/mob/living/carbon/human/human.dm','code/modules/organs/organ.dm',
                 'code/game/mob/living/carbon/human/traits.dm','icons/mob/screen1_full.dmi'):
        actual = (ROOT/name).read_bytes()
        baseline = subprocess.check_output(['git','show',BASE+':'+name],cwd=ROOT)
        # Git checkout can use CRLF; compare normalized source, exact binary assets.
        if actual.replace(b'\r\n',b'\n') != baseline.replace(b'\r\n',b'\n'):
            raise RuntimeError('Changed production input '+name)
        production[name] = digest(ROOT/name)
    for name,expected in BINARIES.items():
        if digest(BIN/name) != expected:
            raise RuntimeError('Unexpected executable '+name)
    (out/'config').mkdir()
    (out/'config/config.txt').write_text('server_name Isolated HUD fixture\n')
    shutil.copytree(ROOT/'config/names',out/'config/names')
    packet = dict(head=git('rev-parse','HEAD'),base=BASE,root=str(ROOT),out=str(out),
                  generated=generated,harness=harness,production=production,
                  probe=digest(ROOT/'tests/hud_visual/probe.dm'),binaries=BINARIES,
                  commands=[[str(BIN/'DreamMaker.exe'),'-max_errors','0',str(dme)],
                            [str(BIN/'DreamDaemon.exe'),'.hud_visual_fixture.dmb','59474','-ip','127.0.0.1','-invisible','-close','-safe','-log','runtime.log']],
                  limits=dict(shared_seconds=120,compile_seconds=75,compile_cpu_seconds=30,
                              runtime_seconds=30,runtime_cpu_seconds=10,cleanup_seconds=10,
                              compile_private_bytes=1024*1024**2,runtime_private_bytes=512*1024**2,
                              watcher_private_bytes=128*1024**2))
    (out/'packet.json').write_text(json.dumps(packet,indent=2)+'\n')
    print(json.dumps(dict(packet=str(out/'packet.json'),sha256=digest(out/'packet.json'),head=packet['head'])))

def execute(out, grant):
    p=json.loads((out/'packet.json').read_text())
    g=json.loads(grant.read_text())
    now=dt.datetime.now(dt.timezone.utc)
    if g['packet_sha256'] != digest(out/'packet.json') or g['head'] != p['head'] or not g['exclusive_blackout_only']:
        raise RuntimeError('Exact parent lease mismatch')
    if not dt.datetime.fromisoformat(g['start_utc']) <= now <= dt.datetime.fromisoformat(g['end_utc']):
        raise RuntimeError('Outside parent UTC launch window')
    if git('rev-parse','HEAD') != p['head'] or git('diff','HEAD'):
        raise RuntimeError('Frozen source changed')
    for group in ('generated','harness','production'):
        for path,expected in p[group].items():
            if digest(ROOT/path) != expected:
                raise RuntimeError('Frozen input changed '+path)
    if digest(ROOT/'tests/hud_visual/probe.dm') != p['probe']:
        raise RuntimeError('Probe changed')
    with (out/'USED').open('x') as f:
        f.write(now.isoformat())
    from windows import Adapter
    a=Adapter()
    report=dict(head=p['head'],packet_sha256=digest(out/'packet.json'),start_utc=now.isoformat(),phases=[])
    start=time.monotonic()
    try:
        a.preflight(LIMITS)
        a.open()
        for index,phase in enumerate(('compile','runtime')):
            if dt.datetime.now(dt.timezone.utc) > dt.datetime.fromisoformat(g['end_utc']):
                raise RuntimeError('Parent launch window expired before phase spawn')
            if phase=='runtime':
                stdout=(out/'compile.stdout.log').read_text(errors='replace')
                stderr=(out/'compile.stderr.log').read_text(errors='replace')
                if '0 errors, 0 warnings' not in stdout+stderr or '516.1681' not in stdout+stderr:
                    raise RuntimeError('Pinned warning-free compile not established')
                for suffix in ('.dmb','.rsc'):
                    shutil.copy2(ROOT/('.hud_visual_fixture'+suffix),out/('.hud_visual_fixture'+suffix))
                # Tighten the same owned Job for the sequential runtime phase.
                import ctypes as c
                from windows import JobLimits
                limits=JobLimits()
                limits.basic.flags=0x2000|0x8|0x100
                limits.basic.active=1
                limits.process_memory=p['limits']['runtime_private_bytes']
                a.check(a.k.SetInformationJobObject(a.job,9,c.byref(limits),c.sizeof(limits)))
            process=a.launch(p['commands'][index], ROOT if index==0 else out, out,phase)
            identity=a.identity(process)
            row=dict(phase=phase,identity=identity,samples=[])
            report['phases'].append(row)
            print(json.dumps(dict(started=phase,identity=identity)),flush=True)
            phase_start=time.monotonic()
            while not a.exited(process):
                sample=a.sample(process)
                sample['elapsed']=time.monotonic()-phase_start
                sockets=a.sockets(process)
                sample['sockets']=sockets
                row['samples'].append(sample)
                if any(s['state']=='listen' and (s['address']!='127.0.0.1' or s['port']!=59474) for s in sockets):
                    raise RuntimeError('Unexpected owned listener')
                if index==1 and (out/'entered.txt').exists() and any(s['state']=='listen' for s in sockets):
                    raise RuntimeError('Port closure not established after fixture entry')
                if (sample['elapsed']>p['limits'][phase+'_seconds'] or sample['cpu_seconds']>p['limits'][phase+'_cpu_seconds'] or
                    sample['private_bytes']>p['limits'][phase+'_private_bytes'] or sample['watcher_private_bytes']>128*1024**2 or
                    time.monotonic()-start>110):
                    raise RuntimeError('Owned resource/shared deadline exceeded')
                time.sleep(.05)
            row['final']=a.finish(process)
            row['elapsed']=time.monotonic()-phase_start
            if (row['final']['exit_code'] or row['final']['active_processes'] or
                row['final']['cpu_seconds']>p['limits'][phase+'_cpu_seconds'] or
                row['elapsed']>p['limits'][phase+'_seconds'] or time.monotonic()-start>110):
                raise RuntimeError('Phase did not exit successfully')
        result=(out/'result.txt').read_text()
        logs='\n'.join(f.read_text(errors='replace') for f in out.glob('*.log'))
        if not result.startswith('PASS ') or any(s in logs for s in ('BUG:','UNEXPECTED','Runtime in','runtime error','Bad ref','FAIL ')):
            raise RuntimeError('Native result or diagnostic failure: '+result)
        report['result']=result
        report['pass']=True
    except BaseException as error:
        report['pass']=False
        report['error']=str(error)
        raise
    finally:
        report['cleanup']=a.cleanup(None,10)
        report['elapsed']=time.monotonic()-start
        (out/'receipt.json').write_text(json.dumps(report,indent=2)+'\n')
        print(json.dumps({k:report[k] for k in ('pass','cleanup','elapsed') if k in report}),flush=True)
        if not report['cleanup']['all_exited']:
            raise RuntimeError('Cleanup unconfirmed')

if __name__=='__main__':
    parser=argparse.ArgumentParser()
    parser.add_argument('--out',type=Path,required=True)
    parser.add_argument('--prepare',action='store_true')
    parser.add_argument('--grant',type=Path)
    args=parser.parse_args()
    if args.prepare:
        prepare(args.out)
    elif args.grant:
        execute(args.out,args.grant)
    else:
        parser.error('Explicit --prepare or parent-issued --grant required')
