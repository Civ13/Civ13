"""AI characters for the launcher (shard_group.py agents): the autopilot watchers and runs on this host.

A watcher (tools/agent-control/autopilot.py --watch) plays every character an admin spawns for its agent,
one autopilot run per character, each logging to <log dir>/<name>-<ref>.log. This module finds them by
process command line, reads their logs, stops a hung run (the watcher plays the character again) and
restarts a watcher from the watcher.json it wrote when it started. Never reads or writes agent tokens.
"""

import json
import os
import re
import shlex
import signal
import subprocess
import sys
import time
from pathlib import Path

TAIL_LINES = 40
STALL_SECONDS = 600  # a run whose log has not changed for this long is shown as stalled
STOP_WAIT = 60  # seconds a watcher may take to stop its runs after its pause file appears
REF = re.compile(r'^\[0x[0-9a-fA-F]{1,12}\]$')
NEEDS = re.compile(r'NEEDS[^:]*: ([^|)]*)')
WATCH_RECORD = 'watcher.json'
WATCH_ENV = ('CIV13_AGENT_NAME', 'CIV13_AGENT_TOKEN_FILE', 'CIV13_HOST', 'CIV13_PORT', 'PYTHONDONTWRITEBYTECODE')


def windows_processes():
    """Every python process as {pid, ppid, cmd, started} (Windows CIM; empty elsewhere)."""
    if os.name != 'nt':
        return []
    script = ("Get-CimInstance Win32_Process -Filter \"Name like 'python%'\" | "
              "Select-Object ProcessId,ParentProcessId,CommandLine,@{n='Started';e={$_.CreationDate.ToUniversalTime().ToString('o')}} | "
              "ConvertTo-Json -Compress")
    try:
        out = subprocess.run(['powershell', '-NoProfile', '-NonInteractive', '-Command', script], capture_output=True,
                             text=True, timeout=30, creationflags=getattr(subprocess, 'CREATE_NO_WINDOW', 0)).stdout
        rows = json.loads(out or '[]')
    except (OSError, ValueError, subprocess.SubprocessError):
        return []
    if isinstance(rows, dict):
        rows = [rows]
    return [{'pid': r.get('ProcessId'), 'ppid': r.get('ParentProcessId'), 'cmd': r.get('CommandLine') or '',
             'started': r.get('Started') or ''} for r in rows if isinstance(r, dict) and isinstance(r.get('ProcessId'), int)]


def split_command(cmd):
    try:
        return shlex.split(cmd, posix=False) if os.name == 'nt' else shlex.split(cmd)
    except ValueError:
        return cmd.split()


def _flag(parts, name):
    for index, part in enumerate(parts):
        if part == name and index + 1 < len(parts):
            return parts[index + 1].strip('"')
        if part.startswith(name + '='):
            return part.split('=', 1)[1].strip('"')
    return None


def is_autopilot(cmd):
    return 'autopilot.py' in cmd.replace('\\', '/')


def classify(processes):
    """(watchers, runs) among the processes: watchers by --watch, runs by --character."""
    watchers, runs = [], []
    for proc in processes:
        cmd = proc.get('cmd') or ''
        if not is_autopilot(cmd):
            continue
        parts = split_command(cmd)
        if '--watch' in parts:
            script = next((p.strip('"') for p in parts if p.strip('"').endswith('autopilot.py')), '')
            default = Path(script).resolve().parents[2] / 'data' / 'agent-control' if script else None
            log_dir = _flag(parts, '--log-dir') or (str(default) if default else '')
            watchers.append(dict(proc, log_dir=log_dir))
        elif _flag(parts, '--character'):
            runs.append(dict(proc, character=_flag(parts, '--character')))
    return watchers, runs


def tail(path, lines=TAIL_LINES):
    try:
        with open(path, 'rb') as handle:
            handle.seek(0, os.SEEK_END)
            size = handle.tell()
            handle.seek(max(0, size - 64 * 1024))
            text = handle.read().decode('utf-8', errors='replace')
    except OSError:
        return []
    return text.splitlines()[-lines:]


def run_log(log_dir, character):
    """The run's log in the watcher's folder: <name>-<ref without brackets or punctuation>.log, newest first."""
    if not log_dir or not character:
        return None
    key = re.sub(r'[^A-Za-z0-9]+', '', character)
    try:
        found = [p for p in Path(log_dir).glob('*-%s.log' % key) if p.is_file()]
    except OSError:
        return None
    return max(found, key=lambda p: p.stat().st_mtime) if found else None


def latest_needs(lines):
    for line in reversed(lines):
        match = NEEDS.search(line)
        if match:
            return match.group(1).strip()
    return ''


def read_record(log_dir):
    try:
        record = json.loads((Path(log_dir) / WATCH_RECORD).read_text(encoding='utf-8'))
    except (OSError, ValueError):
        return None
    return record if isinstance(record, dict) else None


def status(processes=None, now=None):
    """The launcher's AI characters window: every watcher with its runs, their logs and how fresh they are."""
    now = time.time() if now is None else now
    processes = windows_processes() if processes is None else processes
    watchers, runs = classify(processes)
    out = []
    for watcher in watchers:
        record = read_record(watcher['log_dir']) if watcher['log_dir'] else None
        entry = {'pid': watcher['pid'], 'started': watcher['started'], 'log_dir': watcher['log_dir'],
                 'agent': ((record or {}).get('env') or {}).get('CIV13_AGENT_NAME', ''),
                 'port': ((record or {}).get('env') or {}).get('CIV13_PORT', ''),
                 'restartable': bool(record and record.get('pid') == watcher['pid'] and not record.get('token_in_env')),
                 'runs': []}
        for run in runs:
            if run['ppid'] != watcher['pid']:
                continue
            path = run_log(watcher['log_dir'], run['character'])
            lines = tail(path) if path else []
            age = int(now - path.stat().st_mtime) if path else None
            entry['runs'].append({'pid': run['pid'], 'character': run['character'], 'started': run['started'],
                                  'log': str(path) if path else '', 'idle_s': age,
                                  'stalled': age is not None and age >= STALL_SECONDS,
                                  'needs': latest_needs(lines), 'tail': lines})
        out.append(entry)
    orphans = [{'pid': r['pid'], 'character': r['character']} for r in runs if not any(r['ppid'] == w['pid'] for w in watchers)]
    return {'watchers': out, 'orphans': orphans, 'text': describe(out, orphans)}


