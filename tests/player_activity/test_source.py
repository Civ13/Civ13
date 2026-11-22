"""Source checks for the player activity recorder wiring.

The recorder is off by default, writes only ckey-level account keys, and is
fed from the existing choke points: client join and leave, region travel
depart/arrive/refusal, the death hook, world save notices and reboot.
"""
import pathlib
import re
import unittest

ROOT = pathlib.Path(__file__).resolve().parents[2]
SOURCE = 'code/modules/player_activity/player_activity.dm'


def read(path):
    return (ROOT / path).read_text(encoding='utf-8')


class PlayerActivityWiring(unittest.TestCase):
    def setUp(self):
        self.source = read(SOURCE)

    def test_included(self):
        self.assertIn('#include "code\\modules\\player_activity\\player_activity.dm"', read('civ13.dme'))

    def test_off_by_default(self):
        config = read('code/datums/configuration.dm')
        self.assertIn('var/player_activity = FALSE', config)
        self.assertIn('config.player_activity = text2num(value) == 1', config)
        self.assertIn('#PLAYER_ACTIVITY 1', read('config/config.txt'))

    def test_join_notice_only_when_on(self):
        motd = read('code/game/mob/motd.dm')
        notice = motd.split('if (config.player_activity)', 1)[1].split('//to_chat', 1)[0]
        self.assertIn('No chat, IP addresses or positions are recorded', notice)
        self.assertNotIn('magic', notice.lower())

    def test_client_join_and_leave(self):
        client = read('code/modules/client/client_procs.dm')
        self.assertIn('player_activity.session_start(src)', client)
        self.assertIn('player_activity.session_end(src)', client)

    def test_travel_choke_points(self):
        travel = read('code/modules/persistence/region_travel.dm')
        self.assertIn('player_activity.depart(H, destination, payload)', travel)
        self.assertIn('player_activity.arrive(P, incoming)', travel)
        self.assertIn('player_activity.travel_refused(H, destination, result)', travel)

    def test_save_and_reboot(self):
        # Persistence fixtures build without this module, so the save notice
        # reaches it only through text2path.
        functions = read('code/modules/persistence/functions.dm')
        self.assertIn('text2path("/proc/player_activity_world_save")', functions)
        self.assertNotIn('player_activity.', functions)
        self.assertEqual(read('code/world.dm').count('player_activity.world_stopping("restart")'), 2)

    def test_hooks_return_true(self):
        for hook in ('/hook/death/proc/player_activity_death',):
            body = self.source.split(hook, 1)[1].split('\n/', 1)[0]
            self.assertIn('return TRUE', body)

    def test_no_private_identifiers(self):
        code = '\n'.join(line for line in self.source.splitlines() if not line.lstrip().startswith('//'))
        for forbidden in ('public_address', 'computer_id', 'address', 'real_name', '.x,', 'message', 'msg'):
            self.assertNotIn(forbidden, code, forbidden)

    def test_no_new_mob_vars(self):
        # Mob vars would be written by the world save and carried by every NPC.
        self.assertIsNone(re.search(r'^/mob[^\n]*/var/', self.source, re.M))

    def test_not_under_logs(self):
        # The getlogs verb hands out data/logs to every admin.
        self.assertIn('#define PLAYER_ACTIVITY_DIR "data/player_activity/"', self.source)

    def test_runs_as_a_process(self):
        process = read('code/processes/player_activity.dm')
        self.assertIn('/process/player_activity/fire()', process)
        self.assertIn('#include "code\\processes\\player_activity.dm"', read('civ13.dme'))
        self.assertNotIn('spawn', self.source)

    def test_bounded_buffer(self):
        self.assertIn('#define PLAYER_ACTIVITY_MAX_LINES 2000', self.source)


if __name__ == '__main__':
    unittest.main()


class ProgressWiring(unittest.TestCase):
    def test_hooks(self):
        expected = {
            'code/modules/research_tree/character_knowledge.dm': 'player_activity.node_learned(src, node_id)',
            'code/modules/research_tree/research_faction.dm': 'player_activity.node_done(faction, node_id,',
            'code/game/mob/groups/faction_membership.dm': 'player_activity.faction_event(src, "faction_join", faction)',
            'code/game/mob/groups/factions.dm': 'player_activity.faction_event(src, "faction_leave", civilization)',
            'code/game/mob/groups/faction_creation.dm': 'player_activity.faction_event(owner, "faction_found", newname)',
            'code/game/objects/items/stacks/stack.dm': 'player_activity.crafted(H, recipe.result_type)',
            'code/modules/research_tree/recipe_gates.dm': 'player_activity.research_wall(H, node_id)',
            'code/modules/client/player_tutorial.dm': 'player_activity.tutorial_step(owner, step_id)',
        }
        for path, call in expected.items():
            self.assertIn(call, read(path), path)

    def test_learn_records_only_new_nodes(self):
        body = read('code/modules/research_tree/character_knowledge.dm').split('/mob/living/human/proc/learn_recipe_node(node_id)', 1)[1].split('\n/', 1)[0]
        self.assertLess(body.index('var/is_new = !(node_id in known_recipe_nodes)'), body.index('known_recipe_nodes |= node_id'))


