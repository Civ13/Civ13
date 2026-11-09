"""Native faction recruitment application probe (#4237 stages 2 and 4).

Compiles the production faction_recruitment.dm and faction_membership.dm with
faction_leaving_proc(), is_faction_leader(), faction_is_extant() and
faction_rename_assoc_key() copied from their files, plus small stubs, into a
temporary fixture. DreamDaemon runs it with -safe on port 0 (no clients) and
the probe writes result.txt.
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
RECRUITMENT = 'code/game/mob/groups/faction_recruitment.dm'
MEMBERSHIP = 'code/game/mob/groups/faction_membership.dm'
FACTIONS = 'code/game/mob/groups/factions.dm'
RESEARCH = 'code/modules/research_tree/research_faction.dm'
RENAME = 'code/game/mob/groups/faction_rename.dm'

# Each control breaks one rule; the probe must then fail.
CONTROLS = {
    'explicit-open': (RECRUITMENT, 'if (next["mode"] == RECRUIT_MODE_AUTO && !next["open"]', 'if (FALSE && !next["open"]'),
    'identity': (RECRUITMENT, '\tif (!H || !A || !H.recruitment_life_id || H.recruitment_life_id != A["life"])\n', '\tif (!H || !A)\n'),
    'revision': (RECRUITMENT, '\tif (P["revision"] != A["revision"])\n', '\tif (FALSE)\n'),
    'reviewer': (RECRUITMENT, '\tif (!can_recruit_for_faction(R, faction))\n\t\treturn "You can\'t review', '\tif (FALSE)\n\t\treturn "You can\'t review'),
    'leader-policy': (RECRUITMENT, '\tif (!is_faction_leader(H, faction) || H.stat == DEAD)\n', '\tif (H.stat == DEAD)\n'),
    'cooldown': (MEMBERSHIP, '\tif (faction_rejoin_blocked(faction))\n', '\tif (FALSE)\n'),
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
    research = read(RESEARCH, control)
    parts = {
        'recruitment.dm': read(RECRUITMENT, control),
        'membership.dm': read(MEMBERSHIP, control),
        'leaving.dm': proc_text(read(FACTIONS, control), '/mob/living/human/proc/faction_leaving_proc()'),
        'leader.dm': proc_text(research, '/obj/map_metadata/proc/is_faction_leader(') + '\n' + proc_text(research, '/proc/faction_is_extant('),
        'rename.dm': proc_text(read(RENAME, control), '/proc/faction_rename_assoc_key('),
    }
    for name, text in parts.items():
        (directory / name).write_text(text, encoding='utf-8')
    shutil.copy(HERE / 'probe.dm', directory / 'probe.dm')
    (directory / 'prelude.dm').write_text('#define DEAD 2\n#define QDELETED(X) (!X)\n', encoding='utf-8')
    (directory / 'fixture.dme').write_text(''.join(f'#include "{name}"\n' for name in ('prelude.dm', *parts, 'probe.dm')), encoding='utf-8')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--byond-bin', type=Path, required=True)
    parser.add_argument('--negative-control', choices=CONTROLS)
    args = parser.parse_args()
    exe = '.exe' if os.name == 'nt' else ''
    compiler = args.byond_bin / (('dm' if os.name == 'nt' else 'DreamMaker') + exe)
    daemon = args.byond_bin / (('dd' if os.name == 'nt' else 'DreamDaemon') + exe)
    with tempfile.TemporaryDirectory(prefix='faction_recruitment_') as temp:
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