def describe(watchers, orphans):
    if not watchers and not orphans:
        return 'No AI character watcher is running on this host.'
    lines = []
    for w in watchers:
        lines.append('Watcher for agent %s on port %s (pid %s), logs in %s' % (w['agent'] or '?', w['port'] or '?', w['pid'], w['log_dir']))
        if not w['runs']:
            lines.append('  No character is being played right now.')
        for r in w['runs']:
            state = 'STALLED' if r['stalled'] else 'active'
            idle = '?' if r['idle_s'] is None else '%ds' % r['idle_s']
            lines.append('  %s run pid %s: %s, last log line %s ago' % (r['character'], r['pid'], state, idle))
            if r['needs']:
                lines.append('    needs: ' + r['needs'])
            for line in r['tail'][-15:]:
                lines.append('    | ' + line)
        lines.append('')
    for r in orphans:
        lines.append('Run pid %s for %s has no watcher.' % (r['pid'], r['character']))
    return '\n'.join(lines).rstrip() + '\n'


def kill(pid):
    os.kill(pid, signal.SIGTERM)  # TerminateProcess on Windows


def stop_run(pid, processes=None, killer=kill):
    """Stop one autopilot run (not a watcher, not any other process). Its watcher plays the character again."""
    processes = windows_processes() if processes is None else processes
    _, runs = classify(processes)
    run = next((r for r in runs if r['pid'] == pid), None)
    if run is None:
        return {'ok': False, 'refused': 'pid %s is not an AI character run on this host' % pid}
    killer(pid)
    return {'ok': True, 'stopped': pid, 'character': run['character'],
            'text': 'Stopped the run for %s. Its watcher plays the character again within a few minutes.' % run['character']}


def restart_watcher(pid, processes=None, killer=kill, launch=None, sleep=time.sleep, clock=time.monotonic):
    """Stop a watcher and its runs (pause file first, so runs finish their step), then start it again as recorded."""
    processes = windows_processes() if processes is None else processes
    watchers, runs = classify(processes)
    watcher = next((w for w in watchers if w['pid'] == pid), None)
    if watcher is None:
        return {'ok': False, 'refused': 'pid %s is not an AI character watcher on this host' % pid}
    record = read_record(watcher['log_dir'])
    if not record or record.get('pid') != pid:
        return {'ok': False, 'refused': 'this watcher was started before the launcher could restart it; start it once by hand'}
    if record.get('token_in_env'):
        return {'ok': False, 'refused': 'this watcher got its agent token directly; start it again by hand'}
    pause = record.get('pause_file') or ''
    if pause:
        try:
            Path(pause).write_text('Launcher restart.\n', encoding='utf-8')
        except OSError:
            pause = ''
    children = [r['pid'] for r in runs if r['ppid'] == pid]
    deadline = clock() + STOP_WAIT
    while pause and clock() < deadline and alive(pid, None):
        sleep(2)
    for child in children:
        if alive(child, None):
            killer(child)
    if alive(pid, None):
        killer(pid)
    if pause:
        try:
            os.unlink(pause)
        except OSError:
            pass
    started = (launch or start_watcher)(record, watcher['log_dir'])
    return {'ok': True, 'restarted': pid, 'pid': started,
            'text': 'Restarted the watcher (new pid %s). It plays its characters again within a minute.' % started}


def alive(pid, processes):
    if processes is not None:
        return any(p['pid'] == pid for p in processes)
    if os.name == 'nt':
        return any(p['pid'] == pid for p in windows_processes())
    try:
        os.kill(pid, 0)
    except OSError:
        return False
    return True


def start_watcher(record, log_dir):
    """Start a watcher exactly as recorded, detached, its output appended to watch.log in its log folder."""
    argv = [record['python']] + [str(a) for a in record['argv']]
    env = dict(os.environ)
    for key in WATCH_ENV:
        env.pop(key, None)
    env.update({k: str(v) for k, v in (record.get('env') or {}).items() if k in WATCH_ENV})
    flags = getattr(subprocess, 'DETACHED_PROCESS', 0) | getattr(subprocess, 'CREATE_NEW_PROCESS_GROUP', 0) | getattr(subprocess, 'CREATE_NO_WINDOW', 0)
    with open(Path(log_dir) / 'watch.log', 'a', encoding='utf-8') as log:
        process = subprocess.Popen(argv, cwd=record.get('cwd') or None, env=env, stdin=subprocess.DEVNULL,
                                   stdout=log, stderr=subprocess.STDOUT, creationflags=flags, close_fds=True)
    return process.pid


def main(argv=None):
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--stop-run', type=int)
    parser.add_argument('--restart-watcher', type=int)
    args = parser.parse_args(argv)
    if args.stop_run:
        result = stop_run(args.stop_run)
    elif args.restart_watcher:
        result = restart_watcher(args.restart_watcher)
    else:
        result = dict(status(), ok=True)
    print(json.dumps(result))
    return 0 if result.get('ok', True) else 1


if __name__ == '__main__':
    sys.exit(main())
