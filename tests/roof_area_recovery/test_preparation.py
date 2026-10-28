"""Offline preparation/admission checks. These do not establish native recovery."""
import hashlib
import json
import re
import struct
from pathlib import Path
import subprocess
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
RUNNER = ROOT / 'tests/world_save/run-durable-world.py'


class RoofAreaPreparation(unittest.TestCase):
    def test_roof_probe_reads_chunks_and_missing_roof_control_keeps_valid_encoding(self):
        probe = (ROOT / 'tests/roof_area_recovery/probe.dm').read_text()
        self.assertIn('var/version = F["/format_version"]', probe)
        self.assertIn('map_storage.saved_content_refs(F["[turf_path]/content"], version)', probe)
        self.assertNotIn('params2list(F["[turf_path]/content"])', probe)
        self.assertIn('if(mode == "missing-roof") F["[turf_path]/content"] << (version == 3 ? list() : "")', probe)

    def test_roof_projection_admits_both_typed_versions_and_decodes_chunked_contents(self):
        source = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        plan = source.split('/map_storage/proc/prepare_saved_roof_areas(', 1)[1].split('/map_storage/proc/materialize_saved_roof_areas()', 1)[0]
        def check(plan):
            self.assertIn('var/version = F["/format_version"]', plan)
            self.assertIn('if(version != 2 && version != 3) continue', plan)
            self.assertIn('var/list/contents = saved_content_refs(F["[turf_path]/content"], version)', plan)
            self.assertNotIn('params2list(', plan)
        check(plan)
        # Each independently restored integration defect must be detected.
        for old in (plan.replace('if(version != 2 && version != 3) continue',
                                 'if(version != 2) continue'),
                    plan.replace('saved_content_refs(F["[turf_path]/content"], version)',
                                 'params2list(F["[turf_path]/content"])')):
            with self.subTest(old=old), self.assertRaises(AssertionError):
                check(old)

    def test_postflight_control_exception_names_are_distinct_in_shared_dm_scope(self):
        probe=(ROOT/'tests/roof_area_recovery/probe.dm').read_text()
        block=probe.split('else if(mode == "postflight-empty")',1)[1].split('else if(!(mode in',1)[0]
        names=re.findall(r'catch\(var/exception/(\w+)\)',block)
        self.assertEqual(len(names),3)
        self.assertEqual(len(set(names)),3)

    def test_closure_interval_uses_small_world_clock_without_epoch_precision_loss(self):
        probe=(ROOT/'tests/roof_area_recovery/probe.dm').read_text()
        handshake=probe.split('var/closure_deadline = ',1)[1].split('\n\t\tconfig = new',1)[0]
        self.assertTrue(handshake.startswith('world.time + 100\n'))
        self.assertIn('world.time < closure_deadline) sleep(1)',handshake)
        self.assertNotIn('world.realtime',handshake)
        self.assertIn('External listener closure was not acknowledged',handshake)
        f32=lambda value:struct.unpack('f',struct.pack('f',value))[0]
        # The failed CI epoch loses a 100-decisecond addition; a fresh world's
        # small clock preserves that exact ten-second interval.
        epoch=f32(8461133900)
        self.assertEqual(f32(epoch+100),epoch)
        for start in (0,1,10,600):
            self.assertEqual(f32(f32(start)+100)-f32(start),100)

    def test_native_execution_is_refused_before_preparation(self):
        result = subprocess.run([sys.executable, str(RUNNER), '--roof-areas'],
                                cwd=ROOT, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 2)
        self.assertIn('separately reviewed bounded runner/admission', result.stderr)
        self.assertNotIn('Retained evidence:', result.stdout)

    def test_other_modes_cannot_enable_execution(self):
        for mode in ('--lighting', '--wounds', '--persistence-year', '--dimension-bootstrap',
                     '--recovery-reconnect', '--lifecycle-shutdown', '--startup-only'):
            with self.subTest(mode=mode):
                result = subprocess.run([sys.executable, str(RUNNER), '--roof-areas', '--prepare-only', mode],
                                        cwd=ROOT, capture_output=True, text=True, timeout=20)
                self.assertEqual(result.returncode, 2)
                self.assertIn('cannot combine', result.stderr)

    def test_named_source_controls_prepare_without_changing_production(self):
        path = ROOT / 'code/modules/persistence/loading.dm'
        original = path.read_bytes()
        for control in ('projection', 'cleanup-namespace'):
            with self.subTest(control=control):
                result = subprocess.run([sys.executable, str(RUNNER), '--roof-areas', '--prepare-only',
                                         '--roof-control', control], cwd=ROOT, capture_output=True,
                                        text=True, timeout=40, check=True)
                output = Path(result.stdout.split('Retained evidence: ', 1)[1].splitlines()[0])
                receipt = json.loads((output / 'receipt.json').read_text())
                self.assertEqual(receipt['roof_control'], control)
                changed = (output / next(output.glob('*_2.dm')).name).read_text()
                if control == 'projection':
                    self.assertNotIn('\t\tprepare_saved_roof_areas(round_state["generation"])', changed)
                    self.assertIn('Old-defect control', changed)
                else:
                    predicate = changed.split('/map_storage/proc/is_loaded_validated_roof(', 1)[1].split('/map_storage/proc/verify_restored_roof_areas()', 1)[0]
                    self.assertNotIn('loading_z', predicate)
                    self.assertIn('existing_references[row["entry"]] == roof', predicate)
                self.assertEqual(path.read_bytes(), original)
                self.assertFalse(list(output.glob('*.dmb')))

    def test_source_controls_cannot_select_an_existing_native_mode(self):
        result = subprocess.run([sys.executable, str(RUNNER), '--roof-control', 'projection', '--wounds'],
                                cwd=ROOT, capture_output=True, text=True, timeout=20)
        self.assertEqual(result.returncode, 2)
        self.assertIn('Roof controls require --roof-areas', result.stderr)
        self.assertNotIn('Retained evidence:', result.stdout)

    def test_actual_preparer_retains_full_sources_without_engine_or_private_data(self):
        inputs = [ROOT / p for p in ('code/modules/persistence/loading.dm',
                  'code/modules/persistence/durable_world.dm', 'code/game/objects/roof_stuff.dm')]
        before = {p: p.read_bytes() for p in inputs}
        result = subprocess.run([sys.executable, str(RUNNER), '--roof-areas', '--prepare-only'],
                                cwd=ROOT, capture_output=True, text=True, timeout=40, check=True)
        output = Path(result.stdout.split('Retained evidence: ', 1)[1].splitlines()[0])
        receipt = json.loads((output / 'receipt.json').read_text())
        self.assertTrue(receipt['roof_areas'] and receipt['prepared_only'])
        fixture = ROOT / 'tests/roof_area_recovery/probe.dm'
        self.assertEqual(receipt['roof_probe_hash'], hashlib.sha256(fixture.read_bytes()).hexdigest())
        probe = next(output.glob('*_probe.dm')).read_text()
        self.assertIn('/world/OpenPort(port)\n\treturn ..("none")', probe)
        self.assertIn('/client/New()\n\tdel(src)', probe)
        self.assertNotIn('OpenPort(0)', probe)
        self.assertIn('new /obj/roof/wood(T)', probe)
        self.assertIn('map_storage.run_world_operation("save", op)', probe)
        self.assertIn('map_storage.run_world_operation("load", op)', probe)
        self.assertIn('map_storage.restore_durable_world()', probe)
        dme = (output / 'probe.dme').read_text()
        self.assertIn('code\\game\\objects\\roof_stuff.dm', dme)
        self.assertNotIn('.dmm"', dme)
        self.assertFalse(list(output.glob('*.dmb')))
        self.assertFalse(list(output.glob('*.rsc')))
        self.assertFalse((output / 'config').exists())
        self.assertFalse((output / 'map_saves').exists())
        for path, data in before.items():
            self.assertEqual(path.read_bytes(), data)

    def test_projection_precedes_both_validators_and_never_mutates_world(self):
        source = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        plan = source.split('/map_storage/proc/prepare_saved_roof_areas(', 1)[1].split('/map_storage/proc/materialize_saved_roof_areas()', 1)[0]
        self.assertNotIn('new type', plan)
        self.assertNotIn('contents +=', plan)
        for guard in ('Ambiguous or multiply placed saved roof', 'Saved roof lacks scalar area metadata',
                      'Saved roof base area differs', 'Unsupported saved roof climate'):
            self.assertIn(guard, plan)
        validate = source.split('/map_storage/proc/validate_world_save()', 1)[1]
        self.assertLess(validate.index('prepare_saved_roof_areas('), validate.index('validate_saved_value('))
        self.assertLess(validate.index('prepare_saved_roof_areas('), validate.index('validate_durable_world('))
        self.assertIn('if(!ispath(area_type, value["type"]))', validate)

    def test_materialization_precedes_recursive_import_and_keeps_strict_decode(self):
        source = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        load = source.split('/map_storage/proc/load_world_contents(', 1)[1].split('// A failed preflight', 1)[0]
        self.assertLess(load.index('T.ChangeTurf('), load.index('materialize_saved_roof_areas()'))
        self.assertLess(load.index('materialize_saved_roof_areas()'), load.index('Load_Entry('))
        self.assertIn('!istype(T.loc, value["type"])', source)
        self.assertIn('if(is_loaded_validated_roof(ob))', source)
        self.assertIn('Saved roof location changed during import', source)

    def test_exact_retained_instance_and_scoped_cleanup_contract(self):
        source = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        lookup = source.split('/map_storage/proc/find_saved_roof_area(', 1)[1].split('/map_storage/proc/unique_saved_roof_area(', 1)[0]
        self.assertIn('area_list.Copy()', lookup)
        self.assertIn('for(var/area/A in world) candidates |= A', lookup)
        self.assertIn('if(A.type != type) continue', lookup)
        self.assertNotIn('locate(/turf)', lookup)
        unique = source.split('/map_storage/proc/unique_saved_roof_area(', 1)[1].split('/map_storage/proc/prepare_saved_roof_areas(', 1)[0]
        self.assertIn('find_saved_roof_area(type)', unique)
        self.assertIn('cached != found', unique)
        materialize = source.split('/map_storage/proc/materialize_saved_roof_areas()', 1)[1].split('/map_storage/proc/restore_validated_roof(', 1)[0]
        self.assertNotIn('locate(type)', materialize)
        self.assertEqual(materialize.count('new type()'),1)
        self.assertLess(materialize.index('unique_saved_roof_area(A.type, TRUE)'),materialize.index('new type()'))
        self.assertLess(materialize.index('Planned roof area absence changed'),materialize.index('new type()'))
        self.assertLess(materialize.index('new type()'),materialize.index('validated_roof_instances[key] = A'))
        self.assertLess(materialize.index('validated_roof_absent = list()'),materialize.index('A.contents += T'))
        cleanup = source.split('/map_storage/proc/is_loaded_validated_roof(', 1)[1].split('/map_storage/proc/verify_restored_roof_areas()', 1)[0]
        self.assertIn('roof.z != loading_z', cleanup)
        self.assertIn('row["z"] == loading_z', cleanup)
        self.assertIn('validated_roof_entries["[loading_z]:[row["entry"]]"] == row', cleanup)

    def test_only_proven_destinations_are_prospective_and_base_identity_stays_required(self):
        source=(ROOT/'code/modules/persistence/loading.dm').read_text()
        plan=source.split('/map_storage/proc/prepare_saved_roof_areas(',1)[1].split('/map_storage/proc/materialize_saved_roof_areas()',1)[0]
        self.assertIn('var/area/base = unique_saved_roof_area(base_type)',plan)
        self.assertIn('target_type = saved_roof_area_type(base.vars["climate"])',plan)
        self.assertIn('for(var/key in validated_roof_types)',plan)
        self.assertIn('if(A || (key in validated_roof_instances))',plan)
        self.assertIn('validated_roof_absent[key] = type',plan)
        self.assertNotIn('new type',plan)
        self.assertNotIn('contents +=',plan)
        self.assertIn('validated_roof_types[key] != type',source)
        self.assertIn('!ispath(type, /area/caribbean/roofed)',source)
        runtime=(ROOT/'code/modules/persistence/functions.dm').read_text().split('/map_storage/persistence_runtime_var(key)',1)[1].split('// Native lookup',1)[0]
        self.assertIn('"validated_roof_absent"',runtime)
        reset=source.split('/map_storage/proc/clear_saved_roof_areas()',1)[1].split('/map_storage/proc/saved_roof_area_type(',1)[0]
        self.assertIn('validated_roof_absent = list()',reset)

    def test_native_fixture_has_real_alias_and_fail_closed_controls(self):
        probe = (ROOT / 'tests/roof_area_recovery/probe.dm').read_text()
        for mode in ('missing-roof', 'wrong-base', 'missing-scalar', 'disabled-roof',
                     'unrelated-area', 'duplicate-area', 'duplicate-placement',
                     'empty-instance', 'postflight-empty', 'write-covered', 'read-covered', 'old-defect'):
            self.assertIn(mode, probe)
        for check in ('Saved area references diverged', 'Nested area or roof alias lost',
                      'Saved list area key/alias diverged', 'Rejected preflight mutated',
                      'Actual roofs do not share the canonical climate area',
                      'Disabled roof changed topology', 'Fully roofed base area still has turfs',
                      'Cross-z equal numeric roof ref was retained', 'Postflight empty area was reselected',
                      'Changed retained roof identity was accepted', 'Changed planned roof absence was accepted',
                      'Absent roof destination was not planned without mutation', 'Fresh reader rejected absent roof destination',
                      'Real roof constructor overlay was not registered', 'Roof destruction did not restore'):
            self.assertIn(check, probe)
        self.assertIn('"mode" = mode, "error" = "[e]"',probe)


if __name__ == '__main__':
    unittest.main()
