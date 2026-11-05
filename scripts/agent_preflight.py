"""Offline pre-push checks for agent and contributor branches.

Catches the failures that most often sent agent PRs through extra CI rounds:
byte-pinned source files, stale generated crafting files, offline suites that
were not run locally, and stale player-help wiki guide pins. Starts no BYOND
process and needs no network. It does not replace the hosted compiler or CI.

    python3 scripts/agent_preflight.py pins            # who pins the files you changed
    python3 scripts/agent_preflight.py generated       # atlas + recipe audit drift
    python3 scripts/agent_preflight.py generated --write
    python3 scripts/agent_preflight.py suites          # every offline CI suite
    python3 scripts/agent_preflight.py suites --affected
    python3 scripts/agent_preflight.py patterns [--write]  # forbidden-pattern ratchet
    python3 scripts/agent_preflight.py wiki-pins --wiki-root ../civ13-wiki [--write]
    python3 scripts/agent_preflight.py all             # pins + generated + patterns + suites
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


def suites(args):
    module = baseline_module()
    names = list(module.SUITES)
    if args.affected:
        selection = module.impact(changed_files(args.base))
        names = [n for n, data in selection['suites'].items() if data['selected']]
    head = git('rev-parse', 'HEAD')
    base = git('merge-base', args.base, 'HEAD', check=False) or head
    environment = dict(os.environ, LOS_EVENT_BASE=base, LOS_EVENT_HEAD=head)
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
    print(f'\n{len(names) - len(failed)}/{len(names)} suites passed.')
    if failed:
        print('Failed:', ', '.join(failed))
        print('Compare with master before blaming your change: git stash; rerun the suite; git stash pop.')
    return 1 if failed else 0


def wiki_pins(args):
    bridge = ROOT / 'scripts/player_help_bridge.py'
    source = bridge.read_text(encoding='utf-8')
    wiki = Path(args.wiki_root).resolve()
    revision = subprocess.run(['git', 'rev-parse', 'HEAD'], cwd=wiki, capture_output=True, text=True).stdout.strip()
    spec = importlib.util.spec_from_file_location('player_help_bridge_for_preflight', bridge)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    stale, missing = [], []
    for relative, (expected, _aliases) in module.WIKI_REVIEWED_GUIDES.items():
        path = wiki / 'src' / relative
        if not path.exists():
            missing.append(relative)
            continue
        text = path.read_bytes().decode('utf-8').replace('\r\n', '\n').replace('\r', '\n')
        digest = hashlib.sha256(text.encode('utf-8')).hexdigest()
        if digest != expected:
            stale.append(relative)
            source = source.replace(expected, digest)
    print(f'Wiki checkout {revision or "(unknown)"}; pinned revision {module.WIKI_REVIEWED_REVISION}')
    print(f'{len(module.WIKI_REVIEWED_GUIDES) - len(stale) - len(missing)} current, {len(stale)} changed, {len(missing)} missing')
    for relative in stale:
        print('  changed:', relative)
    for relative in missing:
        print('  missing:', relative)
    # New player guides are never pinned by accident: list the ones Help does not read yet.
    pinned = set(module.WIKI_REVIEWED_GUIDES) | set(module.WIKI_LEGACY_GUIDES)
    unpinned = sorted(str(path.relative_to(wiki / 'src')).replace(os.sep, '/')
                      for folder in ('guides', 'gamemodes') for path in (wiki / 'src' / folder).glob('*.md'))
    unpinned = [relative for relative in unpinned if relative not in pinned]
    for relative in unpinned:
        print('  unpinned (add a hash and aliases to WIKI_REVIEWED_GUIDES if players should get it):', relative)
    if stale and args.write:
        if revision:
            source = source.replace(module.WIKI_REVIEWED_REVISION, revision)
        bridge.write_text(source, encoding='utf-8')
        print('Updated hashes and revision in scripts/player_help_bridge.py. Review the changed guides before committing.')
    return 1 if (stale and not args.write) or missing else 0


def patterns(args):
    """Forbidden source patterns against tools/lint/forbidden_patterns_baseline.json."""
    command = [sys.executable, '-B', str(ROOT / 'scripts/check_forbidden_patterns.py')]
    if args.write:
        command.append('--write')
    return subprocess.run(command, cwd=ROOT).returncode


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
    p = sub.add_parser('all', help='pins, generated, patterns and all suites')
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
        return suites(args) or status
    return {'pins': pins, 'generated': generated, 'patterns': patterns, 'suites': suites,
            'wiki-pins': wiki_pins}[args.command](args)


if __name__ == '__main__':
    sys.exit(main())
