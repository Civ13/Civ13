"""Bronze production and availability prompt coverage without a model or HTTP."""
import importlib.util
import hashlib
from pathlib import Path
import tempfile
import unittest
from unittest import mock

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('bronze_bridge', ROOT / 'scripts/player_help_bridge.py')
bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bridge)


class BronzeRetrievalTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.corpus = bridge.recipe_context(ROOT / 'UI/crafting-atlas.json') + bridge.gameplay_knowledge(ROOT)

    def prompt(self, question, corpus=None, history=None):
        calls = []
        def transport(*args):
            calls.append(args[1])
            return {'message': {'content': 'offline fixture response'}}
        with tempfile.TemporaryDirectory() as temporary:
            worker = bridge.Bridge(Path(temporary), {'enabled': True, 'model': 'test',
                'endpoint': 'http://unused.invalid', 'timeout_seconds': 1},
                self.corpus if corpus is None else corpus, transport)
            try:
                request = {'id': 'bronze', 'account': 'a' * 32, 'question': question,
                           'game_context': {'map': 'Nomads', 'civilizations': True, 'era_ordinal': 0}}
                if history is not None:
                    request['conversation'] = history
                self.assertEqual(worker.answer(request)['status'], 'ok')
            finally:
                worker.close()
        self.assertEqual(len(calls), 1)
        return calls[0]['messages'][0]['content']

    def test_production_and_when_questions_include_route_and_gates(self):
        for question in ('when I can make bronze', 'How do I make bronze?',
                         'How do I produce bronze ingots in Nomads?'):
            with self.subTest(question=question):
                prompt = self.prompt(question)
                for required in ('CURRENT GAMEPLAY CODE (bronze production',
                                 'MCC.current_material = "bronze"',
                                 'min(MCC.contents_materials["copper"],MCC.contents_materials["tin"])',
                                 'MCC.contents_materials = list()',
                                 '/obj/item/stack/ore/copper', '/obj/item/stack/ore/tin',
                                 'clay blacksmith pot', 'clay blacksmith jug',
                                 'max_capacity = 20', 'max_capacity = 70',
                                 'OVEN firing', 'ANVIL use gates', 'crafting',
                                 'amt_to_transfer', '/obj/item/stack/material/bronze',
                                 'CURRENT GAMEPLAY CODE (bronze availability',
                                 '"bronze_working"', '"pottery_storage"', '"stone_arms"',
                                 'map.is_node_done(research_faction, node_req)',
                                 'map.ordinal_age <= text2num(i[12])',
                                 'does not report completed research nodes',
                                 'Missing retrieval is not evidence',
                                 'Do not claim research is unlocked from era alone.'):
                    self.assertIn(required, prompt)
                self.assertLess(len(prompt), 20000)

    def test_bronze_working_bootstrap_uses_unfired_type_and_full_study(self):
        prompt = self.prompt('How can I unlock Bronze Working?')
        for text in ('name = "unfired clay axehead mold"',
                     'istype(W, N.prototype_type)', 'map.can_manage_faction_research',
                     'tier < N.min_bench_tier', 'map.node_prereqs_met',
                     'pentry[RNODE_ENTRY_TICKS] >= N.cost_ticks',
                     'REQUIREMENT alongside the full study'):
            self.assertIn(text, prompt)
        evidence = bridge.bronze_knowledge(ROOT)[0]
        self.assertLessEqual(len(evidence['text']), 14000)
        self.assertIn('code/modules/research_tree/research_bench.dm', evidence['source_hashes'])

    def test_followup_keeps_availability_with_production(self):
        prompt = self.prompt('When can I make it?', history={'version': 1, 'turns': [
            {'question': 'How do I make bronze?', 'answer': 'Earlier answer may be incomplete.'}]})
        self.assertIn('MCC.current_material = "bronze"', prompt)
        self.assertIn('map.is_node_done(research_faction, node_req)', prompt)

    def test_removing_new_evidence_reproduces_missing_production(self):
        old = [entry for entry in self.corpus if not entry['topic'].startswith('bronze production')
               and not entry['topic'].startswith('bronze availability')]
        prompt = self.prompt('when I can make bronze', old)
        self.assertNotIn('MCC.current_material = "bronze"', prompt)
        self.assertNotIn('CURRENT GAMEPLAY CODE (bronze availability', prompt)

    def test_unrelated_map_catalog_is_not_selected_for_nomads(self):
        wrong = {'topic': 'bronze production availability unlock research',
                 'source': 'recipe', 'catalog': 'Material / battle_ships',
                 'text': 'WRONG MAP BRONZE RECIPE'}
        self.assertNotIn('WRONG MAP BRONZE RECIPE', self.prompt('when I can make bronze', self.corpus + [wrong]))

    def test_source_hashes_and_marker_drift_fail_closed(self):
        entries = bridge.bronze_knowledge(ROOT)
        for entry in entries:
            self.assertEqual(len(entry['sha256']), 64)
            for path, digest in entry['source_hashes'].items():
                self.assertEqual(hashlib.sha256((ROOT / path).read_bytes()).hexdigest(), digest)
        original = Path.read_bytes
        def changed(path):
            raw = original(path)
            if path.name == 'refining.dm':
                return raw.replace(b'/obj/structure/furnace/attack_hand', b'/obj/structure/furnace/renamed')
            return raw
        with mock.patch.object(Path, 'read_bytes', changed):
            with self.assertRaisesRegex(ValueError, 'Reviewed bronze source markers changed'):
                bridge.bronze_knowledge(ROOT)


if __name__ == '__main__':
    unittest.main()