class HiddenContentStaysOut(unittest.TestCase):
    """Ids are written by name, so the sources they come from must hold nothing hidden."""

    HIDDEN = ('code/modules/magic', 'code/modules/divine')

    def hidden_types(self):
        types = set()
        for folder in self.HIDDEN:
            for path in (ROOT / folder).rglob('*.dm'):
                for match in re.finditer(r'^(/(?:obj|mob)/[A-Za-z0-9_/]+)', path.read_text(encoding='utf-8', errors='replace'), re.M):
                    types.add(match.group(1).split('/proc')[0].split('/verb')[0])
        return types

    def test_crafting_recipes_hold_no_hidden_types(self):
        hidden = self.hidden_types()
        self.assertTrue(hidden)
        recipes = '\n'.join(p.read_text(encoding='utf-8', errors='replace') for p in (ROOT / 'config/crafting').iterdir() if p.is_file())
        found = sorted(t for t in hidden if re.search(re.escape(t) + r'(?![A-Za-z0-9_/])', recipes))
        # A type also defined outside the hidden modules (/obj/item/weapon/book) is ordinary.
        ordinary = set()
        pattern = re.compile(r'^(/(?:obj|mob)/[A-Za-z0-9_/]+)', re.M)
        for path in (ROOT / 'code').rglob('*.dm'):
            if any(str(path).startswith(str(ROOT / folder)) for folder in self.HIDDEN):
                continue
            for match in pattern.finditer(path.read_text(encoding='utf-8', errors='replace')):
                ordinary.add(match.group(1))
        self.assertEqual([t for t in found if t not in ordinary], [])

    def test_research_nodes_hold_nothing_hidden(self):
        nodes = read('code/modules/research_tree/research_node.dm').lower()
        for word in ('magic', 'spell', 'wand', 'shrine', 'divine'):
            self.assertNotIn(word, nodes)
        for folder in self.HIDDEN:
            for path in (ROOT / folder).rglob('*.dm'):
                text = path.read_text(encoding='utf-8', errors='replace')
                self.assertNotIn('register_research_node', text, path)
                self.assertNotIn('learn_recipe_node', text, path)
                self.assertNotIn('player_activity', text, path)


class FeatureWiring(unittest.TestCase):
    def test_feature_counters(self):
        expected = {
            'code/game/mob/crafting_atlas.dm': 'player_activity.feature_used(src, "atlas")',
            'code/modules/1713/movement_check.dm': 'player_activity.feature_used(src, "check_movement")',
            'code/game/mob/player_help.dm': 'player_activity.feature_used(C, "player_help")',
            'code/game/objects/items/stacks/crafting_window.dm': 'player_activity.feature_used(src, "crafting_within_reach")',
            'code/modules/1713/click_route.dm': 'player_activity.feature_used(src, "click_route")',
            'code/game/objects/structures/tree_climbing.dm': 'player_activity.feature_used(src, "tree_climb")',
            'code/modules/bug_reports/bug_reports.dm': 'player_activity.feature_used(src, "bug_report")',
            'code/modules/1713/signal_fires.dm': 'player_activity.feature_used(user, "signal_fire")',
            'code/modules/voice/voice_chat.dm': 'player_activity.feature_used(C, "voice")',
            'code/modules/naval/ship_voyage.dm': 'player_activity.voyage(H, kind)',
        }
        for path, call in expected.items():
            self.assertIn(call, read(path), path)

    def test_help_outcomes_without_question_text(self):
        source = read('code/game/mob/player_help.dm')
        for outcome in ('ok', 'rate_limited', 'busy', 'failed', 'timeout'):
            self.assertIn('player_activity.help_outcome(C, "%s")' % outcome, source)
        for line in source.splitlines():
            if 'player_activity.' in line:
                self.assertNotIn('question', line)
                self.assertNotIn('answer', line)
