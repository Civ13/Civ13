"""Offline cross-level link codec contracts for #3407. Never launches BYOND.

The native round trip is tests/persistence_pointers/level_links/run.py; these
checks keep its declarations, production anchors and packet staging honest.
"""
import importlib.util
import json
from pathlib import Path
import sys
import tempfile
import unittest

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
from inventory import ROOT
sys.path.insert(0, str(ROOT / 'tests/save_movement'))
from source_adapter import extract, project

NPC = 'code/game/mob/living/simple_animal/subtile_movement.dm'
MULTIZ = 'code/modules/multiz/structures.dm'
SAVING = 'code/modules/persistence/saving.dm'
LOADING = 'code/modules/persistence/loading.dm'
FUNCTIONS = 'code/modules/persistence/functions.dm'
_spec = importlib.util.spec_from_file_location('level_link_runner', HERE / 'level_links/run.py')
RUNNER = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(RUNNER)


def read(path):
    return (ROOT / path).read_text(encoding='utf-8-sig')


class LevelLinkContracts(unittest.TestCase):
    def test_reviewed_link_fields_match_their_declared_hooks(self):
        rows = [r for r in json.loads(read('tests/persistence_pointers/classifications.json')) if r['policy'] == 'level_link']
        self.assertEqual({(r['owner'], r['field']) for r in rows},
                         {('/mob/living/simple_animal', 'following_mob'), ('/obj/structure/multiz', 'target')})
        body = extract(read(NPC), '/mob/living/simple_animal/persistence_level_link_var')
        self.assertIn('..()', body)
        fn = project('/mob/living/simple_animal/persistence_level_link_var(key)\n' + body.replace('..()', 'parent(key)') + '\n',
                     '/mob/living/simple_animal/persistence_level_link_var', 'key', {'parent': lambda key: False})
        self.assertTrue(fn('following_mob'))
        for key in ('target_mob', 'target_obj', 'origin', 'LAssailant'):
            self.assertFalse(fn(key), key)
        multiz = read(MULTIZ)
        block = multiz[multiz.index('/obj/structure/multiz\n'):multiz.index('////LADDER////')]
        self.assertIn('\tpersistence_level_link_var(key)\n\t\treturn key == "target" || ..()\n', block)
        # The generic default declares no link; ambiguous names stay per type.
        default = extract(read(FUNCTIONS), '/datum/proc/persistence_level_link_var')
        self.assertEqual(default.strip().splitlines()[-1].strip(), 'return FALSE')

    def test_links_are_durable_not_runtime_excluded(self):
        runtime = extract(read(NPC), '/mob/living/simple_animal/persistence_runtime_var')
        self.assertNotIn('"following_mob"', runtime)
        self.assertNotIn('"target"', runtime)

    def test_export_keeps_the_per_level_guard_for_everything_else(self):
        saving = read(SAVING)
        self.assertEqual(saving.count('if(movable.z && movable.z != saving_z)'), 1)
        self.assertEqual(saving.count('value = encode_level_link(A.vars[v])'), 1)
        check = extract(saving, '/map_storage/proc/level_link_target')
        self.assertIn('source.persistence_level_link_var(field)', check)
        self.assertIn('T.z != saving_z', check)
        # Unbound saved targets fail closed and are recorded for the admin alert.
        finish = extract(saving, '/map_storage/proc/finish_level_links')
        self.assertIn('record_save_reference_failure("unbound_level_link"', finish)
        self.assertNotIn('\\ref[', finish.split('rows += ')[1])
        body = extract(saving, '/map_storage/proc/save_world_contents')
        self.assertLess(body.index('finish_level_links()'), body.index('validate_captured_world_save(round_state)'))

    def test_import_resolves_after_every_level_and_preflight_admits_rows(self):
        loading = read(LOADING)
        load = extract(loading, '/map_storage/proc/load_world_contents')
        self.assertLess(load.index('begin_level_link_import()'), load.index('for(var/B = 1, B <= world.maxz, B++)'))
        self.assertLess(load.index('restore_level_links()'), load.index('verify_restored_roof_areas()'))
        self.assertIn('object.vars[v] = decode_saved_value(savefile, savefile[v])', loading)
        validate = extract(loading, '/map_storage/proc/validate_world_save')
        self.assertIn('validate_level_link_targets(level_links, round_state["generation"])', validate)
        self.assertIn('if(!candidate) validated_level_links', validate)
        # Nested values never carry links; the generic validator rejects them.
        self.assertNotIn('level_link', extract(loading, '/map_storage/proc/validate_saved_value'))
        self.assertIn('has_level_links', extract(read(FUNCTIONS), '/map_storage/proc/read_round_state'))

    def test_native_packet_stages_unchanged_production_sources(self):
        with tempfile.TemporaryDirectory() as directory:
            output = Path(directory)
            receipt = RUNNER.prepare(output)
            for path in RUNNER.CROSS.PRODUCTION:
                self.assertEqual((output / Path(path).name).read_text(), read(path))
            self.assertFalse((output / 'cross_level_probe.dm').exists())
            self.assertIn('#include "level_links_probe.dm"', (output / 'probe.dme').read_text())
            self.assertFalse(receipt['native_verified'])

    def test_controls_mutate_only_their_named_source(self):
        for control, (name, before, after, case, minimum, expected) in RUNNER.CONTROLS.items():
            with self.subTest(control=control), tempfile.TemporaryDirectory() as directory:
                output = Path(directory)
                RUNNER.prepare(output, control)
                for path in RUNNER.CROSS.PRODUCTION:
                    original = read(path)
                    actual = (output / Path(path).name).read_text()
                    self.assertEqual(actual, original.replace(before, after, 1) if Path(path).name == name else original)
                self.assertIn(case, RUNNER.CASES)
                self.assertTrue((expected['pattern'] if isinstance(expected, dict) else expected).startswith('FAIL: '))


if __name__ == '__main__':
    unittest.main()
