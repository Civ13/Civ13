"""Inventory compiled inherited sprite defaults without constructing game objects."""
import argparse, hashlib, importlib.util, json, os, re, shutil, subprocess, tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]

def toolchain():
    spec = importlib.util.spec_from_file_location('sprite_byond_runtime', ROOT / 'scripts/byond_runtime.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def combined_output(result):
    # Keep stream boundaries explicit, including unterminated stdout.
    return result.stdout + ('\n' if result.stdout and not result.stdout.endswith('\n') else '') + result.stderr


def run_logged(command, diagnostic, *, runtime_log=None, **kwargs):
    try:
        result = subprocess.run(command, **kwargs)
    except subprocess.TimeoutExpired as error:
        def text(value):
            return value.decode(errors='replace') if isinstance(value, bytes) else value or ''
        output = text(error.stdout) + '\n' + text(error.stderr)
        if runtime_log is not None and runtime_log.is_file():
            output += '\n' + runtime_log.read_text(errors='replace')
        diagnostic.write_text(output, encoding='utf-8')
        raise
    output = combined_output(result)
    if runtime_log is not None and runtime_log.is_file():
        output += '\n' + runtime_log.read_text(errors='replace')
    diagnostic.write_text(output, encoding='utf-8')
    return result


def validate_compiler(result, expected):
    # Validate the combined output: a second banner on stderr is ambiguous too.
    text = combined_output(result)
    if result.returncode:
        raise RuntimeError('Sprite fixture compiler exited unsuccessfully')
    banners = re.findall(r'^DM compiler version[^\r\n]*', text, re.M)
    if banners != ['DM compiler version ' + expected] or not re.search(r'^.* - 0 errors, 0 warnings(?:[ (].*)?$', text, re.M):
        raise RuntimeError('Sprite fixture requires one exact BYOND ' + expected + ' compiler banner and clean result')
    return banners[0].removeprefix('DM compiler version ')


def selected_runtime(args):
    if args.legacy_fixture_5161681:
        if args.byond_archive:
            raise ValueError('Legacy fixture cannot claim the current pinned archive')
        return {'version': '516.1681', 'identity_basis': 'explicit-historical-fixture-unverified-members'}
    if os.name == 'nt' or args.byond_archive is None:
        raise ValueError('Current sprite extraction requires Linux and --byond-archive matching the central pin; historical 1681 fixtures require --legacy-fixture-5161681')
    return toolchain().verify_linux(args.byond_bin, args.byond_archive)


def source_identity():
    return {'head_sha': subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
            'source_tree': subprocess.check_output(['git', 'rev-parse', 'HEAD^{tree}'], cwd=ROOT, text=True).strip(),
            'tracked_dirty': bool(subprocess.check_output(['git', 'status', '--porcelain', '--untracked-files=no'], cwd=ROOT, text=True).strip()),
            'tracked_patch_sha256': hashlib.sha256(subprocess.check_output(['git', 'diff', '--binary', 'HEAD'], cwd=ROOT)).hexdigest()}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--negative-control', action='store_true')
    parser.add_argument('--atlas-assets', type=Path)
    parser.add_argument('--byond-archive', type=Path)
    parser.add_argument('--legacy-fixture-5161681', action='store_true')
    args = parser.parse_args()
    # Keep paths stable across ROOT and temporary runtime working directories,
    # without resolving away links before passive identity validation.
    args.byond_bin = args.byond_bin.absolute()
    args.byond_archive = args.byond_archive.absolute() if args.byond_archive else None
    args.output = args.output.absolute()
    args.atlas_assets = args.atlas_assets.absolute() if args.atlas_assets else None
    outputs = [args.output, *(args.output.with_suffix(s) for s in ('.evidence.json', '.compiler.log', '.runtime.log'))]
    if any(p.exists() or p.is_symlink() for p in outputs):
        raise RuntimeError('Preserve existing sprite attempt output and evidence; use a fresh destination')
    identity = selected_runtime(args)  # Refuse mismatches before generated source or execution.
    source_before = source_identity()
    env = os.environ.copy()
    if not args.legacy_fixture_5161681:
        if env.get('LD_PRELOAD') or env.get('LD_AUDIT'):
            raise RuntimeError('Loader injection is incompatible with pinned sprite extraction')
        env['LD_LIBRARY_PATH'] = str(args.byond_bin.resolve())
        env['BYOND_SYSTEM'] = str(args.byond_bin.resolve().parent)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    flags = subprocess.CREATE_NO_WINDOW if os.name == 'nt' else 0
    prefix = '.sprite_audit'
    generated = [ROOT / (prefix + s) for s in ('.dme', '_world.dm', '_globals.dm', '.dmb', '.rsc', '_attachments.dm', '_fixture.dm')]
    if any(p.exists() or p.is_symlink() for p in generated):
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
        if args.negative_control:
            attachments = (ROOT / 'code/modules/1713/weapons/attachment.dm').read_text(encoding='utf-8')
            target = '/obj/item/weapon/attachment/scope/adjustable/sniper_scope/pu/ppu8'
            start = attachments.index(target + '\n')
            end = attachments.index('\n/obj/', start + 1)
            block = attachments[start:end]
            assert block.count("\ticon = 'icons/obj/guns/parts.dmi'") == 1
            mutated = block.replace("\ticon = 'icons/obj/guns/parts.dmi'", "\ticon = 'icons/obj/gun_att.dmi'")
            generated[5].write_text(attachments[:start] + mutated + attachments[end:], encoding='utf-8')
            source = source.replace('code\\modules\\1713\\weapons\\attachment.dm', prefix + '_attachments.dm')
        fixture=(ROOT / 'tests/sprites/fixture.dm').read_text(encoding='utf-8')
        if args.atlas_assets:
            fixture=fixture.replace('typesof(/obj/item, /obj/structure, /obj/machinery)', 'typesof(/obj, /turf, /mob)')
            fixture=fixture.replace('"invisibility" = initial(T:invisibility)', '"dir" = initial(T:dir), "invisibility" = initial(T:invisibility)')
            fixture=fixture.replace('\ttext2file(json_encode(rows)', '\tvar/list/requests = json_decode(file2text("requests.json"))\n\tvar/list/exports = list()\n\tfor(var/typepath in requests)\n\t\tvar/T = text2path(typepath)\n\t\tif(!T)\n\t\t\tcontinue\n\t\tvar/I = initial(T:icon)\n\t\tvar/S = initial(T:icon_state)\n\t\tif(I && (S in icon_states(I)))\n\t\t\tvar/icon/preview = icon(I, S, initial(T:dir), 1)\n\t\t\tvar/filename = "sprite_[exports.len].png"\n\t\t\tfcopy(preview, filename)\n\t\t\texports[typepath] = filename\n\ttext2file(json_encode(exports), "exports.json")\n\ttext2file(json_encode(rows)')
            fixture=fixture.replace('var/T = text2path(typepath)', 'var/list/parts = splittext(typepath, "#")\n\t\tvar/T = text2path(parts[1])')
            fixture=fixture.replace('\t\tvar/S = initial(T:icon_state)\n\t\tif(I &&', '\t\tvar/S = parts.len > 1 ? parts[2] : initial(T:icon_state)\n\t\tif(I &&')
        generated[6].write_text(fixture, encoding='utf-8')
        generated[0].write_text(source + '\n#include "'+generated[6].name+'"\n', encoding='utf-8')
        compiler = args.byond_bin / ('dm.exe' if os.name == 'nt' else 'DreamMaker')
        daemon = args.byond_bin / ('dd.exe' if os.name == 'nt' else 'DreamDaemon')
        result = run_logged([str(compiler), '-max_errors', '0', generated[0].name], args.output.with_suffix('.compiler.log'), cwd=ROOT, capture_output=True, text=True, timeout=180, creationflags=flags, env=env)
        compiler_text = combined_output(result)
        print(compiler_text)
        actual_version = validate_compiler(result, identity['version'])
        with tempfile.TemporaryDirectory(prefix='civ13-sprites-') as folder:
            tmp = Path(folder)
            for path in generated[3:5]:
                shutil.copy2(path, tmp / path.name)
            shutil.copytree(ROOT / 'config/names', tmp / 'config/names')
            if args.atlas_assets:
                shutil.copy2(args.atlas_assets / 'requests.json', tmp / 'requests.json')
            if selected_runtime(args) != identity:
                raise RuntimeError('Runtime identity changed after compilation')
            runtime = run_logged([str(daemon), str(tmp / generated[3].name), *(['-invisible', '-close'] if os.name == 'nt' else []), '-trusted', '-log', 'runtime.log'], args.output.with_suffix('.runtime.log'), runtime_log=tmp/'runtime.log', cwd=tmp, capture_output=True, text=True, timeout=60, creationflags=flags, env=env)
            log = (tmp / 'runtime.log').read_text(errors='replace')
            if runtime.returncode or any(t in log.lower() for t in ('runtime error:', '## error:', 'bug:')):
                raise RuntimeError('Daemon exit '+str(runtime.returncode)+'\n'+log + runtime.stdout + runtime.stderr)
            if selected_runtime(args) != identity:
                raise RuntimeError('Runtime identity changed during extraction')
            rows = json.loads((tmp / 'sprites.json').read_text())
            if args.atlas_assets:
                exports=json.loads((tmp / 'exports.json').read_text())
                for filename in exports.values():
                    shutil.copy2(tmp / filename, args.atlas_assets / filename)
                (args.atlas_assets / 'exports.json').write_text(json.dumps(exports), encoding='utf-8')
            args.output.parent.mkdir(parents=True, exist_ok=True)
            args.output.write_text(json.dumps(rows, indent=2), encoding='utf-8')
            from validate import validate
            try:
                validate(ROOT, rows)
            except ValueError as error:
                if not args.negative_control or str(error) != 'Unresolved compiled sprite: /obj/item/weapon/attachment/scope/adjustable/sniper_scope/pu/ppu8':
                    raise
                print('PASS: Wrong inherited icon resource negative control detected')
            else:
                if args.negative_control:
                    raise RuntimeError('Negative control unexpectedly passed')
            if source_identity() != source_before:
                raise RuntimeError('Tracked source changed during sprite extraction')
            evidence = {**source_before, 'status': 'passed', 'byond': actual_version, 'runtime_identity': identity, 'types': len(rows),
                        'negative_control': args.negative_control,
                        'compiler_log_sha256': hashlib.sha256(compiler_text.encode()).hexdigest(),
                        'runtime_log_sha256': hashlib.sha256(args.output.with_suffix('.runtime.log').read_bytes()).hexdigest(),
                        'generated_source_sha256': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in generated if p.exists()},
                        'inventory_sha256': hashlib.sha256(args.output.read_bytes()).hexdigest(),
                        'identity_scope': 'Compiler banner and passive bundled runtime identity; not full dynamic dependency or gameplay acceptance'}
            if args.atlas_assets:
                evidence['requests_sha256'] = hashlib.sha256((args.atlas_assets / 'requests.json').read_bytes()).hexdigest()
                evidence['exported_assets_sha256'] = {name: hashlib.sha256((args.atlas_assets / name).read_bytes()).hexdigest()
                                                     for name in sorted(set(exports.values()) | {'exports.json'})}
            args.output.with_suffix('.evidence.json').write_text(json.dumps(evidence, indent=2), encoding='utf-8')
            print(f'Inventory: {len(rows)} compiled types; {sum(not r["valid"] for r in rows)} unresolved defaults')
    except BaseException as error:
        args.output.with_suffix('.evidence.json').write_text(json.dumps({**source_before, 'status': 'failed',
            'error_type': type(error).__name__, 'runtime_identity': identity,
            'identity_scope': 'Attempt only; no successful extraction or native compatibility claim'}, indent=2), encoding='utf-8')
        raise
    finally:
        for path in generated:
            path.unlink(missing_ok=True)

if __name__ == '__main__':
    main()
