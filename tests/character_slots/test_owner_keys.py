"""Source checks for character slot owner keys (docs/character-slots.md)."""
import re
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def read(path):
    return (ROOT / path).read_text()


class OwnerKeySourceTest(unittest.TestCase):
    def test_owner_keys_are_defined_once(self):
        source = read("code/modules/persistence/player_reclaim.dm")
        for proc in ("/proc/owner_key_slot(key)", "/proc/owner_key_account(key)",
                     "/proc/owner_key_for(account, slot = 1)", "/client/proc/owner_key()"):
            self.assertEqual(source.count(proc), 1, proc)
        # Slot keys start with "@", which no ckey, account key or agent account does.
        self.assertIn('copytext(key, 1, 2) != "@"', source)
        self.assertIn('return "@[round(slot)][account]"', source)
        self.assertIn("if(slot > 1) return persistence_owner_valid(owner_key_account(account))", source)
        self.assertIn("if(!slot) return FALSE", source)

    def test_bodies_beds_and_homes_belong_to_the_owner_key(self):
        sites = {
            "code/modules/persistence/player_reclaim.dm": ("var/account = client.owner_key()", "var/owner = C.owner_key()"),
            "code/modules/persistence/bed_return.dm": ("character_return_pending(lobby.client.owner_key())",),
            "code/modules/persistence/region_travel.dm": ("region_travel_waiting_body(C.owner_key())",),
            "code/modules/persistence/region_event.dm": ("event_stash_of(lobby.client.owner_key())",),
            "code/modules/research_tree/death_legacy.dm": ("H.client.owner_key()",),
            "code/game/objects/map_metadata/nomads/nomads_start.dm": ("region_home_bed(lobby.client.owner_key())",),
        }
        for path, needles in sites.items():
            source = read(path)
            for needle in needles:
                self.assertIn(needle, source, path)

    def test_no_ownership_compare_uses_the_bare_ckey(self):
        for path in ("code/modules/persistence/player_reclaim.dm", "code/modules/persistence/bed_return.dm",
                     "code/modules/persistence/region_home.dm", "code/modules/persistence/region_travel.dm"):
            source = read(path)
            self.assertIsNone(re.search(r"persistence_(bed_)?owner_ckey (==|!=) (H\.|C\.|lobby\.)?client\.ckey", source), path)
            self.assertIsNone(re.search(r"(client|C)\.ckey (==|!=) [A-Za-z_.]*persistence_(bed_)?owner_ckey", source), path)

    def test_the_person_is_the_account_behind_the_key(self):
        # Accolades, karma, magic, activity and admin lookups belong to the person.
        for path, needle in (
                ("code/modules/accolades/accolades.dm", "account = owner_key_account(account)"),
                ("code/modules/karma/karma_give.dm", "owner_key_account(H.persistence_owner_ckey)"),
                ("code/modules/divine/magic_whitelist.dm", "ckey(owner_key_account(persistence_owner_ckey))"),
                ("code/modules/player_activity/player_activity.dm", "owner_key_account(H.persistence_owner_ckey)"),
                ("code/modules/admin/verbs/research_knowledge.dm", "owner_key_account(persistence_owner_ckey)"),
                ("code/game/mob/groups/nation.dm", "owner_key_account(H.persistence_owner_ckey) == actor")):
            self.assertIn(needle, read(path), path)

    def test_a_solo_party_may_be_a_slot_key(self):
        source = read("code/modules/persistence/party_train.dm")
        self.assertIn("ckey(owner_key_account(copytext(party, 6))) == owner_key_account(copytext(party, 6))", source)

    def test_the_coordinator_accepts_slot_keys(self):
        import sys
        sys.path.insert(0, str(ROOT))
        from tools.transfer_storage.region import account_key_valid
        self.assertTrue(account_key_valid("@2" + "a" * 32))
        self.assertTrue(account_key_valid("a" * 32))
        self.assertFalse(account_key_valid("a" * 33))
        self.assertFalse(account_key_valid("@2" + "a" * 33))


if __name__ == "__main__":
    unittest.main()
