"""Nomad starting-money source regressions; no native game or save is opened.

Execute the complete coin-grant helper with only construction/equipping faked.
Bind all seven era/map clothing branches to that helper, and check that the job
identity reaches it before both fresh-join paths and later customization.
"""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
JOBS = 'code/modules/1713/jobs/nomads.dm'
HELPER = '/mob/living/human/proc/give_starting_copper_coins'
COIN = '/obj/item/stack/money/coppercoin/twohundred'
MONEY = 'code/game/objects/items/stacks/money.dm'
GRANT = f'equip_to_slot_or_del(new {COIN}(src), slot_r_store)'
spec = importlib.util.spec_from_file_location(
    'nomad_coin_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


def coin_grant(source, job, contents):
    money = read(MONEY)
    amount = int(re.search(r'^' + re.escape(COIN) + r'\n\tamount = (\d+)\n', money, re.M)[1])
    body = adapter.extract(source, HELPER)
    # Only the exact native constructor is replaced; all production control
    # flow is translated, and unsupported statements fail the projection.
    assert body.count(f'new {COIN}(src)') == 1
    body = body.replace(f'new {COIN}(src)', 'make_coins(src)')
    return adapter.project(HELPER + '()\n' + body, HELPER, '', {
        'original_job': job,
        'src': contents,
        'slot_r_store': 'right pocket',
        'make_coins': lambda owner: (COIN, amount),
        'equip_to_slot_or_del': lambda item, slot: contents.append((item, slot)),
    })()


class StartingCopperTests(unittest.TestCase):
    def setUp(self):
        self.source = read(JOBS)

    def test_nomads_get_no_new_coins_or_inventory_changes(self):
        for existing in ([], [('earned copper', 37), ('saved silver', 4)]):
            with self.subTest(existing=existing):
                inventory = list(existing)
                for _ in range(2):  # A later clothing/customization call is safe too.
                    coin_grant(self.source, SimpleNamespace(is_nomad=True), inventory)
                self.assertEqual(inventory, existing)

    def test_other_roles_and_unassigned_humans_keep_the_existing_grant(self):
        for job in (SimpleNamespace(is_nomad=False), None):
            inventory = [('existing item', 1)]
            coin_grant(self.source, job, inventory)
            self.assertEqual(inventory, [('existing item', 1), ((COIN, 20), 'right pocket')])

    def test_every_former_era_grant_uses_the_same_role_gate(self):
        clothes = adapter.extract(self.source, '/mob/living/human/proc/give_clothes')
        self.assertNotIn('/obj/item/stack/money/coppercoin', clothes)
        # Seven grant sites, covering eight eras (the final case covers 8 and 9).
        cases = re.split(r'^\t\tif \((\d(?:, \d)?)\)\n', clothes, flags=re.M)
        grants = {case: body.count('give_starting_copper_coins()')
                  for case, body in zip(cases[1::2], cases[2::2])}
        self.assertEqual(grants, {'0': 0, '1': 1, '2': 0, '3': 1, '4': 1,
                                  '5': 1, '6': 1, '7': 1, '8, 9': 1})
        self.assertEqual(self.source.count(GRANT), 1)
        self.assertIn('if (map.chad_mode)', clothes)
        # Map-specific NationsRP and persistence-beta exceptions stay in place.
        for name in ('MAP_NATIONSRP', 'MAP_NATIONSRP_COLDWAR', 'MAP_NOMADS_PERSISTENCE_BETA'):
            self.assertIn(name, clothes)

    def test_job_identity_precedes_fresh_equipment_and_customization(self):
        job = self.source.split('/datum/job/civilian/civnomad\n', 1)[1].split(
            '/datum/job/civilian/civnomad/equip', 1)[0]
        self.assertIn('is_nomad = TRUE', job)
        equip = adapter.extract(self.source, '/datum/job/civilian/civnomad/equip')
        self.assertIn('H.give_clothes()', equip)
        lobby = read('code/game/mob/new_player/new_player.dm')
        create = adapter.extract(lobby, '/mob/new_player/proc/create_character')
        self.assertLess(create.index('new_character.original_job = original_job'),
                        create.index('new_character.key = key'))
        self.assertIn('job_master.AssignRole(src, rank, TRUE)', lobby)
        self.assertIn('character = job_master.EquipRank(character, rank, TRUE)', lobby)
        ticker = read('code/game/gameticker.dm')
        self.assertIn('player.create_character()', ticker)
        self.assertIn('job_master.EquipRank(player, player.mind.assigned_role, FALSE)', ticker)
        # Identity customization shares give_clothes(), not an ungated coin grant.
        customize = read('code/game/mob/living/carbon/human/nomads_spawn.dm')
        self.assertIn('give_clothes()', customize)
        self.assertNotIn('/obj/item/stack/money', customize)

    def test_saved_body_reclaim_and_region_coins_remain_separate(self):
        reclaim = adapter.extract(read('code/modules/persistence/player_reclaim.dm'),
                                  '/map_storage/proc/reclaim_saved_player')
        self.assertIn('H.key = C.key', reclaim)
        for fresh_spawn in ('EquipRank', 'give_clothes', 'give_starting_copper_coins'):
            self.assertNotIn(fresh_spawn, reclaim)
        customize = adapter.extract(read('code/game/mob/living/carbon/human/nomads_spawn.dm'),
                                    '/mob/living/human/proc/nomads_spawn')
        self.assertTrue(customize.lstrip().startswith('if(persistence_restored)\n\t\treturn'))
        self.assertIn('"copper_coin" = /obj/item/stack/money/coppercoin',
                      read('code/modules/persistence/region_travel.dm'))

    def test_removing_the_nomad_guard_reproduces_the_grant(self):
        mutant = self.source.replace('\tif (original_job && original_job.is_nomad)\n\t\treturn\n', '', 1)
        self.assertNotEqual(mutant, self.source)
        inventory = []
        coin_grant(mutant, SimpleNamespace(is_nomad=True), inventory)
        self.assertEqual(inventory, [((COIN, 20), 'right pocket')])


if __name__ == '__main__':
    unittest.main()
