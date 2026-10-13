"""Production-source decay probe; isolated state, bounded runtime, RSS samples."""
import argparse, json, os, shutil, subprocess, tempfile, time
from pathlib import Path

def process_memory(pid):
    if os.name == 'nt':
        import ctypes
        from ctypes import wintypes
        class Counters(ctypes.Structure):
            _fields_ = [('cb', wintypes.DWORD), ('faults', wintypes.DWORD)] + [(key, ctypes.c_size_t) for key in ('peak_rss', 'rss', 'peak_paged', 'paged', 'peak_nonpaged', 'nonpaged', 'pagefile', 'peak_pagefile', 'private')]
        kernel = ctypes.WinDLL('kernel32', use_last_error=True)
        api = ctypes.WinDLL('psapi', use_last_error=True)
        kernel.OpenProcess.argtypes = [wintypes.DWORD, wintypes.BOOL, wintypes.DWORD]
        kernel.OpenProcess.restype = wintypes.HANDLE
        kernel.CloseHandle.argtypes = [wintypes.HANDLE]
        api.GetProcessMemoryInfo.argtypes = [wintypes.HANDLE, ctypes.POINTER(Counters), wintypes.DWORD]
        handle = kernel.OpenProcess(0x410, False, pid)
        if not handle: return None
        try:
            counters = Counters(); counters.cb = ctypes.sizeof(counters)
            if not api.GetProcessMemoryInfo(handle, ctypes.byref(counters), counters.cb): return None
            return {'rss_bytes': counters.rss, 'private_bytes': counters.private}
        finally: kernel.CloseHandle(handle)
    try:
        resident = int(Path(f'/proc/{pid}/statm').read_text().split()[1])
        return {'rss_bytes': resident * os.sysconf('SC_PAGE_SIZE')}
    except (FileNotFoundError, ProcessLookupError): return None

def check_transition_hooks(name, source):
    assert 'advance_decay = season_decay_requested(force, advance_decay)' in source, name
    if name != '_map_metadata':
        assert 'abandonment_season_autonomous = TRUE' in source, name
    elif '/season_apply(' in source:
        assert 'season_apply(force, advance_decay, epoch)' in source, name
        assert 'season_transition_complete(epoch)' in source, name
    inside = False
    lines = source.splitlines()
    transitions = 0
    for i, line in enumerate(lines):
        if line.startswith('/'):
            # Base transitions run in the queued worker; custom cycles still
            # implement seasons directly. Do not count unrelated assignments.
            inside = '/seasons(' in line or '/season_apply(' in line
        if inside and line.lstrip().startswith('season = '):
            assert i + 1 < len(lines) and lines[i+1].strip() == 'record_abandonment_season_change(advance_decay)', (name, i+1)
            transitions += 1
    assert transitions >= 2, name
    return transitions


def check_asia_forwarding(source):
    if '/obj/map_metadata/nomads/asia/seasons(' in source:
        assert '..(looping, force, advance_decay)' in source
    else:
        # Asia now inherits the queued clock and extends its completion hook.
        assert '/obj/map_metadata/nomads/asia/season_transition_complete(var/epoch)' in source
        assert '..(epoch)' in source
        assert 'season_worker_valid(epoch)' in source


def check_season_wiring(root):
    """Check production clock hooks without a compiler, daemon or map startup."""
    metadata = root / 'code/game/objects/map_metadata'
    for name in ('_map_metadata', 'nomads/nomads_mountain', 'nomads/nomads_ice_age', 'colonia', 'pepelsibirsk'):
        source = (metadata / (name + '.dm')).read_text()
        check_transition_hooks(name, source)
    asia = (metadata / 'nomads/nomads_asia.dm').read_text()
    check_asia_forwarding(asia)
    admin = (root / 'code/modules/admin/verbs/weather.dm').read_text()
    assert 'map.seasons(FALSE, TRUE, advance_decay)' in admin
    assert '"Keep decay age", "Advance decay age", "Cancel"' in admin


