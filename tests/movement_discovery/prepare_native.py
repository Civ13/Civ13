"""Prepare source only. There is deliberately no compile or execution option."""
import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess

from test_lifecycle import ANIMAL, HUMAN, FIXTURES, ROOT, TYPE, WRITES, load_audit, read, validate_guard, validate_production_inventory
from test_movement import body, legacy_body, validate_loop

HERE = Path(__file__).resolve().parent
CONTROLS = ('fixed', 'missing-add', 'missing-remove', 'deduplicate',
            'reverse-order', 'same-z', 'rng-order')


def procedure(path, signature):
    text = read(path).rstrip() + '\n'
    matches = re.findall(r'^' + re.escape(signature) + r'[^\n]*\n(?:\t[^\n]*\n|\n)*', text, re.M)
    if len(matches) != 1:
        raise ValueError(f'Expected one procedure: {path}:{signature}')
    return matches[0].rstrip() + '\n'


def between(path, start, stop):
    text = read(path)
    if text.count(start) != 1:
        raise ValueError(f'Ambiguous lifecycle anchor: {path}:{start}')
    text = text.split(start, 1)[1].split(stop, 1)[0]
    return text


def production():
    audit = load_audit()
    validate_production_inventory(audit['references'])
    for guard in audit['guards']:
        validate_guard(guard['path'], read(guard['path']), guard)
    for path in (HUMAN, ANIMAL):
        validate_loop(path, read(path))
    helpers = read('code/_helpers/mobs.dm')
    helpers = helpers[helpers.index('/proc/register_living_mob('):]
    # This is the complete final block in the current file, with all eight
    # membership/switch helpers. Refuse extension rather than absorb new code.
    assert helpers.rstrip().endswith('return global.dead_mob_list.Remove(src)')
    pieces = [helpers]
    for path, signature in (
        ('code/game/mob/mob.dm', '/mob/New()'),
        ('code/game/mob/mob.dm', '/mob/Destroy()'),
        ('code/_helpers/unsorted.dm', '/mob/dview/New()'),
        ('code/game/mob/living/carbon/human/announcer.dm', '/mob/living/human/announcer/New('),
    ):
        pieces.append(procedure(path, signature))
    # Actual contiguous membership-transition fragments. Surrounding gameplay
    # side effects are not executed by these explicitly named fragment adapters.
    pieces.append('/mob/proc/probe_death_fragment()\n' + between(
        'code/game/mob/death.dm', '\ttimeofdeath = world.time\n', '\n\tupdateicon()').split('\n', 1)[1] + '\n')
    pieces.append('/mob/living/proc/probe_rejuvenate_fragment()\n' + between(
        'code/game/mob/living/living.dm', '\t// remove the character from the list of the dead\n',
        '\n\t// make the icons look correct') + '\n')
    pieces.append('/mob/living/simple_animal/proc/probe_life_fragment()\n' + between(
        'code/game/mob/living/simple_animal/simple_animal.dm', '\t//Health\n', '\n\tif (health > maxHealth)') + '\n')
    admin_text = read('code/modules/admin/verbs/modifyvariables.dm')
    start = admin_text.index('\t\t\t\tif ((O.vars[variable] == 2)')
    end = admin_text.index('\n\t\t\telse\n\t\t\t\tvar/var_new =  input', start)
    admin = admin_text[start:end]
    admin = '\n'.join(line[3:] if line.startswith('\t\t\t') else line for line in admin.splitlines())
    pieces.append('/proc/probe_admin_fragment(var/datum/O, var/var_new)\n\tvar/variable = "stat"\n' + admin + '\n')
    # The scheduler now rejects null/nonliving entries before its single
    # deleted-entry cleanup. Adapt only the source's real membership write,
    # not the scheduler guards or side effects. Null clearing is exercised
    # against the helper directly by the fixture, not a nonexistent call site.
    cleanup = next(g for g in audit['guards'] if g['label'] == 'deleted-cleanup-after-null-filter')
    lines = [line.strip() for line in cleanup['body'].splitlines()
             if line.strip() == 'unregister_living_mob(M)']
    if len(lines) != 1:
        raise ValueError('Expected one registered deleted-entry cleanup')
    pieces.append('/proc/probe_deleted_cleanup_membership(var/mob/M)\n\t' + lines[0] + '\n')
    restored = between('code/processes/human_corpse_decay.dm',
        '\t// Restore durable age; bind fresh runtime epochs after native graph loading.\n', '\n\t\tupdate_canmove()')
    assert restored.startswith('\tunregister_corpse_decay()\n')
    pieces.append('/mob/living/human/proc/probe_after_load_fragment()\n' + restored.split('\n', 1)[1] + '\n')
    for mode in ('legacy', 'candidate'):
        for path, kind in (('code/game/mob/mob_movement.dm', 'human'),
                           ('code/modules/1713/complex_animal/_backend.dm', 'animal')):
            fragment = legacy_body(path) if mode == 'legacy' else body(path, read(path))
            if kind == 'human':
                signature = f'/mob/proc/probe_{mode}_human()\n\tvar/mob/mob = src\n'
            else:
                signature = f'{TYPE}/proc/probe_{mode}_animal()\n'
                assert fragment.count('\t..()\n') == 1
                fragment = fragment.replace('\t..()\n', '\tprobe_parent_move()\n', 1)
            pieces.append(signature + fragment)
    return '\n'.join(pieces)


