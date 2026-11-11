"""Check the appearance editor sends and accepts species gender choices, from source, not BYOND."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MODULE = ROOT / 'code/modules/nano/modules/appearance_changer.dm'
SPECIES = ROOT / 'code/game/mob/living/carbon/human/species/species.dm'
TSX = ROOT / 'tgui/src/interfaces/Standard.tsx'
TMPL = ROOT / 'UI/templates/appearance_changer.tmpl'

# The pre-fix data block, frozen as a negative control.
OLD_DATA = '''	data["change_gender"] = can_change(APPEARANCE_GENDER)
	data["change_skin_tone"] = can_change_skin_tone()
'''


def data_problems(source):
    problems = []
    block = re.search(r'data\["change_gender"\] = can_change\(APPEARANCE_GENDER\)\n((?:\t.*\n)*?)\tdata\["change_skin_tone"\]', source)
    if not block:
        return ['no gender data block']
    body = block.group(1)
    if 'for (var/gender_key in owner.species.genders)' not in body:
        problems.append('genders are not listed from the species')
    if '"gender_name" =' not in body or '"gender_key" = gender_key' not in body:
        problems.append('entries lack gender_name/gender_key')
    if 'data["genders"] = genders' not in body:
        problems.append('genders are not sent')
    return problems


class AppearanceGendersTest(unittest.TestCase):
    def test_species_defines_genders(self):
        self.assertIn('var/list/genders = list(MALE, FEMALE)', SPECIES.read_text(encoding='utf-8'))

    def test_interfaces_read_gender_fields(self):
        self.assertIn("'genders', 'gender_name', 'gender_key'", TSX.read_text(encoding='utf-8'))
        tmpl = TMPL.read_text(encoding='utf-8')
        self.assertIn('data.genders', tmpl)
        self.assertIn('value.gender_key', tmpl)

    def test_server_sends_gender_choices(self):
        self.assertEqual(data_problems(MODULE.read_text(encoding='utf-8')), [])

    def test_topic_accepts_only_species_genders(self):
        self.assertIn('(href_list["gender"] in owner.species.genders)', MODULE.read_text(encoding='utf-8'))

    def test_negative_control_old_data_fails(self):
        self.assertTrue(data_problems(OLD_DATA))


if __name__ == '__main__':
    unittest.main()
