"""Source contracts for drinking from containers on help intent."""
from pathlib import Path
import re
import sys
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
SURGERY = (ROOT / "code/modules/surgery/surgery.dm").read_text(encoding="utf-8")
GLASS = (ROOT / "code/modules/reagents/reagent_containers/glass.dm").read_text(encoding="utf-8")


def do_surgery():
    match = re.search(r"(?m)^proc/do_surgery\(.*\n(?:(?:\t[^\n]*|)\n)*", SURGERY)
    assert match, "missing do_surgery"
    return match.group()


class DrinkingTests(unittest.TestCase):
    def test_skill_warning_only_after_step_applies(self):
        body = do_surgery()
        applies = body.index("S.can_use(user, M, zone, tool)")
        warning = body.index("not skilled enough")
        self.assertLess(applies, warning)
        self.assertEqual(body.count("not skilled enough"), 1)

    def test_own_mouth_with_open_container_drinks(self):
        body = do_surgery()
        guard = body.index('M == user && zone == "mouth"')
        self.assertLess(guard, body.index("for (var/datum/surgery_step/S in surgery_steps)"))
        self.assertIn("tool.is_open_container()", body[guard:guard + 200])

    def test_self_drink_message_names_the_drinker(self):
        self.assertIn("[user] drinks from \\the [src].", GLASS)
        self.assertNotIn("[src] drinks from \\the [src].", GLASS)

    def test_drinking_credits_half_the_amount_actually_swallowed(self):
        containers = (ROOT / 'code/modules/reagents/reagent_containers.dm').read_text(encoding='utf-8')
        feed = containers.split('/proc/standard_feed_mob(', 1)[1].split('\n/', 1)[0]
        self.assertIn('var/swallowed = reagents.trans_to_mob(target', feed)
        self.assertIn('if (swallowed > 0)\n\t\ttarget.bladder += swallowed / 2', feed)
        self.assertNotIn('target.bladder += amount_per_transfer_from_this', feed)
        taste = (ROOT / 'code/game/mob/living/carbon/taste.dm').read_text(encoding='utf-8')
        self.assertIn('var/swallowed = from.trans_to_holder(target,amount,multiplier,copy)', taste)
        self.assertIn('return swallowed', taste)
        holder = (ROOT / 'code/modules/reagents/Chemistry-Holder.dm').read_text(encoding='utf-8')
        self.assertIn('return C.ingest(src,R, amount, multiplier, copy, smoked)', holder)


class OrganSelectionsTests(unittest.TestCase):
    def setUp(self):
        sys.path.insert(0, str(ROOT / 'tests/save_movement'))
        import source_adapter
        self.adapter = source_adapter
        self.organs = (ROOT / 'code/modules/surgery/organs_internal.dm').read_text(encoding='utf-8')
        self.prefix = '/datum/surgery_step/internal/proc/'
        matching = self.project('organ_matches_selection', 'target, target_zone, I, cut_away', dict(
            QDELETED=lambda organ: organ is None or organ.deleted,
            ORGAN_CUT_AWAY=4,
            operation_site_open=lambda target, zone: zone in target.open_zones,
        ))
        self.resolve = self.project('current_zone_selection', 'target, target_zone, cut_away',
                                    dict(organ_matches_selection=matching))
        cleanup = source_adapter.extract(SURGERY, '/datum/surgery_status/proc/release_zone')
        cleanup = re.sub(r'(?m)^\t(selected_organs|in_progress) -= zone$', r'\tstage.\1.pop(zone, None)', cleanup)
        self.release = source_adapter.project('/release()\n' + cleanup + '\n', '/release', 'stage, zone', {})

    def project(self, proc, args, env):
        return self.adapter.project(self.organs, self.prefix + proc, args, env)

    def sample(self):
        class OrganSlots(dict):
            def __missing__(self, key):
                return None
        class Organ(SimpleNamespace):
            __eq__ = object.__eq__
            __ne__ = object.__ne__
        heart = Organ(parent_organ='chest', organ_tag='heart', status=4, deleted=False)
        brain = Organ(parent_organ='head', organ_tag='brain', status=0, deleted=False)
        stage = SimpleNamespace(in_progress={'chest': True, 'head': True},
                                selected_organs=OrganSlots(chest=heart, head=brain))
        target = SimpleNamespace(op_stage=stage, internal_organs_by_name={'heart': heart, 'brain': brain},
                                 open_zones={'chest', 'head'})
        return target, heart, brain

    def test_each_zone_resolves_its_own_selection_and_releases_independently(self):
        target, heart, brain = self.sample()
        self.assertIs(self.resolve(target, 'chest', True), heart)
        self.assertIs(self.resolve(target, 'head', False), brain)
        self.assertIsNone(self.resolve(target, 'head', True))
        self.release(target.op_stage, 'chest')
        self.assertIsNone(self.resolve(target, 'chest', True))
        self.assertIs(self.resolve(target, 'head', False), brain)
        self.assertEqual(set(target.op_stage.in_progress), {'head'})

    def test_stale_replaced_or_wrong_zone_selection_cannot_finish(self):
        target, heart, brain = self.sample()
        target.internal_organs_by_name['heart'] = type(heart)(**vars(heart))
        self.assertIsNone(self.resolve(target, 'chest', True))
        target.op_stage.selected_organs['head'] = heart
        self.assertIsNone(self.resolve(target, 'head', True))
        target.op_stage.selected_organs['head'] = brain
        target.open_zones.remove('head')
        self.assertIsNone(self.resolve(target, 'head', False))
        target.open_zones.add('head')
        brain.deleted = True
        self.assertIsNone(self.resolve(target, 'head', False))

    def test_zone_is_reserved_before_prompt_and_released_on_rejection(self):
        body = do_surgery()
        self.assertLess(body.index('if (zone in stage.in_progress)'), body.index('stage.in_progress += zone'))
        self.assertLess(body.index('stage.in_progress += zone'), body.index('S.can_use(user, M, zone, tool)'))
        self.assertIn('stage.release_zone(zone)\n\t\t\treturn TRUE', body)
        self.assertLess(body.index('S.end_step(user, M, zone, tool)'), body.rindex('stage?.release_zone(zone)'))
        pick = self.adapter.extract(self.organs, self.prefix + 'select_organ')
        self.assertLess(pick.index('choice in options'), pick.index('stage.selected_organs[target_zone]'))
        self.assertIn('return SURGERY_FAILURE', pick)
        self.assertNotIn('op_stage.current_organ', self.organs)
        self.assertIn('var/tmp/list/selected_organs', SURGERY)
        self.assertIn('var/tmp/list/in_progress', SURGERY)


if __name__ == "__main__":
    unittest.main()
