"""Offline projection of the production charge and shock decision; no BYOND runtime."""
from pathlib import Path
import sys
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project

SOURCE = ROOT / 'code/game/objects/items/weapons/defib.dm'
PROC = '/obj/item/weapon/shockpaddles/proc/do_revive'


class ChargeRevalidation(unittest.TestCase):
    def run_charge(self, revived_during_wait):
        patient = SimpleNamespace(stat='dead', visible_message=lambda *args: None)
        trace = []

        def wait(*args):
            if revived_during_wait:
                patient.stat = 'alive'
            return True

        def eligible(target):
            trace.append(('eligibility', target.stat))
            return None if target.stat == 'dead' else 'vital signs detected'

        env = dict(do_after=wait, can_defib=eligible, can_revive=lambda target: None,
                   checked_use=lambda amount: trace.append(('charge', amount)) or True,
                   make_announcement=lambda *args: trace.append(('announcement',) + args),
                   playsound=lambda *args: None, get_turf=lambda obj: None,
                   set_cooldown=lambda *args: None, chargetime=20, chargecost=100,
                   cooldowntime=60, src=object())
        source = SOURCE.read_text(encoding='utf-8-sig')
        body = extract(source, PROC)
        start = body.index('\tif(!do_after(user, chargetime, H))')
        end = body.index('\tH.apply_damage(', start)
        segment = body[start:end]
        projected = project('/probe()\n' + segment + '\n\treturn TRUE\n', '/probe',
                            'H, user, error', env)
        result = projected(patient, object(), None)
        return result, trace

    def test_patient_revived_while_charging_is_not_shocked(self):
        result, trace = self.run_charge(True)
        self.assertFalse(result)
        self.assertNotIn(('charge', 100), trace)
        self.assertIn(('eligibility', 'alive'), trace)

    def test_still_dead_patient_can_be_shocked(self):
        result, trace = self.run_charge(False)
        self.assertTrue(result)
        self.assertIn(('charge', 100), trace)


if __name__ == '__main__':
    unittest.main()
