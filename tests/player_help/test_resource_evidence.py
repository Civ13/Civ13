"""Offline, injected retrieval checks for reviewed material shard evidence."""
from pathlib import Path
import shutil
import tempfile
import unittest
from unittest import mock
import test_bridge

bridge = test_bridge.bridge
ROOT = Path(__file__).resolve().parents[2]


class ResourceEvidenceTests(unittest.TestCase):
    setUp = test_bridge.BridgeTests.setUp
    tearDown = test_bridge.BridgeTests.tearDown
    make = test_bridge.BridgeTests.make
    def test_constructed_material_names_and_prompt_evidence(self):
        self.corpus = bridge.gameplay_knowledge(ROOT)
        payloads = []
        instance = self.make(lambda _, payload, *args: payloads.append(payload) or
                             {'message': {'content': 'Injected answer'}})
        for question, alias in [('What is flint shrapnel used for?', 'flint shrapnel'),
                                ('Can I use a glass shard?', 'glass shard'),
                                ('What does steel shrapnel do?', 'steel shrapnel')]:
            with self.subTest(question=question):
                request = {'id': '1-2-3', 'account': 'a' * 32, 'question': question}
                self.assertEqual(instance.answer(request)['status'], 'ok')
                prompt = payloads[-1]['messages'][0]['content'].lower()
                instance.limiter.accounts.clear()
                instance.limiter.global_times.clear()
                self.assertIn(alias, prompt)
                self.assertIn('shard', prompt)
                self.assertIn('foot', prompt)
                self.assertNotIn('do not index this secret', prompt)

    def test_unknown_term_does_not_invent_resource(self):
        self.corpus = bridge.resource_knowledge(ROOT)
        payloads = []
        instance = self.make(lambda _, payload, *args: payloads.append(payload) or
                             {'message': {'content': 'I do not know.'}})
        request = {'id': '1-2-4', 'account': 'b' * 32, 'question': 'What is zyzzyquux?' }
        self.assertEqual(instance.answer(request)['status'], 'ok')
        self.assertNotIn('flint shrapnel', payloads[0]['messages'][0]['content'].lower())

    def test_allowlist_refuses_changed_contract_and_excludes_unreviewed_files(self):
        sources = bridge.resource_knowledge(ROOT)
        self.assertTrue(sources)
        self.assertTrue(all(row['source'] == 'code' and row.get('source_hashes') for row in sources))
        with mock.patch.object(bridge, 'RESOURCE_SOURCE_MARKERS', ('missing marker',)):
            with self.assertRaises(ValueError):
                bridge.resource_knowledge(ROOT)
        with tempfile.TemporaryDirectory() as temporary:
            target = Path(temporary)
            for relative in ('code/modules/materials/materials.dm',
                             'code/game/objects/items/weapons/material/shards.dm', 'code/predefines.dm',
                             'code/game/objects/items/clothing/clothing.dm',
                             'code/modules/reagents/reagent_containers/food/sandwich.dm'):
                dest = target / relative
                dest.parent.mkdir(parents=True, exist_ok=True)
                shutil.copyfile(ROOT / relative, dest)
            (target / 'private.txt').write_text('DO NOT INDEX THIS SECRET')
            self.assertNotIn('DO NOT INDEX THIS SECRET', str(bridge.resource_knowledge(target)))
            materials = target / 'code/modules/materials/materials.dm'
            value = materials.read_text(encoding='utf-8').replace('/material/flint\n', '/material/flint\n\tshard_type = null\n', 1)
            materials.write_text(value, encoding='utf-8')
            with self.assertRaisesRegex(ValueError, 'shard type changed: flint'):
                bridge.resource_knowledge(target)


if __name__ == '__main__':
    unittest.main()
