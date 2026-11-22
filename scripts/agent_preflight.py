"""Offline pre-push checks for agent and contributor branches.

Catches the failures that most often sent agent PRs through extra CI rounds:
byte-pinned source files, stale generated crafting files, offline suites that
were not run locally, and stale player-help wiki guide pins. Needs no network.
`compile` (also run by `all` when a compiler is found) builds the game with a
little extra global data, because the engine puts every initialised global into
one proc with a size limit and test probes add globals of their own. It does
not replace the hosted compiler or CI.

    python3 scripts/agent_preflight.py pins            # who pins the files you changed
    python3 scripts/agent_preflight.py generated       # atlas + recipe audit drift
    python3 scripts/agent_preflight.py generated --write
    python3 scripts/agent_preflight.py suites          # every offline CI suite
    python3 scripts/agent_preflight.py suites --affected
    python3 scripts/agent_preflight.py patterns [--write]  # forbidden-pattern ratchet
    python3 scripts/agent_preflight.py wiki-pins --wiki-root ../civ13-wiki [--write]
    python3 scripts/agent_preflight.py compile         # full compile plus global-init headroom
    python3 scripts/agent_preflight.py all             # pins + generated + patterns + suites + compile
"""
import argparse
import hashlib
import importlib.util
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PIN_WORDS = re.compile(r'sha256|sha1|hexdigest|blob|frozen|fixture|byte|exact|unchanged|hash', re.I)
SEARCH_DIRS = ('tests', 'scripts', 'docs')
SEARCH_SUFFIXES = {'.py', '.json', '.txt', '.mjs', '.js', '.yml', '.yaml', '.toml'}


def git(*args, check=True):
    return subprocess.run(['git', *args], cwd=ROOT, check=check, capture_output=True, text=True).stdout.strip()


def changed_files(base):
    merge_base = git('merge-base', base, 'HEAD', check=False) or base
    names = set(git('diff', '--name-only', merge_base, check=False).splitlines())
    names |= set(git('ls-files', '--others', '--exclude-standard').splitlines())
    return sorted(name for name in names if name)


def baseline_module():
    spec = importlib.util.spec_from_file_location('ci_baseline_for_preflight', ROOT / 'scripts/ci_baseline.py')
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


def pins(args):
    paths = args.paths or changed_files(args.base)
    if not paths:
        print('No changed files against', args.base)
        return 0
    candidates = [p for d in SEARCH_DIRS for p in (ROOT / d).rglob('*')
                  if p.is_file() and p.suffix in SEARCH_SUFFIXES]
    texts = {}
    for path in candidates:
        try:
            texts[path] = path.read_text(encoding='utf-8', errors='ignore')
        except OSError:
            continue
    flagged = 0
    for changed in paths:
        if not changed.endswith(('.dm', '.dme', '.txt', '.json', '.py', '.html', '.tsx', '.js')):
            continue
        hits = []
        for path, text in texts.items():
            relative = path.relative_to(ROOT).as_posix()
            if relative == changed or changed not in text:
                continue
            pinned = any(PIN_WORDS.search(line) for line in text.splitlines() if changed in line) or \
                bool(PIN_WORDS.search(text[:4000]))
            hits.append((pinned, relative))
        if hits:
            flagged += 1
            print(f'\n{changed} is referenced by:')
            for pinned, relative in sorted(hits, reverse=True):
                print(('  [likely pinned] ' if pinned else '  ') + relative)
    suites = baseline_module().impact(paths)
    selected = sorted(name for name, data in suites['suites'].items() if data['selected'])
    print('\nCI would select these offline suites:', ', '.join(selected) or 'none')
    if suites['fallback_reasons']:
        print('CI falls back to every offline suite because of:', '; '.join(suites['fallback_reasons'][:5]))
    if flagged:
        print('\nIf a pinned test fails: revert a cosmetic edit to that file, or refresh the fixture/hash'
              ' the test names in the same commit and say so in the PR. Never weaken the test.')
    return 0


