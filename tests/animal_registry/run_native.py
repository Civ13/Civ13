"""Isolated production registry hooks, Linux BYOND 516.1681. Never starts Civ13."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import signal
import subprocess
import sys
import time

from test_source_contract import HOOKS, ROOT, SOURCE, SUITES, violations

VERSION = '516.1681'
LIMIT = 2 * 1024 * 1024
DIAGNOSTIC = re.compile(r'\bwarning:|\berror:|runtime error|\bRUNTIME\b|\bBUG\b|bad ref|bad loc|cannot read|cannot execute|segmentation|fatal|infinite loop|exception', re.I)


def extract(source, hooks=HOOKS):
    if violations(source, hooks):
        raise ValueError('Production hook contract changed')
    result = {}
    for hook in hooks:
        header = '/mob/living/simple_animal/' + hook + '()'
        matches = re.findall(r'^' + re.escape(header) + r'\n(.*?)(?=^/|\Z)', source, re.M | re.S)
        if len(matches) != 1:
            raise ValueError('Hook extraction is ambiguous: ' + hook)
        result[hook] = header + '\n' + matches[0]
    return result


def case_names(hooks=HOOKS):
    result = [h + ':' + s for h in hooks for s in ('registered', 'repeated', 'unregistered')]
    result += [h.rsplit('/', 1)[0] + ':death-then-Destroy' for h in hooks
               if h.endswith('/death') and h.rsplit('/', 1)[0] + '/Destroy' in hooks]
    return result


def expected_failures(control, hooks=HOOKS):
    if control is None:
        return []
    names = [control + ':' + s for s in ('registered', 'repeated', 'unregistered')]
    kind = control.rsplit('/', 1)[0]
    if kind + '/death' in hooks and kind + '/Destroy' in hooks:
        names.append(kind + ':death-then-Destroy')
    return sorted(names)


def prepare(source, control=None, hooks=HOOKS):
    bodies = extract(source, hooks)
    if control is not None:
        if control not in hooks:
            raise ValueError('Unknown exact hook control')
        before = hooks[control] + ' -= src'
        if bodies[control].count(before) != 1:
            raise ValueError('Mutation anchor changed')
        bodies[control] = bodies[control].replace(before, hooks[control] + ' &= src', 1)
    declarations = '\n'.join('var/list/' + r + ' = list()' for r in sorted(set(hooks.values())))
    calls = []
    for hook, registry in hooks.items():
        kind, method = hook.rsplit('/', 1)
        calls.append(f'\trun_hook(/mob/living/simple_animal/{kind}, "{method}", "{registry}", "{hook}")')
        if method == 'death' and kind + '/Destroy' in hooks:
            calls.append(f'\trun_pair(/mob/living/simple_animal/{kind}, "{registry}", "{kind}:death-then-Destroy")')
    accessors = '/proc/get_registry(registry_name)\n\tswitch(registry_name)\n'
    for registry in sorted(set(hooks.values())):
        accessors += f'\t\tif("{registry}") return {registry}\n'
    accessors += '/proc/set_registry(registry_name, list/value)\n\tswitch(registry_name)\n'
    for registry in sorted(set(hooks.values())):
        accessors += f'\t\tif("{registry}") {registry} = value\n'
    fixture = r'''
var/list/results = list()
var/active_registry_name
var/list/parent_calls = list()
var/parent_order_ok = 1
/mob/living/simple_animal/proc/death()
	parent_calls += "death"
	if(src in get_registry(active_registry_name)) parent_order_ok = 0
/mob/living/simple_animal/proc/Destroy()
	parent_calls += "Destroy"
	if(src in get_registry(active_registry_name)) parent_order_ok = 0
/client/New()
	del(src)
	return
/world/Topic()
	return null
/world
	hub = ""
	visibility = 0
	maxx = 1
	maxy = 1
	maxz = 1
/world/OpenPort(port)
	if(port == "none") return ..()
	return 0
/proc/reset_case(registry_name)
	set_registry(registry_name, list())
	active_registry_name = registry_name
	parent_calls = list()
	parent_order_ok = 1
/proc/record_case(label, registry_name, mob/owner, mob/peer_a, mob/peer_b, list/expected_calls)
	var/list/registry = get_registry(registry_name)
	var/ok = registry.len == 2 && !(owner in registry) && (peer_a in registry) && (peer_b in registry) && parent_order_ok
	if(parent_calls.len != expected_calls.len) ok = 0
	else
		for(var/i = 1 to expected_calls.len)
			if(parent_calls[i] != expected_calls[i]) ok = 0
	results += list(list("case" = label, "passed" = ok ? 1 : 0))
/proc/run_hook(kind, method, registry_name, label)
	var/mob/owner = new kind
	var/mob/peer_a = new /mob
	var/mob/peer_b = new /mob
	reset_case(registry_name)
	set_registry(registry_name, list(peer_a, owner, peer_b))
	call(owner, method)()
	record_case("[label]:registered", registry_name, owner, peer_a, peer_b, list(method))
	call(owner, method)()
	record_case("[label]:repeated", registry_name, owner, peer_a, peer_b, list(method, method))
	reset_case(registry_name)
	set_registry(registry_name, list(peer_a, peer_b))
	call(owner, method)()
	record_case("[label]:unregistered", registry_name, owner, peer_a, peer_b, list(method))
	set_registry(registry_name, list())
	del(owner)
	del(peer_a)
	del(peer_b)
/proc/run_pair(kind, registry_name, label)
	var/mob/owner = new kind
	var/mob/peer_a = new /mob
	var/mob/peer_b = new /mob
	reset_case(registry_name)
	set_registry(registry_name, list(peer_a, owner, peer_b))
	call(owner, "death")()
	call(owner, "Destroy")()
	record_case(label, registry_name, owner, peer_a, peer_b, list("death", "Destroy"))
	set_registry(registry_name, list())
	del(owner)
	del(peer_a)
	del(peer_b)
/world/New()
	..()
	var/initial_port = port
	OpenPort("none")
	var/reopen = OpenPort(0)
	if(initial_port <= 0 || port != 0 || reopen != 0)
		world.log << "BUG network contract initial=[initial_port] current=[port] reopen=[reopen]"
		del(world)
		return
	if(byond_version != 516 || byond_build != 1681)
		world.log << "BUG runtime version actual=[byond_version].[byond_build]"
		del(world)
		return
CALLS
	text2file(json_encode(list("version" = "516.1681", "initial_port" = initial_port, "closed_port" = port, "reopen" = reopen, "cases" = results)), "result.json")
	world.log << "DONE registry fixture"
	del(world)
'''.replace('CALLS', '\n'.join(calls))
    return {'probe.dme': '#include "hooks.dm"\n#include "fixture.dm"\n',
            'hooks.dm': declarations + '\n\n' + '\n'.join(bodies.values()),
            'fixture.dm': accessors + fixture}


def limits():
    import resource
    resource.setrlimit(resource.RLIMIT_CPU, (20, 20))
    resource.setrlimit(resource.RLIMIT_AS, (512 * 1024**2, 512 * 1024**2))
    resource.setrlimit(resource.RLIMIT_FSIZE, (LIMIT, LIMIT))
    resource.setrlimit(resource.RLIMIT_CORE, (0, 0))


def run(command, work, role, deadline):
    remaining = min(30, deadline - time.monotonic())
    if remaining <= 0:
        raise RuntimeError('Aggregate deadline expired')
    child = None
    receipt = {'command': command, 'reaped': False}
    try:
        with (work / (role + '.stdout')).open('wb') as out, (work / (role + '.stderr')).open('wb') as err:
            child = subprocess.Popen(command, cwd=work, stdin=subprocess.DEVNULL, stdout=out, stderr=err,
                                     start_new_session=True, preexec_fn=limits)
            child.wait(timeout=remaining)
            if child.returncode:
                raise RuntimeError(role + ' failed with exit ' + str(child.returncode))
    finally:
        if child is not None:
            try:
                os.killpg(child.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            child.wait()
            receipt.update(reaped=True, returncode=child.returncode)
        (work / (role + '-process.json')).write_text(json.dumps(receipt, indent=2))
    return read_bounded(work / (role + '.stdout')) + '\n' + read_bounded(work / (role + '.stderr'))


def read_bounded(path):
    if path.stat().st_size >= LIMIT:
        raise ValueError('Output reached safety limit: ' + path.name)
    return path.read_text(encoding='utf-8', errors='strict')


def verify(result, log, control=None, hooks=HOOKS, runtime_log=None):
    canonical = log if runtime_log is None else runtime_log
    if DIAGNOSTIC.search(log) or canonical.count('DONE registry fixture') != 1:
        raise ValueError('Runtime diagnostics or incomplete/duplicate completion')
    # BYOND opens its startup listener before world/New; require the engine's
    # loopback bind record, then the immediate closure and refused reopen.
    canonical = runtime_log if runtime_log is not None else log
    bindings = re.findall(r'World opened on network port ([0-9]+) for address ([^\s]+)\.', canonical)
    initial = result.get('initial_port')
    if (type(initial) is not int or not 1 <= initial <= 65535
            or bindings != [(str(initial), '127.0.0.1')]
            or canonical.count('World no longer opened to new users.') != 1
            or not canonical.index('World opened on network port') < canonical.index('World no longer opened to new users.') < canonical.index('DONE registry fixture')):
        raise ValueError('Expected one loopback startup binding followed by closure')
    if any(address != '127.0.0.1' for _, address in re.findall(
            r'World opened on network port ([0-9]+) for address ([^\s]+)\.', log)):
        raise ValueError('Non-loopback binding in output')
    if result.get('version') != VERSION or any(result.get(k) != 0 for k in ('closed_port', 'reopen')):
        raise ValueError('Runtime version/network contract missing')
    rows = result.get('cases')
    if not isinstance(rows, list) or sorted(r.get('case', '') for r in rows) != sorted(case_names(hooks)):
        raise ValueError('Missing, duplicate, or unexpected cases')
    if any(type(r.get('passed')) is not int or r['passed'] not in (0, 1) for r in rows):
        raise ValueError('Invalid verdict type')
    failures = sorted(r['case'] for r in rows if not r['passed'])
    if failures != expected_failures(control, hooks):
        raise ValueError('Unexpected failures or surviving mutation: ' + repr(failures))


def execute(args, runner=run):
    if not args.prepare_only and sys.platform != 'linux':
        raise ValueError('Native execution supports Linux only')
    output = args.output.resolve()
    output.mkdir(parents=True, exist_ok=False)
    source_path, hooks = SUITES[args.suite]
    if args.negative_control is not None and args.negative_control not in hooks:
        raise ValueError('Control is not part of the selected suite')
    source = (ROOT / source_path).read_text()
    modes = [None, *hooks] if args.all_controls else [args.negative_control]
    summary = {'status': 'incomplete', 'native_execution': False, 'version': VERSION,
               'suite': args.suite, 'source': source_path,
               'source_sha256': hashlib.sha256(source.encode()).hexdigest(), 'modes': {}}
    deadline = time.monotonic() + 600
    try:
        if not args.prepare_only:
            binary = args.byond_bin.resolve(strict=True)
            compiler, daemon = binary / 'DreamMaker', binary / 'DreamDaemon'
            summary['binary_sha256'] = {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in (compiler, daemon)}
        for index, control in enumerate(modes):
            work = output / ('baseline' if control is None else 'control-' + str(index))
            work.mkdir()
            sources = prepare(source, control, hooks)
            for name, content in sources.items():
                (work / name).write_text(content, newline='\n')
            mode = {'control': control, 'native_execution': False, 'status': 'prepared',
                    'source_sha256': {n: hashlib.sha256(s.encode()).hexdigest() for n, s in sources.items()}}
            summary['modes'][work.name] = mode
            if args.prepare_only:
                continue
            log = runner([str(compiler), '-max_errors', '0', 'probe.dme'], work, 'compile', deadline)
            if not re.search(r'DM compiler version 516\.1681\b', log) or '0 errors, 0 warnings' not in log or DIAGNOSTIC.search(log):
                raise ValueError('Pinned clean compilation required')
            summary['native_execution'] = mode['native_execution'] = True
            log = runner([str(daemon), 'probe.dmb', '-ip', '127.0.0.1', '-invisible', '-close', '-trusted', '-nowebclient', '-log', 'runtime.log'], work, 'daemon', deadline)
            runtime_log = read_bounded(work / 'runtime.log')
            log += '\n' + runtime_log
            result = json.loads(read_bounded(work / 'result.json'))
            verify(result, log, control, hooks, runtime_log=runtime_log)
            mode.update(status='passed', result=result)
            print(json.dumps(dict(control=control, status='passed', cases=len(result['cases']),
                                  expected_failures=expected_failures(control, hooks),
                                  source_sha256=summary['source_sha256'],
                                  generated_sha256=mode['source_sha256'],
                                  binary_sha256=summary['binary_sha256'])), flush=True)
        summary['status'] = 'prepared-only' if args.prepare_only else 'passed'
    except Exception:
        # Preserve bounded actual engine evidence in CI even if no result was written.
        for path in sorted(output.glob('*/*')):
            if path.name in ('compile.stdout', 'compile.stderr', 'daemon.stdout', 'daemon.stderr', 'runtime.log'):
                try:
                    print('ENGINE EVIDENCE ' + str(path.relative_to(output)), flush=True)
                    print(read_bounded(path)[-16384:], flush=True)
                except (OSError, ValueError):
                    print('Engine output unavailable or exceeded its safety limit', flush=True)
        raise
    finally:
        (output / 'summary.json').write_text(json.dumps(summary, indent=2))
    return summary


def main():
    p = argparse.ArgumentParser(description=__doc__)
    p.add_argument('--byond-bin', type=Path)
    p.add_argument('--output', type=Path, required=True)
    p.add_argument('--prepare-only', action='store_true')
    p.add_argument('--suite', choices=list(SUITES), default='farm')
    modes = p.add_mutually_exclusive_group()
    modes.add_argument('--negative-control', choices=sorted({h for _, hooks in SUITES.values() for h in hooks}))
    modes.add_argument('--all-controls', action='store_true')
    args = p.parse_args()
    if not args.prepare_only and args.byond_bin is None:
        p.error('--byond-bin is required for native execution')
    summary = execute(args)
    print(summary['status'] + ': isolated registry hooks; not whole-game or connected-client acceptance')


if __name__ == '__main__':
    main()
