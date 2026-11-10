"""Offline source contracts. These do not execute DM or establish client acceptance."""
from pathlib import Path
import json
import unittest

ROOT = Path(__file__).resolve().parents[1]


class AtlasExamineTests(unittest.TestCase):
    def test_player_entrypoint_is_after_existing_visibility_and_blindness_gates(self):
        source = (ROOT / 'code/game/mob/mob.dm').read_text()
        body = source.split('/mob/verb/examinate(', 1)[1].split('/mob/proc/ret_grab', 1)[0]
        self.assertLess(body.index('los_read_allowed'), body.index('examine_link'))
        self.assertLess(body.index('is_blind(src) || stat'), body.index('examine_link'))
        self.assertLess(body.index('A.examine(src)'), body.index('examine_link'))
        self.assertIn('if (A && !QDELETED(A))', body)
        self.assertEqual(body.count('examine_link'), 1)

    def test_adapter_is_read_only_exact_and_uses_actual_material(self):
        source = (ROOT / 'code/game/mob/crafting_atlas_examine.dm').read_text()
        for contract in ('name != initial(name)', 'var/material/actual = get_material()',
                         'return actual ? "[actual.type]" : null',
                         '!resource_exists(resource_id)', 'url_encode(resource_id)',
                         'to_chat(viewer,', '!viewer.client', 'QDELETED(target)'):
            self.assertIn(contract, source)
        for forbidden in ('typesof(', 'parent_type', 'target.contents', 'target.loc',
                          'learn_node(', 'new /', 'world <<', 'visible_message('):
            self.assertNotIn(forbidden, source)
        self.assertIn('crafting_atlas_examine.dm', (ROOT / 'civ13.dme').read_text())

    def test_current_catalog_contains_example_exact_links_not_guessed_parents(self):
        resources = json.loads((ROOT / 'UI/crafting-atlas.json').read_text())['resources']
        for identity in ('/material/wood', '/mob/living/simple_animal/chicken', '/turf/floor/grass'):
            self.assertIn(identity, resources)
        self.assertNotIn('/unknown/not_catalogued', resources)

    def test_existing_route_revalidates_and_uses_presenter_fallback(self):
        source = (ROOT / 'code/game/mob/crafting_atlas.dm').read_text()
        body = source.split('/datum/crafting_atlas_reference/Topic', 1)[1]
        self.assertIn('if (!usr || !usr.client)', body)
        self.assertIn('if (resource_exists(resource_id))', body)
        self.assertIn('show(viewer, resource_id, 1, resource_id)', body)


if __name__ == '__main__':
    unittest.main()
