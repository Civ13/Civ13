"""Project rag waits and completions with fake movement and reagent boundaries."""
import importlib.util
import re
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location('rag_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
SOURCE = (ROOT / 'code/game/objects/items/weapons/detective.dm').read_text()
HUMAN_LIFE = (ROOT / 'code/game/mob/living/carbon/human/human_life.dm').read_text()
BLOCK_GAS_SMOKE_EFFECT = 2048


def exercise(kind, movement='stationary', floor=False):
    calls = []
    target = SimpleNamespace(nearby=True, deleted=False, clean_blood=lambda: calls.append('clean'))
    target.is_open_container = lambda: True
    turf = object()
    user = SimpleNamespace(loc=turf, visible_message=lambda *args: None)
    user.Adjacent = lambda obj: obj.nearby
    reagents = SimpleNamespace(total_volume=10, splash=lambda obj, amount: calls.append('splash'),
                               trans_to=lambda obj, amount: calls.append('transfer'))
    def wait(actor, delay, monitored=None, **kwargs):
        if movement != 'stationary':
            target.nearby = False
        # do_after cancels if the monitored atom changes loc. An obstruction
        # can also make the target unreachable without changing its loc.
        return not (movement == 'moved' and monitored is target)
    env = {'do_after': wait, 'get_turf': lambda actor: turf,
           'QDELETED': lambda obj: obj is None or obj.deleted,
           'update_name': lambda: None, 'to_chat': lambda *args: None,
           'effect': lambda: calls.append('attack')}
    if kind == 'attack':
        body = adapter.extract(SOURCE, '/obj/item/weapon/reagent_containers/glass/rag/attack')
        lines = body.splitlines()
        start = next(i for i, line in enumerate(lines) if 'if (do_after(user, 20,' in line)
        end = next(i for i in range(start + 1, len(lines)) if 'var/mob/living/M = target' in lines[i])
        segment = [line[1:] for line in lines[start:end]] + ['\t\teffect()']
        args = 'user, target'
    else:
        declaration = '/obj/item/weapon/reagent_containers/glass/rag/proc/' + ('wipe_down' if kind == 'wipe' else 'remove_contents')
        segment = adapter.extract(SOURCE, declaration).splitlines()
        # Message interpolation is outside this behavior test.
        segment = ['\t\tvar/target_text = "target"' if 'var/target_text =' in line else line for line in segment]
        args = 'A, user, reagents' if kind == 'wipe' else 'user, trans_dest, reagents'
    proc = adapter.project('/test/proc/run()\n' + '\n'.join(segment) + '\n', '/test/proc/run', args, env)
    if kind == 'attack': proc(user, target)
    elif kind == 'wipe': proc(target, user, reagents)
    else: proc(user, None if floor else target, reagents)
    return calls


def attack_effects(*, mask=None, head=None, human=True, during_wait=None,
                   on_fire=False, organ='mouth', volume=10):
    """Project the full source decision with mocked game/presentation boundaries."""
    effects = []
    warnings = []
    protection = '/mob/living/human/proc/blocks_chemical_smoke'
    blocks = adapter.project(HUMAN_LIFE, protection, 'wear_mask, head',
                             {'BLOCK_GAS_SMOKE_EFFECT': BLOCK_GAS_SMOKE_EFFECT})
    target = SimpleNamespace(nearby=True, deleted=False, human=human, wear_mask=mask, head=head,
                             IgniteMob=lambda: effects.append('ignite'))
    target.blocks_chemical_smoke = lambda: blocks(target.wear_mask, target.head)
    user = SimpleNamespace(targeted_organ=organ, Adjacent=lambda obj: obj.nearby,
                           do_attack_animation=lambda item: effects.append('animate'),
                           visible_message=lambda *args: effects.append('announce'))
    rag = object()
    def wait(actor, delay, monitored=None):
        if during_wait:
            during_wait(monitored)
        return True
    def transfer(recipient, quantity, route):
        assert (recipient, quantity, route) == (target, 5, 'blood')
        effects.append('transfer')

    env = {'isliving': lambda obj: obj is target, 'istype': lambda obj: obj.human,
           'do_after': wait, 'QDELETED': lambda obj: obj is None or obj.deleted,
           'reagents': SimpleNamespace(total_volume=volume, trans_to_mob=transfer),
           'amount_per_transfer_from_this': 5, 'CHEM_BLOOD': 'blood',
           'update_name': lambda: effects.append('rename'),
           'wipe_down': lambda recipient, actor: effects.append('wipe'),
           'to_chat': lambda actor, message: warnings.append((actor is user, message)),
           'inherited': lambda: effects.append('inherited'), 'src': rag}
    declaration = '/obj/item/weapon/reagent_containers/glass/rag/attack'
    body = adapter.extract(SOURCE, declaration)
    # Flatten the multiline in-game visible_message so the small adapter can
    # preserve the call itself; bind the parent call at a fake boundary.
    body = re.sub(r'visible_message\(\n([\s\S]*?)\n[ \t]*\)',
                  lambda m: 'visible_message(' + ' '.join(x.strip() for x in m[1].splitlines()) + ')', body)
    body = body.replace('return ..()', 'return inherited()')
    attack = adapter.project('/test/proc/run()\n' + body + '\n', '/test/proc/run',
                             'user, target, on_fire', env)
    attack(user, target, on_fire)
    return effects, warnings


class RagTargetTest(unittest.TestCase):
    def test_moved_target_does_not_receive_completion(self):
        for kind, effect in [('attack', 'attack'), ('wipe', 'clean'), ('wring', 'transfer')]:
            for movement in ('moved', 'reach_changed'):
                with self.subTest(kind=kind, movement=movement):
                    self.assertNotIn(effect, exercise(kind, movement))

    def test_stationary_targets_and_floor_still_work(self):
        for kind, effect in [('attack', 'attack'), ('wipe', 'clean'), ('wring', 'transfer')]:
            with self.subTest(kind=kind):
                self.assertIn(effect, exercise(kind))
        self.assertIn('splash', exercise('wring', floor=True))


class RagInhalationTest(unittest.TestCase):
    def setUp(self):
        self.protection = SimpleNamespace(item_flags=BLOCK_GAS_SMOKE_EFFECT, flags=0)
        self.regular = SimpleNamespace(item_flags=0, flags=BLOCK_GAS_SMOKE_EFFECT)

    def test_smoke_protection_in_either_slot_blocks_smothers(self):
        for slot in ('mask', 'head'):
            with self.subTest(slot=slot):
                effects, warnings = attack_effects(**{slot: self.protection})
                self.assertEqual(effects, [])
                self.assertEqual(len(warnings), 1)
                self.assertTrue(warnings[0][0])
                self.assertIn('blocks inhalation', warnings[0][1])

    def test_unprotected_living_targets_still_receive_the_reagent(self):
        expected = ['animate', 'announce', 'transfer', 'rename']
        for setup in ({}, {'mask': self.regular, 'head': self.regular},
                      {'mask': self.protection, 'human': False}):
            with self.subTest(setup=setup):
                self.assertEqual(attack_effects(**setup), (expected, []))

    def test_equipment_is_checked_when_the_wait_finishes(self):
        add_mask = lambda target: setattr(target, 'wear_mask', self.protection)
        remove_mask = lambda target: setattr(target, 'wear_mask', None)
        self.assertEqual(attack_effects(during_wait=add_mask)[0], [])
        self.assertIn('transfer', attack_effects(mask=self.protection, during_wait=remove_mask)[0])

    def test_burning_wiping_dry_and_loss_of_reach_preserve_existing_paths(self):
        self.assertEqual(attack_effects(mask=self.protection, on_fire=True),
                         (['announce', 'animate', 'ignite'], []))
        self.assertEqual(attack_effects(mask=self.protection, organ='head'), (['wipe'], []))
        self.assertEqual(attack_effects(mask=self.protection, volume=0), ([], []))
        self.assertEqual(attack_effects(mask=self.protection,
                                        during_wait=lambda target: setattr(target, 'nearby', False)), ([], []))


if __name__ == '__main__':
    unittest.main()
