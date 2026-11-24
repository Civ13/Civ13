#!/usr/bin/env python3
"""Offline source contracts for the Skills Guide window."""
import importlib.util
import pathlib
import re
from types import SimpleNamespace
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text(encoding='utf-8', errors='replace').replace('\r\n', '\n')


GUIDE = read('code/modules/research_tree/skill_guide.dm')


class SkillGuide(unittest.TestCase):
    def test_the_guide_is_compiled_into_the_game(self):
        self.assertEqual(read('civ13.dme').count('research_tree\\skill_guide.dm"'), 1)

    def test_every_status_tab_skill_has_a_row(self):
        # Players asked "how do I raise this?" for skills the Status tab
        # lists; a skill shown there without a row here is the same gap.
        rows = set(re.findall(r'^\t"(\w+)" = list\("', GUIDE, re.M))
        self.assertEqual(rows, {'strength', 'crafting', 'dexterity', 'stamina', 'swords', 'bows', 'rifle', 'pistol',
                                'machinegun', 'throwing', 'medical', 'farming', 'hunting', 'swimming', 'unarmed', 'philosophy'})

    def test_magic_is_never_mentioned(self):
        self.assertNotIn('magic', GUIDE.lower().replace('magic is left out on purpose', ''))

    def test_the_tabs_point_at_the_guide(self):
        pointer = '"<b>How to raise them:</b>", "IC tab, Skills Guide"'
        self.assertIn(pointer, read('code/game/mob/living/carbon/human/human.dm'))
        self.assertIn(pointer, read('code/modules/research_tree/scholarship.dm'))
        self.assertIn('set name = "Skills Guide"\n', GUIDE)
        self.assertIn('set category = "IC"\n', GUIDE)


