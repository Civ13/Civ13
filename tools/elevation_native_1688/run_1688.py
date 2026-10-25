"""Proposed hosted Linux controller. Never run native tools without --reviewed-native.
No production startup, client, live save, remote write, or QEMU/socket workaround.
"""
import argparse, hashlib, json, os, re, resource, signal, subprocess, sys, time
from pathlib import Path
from prepare_1688 import prepare
LIMIT = 2*1024*1024
DIAGNOSTIC = re.compile(r'\bwarning:|\berror:|runtime error|Runtime in|\bFAIL:|\bBUG\b|bad ref|bad loc|segmentation|fatal', re.I)

from owned_process_1688 import run_bounded
EXPECTED_COMMIT = '6abda09ce48cc858c244bfddf69eca69845d44a8'
ARCHIVE_SHA256 = '16278f318cdeb4b77c57868dd7135032fde717ea6226269d22b2a1a50968e7f9'

def read(path):
    if path.stat().st_size >= LIMIT: raise ValueError('Evidence limit reached: '+path.name)
    return path.read_text(encoding='utf-8',errors='strict')

def run(command, work, role, environment, deadline):
    remaining=min(30,deadline-time.monotonic())
    if remaining <= 0: raise ValueError('Aggregate deadline reached')
    try:
        receipt=run_bounded(command,work,work/(role+'.log'),remaining,LIMIT,environment)
    except BaseException as error:
        (work/(role+'-process.json')).write_text(json.dumps({'command':command,'controller_error':str(error),'cleanup_verified':False},indent=2))
        raise
    receipt['command']=command
    (work/(role+'-process.json')).write_text(json.dumps(receipt,indent=2))
    if receipt['exit_code'] or receipt['stop_reason'] or receipt['log_truncated'] or not receipt['cleanup_no_observed_live_descendants'] or not receipt['cleanup_process_group_absent']:
        raise ValueError(role+' failed or cleanup was not established; see receipt')
    return read(work/(role+'.log'))

def verify_binaries(binary, archive):
    import zipfile
    if hashlib.sha256(archive.read_bytes()).hexdigest() != ARCHIVE_SHA256:
        raise ValueError('BYOND archive differs from verified 516.1688 acquisition')
    expected={}
    with zipfile.ZipFile(archive) as z:
        for name in ('DreamMaker','DreamDaemon','libbyond.so','libext.so'):
            data=z.read('byond/bin/'+name)
            expected[name]=hashlib.sha256(data).hexdigest()
            file=binary/name
            if file.is_symlink() or not file.is_file() or hashlib.sha256(file.read_bytes()).hexdigest() != expected[name]:
                raise ValueError('BYOND runtime member differs from pinned archive: '+name)
    return dict(archive_sha256=ARCHIVE_SHA256,member_sha256=expected)

def verify_fixture(output, receipt):
    for name,digest in receipt['generated_sha256'].items():
        p=output/name
        if p.is_symlink() or hashlib.sha256(p.read_bytes()).hexdigest() != digest:
            raise ValueError('Prepared fixture changed: '+name)

def verify(result, logs, runtime):
    if DIAGNOSTIC.search(logs): raise ValueError('Native diagnostic detected')
    if type(result.get('passed')) is not int or result['passed'] != 1 or result.get('version') != '516.1688': raise ValueError('Missing successful pinned result')
    if result.get('checks') != 27 or result.get('constructor_checks') != 1: raise ValueError('Expected oracle counts differ')
    initial=result.get('initial_port')
    if type(initial) is not int or not 1 <= initial <= 65535 or result.get('closed_port') != 0: raise ValueError('Network closure result differs')
    bindings=re.findall(r'World opened on network port ([0-9]+) for address ([^\s]+)\.',runtime)
    if bindings != [(str(initial),'127.0.0.1')]: raise ValueError('Unexpected bind evidence')
    if type(result.get('expected_invalid_snapshot_diagnostics')) is not int or result['expected_invalid_snapshot_diagnostics'] != 1:
        raise ValueError('Expected one phase-scoped invalid snapshot diagnostic')
    lines=runtime.splitlines()
    opened=f'World opened on network port {initial} for address 127.0.0.1.'
    closed='World no longer opened to new users.'
    startup='ELEVATION_PHASE startup-closed'
    begin='ELEVATION_PHASE invalid-snapshot begin'
    end='ELEVATION_PHASE invalid-snapshot end'
    if runtime.count('World opened on network port') != 1 or lines.count(opened) != 1 or lines.count(startup) != 1 or closed not in lines:
        raise ValueError('Unexpected listener or missing startup closure evidence')
    opening,closing,started=lines.index(opened),lines.index(closed),lines.index(startup)
    if not opening < closing < started or lines[opening+1:closing] != ['Welcome BYOND! (5.0 Public Version 516.1688)']:
        raise ValueError('Listener was not immediately closed before fixture activity')
    if lines.count(begin) != 1 or lines.count(end) != 1 or not started < lines.index(begin) < lines.index(end):
        raise ValueError('Invalid snapshot phase markers missing or out of order')
    expected=['World-save preflight rejected: Invalid elevation region bounds on :',
              'Save rejected before clearing the world: Invalid elevation region bounds']
    if lines[lines.index(begin)+1:lines.index(end)] != expected:
        raise ValueError('Missing, extra or mismatched in-phase rejection diagnostics')
    actual=[line for line in lines if line.startswith(('World-save preflight rejected:', 'Save rejected before clearing the world:'))]
    if actual != expected:
        raise ValueError('Out-of-phase rejection diagnostic')

