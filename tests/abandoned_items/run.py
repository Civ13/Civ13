"""Production-source decay probe; isolated state, bounded runtime, RSS samples."""
import argparse, json, os, shutil, subprocess, tempfile, time
from pathlib import Path

def main():
    p = argparse.ArgumentParser()
    p.add_argument('--byond-bin', type=Path, required=True)
    p.add_argument('--negative-control', action='store_true')
    a = p.parse_args()
    root = Path(__file__).resolve().parents[2]
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
        if a.negative_control:
            decay = (root / 'code/processes/abandoned_items.dm').read_text(encoding="utf-8")
            decay = decay.replace('\t\tqdel(src)\n\t\treturn TRUE', '\t\treturn FALSE', 1)
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
        log = (out / 'daemon.log').open('w')
        cmd = [str(daemon), str(out / generated[3].name)]
        if os.name == 'nt': cmd += ['-invisible', '-close']
        cmd += ['-safe', '-params', f'tested_commit={head}', '-log', 'runtime.log']
        proc = subprocess.Popen(cmd, cwd=out, stdout=log, stderr=subprocess.STDOUT, creationflags=flags)
        samples = []
        # psutil is optional locally; object and reference evidence always exists.
        try:
            import psutil
            monitor = psutil.Process(proc.pid)
        except ImportError: monitor = None
        start = time.monotonic()
        try:
            while proc.poll() is None:
                if time.monotonic() - start > 120: raise RuntimeError('Probe exceeded120 seconds')
                if monitor:
                    try: samples.append({'seconds': round(time.monotonic()-start,3), 'rss_bytes': monitor.memory_info().rss})
                    except psutil.NoSuchProcess: pass
                time.sleep(0.1)
        finally:
            if proc.poll() is None: proc.kill(); proc.wait()
            log.close()
            (out / 'rss.json').write_text(json.dumps(samples))
        result = (out / 'result.txt').read_text(encoding="utf-8").strip()
        print(result)
        if a.negative_control:
            if not result.startswith('FAIL: expired exposed waste decays'): raise RuntimeError('Negative control did not detect disabled deletion')
            print('PASS: disabled-decay mutation detected')
        elif not result.startswith('PASS:') or proc.returncode:
            raise RuntimeError('Production assertions failed')
        if samples: print(f'RSS bytes first={samples[0]["rss_bytes"]} peak={max(s["rss_bytes"] for s in samples)} last={samples[-1]["rss_bytes"]}; short synthetic run only')
    finally:
        for f in generated: f.unlink(missing_ok=True)

if __name__ == '__main__': main()
