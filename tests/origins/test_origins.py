"""Peoples of the Nomads lands: the origin table stays consistent with the
languages, name generators and colour tables it points at. Offline only."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
ORIGINS = (ROOT / 'code/game/mob/living/carbon/human/origins.dm').read_text()
SPAWN = (ROOT / 'code/game/mob/living/carbon/human/nomads_spawn.dm').read_text()
CLIMATES = {'tundra', 'taiga', 'temperate', 'semiarid', 'sea', 'desert', 'savanna', 'jungle'}


def dm_list(text):
    return re.findall(r'"([^"]+)"', text)


def origins():
    found = {}
    for block in re.split(r'\n(?=/datum/origin/)', ORIGINS)[1:]:
        block = block.split('\nvar/global')[0]
        fields = dict(re.findall(r'^\t(\w+) = (.+)$', block, re.M))
        found[fields['id'].strip('"')] = fields
    return found


def tables():
    body = ORIGINS[ORIGINS.index('/proc/land_origin_tables()'):ORIGINS.index('/proc/land_has_origins')]
    named = {}
    for name, rows in re.findall(r'var/list/(\w+) = list\((.*?)\)\n', body, re.S):
        named[name] = dict(re.findall(r'"(\w+)" = "(\w+)"', rows))
    lands = dict(re.findall(r'(MAP_\w+) = (\w+)', body[body.index('tables = list('):]))
    return named, lands


class OriginTable(unittest.TestCase):
    def test_every_people_points_at_real_data(self):
        languages = set(re.findall(r'^\s*name\s*=\s*"([^"]+)"', (ROOT / 'code/game/mob/language/earth.dm').read_text(), re.M))
        species = (ROOT / 'code/game/mob/living/carbon/human/species/species.dm').read_text()
        colours = (ROOT / 'code/_helpers/global_lists.dm').read_text()
        hair = set(dm_list(colours[colours.index('var/list/hair_colors'):colours.index('var/list/eye_colors')])[::2])
        eyes = set(dm_list(colours[colours.index('var/list/eye_colors'):colours.index('var/global/list/global_mutations')])[::2])
        people = origins()
        self.assertGreaterEqual(len(people), 20)
        names = [f['name'] for f in people.values()]
        self.assertEqual(len(names), len(set(names)))
        for oid, f in people.items():
            self.assertIn(f['language'].strip('"'), languages, oid)
            self.assertIn('/datum/species/proc/get_random_%s_name(' % f['name_style'].strip('"'), species, oid)
            # A people never sets looks: no look may mark someone as one people.
            self.assertFalse({'hair', 'eyes', 'skin'} & set(f), oid)
        looks = ORIGINS[ORIGINS.index('/proc/birthplace_looks('):ORIGINS.index('/proc/land_has_origins')]
        named = dict(re.findall(r'var/list/(\w+) = list\(([^)]*)\)', looks))
        rows = re.findall(r'"(\w+)" = list\((\w+), (\w+), list\((-?\d+), (-?\d+)\)\)', looks)
        self.assertEqual({r[0] for r in rows}, CLIMATES | {'default'})
        for climate, eye_list, hair_list, light, dark in rows:
            self.assertTrue(set(dm_list(named[eye_list])) <= eyes, climate)
            self.assertTrue(set(dm_list(named[hair_list])) <= hair, climate)
            # Wide ranges: every climate spans at least 60 tones.
            self.assertTrue(0 >= int(light) > int(dark) >= -185, climate)
            self.assertGreaterEqual(int(light) - int(dark), 60, climate)

    def test_every_land_covers_every_climate(self):
        people = origins()
        named, lands = tables()
        for land in ('MAP_NOMADS_GAIA', 'MAP_NOMADS_EUROPE', 'MAP_NOMADS_AFRICA', 'MAP_NOMADS_ASIA',
                     'MAP_NOMADS_AMERICAS_NORTH', 'MAP_NOMADS_AMERICAS_SOUTH', 'MAP_NOMADS_JUNGLE',
                     'MAP_NOMADS_DESERT'):
            self.assertIn(land, lands)
        for land, table_name in lands.items():
            table = named[table_name]
            self.assertIn('default', table, land)
            self.assertTrue(set(table) - {'default'} <= CLIMATES, land)
            for origin_id in table.values():
                self.assertIn(origin_id, people, land)

    def test_the_americas_have_their_own_peoples(self):
        named, lands = tables()
        gaia = set(named[lands['MAP_NOMADS_GAIA']].values())
        for land in ('MAP_NOMADS_AMERICAS_NORTH', 'MAP_NOMADS_AMERICAS_SOUTH'):
            self.assertFalse(set(named[lands[land]].values()) & gaia, land)

    def test_spawn_uses_the_table_and_records_the_origin(self):
        self.assertIn('else if (map && land_has_origins(map.ID))\n\t\tchoose_origin(mob_area ? mob_area.climate : null)', SPAWN)
        for retired in ('MAP_NOMADS_EUROPE', 'MAP_NOMADS_AFRICA', 'MAP_NOMADS_ASIA', 'MAP_NOMADS_GAIA'):
            self.assertNotIn(retired, SPAWN)
        apply = ORIGINS[ORIGINS.index('/mob/living/human/proc/apply_origin'):]
        self.assertLess(apply.index('origin_id = O.id'), apply.index('if (keep_setup)'))
        self.assertLess(apply.index('if (keep_setup)'), apply.index('update_character_appearance'))
        self.assertIn('var/list/looks = birthplace_looks(climate)', apply)
        self.assertNotIn('O.skin', ORIGINS)
        choose = ORIGINS[ORIGINS.index('/mob/living/human/proc/choose_origin'):ORIGINS.index('/mob/living/human/proc/apply_origin')]
        # Nobody without a keyboard is asked anything, and a second call is a no-op.
        self.assertIn('if (!map || origin_id)\n\t\treturn FALSE', choose)
        self.assertLess(choose.index('if (client)'), choose.index('WWinput'))

    def test_inuktitut_survives_the_hearing_capitalisation(self):
        earth = (ROOT / 'code/game/mob/language/earth.dm').read_text()
        self.assertIn('name = "Inuktitut"', earth)
        self.assertNotIn('name = "inuktitut"', earth)

    def test_south_america_has_andean_and_forest_peoples(self):
        named, lands = tables()
        south = named[lands['MAP_NOMADS_AMERICAS_SOUTH']]
        self.assertEqual(south['jungle'], 'tupi')
        self.assertEqual(south['default'], 'inca')
        self.assertEqual(set(south.values()), {'inca', 'tupi', 'caribs'})
        earth = (ROOT / 'code/game/mob/language/earth.dm').read_text(encoding='latin-1')
        written = (ROOT / 'code/modules/paperwork/written_languages.dm').read_text()
        keys = re.findall(r'^\s*key = "(\w+)"', earth, re.M)
        for language in ('quechua', 'tupi'):
            self.assertIn('/datum/language/%s\n' % language, earth)
            self.assertIn('"civ13:%s:v1" = /datum/language/%s' % (language, language), written)
            for gender in ('male', 'female'):
                # In code, not config/names: fixtures stage an exact pinned set of name files.
                row = re.search(r'^var/global/list/first_names_%s_%s = list\((.+)\)$' % (gender, language), ORIGINS, re.M)
                names = dm_list(row.group(1))
                self.assertGreaterEqual(len(names), 20)
                self.assertTrue(all(n.isascii() and n.isalpha() for n in names), language)
        for key in ('qu', 'tp'):
            self.assertEqual(keys.count(key), 1, key)


class PeoplesAreNeverATarget(unittest.TestCase):
    """No game rule may read a character's people, and nobody can see it on sight."""

    # The only files allowed to read a character's people. Each one either
    # keeps the record (save, travel, admin, agents) or gives a birth default
    # (mother tongue, starting clothes). Adding a file here needs a reason
    # that is not a game rule: no stat, price, law, door, job or spawn check.
    READERS = {
        'code/game/mob/living/carbon/human/origins.dm',
        'code/game/mob/living/carbon/human/peoples.dm',
        'code/game/mob/living/carbon/human/peoples_split.dm',
        'code/game/mob/living/carbon/human/peoples_blend.dm',
        'code/modules/admin/verbs/peoples_admin.dm',
        'code/game/mob/language/proficiency.dm',
        'code/modules/1713/jobs/spawn_outfits.dm',
        'code/modules/admin/verbs/origin_languages.dm',
        'code/modules/agent_control/agent_characters.dm',
        'code/modules/persistence/region_travel_tongues.dm',
        'code/modules/research_tree/death_legacy.dm',
    }
    READ = re.compile(r'\borigin_id\b|\bget_origin\(|\borigin_summary\(|\borigin_land\b|\bpeople_raised\b|\bpeople_welcomed\b|\braised_among\(')

    def test_only_record_keepers_read_a_people(self):
        readers = set()
        for path in (ROOT / 'code').rglob('*.dm'):
            for line in path.read_text(encoding='latin-1').splitlines():
                code = line.split('//')[0]
                if self.READ.search(code):
                    readers.add(path.relative_to(ROOT).as_posix())
                    break
        self.assertEqual(readers - self.READERS, set())

    def test_examine_never_names_a_people(self):
        examine = (ROOT / 'code/game/mob/living/carbon/human/examine.dm').read_text(encoding='latin-1')
        self.assertIsNone(re.search(r'\borigins?\b|\bpeoples?\b|origin_summary|get_origin', examine, re.I))


