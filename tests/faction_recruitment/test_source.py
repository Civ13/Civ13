"""Offline checks for faction recruitment applications (#4237)."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402

ROOT = run.ROOT


def read(path):
    return (ROOT / path).read_text(encoding='utf-8').replace('\r\n', '\n')


class FactionRecruitmentSource(unittest.TestCase):
    def test_controls_and_extracted_procs_are_unique(self):
        for control in (None, *run.CONTROLS):
            for path in (run.RECRUITMENT, run.MEMBERSHIP, run.FACTIONS, run.RESEARCH, run.RENAME, run.ROSTER, run.COLONY, run.PARTY):
                run.read(path, control)
        self.assertIn('#include "code\\game\\mob\\groups\\faction_recruitment.dm"', read('civ13.dme'))

    def test_state_is_a_durable_map_field(self):
        contract = read('code/modules/persistence/durable_contract.dm')
        self.assertIn('"faction_renames", "faction_recruitment"),', contract)
        self.assertIn('if(!("faction_recruitment" in schema)) result["faction_recruitment"] = list()', contract)

    def test_lifecycle_hooks(self):
        death = run.proc_text(read('code/game/mob/living/carbon/human/death.dm'), '/mob/living/human/death(')
        self.assertIn('recruitment_life_id = null', death)
        rename = run.proc_text(read(run.RENAME), '/obj/map_metadata/proc/rename_faction(')
        self.assertIn('recruitment_rename_faction(old_name, new_name)', rename)
        login = read('code/modules/1713/cmss13_squad.dm').split('/mob/living/human/Login()', 1)[1].split('\n/', 1)[0]
        self.assertIn('recruitment_login_notices()', login)

    def test_config_keys_are_parsed_and_documented(self):
        config = read('code/datums/configuration.dm')
        text = read('config/config.txt')
        for key in ('recruitment_expiry_days', 'recruitment_queue_limit', 'recruitment_cooldown_minutes'):
            self.assertIn(f'var/{key} = ', config)
            self.assertIn(f'"{key}"', config)
            self.assertIn(key.upper() + ' ', text)

    def test_records_hold_no_object_references(self):
        source = read(run.RECRUITMENT)
        submit = run.proc_text(source, '/obj/map_metadata/proc/recruitment_submit(')
        record = submit.split('var/list/A = list(', 1)[1].split('\n', 1)[0]
        for value in ('= H,', '= H)', '= src', '= R,', '= R)'):
            self.assertNotIn(value, record)
        self.assertIn('"life" = H.recruitment_identity()', record)

    def test_station_is_craftable_and_registered(self):
        self.assertIn('#include "code\\game\\mob\\groups\\recruitment_station.dm"', read('civ13.dme'))
        recipes = read('config/crafting/material_recipes_global.txt')
        self.assertIn('recruitment station,/obj/structure/recruitment_station,10,', recipes)
        self.assertIn('"/obj/structure/recruitment_station" = "basic_furniture"', read('code/modules/research_tree/research_node.dm'))
        factions = read(run.FACTIONS)
        self.assertGreaterEqual(factions.count('verbs += /mob/living/human/proc/recruitment_applications'), 2)
        self.assertIn("'recruitment_station.tmpl': RecruitmentStation", read('tgui/src/interfaces/index.tsx'))
        self.assertTrue((ROOT / 'UI/templates/recruitment_station.tmpl').is_file())

    def test_panel_rechecks_after_prompts(self):
        station = read('code/game/mob/groups/recruitment_station.dm')
        state = run.proc_text(station, '/datum/topic_state/recruitment_panel/can_use_topic(')
        self.assertIn('H.Adjacent(P.station)', state)
        topic = run.proc_text(station, '/datum/recruitment_panel/Topic(')
        # Every state change routes through the shared map helpers, never raw list edits.
        for helper in ('map.recruitment_submit(', 'map.recruitment_decide(', 'map.recruitment_set_policy('):
            self.assertIn(helper, topic)
        self.assertNotIn('faction_recruitment[', topic)
        self.assertGreaterEqual(topic.count('still_valid(H)'), 6)
        # The client only ever sends opaque ids or fixed values.
        template = read('UI/templates/recruitment_station.tmpl')
        self.assertNotIn("'name': ", template)



class FactionMemberStartSource(unittest.TestCase):
    """Val's rule (2026-11-14): only accounts that joined a faction in play may start with it."""

    def setUp(self):
        self.start = read('code/game/mob/groups/faction_start.dm')
        self.roster = read(run.ROSTER)

    def test_included_and_the_roster_is_filled_only_in_play(self):
        dme = read('civ13.dme')
        self.assertLess(dme.index('faction_recruitment.dm"'), dme.index('faction_roster.dm"'))
        self.assertLess(dme.index('faction_roster.dm"'), dme.index('faction_start.dm"'))
        enroll = run.proc_text(read(run.MEMBERSHIP), '/mob/living/human/proc/enroll_in_faction(')
        self.assertIn('map.faction_roster_add(faction, faction_roster_account(src))', enroll)
        found = run.proc_text(read('code/game/mob/groups/faction_creation.dm'), '/datum/nano_module/faction_creation/proc/found_faction(')
        self.assertIn('map.faction_roster_add(newname, faction_roster_account(owner))', found)
        # Nothing in the lobby adds anyone to a roster.
        prompt = run.proc_text(self.start, '/mob/new_player/proc/faction_start_prompt(')
        self.assertNotIn('faction_roster_add', prompt)
        self.assertIn('map.faction_start_choices(account, colony_start_grant)', prompt)
        choices = run.proc_text(self.start, '/obj/map_metadata/proc/faction_start_choices(')
        self.assertIn('faction_on_roster(faction, account)', choices)

    def test_a_start_rechecks_the_roster_and_beats_the_bed(self):
        apply = run.proc_text(self.start, '/mob/new_player/proc/faction_start_apply(')
        self.assertLess(apply.index('map.faction_on_roster(faction, client.ckey)'), apply.index('H.civilization = faction'))
        destination = run.proc_text(self.start, '/mob/new_player/proc/faction_start_destination(')
        self.assertIn('map.faction_on_roster(faction_start_choice, client.ckey)', destination)
        gaia = run.proc_text(read('code/game/objects/map_metadata/nomads/nomads_start.dm'), '/obj/map_metadata/nomads/proc/new_player_destination(')
        self.assertLess(gaia.index('lobby.faction_start_destination()'), gaia.index('region_home_bed('))
        character = run.proc_text(read('code/game/mob/new_player/new_player.dm'), '/mob/new_player/proc/create_character(')
        self.assertLess(character.index('faction_start_apply(new_character)'), character.index('new_character.key = key'))
        late = run.proc_text(read('code/game/mob/new_player/new_player.dm'), '/mob/new_player/proc/AttemptLateSpawn(')
        self.assertLess(late.index('map_storage.allow_new_character(src)'), late.index('faction_start_prompt()'))

    def test_colony_starts_need_a_grant_from_the_factions_own_land(self):
        # Abroad: only factions founded here, only lands taking colony starts.
        abroad = run.proc_text(self.start, '/obj/map_metadata/proc/faction_colony_choices(')
        for need in ('colonies[faction]', 'faction_on_roster(faction, account)', 'list("COLONY", "OPEN")'):
            self.assertIn(need, abroad)
        prompt = run.proc_text(self.start, '/mob/new_player/proc/faction_start_prompt(')
        self.assertIn('region_home_ask(account, "colony", pick[1], pick[2])', prompt)
        self.assertIn('region_home_ask(account, "colony_used", null, colony_start_grant)', prompt)
        # Here: a grant stands in for the roster only for its own colony.
        for name in ('/mob/new_player/proc/faction_start_apply(', '/mob/new_player/proc/faction_start_destination('):
            self.assertIn('map.colony_home_faction(colony_start_grant) == faction', run.proc_text(self.start, name))
        admit = run.proc_text(read('code/modules/persistence/region_home.dm'), '/proc/region_home_admit(')
        self.assertIn('lobby.colony_start_grant = colony_parent_valid(result["colony_grant"])', admit)
        relocate = run.proc_text(read('code/game/jobs/job_controller.dm'), '/datum/controller/occupations/proc/relocate(')
        self.assertLess(relocate.index('H.faction_start_turf'), relocate.index('uses_random_new_player_spawn'))

    def test_open_land_wild_starts_skip_new_players_and_go_through_the_coordinator(self):
        wilds = run.proc_text(self.start, '/mob/new_player/proc/wild_start_choices(')
        for need in ('new_player_marks.is_new(client)', 'entry["stage"] != "OPEN"', 'entry["paused"]', 'land == shard_group.region'):
            self.assertIn(need, wilds)
        prompt = run.proc_text(self.start, '/mob/new_player/proc/faction_start_prompt(')
        self.assertIn('region_home_ask(account, "start", land)', prompt)

    def test_stations_register_and_limits_are_configurable(self):
        station = read('code/game/mob/groups/recruitment_station.dm')
        self.assertIn('recruitment_stations |= src', station)
        self.assertIn('recruitment_stations -= src', station)
        config = read('code/datums/configuration.dm')
        text = read('config/config.txt')
        for key in ('faction_member_limit', 'faction_roster_idle_days'):
            self.assertIn(f'var/{key} = ', config)
            self.assertIn(key.upper() + ' ', text)
        self.assertIn('verbs += /mob/living/human/proc/set_faction_member_limit', read(run.FACTIONS))


