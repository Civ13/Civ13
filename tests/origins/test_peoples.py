"""Peoples as world records (peoples.dm): Gaia's own roots, the name
blocklist, travel and the admin verbs. Offline only; the behaviour is in the
native probe tests/origins/peoples_probe.dm."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
PEOPLES = (ROOT / 'code/game/mob/living/carbon/human/peoples.dm').read_text()
ORIGINS = (ROOT / 'code/game/mob/living/carbon/human/origins.dm').read_text()
ADMIN = (ROOT / 'code/modules/admin/verbs/peoples_admin.dm').read_text()
SPLIT = (ROOT / 'code/game/mob/living/carbon/human/peoples_split.dm').read_text()
BLEND = (ROOT / 'code/game/mob/living/carbon/human/peoples_blend.dm').read_text()
BLOCKED = (ROOT / 'config/people_names_blocked.txt').read_text()


def proc(text, head):
    body = text[text.index(head):]
    nxt = re.search(r'\n(?=/)', body[1:])
    return body[:nxt.start() + 1] if nxt else body


class GaiaRoots(unittest.TestCase):
    def test_gaia_hands_out_only_its_own_peoples(self):
        gaia = ORIGINS[ORIGINS.index('var/list/gaia = list('):ORIGINS.index('var/list/europe')]
        ids = set(re.findall(r'= "(\w+)"', gaia))
        renames = dict(re.findall(r'"(\w+)" = "(\w+)"', proc(PEOPLES, '/proc/gaia_root_renames')))
        self.assertEqual(ids, set(renames.values()))
        for old, new in renames.items():
            self.assertIn('id = "%s"' % old, ORIGINS)
            self.assertIn('/datum/origin/%s\n\tid = "%s"' % (new, new), ORIGINS)

    def test_a_gaia_root_keeps_the_language_and_names_it_replaces(self):
        renames = dict(re.findall(r'"(\w+)" = "(\w+)"', proc(PEOPLES, '/proc/gaia_root_renames')))
        def fields(text, oid):
            block = text[text.index('/datum/origin/%s\n' % oid):]
            block = block[:block.index('\n\n')]
            return dict(re.findall(r'^\t(language|name_style) = (.+)$', block, re.M))
        for old, new in renames.items():
            self.assertEqual(fields(ORIGINS, old), fields(ORIGINS, new), new)

    def test_settling_happens_at_login(self):
        login = (ROOT / 'code/modules/research_tree/knowledge_spread.dm').read_text()
        self.assertIn('\toffer_pending_language_naming()\n\tsettle_people_record()', login)
        settle = proc(PEOPLES, '/mob/living/human/proc/settle_people_record')
        self.assertIn('(origin_land in gaia_land_names())', settle)


class Records(unittest.TestCase):
    def test_records_live_with_the_daughter_languages(self):
        self.assertIn('return language_lineage_part("peoples")', PEOPLES)
        lookup = proc(ORIGINS, '/proc/origin_by_id')
        self.assertIn('. = world_people(id)', lookup)

    def test_no_initialised_globals_in_peoples(self):
        # The world's global init proc sits near the compiler's size limit.
        for text in (PEOPLES, ADMIN, SPLIT, BLEND):
            self.assertIsNone(re.search(r'^\s*var/(static|global)/[^\n=]*= *list\(', text, re.M))

    def test_a_formed_people_dresses_like_its_root(self):
        outfits = (ROOT / 'code/modules/1713/jobs/spawn_outfits.dm').read_text()
        self.assertIn('var/datum/origin/root = origin_root(origin_by_id(origin_id))', outfits)

    def test_travel_carries_and_checks_people_records(self):
        tongues = (ROOT / 'code/modules/persistence/region_travel_tongues.dm').read_text()
        self.assertIn('T["peoples"] = peoples', tongues)
        self.assertIn('region_travel_import_peoples(T["peoples"])', tongues)
        self.assertIn('record["imported"] = TRUE', proc(tongues, '/proc/region_travel_import_peoples'))


class Splits(unittest.TestCase):
    def test_splits_run_on_the_calendar_never_on_research_eras(self):
        # Eras move with player research (Val, 2026-11-21).
        self.assertNotIn('ordinal_age', SPLIT)
        self.assertNotIn('era', re.sub(r'//.*', '', SPLIT).replace('area', ''))
        self.assertIn('people_year_check(world_calendar_year())', SPLIT)

    def test_contact_is_watched_and_halves_the_years_apart(self):
        hear = (ROOT / 'code/game/mob/hear_say.dm').read_text()
        self.assertIn('H.language_drift_heard(language, speaker)\n\t\tH.people_heard(speaker)', hear)
        drift = (ROOT / 'code/game/mob/language/drift.dm').read_text()
        self.assertIn('people_isolation_tick()', proc(drift, '/proc/language_drift_tick'))
        check = proc(SPLIT, '/proc/people_year_check')
        self.assertIn('isolation[key] = round((isnum(isolation[key]) ? isolation[key] : 0) / 2)', check)
        self.assertLess(check.index('for (var/key in active)'), check.index('active.Cut()'))

    def test_splits_are_rare(self):
        defines = (ROOT / 'code/__defines/species_languages.dm').read_text()
        years = int(re.search(r'#define PEOPLE_SPLIT_YEARS (\d+)', defines).group(1))
        self.assertGreaterEqual(years, 180)
        self.assertGreaterEqual(int(re.search(r'#define PEOPLE_SPLIT_MIN (\d+)', defines).group(1)), 5)

    def test_only_a_verified_leader_names_a_people(self):
        verb = proc(SPLIT, '/mob/living/human/proc/name_our_people()\n')
        self.assertLess(verb.index('map.is_faction_leader(src, civilization)'), verb.index('split_people('))
        self.assertLess(verb.index('account_verified(nation_account())'), verb.index('split_people('))
        self.assertIn('people_name_problem(wanted)', verb)
        login = (ROOT / 'code/modules/research_tree/knowledge_spread.dm').read_text()
        self.assertIn('settle_people_record()\n\toffer_pending_people_naming()', login)


class BlendAndBelong(unittest.TestCase):
    def test_both_run_on_the_yearly_check(self):
        check = proc(SPLIT, '/proc/people_year_check')
        self.assertLess(check.index('people_blend_year(active, year)'), check.index('active.Cut()'))
        self.assertLess(check.index('people_belong_year()'), check.index('active.Cut()'))
        self.assertIn('H.people_played_year = TRUE', proc(SPLIT, '/proc/people_isolation_tick'))
        self.assertNotIn('ordinal_age', BLEND)

    def test_nobody_is_moved_by_a_blend_or_by_belonging(self):
        self.assertNotIn('origin_id =', re.sub(r'//.*', '', BLEND))

    def test_newcomers_are_born_into_a_blend(self):
        choose = proc(ORIGINS, '/mob/living/human/proc/choose_origin')
        self.assertIn('var/datum/origin/blend = community_blend_people(get_turf(src), src)', choose)
        self.assertLess(choose.index('community_blend_people('), choose.index('if (legacy_people)'))

    def test_welcome_is_a_leaders_note(self):
        verb = proc(BLEND, '/mob/living/human/proc/welcome_among_us()\n')
        self.assertLess(verb.index('map.is_faction_leader(src, civilization)'), verb.index('H.people_welcomed |= O.id'))
        self.assertIn('H.raised_among(O.id)', verb)
        login = (ROOT / 'code/modules/research_tree/knowledge_spread.dm').read_text()
        self.assertIn('offer_pending_people_naming()\n\toffer_people_welcome()', login)


class Names(unittest.TestCase):
    def test_new_peoples_and_languages_take_the_blocklist(self):
        self.assertIn('if (name_blocked(text))', proc(PEOPLES, '/proc/people_name_problem'))
        daughter = (ROOT / 'code/game/mob/language/daughter.dm').read_text()
        self.assertIn('if (name_blocked(text))', proc(daughter, '/proc/language_name_problem'))

    def test_blocklist_covers_races_peoples_and_slurs(self):
        lines = [l.strip() for l in BLOCKED.splitlines() if l.strip() and not l.startswith('#')]
        self.assertTrue(all(l == l.lower() for l in lines))
        words = {l for l in lines if not l.startswith('*')}
        parts = {l[1:] for l in lines if l.startswith('*')}
        self.assertTrue({'white', 'black', 'aryan', 'german', 'zulu'} <= words)
        self.assertGreaterEqual(len(parts), 20)
        # A part blocks anywhere, so it must be long enough not to catch ordinary names.
        self.assertTrue(all(len(p) >= 3 for p in parts))
        for ordinary in ('spice', 'abode', 'raccoon', 'jasper'):
            self.assertFalse(any(p in ordinary for p in parts), ordinary)


class AdminVerbs(unittest.TestCase):
    def test_registered_guarded_and_logged(self):
        registry = (ROOT / 'code/modules/admin/admin_verbs.dm').read_text(encoding='latin-1')
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertIn('code\\modules\\admin\\verbs\\peoples_admin.dm', dme)
        self.assertIn('code\\game\\mob\\living\\carbon\\human\\peoples.dm', dme)
        for verb in ('cmd_admin_check_peoples', 'cmd_admin_found_people', 'cmd_admin_rename_people', 'cmd_admin_merge_people', 'cmd_admin_force_people_split'):
            self.assertIn('/client/proc/%s,' % verb, registry)
            body = proc(ADMIN, '/client/proc/%s(' % verb)
            self.assertIn('if (!check_rights(R_ADMIN))\n\t\treturn', body)
            if verb != 'cmd_admin_check_peoples':
                self.assertIn('log_admin(', body)

    def test_set_origin_offers_formed_peoples(self):
        origin_admin = (ROOT / 'code/modules/admin/verbs/origin_languages.dm').read_text()
        self.assertIn('var/list/peoples = all_people_choices()', origin_admin)


if __name__ == '__main__':
    unittest.main()
