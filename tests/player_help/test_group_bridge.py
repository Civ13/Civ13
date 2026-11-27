"""Shared bridge lifecycle and fairness using private spools and an offline model."""
import importlib.util
import json
from pathlib import Path
import tempfile
import threading
import time
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('group_test_bridge', ROOT / 'scripts/player_help_bridge.py')
help_bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(help_bridge)


class SharedBridgeTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.manifest = self.root / 'regions.json'
        self.regions = {region: {'game_root': str(self.root / region), 'listed': listed}
                        for region, listed in (('gaia', True), ('deep', True), ('other', False))}
        self.publish()
        self.calls = []
        self.release = {}
        self.config = {'enabled': True, 'model': 'offline', 'endpoint': 'http://invalid/api/chat',
                       'workers': 1, 'timeout_seconds': 5, 'poll_seconds': 0.01}
        self.broken = set()
        self.distinct = set()
        self.service = help_bridge.GroupBridge(self.manifest, self.config, self.transport, self.corpus)
        self.addCleanup(self.service.close)
        self.addCleanup(lambda: [event.set() for event in self.release.values()])

    def publish(self):
        help_bridge.atomic_json(self.manifest, self.regions)

    def corpus(self, root, *_):
        if root.name in self.broken:
            raise ValueError('private path must not be logged')
        return [{'topic': 'Test', 'text': 'Different' if root.name in self.distinct else 'Common'}], {}

    def transport(self, _endpoint, payload, *_):
        question = payload['messages'][-1]['content']
        self.calls.append(question)
        if question in self.release and not self.release[question].wait(3):
            raise TimeoutError()
        return {'message': {'content': question}}

    def until(self, predicate):
        deadline = time.monotonic() + 4
        while not predicate() and time.monotonic() < deadline:
            self.service.tick()
            time.sleep(0.01)
        self.assertTrue(predicate())

    def spool(self, region):
        return self.root / region / 'SQL/player-help'

    def question(self, region, question, slot=1):
        spool = self.spool(region)
        request_id = f'10-20-{slot}'
        help_bridge.atomic_json(spool / f'{slot}.request.json', {
            'id': request_id, 'account': str(slot) * 32, 'question': question})
        (spool / f'{slot}.ready').write_bytes((request_id + '\r\n').encode('ascii'))

    def response(self, region, slot=1):
        return self.spool(region) / f'{slot}.response.json'

    def test_same_slot_and_id_never_mix_and_busy_region_cannot_starve_another(self):
        self.until(lambda: len(self.service.bridges) == 2)
        self.assertIs(self.service.bridges['gaia'].corpus, self.service.bridges['deep'].corpus)
        self.release['Gaia first'] = threading.Event()
        self.question('gaia', 'Gaia first')
        self.question('gaia', 'Gaia second', 2)
        self.question('deep', 'Deep first')
        self.until(lambda: self.calls == ['Gaia first'])
        for _ in range(4):
            self.service.tick()
        self.assertEqual(['Gaia first'], self.calls)
        self.assertEqual(1, sum(len(worker.active) for worker in self.service.bridges.values()))
        self.release['Gaia first'].set()
        self.until(lambda: self.response('gaia', 2).exists() and self.response('deep').exists())
        self.assertEqual(['Gaia first', 'Deep first', 'Gaia second'], self.calls)
        for region, answer in (('gaia', 'Gaia first'), ('deep', 'Deep first')):
            self.assertEqual(('10-20-1', answer), tuple(json.loads(self.response(region).read_text())[key]
                                                       for key in ('id', 'answer')))

    def test_stop_drains_only_one_spool_and_start_reuses_the_process(self):
        self.distinct.add('deep')
        self.until(lambda: len(self.service.bridges) == 2)
        self.assertIsNot(self.service.bridges['gaia'].corpus, self.service.bridges['deep'].corpus)
        self.release['Gaia finishing'] = threading.Event()
        self.question('gaia', 'Gaia finishing')
        self.until(lambda: bool(self.calls))
        (self.root / 'gaia.off').touch()
        self.question('gaia', 'Gaia blocked', 2)
        self.question('deep', 'Deep still active')
        self.service.tick()
        self.assertFalse(json.loads((self.spool('gaia') / 'health.json').read_text())['enabled'])
        self.assertTrue((self.spool('gaia') / 'worker.lock').exists())
        self.release['Gaia finishing'].set()
        self.until(lambda: self.response('deep').exists())
        self.assertTrue(self.response('gaia').exists())
        self.assertFalse((self.spool('gaia') / 'worker.lock').exists())
        self.assertEqual(['Gaia finishing', 'Deep still active'], self.calls)
        self.assertIn('deep', self.service.bridges)
        (self.root / 'gaia.off').unlink()
        self.until(lambda: 'gaia' in self.service.bridges)
        self.assertFalse((self.spool('gaia') / '2.ready').exists())

    def test_legacy_lock_is_preserved_and_a_bad_corpus_does_not_hold_other_regions(self):
        old = help_bridge.Bridge(self.spool('gaia'), self.config, [])
        self.addCleanup(old.close)
        self.broken.add('deep')
        (self.root / 'other.on').touch()
        self.until(lambda: 'other' in self.service.bridges)
        self.assertEqual({'other'}, set(self.service.bridges))
        self.assertTrue(old.lock.exists())
        with self.assertRaises(FileExistsError):
            help_bridge.GroupBridge(self.manifest, self.config)
        old.close()
        self.until(lambda: 'gaia' in self.service.bridges)
        self.assertNotIn('deep', self.service.bridges)
        (self.root / 'stopped').touch()
        self.until(lambda: not self.service.bridges)
        self.assertFalse((self.spool('other') / 'worker.lock').exists())


if __name__ == '__main__':
    unittest.main()
