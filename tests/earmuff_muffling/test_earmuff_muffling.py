"""Source-projected human ear status + parent disability sequence; not native BYOND."""
import importlib.util
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
HUMAN = ROOT / 'code/game/mob/living/carbon/human/human_life.dm'
LIVING = ROOT / 'code/game/mob/living/life.dm'
SPEC = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
EAR_TYPE = '/obj/item/clothing/ears/earmuffs'


def make_tick(human):
    parent = LIVING.read_text()
    life = parent[parent.index('/mob/living/Life()'):parent.index('/mob/living/proc/handle_breathing()')]
    assert life.index('if (handle_regular_status_updates())') < life.index('\n\t\thandle_disabilities()')
    ordinary = human.split('\t\t//Ears\n', 1)[1].split('\n\t\t//Resting', 1)[0]
    ordinary = '\n'.join(line[1:] for line in ordinary.splitlines()).replace(
        'muffled ? TRUE : FALSE', 'TRUE if muffled else FALSE')
    parent_ears = parent.split('\t//Ears\n', 1)[1].split('\n//this handles hud updates', 1)[0]
    finish = human.split('/mob/living/human/handle_disabilities()\n', 1)[1].split('\t//Vision\n', 1)[0]
    assert finish.startswith('\t..()\n')
    finish = finish[len('\t..()\n'):]
    if '/mob/living/human/proc/earmuffs_equipped()' in human:
        equipped = ADAPTER.project(human.replace(EAR_TYPE, 'EARMUFFS'),
                                   '/mob/living/human/proc/earmuffs_equipped',
                                   'l_ear, r_ear, istype, EARMUFFS', {})
    else:
        equipped = lambda *_: False

    source = ('/tick()\n' + ordinary + '\n' + parent_ears + '\n' + finish
              + '\treturn (ear_deaf, ear_damage)\n').replace(EAR_TYPE, 'EARMUFFS')
    source = source.replace('setEarDamage(-1, max(ear_deaf, TRUE))', 'ear_deaf = max(ear_deaf, TRUE)')
    source = source.replace('adjustEarDamage(-0.05,-1)',
                            'ear_damage = max(FALSE, ear_damage-0.05)\n\t\t\tear_deaf = max(FALSE, ear_deaf-1)')
    args = 'ear_deaf, ear_damage, sdisabilities, find_trait, earmuffs_equipped, DEAF, l_ear, r_ear, istype, EARMUFFS'
    projected = ADAPTER.project(source, '/tick', args, {})

    def tick(deaf=0, damage=0, left=False, right=False, trait=False, disability=False):
        istype = lambda item, path: item == path
        return projected(deaf, damage, int(disability), lambda _: trait,
                         lambda: equipped(left, right, istype, True), 1, left, right, istype, True)
    return tick


class EarmuffTests(unittest.TestCase):
    def test_either_ear_remains_muffled_after_each_full_tick_and_then_recovers(self):
        tick = make_tick(HUMAN.read_text())
        for left, right in ((True, False), (False, True)):
            deaf, damage = 0, 5
            for _ in range(3):
                deaf, damage = tick(deaf, damage, left=left, right=right)
                self.assertEqual(deaf, 1)
            self.assertAlmostEqual(damage, 4.4)
            self.assertEqual(tick(deaf, damage)[0], 0)

    def test_long_deafness_and_permanent_flags_are_not_replaced(self):
        tick = make_tick(HUMAN.read_text())
        self.assertEqual(tick(7, 23, left=True)[0], tick(7, 23)[0])
        self.assertEqual(tick(7, 23, left=True)[0], 5)
        self.assertEqual(tick(5, 23)[0], 3)
        self.assertEqual(tick(7, 110, right=True)[0], 6)
        self.assertEqual(tick(7, 23, right=True, disability=True)[0], 7)
        self.assertEqual(tick(0, 23, trait=True)[0], 1)

    def test_missing_post_decay_hook_negative_control_loses_equipment_floor(self):
        text = HUMAN.read_text()
        hook = '\tif (ear_deaf < TRUE && earmuffs_equipped())\n\t\tear_deaf = TRUE\n'
        self.assertEqual(text.count(hook), 1)
        mutant = make_tick(text.replace(hook, '', 1))
        self.assertEqual(mutant(right=True)[0], 0)


if __name__ == '__main__':
    unittest.main()
