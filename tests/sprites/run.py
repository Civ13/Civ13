"""Inventory compiled inherited sprite defaults without constructing game objects."""
import argparse, json, os, re, shutil, subprocess, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    prefix = '.sprite_audit'
    generated = [ROOT / (prefix + s) for s in ('.dme', '_world.dm', '_globals.dm', '.dmb', '.rsc')]
    if any(p.exists() for p in generated):
        raise RuntimeError('Preserve existing sprite probe files')
    try:
        world = (ROOT / 'code/world.dm').read_text(encoding='utf-8')
        start = world.index('/world/New()')
        parent = world.index('\n\t..()', start)
        world = world[:parent] + world[parent:].replace('\n\t..()', '', 1)
        world = world.replace('/world/New()', '/world/proc/unused_sprite_startup()', 1)
        world = world.replace('/datum/global_init/New()\n', '/datum/global_init/New()\n\treturn\n', 1)
        generated[1].write_text(world, encoding='utf-8')
        globals_source = (ROOT / 'code/controllers/mc/globals.dm').read_text(encoding='utf-8')
        marker = '/datum/controller/global_vars/New()\n'
        assert globals_source.count(marker) == 1
        generated[2].write_text(globals_source.replace(marker, marker + '\treturn\n'), encoding='utf-8')
        source = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
        source = source.replace('code\\world.dm', prefix + '_world.dm').replace('code\\controllers\\mc\\globals.dm', prefix + '_globals.dm')
        source = re.sub(r'^#include ".*\.dmm"\s*$', '', source, flags=re.M)
        generated[0].write_text(source + '\n#include "tests/sprites/fixture.dm"\n', encoding='utf-8')
        compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        result = subprocess.run([str(compiler), '-max_errors', '0', generated[0].name], cwd=ROOT, capture_output=True, text=True, timeout=180, creationflags=flags)
        print(result.stdout + result.stderr)
        if result.returncode or not re.search(r'0 errors, 0 warnings', result.stdout):
            raise RuntimeError('Sprite fixture compilation failed')
        with tempfile.TemporaryDirectory(prefix='civ13-sprites-') as folder:
            tmp = Path(folder)
            for path in generated[3:]:
                shutil.copy2(path, tmp / path.name)
            runtime = subprocess.run([str(daemon), str(tmp / generated[3].name), *(['-invisible', '-close'] if os.name == 'nt' else []), '-safe', '-log', 'runtime.log'], cwd=tmp, capture_output=True, text=True, timeout=60, creationflags=flags)
            log = (tmp / 'runtime.log').read_text(errors='replace')
            if runtime.returncode or any(t in log.lower() for t in ('runtime error:', '## error:', 'bug:')):
                raise RuntimeError(log + runtime.stdout + runtime.stderr)
            rows = json.loads((tmp / 'sprites.json').read_text())
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(rows, indent=2), encoding='utf-8')
            print(f'Inventory: {len(rows)} compiled types; {sum(not r["valid"] for r in rows)} unresolved defaults')
    finally:
        for path in generated:
            path.unlink(missing_ok=True)

if __name__ == '__main__':
    main()
