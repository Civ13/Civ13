"""Offline source contracts only; these do not execute DM or a save round trip."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/1713/production.dm').read_text(encoding='utf-8')


def body(source, header):
    start = source.index(header)
    end = source.find('\n/obj/', start + len(header))
    return source[start:end if end >= 0 else len(source)]


class PrimitiveSawmillContracts(unittest.TestCase):
    def test_recipe_and_axe_comparison(self):
        recipes = (ROOT / 'config/crafting/material_recipes_global.txt').read_text()
        self.assertEqual(recipes.count('primitive saw mill,/obj/structure/sawmill,'), 1)
        axe = (ROOT / 'code/modules/materials/material_sheets.dm').read_text()
        self.assertIn('var/cost = hatchet ? 2 : 1', axe)
        self.assertIn('var/planks = hatchet ? 1 : 4', axe)
        self.assertIn('(hatchet ? 80 : 60)/user.getStatCoeff("strength")', axe)
        cut = body(SOURCE, '/obj/structure/sawmill/proc/cut_primitive_log(')
        self.assertIn('20 / H.getStatCoeff("strength")', cut)
        self.assertIn('new(site, 4, FALSE)', cut)

    def test_partial_stack_and_material_validation_precede_debit(self):
        cut = body(SOURCE, '/obj/structure/sawmill/proc/cut_primitive_log(')
        debit = cut.index('W.use(1)')
        self.assertGreater(cut[:debit].count('W.amount < 1'), 1)
        self.assertGreater(cut[:debit].count('W.default_type != "wood"'), 1)
        self.assertIn('W.material.name != "wood"', cut[:debit])
        self.assertLess(debit, cut.index('flint_blade_uses--'))
        self.assertLess(cut.index('flint_blade_uses--'), cut.index('new(site, 4, FALSE)'))
        self.assertIn('P.customcolor = wood_customcolor', cut)

    def test_wrong_and_broken_blades_and_consumption(self):
        install = body(SOURCE, '/obj/structure/sawmill/proc/install_flint(')
        self.assertIn('!F.sharpened', install)
        self.assertIn('flint_blade_uses > 0', install)
        self.assertLess(install.index('H.drop_from_inventory(F)'), install.index('qdel(F)'))
        self.assertLess(install.index('qdel(F)'), install.index('flint_blade_uses = 20'))
        cut = body(SOURCE, '/obj/structure/sawmill/proc/cut_primitive_log(')
        self.assertGreater(cut.count('flint_blade_uses < 1'), 1)
        self.assertIn('flint_blade_uses == 0', cut)

    def test_interruption_deletion_concurrency_and_save_boundary(self):
        cut = body(SOURCE, '/obj/structure/sawmill/proc/cut_primitive_log(')
        self.assertLess(cut.index('primitive_busy = TRUE'), cut.index('do_after('))
        self.assertLess(cut.index('QDELETED(src) || token != primitive_epoch'), cut.index('W.use(1)'))
        self.assertLess(cut.index('!completed'), cut.index('W.use(1)'))
        access = body(SOURCE, '/obj/structure/sawmill/proc/primitive_access(')
        for term in ('!persistence_save_in_progress', '!persistence_active_operation', '!persistence_load_recovery_required', 'I.loc == H', 'H.item_is_in_hands(I)'):
            self.assertIn(term, access)
        cancel = body(SOURCE, '/obj/structure/sawmill/proc/cancel_primitive_work(')
        self.assertIn('primitive_epoch++', cancel)
        for hook in ('before_save', 'after_load'):
            self.assertIn('cancel_primitive_work()', body(SOURCE, '/obj/structure/sawmill/' + hook + '()'))
        excluded = body(SOURCE, '/obj/structure/sawmill/persistence_runtime_var(')
        self.assertIn('primitive_busy', excluded)
        self.assertIn('primitive_epoch', excluded)
        self.assertNotIn('flint_blade_uses', excluded)

    def test_wrench_aba_invalidates_original_cut(self):
        wrench = body(SOURCE, '/obj/structure/sawmill/wrench_action(')
        cut = body(SOURCE, '/obj/structure/sawmill/proc/cut_primitive_log(')
        self.assertIn('var/was_anchored = anchored', wrench)
        self.assertLess(wrench.index('. = ..()'), wrench.index('anchored != was_anchored'))
        self.assertIn('is_primitive_mill() && anchored != was_anchored', wrench)
        self.assertIn('cancel_primitive_work()', wrench)
        self.assertLess(cut.index('token != primitive_epoch'), cut.index('W.use(1)'))
        # Model the two admitted transitions; the mutation control omits invalidation.
        def resumes(invalidate):
            anchored, epoch = True, 1
            token = epoch
            for new_state in (False, True):
                changed = anchored != new_state
                anchored = new_state
                if changed and invalidate:
                    epoch += 1
            return anchored and token == epoch
        self.assertFalse(resumes(True))
        self.assertTrue(resumes(False), 'omitting transition invalidation must expose ABA')


if __name__ == '__main__':
    unittest.main()
