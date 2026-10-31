"""Offline closure of the isolated animal schema; no native execution."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]

class FixtureSchemaTests(unittest.TestCase):
    def test_real_animal_fields_exist_and_human_only_fields_remain_absent(self):
        saving = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        body = saving.split('/map_storage/proc/moving_save_root_supported(', 1)[1].split('/map_storage/proc/prepare_moving_save_roster(', 1)[0]
        groups = re.findall(r'for\(var/key in list\(([^\n]+)\)\)', body)
        self.assertEqual(len(groups), 2)
        required = set(re.findall(r'"([a-z_]+)"', '\n'.join(groups)))
        self.assertEqual(len(required), 16)
        human_only = {'handcuffed', 'legcuffed'}
        self.assertIn('A.vars.Find(key)', body, 'Optional human-only fields need a presence guard')
        for filename, subtype in (('probe.dm', 'chunk_fixture'), ('benchmark.dm', 'memory_benchmark')):
            with self.subTest(filename=filename):
                text = (ROOT / 'tests/movement_save_chunks' / filename).read_text()
                block = text.split('/mob/living/simple_animal/' + subtype + '\n', 1)[1].split('\n\tNew()', 1)[0]
                declared = set(re.findall(r'^\tvar/(?:list/)?([a-z_]+)\s*$', block, re.M))
                self.assertEqual(required - declared, human_only)
                self.assertFalse(human_only & declared)
                # No non-neutral fixture ownership is fabricated to satisfy admission.
                self.assertNotRegex(block, r'var/(?:list/)?(?:' + '|'.join(sorted(required)) + r')\s*=')

    def test_frontier_injection_waits_for_completed_turf_capture(self):
        probe = (ROOT / 'tests/movement_save_chunks/probe.dm').read_text()
        self.assertIn('if(!mutations && !saving_export_stack.len && saving_references[', probe)

    def test_membership_result_is_normalized_before_boolean_comparison(self):
        probe = (ROOT / 'tests/movement_save_chunks/probe.dm').read_text()
        self.assertIn('var/expect_refusal = !!(world.params["scenario"] in list(', probe)
        self.assertNotIn('params2list(world.params)', probe)

    def test_native_fixture_covers_absent_and_present_active_optional_field(self):
        probe = (ROOT / 'tests/movement_save_chunks/probe.dm').read_text()
        self.assertIn('/mob/living/simple_animal/chunk_fixture/optional_cuff\n\tvar/handcuffed = TRUE', probe)
        self.assertIn('if(map_storage.moving_save_root_supported(cuffed))', probe)
        self.assertIn('del(cuffed)\n\t\tif(mob_list.len)', probe)
        self.assertIn('if(!map_storage.moving_save_root_supported(subject))', probe)
        self.assertLess(probe.index('del(cuffed)'), probe.index('subject = new(locate(4,1,1))'))

    def test_reference_first_control_persists_its_reference_field(self):
        probe = (ROOT / 'tests/movement_save_chunks/probe.dm').read_text()
        self.assertIn('/obj/chunk_reference_holder\n\tmap_storage_saved_vars = "name;shared;pet"\n\tvar/mob/pet', probe)
        self.assertIn('else if(world.params["scenario"] == "reference")\n\t\t\t\tsubject.loc = locate(1,1,1)', probe)
        # Generic non-item /obj types use explicit partial-field inventory.
        functions = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        self.assertIn('to_save |= params2list(map_storage_saved_vars)', functions)

if __name__ == '__main__': unittest.main()
