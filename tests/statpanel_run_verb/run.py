"""Run the stat panel's run_verb() against stub verbs in a tiny native world.

The new stat panel sends a verb's display name; run_verb() turns it into a
command. "Crafting Atlas" used to resolve to the client verb "Open Web Crafting
Atlas" (its path contains crafting_atlas and client verbs are scanned first), so
the panel opened the web atlas instead of the in-game one.

Usage: python3 tests/statpanel_run_verb/run.py --byond-bin <dir with DreamMaker/DreamDaemon>
       add --negative-control to run the frozen pre-fix proc, which must fail.
"""
import argparse
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/statpanel/statpanel.dm'
HERE = Path(__file__).resolve().parent
DECL = '/client/proc/run_verb(verb_name as text)'


def proc_text(source):
    start = source.index(DECL)
    end = source.find('\n/', start + 1)
    return source[start:end if end != -1 else len(source)]


def transplant(text):
    """Move run_verb() onto the probe object and record commands instead of winset."""
    text = text.replace(DECL, '/obj/run_verb_probe/proc/run_verb(verb_name as text)', 1)
    count = text.count('winset(src, null, ')
    if count < 1:
        raise RuntimeError('run_verb() no longer calls winset(src, null, ...): update the probe')
    return text.replace('winset(src, null, ', 'record_command(', count)


def run(byond_bin, proc_source):
    work = Path(tempfile.mkdtemp(prefix='civ13-run-verb-'))
    try:
        (work / 'run_verb.dm').write_text(transplant(proc_source), encoding='utf-8')
        shutil.copy(HERE / 'probe.dm', work / 'probe.dm')
        (work / 'probe.dme').write_text('#include "probe.dm"\n#include "run_verb.dm"\n', encoding='utf-8')
        compiled = subprocess.run([str(byond_bin / 'DreamMaker'), '-max_errors', '0', 'probe.dme'],
                                  cwd=work, capture_output=True, text=True)
        output = compiled.stdout + compiled.stderr
        if compiled.returncode != 0 or not re.search(r'\b0 errors, 0 warnings', output):
            raise RuntimeError('probe compile failed:\n' + output[-4000:])
        subprocess.run([str(byond_bin / 'DreamDaemon'), 'probe.dmb', '-trusted', '-invisible'],
                       cwd=work, capture_output=True, timeout=120)
        result = work / 'result.json'
        if not result.exists():
            raise RuntimeError('probe wrote no result')
        return json.loads(result.read_text(encoding='utf-8'))
    finally:
        shutil.rmtree(work, ignore_errors=True)


EXPECTED = {
    'Crafting Atlas': "command='Crafting-Atlas'",
    'Open Web Crafting Atlas': "command='Open-Web-Crafting-Atlas'",
    'Open Wiki': "command='Open-Wiki'",
    'Unknown Button': '',
    'unknown_button': '',
    'Unlisted Button': '',
}


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument('--byond-bin', required=True, type=Path)
    parser.add_argument('--negative-control', action='store_true')
    args = parser.parse_args()
    source = (HERE / 'pre_fix_run_verb.dm.txt' if args.negative_control else SOURCE).read_text(encoding='utf-8')
    got = run(args.byond_bin, proc_text(source))
    expected = {
        name: {'accepted': bool(command), 'command': command}
        for name, command in EXPECTED.items()
    }
    # The historical fixture tests the Atlas name collision, not the newer
    # registration boundary. Only require that the known collision still fails.
    if args.negative_control:
        expected = {'Crafting Atlas': expected['Crafting Atlas']}
    wrong = {name: got.get(name) for name, want in expected.items() if got.get(name) != want}
    print(json.dumps({'commands': got, 'wrong': wrong}, indent=1))
    if args.negative_control:
        if not wrong:
            print('FAIL negative control: the pre-fix proc resolved every verb correctly')
            return 1
        print('PASS negative control: the pre-fix proc opened the wrong verb')
        return 0
    print('PASS' if not wrong else 'FAIL')
    return 0 if not wrong else 1


if __name__ == '__main__':
    raise SystemExit(main())
