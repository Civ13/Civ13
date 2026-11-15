"""Source contracts for the shared faction grace wall.

legacy_bodies.json freezes each map's pre-refactor check_caribbean_block body.
run.py compiles those bodies against the live helper and compares them in
DreamDaemon; these offline tests only check that every listed map still
dispatches to the helper and that no copy of a frozen body has come back.
"""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MAPS = ROOT / 'code/game/objects/map_metadata'
HERE = Path(__file__).resolve().parent
HEADER = '/check_caribbean_block(var/mob/living/human/H, var/turf/T)'
CALL = re.compile(r'^\treturn check_faction_grace_wall\(H, T, (faction1|faction2), (faction1|faction2|null)(, [^\n]*)?\)$')


def body(source, header):
    match = re.search(r'(?m)^' + re.escape(header) + r'\n((?:\t.*\n?|[ \t]*\n)*)', source)
    if not match:
        return None
    return match.group(1).rstrip('\n')


def errors(sources, entries):
    found = []
    helper = body(sources['_map_metadata.dm'], '/obj/map_metadata/proc/check_faction_grace_wall(var/mob/living/human/H, var/turf/T, one_faction, two_faction, grace_side = 1, wall_area = /area/caribbean/no_mans_land/invisible_wall, one_area = /area/caribbean/no_mans_land/invisible_wall/one, two_area = /area/caribbean/no_mans_land/invisible_wall/two)')
    if not helper:
        found.append('shared helper missing')
    for entry in entries:
        name = Path(entry['file']).name
        current = body(sources[name], entry['type'] + HEADER)
        if current is None or not CALL.match(current):
            found.append(f'{entry["type"]} must call check_faction_grace_wall')
    legacy = {entry['old'] for entry in entries}
    for name, source in sources.items():
        for old in legacy:
            if old + '\n' in source:
                found.append(f'{name} still carries a copied grace wall body')
                break
    return found


class GraceWallContracts(unittest.TestCase):
    def setUp(self):
        self.entries = json.loads((HERE / 'legacy_bodies.json').read_text(encoding='utf-8'))
        self.sources = {path.name: path.read_text(encoding='utf-8') for path in MAPS.rglob('*.dm')}

    def test_fixture_covers_each_map_once(self):
        types = [entry['type'] for entry in self.entries]
        self.assertEqual(len(types), len(set(types)))
        self.assertGreaterEqual(len(types), 50)

    def test_every_listed_map_uses_the_shared_helper(self):
        self.assertEqual(errors(self.sources, self.entries), [])

    def test_detects_reintroduced_copy(self):
        changed = dict(self.sources)
        entry = self.entries[0]
        name = Path(entry['file']).name
        changed[name] = changed[name] + '\n/obj/map_metadata/copy' + HEADER + '\n' + entry['old'] + '\n'
        self.assertTrue(errors(changed, self.entries))

    def test_detects_wrong_dispatch(self):
        changed = dict(self.sources)
        entry = self.entries[-1]
        name = Path(entry['file']).name
        current = body(changed[name], entry['type'] + HEADER)
        changed[name] = changed[name].replace(current, '\treturn FALSE', 1)
        self.assertTrue(errors(changed, self.entries))


if __name__ == '__main__':
    unittest.main()
