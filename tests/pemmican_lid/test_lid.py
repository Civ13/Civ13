"""Check pemmican mixing needs an open glass container, from source, not BYOND."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/complex_production.dm'
DECL = '/obj/item/weapon/reagent_containers/food/snacks/driedmeat/minced_driedmeat/attack_self(mob/user)'

# The pre-fix action, frozen as a negative control.
OLD_BODY = '''
		if (G.reagents.get_reagent_amount("fat_oil") >= 5)
			if(do_after(user, 90))
				G.reagents.remove_reagent("fat_oil", 5)
'''


def action_body(source):
    start = source.index(DECL)
    end = source.find('\n/', start + len(DECL))
    return source[start:end]


def lid_problems(body):
    problems = []
    wait = body.find('do_after(user, 90)')
    consume = body.find('remove_reagent("fat_oil", 5)')
    before = body[:wait]
    after = body[wait:consume]
    if 'G.is_open_container()' not in before:
        problems.append('a closed container can start mixing')
    if 'G.is_open_container()' not in after:
        problems.append('closing the lid during the wait still mixes')
    if 'get_reagent_amount("fat_oil") < 5' not in after:
        problems.append('oil is not rechecked after the wait')
    return problems


class PemmicanLidTest(unittest.TestCase):
    def test_mixing_requires_open_container(self):
        self.assertEqual(lid_problems(action_body(SOURCE.read_text(encoding='utf-8'))), [])

    def test_negative_control_old_action_fails(self):
        self.assertEqual(len(lid_problems(OLD_BODY)), 3)


if __name__ == '__main__':
    unittest.main()
