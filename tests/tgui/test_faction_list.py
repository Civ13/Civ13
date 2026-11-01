"""Faction List source contracts and guard projections; no native DM execution."""
from pathlib import Path
import re
import unittest
ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/mob/groups/factions.dm').read_text()
VERB = SOURCE.split('/mob/proc/faction_list()', 1)[1].split('/mob/proc/show_faction_list()', 1)[0]
OPEN = SOURCE.split('/mob/proc/show_faction_list()', 1)[1].split('/datum/nanoui/tgui/faction_list/update', 1)[0]
UPDATE = SOURCE.split('/datum/nanoui/tgui/faction_list/update', 1)[1].split('/datum/topic_state/faction_list/can_use_topic', 1)[0]
STATE = SOURCE.split('/datum/topic_state/faction_list/can_use_topic', 1)[1]

class FactionListContract(unittest.TestCase):
    def test_identity_and_mode_guard_precede_tally_and_resource_delivery(self):
        for marker in ('set name = "Check Faction List"', 'set category = "Faction"', 'set src = usr', 'usr != src'):
            self.assertIn(marker, VERB)
        self.assertLess(VERB.index('usr != src'), VERB.index('show_faction_list()'))
        self.assertIn('if (!client || !map || !map.civilizations)', OPEN)
        self.assertLess(OPEN.index('!map.civilizations'), OPEN.index('map.facl = list()'))

    def test_preserves_explicit_tally_and_all_non_dead_humans_without_player_or_member_filter(self):
        for marker in ('map.facl = list()', 'map.custom_faction_nr.len', 'map.facl += list(map.custom_faction_nr[i] = nu)',
                       'map.facl[relf] = 0', 'for (var/mob/living/human/H in world)',
                       'if (relf == H.civilization && H.stat != DEAD)', 'map.facl[relf] += 1', 'if (map.facl[relf] > 0)'):
            self.assertIn(marker, OPEN)
        self.assertNotIn('H.client', OPEN)
        self.assertNotIn('sort', OPEN)
        guard = re.search(r'if \((relf == H.civilization && H.stat != DEAD)\)', OPEN).group(1)
        expression = guard.replace('H.civilization', 'civilization').replace('H.stat', 'stat').replace('&&', 'and')
        for faction, stat, expected in [('A', 0, True), ('A', 1, True), ('A', 2, False), ('B', 0, False)]:
            self.assertEqual(eval(expression, {'__builtins__': {}}, dict(relf='A', civilization=faction, stat=stat, DEAD=2)), expected)

    def test_cached_custom_symbol_precedes_existing_tinted_fallback_and_delivery_precedes_open(self):
        for marker in ('map.get_faction_symbol_icon(relf)', 'if (!symbol)', 'civ_data && civ_data.len >= 7',
                       'new/icon(\'icons/obj/banners.dmi\', "b_[civ_data[6]]")', 'symbol.Blend(civ_data[7], ICON_MULTIPLY)',
                       'symbol_file = "flist_[ckey(relf)].png"', 'src << browse_rsc(symbol, symbol_file)', 'ui.open()'):
            self.assertIn(marker, OPEN)
        self.assertLess(OPEN.index('map.get_faction_symbol_icon'), OPEN.index('if (!symbol)'))
        self.assertLess(OPEN.index('src << browse_rsc'), OPEN.index('try_update_ui'))
        self.assertNotRegex(OPEN, r'bake_faction|finalize_faction|admin_reset|faction_symbol_grid')

    def test_only_existing_public_details_enter_snapshot_and_no_persistence_contract_changes(self):
        for marker in ('"name" = html_encode("[relf]")', '"motto" = map.faction_motto[relf]', '"flavour" = map.faction_flavour[relf]',
                       '"members" = map.facl[relf]', '"symbol" = symbol_file'):
            self.assertIn(marker, OPEN)
        self.assertNotRegex(OPEN, r'map\.(?!facl)\w+\s*(?:\+=|-=|=(?!=))')
        self.assertNotRegex(OPEN, r'Write\(|savefile|faction_symbol_grid|custom_civs\[[^]]+\]\s*=')

    def test_owner_state_retains_observer_and_dead_access_but_closes_stale_or_disconnected_readers(self):
        match = re.search(r'if \((.+)\)\n\t\treturn STATUS_CLOSE', STATE)
        self.assertIsNotNone(match)
        expression = match.group(1).replace('!user.client', 'not connected').replace('!map.civilizations', 'not civilizations').replace('!map', 'not has_map').replace('!user', 'not user').replace('||', 'or')
        def allowed(source, user, connected=True, has_map=True, civilizations=True):
            return not eval(expression, {'__builtins__': {}}, dict(src_object=source, user=user, connected=connected, has_map=has_map, civilizations=civilizations))
        for kind in ('human', 'observer', 'dead owner'):
            owner = object()
            self.assertTrue(allowed(owner, owner), kind)
            self.assertFalse(allowed(object(), owner), kind)
            self.assertFalse(allowed(owner, owner, connected=False), kind)
            self.assertFalse(allowed(owner, owner, has_map=False), kind)
            self.assertFalse(allowed(owner, owner, civilizations=False), kind)
        self.assertFalse(allowed(None, None))
        self.assertIn('return STATUS_UPDATE', STATE)
        self.assertNotRegex(STATE, r'STATUS_INTERACTIVE|ishuman|isliving|stat|shared_nano_interaction|civilization ==')

    def test_close_noninterference_and_status_only_refresh_do_not_retally_or_resend(self):
        for marker in ('ui.use_on_close_logic(FALSE)', 'ui.open()', '_state = reader_state', 'var/mob/user = src', 'var/ui_key = "faction_list"'):
            self.assertIn(marker, OPEN)
        self.assertLess(OPEN.index('ui.use_on_close_logic(FALSE)'), OPEN.index('ui.open()'))
        for marker in ('!user || src_object != user || !state', 'close()', 'push_data(null, TRUE)'):
            self.assertIn(marker, UPDATE)
        self.assertLess(UPDATE.index('src_object != user'), UPDATE.index('push_data(null, TRUE)'))
        self.assertNotRegex(OPEN + UPDATE, r'set_using_object|unset_using_object|set_auto_update|spawn\(')
        self.assertNotRegex(UPDATE, r'map\.|browse_rsc|show_faction_list\(')

    def test_classic_modern_are_read_only_and_ci_tracks_producer_and_compiler(self):
        classic = (ROOT / 'UI/templates/faction_list.tmpl').read_text()
        modern = (ROOT / 'tgui/src/interfaces/FactionList.tsx').read_text()
        for source in (classic, modern):
            self.assertNotRegex(source, r'href=|<input|onClick|dangerouslySetInnerHTML')
            self.assertIn('encodeURIComponent', source)
        transport = (ROOT / 'code/modules/nano/tgui.dm').read_text().split('/datum/nanoui/tgui/Topic', 1)[0]
        self.assertNotIn('faction_list.tmpl', transport)
        legacy = (ROOT / 'code/modules/nano/_nanoui.dm').read_text().split('/datum/nanoui/Topic', 1)[1]
        for marker in ('status != STATUS_INTERACTIVE', 'src_object.Topic'):
            self.assertIn(marker, legacy)
        self.assertLess(legacy.index('status != STATUS_INTERACTIVE'), legacy.index('src_object.Topic'))
        workflow = (ROOT / '.github/workflows/tgui.yml').read_text()
        for marker in ("'code/game/mob/groups/factions.dm'", "'code/game/mob/groups/faction_symbol.dm'", "'code/game/mob/groups/faction_creation.dm'", "'UI/js/libraries/doT.js'"):
            self.assertIn(marker, workflow)

if __name__ == '__main__':
    unittest.main()