def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--source',required=True,type=Path)
    p.add_argument('--output',required=True,type=Path)
    p.add_argument('--expected-commit',required=True)
    p.add_argument('--byond-bin',type=Path)
    p.add_argument('--byond-archive',type=Path)
    p.add_argument('--reviewed-native',action='store_true')
    a=p.parse_args(); source=a.source.resolve(); output=a.output.resolve()
    if a.expected_commit != EXPECTED_COMMIT: raise ValueError('Only main-reviewed integration commit accepted')
    head=subprocess.check_output(['git','rev-parse','HEAD'],cwd=source,text=True).strip()
    if head != a.expected_commit: raise ValueError('Checkout differs from approved source')
    if subprocess.check_output(['git','status','--porcelain','--untracked-files=no'],cwd=source): raise ValueError('Tracked source changes present')
    receipt=prepare(source,output)
    summary={'head':head,'status':'prepared-only','native_executed':False,'native_compiler_executed':False,'native_daemon_executed':False,'compiler_passed':False,'daemon_passed':False,'adapter':receipt,'controller_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (Path(__file__),Path(__file__).with_name('prepare_1688.py'),Path(__file__).with_name('owned_process_1688.py'))}}
    try:
        if not a.reviewed_native: return
        if sys.platform != 'linux' or a.byond_bin is None or a.byond_archive is None: raise ValueError('Reviewed Linux BYOND directory required')
        binary=a.byond_bin.resolve(strict=True)
        compiler=binary/'DreamMaker'; daemon=binary/'DreamDaemon'
        summary['runtime_identity']=verify_binaries(binary,a.byond_archive.resolve(strict=True))
        for d in ('home','tmp','map_saves'): (output/d).mkdir()
        env={'HOME':str(output/'home'),'TMPDIR':str(output/'tmp'),'LANG':'C','LC_ALL':'C','TZ':'UTC','BYOND_SYSTEM':str(binary.parent),'LD_LIBRARY_PATH':str(binary)}
        deadline=time.monotonic()+90
        verify_fixture(output,receipt)
        summary.update(status='compiler-attempt',native_executed=True,native_compiler_executed=True)
        (output/'controller-result.json').write_text(json.dumps(summary,indent=2))
        log=run([str(compiler),'elevation.dme'],output,'compile',env,deadline)
        if 'DM compiler version 516.1688' not in log or '0 errors, 0 warnings' not in log or DIAGNOSTIC.search(log): raise ValueError('Clean pinned compile required')
        summary.update(compiler_passed=True)
        verify_fixture(output,receipt)
        verify_binaries(binary,a.byond_archive.resolve(strict=True))
        summary.update(status='daemon-attempt',native_daemon_executed=True)
        (output/'controller-result.json').write_text(json.dumps(summary,indent=2))
        log=run([str(daemon),'elevation.dmb','-ip','127.0.0.1','-invisible','-close','-trusted','-nowebclient','-log','runtime.log'],output,'daemon',env,deadline)
        runtime=read(output/'runtime.log')
        result=json.loads(read(output/'elevation-result.json'))
        verify(result,log+'\n'+runtime,runtime)
        verify_fixture(output,receipt)
        verify_binaries(binary,a.byond_archive.resolve(strict=True))
        summary.update(status='passed',daemon_passed=True,result=result)
    except Exception as e:
        summary.update(status='failed',error=str(e)); raise
    finally:
        (output/'controller-result.json').write_text(json.dumps(summary,indent=2))

if __name__=='__main__': main()
