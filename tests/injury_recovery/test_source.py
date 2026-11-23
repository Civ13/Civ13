"""Offline source-contract and arithmetic checks; not native gameplay evidence."""
import importlib.util
from pathlib import Path
from types import SimpleNamespace
import unittest
ROOT = Path(__file__).resolve().parents[2]
def source(name):
    return (ROOT / name).read_text()
class Recovery(unittest.TestCase):
    def test_dispatch_covers_subtype_overrides(self):
        self.assertIn('I.process()\n\t\tI.recover_internal_damage()', source('code/game/mob/living/carbon/human/human_organs.dm'))
    def test_guards(self):
        body = source('code/modules/organs/organ.dm').split('/obj/item/organ/proc/recover_internal_damage()')[1]
        for guard in ('loc != owner', 'src in owner.internal_organs', 'owner.stat == DEAD', 'owner.inducedSSD', 'damage >= max_damage', 'ORGAN_DEAD | ORGAN_CUT_AWAY', 'rejecting', 'germ_level >= INFECTION_LEVEL_ONE', 'owner.bodytemperature < 170'):
            self.assertIn(guard, body)
        self.assertIn('is_broken() ? 0.005 : 0.01', body)
        self.assertIn('config.organ_regeneration_multiplier', body)
        self.assertIn('damage = max(0, damage - recovery', body)
    def test_partial_damage_and_severe_damage_converge(self):
        for initial in (0.001, 9, 29, 59):
            damage = initial
            for tick in range(20000):
                damage = max(0, damage - (0.005 if damage >= 30 else 0.01))
                if damage == 0:
                    break
            self.assertEqual(damage, 0)
    def test_healed_bleeding_records_do_not_emit_phantom_pain(self):
        src = source('code/modules/organs/organ_external.dm')
        self.assertIn('if (W.internal && W.damage > 0 && owner.bodytemperature >= 170)', src)
        self.assertIn('min(60, W.damage)', src)
    def test_internal_pain_scales_and_parent_is_checked(self):
        src = source('code/modules/organs/pain.dm')
        self.assertIn('if(parent)\n', src)
        self.assertIn('min(50, I.damage)', src)
        self.assertNotIn('never heals on its own', src)
        self.assertIn('min(9, damage)', source('code/modules/organs/brain.dm'))
        self.assertNotIn('damage--', source('code/modules/organs/brain.dm'))
    def test_periodic_internal_ache_reports_without_inflicting_pain(self):
        pain = source('code/modules/organs/pain.dm')
        emission = pain.split('/mob/living/human/proc/custom_pain(', 1)[1].split(
            '/mob/living/human/proc/handle_pain()', 1)[0]
        self.assertIn('if(!nohalloss && (power || flash_pain))', emission)
        self.assertIn('affecting.add_pain(ceil(power/2))', emission)
        self.assertIn('to_chat(src,', emission)

        spec = importlib.util.spec_from_file_location(
            'pain_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
        adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(adapter)
        adapter.FIELDS += ('internal_organs', 'get_organ')

        def run(pain_source):
            loop = pain_source.split('	// Damage to internal organs hurts a lot.\n', 1)[1]
            loop = loop.split('\n	if(prob(2))', 1)[0]
            limb = SimpleNamespace(pain=0)
            injury = SimpleNamespace(damage=35, status=0, parent_organ='chest')
            body = SimpleNamespace(internal_organs=[injury], get_organ=lambda _: limb)
            messages = []

            def report(_text, power, *, affecting, nohalloss=False):
                messages.append(power)
                if not nohalloss:
                    affecting.pain += (power + 1) // 2

            body.custom_pain = report
            projected = adapter.project(
                '/proc/periodic_ache(src)\n' + loop + '\n', '/proc/periodic_ache', 'src',
                dict(typed_iter=lambda items, _type: items, ORGAN_DEAD=1, prob=lambda _: True),
                method=True)
            projected(body)
            projected(body)
            injury.damage = 0
            projected(body)
            injury.damage, injury.status = 35, 1
            projected(body)
            return messages, limb.pain

        self.assertEqual(run(pain), ([35, 35], 0))
        feedback = pain.replace(', affecting = parent, nohalloss = TRUE)', ', affecting = parent)')
        self.assertNotEqual(feedback, pain)
        self.assertEqual(run(feedback), ([35, 35], 36))

if __name__ == '__main__':
    unittest.main()
