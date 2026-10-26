"""Offline ownership/source regressions, not DM compilation or native evidence."""
import hashlib
import json
from pathlib import Path
import subprocess
import tempfile
import unittest

import prepare

UNCHANGED = {
    'proc/reproduction()': 'b9e0107c31c99574e51ee33f19bca51e10e917524b1d30a05305e465478bcb61',
    'proc/Ticker()': '796152a1b051572c30d1a93a0690c65d74d2733044528d99a75f501d0c8e81bf',
    'proc/wolf_out()': 'b1b657feb98490a827f220f1e391e4b7631ee2e5ecbfae54426582c6c757c340',
    'proc/aggro()': '82e07a30f7352458e631a51637c92106600b3ea41b5d84ee7403a6859569b3fd',
    'proc/process_cub(': '19e57285e3c08d75c7a9f3b6c0039ad891b76ffa5e2bcd35bef1c5f32f2c3d64',
    'proc/set_cavetype()': '0d33759d5daab35f8aa7498f209d72a09b392d5ac450e56e82f8cb156e774ecd',
}


def contract(source):
    """Inspect production ownership paths; reject the audited defect and controls."""
    new = prepare.method(source, 'New()')
    full = prepare.method(source, 'full/New()')
    tick = prepare.method(source, 'proc/Tick()')
    stop = prepare.method(source, 'Destroy()')
    saved = prepare.method(source, 'persistence_runtime_var(key)')
    assert new.count('\tTick()\n') == 1 and 'ticking =' not in new, 'constructor ownership'
    assert 'Tick()' not in full and 'wolfcave_ticking' not in source, 'full extra chain'
    assert '\tif(ticking || gcDestroyed || gc_destroyed)\n\t\treturn\n' in tick, 'duplicate start'
    assert '\tticking = TRUE\n' in tick, 'synchronous claim'
    assert '\tspawn while(src && ticking && !gcDestroyed && !gc_destroyed)\n' in tick, 'retirement guard'
    assert 'for(' not in tick and ' in world' not in tick and 'B.' not in tick, 'global scan'
    recount = '\t\ttotal_population = males + females + cubs\n'
    assert recount in tick, 'population recount'
    assert tick.index(recount) < tick.index('\t\tTicker()\n') < tick.index('\t\tsleep('), 'service order'
    assert '\tticking = FALSE\n' in stop and '\treturn ..()\n' in stop, 'stop and parent cleanup'
    assert 'return key == "ticking" || ..()' in saved, 'saved timer and inherited exclusions'


