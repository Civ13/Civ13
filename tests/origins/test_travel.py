"""A traveller's people and languages cross between lands with them.

Source contracts for code/modules/persistence/region_travel_tongues.dm and
its hooks in region_travel.dm. Never launches BYOND.
"""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TRAVEL = (ROOT / 'code/modules/persistence/region_travel.dm').read_text(encoding='utf-8-sig').replace('\r\n', '\n')
TONGUES = (ROOT / 'code/modules/persistence/region_travel_tongues.dm').read_text().replace('\r\n', '\n')


def proc(source, name):
    start = source.index('\n' + name + '(') + 1
    end = re.search(r'\n(?=[^\s#])', source[start + 1:])
    return source[start:start + 1 + end.start()] if end else source[start:]


class TravelCarriesLanguages(unittest.TestCase):
    def test_file_is_compiled_after_travel(self):
        dme = (ROOT / 'civ13.dme').read_text()
        self.assertLess(dme.index('persistence\\region_travel.dm'), dme.index('persistence\\region_travel_tongues.dm'))

    def test_every_trip_carries_the_record(self):
        payload = proc(TRAVEL, '/mob/living/human/proc/region_travel_payload')
        self.assertIn('var/list/tongues = region_travel_tongues()\n\tif(tongues)\n\t\tP["tongues"] = tongues', payload)
        self.assertLess(payload.index('P["tongues"] = tongues'), payload.index('return json_encode(P)'))

    def test_the_record_holds_scores_default_people_and_todays_gains(self):
        build = proc(TONGUES, '/mob/living/human/proc/region_travel_tongues')
        for needle in ('for(var/datum/language/held in languages)', 'for(var/lname in partial_languages)',
                       'T["default"] = speaking.name', 'T["origin"] = origin_id', 'T["land"] =',
                       'T["day"] = language_gain_day', 'T["today"] = today'):
            self.assertIn(needle, build)
        # A spoken language never arrives unspoken.
        self.assertIn('known[L.name] = max(LANGUAGE_BROKEN, round(language_score(L), 0.01))', build)

    def test_a_bad_record_refuses_the_trip(self):
        decode = proc(TRAVEL, '/proc/region_travel_decode')
        self.assertIn('if(("tongues" in P) && !region_travel_tongues_valid(P["tongues"])) return null', decode)
        valid = proc(TONGUES, '/proc/region_travel_tongues_valid')
        for needle in ('!language_learnable(all_languages[lname])', 'score <= 0 || score > 100',
                       '!(chosen in known) || known[chosen] < LANGUAGE_BROKEN', '!origin_by_id(value["origin"])',
                       'if(!(key in list("known", "default", "origin", "land", "day", "today", "native", "daughters"))) return FALSE',
                       '!region_travel_gain_bucket_valid(bucket, known)'):
            self.assertIn(needle, valid)

    def test_the_arrival_gets_its_languages_instead_of_the_new_bodys(self):
        build = proc(TRAVEL, '/proc/region_travel_build')
        self.assertLess(build.index('H.persistence_restored = TRUE'), build.index('H.region_travel_restore_tongues(P["tongues"])'))
        restore = proc(TONGUES, '/mob/living/human/proc/region_travel_restore_tongues')
        # No record (an older sender): the body is left as it is.
        self.assertTrue(restore.split('\n')[1].strip().startswith('if(!islist(T) || !islist(T["known"])) return FALSE'))
        self.assertLess(restore.index('languages -= held'), restore.index('languages += L'))
        self.assertIn('partial_languages[L.name] = known[lname] * L.difficulty / 100', restore)
        self.assertIn('if(known[lname] >= LANGUAGE_BROKEN && !(L in languages))', restore)
        for needle in ('origin_id = T["origin"]', 'origin_land = T["land"]', 'language_gain_today = today.Copy()'):
            self.assertIn(needle, restore)
        # Always someone to talk as.
        self.assertIn('default_language = speaking', restore)
        self.assertIn('var/datum/language/own = mother_tongue()', restore)

    def test_notes_are_written_when_the_player_takes_the_body(self):
        claim = proc(TRAVEL, '/proc/region_travel_claim')
        self.assertLess(claim.index('H.key = C.key'), claim.index('H.region_travel_tongue_notes()'))
        notes = proc(TONGUES, '/mob/living/human/proc/region_travel_tongue_notes')
        self.assertIn('if(!mind) return', notes)
        self.assertIn('!(islist(listed) && (held.name in listed))', notes)


class TravelKeepsFactionVerbs(unittest.TestCase):
    def test_the_arrival_gets_the_role_verbs(self):
        # A travelled body never ran a job's equip(), so without this it had
        # no Create Faction / Abandon Faction verbs until its next reload.
        build = proc(TRAVEL, '/proc/region_travel_build')
        self.assertIn('H.restore_role_verbs()', build)
        self.assertLess(build.index('colony_arrival(H, P)'), build.index('H.restore_role_verbs()'))
        self.assertLess(build.index('H.restore_role_verbs()'), build.index('return H'))
        factions = '\n' + (ROOT / 'code/game/mob/groups/factions.dm').read_text(encoding='utf-8-sig').replace('\r\n', '\n')
        restore = proc(factions, '/mob/living/human/proc/restore_role_verbs')
        self.assertIn('make_nomad()', restore)
        nomad = proc(factions, '/mob/living/human/proc/make_nomad')
        for verb in ('create_faction', 'abandon_faction'):
            self.assertIn('verbs += /mob/living/human/proc/' + verb, nomad)

    def test_the_arrival_is_a_nomad(self):
        # Recruit, research levels and the faction HUD gate on "Nomad"; a bare
        # body kept the mob default ("Sailor") and could not recruit (2026-11-15).
        factions = '\n' + (ROOT / 'code/game/mob/groups/factions.dm').read_text(encoding='utf-8-sig').replace('\r\n', '\n')
        restore = proc(factions, '/mob/living/human/proc/restore_role_verbs')
        self.assertIn('if (original_job_title == initial(original_job_title))\n\t\t\toriginal_job_title = "Nomad"', restore)
        self.assertLess(restore.index('original_job_title = "Nomad"'), restore.index('make_nomad()'))
        recruit = (ROOT / 'code/game/mob/living/carbon/give.dm').read_text(encoding='utf-8-sig')
        self.assertIn('user.original_job_title != "Nomad"', recruit)


if __name__ == '__main__':
    unittest.main()
