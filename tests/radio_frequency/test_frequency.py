"""Offline projections of radio frequency checks; no BYOND runtime or gameplay."""
import importlib.util
from itertools import product
from pathlib import Path
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).parent
RADIO = ROOT / 'code/modules/1713/radio.dm'
SPEC = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
ADAPTER = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(ADAPTER)
ADAPTER.FIELDS += ('freq', 'multifreq', 'multifreqlist')

ITEM = '/obj/item/weapon/radio'
STRUCTURE = '/obj/structure/radio'
HELPER = '/proc/radio_transmitter_frequency_matches'


def istype(obj, path):
    return obj is not None and (obj.path == path or obj.path.startswith(path + '/'))


def project(source, declaration, args, *, method=False, env=None):
    # DM type paths in istype() become opaque strings for the fake type boundary.
    source = source.replace(', ' + ITEM + ')', ', "' + ITEM + '")')
    source = source.replace(', ' + STRUCTURE + ')', ', "' + STRUCTURE + '")')
    return ADAPTER.project(source, declaration, args, dict(env or {}, istype=istype), method=method)


def new_checks(source):
    helper = project(source, HELPER, 'original, source_freq, source_multifreq, source_multifreqlist')
    checks = []
    for path in (ITEM, STRUCTURE):
        checks.append(project(source, path + '/proc/check_freq', 'src, original', method=True,
                              env={'radio_transmitter_frequency_matches': helper}))
    return checks


def old_checks():
    baseline = (HERE / 'before.dm.txt').read_text(encoding='utf-8')
    return [project(baseline, path + '/proc/check_freq', 'src, original', method=True)
            for path in (ITEM, STRUCTURE)]


def radio(path, freq=150, multifreq=False, channels=()):
    return SimpleNamespace(path=path, freq=freq, multifreq=multifreq, multifreqlist=list(channels))


class FrequencyTests(unittest.TestCase):
    def test_equivalence_with_original_both_transmitter_and_receiver_types(self):
        old, new = old_checks(), new_checks(RADIO.read_text(encoding='utf-8-sig'))
        targets = [None, SimpleNamespace(path='/obj/structure/chair')]
        targets += [radio(path, freq, True, [999]) for path, freq in product(
            (ITEM, ITEM + '/headset', STRUCTURE, STRUCTURE + '/receiver'),
            (150, 151, '150', 0))]
        for index, source_path in enumerate((ITEM, STRUCTURE)):
            for freq, multi, channels, target in product(
                    (150, '150', 0), (False, True), ((), (150,), ('150',), (151, 0)), targets):
                with self.subTest(source=source_path, freq=freq, multi=multi, channels=channels, target=target):
                    sender = radio(source_path, freq, multi, channels)
                    self.assertEqual(new[index](sender, target), old[index](sender, target))

    def test_null_unknown_and_direction(self):
        for check, path in zip(new_checks(RADIO.read_text(encoding='utf-8-sig')), (ITEM, STRUCTURE)):
            sender = radio(path, 150, True, [151])
            self.assertIsNone(check(sender, None))
            self.assertIs(check(sender, SimpleNamespace(path='/obj/item')), False)
            # Only the transmitter's list determines multi-channel matching.
            self.assertTrue(check(sender, radio(ITEM, 151, True, [999])))
            self.assertFalse(check(sender, radio(ITEM, 150, True, [151])))
            sender.multifreq = False
            self.assertTrue(check(sender, radio(STRUCTURE, 150, True, [999])))
            self.assertFalse(check(sender, radio(STRUCTURE, 151, True, [150])))
            self.assertFalse(check(sender, radio(ITEM, '150')))

    def test_negative_controls_detect_reversed_and_wrong_single_comparisons(self):
        source = RADIO.read_text(encoding='utf-8-sig')
        mutations = (
            ('SR.freq in source_multifreqlist', 'source_freq in SR.multifreqlist'),
            ('if (R.freq == source_freq)', 'if (R.freq != source_freq)'),
        )
        for before, after in mutations:
            self.assertIn(before, source)
            mutant = new_checks(source.replace(before, after, 1))[0]
            sender = radio(ITEM, 150, True, [151])
            if before.startswith('SR'):
                target = radio(STRUCTURE, 151, True, [999])
            else:
                sender.multifreq = False
                target = radio(ITEM, 150)
            self.assertNotEqual(mutant(sender, target), old_checks()[0](sender, target))


if __name__ == '__main__':
    unittest.main()
