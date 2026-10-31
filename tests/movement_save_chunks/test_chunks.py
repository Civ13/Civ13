"""Offline algorithm and source-boundary checks; NOT native DM execution."""
from copy import deepcopy
from pathlib import Path
import unittest
import re
import tempfile
import importlib.util
import hashlib

ROOT = Path(__file__).resolve().parents[2]
SAVING = (ROOT / 'code/modules/persistence/saving.dm').read_text()
FUNCTIONS = (ROOT / 'code/modules/persistence/functions.dm').read_text()

class Refused(Exception):
    pass

class Attempt:
    """Projection of admitted empty-root ownership, not a DM interpreter."""
    def __init__(self, roots, roster=True, origin_guard=True):
        self.live = deepcopy(roots)
        self.roster = list(roots) if roster else []
        self.origin_guard = origin_guard
        self.records = {}
        self.owners = {}
        self.previous = {'generation': 'good', 'bytes': b'unchanged'}
        self.marker = None
        self.captures = 0

    def capture(self, identity):
        if identity in self.records:
            return
        root = self.live.get(identity)
        if not root or root.get('contents') or root['z'] != 1:
            raise Refused('unsupported mutation')
        self.records[identity] = deepcopy(root)
        self.captures += 1

    def edge(self, identity, turf):
        if self.origin_guard and turf != self.records[identity]['loc']:
            return
        self.owners.setdefault(identity, turf)

    def scan(self, turf):
        for identity, root in list(self.live.items()):
            if root['loc'] == turf:
                self.capture(identity)
                self.edge(identity, turf)

    def finish(self):
        for identity in self.roster:
            root = self.live.get(identity)
            if not root or root.get('contents') or root['z'] != 1:
                raise Refused('unsupported mutation')
            self.capture(identity)
            origin = self.records[identity]['loc']
            if identity in self.owners and self.owners[identity] != origin:
                raise Refused('conflicting owners')
            self.owners[identity] = origin
        self.marker = 'new'


def roots():
    return {'animal': {'loc': 'B', 'z': 1, 'name': 'paid pet', 'contents': []}}

class AlgorithmTests(unittest.TestCase):
    def test_uncaptured_root_crosses_behind_frontier(self):
        a = Attempt(roots()); a.scan('A'); a.live['animal']['loc'] = 'A'; a.scan('B'); a.finish()
        self.assertEqual(a.owners, {'animal': 'A'})
        broken = Attempt(roots(), roster=False)
        broken.scan('A'); broken.live['animal']['loc'] = 'A'; broken.scan('B'); broken.finish()
        self.assertNotEqual(broken.owners, a.owners, 'roster omission must lose the root')

    def test_detached_fields_survive_writing_interleavings(self):
        a = Attempt(roots()); a.capture('animal')
        for i in range(100):
            a.live['animal']['loc'] = 'A' if i % 2 else 'B'
            a.live['animal']['name'] = 'changed while writing'
            a.scan(a.live['animal']['loc'])
        a.finish()
        self.assertEqual(a.records['animal']['name'], 'paid pet')
        self.assertEqual(a.owners, {'animal': 'B'})
        self.assertEqual(a.captures, 1)

    def test_reference_before_spatial_discovery(self):
        for guard in (True, False):
            a = Attempt(roots(), origin_guard=guard)
            a.capture('animal'); a.live['animal']['loc'] = 'A'; a.scan('A')
            if guard:
                a.finish(); self.assertEqual(a.owners['animal'], 'B')
            else:
                with self.assertRaisesRegex(Refused, 'conflicting owners'): a.finish()

    def test_two_roots_swap_without_duplicate_capture(self):
        r = roots(); r['other'] = dict(r['animal'], loc='A', name='other')
        a = Attempt(r); a.capture('animal'); a.capture('other')
        a.live['animal']['loc'], a.live['other']['loc'] = 'A', 'B'
        a.scan('A'); a.scan('B'); a.finish()
        self.assertEqual(a.owners, {'animal': 'B', 'other': 'A'})
        self.assertEqual(a.captures, 2)

    def test_unsupported_mutations_preserve_previous_generation(self):
        for mutation in ('delete', 'inventory', 'cross_z'):
            with self.subTest(mutation=mutation):
                a = Attempt(roots()); prior = deepcopy(a.previous); a.capture('animal')
                if mutation == 'delete': del a.live['animal']
                elif mutation == 'inventory': a.live['animal']['contents'] = ['item']
                else: a.live['animal']['z'] = 2
                with self.assertRaises(Refused): a.finish()
                self.assertIsNone(a.marker); self.assertEqual(a.previous, prior)

