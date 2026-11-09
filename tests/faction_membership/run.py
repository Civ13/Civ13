"""Native faction membership and recruitment-authority probe (#4237 stage 1).

Compiles the production faction_membership.dm, faction_leaving_proc() from
factions.dm and is_faction_leader() from research_faction.dm with small stubs
into a temporary fixture. DreamDaemon runs it with -safe on port 0 (no
clients) and the probe writes result.txt.
"""
import argparse
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent
MEMBERSHIP = 'code/game/mob/groups/faction_membership.dm'
FACTIONS = 'code/game/mob/groups/factions.dm'
RESEARCH = 'code/modules/research_tree/research_faction.dm'

# Each control breaks one rule; the probe must then fail.
CONTROLS = {
    'cooldown': (MEMBERSHIP, '\tif (faction_rejoin_blocked(faction))\n', '\tif (FALSE)\n'),
    'privileges': (MEMBERSHIP, '\tclear_faction_privileges()\n\tcivilization = faction\n', '\tcivilization = faction\n'),
    'leader_flag': (MEMBERSHIP, '\treturn is_faction_leader(H, faction)\n', '\treturn H.leader || is_faction_leader(H, faction)\n'),
    'switch': (MEMBERSHIP, '\tif (civilization && civilization != "none" && !allow_switch)\n', '\tif (FALSE)\n'),
}


def read(path, control=None):
    text = (ROOT / path).read_text(encoding='utf-8').replace('\r\n', '\n')
    if control:
        target, old, new = CONTROLS[control]
        if target == path:
            if text.count(old) != 1:
                raise RuntimeError(f'Control target missing or ambiguous: {control}')
            text = text.replace(old, new, 1)
    return text


def proc_text(source, signature):
    start = source.index(signature)
    body = source.index('\n', start) + 1
    end = re.compile(r'^\S', re.M).search(source, body)
    return source[start:end.start() if end else len(source)]


def build(directory, control):
    (directory / 'membership.dm').write_text(read(MEMBERSHIP, control), encoding='utf-8')
    (directory / 'leaving.dm').write_text(proc_text(read(FACTIONS, control), '/mob/living/human/proc/faction_leaving_proc()'), encoding='utf-8')
    (directory / 'leader.dm').write_text(proc_text(read(RESEARCH, control), '/obj/map_metadata/proc/is_faction_leader('), encoding='utf-8')
    shutil.copy(HERE / 'probe.dm', directory / 'probe.dm')
    (directory / 'fixture.dme').write_text(''.join(f'#include "{name}"\n' for name in ('probe.dm', 'membership.dm', 'leaving.dm', 'leader.dm')), encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--negative-control', choices=CONTROLS)
    args = parser.parse_args()
    exe = '.exe' if os.name == 'nt' else ''
    compiler = args.byond_bin / (('dm' if os.name == 'nt' else 'DreamMaker') + exe)
    daemon = args.byond_bin / (('dd' if os.name == 'nt' else 'DreamDaemon') + exe)
    with tempfile.TemporaryDirectory(prefix='faction_membership_') as temp:
        directory = Path(temp)
        build(directory, args.negative_control)
        compiled = subprocess.run([str(compiler), '-max_errors', '0', 'fixture.dme'], cwd=directory, capture_output=True, text=True, timeout=300)
        if compiled.returncode != 0 or ' 0 errors' not in compiled.stdout:
            print(compiled.stdout + compiled.stderr)
            return 2
        subprocess.run([str(daemon), 'fixture.dmb', '0', '-safe', '-invisible', '-close', '-logself'], cwd=directory, capture_output=True, text=True, timeout=120)
        result = directory / 'result.txt'
        text = result.read_text(encoding='utf-8') if result.exists() else 'FAIL: probe wrote no result\n'
    print(text.strip())
    passed = text.strip().endswith('PASS')
    if args.negative_control:
        print('control reached its failure' if not passed else 'CONTROL DID NOT FAIL')
        return 0 if not passed else 1
    return 0 if passed else 1


if __name__ == '__main__':
    sys.exit(main())
