"""Opt-in reviewed hosted-Linux mount fixture. Never called by ordinary CI.

No native launch occurs on import. Windows runtime remains refused. Reuses the
existing retained-leader process-group runner and current archive identity.
"""
import argparse
from datetime import datetime, timedelta, timezone
import importlib.util
import json
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import sys
import time

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


prepare = load('mount_reviewed_prepare', HERE/'prepare.py')
common = load('mount_retained_monitor', ROOT/'tests/movement_save_chunks/human_spatial_run.py')
linux = load('mount_linux_census', ROOT/'tests/nomads_lifecycle/run_variable_probe_linux.py')


def require(ok, message):
    if not ok:
        raise RuntimeError(message)


def write(path, value):
    path.write_text(json.dumps(value, indent=2)+'\n', encoding='utf-8')


def gate(prepared, output, head, manifest_sha, until):
    require(sys.platform == 'linux', 'Windows startup-socket hold unchanged; hosted Linux only')
    require(os.environ.get('GITHUB_ACTIONS') == 'true' and os.environ.get('RUNNER_OS') == 'Linux'
            and os.environ.get('GITHUB_REPOSITORY') == 'Civ13/Civ13'
            and os.environ.get('GITHUB_EVENT_NAME') == 'pull_request',
            'Requires explicitly selected isolated Civ13 hosted Linux job')
    workspace = Path(os.environ['GITHUB_WORKSPACE']).resolve(strict=True)
    temporary = Path(os.environ['RUNNER_TEMP']).resolve(strict=True)
    require(ROOT.resolve() == workspace, 'Wrong source checkout')
    require(prepared.is_relative_to(temporary) and prepared != temporary and prepared.is_dir(), 'Private prepared stage required')
    require(output.is_relative_to(temporary) and output != temporary and not output.exists(), 'New private execution directory required')
    require(prepare.stager.current.legacy.git(ROOT, 'rev-parse', 'HEAD').decode().strip() == head
            and not prepare.stager.current.legacy.git(ROOT, 'status', '--porcelain').strip(), 'Reviewed clean head changed')
    require(until.tzinfo is not None and datetime.now(timezone.utc)+timedelta(seconds=900) <= until,
            'Insufficient remaining reviewed authorization for whole 900-second attempt')
    path = prepared/'mount-native-manifest.json'
    require(re.fullmatch('[0-9a-f]{40}',head) and re.fullmatch('[0-9a-f]{64}',manifest_sha), 'Canonical source/hash required')
    require(path.is_file() and not path.is_symlink() and path.stat().st_size <= 2*1024**2, 'Manifest type/size bound')
    require(common.digest(path) == manifest_sha, 'Reviewed prepared manifest changed')
    manifest = json.loads(path.read_text())
    require(manifest['head'] == head and manifest['fixture'] == 'mount_lifecycle'
            and manifest['target_engine'] == '516.1688' and list(manifest['variants']) == list(prepare.VARIANTS),
            'Wrong source/fixture/variant set')
    return manifest


def verify_inputs(prepared, manifest, generated=()):
    stage = prepared/'stage'
    require(stage.is_dir() and not stage.is_symlink(), 'Private source stage required')
    inventory = common.inventory(stage,total_limit=2*1024**3,max_entries=12000)
    require(set(inventory) == set(manifest['stage_files']) | set(generated), 'Unexpected/missing staged file')
    for name, expected in manifest['stage_files'].items():
        relative=PurePosixPath(name)
        require(not relative.is_absolute() and '..' not in relative.parts, 'Unsafe source path')
        path = stage/name
        require(path.is_file() and not path.is_symlink() and path.stat().st_size == expected['bytes']
                and path.resolve().is_relative_to(stage.resolve()) and common.digest(path) == expected['sha256'], 'Prepared input changed: '+name)


