"""Offline packet/adapter contracts only. Never compiles or executes DM."""
import hashlib
import importlib.util
import json
import os
from pathlib import Path
import shutil
import sys
import tempfile
import textwrap
import unittest
from unittest.mock import patch

HERE = Path(__file__).resolve().parent
SPEC = importlib.util.spec_from_file_location('character_return_prepare', HERE / 'prepare.py')
PREP = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(PREP)
SOURCE = Path(os.environ.get('CIV13_CHARACTER_SOURCE_ROOT', HERE.parents[2])).resolve()


class PreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.output = Path(self.temp.name) / 'packet'

    def prepare(self, control=None):
        return PREP.prepare(SOURCE, self.output, control)

    def test_no_process_even_when_all_subprocess_entrypoints_are_poisoned(self):
        with patch('subprocess.Popen', side_effect=AssertionError('process forbidden')), \
             patch('subprocess.run', side_effect=AssertionError('process forbidden')), \
             patch('subprocess.check_output', side_effect=AssertionError('process forbidden')):
            receipt = self.prepare()
        self.assertTrue(receipt['prepared_only'])
        self.assertFalse(receipt['native_executed'])
        self.assertFalse(receipt['compiled'])

    def test_inputs_and_generic_generators_remain_byte_identical(self):
        before = PREP.verify_inputs(SOURCE)
        self.prepare()
        self.assertEqual(PREP.verify_inputs(SOURCE), before)

    def test_source_mismatch_rejected_before_output_or_import(self):
        bad = Path(self.temp.name) / 'source'
        for name in PREP.verify_inputs(SOURCE)['sha256']:
            target = bad / name
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(SOURCE / name, target)
        file = bad / 'code/modules/persistence/player_reclaim.dm'
        file.write_bytes(file.read_bytes() + b'\n// unexpected source\n')
        with patch.object(PREP, 'load_helpers', side_effect=AssertionError('import before pin check')):
            with self.assertRaisesRegex(ValueError, 'Pinned source mismatch'):
                PREP.prepare(bad, self.output)
        self.assertFalse(self.output.exists())

    def test_existing_output_is_never_overwritten(self):
        self.output.mkdir()
        marker = self.output / 'retained.txt'
        marker.write_text('keep')
        with self.assertRaisesRegex(ValueError, 'already exist'):
            self.prepare()
        self.assertEqual(marker.read_text(), 'keep')

    def test_unknown_native_cli_rejected_without_packet(self):
        argv = ['prepare.py', '--prepare-only', '--source-root', str(SOURCE),
                '--output', str(self.output), '--execute']
        with patch.object(sys, 'argv', argv), self.assertRaises(SystemExit) as error:
            PREP.main()
        self.assertEqual(error.exception.code, 2)
        self.assertFalse(self.output.exists())

    def test_unknown_control_rejected_without_packet(self):
        with self.assertRaisesRegex(ValueError, 'Unknown omission'):
            self.prepare('weaken-everything')
        self.assertFalse(self.output.exists())

    def test_reclaim_adaptation_is_exactly_reversible_and_keeps_five_accesses(self):
        base = PREP.load_helpers(SOURCE)
        original = (SOURCE / 'code/modules/persistence/player_reclaim.dm').read_text()
        adapted, before, after = PREP.adapt_reclaim(original, base)
        self.assertEqual(before.count('lobby.client'), 5)
        self.assertEqual(after.count('lobby.claim_client'), 5)
        inverted = adapted.replace('lobby.claim_client', 'lobby.client').replace(
            'var/datum/character_return_client/C', 'var/client/C').replace(
            'character_return_transfer(C, H)', 'H.key = C.key')
        self.assertEqual(inverted, original)
        for guard in ('persistence_player_claims[C.ckey] != lobby', 'C.mob != lobby',
                      'H.persistence_owner_ckey != C.ckey', 'H.client || H.key',
                      'if(C.mob != H)', 'persistence_restored_bodies.Remove(C.ckey)'):
            self.assertIn(guard, after)

    def test_admission_adaptation_is_exactly_reversible(self):
        base = PREP.load_helpers(SOURCE)
        original = (SOURCE / 'code/modules/persistence/bed_return.dm').read_text()
        adapted, before, after = PREP.adapt_bed(original, base)
        self.assertEqual(before.count('lobby.client'), 5)
        self.assertEqual(after.count('lobby.claim_client'), 5)
        self.assertEqual(adapted.replace('lobby.claim_client', 'lobby.client'), original)

    def test_changed_adapter_anchor_is_rejected_not_relaxed(self):
        base = PREP.load_helpers(SOURCE)
        original = (SOURCE / 'code/modules/persistence/player_reclaim.dm').read_text()
        with self.assertRaisesRegex(ValueError, 'Exact reclaim IO anchor changed'):
            PREP.adapt_reclaim(original.replace('lobby.client != C', 'FALSE'), base)

    def test_original_recovery_adapter_exposes_exact_five_vs_three_failure(self):
        # Execute only the immutable read/adapt block, not its CLI, build or run paths.
        source = (SOURCE / 'tests/world_save/run-durable-world.py').read_text()
        start = source.index("            relative = 'code/modules/persistence/player_reclaim.dm'", source.index('        if args.recovery_reconnect:\n'))
        end = source.index('        for index, (relative, text) in enumerate(replacements.items()):', start)
        block = textwrap.dedent(source[start:end])
        with patch('subprocess.Popen', side_effect=AssertionError('process forbidden')), \
             patch('subprocess.run', side_effect=AssertionError('process forbidden')):
            with self.assertRaisesRegex(RuntimeError, '^Reclaim client IO adapter anchor changed: lobby.client$'):
                exec(compile(block, 'immutable-recovery-adapter-excerpt', 'exec'), {'root': SOURCE, 'replacements': {}})

    def test_only_dedicated_disabled_stubs_removed(self):
        self.prepare()
        base = PREP.load_helpers(SOURCE)
        original = base.adapt_stubs((SOURCE / 'tests/world_save/stubs.dm').read_text())
        for name in PREP.DISABLED_STUBS:
            original = base.replace_once(original, base.extract_proc(original, name), '', name)
        self.assertEqual((self.output / 'stubs.dm').read_text(), original)
        self.assertIn('/obj/map_metadata/proc/uses_durable_metadata()\n\treturn FALSE', original)
        self.assertIn('Lost-limb restoration requires the production wound fixture', original)

    def test_real_saver_loader_and_other_sources_not_mutated(self):
        self.prepare()
        for filename in ('functions.dm', 'saving.dm', 'loading.dm', 'durable_graph.dm'):
            source = SOURCE / 'code/modules/persistence' / filename
            self.assertEqual((self.output / filename).read_text(), source.read_text(encoding='utf-8-sig'))

    def test_complete_include_closure_and_single_closed_startup(self):
        receipt = self.prepare()
        dme = (self.output / 'probe.dme').read_text()
        import re
        included = re.findall(r'^#include "([^"]+)"$', dme, re.M)
        for name in included:
            self.assertTrue((self.output / name).is_file(), name)
        combined = '\n'.join((self.output / name).read_text() for name in included)
        self.assertEqual(combined.count('/world/New()\n'), 1)
        self.assertIn('/world/OpenPort(port)\n\treturn ..("none")', combined)
        self.assertIn('/client/New()\n\tdel(src)', combined)
        self.assertIn('#define SPAN_WARNING(X)', combined)
        self.assertEqual(len(receipt['cases']), 11)

    def test_receipt_hashes_bind_every_generated_dm_file(self):
        receipt = self.prepare()
        for name, expected in receipt['generated_sha256'].items():
            self.assertEqual(hashlib.sha256((self.output / name).read_bytes()).hexdigest(), expected)
        self.assertEqual(json.loads((self.output / 'receipt.json').read_text()), receipt)

    def test_claim_consumption_omission_is_generated_only_and_case_bound(self):
        receipt = self.prepare('omit-claim-consume')
        source = (self.output / 'player_reclaim.dm').read_text()
        self.assertNotIn('persistence_restored_bodies.Remove(C.ckey)', source)
        self.assertIn('persistence_restored_bodies.Remove(C.ckey)', (SOURCE / 'code/modules/persistence/player_reclaim.dm').read_text())
        self.assertEqual(receipt['cases'], ['repeat-return'])
        self.assertEqual(receipt['expected_result'], 'FAIL: repeated return moved back to bed')

    def test_reservation_omission_retains_posthook_ownership_checks(self):
        receipt = self.prepare('omit-reservation')
        source = (self.output / 'player_reclaim.dm').read_text()
        self.assertNotIn('persistence_player_claims[C.ckey] || character_recovery_unready()', source)
        self.assertIn('persistence_player_claims[C.ckey] != lobby', source)
        self.assertEqual(receipt['cases'], ['reserved'])

    def test_bed_owner_omission_does_not_stub_bed_policy(self):
        receipt = self.prepare('omit-bed-owner')
        self.assertIn('/obj/structure/bed/persistence_runtime_var(key)', (self.output / 'character_return_fixture.dm').read_text())
        self.assertIn('var/pending_return = registered && (H in registered)', (self.output / 'bed_return.dm').read_text())
        self.assertEqual(receipt['cases'], ['disk'])

    def test_disk_and_repeat_oracles_are_not_whitelist_shortcuts(self):
        fixture = (HERE / 'fixture.dm').read_text()
        self.assertNotIn('/get_saved_vars()', fixture)
        for evidence in ('map_storage.validate_world_save()', 'map_storage.Load_World()',
                         'disk bed ownership lost', 'repeated return moved back to bed',
                         'H.health == 23 && H.nutrition == 83 && H.water == 29',
                         'H.fixture_medical == M', 'H.persistence_restored'):
            self.assertIn(evidence, fixture)

    def test_disk_resets_old_registry_and_uses_production_readiness(self):
        fixture = (HERE / 'fixture.dm').read_text()
        disk = fixture[fixture.index('if(cross_case == "disk")'):fixture.index('if(cross_case == "repeat-return")')]
        self.assertLess(disk.index('map_storage.reset_player_restoration()'), disk.index('map_storage.ClearMap()'))
        self.assertLess(disk.index('map_storage.Load_World()'), disk.index('map_storage.finish_player_restoration()'))
        self.assertNotIn('persistence_player_restore_ready = TRUE', disk)

    def test_zone_adapter_is_limited_to_dedicated_metadata_subtype(self):
        self.prepare()
        fixture = (self.output / 'character_return_fixture.dm').read_text()
        self.assertIn('/map_storage/cross_level/character_return/begin_zone_export(generation)', fixture)
        self.assertNotIn('/map_storage/proc/begin_zone_export', fixture)
        self.assertIn('Topology needs the full-source fixture', (self.output / 'stubs.dm').read_text())


if __name__ == '__main__':
    unittest.main()