class CraftsmanWork(unittest.TestCase):
    # Project the production reward paths, substituting world and tool effects.
    # This checks preconditions and paid paths, not the DM engine or live skill.
    def setUp(self):
        spec = importlib.util.spec_from_file_location('craftsman_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
        self.adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(self.adapter)
        self.rewards = []
        self.book_world = True
        self.deeds = []
        self.actor = SimpleNamespace(note_craftsman_work=self.dispatch)
        skill = read('code/modules/research_tree/learning_by_doing.dm')
        skill = skill.replace('"craftsman:[lesson]:[result_type]"', 'format_key(lesson, result_type)')
        self.skill = self.adapter.project(skill, '/mob/living/human/proc/note_craftsman_work', 'lesson,result_type,effort,stat',
                                         dict(CONSCIOUS=0, learning_by_doing_enabled=lambda: self.book_world,
                                              ispath=lambda value: bool(value) and value.startswith('/'),
                                              format_key=lambda lesson, product: f'craftsman:{lesson}:{product}',
                                              adaptStat=lambda *args: self.rewards.append(args)))
        self.parts = read('code/game/objects/structures/blacksmithing/parts.dm')
        parts = self.parts.replace('!istype(H) || !istype(P)', 'H != actor || !valid_part(P)')
        self.head = self.adapter.project(parts, '/proc/note_craftsman_head_work', 'user,item,lesson,effort',
                                         dict(actor=self.actor, valid_part=lambda P: bool(P) and hasattr(P, 'is_work_tool_head'),
                                              QDELETED=lambda value: value.deleted))

    def dispatch(self, lesson, product, effort):
        self.skill(lesson, product, effort, getattr(self.actor, 'stat', 0))

    def make_head(self, product='pickaxe', valid=True):
        return SimpleNamespace(deleted=False, health=20, material='iron',
                               result='/obj/item/weapon/material/' + product, is_work_tool_head=lambda: valid)

    def test_only_valid_forged_work_heads_train_existing_variety_skill(self):
        forge = read('code/game/objects/structures/blacksmithing/blacksmithing.dm')
        hook = self.adapter.project(forge, '/obj/structure/anvil/proc/finish_forged_piece', 'made,user,H,material_name',
                                    dict(note_craftsman_head_work=self.head))
        for head in (None, self.make_head(valid=False), self.make_head('pickaxe'), self.make_head('shovel')):
            hook(head, self.actor, self.actor, 'iron')
        self.assertEqual(self.rewards, [
            ('crafting', 1, 'craftsman:forge-head:/obj/item/weapon/material/pickaxe'),
            ('crafting', 1, 'craftsman:forge-head:/obj/item/weapon/material/shovel'),
        ])
        head = self.make_head()
        for state in ('deleted', 'worn', 'no material', 'not a research world', 'unconscious'):
            with self.subTest(state=state):
                head.deleted = state == 'deleted'
                head.health = 0 if state == 'worn' else 20
                head.material = None if state == 'no material' else 'iron'
                self.book_world = state != 'not a research world'
                self.actor.stat = 1 if state == 'unconscious' else 0
                hook(head, self.actor, self.actor, 'iron')
                self.assertEqual(len(self.rewards), 2)

    def test_same_craft_key_reuses_existing_variety_and_refits_remain_unpaid(self):
        item = self.make_head('hatchet')
        self.head(self.actor, item, 'forge-head', 1)
        self.head(self.actor, item, 'forge-head', 1)
        self.assertEqual(self.rewards[0], self.rewards[1])
        learning = read('code/modules/research_tree/learning_by_doing.dm')
        stats = read('code/game/mob/living/carbon/human/human_stats.dm')
        self.assertIn('skill_variety_mult(statname, variety_key)', stats)
        self.assertIn('return SKILL_VARIETY_FIRST', learning)
        assembly = self.adapter.extract(self.parts, '/obj/item/weapon/material/part/proc/assemble_work_tool')
        self.assertNotIn('note_craftsman', assembly)

    def test_paid_wooden_hull_replacement_earns_one_award_not_temporary_patch_or_steel(self):
        src = read('code/modules/naval/berth.dm')
        src = src.replace('deck.type == /obj/covers/repairedfloor/ship', 'deck.type == WOOD')
        src = src.replace('/obj/covers/repairedfloor/ship, 1)', 'WOOD_TYPE, 1)')
        self.actor.visible_message = lambda *args: None
        timber = SimpleNamespace(deleted=False)
        patch = SimpleNamespace(deleted=False)
        self.allowed = True
        self.wait = True
        self.work = 'wood'
        self.actor.get_active_hand = lambda: timber
        self.late_blocked = False
        def delay(*args):
            self.late_blocked = not self.allowed
            return self.wait
        def finish(*args):
            self.deeds.append(self.work)
            return None if self.work is None else SimpleNamespace(type=self.work, deleted=False)
        action = self.adapter.project(src, '/proc/berth_plank', 'H,W,P', dict(
            berth_plank_refusal=lambda *args: 'blocked' if self.late_blocked else None,
            to_chat=lambda *args: None, SPAN_WARNING=lambda s:s, SPAN_NOTICE=lambda s:s,
            craft_at=lambda t: SimpleNamespace(name='ship'), get_turf=lambda item:'tile',
            playsound=lambda *args: None, do_after=delay, yard_time=lambda *args:1, BERTH_PLANK_TIME=2,
            QDELETED=lambda thing: thing.deleted, berth_plank_lay=finish, WOOD='wood', WOOD_TYPE='/obj/covers/repairedfloor/ship'))
        for work, allowed, wait, hand, expected in (
            ('wood', True, True, timber, 1),
            ('steel', True, True, timber, 1),
            (None, True, True, timber, 1),
            ('wood', True, False, timber, 1),
            ('wood', False, True, timber, 1),
            ('wood', True, True, object(), 1),
        ):
            with self.subTest(work=work, allowed=allowed, wait=wait, hand=hand):
                self.work, self.allowed, self.wait, self.late_blocked = work, allowed, wait, False
                self.actor.get_active_hand = lambda: hand
                action(self.actor, timber, patch)
                self.assertEqual(len(self.rewards), expected)
        self.assertEqual(self.deeds, ['wood', 'steel', None])
        self.assertNotIn('note_craftsman_work', read('code/modules/naval/hull_ledger.dm').split('/proc/hull_patch_lay',1)[1].split('/proc/hull_patch_attack',1)[0])

    def test_sharpening_checks_actual_health_improvement_at_the_grindstone(self):
        src = read('code/game/objects/structures/repairing.dm')
        body = self.adapter.extract(src, '/obj/structure/repair/attackby')
        paid = body[body.index("\t\tif (do_after"):body.index("\telse if (is_tool")]
        paid = paid.replace('istype(src, /obj/structure/repair/grindstone)', 'isgrindstone(src)')
        projected = '/proc/test_repair_paid()\n' + '\n'.join(line[1:] for line in paid.splitlines()) + '\n'
        self.improve = True
        work = self.make_head('hatchet')
        work.name = 'hatchet head'
        def repair(*args):
            if self.improve:
                work.health += 5
            return True
        work.repair_wear = repair
        action = self.adapter.project(projected, '/proc/test_repair_paid', 'M,user,src', dict(
            do_after=lambda *args: self.wait, delay=1, QDELETED=lambda thing:thing.deleted,
            idlesprite='idle', repair_ready=lambda *args: self.allowed, damageamount=2, repairamount=8,
            isgrindstone=lambda bench:bench=='grindstone', note_craftsman_head_work=self.head,
            visible_message=lambda *args: None))
        for bench, improve, allowed, wait, expected in (
            ('grindstone', True, True, True, 1),
            ('grindstone', False, True, True, 1),
            ('grindstone', True, False, True, 1),
            ('grindstone', True, True, False, 1),
            ('other', True, True, True, 1),
        ):
            self.improve, self.allowed, self.wait = improve, allowed, wait
            action(work, self.actor, bench)
            self.assertEqual(len(self.rewards), expected)
        self.assertIn('sharpen-head', self.rewards[0][2])

    def test_guide_distinguishes_useful_work_from_trade_access_and_refitting(self):
        self.assertIn('<b>Smith:</b> Forge usable pickaxe, shovel or hatchet heads.', GUIDE)
        self.assertIn('<b>Carpenter:</b> Build wooden doors', GUIDE)
        self.assertIn('Choosing a trade changes the time for its work, not who can do the job.', GUIDE)


if __name__ == '__main__':
    unittest.main()
