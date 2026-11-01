"""Read-only Religion List contracts; no DM/native execution."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/game/mob/groups/religions.dm').read_text(errors='replace')
VERB = SOURCE.split('/mob/proc/religion_list()', 1)[1].split('/mob/proc/show_religion_list()', 1)[0]
OPEN = SOURCE.split('/mob/proc/show_religion_list()', 1)[1].split('/datum/nanoui/tgui/religion_list/update', 1)[0]
UPDATE = SOURCE.split('/datum/nanoui/tgui/religion_list/update', 1)[1].split('/datum/topic_state/religion_list/can_use_topic', 1)[0]
STATE = SOURCE.split('/datum/topic_state/religion_list/can_use_topic', 1)[1]


class ReligionListContract(unittest.TestCase):
    def test_verb_identity_and_mode_gate_precede_data_or_window_delivery(self):
        for marker in ('set name = "Check Religion List"', 'set category = "Faction"', 'set src = usr', 'usr != src'):
            self.assertIn(marker, VERB)
        self.assertLess(VERB.index('usr != src'), VERB.index('show_religion_list()'))
        self.assertIn('if (!client || !map || !map.civilizations)', OPEN)
        self.assertLess(OPEN.index('!map.civilizations'), OPEN.index('for (var/rel in map.custom_religions)'))

    def test_transmits_only_public_names_and_points_in_original_iteration_order(self):
        self.assertIn('for (var/rel in map.custom_religions)', OPEN)
        self.assertIn('"name" = html_encode("[rel]")', OPEN)
        self.assertIn('"points" = map.custom_religions[rel][3]', OPEN)
        self.assertNotRegex(OPEN, r'map\.custom_religions\[rel\]\[(?:1|2|4|5|6|7)\]')
        self.assertNotIn('sort', OPEN)
        self.assertNotIn('religion ==', OPEN)
        self.assertNotRegex(OPEN, r'map\.\w+\s*(?:\+=|-=|=(?!=))')

    def test_state_projection_preserves_observer_and_dead_owner_access_and_rejects_stale_owners(self):
        guard = re.search(r'if \((.+)\)\n\t\treturn STATUS_CLOSE', STATE).group(1)
        expression = guard.replace('!user.client', 'not connected').replace('!map.civilizations', 'not civilizations').replace('!map', 'not has_map').replace('!user', 'not user').replace('||', 'or')
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
        self.assertNotIn('STATUS_INTERACTIVE', STATE)
        self.assertNotRegex(STATE, r'ishuman|isliving|stat|shared_nano_interaction|religious_leader')

    def test_close_is_noninterfering_and_state_and_snapshot_are_bound_to_this_mob(self):
        for marker in ('ui.use_on_close_logic(FALSE)', 'ui.open()', '_state = reader_state', 'var/mob/user = src', 'var/ui_key = "religion_list"'):
            self.assertIn(marker, OPEN)
        self.assertLess(OPEN.index('ui.use_on_close_logic(FALSE)'), OPEN.index('ui.open()'))
        self.assertNotIn('set_using_object', OPEN)
        self.assertNotIn('unset_using_object', OPEN)
        self.assertNotIn('artillery_window', OPEN)

    def test_manager_refresh_checks_owner_and_only_sends_status_without_querying_points(self):
        for marker in ('!user || src_object != user || !state', 'close()', 'push_data(null, TRUE)'):
            self.assertIn(marker, UPDATE)
        self.assertLess(UPDATE.index('src_object != user'), UPDATE.index('push_data(null, TRUE)'))
        self.assertNotIn('map.custom_religions', UPDATE)
        self.assertNotIn('show_religion_list()', UPDATE)
        self.assertNotIn('set_auto_update', OPEN + UPDATE)
        self.assertNotIn('spawn(', OPEN + UPDATE)

    def test_both_renderers_are_read_only_and_frontend_checks_follow_source_dependencies(self):
        transport = (ROOT / 'code/modules/nano/tgui.dm').read_text()
        self.assertIn('/datum/nanoui/tgui/Topic', transport)
        self.assertNotIn('religion_list.tmpl', transport.split('/datum/nanoui/tgui/Topic', 1)[0])
        legacy = (ROOT / 'code/modules/nano/_nanoui.dm').read_text()
        self.assertIn('/datum/nanoui/Topic', legacy)
        legacy = legacy.split('/datum/nanoui/Topic', 1)[1]
        for marker in ('status != STATUS_INTERACTIVE', 'src_object.Topic'):
            self.assertIn(marker, legacy)
        self.assertLess(legacy.index('status != STATUS_INTERACTIVE'), legacy.index('src_object.Topic'))
        template = (ROOT / 'UI/templates/religion_list.tmpl').read_text()
        self.assertNotIn('href=', template)
        self.assertNotIn('<input', template)
        workflow = (ROOT / '.github/workflows/tgui.yml').read_text()
        self.assertIn("'code/game/mob/groups/religions.dm'", workflow)
        self.assertIn("'UI/js/libraries/doT.js'", workflow)


if __name__ == '__main__':
    unittest.main()
