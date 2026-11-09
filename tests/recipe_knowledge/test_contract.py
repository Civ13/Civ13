"""Offline wiring contracts; native behavior/durable roundtrips live in game.dm."""
from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parents[2]
def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')
def proc(source, name):
    match = re.search(r'^' + re.escape(name) + r'\([^\n]*\)\n(.*?)(?=^/|\Z)', source, re.M | re.S)
    assert match, name
    return match[1]
class KnowledgeContract(unittest.TestCase):
    def setUp(self):
        self.source = read('code/modules/research_tree/character_knowledge.dm')
    def test_flag_is_configuration_not_new_durable_metadata(self):
        self.assertIn('return persistence && recipe_books', self.source)
        self.assertNotIn('recipe_books', read('code/modules/persistence/durable_contract.dm'))
        self.assertNotRegex(read('code/game/objects/map_metadata/nomads/nomads_gaia.dm'), r'(?m)^\s*recipe_books\s*=\s*TRUE')
    def test_central_gate_adds_knowledge_without_hiding_menu_rows(self):
        gate = proc(read('code/modules/research_tree/recipe_gates.dm'), '/proc/crafting_node_allowed')
        self.assertIn('crafting_node_world_allowed(H.civilization, node_id)', gate)
        self.assertIn('!map.recipe_knowledge_enabled() || H.knows_recipe_node(node_id)', gate)
        self.assertNotIn('knows_recipe_node', read('code/game/objects/items/stacks/civ_recipes.dm'))
    def test_saved_fields_and_restore_validation(self):
        self.assertIn('var/list/known_recipe_nodes = null', self.source)
        self.assertIn('var/recipe_knowledge_initialized = FALSE', self.source)
        restore = proc(self.source, '/mob/living/human/persistence_import_fields')
        self.assertIn('"recipe_knowledge_initialized" in saved_fields', restore)
        self.assertIn('clean_recipe_node_ids(known_recipe_nodes)', restore)
        self.assertIn('if (stat == DEAD)', restore)
        self.assertIn('forget_recipe_knowledge()', restore)
    def test_new_and_dead_body_hooks(self):
        self.assertIn('initialize_recipe_knowledge()', proc(read('code/game/mob/living/carbon/carbon.dm'), '/mob/living/human/on_runtime_spawn'))
        self.assertIn('forget_recipe_knowledge()', proc(read('code/game/mob/living/carbon/human/death.dm'), '/mob/living/human/death'))
        self.assertIn('recipe_knowledge_initialized = TRUE', proc(self.source, '/mob/living/human/proc/forget_recipe_knowledge'))
    def test_migration_only_at_restoration_or_activation(self):
        body = proc(self.source, '/mob/living/human/proc/migrate_recipe_knowledge')
        self.assertIn('|| recipe_knowledge_initialized)', body)
        self.assertIn('map.is_node_done(civilization, node_id)', body)
        self.assertIn('recipe_knowledge_initialized = TRUE', body)
        restore = proc(read('code/modules/persistence/player_reclaim.dm'), '/map_storage/proc/finish_player_restoration')
        self.assertLess(restore.index('H.finish_character_knowledge_restoration()'), restore.index('persistence_player_restore_ready = TRUE'))
        self.assertIn('persistence_restored_characters', restore)
        self.assertIn('migrate_recipe_knowledge()', proc(self.source, '/mob/living/human/finish_character_knowledge_restoration'))
        self.assertNotIn('migrate_recipe_knowledge', proc(self.source, '/mob/living/human/proc/knows_recipe_node'))
    def test_timed_reusable_book_rechecks_ceiling_and_identity(self):
        book = proc(self.source, '/obj/item/weapon/book/node_book/attack_self')
        for token in ('do_after(H, 600, src)', 'node_id != reading_node', 'H.Adjacent(src)', 'H.incapacitated()', 'H.learn_recipe_node(reading_node)'):
            self.assertIn(token, book)
        self.assertNotIn('qdel(', book)
        learn = proc(self.source, '/mob/living/human/proc/learn_recipe_node')
        self.assertIn('if (!can_learn_recipe_node(node_id))', learn)
        self.assertIn('known_recipe_nodes |= node_id', learn)
        self.assertIn('map.is_node_done(civilization, node_id)', proc(self.source, '/mob/living/human/proc/can_learn_recipe_node'))
    def test_first_book_is_guarded_before_completion(self):
        complete = proc(read('code/modules/research_tree/research_faction.dm'), '/obj/map_metadata/proc/complete_node')
        self.assertLess(complete.index('if (is_node_done(faction, node_id))'), complete.index('entry[RNODE_ENTRY_STATUS] = RNODE_DONE'))
        self.assertEqual(complete.count('produce_first_node_book(faction, node_id)'), 1)
    def test_native_fixture_covers_durable_and_migration_cases(self):
        fixture = read('tests/recipe_knowledge/game.dm')
        for token in ('Save_World()', 'validate_world_save()', 'Load_World()', 'old_save.persistence_import_fields(list())', 'legacy.migrate_recipe_knowledge()', 'fresh.recipe_knowledge_initialized', 'B.node_id == node_id'):
            self.assertIn(token, fixture)
        runner = read('tests/recipe_knowledge/run.py')
        self.assertIn("'0', '-invisible', '-close'", runner)
        self.assertIn("if args.trusted:", runner)
        self.assertIn("'0 errors, 0 warnings'", runner)
if __name__ == '__main__':
    unittest.main()
