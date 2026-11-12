"""Check Moldy Men earn sabotage points for destroying school property, from source, not BYOND."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HOOKS = ROOT / 'code/modules/1713/moldy_men/moldy_men_hooks.dm'
STRUCTURES = ROOT / 'code/game/objects/structures.dm'
WIZARD_BOY = ROOT / 'code/game/objects/map_metadata/wizard_boy.dm'

# Pre-fix Destroy, frozen as a negative control: nothing ever reached the hooks.
OLD_DESTROY = '''/obj/structure/Destroy()
	if (parts)
		new parts(loc)
	..()
'''


def proc_body(source, decl):
    start = source.index(decl)
    end = source.find('\n/', start + 1)
    return source[start:end if end != -1 else len(source)]


def destroy_awards(destroy, hooks, obj, actor):
    """Replay Destroy -> moldy_school_property_destroyed -> moldy_school_destroyed; return points."""
    if 'if (school_property)' not in destroy or 'moldy_school_property_destroyed(src)' not in destroy:
        return 0
    if not obj['school_property']:
        return 0
    obj['school_property'] = 'school_property = FALSE' not in destroy
    gate = proc_body(hooks, '/proc/moldy_school_property_destroyed(')
    distance = int(re.search(r'get_dist\(H, S\) > (\d+)', gate).group(1))
    if not actor['human'] or not actor['conscious'] or actor['z'] != obj['z'] or actor['dist'] > distance:
        return 0
    if not actor['moldy']:
        return 0
    return int(re.search(r'award_points\((\d+), "School object destroyed"\)', hooks).group(1))


MOLDY = {'human': True, 'conscious': True, 'z': 1, 'dist': 1, 'moldy': True}


class SchoolPropertyTest(unittest.TestCase):
    def setUp(self):
        self.hooks = HOOKS.read_text(encoding='utf-8')
        self.destroy = proc_body(STRUCTURES.read_text(encoding='utf-8'), '/obj/structure/Destroy()')

    def obj(self, school=True):
        return {'school_property': school, 'z': 1}

    def test_moldy_man_destroying_school_property_scores_once(self):
        thing = self.obj()
        self.assertEqual(destroy_awards(self.destroy, self.hooks, thing, MOLDY), 25)
        self.assertEqual(destroy_awards(self.destroy, self.hooks, thing, MOLDY), 0)

    def test_ineligible_destruction_scores_nothing(self):
        self.assertEqual(destroy_awards(self.destroy, self.hooks, self.obj(False), MOLDY), 0)
        for change in ({'moldy': False}, {'dist': 8}, {'z': 2}, {'conscious': False}, {'human': False}):
            with self.subTest(change=change):
                self.assertEqual(destroy_awards(self.destroy, self.hooks, self.obj(), dict(MOLDY, **change)), 0)

    def test_only_round_start_school_areas_are_marked(self):
        mark = proc_body(self.hooks, '/obj/map_metadata/wizard_boy/proc/mark_school_property()')
        self.assertIn('istype(A, /area/caribbean/roofed)', mark)
        self.assertIn('istype(A, /area/caribbean/houses)', mark)
        self.assertIn('S.school_property = TRUE', mark)
        self.assertIn('/obj/structure/var/school_property = FALSE', self.hooks)
        new = WIZARD_BOY.read_text(encoding='utf-8')
        self.assertRegex(new, r'spawn\(30\)\n\t\t\tload_houses\(\)\n\t\t\tmark_school_property\(\)')

    def test_negative_control_old_destroy_never_scores(self):
        self.assertEqual(destroy_awards(OLD_DESTROY, self.hooks, self.obj(), MOLDY), 0)


if __name__ == '__main__':
    unittest.main()
