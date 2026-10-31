"""Offline preservation checks. These do not execute BYOND or prove client behavior."""
from pathlib import Path
import hashlib
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
BASE_JOIN_SHA = '8c910b21cc85f01039869b871262c55babb85d6a8374a86c6bd3dd4d8d54204e'
MENU_SHAS = {('code/game/mob/new_player/new_player.dm', 'LateChoices()'): 'd6eae368472d60e78fb4d09c2e68f8844247edddf2202a2f7a998ec1b1d6bc9a', ('code/game/objects/map_metadata/campaign_old.dm', 'LateChoicesCampaign(factjob)'): '9cf4be28ac9f39df0c385dd2e7faf3563d0ad0e9a2277738882dfbb4195c6375', ('code/game/objects/map_metadata/campaign_new.dm', 'LateChoicesCampaignNew(factjob)'): '16a459d851911c4601a4dd9535753d914601b9ec3b61cb57618edf741126ef97', ('code/game/objects/map_metadata/rotstadt.dm', 'LateChoicesRotstadt()'): 'f0b33436a4b76a741165bcd6acd9af9fa6e8e96bc49c45dd4340df875a351139'}


def procedure(source, name):
    start = source.index(name)
    next_type = re.search(r"^/(?!/)", source[start + len(name):], re.M)
    end = start + len(name) + next_type.start() if next_type else len(source)
    return source[start:end].rstrip()


def digest(value):
    return hashlib.sha256("\n".join(line.rstrip() for line in value.splitlines()).encode()).hexdigest()


