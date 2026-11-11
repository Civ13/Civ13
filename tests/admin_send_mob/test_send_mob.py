"""Check Admin Send Mob picks a turf from the selected area only, from source, not BYOND."""
import importlib.util
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/admin/verbs/adminjump.dm'
HELPER = ROOT / 'code/_helpers/areas.dm'
DECL = '/client/proc/sendmob'
spec = importlib.util.spec_from_file_location('dm_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)

# The pre-fix destination choice, frozen as a negative control.
OLD_BODY = '''
		if (config.allow_admin_jump)
			M.on_mob_jump()
			M.loc = pick(get_area_turfs(A))
'''


def destination_problems(body):
    """Return why Send Mob could land outside the chosen area instance or crash on an empty one."""
    problems = []
    if 'get_area_turfs(' in body:
        problems.append('uses the type-wide get_area_turfs helper')
    loop = re.search(r'for \(var/turf/T in A\.contents\)\s*\n\s*(\w+) \+= T', body)
    if not loop:
        return problems + ['does not collect turfs from A.contents']
    name = loop.group(1)
    guard = body.find('if (!%s.len)' % name)
    move = body.find('M.loc = pick(%s)' % name)
    jump = body.find('M.on_mob_jump()')
    if move == -1:
        problems.append('does not pick from the collected turfs')
    if guard == -1 or 'return' not in body[guard:move] or not (guard < jump < move):
        problems.append('does not stop before moving when the area has no turfs')
    return problems


class SendMobAreaTest(unittest.TestCase):
    def test_helper_is_type_wide(self):
        # Why the helper is unsuitable: it matches every area of the selected type, subtypes included.
        helper = HELPER.read_text(encoding='utf-8')
        self.assertIn('areatype = areatemp.type', helper)
        self.assertIn('if (istype(A, areatype))', helper)

    def test_send_mob_uses_selected_area_turfs(self):
        body = adapter.extract(SOURCE.read_text(encoding='utf-8'), DECL)
        self.assertEqual(destination_problems(body), [])

    def test_negative_control_old_body_fails(self):
        self.assertTrue(destination_problems(OLD_BODY))


if __name__ == '__main__':
    unittest.main()