def generated(args):
    status = 0
    atlas = ROOT / 'UI/crafting-atlas.json'
    command = [sys.executable, 'scripts/build-crafting-atlas.py', '--catalog-only']
    result = subprocess.run(command + ['--check-game-catalog', str(atlas)], cwd=ROOT, capture_output=True, text=True)
    if result.returncode == 0:
        print('UI/crafting-atlas.json: current')
    elif args.write:
        subprocess.run(command + ['--game-catalog', str(atlas)], cwd=ROOT, check=True)
        print('UI/crafting-atlas.json: regenerated')
    else:
        print('UI/crafting-atlas.json: STALE (rerun with --write)')
        status = 1
    index = ROOT / 'docs/crafting-recipe-audit-index.json'
    with tempfile.TemporaryDirectory() as folder:
        scratch = Path(folder) / index.name
        shutil.copyfile(index, scratch)
        subprocess.run([sys.executable, 'scripts/audit-crafting-recipes.py', '--summary', '--output', str(scratch)],
                       cwd=ROOT, check=True)
        if scratch.read_bytes() == index.read_bytes():
            print('docs/crafting-recipe-audit-index.json: current')
        elif args.write:
            shutil.copyfile(scratch, index)
            print('docs/crafting-recipe-audit-index.json: counts refreshed (hand-reviewed metadata kept)')
        else:
            print('docs/crafting-recipe-audit-index.json: STALE (rerun with --write)')
            status = 1
    # The CI digest must watch every pull_request workflow (docs/agent-ci-digest.md).
    command = [sys.executable, '-B', 'scripts/ci_digest.py', 'sync-workflows'] + (['--write'] if args.write else [])
    result = subprocess.run(command, cwd=ROOT, capture_output=True, text=True)
    print(result.stdout.strip() or result.stderr.strip())
    return status or result.returncode


TGUI_CHECKS = (
    ('tgui', ('-m', 'unittest', 'discover', '-s', 'tests/tgui', '-p', 'test_*.py')),
    ('tgui_flavor_negative_controls', ('tests/tgui/flavor_negative_controls.py',)),
    ('tgui_notes_negative_controls', ('tests/tgui/notes_negative_controls.py',)),
)


def suites(args):
    module = baseline_module()
    names = list(module.SUITES)
    if args.affected:
        selection = module.impact(changed_files(args.base))
        names = [n for n, data in selection['suites'].items() if data['selected']]
    head = git('rev-parse', 'HEAD')
    base = git('merge-base', args.base, 'HEAD', check=False) or head
    # PYTHONUTF8: Windows defaults text I/O to cp1252; every suite reads UTF-8.
    environment = dict(os.environ, LOS_EVENT_BASE=base, LOS_EVENT_HEAD=head, PYTHONUTF8='1')
    failed = []
    with tempfile.TemporaryDirectory() as folder:
        for name in names:
            output = Path(folder) / (name + '.json')
            result = subprocess.run([sys.executable, '-B', 'scripts/ci_baseline.py', 'unit', '--suite', name,
                                     '--output', str(output)], cwd=ROOT, env=environment,
                                    capture_output=True, text=True)
            counts = json.loads(output.read_text()) if output.exists() else {}
            line = f"{name}: {counts.get('status', 'error')} ({counts.get('tests', 0)} tests)"
            print(line, flush=True)
            if result.returncode:
                failed.append(name)
                if args.verbose:
                    print(result.stderr[-4000:])
    # The tgui window tests have their own workflow (.github/workflows/tgui.yml)
    # and are not a ci_baseline suite; they take a few seconds, so run them here.
    for name, command in TGUI_CHECKS:
        names.append(name)
        result = subprocess.run([sys.executable, '-B', *command], cwd=ROOT, env=environment,
                                capture_output=True, text=True)
        ran = re.search(r'Ran (\d+) tests?', result.stderr)
        print(f"{name}: {'failed' if result.returncode else 'passed'}" + (f' ({ran.group(1)} tests)' if ran else ''),
              flush=True)
        if result.returncode:
            failed.append(name)
            if args.verbose:
                print((result.stderr or result.stdout)[-4000:])
    print(f'\n{len(names) - len(failed)}/{len(names)} suites passed.')
    if failed:
        print('Failed:', ', '.join(failed))
        print('Compare with master before blaming your change: git stash; rerun the suite; git stash pop.')
    return 1 if failed else 0


