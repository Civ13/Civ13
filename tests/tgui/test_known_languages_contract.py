"""Source-boundary contracts for the new reader; no DM/native execution."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
LANGUAGE = (ROOT / 'code/game/mob/language/language.dm').read_text()
DATA = LANGUAGE.split('/mob/proc/known_languages_ui_data()', 1)[1].split('/mob/proc/show_known_languages()', 1)[0]
READER = LANGUAGE.split('/mob/proc/show_known_languages()', 1)[1].split('/mob/living/Topic', 1)[0]

class KnownLanguagesContract(unittest.TestCase):
    def test_filter_hidden_languages_before_serializing_and_escape_classic_data(self):
        self.assertLess(DATA.index('if (L.flags & NONGLOBAL)'), DATA.index('entries += '))
        for field in ('html_encode(L.name)', 'html_encode(L.desc)', 'html_encode("[get_language_prefix()][L.key]")', 'html_encode(current_default.name)'):
            self.assertIn(field, DATA)
        self.assertIn('living_user.default_language', DATA)
        self.assertIn('"is_default" = (L == current_default)', DATA)

    def test_owner_only_read_only_state_preserves_observer_access(self):
        state = (ROOT / 'code/modules/nano/interaction/self.dm').read_text().split('/datum/topic_state/self_read_only/can_use_topic', 1)[1]
        self.assertIn('src_object != user || !user || !user.client', state)
        self.assertIn('return STATUS_CLOSE', state)
        self.assertIn('return STATUS_UPDATE', state)
        self.assertNotIn('shared_nano_interaction', state)
        self.assertNotIn('incapacitated()', state)

    def test_reuses_adapter_manager_and_real_classic_fallback(self):
        self.assertIn('GLOB.nanomanager.try_update_ui(user, src, ui_key, null, data, TRUE)', READER)
        self.assertIn('new /datum/nanoui/tgui/known_languages(user, src, ui_key, "known_languages.tmpl"', READER)
        self.assertIn('_state = self_read_only_state', READER)
        fallback = (ROOT / 'UI/templates/known_languages.tmpl').read_text()
        self.assertIn('{{:value.name}}', fallback)
        self.assertIn('{{:value.description}}', fallback)
        assets = (ROOT / 'code/modules/client/asset_cache.dm').read_text()
        self.assertIn('"UI/templates/"', assets)
        allowed = (ROOT / 'code/modules/nano/tgui.dm').read_text().split('/datum/nanoui/tgui/proc/allowed_actions()', 1)[1].split('/datum/nanoui/tgui/Topic', 1)[0]
        self.assertNotIn('known_languages.tmpl', allowed)
        self.assertIn('return list()', allowed)

    def test_refresh_routes_back_to_reader_without_persistent_or_movement_state(self):
        self.assertIn('/datum/nanoui/tgui/known_languages/update', READER)
        self.assertIn('src_object != user || !state', READER)
        self.assertIn('user.known_languages_ui_data()', READER)
        self.assertIn('push_data(data)', READER)
        for mutation in ('set_using_object', 'using_object =', 'canmove =', 'set_auto_update', 'set_default_language', '/mob/ui_interact'):
            self.assertNotIn(mutation, DATA + READER)

    def test_native_close_does_not_clear_an_unrelated_machine_interaction(self):
        # Follow the real close callback's gate: ui.close() still runs, but the
        # no-ref branch must not reach mob.unset_using_object() for this reader.
        opening = READER.split('// Keep manager-requested refreshes', 1)[0]
        self.assertIn('ui.use_on_close_logic(FALSE)', opening)
        self.assertLess(opening.index('ui.use_on_close_logic(FALSE)'), opening.index('ui.open()'))
        nanoui = (ROOT / 'code/modules/nano/_nanoui.dm').read_text()
        setter = nanoui.split('/datum/nanoui/proc/use_on_close_logic(state)', 1)[1].split('/datum/nanoui/proc/', 1)[0]
        self.assertIn('on_close_logic = state', setter)
        external = (ROOT / 'code/modules/nano/nanoexternal.dm').read_text()
        native_close = external.split('/client/verb/nanoclose', 1)[1].split('/atom/movable/', 1)[0]
        self.assertLess(native_close.index('ui.close()'), native_close.index('else if (ui.on_close_logic)'))
        self.assertRegex(native_close, r'else if \(ui\.on_close_logic\)[\s\S]*mob\.unset_using_object\(\)')
        close = nanoui.split('/datum/nanoui/proc/close()', 1)[1].split('/datum/nanoui/proc/', 1)[0]
        self.assertIn('GLOB.nanomanager.ui_closed(src)', close)
        self.assertNotIn('unset_using_object', close)

if __name__ == '__main__':
    unittest.main()
