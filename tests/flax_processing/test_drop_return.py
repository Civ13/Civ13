"""Offline source/contract models for #3322, never native DM dispatch evidence.

Each same-path human definition is checked independently. The Python model does
not decide how DM dispatches repeated definitions or forwards implicit arguments.
Run directly with a verified Python executable; no BYOND process is launched.
"""
from pathlib import Path
import re
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
HUMAN = '/mob/living/human/drop_from_inventory'
DEFINITIONS = (
    ('code/game/mob/living/living.dm', 'internal_organs'),
    ('code/game/mob/living/carbon/human/human.dm', 'organs'),
)


def source(path):
    return (ROOT / path).read_text(encoding='utf-8')


def block(text, name):
    match = re.search(r'^' + re.escape(name) + r'\([^\n]*\)\n(.*?)(?=^/|\Z)',
                      text, re.M | re.S)
    if not match:
        raise AssertionError('Missing proc: ' + name)
    return match[0].rstrip()


def wrapper_contract(text, item, excluded, arguments, parent):
    """Model only the explicit guard and terminal result in one source body."""
    if item in excluded:
        return None
    result = parent(*arguments)
    return result if text.splitlines()[-1].strip() == 'return ..()' else None


class HumanDropReturnContracts(unittest.TestCase):
    def test_both_same_path_definitions_preserve_signature_guard_and_bare_forwarding(self):
        for path, organs in DEFINITIONS:
            with self.subTest(path=path):
                text = source(path)
                self.assertEqual(text.count(HUMAN + '('), 1)
                self.assertEqual(block(text, HUMAN),
                    HUMAN + '(var/obj/item/W, var/atom/Target = null)\n'
                    f'\tif (W in {organs})\n\t\treturn\n\treturn ..()')

    def test_each_wrapper_model_forwards_success_failure_null_and_identity(self):
        for path, _ in DEFINITIONS:
            text = block(source(path), HUMAN)
            for result in (True, False, None, object()):
                with self.subTest(path=path, result=result):
                    calls = []
                    item, target = object(), object()
                    arguments = (item, target, True)
                    def parent(*args):
                        calls.append(args)
                        return result
                    self.assertIs(wrapper_contract(text, item, [], arguments, parent), result)
                    self.assertEqual(calls, [arguments])

    def test_each_organ_guard_model_rejects_before_parent_and_old_terminal_fails(self):
        for path, _ in DEFINITIONS:
            text = block(source(path), HUMAN)
            item = object()
            def forbidden_parent(*args):
                self.fail('organ guard called parent')
            self.assertIsNone(wrapper_contract(text, item, [item], (item,), forbidden_parent))
            legacy = text.removesuffix('return ..()') + '..()'
            self.assertIsNone(wrapper_contract(legacy, item, [], (item,), lambda *a: True))
            self.assertIs(wrapper_contract(text, item, [], (item,), lambda *a: True), True)

    def test_include_order_does_not_model_repeated_definition_dispatch(self):
        dme = source('civ13.dme')
        paths = ['code/game/mob/inventory.dm', *(path for path, _ in DEFINITIONS)]
        offsets = [dme.index('#include "' + path.replace('/', '\\') + '"') for path in paths]
        self.assertEqual(offsets, sorted(offsets))

    def test_parent_refusal_and_physical_move_contract_remain_distinct(self):
        text = block(source('code/game/mob/inventory.dm'), '/mob/proc/drop_from_inventory')
        self.assertIn('if (W.nodrop || W.nodrop_special_check() || ignore_nodrop)\n\t\t\treturn FALSE', text)
        self.assertIn('if (!Target)\n\t\t\tTarget = loc', text)
        self.assertIn('remove_from_mob(W)', text)
        self.assertIn('W.forceMove(Target, MOVED_DROP)', text)
        self.assertIn('update_icons()\n\t\treturn TRUE', text)
        # Do not reinterpret the existing ignore_nodrop polarity or turn the
        # parent's unchecked forceMove into proof of destination admission.
        self.assertNotIn('if (!W.forceMove', text)

    def test_flax_still_requires_return_and_actual_water_location_before_soaking(self):
        text = block(source('code/modules/1713/flax_processing.dm'), '/obj/item/flax_bundle/afterattack')
        self.assertIn('if (!user.drop_from_inventory(src, W) || loc != W)\n\t\treturn\n\tsoak(user, W)', text)
        self.assertIn('W.salty || W.radiation > 0', text)
        # Contract matrix includes denied, redirected, and legacy false-result
        # physical drops. This models admission, not native movement or cleanup.
        water, elsewhere = object(), object()
        for result, location, expected in (
            (True, water, True), (False, water, False), (None, water, False),
            (True, elsewhere, False), (False, elsewhere, False),
        ):
            item = NS(loc=location)
            self.assertEqual(bool(result and item.loc is water), expected)

    def test_tanning_keeps_direct_transfer_and_both_production_and_legacy_controls(self):
        rack = source('tests/animal_harvest/rack_transfer_probe.dm')
        self.assertIn('harvest_assert(drop_result && clear_batch.loc == site', rack)
        self.assertIn('harvest_assert(!drop_result && clear_batch.loc == site', rack)
        legacy = block(rack, '/mob/living/human/rack_transfer_tester/legacy_return/drop_from_inventory')
        self.assertEqual(legacy.splitlines()[-1], '\t..()')
        admission = block(source('code/game/objects/structures/converters.dm'), '/obj/structure/converter/tanning/attackby')
        self.assertIn('user.transfer_held_item_to(hide, src)', admission)
        self.assertNotIn('drop_from_inventory', admission)
        for marker in ('Floor-drop control', 'Rejected rack transfer', 'Redirected transfer', 'storage contents'):
            self.assertIn(marker, rack)

    def test_existing_flax_fixture_is_explicitly_not_production_inventory_acceptance(self):
        fixture = source('tests/flax_processing/probe.dm')
        adapter = block(fixture, '/mob/living/human/flax_tester/drop_from_inventory')
        self.assertIn('return TRUE', adapter)
        self.assertIn('B.soak(U, W)', fixture)
        proposal = source('tests/flax_processing/drop-return-acceptance.md')
        self.assertIn('Do not use `flax_tester`', proposal)
        self.assertIn('afterattack', proposal)


if __name__ == '__main__':
    unittest.main(verbosity=2)