def wiki_pins(args):
    """Compare the Help pins and the bundled guide copies to a civ13-wiki checkout."""
    bridge = ROOT / 'scripts/player_help_bridge.py'
    source = bridge.read_text(encoding='utf-8')
    wiki = Path(args.wiki_root).resolve()
    revision = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=wiki, capture_output=True, text=True).stdout.strip()
    spec = importlib.util.spec_from_file_location('player_help_bridge_for_preflight', bridge)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    bundle = ROOT / module.WIKI_BUNDLE
    stale, missing, unbundled, digests, texts = [], [], [], {}, {}
    for relative, (expected, _aliases) in module.WIKI_REVIEWED_GUIDES.items():
        path = wiki / 'src' / relative
        if not path.exists():
            missing.append(relative)
            continue
        text = path.read_bytes().decode('utf-8').replace('\r\n', '\n').replace('\r', '\n')
        texts[relative] = text
        digest = hashlib.sha256(text.encode('utf-8')).hexdigest()
        if digest != expected:
            stale.append(relative)
            digests[relative] = digest
            source = source.replace(expected, digest)
        # The game ships its own copy of every pinned guide; Help reads that copy.
        copy = bundle / relative
        if not copy.exists() or copy.read_bytes() != text.encode('utf-8'):
            unbundled.append(relative)
    extra = sorted(str(path.relative_to(bundle)).replace(os.sep, '/') for path in bundle.rglob('*.md')
                   if str(path.relative_to(bundle)).replace(os.sep, '/') not in module.WIKI_REVIEWED_GUIDES) if bundle.is_dir() else []
    print(f'Wiki checkout {revision or "(unknown)"}; pinned revision {module.WIKI_REVIEWED_REVISION}')
    print(f'{len(module.WIKI_REVIEWED_GUIDES) - len(stale) - len(missing)} current, {len(stale)} changed, {len(missing)} missing, '
          f'{len(unbundled)} bundled copies to refresh, {len(extra)} bundled copies no longer pinned')
    for relative in stale:
        print('  changed:', relative)
    for relative in missing:
        print('  missing:', relative)
    for relative in unbundled:
        if relative not in stale:
            print('  bundled copy differs:', relative)
    for relative in extra:
        print('  bundled but not pinned:', relative)
    # New player guides are never pinned by accident: list the ones Help does not read yet.
    pinned = set(module.WIKI_REVIEWED_GUIDES)
    unpinned = sorted(str(path.relative_to(wiki / 'src')).replace(os.sep, '/')
                      for folder in ('guides', 'gamemodes', 'regions') for path in (wiki / 'src' / folder).glob('*.md'))
    unpinned = [relative for relative in unpinned if relative not in pinned and relative not in module.WIKI_UNPINNED]
    for relative in unpinned:
        print('  unpinned (add a hash and aliases to WIKI_REVIEWED_GUIDES if players should get it):', relative)
    if (stale or unbundled or extra) and args.write:
        if revision:
            source = source.replace(module.WIKI_REVIEWED_REVISION, revision)
        bridge.write_text(source, encoding='utf-8')
        for relative in unbundled:
            copy = bundle / relative
            copy.parent.mkdir(parents=True, exist_ok=True)
            copy.write_bytes(texts[relative].encode('utf-8'))
        for relative in extra:
            (bundle / relative).unlink()
        # The wiki guide tests freeze the same revision and a few hashes as literals.
        tests = ROOT / 'tests/player_help/test_wiki_guides.py'
        text = tests.read_text(encoding='utf-8')
        for relative in stale:
            text = text.replace(module.WIKI_REVIEWED_GUIDES[relative][0], digests[relative])
        if revision:
            text = text.replace(module.WIKI_REVIEWED_REVISION, revision)
        tests.write_text(text, encoding='utf-8')
        print(f'Updated hashes and revision in scripts/player_help_bridge.py and tests/player_help/test_wiki_guides.py, '
              f'and the guide copies under {module.WIKI_BUNDLE}. Review the changed guides before committing.')
    return 1 if ((stale or unbundled or extra) and not args.write) or missing else 0


def patterns(args):
    """Forbidden source patterns against tools/lint/forbidden_patterns_baseline.json."""
    command = [sys.executable, '-B', str(ROOT / 'scripts/check_forbidden_patterns.py')]
    if args.write:
        command.append('--write')
    return subprocess.run(command, cwd=ROOT).returncode


# Extra initialised globals the compile check adds: probes declare their own
# globals, so a branch that only just fits breaks every probe build in CI.
HEADROOM_ENTRIES = 1000