class SourceTests(unittest.TestCase):
    def test_production_owns_one_self_chain_and_keeps_five_second_wait(self):
        source = prepare.read(prepare.SOURCE)
        contract(source)
        tick = prepare.method(source, 'proc/Tick()')
        self.assertEqual(tick.count('spawn '), 1)
        self.assertEqual(tick.count('sleep(50)'), 1)
        self.assertNotIn('wolfcave_ticking', prepare.read('code/global.dm'))

    def test_existing_population_rng_and_cooldown_bodies_are_unchanged(self):
        source = prepare.read(prepare.SOURCE)
        for suffix, expected in UNCHANGED.items():
            with self.subTest(suffix=suffix):
                self.assertEqual(hashlib.sha256(prepare.method(source, suffix).encode()).hexdigest(), expected)

    def test_full_initialization_still_delegates_to_randomizing_parent(self):
        source = prepare.read(prepare.SOURCE)
        full = prepare.method(source, 'full/New()')
        self.assertIn('src.males = 5', full)
        self.assertIn('src.females = 5', full)
        self.assertEqual(full.count('\t..()'), 1)
        new = prepare.method(source, 'New()')
        self.assertIn('src.males = pick(1, 2, 3)', new)
        self.assertIn('src.females = pick(1, 2, 3)', new)
        self.assertLess(new.index('src.set_cavetype()'), new.index('\tTick()'))

    def test_custom_save_checks_exclusion_on_both_export_and_import(self):
        self.assertIn('if (persistence_runtime_var(key))', prepare.read('code/modules/persistence/functions.dm'))
        self.assertIn('if(A.persistence_runtime_var(v))', prepare.read('code/modules/persistence/saving.dm'))
        self.assertIn('if(object.persistence_runtime_var(v))', prepare.read('code/modules/persistence/loading.dm'))

    def test_generated_mutants_each_break_their_named_source_contract(self):
        targets = {'world-scan': 'global scan', 'duplicate-start': 'duplicate start',
                   'missing-stop': 'stop and parent cleanup', 'saved-flag': 'Expected one cave method',
                   'missing-recount': 'population recount', 'baseline': 'Expected one cave method'}
        contract(prepare.production())
        for case, failure in targets.items():
            with self.subTest(case=case), self.assertRaisesRegex((AssertionError, ValueError), failure):
                contract(prepare.production(case))

    def test_historical_control_is_the_pinned_audited_scan(self):
        source = subprocess.check_output(['git', '-C', str(prepare.ROOT), 'show',
                                          f'{prepare.BASE}:{prepare.SOURCE}']).decode().replace('\r\n', '\n')
        self.assertIn('for(var/obj/structure/animalspawner/wolfcave/B in world)', prepare.method(source, 'proc/Tick()'))
        self.assertIn('if(!wolfcave_ticking)', prepare.method(source, 'full/New()'))

    def test_extraction_keeps_column_zero_comments_inside_ticker(self):
        ticker = prepare.method(prepare.read(prepare.SOURCE), 'proc/Ticker()')
        self.assertIn('//################## Description', ticker)
        self.assertIn('src.reproduction()', ticker)
        self.assertIn('spawn(4500)', ticker)
        self.assertTrue(ticker.rstrip().endswith('src.set_cavetype()'))

    def test_preparation_is_fresh_hashed_and_never_runs_native_tools(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory) / 'packet'
            manifest = prepare.prepare(output)
            self.assertFalse(manifest['native_executed'])
            self.assertFalse(manifest['compiler_executed'])
            self.assertEqual(manifest['bounds']['map'], [12, 12, 1])
            self.assertEqual(set(manifest['cases']), set(prepare.CASES))
            for case, files in manifest['cases'].items():
                for name, expected in files.items():
                    self.assertEqual(hashlib.sha256((output / case / name).read_bytes()).hexdigest(), expected)
                generated = (output / case / 'production.dm').read_text()
                fixture = (output / case / 'probe.dm').read_text()
                parent = (output / case / 'parent.dm').read_text()
                # The real movable base is not included in this isolated DME.
                # Keep its inherited declaration and the production override.
                self.assertIn('/atom/movable\n\tvar/anchored = FALSE\n', fixture)
                self.assertIn('\tanchored = TRUE\n', parent)
                self.assertIn('sleep(2)', generated)
                self.assertNotIn('sleep(50)', generated)
                self.assertIn('spawn(procreate_holder)', generated)
                self.assertIn('spawn(wanderer_holder)', generated)
            self.assertEqual(json.loads((output / 'manifest.json').read_text()), manifest)
            with self.assertRaises(FileExistsError):
                prepare.prepare(output)

    def test_native_fixture_has_lifecycle_oracles_and_closed_port_adapter(self):
        fixture = prepare.read('tests/wolf_cave_ownership/probe.dm')
        for marker in ('list(1, 3, 10)', 'one chain', 'retired sleeper stops',
                       'survivor after first-owner removal', 'late creation',
                       'replacement serviced once', 'Destroy stops sleeper',
                       'native deletion stops sleeper', 'timer excluded from custom save',
                       'cooldown suppresses next roll', 'spawn(150)', 'OpenPort("none")',
                       '/world/OpenPort(port)', '/client/New()', '/world/Error(exception/E)'):
            self.assertIn(marker, fixture)
        self.assertNotIn('shell(', fixture)
        self.assertNotIn('world.Export', fixture)


if __name__ == '__main__':
    unittest.main()
