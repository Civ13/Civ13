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
            for path in (run.RECRUITMENT, run.MEMBERSHIP, run.FACTIONS, run.RESEARCH, run.RENAME):
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


if __name__ == '__main__':
    unittest.main()