def supervised(command, cwd, phase, seconds, deadline, until, byond, source_bytes=0):
    """Keep legacy's leader unreaped through kill; census before and after reap."""
    started = time.monotonic()
    limit = min(seconds, deadline-started-15,
                (until-datetime.now(timezone.utc)).total_seconds()-15)
    require(limit > 0 and datetime.now(timezone.utc) < until, 'Attempt/authorization expired')
    compile_mode = phase.startswith('compile-')
    memory_monitor, memory = common.monitor_for(cwd, started, deadline, compile_mode,
                                               source_bytes, started+limit)
    trace = dict(events=[], samples=[], errors=[], closed=compile_mode, birth=None,
                 final_group=None, final_native=None, memory=memory)

    def sample(pid, folder):
        require(not trace['errors'], 'Earlier ownership/census error')
        require(datetime.now(timezone.utc) < until, 'Authorization expired')
        current = linux.identity(pid)
        birth = trace['birth']
        require(birth is not None and all(current[k] == birth[k] for k in ('pid','start_ticks','pgrp','session')),
                'Owned process identity changed')
        members = linux.group_members(pid)
        require(len(members) == 1 and members[0]['pid'] == pid, 'Unexpected process-group/session member')
        try:
            sockets = linux.owned_sockets(pid, birth['start_ticks'])
        except (FileNotFoundError, PermissionError) as error:
            exited = common.child_exited_unreaped(pid)
            trace['exit_census'] = dict(error=type(error).__name__, waitid_exit_observed=exited)
            require(exited and trace['closed'], 'Socket census lost before verified closure')
            return
        linux.validate_sockets(sockets, runtime=not compile_mode, closed=trace['closed'])
        if not trace['closed']:
            require(time.monotonic()-started < 5, 'Fixed startup listener closure deadline')
            marker = folder/'port-closed.txt'
            if marker.exists():
                require(marker.is_file() and marker.stat().st_size <= 16 and marker.read_bytes() == b'closed\n',
                        'Invalid closed-entry witness')
                linux.validate_sockets(sockets, runtime=True, closed=True)
                (folder/'port-closed.ack').write_bytes(b'closed\n')
                trace['closed'] = True
        require(len(trace['samples']) < 3000, 'Sample count bound')
        trace['samples'].append(dict(identity=current, members=members, sockets=sockets, closed=trace['closed']))
        watcher=linux.identity(os.getpid())['resident_pages']*os.sysconf('SC_PAGE_SIZE')
        require(watcher <= 128*1024**2, 'Supervisor sampled RSS budget')
        trace['watcher_peak_rss']=max(trace.get('watcher_peak_rss',0),watcher)
        memory_monitor(pid, folder)

    def event(name, value):
        # Never throw from on_event: legacy must enter/finish its own finally and
        # reap the retained child even when a census/identity observation fails.
        trace['events'].append(dict(event=name, value=value))
        try:
            if name == 'spawn':
                birth = linux.identity(value)
                trace['birth'] = birth
                require(birth['pgrp'] == birth['session'] == value, 'Dedicated owned session required')
            elif name in ('group_signal_sent', 'group_already_absent'):
                pid = trace['birth']['pid']
                previous_samples = len(trace['samples'])
                sample(pid, cwd)  # Still unreaped: birth/PID cannot be reused.
                trace['final_socket_census'] = dict(retained_leader=True,
                    rows=trace['samples'][-1]['sockets'] if len(trace['samples']) > previous_samples else None,
                    exit_observation=trace.get('exit_census'), closed=trace['closed'])
            elif name == 'wait':
                require(value == 0, 'Owned child exit failed')
            elif name in ('group_signal_error','wait_error'):
                trace['errors'].append(name+': '+str(value))
        except Exception as error:
            trace['errors'].append(str(error))

    environment = dict(PATH='/usr/bin:/bin', HOME=str(cwd), TMPDIR=str(cwd),
                       LANG='C', LC_ALL='C', LD_LIBRARY_PATH=str(byond))
    result = None
    try:
        require(not linux.native_census(), 'Another native engine process is active; do not evict it')
        result = common.legacy.run_process(command, cwd, phase, limit,
            preexec_fn=common.bounded_child, monitor=sample, env=environment,
            retain_leader=True, on_event=event)
        require(trace['birth'] is not None and trace['closed'], 'Birth/closed-entry acknowledgement missing')
        require('final_socket_census' in trace, 'Missing retained final socket observation')
        require(memory['count'] > 0, 'No RSS observation')
        require(not trace['errors'], 'Supervision/census error: '+str(trace['errors']))
        return result
    except Exception as error:
        trace['error'] = str(error)
        raise
    finally:
        try:
            birth = trace['birth']
            trace['final_group'] = linux.group_members(birth['pid']) if birth else None
            trace['final_native'] = linux.native_census()
            require(trace['final_group'] == [] and trace['final_native'] == [], 'Final process/session census not empty')
        except Exception as cleanup_error:
            trace['errors'].append('final: '+str(cleanup_error))
        trace['process'] = result
        write(cwd/(phase+'-supervision.json'), trace)
        require(not trace['errors'], 'Retained cleanup/final census failed: '+str(trace['errors']))


