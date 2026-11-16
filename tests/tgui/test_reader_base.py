"""Read-only window base contracts; no DM/native execution."""
import unittest
import reader_base as base


class ReaderBaseContract(unittest.TestCase):
    def test_guard_binds_subject_reader_connection_and_the_window_rule(self):
        subject, owner, other = object(), object(), object()
        self.assertTrue(base.allowed(subject, subject, owner, owner))
        self.assertFalse(base.allowed(subject, other, owner, owner))
        self.assertFalse(base.allowed(subject, subject, other, owner))
        self.assertFalse(base.allowed(subject, subject, None, None))
        self.assertFalse(base.allowed(None, None, owner, owner))
        self.assertFalse(base.allowed(subject, subject, owner, owner, connected=False))
        self.assertFalse(base.allowed(subject, subject, owner, owner, rule=False))
        self.assertIn('return granted_status', base.STATE)
        self.assertIn('var/granted_status = STATUS_UPDATE', base.BASE)
        # An opened snapshot stays readable while walking away and for any kind of body.
        self.assertNotRegex(base.STATE, r'get_dist|Adjacent|in_range|ishuman|isliving|shared_nano_interaction|\bstat\b')

    def test_guard_checks_the_connection_before_running_a_window_rule(self):
        self.assertLess(base.STATE.index('!user.client'), base.STATE.index('reader_allowed(user)'))
        self.assertLess(base.STATE.index('user != reader'), base.STATE.index('reader_allowed(user)'))

    def test_refresh_is_status_only_and_never_collects_data(self):
        for marker in ('!user || !src_object || !state', 'close()', 'push_data(null, TRUE)', 'update_status(FALSE)'):
            self.assertIn(marker, base.UPDATE)
        self.assertLess(base.UPDATE.index('close()'), base.UPDATE.index('push_data(null, TRUE)'))
        self.assertNotRegex(base.UPDATE, r'ui_interact|set_initial_data|initial_data|spawn\(|set_auto_update|browse_rsc|send_rsc')

    def test_fixed_classic_page_is_guarded_and_cleared_once_on_close(self):
        self.assertLess(base.GET_HTML.index('STATUS_CLOSE'), base.GET_HTML.index('return legacy_snapshot'))
        self.assertIn('return ""', base.GET_HTML)
        for marker in ('if (reader_closed)', 'reader_closed = TRUE', 'legacy_snapshot = null', 'return ..()'):
            self.assertIn(marker, base.CLOSE)
        self.assertLess(base.CLOSE.index('legacy_snapshot = null'), base.CLOSE.index('return ..()'))

    def test_reopen_replaces_a_window_of_another_type_or_binding(self):
        for marker in ('GLOB.nanomanager.get_open_ui(user, subject, ui_key)', '!istype(ui, ui_type)', '!istype(old_state, state_type)', '!old_state.bound_to(subject, user)', 'ui.close()', 'return null'):
            self.assertIn(marker, base.OPEN_READER)
        self.assertIn('return subject == expected_subject && reader == expected_reader', base.BASE)
        self.assertIn('#include "code\\modules\\nano\\tgui_reader.dm"', (base.ROOT / 'civ13.dme').read_text())


if __name__ == '__main__':
    unittest.main()