def find_compiler():
    """The pinned DreamMaker (or dm.exe) if one is installed, else None."""
    names = ('dm.exe',) if os.name == 'nt' else ('DreamMaker',)
    dirs = [os.environ.get('BYOND_BIN')]
    version = json.loads((ROOT / 'tools/byond/version.json').read_text())['version']
    home = os.environ.get('BYOND_HOME') or str(Path.home() / f'byond-{version}')
    dirs.append(str(Path(home) / 'byond' / 'bin'))
    for folder in dirs:
        for name in names:
            if folder and (Path(folder) / name).is_file():
                return Path(folder) / name
    for name in names:
        found = shutil.which(name)
        if found:
            return Path(found)
    return None


def compile_check(args):
    """Compile civ13.dme plus HEADROOM_ENTRIES extra global list entries."""
    compiler = find_compiler()
    if not compiler:
        print('compile: skipped, no DreamMaker found (bash scripts/cloud_byond_setup.sh installs the pin)')
        return 0
    prefix = 'zz_preflight_headroom'
    entries = ','.join(f'"k{i}" = {i}' for i in range(HEADROOM_ENTRIES))
    created = [ROOT / f'{prefix}{ext}' for ext in ('.dme', '.dm', '.dmb', '.rsc', '.int', '.lk', '.dyn.rsc')]
    try:
        (ROOT / f'{prefix}.dm').write_text(f'var/global/list/{prefix} = list({entries})\n')
        dme = (ROOT / 'civ13.dme').read_text(encoding='latin-1')
        (ROOT / f'{prefix}.dme').write_text(dme + f'\n#include "{prefix}.dm"\n', encoding='latin-1')
        env = dict(os.environ)
        env['LD_LIBRARY_PATH'] = str(compiler.parent) + os.pathsep + env.get('LD_LIBRARY_PATH', '')
        run = subprocess.run([str(compiler), '-max_errors', '0', f'{prefix}.dme'], cwd=ROOT, env=env,
                             capture_output=True, text=True, errors='replace')
        output = run.stdout + run.stderr
        problems = [line for line in output.splitlines() if re.search(r':\s?(error|warning):', line)]
        for line in problems[:40]:
            print(line)
        if any('Procedure is too large' in line for line in problems):
            print(f'compile: FAILED - the global initialiser has no room for {HEADROOM_ENTRIES} more entries. '
                  'Build large global lists in a proc (var/global/list/x = x_table()) instead of inline.')
            return 1
        if run.returncode != 0 or '0 errors, 0 warnings' not in output:
            print('compile: FAILED')
            return 1
        print(f'compile: passed (0 errors, 0 warnings, room for {HEADROOM_ENTRIES} more global entries)')
        return 0
    finally:
        for path in created:
            if path.exists():
                path.unlink()


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('--base', default='origin/master', help='Comparison ref (default origin/master)')
    sub = parser.add_subparsers(dest='command', required=True)
    p = sub.add_parser('pins', help='List tests/manifests that reference changed files')
    p.add_argument('paths', nargs='*')
    p = sub.add_parser('generated', help='Check generated crafting files')
    p.add_argument('--write', action='store_true')
    p = sub.add_parser('suites', help='Run offline CI suites exactly as CI does')
    p.add_argument('--affected', action='store_true', help='Only suites CI maps to the changed files')
    p.add_argument('--verbose', action='store_true')
    p = sub.add_parser('wiki-pins', help='Compare player-help wiki guide pins to a civ13-wiki checkout')
    p.add_argument('--wiki-root', required=True)
    p.add_argument('--write', action='store_true')
    p = sub.add_parser('patterns', help='Forbidden source patterns (spawn, in world, untyped WWinput results)')
    p.add_argument('--write', action='store_true', help='Record lowered counts in the baseline')
    sub.add_parser('compile', help='Compile with global-initialiser headroom (skipped without a compiler)')
    p = sub.add_parser('all', help='pins, generated, patterns, all suites and compile')
    p.add_argument('--write', action='store_true')
    args = parser.parse_args()
    if args.command == 'all':
        args.paths, args.affected, args.verbose = [], False, False
        pins(args)
        print()
        status = generated(args)
        print()
        status = patterns(args) or status
        print()
        status = suites(args) or status
        print()
        return compile_check(args) or status
    return {'pins': pins, 'generated': generated, 'patterns': patterns, 'suites': suites,
            'wiki-pins': wiki_pins, 'compile': compile_check}[args.command](args)


if __name__ == '__main__':
    sys.exit(main())
