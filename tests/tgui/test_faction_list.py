"""Faction List source contracts and guard projections; no native DM execution."""
from pathlib import Path
import re
import unittest
import reader_base
ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/mob/groups/factions.dm').read_text()
VERB = SOURCE.split('/mob/proc/faction_list()', 1)[1].split('/mob/proc/show_faction_list()', 1)[0]
OPEN = SOURCE.split('/mob/proc/show_faction_list()', 1)[1].split('/datum/topic_state/reader/faction_list/reader_allowed', 1)[0]
TALLY = SOURCE.split('/obj/map_metadata/proc/faction_list_tally()', 1)[1].split('/mob/proc/show_faction_list()', 1)[0] if '/obj/map_metadata/proc/faction_list_tally()' in SOURCE else OPEN
RULE = reader_base.rule(SOURCE, 'faction_list')
UPDATE = reader_base.UPDATE

class FactionListContract(unittest.TestCase):
    def test_identity_and_mode_guard_precede_tally_and_resource_delivery(self):
        for marker in ('set name = "Check Faction List"', 'set category = "Faction"', 'set src = usr', 'usr != src'):
            self.assertIn(marker, VERB)
        self.assertLess(VERB.index('usr != src'), VERB.index('show_faction_list()'))
        self.assertIn('if (!client || !map || !map.civilizations)', OPEN)
        self.assertLess(OPEN.index('!map.civilizations'), OPEN.index('map.facl = map.faction_list_tally()'))

    def test_seeds_unique_founded_then_preset_clans_and_counts_all_living_humans(self):
        self.assertIn('map.facl = map.faction_list_tally()', OPEN)
        self.assertIn('if (map.facl[relf] > 0)', OPEN)
        seeds = re.findall(r'for \(var/faction in (custom_\w+)\)\n\s+counts\[faction\] = 0', TALLY)
        self.assertEqual(seeds, ['custom_faction_nr', 'custom_civs'])
        self.assertIn('for (var/mob/living/human/H in human_mob_list)', TALLY)
        self.assertIn('if (H.stat != DEAD && !isnull(counts[faction]))', TALLY)
        self.assertIn('counts[faction] += 1', TALLY)
        self.assertNotRegex(TALLY, r'H\.(?:client|ckey)|sort|custom_\w+\[[^]]+\]\s*=')

        registries = {'custom_faction_nr': ['Founders', 'Mixed'],
                      'custom_civs': ['Orc Horde', 'Mixed', 'Empty']}
        tally = {faction: 0 for registry in seeds for faction in registries[registry]}
        humans = [('Orc Horde', 0), ('Orc Horde', 1), ('Orc Horde', 2),
                  ('Mixed', 0), ('Founders', 0), ('Unregistered', 0)]
        for faction, stat in humans:
            if stat != 2 and faction in tally:
                tally[faction] += 1
        self.assertEqual(list(tally.items()), [('Founders', 1), ('Mixed', 1), ('Orc Horde', 2), ('Empty', 0)])
        self.assertEqual([faction for faction, members in tally.items() if members],
                         ['Founders', 'Mixed', 'Orc Horde'])

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
        # The shared guard binds the window to its owner; this window adds the mode rule.
        self.assertEqual(RULE, 'map && map.civilizations')
        self.assertIn('var/datum/topic_state/reader/faction_list/reader_state = new(user, user)', OPEN)
        allowed = reader_base.allowed
        for kind in ('human', 'observer', 'dead owner'):
            owner = object()
            self.assertTrue(allowed(owner, owner, owner, owner), kind)
            self.assertFalse(allowed(owner, object(), owner, owner), kind)
            self.assertFalse(allowed(owner, owner, owner, owner, connected=False), kind)
            self.assertFalse(allowed(owner, owner, owner, owner, rule=False), kind)
        self.assertFalse(allowed(None, None, None, None))
        self.assertNotRegex(RULE, r'ishuman|isliving|stat|shared_nano_interaction|civilization ==')

    def test_close_noninterference_and_status_only_refresh_do_not_retally_or_resend(self):
        for marker in ('ui.use_on_close_logic(FALSE)', 'ui.open()', '_state = reader_state', 'var/mob/user = src', 'var/ui_key = "faction_list"'):
            self.assertIn(marker, OPEN)
        self.assertLess(OPEN.index('ui.use_on_close_logic(FALSE)'), OPEN.index('ui.open()'))
        for marker in ('!user || !src_object || !state', 'close()', 'push_data(null, TRUE)'):
            self.assertIn(marker, UPDATE)
        self.assertLess(UPDATE.index('close()'), UPDATE.index('push_data(null, TRUE)'))
        self.assertIn('new /datum/nanoui/tgui/snapshot(user, src, ui_key,', OPEN)
        self.assertNotRegex(OPEN + UPDATE, r'set_using_object|unset_using_object|set_auto_update|spawn\(')
        self.assertNotRegex(UPDATE, r'map\.|browse_rsc|show_faction_list\(')

    def test_classic_modern_are_read_only_and_ci_tracks_producer_and_compiler(self):
        # One renderer: there is no classic template to keep in step.
        self.assertFalse((ROOT / 'UI/templates').exists())
        modern = (ROOT / 'tgui/src/interfaces/FactionList.tsx').read_text()
        for source in (modern,):
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
