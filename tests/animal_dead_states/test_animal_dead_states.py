"""Offline checks that dead animals keep their dead sprite; stdlib only, no BYOND.

run.py is the runtime sweep. These tests read the DM source and the DMI files:
every gap in known_missing.txt must still be missing (so a drawn sprite drops
its entry), no update_icons() override may put the standing sprite back on a
corpse, and no grow-up or regrowth timer may redraw a corpse as a living
animal. The negative-control target in run.py must still exist.
"""
import ast
import re
import struct
import unittest
import zlib
from pathlib import Path

HERE = Path(__file__).resolve().parent
ROOT = HERE.parents[1]
BASE = '/mob/living/simple_animal'


def run_constant(name):
    tree = ast.parse((HERE / 'run.py').read_text(encoding='utf-8'))
    for node in tree.body:
        if isinstance(node, ast.Assign) and any(getattr(t, 'id', None) == name for t in node.targets):
            return ast.literal_eval(node.value)
    raise KeyError(name)


CONTROL = run_constant('CONTROL')
TIMER_FILES = (
    'code/game/mob/living/simple_animal/friendly/deer.dm',
    'code/game/mob/living/simple_animal/friendly/farm_animals.dm',
    'code/game/mob/living/simple_animal/hostile/buffalo.dm',
)


def dmi_states(path, cache={}):
    if path not in cache:
        data = path.read_bytes()
        states = set()
        offset = 8
        while offset + 8 <= len(data):
            length, kind = struct.unpack('>I4s', data[offset:offset + 8])
            chunk = data[offset + 8:offset + 8 + length]
            offset += 12 + length
            if kind == b'zTXt':
                text = zlib.decompress(chunk[chunk.index(0) + 2:]).decode('utf-8')
                states = set(re.findall(r'^state = "(.*)"$', text, re.M))
                break
        cache[path] = states
    return cache[path]


def known_entries():
    entries = []
    for line in (HERE / 'known_missing.txt').read_text(encoding='utf-8').splitlines():
        line = line.split('#', 1)[0].strip()
        if line:
            entries.append(tuple(line.split()))
    return entries


def included_sources():
    dme = (ROOT / 'civ13.dme').read_text(encoding='utf-8')
    for rel in re.findall(r'^#include "(.*\.dm)"\s*$', dme, re.M):
        path = ROOT / rel.replace('\\', '/')
        if path.exists():
            yield path


def blocks():
    """Yields (path, header, body lines) for each top-level DM block."""
    for path in included_sources():
        header, body = None, []
        for line in path.read_text(encoding='utf-8', errors='replace').splitlines():
            if line and not line[0].isspace() and not line.startswith('//') and not line.startswith('#'):
                if header is not None:
                    yield path, header, body
                header, body = line.split('//', 1)[0].rstrip(), []
            elif header is not None:
                body.append(line)
        if header is not None:
            yield path, header, body


def animal_path(header):
    path = '/' + header.lstrip('/')
    if path == BASE or path.startswith(BASE + '/'):
        return path
    return None


def collect():
    """Type var defaults and procs for every simple animal."""
    defaults, procs = {}, []
    for path, header, body in blocks():
        animal = animal_path(header)
        if not animal:
            continue
        if '(' in header:
            owner = re.sub(r'/(proc|verb)/[^/]*$', '', animal.split('(', 1)[0])
            owner = owner.rsplit('/', 1)[0]
            procs.append((path, animal.split('(', 1)[0], owner, body))
            continue
        values = defaults.setdefault(animal.rstrip('/'), {})
        for line in body:
            found = re.match(r'\t(?:var/)?(icon|icon_dead|icon_state)\s*=\s*(.+?)\s*(?://.*)?$', line)
            if found:
                values[found.group(1)] = found.group(2)
    return defaults, procs


class KnownMissingTest(unittest.TestCase):
    def test_entries_are_reviewed_gaps(self):
        entries = known_entries()
        self.assertEqual(len(entries), len(set(entries)))
        for entry in entries:
            self.assertEqual(len(entry), 5, entry)
            kind, type_path, variant, state, icon = entry
            self.assertEqual(kind, 'MISSING', entry)
            self.assertTrue(type_path.startswith(BASE), entry)
            self.assertIn(variant, ('adult', 'lamb', 'calf', 'piglet', 'babydeer', 'sheared'), entry)
            self.assertTrue((ROOT / icon).exists(), entry)
            self.assertNotIn(state, dmi_states(ROOT / icon), f'{entry} now exists; drop it from known_missing.txt')


class DeadStateTest(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.defaults, cls.procs = collect()

    def test_found_the_animals(self):
        for path in ('/mob/living/simple_animal/sheep', '/mob/living/simple_animal/camel',
                     '/mob/living/simple_animal/cattle/cow'):
            self.assertIn(path, self.defaults)

    def test_update_icons_overrides_keep_the_corpse(self):
        problems = []
        for path, name, owner, body in self.procs:
            if not name.endswith('/update_icons'):
                continue
            text = '\n'.join(body)
            if re.search(r'^\s*icon_state\s*=', text, re.M) and not re.search(r'\bstat\b', text):
                problems.append(f'{path.relative_to(ROOT)}: {name} sets icon_state without checking stat')
            if owner != BASE and '..()' in text:
                # The base proc shows icon_dead on a corpse; nothing may overwrite it afterwards.
                after = text.split('..()', 1)[1]
                for line in after.splitlines():
                    if re.match(r'\s*icon_state\s*=\s*(?!icon_dead)', line) and not re.search(r'\bstat\b', after):
                        problems.append(f'{path.relative_to(ROOT)}: {name} sets icon_state after ..()')
                        break
        self.assertEqual(problems, [])

    def test_sheep_and_camel_follow_the_base_proc(self):
        source = (ROOT / 'code/game/mob/living/simple_animal/friendly/farm_animals.dm').read_text(encoding='utf-8')
        for name in ('sheep', 'camel'):
            body = source.split(f'/mob/living/simple_animal/{name}/update_icons()\n', 1)[1].split('\n/', 1)[0]
            self.assertIn('if (stat != DEAD)', body, name)
            self.assertTrue(body.rstrip().splitlines()[-1].strip().startswith('..()'), name)

    def test_negative_control_target_exists(self):
        path, old, new = CONTROL
        self.assertEqual((ROOT / path).read_text(encoding='utf-8').count(old), 1)
        self.assertNotEqual(old, new)

    def test_timers_leave_corpses_alone(self):
        problems = []
        for rel in TIMER_FILES:
            lines = (ROOT / rel).read_text(encoding='utf-8').splitlines()
            for number, line in enumerate(lines):
                if re.match(r'\s*spawn\((3000|4800)\)\s*$', line):
                    following = lines[number + 1].strip() if number + 1 < len(lines) else ''
                    if not following.startswith('if (stat == DEAD)'):
                        problems.append(f'{rel}:{number + 1} timer does not skip a dead animal')
        self.assertEqual(problems, [])


if __name__ == '__main__':
    unittest.main()
