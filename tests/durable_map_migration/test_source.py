"""Frozen field inventories and migration integration; no native processes."""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
HERE = Path(__file__).resolve().parent


class MapSchemaMigration(unittest.TestCase):
    def test_exact_historical_and_current_inventories(self):
        old = json.loads((HERE/'map-schema-v1.json').read_text())
        new = json.loads((HERE/'map-schema-v2.json').read_text())
        self.assertEqual(len(old), 131)
        self.assertEqual(len(new), 132)
        self.assertEqual(set(new)-set(old), {'faction_renames'})
        self.assertEqual({k:v for k,v in new.items() if k!='faction_renames'}, old)
        source = (ROOT/'code/modules/persistence/durable_contract.dm').read_text(encoding='utf-8')
        body = source.split('/proc/durable_metadata_map_schema()',1)[1].split('/proc/durable_metadata_area_schema()',1)[0]
        actual = {key:kind for kind,keys in re.findall(r'"([a-z_]+)" = list\(([^\n]+)\)',body)
                  for key in re.findall(r'"([a-zA-Z0-9_]+)"',keys)}
        self.assertEqual(actual,new)

    def test_default_matches_source_and_is_only_added_after_validation(self):
        source = (ROOT/'code/game/mob/groups/faction_creation.dm').read_text(encoding='utf-8')
        self.assertIn('var/list/faction_renames = list()',source)
        contract=(ROOT/'code/modules/persistence/durable_contract.dm').read_text(encoding='utf-8')
        body=contract.split('/proc/durable_metadata_default_map_fields(',1)[1].split('\n/proc/',1)[0]
        self.assertLess(body.index('durable_metadata_validate_fields(fields, schema)'),body.index('fields.Copy()'))
        self.assertEqual(re.findall(r'result\["(\w+)"\] = list\(\)',body),['faction_renames'])
        self.assertNotIn('state[',body)

    def test_encoded_preflight_keeps_exact_inventory_and_root_types(self):
        source=(ROOT/'code/modules/persistence/durable_world.dm').read_text(encoding='utf-8')
        body=source.split('/map_storage/proc/validate_durable_world(',1)[1].split('\n/map_storage/proc/',1)[0]
        self.assertIn('var/list/schema = durable_metadata_map_read_schema(state)',body)
        self.assertIn('fields.len != schema.len',body)
        self.assertIn('if(!(key in fields))',body)
        self.assertIn('G.check_index(fields[key])',body)
        self.assertIn('node["kind"] != kind',body)
        self.assertLess(body.index('durable_metadata_map_read_schema(state)'),body.index('durable_import = G'))

    def test_writer_versions_fields_independently_and_restorer_normalizes(self):
        source=(ROOT/'code/modules/persistence/durable_world.dm').read_text(encoding='utf-8')
        self.assertIn('"schema" = 2, "map_fields_version" = 2',source)
        self.assertIn('if("map_fields_version" in state) keys += "map_fields_version"',source)
        restore=source.split('/map_storage/proc/restore_durable_world()',1)[1]
        self.assertLess(restore.index('durable_metadata_default_map_fields(fields, durable_state)'),
                        restore.index('durable_metadata_restore_fields(map, fields, durable_metadata_map_schema())'))


if __name__=='__main__':
    unittest.main()