class ProductionBoundaryTests(unittest.TestCase):
    def test_roster_and_drain_are_in_real_save(self):
        body = SAVING.split('/map_storage/proc/BuildVarDirectory', 1)[0]
        self.assertLess(body.index('prepare_moving_save_roster()'), body.index('var/backup_dir'))
        self.assertLess(body.index('drain_moving_save_roster(savefile)'), body.index('savefile.Flush()'))
        self.assertIn('global.vars["mob_list"]', SAVING)

    def test_budget_and_no_partial_retry(self):
        for guard in ('nodes > 128', 'edges > 2048', 'reserved_bytes > 1048576', 'work > 8192', 'world.time != start_tick'):
            self.assertIn(guard, SAVING)
        stage = SAVING.split('/map_storage/proc/capture_moving_save_root', 1)[1].split('/map_storage/proc/moving_save_root_edge', 1)[0]
        self.assertIn('moving_save_chunk = null\n\t\t// IDs', stage)
        self.assertIn('throw error', stage)
        self.assertNotIn('retry', stage)
        self.assertIn('moving_save_roots = list()\n\tmoving_save_chunk = null', FUNCTIONS)

    def test_detached_replay_and_origin_owner(self):
        self.assertIn('var/value = staged[path]\n\t\tdestination[path] << value', SAVING)
        self.assertIn('frame.source != moving_root["origin"]', FUNCTIONS)
        self.assertIn('Moving save root entered a captured container', FUNCTIONS)
        self.assertIn('Moving save roster member disappeared or changed ownership', SAVING)

    def test_preflight_falls_back_without_allocating_serializer_ids(self):
        preflight = SAVING.split('/datum/moving_save_preflight\n', 1)[1].split('/datum/moving_save_capture\n', 1)[0]
        self.assertIn('istype(D, /atom/movable) && D != root', preflight)
        for forbidden in ('bind_entry(', 'BuildVarDirectory(', 'saving_references[', 'before_save('):
            self.assertNotIn(forbidden, preflight)
        self.assertIn('if(registry.len > 8192) return', SAVING)
        self.assertIn('for(var/ignored in ignore_types)', SAVING)

    def test_frontier_replay_revalidates_before_ownership_publication(self):
        drain = SAVING.split('/map_storage/proc/drain_moving_save_roster', 1)[1]
        self.assertLess(drain.index('capture_moving_save_root(F, record)'), drain.index('changed during chunk replay'))
        self.assertLess(drain.index('changed during chunk replay'), drain.index('F[path] << chunks'))

    def test_animal_callback_inventory_requires_explicit_reaudit(self):
        found = set()
        pattern = re.compile(r'^(/mob/living/simple_animal[^\n(]*/(?:before_save|before_save_context|get_saved_vars|persistence_runtime_var))\(', re.M)
        for path in (ROOT / 'code').rglob('*.dm'):
            found.update(pattern.findall(path.read_text(errors='replace')))
        self.assertEqual(found, {
            '/mob/living/simple_animal/before_save',
            '/mob/living/simple_animal/persistence_runtime_var',
            '/mob/living/simple_animal/hostile/persistence_runtime_var',
            '/mob/living/simple_animal/pet/persistence_runtime_var',
        }, 'New animal projection hooks require a nonyielding/ownership audit')

    def test_packet_materializes_only_hashed_sources(self):
        spec = importlib.util.spec_from_file_location('moving_packet', ROOT / 'tests/movement_save_chunks/prepare.py')
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            for name, digest in module.prepare(output).items():
                self.assertEqual(hashlib.sha256((output / name).read_bytes()).hexdigest(), digest)
            self.assertFalse(list(output.rglob('*.dmb')))
            self.assertFalse((output / 'result.txt').exists())

    def test_correctness_preparation_cannot_launch_native(self):
        spec = importlib.util.spec_from_file_location('moving_correctness', ROOT / 'tests/movement_save_chunks/correctness.py')
        module = importlib.util.module_from_spec(spec); spec.loader.exec_module(module)
        from unittest.mock import patch
        import subprocess
        with tempfile.TemporaryDirectory() as directory, patch.object(subprocess, 'Popen', side_effect=AssertionError('native forbidden')):
            output = Path(directory) / 'new-packet'
            self.assertEqual(module.main(['--output', str(output)]), 0)
            self.assertIn('return // omission control', (output / 'roster-source/code/modules/persistence/saving.dm').read_text())
            self.assertNotIn(module.ORIGIN_ANCHOR, (output / 'origin-source/code/modules/persistence/functions.dm').read_text())
            control_source = (output / 'origin-source/code/modules/persistence/functions.dm').read_text()
            control_proc = control_source.split('/map_storage/proc/add_export_content(', 1)[1].split('/map_storage/proc/', 1)[0]
            self.assertNotIn('var/list/moving_root', control_proc)
            self.assertNotIn('var/datum/child', control_proc)
            self.assertFalse(list(output.rglob('*.dmb')))

    def test_fresh_process_codec_and_shared_legacy_chunk_alias_are_wired(self):
        runner = (ROOT / 'tests/movement_save_chunks/correctness.py').read_text()
        self.assertIn("'walking', 'codec-read'", runner)
        self.assertIn("shutil.copy2(source_case / 'list-codec.sav'", runner)
        self.assertIn("('codec-write', 'codec-read')", runner)
        probe = (ROOT / 'tests/movement_save_chunks/probe.dm').read_text()
        self.assertIn('verify_native_list_codec_fixture()', probe)
        self.assertIn('Legacy/chunk shared list alias was split', probe)
        self.assertIn('holder.shared = subject.payload', probe)
        self.assertIn('map_storage_saved_vars = "name;shared;pet"', probe)

    def test_vendor_setup_optional_library_path_under_nounset(self):
        import os
        import subprocess
        workflow = (ROOT / '.github/workflows/moving-save-chunks.yml').read_text()
        assignment = 'export LD_LIBRARY_PATH="${LD_LIBRARY_PATH:-}"'
        self.assertLess(workflow.index(assignment), workflow.index('source "$PWD/BYOND/byond/bin/byondsetup"'))
        man_assignment = 'export MANPATH="${MANPATH:-}"'
        self.assertLess(workflow.index(man_assignment), workflow.index('source "$PWD/BYOND/byond/bin/byondsetup"'))
        environment = dict(os.environ)
        for name in ('LD_LIBRARY_PATH', 'MANPATH'): environment.pop(name, None)
        result = subprocess.run(['bash', '-c', 'set -eu; ' + assignment + '; ' + man_assignment + '; MANPATH="/test/man:$MANPATH"; test "$MANPATH" = /test/man:; LD_LIBRARY_PATH="/test/byond:$LD_LIBRARY_PATH"; test "$LD_LIBRARY_PATH" = /test/byond:'], env=environment, capture_output=True, text=True)
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_capture_budget_diagnostics_keep_original_limits(self):
        self.assertIn('work > 8192 || tick_delta || usage_delta > 10 || current_usage >= 90 || elapsed_ds > 1', SAVING)
        for field in ('work=[work]', 'tick_delta=[tick_delta]', 'usage_delta=[usage_delta]', 'total_usage=[current_usage]', 'elapsed_ds=[elapsed_ds]'):
            self.assertIn(field, SAVING)

    def test_existing_fail_closed_boundaries_remain(self):
        for text in ('Child moved or disappeared during capture', 'require_export_frame(frame)', 'drain_save_transfers(frame)'):
            self.assertIn(text, SAVING)
        self.assertIn('Save export turf was replaced', FUNCTIONS)
        self.assertIn('Declared paid child changed before content publication', FUNCTIONS)

if __name__ == '__main__': unittest.main()
