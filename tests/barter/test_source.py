"""Barter: source contract checks.

    python3 tests/barter/test_source.py
"""
import importlib.util
import re
from types import SimpleNamespace
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'code/modules/1713/barter.dm'


class BarterSource(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.text = SOURCE.read_text(encoding='utf-8')

    def test_included(self):
        self.assertIn('#include "code\\modules\\1713\\barter.dm"', (ROOT / 'civ13.dme').read_text(encoding='utf-8'))

    def test_trade_state_is_runtime_only(self):
        self.assertIn('return key == "traders" || key == "offers" || key == "agreed" || key == "agreement_revision" || ..()', self.text)
        self.assertIn('/obj/structure/barter_mat/after_load()', self.text)

    def test_recipes_and_research(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text(encoding='utf-8')
        for line in ('RECIPE: /material/stone/,stone beads,/obj/item/stack/barter_beads/stone,',
                'RECIPE: /material/bone/,bone beads,/obj/item/stack/barter_beads/bone,',
                'RECIPE: /material/leather/,barter mat,/obj/structure/barter_mat,'):
            self.assertIn(line, recipes)
        research = (ROOT / 'code/modules/research_tree/research_node.dm').read_text(encoding='utf-8')
        self.assertIn('"/obj/structure/barter_mat" = "basic_tools",', research)

    def test_sprites_exist(self):
        from PIL import Image
        meta = Image.open(ROOT / 'icons/obj/barter.dmi').info.get('Description', '')
        for state in ('beads_stone', 'beads_bone', 'barter_mat', 'barter_mat_goods'):
            self.assertIn('state = "%s"' % state, meta)

    def test_trades_are_logged(self):
        self.assertIn('log_game("Barter at', self.text)

    def test_stale_agreements_never_enter_the_swap(self):
        spec = importlib.util.spec_from_file_location('barter_adapter', ROOT/'tests/save_movement/source_adapter.py')
        adapter = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(adapter)
        adapter.FIELDS += ('agreement_revision', 'agreed', 'traders', 'tidy', 'swap')

        class DMList(set):
            @property
            def len(self):
                return len(self)
            def __ior__(self, item):
                self.add(item)
                return self
            def Cut(self):
                self.clear()

        prefix = '/obj/structure/barter_mat/'
        agree = adapter.project(self.text, prefix+'proc/agree', 'src,M,reviewed_revision', {}, method=True)
        invalidate = adapter.project(self.text, prefix+'proc/invalidate_agreements', 'src', {}, method=True)
        first, second = object(), object()
        calls = []
        mat = SimpleNamespace(agreement_revision=0, traders=DMList([first, second]), agreed=DMList(),
                              tidy=lambda: None, swap=lambda: calls.append('swap') or True)
        self.assertFalse(agree(mat, first, 0))
        self.assertEqual(mat.agreed, {first})
        invalidate(mat)
        self.assertEqual(mat.agreement_revision, 1)
        self.assertEqual(mat.agreed, set())
        self.assertFalse(agree(mat, first, 0))
        self.assertFalse(agree(mat, second, 1))
        self.assertFalse(agree(mat, first, 0))
        self.assertEqual(mat.agreed, {second})
        self.assertFalse(calls)
        self.assertTrue(agree(mat, first, 1))
        self.assertEqual(calls, ['swap'])
        # A trader departure discovered during tidy must invalidate even a current-looking reply.
        def departure():
            mat.traders.discard(second)
            invalidate(mat)
        mat.tidy = departure
        self.assertFalse(agree(mat, first, 1))
        self.assertEqual(mat.agreed, set())
        self.assertEqual(calls, ['swap'])

        for method in ('after_load', 'proc/join', 'proc/leave', 'proc/offer', 'proc/take_back', 'proc/swap'):
            with self.subTest(method=method):
                self.assertIn('invalidate_agreements()', adapter.extract(self.text, prefix+method))

    def test_menu_captures_revision_before_wait_and_rechecks_after(self):
        menu = self.text.split('/obj/structure/barter_mat/attack_hand(mob/user)', 1)[1]
        self.assertLess(menu.index('var/reviewed_revision = agreement_revision'), menu.index('player_input('))
        self.assertLess(menu.index('player_input('), menu.index('if (QDELETED(src)'))
        resume = menu.split('player_input(', 1)[1]
        self.assertLess(resume.index('tidy()'), resume.index('if (reviewed_revision != agreement_revision)'))
        self.assertLess(resume.index('if (reviewed_revision != agreement_revision)'), resume.index('agree(user, reviewed_revision)'))

    def test_no_forbidden_patterns(self):
        self.assertIsNone(re.search(r'(?<![a-z_])(spawn|input)\(', self.text))
        self.assertNotIn(' in world', self.text)


if __name__ == '__main__':
    unittest.main()
