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


if __name__ == '__main__':
    unittest.main()