class AdminAndAgentTools(unittest.TestCase):
    ADMIN = (ROOT / 'code/modules/admin/verbs/origin_languages.dm').read_text()

    def test_admin_verbs_are_registered_and_guarded(self):
        registry = (ROOT / 'code/modules/admin/admin_verbs.dm').read_text(encoding='latin-1')
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('code\\modules\\admin\\verbs\\origin_languages.dm', dme)
        for verb in ('cmd_admin_check_languages', 'cmd_admin_set_origin', 'cmd_admin_set_language_score'):
            self.assertIn('/client/proc/%s,' % verb, registry)
            body = self.ADMIN[self.ADMIN.index('/client/proc/%s(' % verb):]
            body = body[:body.index('\n/client', 1)] if '\n/client' in body[1:] else body
            self.assertIn('if (!check_rights(R_ADMIN))\n\t\treturn', body)
        for verb in ('cmd_admin_set_origin', 'cmd_admin_set_language_score'):
            body = self.ADMIN[self.ADMIN.index('/client/proc/%s(' % verb):]
            self.assertIn('log_admin(', body)

    def test_a_score_change_never_leaves_a_character_mute(self):
        body = self.ADMIN[self.ADMIN.index('/mob/living/human/proc/admin_set_language_score'):self.ADMIN.index('/client/proc/cmd_admin_check_languages')]
        self.assertLess(body.index('if (!others)\n\t\t\t\treturn FALSE'), body.index('remove_language(L.name)'))
        self.assertIn('score = max(0, min(100, round(score)))', body)
        self.assertIn('if (!default_language || !knows_language(default_language))', body)

    def test_set_origin_keeps_name_and_looks(self):
        body = self.ADMIN[self.ADMIN.index('/mob/living/human/proc/admin_set_origin'):self.ADMIN.index('/mob/living/human/proc/admin_set_language_score')]
        self.assertNotIn('update_character_appearance', body)
        self.assertNotIn('real_name', body)
        self.assertIn('origin_id = O.id', body)

    def test_agents_can_ask_for_a_people_and_read_their_languages(self):
        chars = (ROOT / 'code/modules/agent_control/agent_characters.dm').read_text(encoding='latin-1')
        spawn = chars[chars.index('/datum/agent_control/proc/act_character_spawn'):chars.index('/datum/agent_control/proc/act_character_list')]
        self.assertLess(spawn.index('agent_fail("bad_origin"'), spawn.index('M = new path(T)'))
        self.assertIn('born.origin_wish = origin_wish', spawn)
        self.assertIn('out["languages"] = H.language_rows()', chars)
        choose = ORIGINS[ORIGINS.index('/mob/living/human/proc/choose_origin'):ORIGINS.index('/mob/living/human/proc/apply_origin')]
        # Only a people of this land, and the wish is used once.
        self.assertIn('if (wished && (wished.name in peoples))', choose)
        self.assertIn('var/list/peoples = community.len ? community_people_choices(community) : land_peoples(map.ID)', choose)
        self.assertIn('/mob/living/human/var/tmp/origin_wish', ORIGINS)
        catalog = (ROOT / 'tools/agent-control/catalog.py').read_text()
        self.assertIn('"origin": {"type": "string"', catalog)


if __name__ == '__main__':
    unittest.main()
