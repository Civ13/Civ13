"""Source guards only; these are not proof of body snapshot completeness."""
from pathlib import Path
import unittest
ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/modules/persistence/train_body_graph.dm').read_text()

class BodyCaptureGuards(unittest.TestCase):
    def test_uses_production_exporter_not_text_import(self):
        self.assertIn('BuildVarDirectory(F, body, 1)', SOURCE)
        self.assertNotIn('ImportText(', SOURCE)
        self.assertNotIn('ExportText(', SOURCE)
        self.assertIn('Load_Entry(F, root, null, Q)', SOURCE)
    def test_restore_requires_local_exact_snapshot(self):
        self.assertIn('text != local_snapshot', SOURCE)
        self.assertIn('local_restore_used = TRUE', SOURCE)
        self.assertIn('local_restore_preflight(text)', SOURCE)
        self.assertNotIn('new type', SOURCE)
    def test_external_references_fail_closed(self):
        for guard in ('!body_members[A]', '!body_members[target]', 'isturf(value)', 'isarea(value)', 'istype(value, /client)'):
            self.assertIn(guard, SOURCE)
    def test_production_omissions_rejected(self):
        self.assertIn('if(!saving_references[member]) throw', SOURCE)
        self.assertIn('if(!root) throw', SOURCE)
    def test_no_silent_npc_rejuvenation(self):
        self.assertIn('/map_storage/train_body_graph/rejuvenate_unowned_human_on_load()\n\treturn FALSE', SOURCE)
        loading = (ROOT / 'code/modules/persistence/loading.dm').read_text()
        self.assertIn('/map_storage/proc/rejuvenate_unowned_human_on_load()\n\treturn TRUE', loading)
        self.assertIn('!H.persistence_owner_ckey && rejuvenate_unowned_human_on_load()', loading)
    def test_icons_are_local_bounded_organ_copies(self):
        self.assertIn('value != O.mob_icon', SOURCE)
        self.assertIn('value != O.icon', SOURCE)
        self.assertIn('!isicon(value) || istext(value)', SOURCE)
        self.assertIn('var/icon/I = icon(value)', SOURCE)
        self.assertIn('local_icon_copies += I', SOURCE)
        self.assertIn('local_icon_copies.len >= 64', SOURCE)
        self.assertIn('I.Width() > 128', SOURCE)
        self.assertIn('length(icon_states(I)) > 64', SOURCE)
        self.assertIn('Local icon outside organ renderer', SOURCE)
        self.assertNotIn('path == /icon', SOURCE)
    def test_limb_descriptor_exception_remains_exact(self):
        self.assertIn('row["descriptor"] != initial(path:name)', SOURCE)
        self.assertIn('field != "path" && field != "descriptor"', SOURCE)
        self.assertIn('row["path"] != base["path"]', SOURCE)
        self.assertIn('metadata_mismatch("[context].[i].descriptor")', SOURCE)
    def test_registry_and_filters_are_narrow(self):
        self.assertIn('S.type != /datum/species/human', SOURCE)
        self.assertIn('all_species["Human"] != S', SOURCE)
        self.assertIn('metadata_equal(S, species_baseline)', SOURCE)
        self.assertIn('length(owner.filters) || length(value)', SOURCE)
        self.assertIn('Empty filter marker outside atom.filters', SOURCE)
    def test_matrix_is_exact_and_bounded(self):
        self.assertIn('A.type == /matrix', SOURCE)
        self.assertIn('abs(value) <= 1000000', SOURCE)
        self.assertIn('fields.len != 7', SOURCE)
        self.assertIn('path == /obj/item/stack/teeth/human', SOURCE)
        self.assertNotIn('ispath(path, /matrix)', SOURCE)
    def test_native_fixture_uses_production_body_catalogs(self):
        probe = (ROOT / 'tests/train_body_graph/probe.dm').read_text()
        for setup in ('makeDatumRefLists()', 'initialize_chemical_reagents()', 'initialize_chemical_reactions()', 'populate_material_list()'):
            self.assertIn(setup, probe)
        self.assertLess(probe.index('\t\tbody_fixture_catalogs()'), probe.index('\t\tbody_capture_probe()'))
        self.assertNotIn('/mob/living/human/New()', probe)
    def test_bounded_and_no_world_save(self):
        for guard in ('world.time != capture_tick', 'TRAIN_BODY_NODES', 'TRAIN_BODY_EDGES', 'TRAIN_BODY_BYTES', 'persistence_save_active()'):
            self.assertIn(guard, SOURCE)
        self.assertNotIn('Save_World(', SOURCE)

if __name__ == '__main__':
    unittest.main()