class LobbyJoinSource(unittest.TestCase):
    def test_join_accessible_from_invisible_lobby(self):
        source = (ROOT / "code/game/mob/new_player/new_player.dm").read_text()
        verb = procedure(source, "/client/verb/Join()")
        # BYOND defaults verb invisibility to its source object's invisibility.
        # The lobby remains invisible; only the Join command is exposed.
        lobby = source[:source.index("\n/mob/new_player/")]
        self.assertRegex(lobby, r"(?m)^\s*invisibility = 101\s*$")
        def accessible(body):
            return re.findall(r"(?m)^\s*set invisibility = (\d+)\s*$", body) == ["0"]
        self.assertTrue(accessible(verb))
        self.assertFalse(accessible(verb.replace("\tset invisibility = 0\n", "")))
        self.assertFalse(accessible(verb.replace("set invisibility = 0", "set invisibility = 101")))
        self.assertNotRegex(verb, r"(?m)^\s*(?:src\.)?(?:invisibility|see_invisible)\s*=")

    def test_native_file_menu_invokes_the_same_verb(self):
        skin = (ROOT / "interface/skin.dmf").read_text()
        menu = skin[skin.index('menu "menu"'):]
        match = re.search(r'\telem "join-round"\n(.*?)(?=\telem |\Z)', menu, re.S)
        self.assertIsNotNone(match)
        item = match.group(1)
        self.assertIn('name = "&Join round"', item)
        self.assertIn('category = "&File"', item)
        self.assertEqual(re.findall(r'^\s*command = "(.*)"$', item, re.M), ['Join'])
        self.assertNotIn('byond://', item)

    def test_canonical_admission_and_job_body_preserved(self):
        source = (ROOT / "code/game/mob/new_player/new_player.dm").read_text()
        body = procedure(source, "/mob/new_player/proc/process_lobby_join(")
        # Reverse only the reviewed trait-validation replacement; preserve the
        # historical admission/body digest rather than accepting unrelated drift.
        guard = 'if (get_trait_selection_error(client.prefs.traits))'
        message = 'Please correct your character traits: [get_trait_selection_error(client.prefs.traits)]'
        old_message = "Your traits are not balanced! You can't join until you balance them (sum has to be <= 0)."
        self.assertEqual(body.count(guard), 5)
        self.assertEqual(body.count(message), 5)
        body = body.replace(guard, 'if (check_trait_points(client.prefs.traits) > 0)')
        body = body.replace(message, old_message)
        nomads = body.index('if (href_list["nomads"])')
        nomads_message = body.index(old_message, nomads)
        body = body[:nomads_message] + '<' + body[nomads_message:]
        # Cached fixed diagnostic codes do not alter the historical admission body.
        body = re.sub(r'^\s*lobby_join_trace\("[a-z_]+", "[a-z_]+"\)\n', '', body, flags=re.M)
        body = body[body.index('\tif (href_list["tribes"])'):]
        body = body[:body.index('\n\tif (!lobby_join_native && !href_list["late_join"])')].rstrip()
        body = body.replace("lobby_join_input(", "WWinput(src, ")
        account = procedure(source, "/mob/new_player/proc/lobby_join_campaign_faction()")
        account = account[account.index("\tvar/factjob"):account.rindex("\n\treturn factjob")]
        account = "\n".join("\t" + line for line in account.splitlines())
        body = body.replace("\t\tvar/factjob = lobby_join_campaign_faction()", account)
        body = body.replace('\t\tif (!lobby_join_job_available(href_list["SelectedJob"]))\n\t\t\treturn FALSE\n', "")
        body = body.replace(', href_list["SelectedJob"])) != "Yes")', ')) != "Yes")')
        body = re.sub(r'if \(\(lobby_join_confirmation\((.*)\)\) != "Yes"\)', r'if ((input(src, \1) in list("Yes", "No")) == "No")', body)
        self.assertEqual(digest(body), BASE_JOIN_SHA)

    def test_trait_validation_covers_waits_readiness_and_creation(self):
        source = (ROOT / "code/game/mob/new_player/new_player.dm").read_text()
        self.assertNotIn("check_trait_points(", source)
        guard = 'get_trait_selection_error(client.prefs.traits)'
        topic = procedure(source, "/mob/new_player/Topic(")
        self.assertIn('if (ready && ' + guard + ')\n\t\t\t\tready = FALSE', topic)
        admission = procedure(source, "/mob/new_player/proc/lobby_join_admission_current(")
        self.assertIn('&& !' + guard, admission)
        for name in ('lobby_join_input', 'lobby_join_confirmation'):
            wait = procedure(source, '/mob/new_player/proc/' + name + '(')
            self.assertGreaterEqual(wait.count('!lobby_join_admission_current()'), 2)
        for name, side_effect in (('AttemptLateSpawn', 'job_master.AssignRole('),
                                  ('create_character', 'delayed_spawning_as_job.total_positions')):
            body = procedure(source, '/mob/new_player/proc/' + name + '(')
            self.assertLess(body.index('allow_new_character(src)'), body.index(guard))
            self.assertLess(body.index(guard), body.index(side_effect))
        creation = procedure(source, '/mob/new_player/proc/create_character(')
        self.assertLess(creation.index('client.prefs.be_random_body'), creation.index('mind.transfer_to('))
        self.assertEqual(creation.count('qdel(new_character)'), 3)
        self.assertEqual(creation.count('spawning = FALSE'), 3)
        self.assertIn('var/copied_preferences = client.prefs.copy_to(new_character)', creation)
        self.assertIn('if (!copied_preferences)', creation)
        randomizer = (ROOT / 'code/game/mob/new_player/preferences_setup.dm').read_text()
        self.assertIn('return copy_to(H,1)', randomizer)
        ticker = procedure((ROOT / 'code/game/gameticker.dm').read_text(),
                          '/datum/controller/gameticker/proc/create_characters()')
        self.assertIn('if (player.create_character())\n\t\t\t\t\tqdel(player)', ticker)
        self.assertIn('player.ready = FALSE', ticker)

    def test_menu_filters_and_link_inventory_preserved(self):
        for (path, name), expected in MENU_SHAS.items():
            with self.subTest(menu=name):
                source = (ROOT / path).read_text()
                body = procedure(source, "/mob/new_player/proc/" + name)
                lines = body.splitlines()
                links = 0
                inventories = 0
                for i, line in enumerate(lines):
                    if "dat +=" in line and ";SelectedJob=" in line:
                        links += 1
                        added = lines[i + 1]
                        self.assertEqual(len(line) - len(line.lstrip()), len(added) - len(added.lstrip()))
                        self.assertIn('join_jobs |= "Company Member"' if ";SelectedJob=Company Member" in line else "join_jobs |= job.title", added)
                    if "join_jobs |=" in line:
                        inventories += 1
                self.assertEqual(links, inventories)
                restored = "\n".join(line for line in lines if "var/list/join_jobs" not in line and "join_jobs |=" not in line)
                restored = restored.replace("show_latechoices_window(dat, join_jobs)", "show_latechoices_window(dat)")
                restored = restored.replace('\tif (!lobby_join_validation)\n\t\tsrc << browse(null, "window=latechoices")', '\tsrc << browse(null, "window=latechoices")')
                restored = restored.replace('\tif (lobby_join_validation)\n\t\treturn show_latechoices_window(dat)\n\n', "")
                self.assertEqual(digest(restored), expected)

    def test_typed_and_button_share_request_owner(self):
        source = (ROOT / "code/game/mob/new_player/new_player.dm").read_text()
        topic = procedure(source, "/mob/new_player/Topic(")
        verb = procedure(source, "/client/verb/Join()")
        native = procedure(source, "/mob/new_player/proc/native_join_round()")
        self.assertIn("return handle_lobby_join(href_list)", topic)
        self.assertIn("N.native_join_round()", verb)
        self.assertIn("usr.client != src || mob != usr", verb)
        self.assertIn("!istype(mob, /mob/new_player)", verb)
        self.assertNotIn('/mob/new_player/verb/Join()', source)
        self.assertIn("handle_lobby_join(join_request, TRUE)", native)
        self.assertNotIn("AttemptLateSpawn", verb)
        self.assertNotIn("Topic(", verb)
        owner = procedure(source, "/mob/new_player/proc/handle_lobby_join(")
        self.assertIn("lobby_join_active || src != usr", owner)
        self.assertEqual(owner.count("clear_lobby_join()"), 2)
        for field in ("lobby_join_active", "lobby_join_client", "lobby_join_native", "lobby_join_selected"):
            self.assertIn('"' + field + '"', procedure(source, "/mob/new_player/persistence_runtime_var("))

    def test_native_selection_reenters_admission_after_wait(self):
        source = (ROOT / "code/game/mob/new_player/late_choices_helpers.dm").read_text()
        body = procedure(source, "/mob/new_player/proc/show_latechoices_window(")
        wait = body.index("var/selected_job = WWinput(")
        resume = body[wait:body.index('\tvar/data = ""')]
        self.assertIn("!selected_job || !lobby_join_current()", resume)
        self.assertIn("join_request[join_mode] = 1", resume)
        self.assertIn("return process_lobby_join(join_request)", resume)
        self.assertIn("!(selected_job in join_jobs)", body[:wait])
        self.assertNotIn("AttemptLateSpawn", body)


if __name__ == "__main__":
    unittest.main()
