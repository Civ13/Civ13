"""Source-level checks for the distinct bell stand type descriptions."""
from pathlib import Path
import re
import unittest


ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/game/objects/structures/bells.dm'


def bell_type_properties():
    properties = {'obj/structure/bell_stand': {}, 'obj/structure/bell_stand/church': {}}
    current = None
    for line in SOURCE.read_text(encoding='utf-8').splitlines():
        if line and not line[0].isspace():
            current = line.lstrip('/') if line.lstrip('/') in properties else None
        elif current:
            match = re.fullmatch(r'\s*(name|desc)\s*=\s*"(.*)"\s*', line)
            if match:
                properties[current][match.group(1)] = match.group(2)
    base = properties['obj/structure/bell_stand']
    return base, {**base, **properties['obj/structure/bell_stand/church']}


class BellStandNames(unittest.TestCase):
    def test_ordinary_stand_retains_its_own_name_and_description(self):
        base, _ = bell_type_properties()
        self.assertEqual(base['name'], 'bell stand')
        self.assertEqual(base['desc'], 'Fire! Fire!')

    def test_church_bell_has_its_own_name_and_description(self):
        _, church = bell_type_properties()
        self.assertEqual(church['name'], 'church bell')
        self.assertEqual(church['desc'], 'A church bell. It looks like it could be <b>extremely</b> loud.')


if __name__ == '__main__':
    unittest.main()
