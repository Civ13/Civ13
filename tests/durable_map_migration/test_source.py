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
        mid = json.loads((HERE/'map-schema-v2.json').read_text())
        new = json.loads((HERE/'map-schema-v3.json').read_text())
        v4 = json.loads((HERE/'map-schema-v4.json').read_text())
        v5 = json.loads((HERE/'map-schema-v5.json').read_text())
        v6 = json.loads((HERE/'map-schema-v6.json').read_text())
        v7 = json.loads((HERE/'map-schema-v7.json').read_text())
        v8 = json.loads((HERE/'map-schema-v8.json').read_text())
        self.assertEqual(len(v8), 138)
        self.assertEqual(set(v8)-set(v7), {'player_houses_state'})
        self.assertEqual({k:v for k,v in v8.items() if k!='player_houses_state'}, v7)
        self.assertEqual(len(old), 131)
        self.assertEqual(len(mid), 132)
        self.assertEqual(len(new), 133)
        self.assertEqual(len(v4), 134)
        self.assertEqual(len(v5), 135)
        self.assertEqual(len(v6), 136)
        self.assertEqual(len(v7), 137)
        self.assertEqual(set(v7)-set(v6), {'era_records_state'})
        self.assertEqual({k:v for k,v in v7.items() if k!='era_records_state'}, v6)
        self.assertEqual(set(v6)-set(v5), {'language_lineage_state'})
        self.assertEqual({k:v for k,v in v6.items() if k!='language_lineage_state'}, v5)
        self.assertEqual(set(v5)-set(v4), {'fishing_grounds_state'})
        self.assertEqual({k:v for k,v in v5.items() if k!='fishing_grounds_state'}, v4)
        self.assertEqual(set(v4)-set(new), {'river_flood_state'})
        self.assertEqual({k:v for k,v in v4.items() if k!='river_flood_state'}, new)
        self.assertEqual(set(mid)-set(old), {'faction_renames'})
        self.assertEqual({k:v for k,v in mid.items() if k!='faction_renames'}, old)
        self.assertEqual(set(new)-set(mid), {'faction_recruitment'})
        self.assertEqual({k:v for k,v in new.items() if k!='faction_recruitment'}, mid)
        source = (ROOT/'code/modules/persistence/durable_contract.dm').read_text(encoding='utf-8')
        body = source.split('/proc/durable_metadata_map_schema()',1)[1].split('/proc/durable_metadata_area_schema()',1)[0]
        actual = {key:kind for kind,keys in re.findall(r'"([a-z_]+)" = list\(([^\n]+)\)',body)
                  for key in re.findall(r'"([a-zA-Z0-9_]+)"',keys)}
        self.assertEqual(actual,v8)

    def test_default_matches_source_and_is_only_added_after_validation(self):
        source = (ROOT/'code/game/mob/groups/faction_creation.dm').read_text(encoding='utf-8')
        self.assertIn('var/list/faction_renames = list()',source)
        recruitment = (ROOT/'code/game/mob/groups/faction_recruitment.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/map_metadata/var/list/faction_recruitment = list()',recruitment)
        flood = (ROOT/'code/modules/1713/river_flood.dm').read_text(encoding='utf-8')
        self.assertIn('\tvar/list/river_flood_state = list()',flood)
        grounds = (ROOT/'code/modules/1713/fishing_grounds.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/map_metadata/var/list/fishing_grounds_state = list()',grounds)
        drift = (ROOT/'code/game/mob/language/drift.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/map_metadata/var/list/language_lineage_state = list()',drift)
        eras = (ROOT/'code/modules/research_tree/era_loss.dm').read_text(encoding='utf-8')
        self.assertIn('/obj/map_metadata/var/list/era_records_state = list()',eras)
        contract=(ROOT/'code/modules/persistence/durable_contract.dm').read_text(encoding='utf-8')
        body=contract.split('/proc/durable_metadata_default_map_fields(',1)[1].split('\n/proc/',1)[0]
        self.assertLess(body.index('durable_metadata_validate_fields(fields, schema)'),body.index('fields.Copy()'))
        self.assertEqual(re.findall(r'result\["(\w+)"\] = list\(\)',body),['faction_renames','faction_recruitment','river_flood_state','fishing_grounds_state','language_lineage_state','era_records_state','player_houses_state'])
        self.assertNotIn('state[',body)

    def test_house_roles_use_life_tokens_and_do_not_mutate_economic_rows(self):
        rules = (ROOT/'code/game/mob/groups/player_houses.dm').read_text()
        death = (ROOT/'code/game/mob/living/carbon/human/death.dm').read_text()
        runtime = (ROOT/'code/game/mob/living/carbon/human/nomads_adoption.dm').read_text()
        # The company companion may read the registry to select and revalidate a
        # charter target. Require each reference to be an explicit read; house
        # authority still cannot alter shares, balances, listings, or permissions.
        for line in rules.splitlines():
            if "custom_company" in line:
                self.assertTrue(
                    line.strip() == "for (var/company in land.custom_company_nr)"
                    or line.strip().endswith("|| !(company in land.custom_company_nr))"),
                    line,
                )
        for field in ("sales_registry", "faction_perms", "adoption_surname"):
            self.assertNotIn(field, rules)
        role = rules.split('/obj/map_metadata/proc/player_house_role(', 1)[1].split('\n/', 1)[0]
        self.assertIn('roster[H.player_house_life_id]', role)
        self.assertNotIn('owner_key', role)
        self.assertNotIn('real_name', role)
        self.assertIn('H.stat == DEAD', role)
        discard = rules.split('/mob/living/human/proc/lose_player_house_authority()', 1)[1].split('\n/', 1)[0]
        self.assertIn('player_house_life_id = null', discard)
        self.assertLess(death.index('lose_player_house_authority()'), death.index('company_return_stake('))
        self.assertIn('player_house_runtime_var(key)', runtime)
        states = rules.split('/proc/player_house_runtime_var(key)', 1)[1].split('\n/', 1)[0]
        self.assertNotIn('player_house_life_id', states)
        commit = rules[rules.index('var/answer = WWinput(target'):]
        self.assertLess(commit.index('persistence_admission_changed(save_identity)'), commit.index('roster[life] = offer_role'))
        self.assertLess(commit.index('invitee_life_generation != target.player_house_life_generation'), commit.index('roster[life] = offer_role'))

    def test_house_recovery_requires_named_charter_consent_and_admin_reason(self):
        rules = (ROOT/'code/game/mob/groups/player_houses.dm').read_text()
        recovery = rules.split('/client/proc/recover_player_house()', 1)[1].split('\n/', 1)[0]
        assignment = recovery.index('roster[life] = "steward"')
        for required in ('check_rights(R_ADMIN)', 'player_house_has_active_steward(id)',
                         'persistence_admission_changed(save_identity)', 'land != map',
                         'life_generation != recipient.player_house_life_generation',
                         'Staff are offering you stewardship', 'if(!reason'):
            self.assertLess(recovery.rindex(required, 0, assignment), assignment)
        self.assertIn('log_admin(', recovery[assignment:])
        self.assertNotIn('custom_company', recovery)

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
        self.assertIn('"schema" = 2, "map_fields_version" = 8',source)
        self.assertIn('if("map_fields_version" in state) keys += "map_fields_version"',source)
        restore=source.split('/map_storage/proc/restore_durable_world()',1)[1]
        self.assertLess(restore.index('durable_metadata_default_map_fields(fields, durable_state)'),
                        restore.index('durable_metadata_restore_fields(map, fields, durable_metadata_map_schema())'))


class WeatherCallbackCompatibility(unittest.TestCase):
    def test_finite_legacy_callbacks_remain_without_old_scheduler(self):
        source = (ROOT/'code/modules/persistence/durable_environment.dm').read_text()
        for event in ('blizzard', 'heat', 'sandstorm'):
            for phase in ('start', 'end'):
                key = f'{event}_{phase}'
                self.assertIn(f'"{key}" = "durable_{key}"', source)
                self.assertIn(f'/obj/map_metadata/proc/durable_{key}()', source)
        self.assertNotIn('/obj/map_metadata/proc/durable_weather_events()', source)
        queue = (ROOT/'code/modules/persistence/durable_timers.dm').read_text()
        self.assertIn('!(key in allowed)', queue)
        self.assertIn('remaining < 0 || remaining > 1e15', queue)


if __name__=='__main__':
    unittest.main()