def controlled(source, control):
    replacements = {
        'missing-add': ('\t\tglobal.living_complex_animal_list += M', '\t\treturn'),
        'missing-remove': ('\t\tglobal.living_complex_animal_list.Remove(M)', '\t\treturn'),
        'deduplicate': ('global.living_complex_animal_list += M', 'global.living_complex_animal_list |= M'),
        'reverse-order': ('global.living_complex_animal_list += M', 'global.living_complex_animal_list.Insert(1, M)'),
        'rng-order': ('if (prob(90)', 'if (prob(89)'),
    }
    if control in replacements:
        old, new = replacements[control]
        assert source.count(old) == (2 if control == 'rng-order' else 1)
        # Mutate candidate only; never weaken the legacy oracle.
        if control == 'rng-order':
            index = source.index(f'{TYPE}/proc/probe_candidate_animal()')
            source = source[:index] + source[index:].replace(old, new, 1)
        else:
            source = source.replace(old, new, 1)
    elif control == 'same-z':
        index = source.index('/mob/proc/probe_candidate_human()')
        old = '\tfor (var/mob/living/simple_animal/complex_animal/C in living_complex_animal_list)\n'
        assert source[index:].count(old) == 1
        source = source[:index] + source[index:].replace(old, old + '\t\tif (C.z != mob.z)\n\t\t\tcontinue\n', 1)
    elif control != 'fixed':
        raise ValueError(control)
    return source


def checkout_metadata():
    # These are provenance for packets, not semantic test inputs. No historical
    # Git objects or uninterrupted checkout history are required.
    return (
        subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=ROOT, text=True).strip(),
        subprocess.check_output(['git', 'diff', 'HEAD'], cwd=ROOT),
    )


def stage(output, control='fixed'):
    if control not in CONTROLS:
        raise ValueError(control)
    output = Path(output)
    # Refuse reuse/overwrite; staging never invokes an engine or shell helper.
    source = controlled(production(), control)
    head_sha, dirty_patch = checkout_metadata()
    audit = load_audit()
    output.mkdir(parents=True, exist_ok=False)
    (output / 'production.dm').write_text(source, encoding='utf-8')
    (output / 'probe.dm').write_bytes((HERE / 'native_probe.dm').read_bytes())
    (output / 'expectations.json').write_bytes((HERE / 'native_expectations.json').read_bytes())
    (output / 'probe.dme').write_text('#define TRUE 1\n#define FALSE 0\n#define CONSCIOUS 0\n#define UNCONSCIOUS 1\n#define DEAD 2\n#define prob(P) probe_prob(C, P)\n#include "probe.dm"\n#include "production.dm"\n', encoding='utf-8')
    (output / 'dirty.patch').write_bytes(dirty_patch)
    sha = lambda data: hashlib.sha256(data).hexdigest()
    manifest = {
        'head_sha': head_sha,
        'oracle_provenance': 'bc7209b23d4ee39651a736a7a9ddb1d1081166ac (frozen movement excerpts only)',
        'audit_source_sha': audit['source_review_sha'],
        'contract_fixture_sha256': {p.name: sha(p.read_bytes()) for p in sorted(FIXTURES.iterdir())},
        'control': control, 'prepared_only': True,
        'preparer_sha256': sha(Path(__file__).read_bytes()),
        'compiled': False, 'executed': False, 'world': [16, 16, 2],
        'write_inventory': WRITES,
        'source_sha256': {path: sha((ROOT / path).read_bytes()) for path in sorted({row[0] for row in audit['references']})},
        'oracle_source_sha256': {path: sha(legacy_body(path).encode()) for path in (
            'code/game/mob/mob_movement.dm', 'code/modules/1713/complex_animal/_backend.dm')},
        'files': {p.name: sha(p.read_bytes()) for p in output.iterdir() if p.is_file()},
        'limits': 'Source only; lifecycle fragments and external effects adapted; no native/full-game acceptance.',
    }
    (output / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n', encoding='utf-8')
    return manifest


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--control', choices=CONTROLS, default='fixed')
    args = parser.parse_args()
    print(json.dumps(stage(args.output, args.control), indent=2))
