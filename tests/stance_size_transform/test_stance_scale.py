"""Every stance transform on a human comes from one helper.

Running, walking, proning, prone movement, clicking while prone and the next
update_icons() used to each rebuild the mob's transform from a fresh matrix.
They disagreed: the prone click skipped Scale(size_multiplier) and turned a
west-facing body the other way from update_icons(), so a Tall or Short
character changed size and flipped a moment after every click until the next
icon update. Now /mob/living/human/proc/posture_transform() is the only stance
matrix and every caller applies it. Standard library source check; no BYOND.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
HELPER_FILE = 'code/game/mob/living/carbon/human/update_icons.dm'
CALLERS = (
    'code/_onclick/click.dm',
    'code/_onclick/hud/base_screen_objects.dm',
    'code/game/mob/mob_movement.dm',
    'code/game/mob/living/carbon/human/inventory.dm',
    HELPER_FILE,
)
# A stance transform is a fresh matrix translated by the prone offset or the
# standing height offset.
STANCE = re.compile(r'M\.Translate\(\s*(1,\s*-6|0,\s*16\*)')
HELPER = re.compile(r'^/mob/living/human/proc/posture_transform\(\)\n(.*?)(?=^\S)', re.S | re.M)


def read(rel):
    return (ROOT / rel).read_text(encoding='utf-8', errors='replace')


def helper_body(text):
    match = HELPER.search(text)
    return match.group(1) if match else None


def stance_outside_helper(text):
    body = helper_body(text)
    if body:
        text = text.replace(body, '')
    return STANCE.findall(text)


class StanceTransformTest(unittest.TestCase):
    def test_helper_scales_both_postures(self):
        body = helper_body(read(HELPER_FILE))
        self.assertIsNotNone(body, 'posture_transform() helper is missing')
        self.assertEqual(len(re.findall(r'M\.Scale\(\s*size_multiplier\s*\)', body)), 2, body)
        self.assertEqual(len(STANCE.findall(body)), 2, body)

    def test_prone_west_turn_matches_crawl(self):
        body = helper_body(read(HELPER_FILE))
        self.assertRegex(body, r'M\.Turn\(\(prone && !lying && dir == WEST\) \? -90 : 90\)')

    def test_no_stance_matrix_outside_helper(self):
        for rel in CALLERS:
            self.assertEqual(stance_outside_helper(read(rel)), [], f'{rel}: builds its own stance transform')

    def test_every_stance_path_applies_helper(self):
        expected = {
            'code/_onclick/click.dm': 1,
            'code/_onclick/hud/base_screen_objects.dm': 2,
            'code/game/mob/mob_movement.dm': 4,
            'code/game/mob/living/carbon/human/inventory.dm': 3,
        }
        for rel, count in expected.items():
            self.assertEqual(read(rel).count('update_posture_transform()'), count, rel)
        self.assertIn('transform = posture_transform()', read(HELPER_FILE))

    def test_prone_facing_redraws_at_once(self):
        text = read(HELPER_FILE)
        self.assertRegex(text, r'/mob/living/human/facedir\(var/ndir\)\n\tif \(prone && !lying\)\n\t\tndir = prone_facing_dir\(ndir\)')
        self.assertIn('update_posture_transform()', text.split('/mob/living/human/facedir(var/ndir)')[1].split('\n\n')[0])

    def test_mutation_without_helper_is_caught(self):
        sample = 'if (prone)\n\tvar/matrix/M = matrix()\n\tM.Turn(90)\n\tM.Translate(1,-6)\n\ttransform = M\n'
        self.assertTrue(stance_outside_helper(sample))


if __name__ == '__main__':
    unittest.main()
