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

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--byond-bin', type=Path, required=True)
    p.add_argument('--output', type=Path)
    p.add_argument('--negative-control', nargs='?', const='nodrop', choices=('nodrop', 'restart', 'noop', 'icon-readiness', 'icon-callback', 'runtime-parent'))
    a = p.parse_args()
    root = Path(__file__).resolve().parents[2]
    out = a.output.resolve() if a.output else Path(tempfile.mkdtemp(prefix='civ13-corpse-decay-'))
    if a.output and out.exists() and any(out.iterdir()):
        raise RuntimeError('Evidence output must be fresh')
    out.mkdir(parents=True, exist_ok=True)
    stem = '.human_corpse_decay_probe'
    generated = [root / (stem + s) for s in ('.dme', '_world.dm', '_decay.dm', '.dmb', '.rsc', '_icons.dm', '_external.dm')]
    training_copy = root / (stem + '_training.dm')
    generated.append(training_copy)
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
        if a.negative_control == 'icon-readiness':
            icons = (root / 'code/modules/organs/organ_icon.dm').read_text(encoding='utf-8')
            guard = 'if (QDELETED(src) || !owner || !owner.species || !species || !owner.body_build)'
            assert icons.count(guard) == 1
            generated[5].write_text(icons.replace(guard, 'if (QDELETED(src) || !owner || !owner.species)', 1), encoding='utf-8')
            source = source.replace('code\\modules\\organs\\organ_icon.dm', stem + '_icons.dm')
        elif a.negative_control == 'icon-callback':
            external = (root / 'code/modules/organs/organ_external.dm').read_text(encoding='utf-8')
            guard = 'if (!QDELETED(src) && owner && owner.species && species && owner.body_build)'
            assert external.count(guard) == 1
            generated[6].write_text(external.replace(guard, 'if (TRUE)', 1), encoding='utf-8')
            source = source.replace('code\\modules\\organs\\organ_external.dm', stem + '_external.dm')
        elif a.negative_control == 'runtime-parent':
            training = (root / 'code/modules/1713/active_training.dm').read_text(encoding='utf-8')
            fixed = 'return (key in list("exercise_rest_epoch", "exercise_equipment")) || ..()'
            broken = 'return key in list("exercise_rest_epoch", "exercise_equipment") || ..()'
            if training.count(fixed) != 1:
                raise RuntimeError('Runtime-parent mutation target changed')
            training_copy.write_text(training.replace(fixed, broken, 1), encoding='utf-8')
            source = source.replace('code\\modules\\1713\\active_training.dm', training_copy.name)
        elif a.negative_control:
            decay = (root / 'code/processes/human_corpse_decay.dm').read_text(encoding='utf-8')
            if a.negative_control == 'nodrop':
                decay = decay.replace('if (I.nodrop || I.anchored || I.nodrop_special_check())', 'if (I.nodrop && !I.nodrop)', 1)
                decay = decay.replace('(I && I.loc == src)', 'FALSE', 1)
                decay = decay.replace('if (!(A in organs) && !(A in internal_organs))', 'if (FALSE)', 1)
            elif a.negative_control == 'restart':
                decay = decay.replace('// Restore durable age;', 'reset_corpse_decay_age()\n\t// Restore durable age;', 1)
            else:
                decay = decay.replace('if (loc != previous)', 'if (loc != previous || loc == previous)', 1)
            generated[2].write_text(decay, encoding='utf-8')
            source = source.replace('code\\processes\\human_corpse_decay.dm', stem + '_decay.dm')
        generated[0].write_text(source + '\n#include "tests/human_corpse_decay/probe.dm"\n')
        head = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=root, text=True).strip()
        (out / 'dirty.patch').write_bytes(subprocess.check_output(['git', 'diff', 'HEAD'], cwd=root))
        build = subprocess.run([str(compiler), '-max_errors', '0', str(generated[0])], cwd=root, capture_output=True, text=True, timeout=120, creationflags=flags)
        text = build.stdout + build.stderr
        (out / 'compile.log').write_text(text)
        print(text, flush=True)
        if build.returncode or 'DM compiler version 516.1681' not in text or '0 errors, 0 warnings' not in text:
            raise RuntimeError('Pinned compilation failed')
        for f in generated[3:5]: shutil.copy2(f, out / f.name)
        # Only tracked name data; no production config, credentials or saves.
        for rel in subprocess.check_output(['git', 'ls-files', 'config/names'], cwd=root, text=True).splitlines():
            destination = out / rel
            destination.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(root / rel, destination)
        (out / 'config/config.txt').write_text('', encoding='utf-8')
        log = (out / 'daemon.log').open('w')
        cmd = [str(daemon), str(out / generated[3].name)]
        if os.name == 'nt': cmd += ['-invisible', '-close']
        cmd += ['-trusted', '-params', f'tested_commit={head}', '-log', 'runtime.log']
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
                    try:
                        rows = cycles.read_text().splitlines()
                        if rows:
                            sample['completed_cycle'] = json.loads(rows[-1])['cycle']
                    except (json.JSONDecodeError, FileNotFoundError, KeyError):
                        pass  # The native writer may still be appending this sample.
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
        daemon_text = (out / 'daemon.log').read_text(encoding='utf-8', errors='replace')
        if any(marker in (runtime_text + daemon_text).lower() for marker in ('runtime error:', 'bad ref', 'badref', '## bug:')):
            print('Native runtime log:\n' + runtime_text, flush=True)
            print('Native daemon output:\n' + daemon_text, flush=True)
            raise RuntimeError('Uncaught runtime/engine diagnostic in isolated logs')
        result = (out / 'result.txt').read_text(encoding="utf-8").strip()
        print(result)
        if a.negative_control:
            expected = {'nodrop': 'nodrop gear blocks retirement', 'restart': 'restart retains exposure', 'noop': 'noop movement retains exposure', 'icon-readiness': 'partial head icon defers species lookup', 'icon-callback': 'partial organ constructor callback defers', 'runtime-parent': 'human inherits corpse runtime exclusion'}[a.negative_control]
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