def run(prepared, output, byond, archive, head, manifest_sha, until):
    attempt_started = time.monotonic()
    manifest = gate(prepared, output, head, manifest_sha, until)
    workspace = ROOT.resolve()
    require(byond == workspace/'BYOND/byond/bin' and archive == workspace/'BYOND/pinned.zip', 'Existing pinned CI engine paths required')
    require(os.environ.get('BYOND_MAJOR') == '516' and os.environ.get('BYOND_MINOR') == '1688', 'CI engine pin mismatch')
    verify_inputs(prepared, manifest)
    require(shutil.disk_usage(output.parent).free >= 6*1024**3, 'Insufficient private evidence disk budget')
    runtime = linux.current_runtime(byond, archive)  # Archive/install hash verifier, no launch.
    output.mkdir()
    deadline = attempt_started+900
    report = dict(head=head, manifest_sha256=manifest_sha, accepted=False, phases=[],
                  scope='Hosted Linux sampled process/socket closure;not an egress sandbox or Windows acceptance')
    compiled_bytes = 0
    generated=set()
    stage = prepared/'stage'
    try:
        for variant, data in manifest['variants'].items():
            report['active_variant']=variant
            report['active_phase']='compile'
            write(output/'mount-run.json',report)
            require(datetime.now(timezone.utc) < until and time.monotonic() < deadline, 'Attempt expired')
            verify_inputs(prepared, manifest,generated)
            dme = prepared/data['dme']
            phase = 'compile-'+variant
            runtime.before_launch(phase, output)
            row = supervised([str(byond/'DreamMaker'), '-max_errors','0',str(dme)], stage, phase,120,
                deadline,until,byond, sum(x['bytes'] for x in manifest['stage_files'].values())+compiled_bytes)
            generated.update((dme.with_suffix('.dmb').relative_to(stage).as_posix(),
                              dme.with_suffix('.rsc').relative_to(stage).as_posix(),
                              phase+'-stdout.log',phase+'-stderr.log',phase+'-supervision.json'))
            verify_inputs(prepared,manifest,generated)
            log = prepare.stager.current.read_bounded(stage/(phase+'-stdout.log'))
            log += prepare.stager.current.read_bounded(stage/(phase+'-stderr.log'))
            runtime.validate_compile(row['returncode'],log,dme.with_suffix('.dmb').name)
            work = output/('runtime-'+variant)
            work.mkdir()
            assets = {}
            for extension in ('.dmb','.rsc'):
                source = dme.with_suffix(extension)
                require(source.is_file() and 0 < source.stat().st_size <= common.MAX_BYTES, 'Missing/oversized compiler artifact')
                assets[source.name] = dict(bytes=source.stat().st_size,sha256=common.digest(source))
                compiled_bytes += source.stat().st_size
                shutil.copy2(source,work/source.name)
            shutil.copytree(stage/'config',work/'config')
            require(all(common.digest(work/name)==value['sha256'] for name,value in assets.items()), 'Copied native artifact changed')
            linux.vacant_port()  # Refuse an occupied fixed port; never evict/fallback.
            runtime.before_launch('runtime-'+variant,output)
            report['active_phase']='runtime'
            write(output/'mount-run.json',report)
            argv = [str(byond/'DreamDaemon'),str(work/dme.with_suffix('.dmb').name),str(linux.PORT),
                    '-ip','127.0.0.1','-nowebclient','-trusted','-close','-params',
                    'tested_commit='+head+';fixture_variant='+variant,'-log','runtime.log']
            result = supervised(argv,work,'runtime-'+variant,30,deadline,until,byond)
            receipt = common.json_read(work/'receipt.json')
            checked = prepare.validate_receipt(receipt,head,variant)
            expected = ('FAIL '+data['expected_failure'] if data['expected_failure'] else 'PASS')+'\n'
            require((work/'result.txt').read_text() == expected, 'Wrong native result marker')
            report['phases'].append(dict(variant=variant,compiler=row,runtime=result,artifacts=assets,receipt=checked))
            write(output/'mount-run.json',report)
        report['accepted'] = True
        return report
    except Exception as error:
        report['error'] = str(error)
        raise
    finally:
        try:
            report['final_native'] = linux.native_census()
            require(report['final_native'] == [], 'Final native census not empty')
        except Exception as final_error:
            report['final_error'] = str(final_error)
            report['accepted'] = False
        write(output/'mount-run.json',report)
        require('final_error' not in report, 'Final native census failed; original='+str(report.get('error')))


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    for name in ('prepared','output','byond-bin','archive'):
        parser.add_argument('--'+name,required=True,type=Path)
    for name in ('expected-head','manifest-sha256','authorized-until'):
        parser.add_argument('--'+name,required=True)
    args = parser.parse_args()
    run(args.prepared.resolve(),args.output.resolve(),args.byond_bin.resolve(),args.archive.resolve(),
        args.expected_head,args.manifest_sha256,datetime.fromisoformat(args.authorized_until.replace('Z','+00:00')))