class ColonyCharterSource(unittest.TestCase):
    """Colonies: factions travel by id, a leader plants a charter abroad."""

    def setUp(self):
        self.colony = read(run.COLONY)
        self.travel = read('code/modules/persistence/region_travel.dm')

    def test_included_craftable_and_registered(self):
        dme = read('civ13.dme')
        self.assertLess(dme.index('faction_start.dm"'), dme.index('colony_charter.dm"'))
        self.assertIn('colony charter,/obj/structure/colony_charter,', read('config/crafting/material_recipes_global.txt'))
        self.assertIn('"/obj/structure/colony_charter" = "basic_furniture"', read('code/modules/research_tree/research_node.dm'))
        self.assertIn('colony_charters |= src', self.colony)
        self.assertIn('colony_charters -= src', self.colony)

    def test_travel_carries_the_faction_and_arrival_rejoins_it(self):
        payload = run.proc_text(self.travel, '/mob/living/human/proc/region_travel_payload(')
        self.assertIn('P["faction"] = faction_id', payload)
        self.assertIn('P["faction_leader"] = 1', payload)
        decode = run.proc_text(self.travel, '/proc/region_travel_decode(')
        self.assertIn('!colony_parent_valid(P["faction"])) return null', decode)
        self.assertIn('P["faction_leader"] != 1) return null', decode)
        arrive = self.travel[self.travel.index('party_train_restore_faction(H, P["party"])'):]
        self.assertLess(arrive.index('colony_arrival(H, P)'), arrive.index('region_raid_note_origin(H, P)'))
        arrival = run.proc_text(self.colony, '/proc/colony_arrival(')
        # Arrival goes through the one membership transition, so limits hold.
        self.assertIn('H.enroll_in_faction(name)', arrival)
        self.assertNotIn('civilization = name', arrival)

    def test_planting_rechecks_after_the_prompt_and_only_counts_standing_charters(self):
        attack = run.proc_text(self.colony, '/obj/structure/colony_charter/attack_hand(')
        self.assertEqual(2, attack.count('plant_block(user)'))
        self.assertLess(attack.index('WWinput('), attack.rindex('plant_block(user)'))
        block = run.proc_text(self.colony, '/obj/structure/colony_charter/proc/plant_block(')
        for need in ('user.colony_origin_leader', 'civ:[shard_group.region]:', 'faction_name_taken(name)'):
            self.assertIn(need, block)
        for name in ('/obj/map_metadata/proc/colony_home_faction(', '/obj/map_metadata/proc/colony_report('):
            self.assertIn('colony_charter_of(', run.proc_text(self.colony, name))
        self.assertIn('"colonies" = colonies', read('code/modules/persistence/land_stage.dm'))


if __name__ == '__main__':
    unittest.main()
