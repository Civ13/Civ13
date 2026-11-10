"""Pure lexical fixtures; no engine, constructors or world data are loaded."""
from pathlib import Path
import sys
import unittest

ROOT = Path(__file__).resolve().parents[2]
sys.path.insert(0, str(ROOT / 'scripts'))
from atlas.entity_inventory import inventory, masked_source


class EntityInventoryTests(unittest.TestCase):
    def rows(self, source, extras=None, resources=None):
        files = {'civ13.dme': '#include "code/main.dm"\n', 'code/main.dm': source}
        files.update(extras or {})
        report = inventory(files, resources or {})
        return report, {row['type']: row for row in report['entries']}

    def test_direct_literals_have_provenance_not_inherited_claims(self):
        _, rows = self.rows('/obj/item/a\n\tname = "A"\n\tdesc = "Plain description."\n/obj/item/a/b\n')
        a, b = rows['/obj/item/a'], rows['/obj/item/a/b']
        self.assertEqual(a['fields']['name'][0], dict(file='code/main.dm', line=2, status='literal', value='A'))
        self.assertEqual(b['name_status'], 'not_declared_here')
        self.assertEqual(b['inheritance_status'], 'unresolved_not_compiled')
        self.assertEqual(b['parent_hint'], '/obj/item/a')

    def test_conditional_macro_and_conflicting_values_are_not_resolved(self):
        source = '#ifdef SECRET\n/obj/item/a\n\tname = "Maybe"\n#endif\n/obj/item/b\n\tdesc = "Uses [thing]"\n/obj/item/c\n\tname = "One"\n/obj/item/c\n\tname = "Two"\n'
        _, rows = self.rows(source)
        self.assertEqual(rows['/obj/item/a']['name_status'], 'unresolved_conditional')
        self.assertEqual(rows['/obj/item/b']['desc_status'], 'unresolved_expression')
        self.assertEqual(rows['/obj/item/c']['name_status'], 'conflicting_redeclarations')

    def test_comments_multiline_strings_and_proc_paths_are_not_entities(self):
        source = '/*\n/obj/item/fake\n*/\n/obj/item/a\n\tdesc = {"\n/obj/item/fake2\n"}\n/obj/item/a/proc/test\n\tname = "Not an entity"\n'
        report, rows = self.rows(source)
        self.assertEqual(set(rows), {'/obj/item/a'})
        self.assertEqual(rows['/obj/item/a']['desc_status'], 'unresolved_expression')
        self.assertEqual(report['excluded_absolute_declarations']['proc_verb_var_path'], 1)
        self.assertEqual(masked_source(source).count('\n'), source.count('\n'))

    def test_nested_block_comments_cannot_leak_fake_declarations(self):
        source = '/* outer /* inner */\n/obj/item/fake\n*/\n/obj/item/real\n'
        _, rows = self.rows(source)
        self.assertEqual(set(rows), {'/obj/item/real'})

    def test_slashes_inside_strings_and_trailing_comments_preserve_values(self):
        _, rows = self.rows('/obj/item/a\n\tdesc = "https://example.test/a/*b*/" // trailing\n')
        self.assertEqual(rows['/obj/item/a']['fields']['desc'][0]['value'], 'https://example.test/a/*b*/')

    def test_include_reference_is_not_active_build_or_player_eligibility(self):
        report, rows = self.rows('/turf/floor/a\n', {'code/off.dm': '/mob/living/simple_animal/test\n'})
        off = rows['/mob/living/simple_animal/test']
        self.assertEqual(off['declarations'][0]['include_status'], 'not_in_literal_include_graph')
        self.assertEqual(report['summary']['only_off_graph'], 1)
        self.assertIn('unreviewed', off['public_eligibility'])
        self.assertEqual(rows['/turf/floor/a']['declarations'][0]['include_status'], 'referenced_unpreprocessed')

    def test_actual_include_graph_follows_nested_literal_includes(self):
        _, rows = self.rows('#include "nested.dm"\n', {'code/nested.dm': '/obj/structure/a\n'})
        self.assertEqual(rows['/obj/structure/a']['declarations'][0]['include_status'], 'referenced_unpreprocessed')

    def test_aliases_use_catalog_types_without_duplicating_material_mapping(self):
        resources = {'/material/wood': {'type': '/obj/item/stack/material/wood'},
                     'alias': {'type': '/obj/item/stack/material/wood'}}
        _, rows = self.rows('/obj/item/stack/material/wood\n', resources=resources)
        row = rows['/obj/item/stack/material/wood']
        self.assertEqual(row['atlas_ids'], ['/material/wood', 'alias'])
        self.assertEqual(row['atlas_match'], 'ambiguous_aliases')

    def test_parent_override_is_only_a_hint_even_for_cycles(self):
        _, rows = self.rows('/obj/item/a\n\tparent_type = /obj/item/b\n/obj/item/b\n\tparent_type = /obj/item/a\n')
        self.assertEqual(rows['/obj/item/a']['parent_hint'], '/obj/item/b')
        self.assertEqual(rows['/obj/item/a']['inheritance_status'], 'unresolved_not_compiled')

    def test_output_is_deterministic_and_missing_catalog_is_not_unobtainability(self):
        source = '/obj/item/a\n\tname = "A"\n'
        report, rows = self.rows(source)
        again, _ = self.rows(source)
        self.assertEqual(report, again)
        self.assertEqual(rows['/obj/item/a']['atlas_match'], 'absent')
        self.assertIn('not acquisition evidence', ' '.join(report['limitations']))


if __name__ == '__main__':
    unittest.main()
