"""Source preparation/acceptance guards only; no BYOND or browser launch."""
from pathlib import Path
import tempfile
import unittest

from run import ASSETS, CREATION, OMISSION_FAILURES, PREFIX, ROOT, prepare, replace_once, sources, verify_result


class FactionAssets(unittest.TestCase):
    def test_getter_registers_only_new_assets_before_return(self):
        source = (ROOT / ASSETS).read_text(encoding='utf-8')
        getter = source.split('/proc/get_asset_datum(var/type)\n', 1)[1].split('/datum/asset/New()', 1)[0]
        self.assertIn('var/datum/asset/A = new type()\n', getter)
        self.assertIn('\t\tA.register()\n\t\treturn A\n\treturn asset_datums[type]', getter)
        constructor = source.split('/datum/asset/New()\n', 1)[1].split('/datum/asset/proc/register()', 1)[0]
        self.assertIn('asset_datums[type] = src', constructor)
        # Publication by New precedes registration, so a self lookup reuses it.
        register = source.split('/datum/asset/nanoui/register()\n', 1)[1].split('/datum/asset/nanoui/send(', 1)[0]
        self.assertNotIn('get_asset_datum(', register)
        self.assertIn('register_asset(filename,', register)

    def test_accepted_restore_path_and_browser_resources(self):
        ticker = (ROOT / 'code/game/gameticker.dm').read_text(encoding='utf-8')
        setup = ticker.split('/datum/controller/gameticker/proc/setup()\n', 1)[1]
        self.assertLess(setup.index('if(map_storage.round_restored) return TRUE'), setup.index('callHook("roundstart")'))
        creation = (ROOT / CREATION).read_text(encoding='utf-8')
        self.assertIn('"faction_creation.tmpl"', creation)
        for directory, files in {'UI/js': ['libraries.min.js', 'nano_template.js', 'faction_symbol.js'],
                                 'UI/templates': ['faction_creation.tmpl', 'layout_basic.tmpl'],
                                 'UI/css': ['civ13_theme.css', 'faction_symbol.css', 'layout_basic.css']}.items():
            for name in files:
                self.assertTrue((ROOT / directory / name).is_file())

    def test_profiles_preserve_actual_handlers_and_only_omit_registration(self):
        positive, omission = sources(), sources(True)
        assets = positive[PREFIX + '_assets.dm']
        self.assertEqual(assets.replace('\t\tA.register()\n\t\treturn A\n', '\t\treturn A\n'), omission[PREFIX + '_assets.dm'])
        self.assertIn('/datum/asset/nanoui/register()\n\tfaction_ui_registrations++\n', assets)
        self.assertIn('fcopy_rsc(path + filename)', assets)
        self.assertIn('/datum/nanoui/faction_assets_probe(user, src,', positive[PREFIX + '_creation.dm'])
        self.assertNotIn('.dmm"', positive[PREFIX + '.dme'])
        self.assertNotIn('CIV13_GAMEPLAY_BRIDGE', positive[PREFIX + '.dme'])
        self.assertEqual(positive[PREFIX + '_creation.dm'], omission[PREFIX + '_creation.dm'])
        for text in ('absent', 'duplicate duplicate'):
            with self.assertRaises(ValueError):
                replace_once(text, 'duplicate', 'replacement')

    def test_preparation_is_fresh_and_hash_bound(self):
        with tempfile.TemporaryDirectory() as folder:
            destination = Path(folder) / 'prepared'
            generated, metadata = prepare(destination)
            self.assertEqual(set(generated), set(metadata['generated_sha256']))
            self.assertIn(ASSETS, metadata['source_sha256'])
            self.assertIn('UI/templates/faction_creation.tmpl', metadata['source_sha256'])
            with self.assertRaises(ValueError):
                prepare(destination)

    def test_controls_require_complete_exact_named_failures(self):
        labels = sorted(OMISSION_FAILURES) + ['other-' + str(i) for i in range(13)]
        checks = [dict(label=label, passed=True) for label in labels]
        good = dict(port=0, check_count=18, checks=checks, failed_labels=[])
        verify_result(good, False)
        for changes in (dict(port=1234), dict(check_count=17), dict(checks=[]), dict(failed_labels=['unrelated'])):
            with self.assertRaises(ValueError):
                verify_result(dict(good, **changes), False)
        negative_checks = [dict(label=label, passed=label not in OMISSION_FAILURES) for label in labels]
        verify_result(dict(good, checks=negative_checks, failed_labels=sorted(OMISSION_FAILURES)), True)
        with self.assertRaises(ValueError):
            verify_result(good, True)


if __name__ == '__main__':
    unittest.main()