def main():
    p = argparse.ArgumentParser()
    p.add_argument('--byond-bin', type=Path)
    p.add_argument('--check-season-wiring', action='store_true', help='Check source hooks only; do not start BYOND')
    p.add_argument('--negative-control', nargs='?', const='decay', choices=('decay', 'storage', 'save', 'seasons'))
    a = p.parse_args()
    if a.check_season_wiring and a.negative_control:
        p.error('Runtime negative controls cannot be combined with source-only checks')
    if not a.check_season_wiring and a.byond_bin is None:
        p.error('--byond-bin is required for the runtime fixture')
    root = Path(__file__).resolve().parents[2]
    check_season_wiring(root)
    if a.check_season_wiring:
        print('PASS: production season transition hooks')
        return
    out = Path(tempfile.mkdtemp(prefix='civ13-decay-'))
    stem = '.abandoned_items_probe'
    generated = [root / (stem + s) for s in ('.dme', '_world.dm', '_decay.dm', '.dmb', '.rsc')]
    if any(x.exists() for x in generated):
        raise RuntimeError('Existing probe artifacts must be preserved')
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    compiler = a.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
    daemon = a.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
    print(f'Evidence: {out}', flush=True)
    try:
        world = (root / 'code/world.dm').read_text(encoding="utf-8")
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_decay_startup()', 1)
        generated[1].write_text(world, encoding="utf-8")
        source = (root / 'civ13.dme').read_text(encoding="utf-8").replace('code\\world.dm', stem + '_world.dm')
        source = "\n".join(line for line in source.splitlines() if not line.strip().startswith('#include "maps\\'))
        if a.negative_control:
            decay = (root / 'code/processes/abandoned_items.dm').read_text(encoding="utf-8")
            if a.negative_control == 'decay':
                decay = decay.replace('\t\tqdel(src)\n\t\treturn TRUE', '\t\treturn FALSE', 1)
            elif a.negative_control == 'storage':
                decay = decay.replace('/obj/item/proc/abandonment_protected()\n', '/obj/item/proc/abandonment_protected()\n\treturn FALSE\n', 1)
            elif a.negative_control == 'seasons':
                decay = decay.replace('isnull(advance_decay) ? !force : advance_decay', 'isnull(advance_decay) ? TRUE : advance_decay', 1)
            else:
                decay = decay.replace('\t\treturn TRUE\n\treturn ..()', '\t\treturn FALSE\n\treturn ..()', 1)
            generated[2].write_text(decay, encoding="utf-8")
            source = source.replace('code\\processes\\abandoned_items.dm', stem + '_decay.dm')
        generated[0].write_text(source + '\n#include "tests/abandoned_items/probe.dm"\n')
        head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated[0])], cwd=root, capture_output=True, text=True, timeout=120, creationflags=flags)
        text = build.stdout + build.stderr
        (out / 'compile.log').write_text(text)
        print(text, flush=True)
        if build.returncode or 'DM compiler version 516.1681' not in text or '0 errors, 0 warnings' not in text:
            raise RuntimeError('Pinned compilation failed')
        for f in generated[3:]: shutil.copy2(f, out / f.name)
        # Only tracked name data; no production config, credentials or saves.
        for rel in subprocess.check_output(['git', 'ls-files', 'config/names'], cwd=root, text=True).splitlines():
            destination = out / rel
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / rel, destination)
        (out / 'config/config.txt').write_text('', encoding='utf-8')
        log = (out / 'daemon.log').open('w')
        cmd = [str(daemon), str(out / generated[3].name)]
        if os.name == 'nt': cmd += ['-invisible', '-close']
        cmd += ['-safe', '-params', f'tested_commit={head}', '-log', 'runtime.log']
        proc = subprocess.Popen(cmd, cwd=out, stdout=log, stderr=subprocess.STDOUT, creationflags=flags)
        samples = []
        start = time.monotonic()
        try:
            while proc.poll() is None:
                if time.monotonic() - start > 120: raise RuntimeError('Probe exceeded120 seconds')
                memory = process_memory(proc.pid)
                if memory:
                    sample = {'seconds': round(time.monotonic()-start,3), **memory}
                    cycles = out / 'cycles.jsonl'
                    if cycles.exists():
                        rows = cycles.read_text().splitlines()
                        if rows: sample['completed_cycle'] = json.loads(rows[-1])['cycle']
                    phase = out / 'phase.json'
                    try:
                        if phase.exists(): sample.update(json.loads(phase.read_text()))
                    except (json.JSONDecodeError, FileNotFoundError): pass
                    samples.append(sample)
                time.sleep(0.1)
        finally:
            if proc.poll() is None: proc.kill(); proc.wait()
            log.close()
            (out / 'rss.json').write_text(json.dumps(samples))
        runtime_text = (out / 'runtime.log').read_text(encoding='utf-8', errors='replace')
        if 'runtime error:' in runtime_text: raise RuntimeError('Uncaught runtime error in isolated log')
        result = (out / 'result.txt').read_text(encoding="utf-8").strip()
        print(result)
        if a.negative_control:
            expected = {'decay': 'fourth change decays waste', 'storage': 'nested storage protects waste', 'save': 'production serializer excludes runtime state', 'seasons': 'forced base transition preserves decay by default'}[a.negative_control]
            if not result.startswith('FAIL: ' + expected): raise RuntimeError('Negative control did not detect expected mutation')
            print(f'PASS: {a.negative_control} mutation detected')
        elif not result.startswith('PASS:') or proc.returncode:
            raise RuntimeError('Production assertions failed')
        settled = [s for s in samples if s.get('phase') == 'settled']
        if settled:
            print(f'Settled RSS bytes first={settled[0]["rss_bytes"]} last={settled[-1]["rss_bytes"]} range={min(s["rss_bytes"] for s in settled)}..{max(s["rss_bytes"] for s in settled)}; counts zero at each completed cycle')
        if samples: print(f'RSS bytes first={samples[0]["rss_bytes"]} peak={max(s["rss_bytes"] for s in samples)} last={samples[-1]["rss_bytes"]}; short synthetic run only')
    finally:
        for f in generated: f.unlink(missing_ok=True)

if __name__ == '__main__': main()
