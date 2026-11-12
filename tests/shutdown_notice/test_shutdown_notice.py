"""Planned shutdown notices (code/modules/persistence/shutdown_notice.dm): source wiring.

The native countdown probe is developer evidence, outside the offline suite (it runs for
about 40 seconds): python3 tests/shutdown_notice/run.py
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def read(relative):
    return (ROOT / relative).read_text(encoding='utf-8')


class ShutdownNoticeSources(unittest.TestCase):
    def test_module_is_compiled_and_the_cancel_verb_is_offered(self):
        self.assertIn('#include "code\\modules\\persistence\\shutdown_notice.dm"', read('civ13.dme'))
        self.assertIn('/datum/admins/proc/cancel_planned_shutdown,', read('code/modules/admin/admin_verbs.dm'))

    def test_transaction_counts_down_through_a_runtime_hook(self):
        # The standalone transaction fixture compiles without shutdown_notice.dm.
        transaction = read('code/modules/persistence/restart_transaction.dm')
        self.assertNotIn('planned_shutdown_countdown(', transaction.replace('"/proc/planned_shutdown_countdown"', ''))
        self.assertIn('text2path("/proc/planned_shutdown_countdown")', transaction)
        self.assertIn('if(called_off) throw EXCEPTION(', transaction)
        self.assertIn('text2path("/proc/planned_shutdown_clear")', transaction)

    def test_lifecycle_takes_an_optional_bounded_warning(self):
        lifecycle = read('code/modules/persistence/nomads_lifecycle.dm')
        self.assertIn('if((action == "save_shutdown" || action == "handover_save") && ("warn" in input)) allowed += "warn"', lifecycle)
        self.assertIn('requested_warning < 0 || requested_warning > 3600', lifecycle)
        self.assertIn('"shutdown_warning" = TRUE, "shutdown_in" = planned_shutdown_remaining()', lifecycle)

    def test_every_planned_restart_path_uses_the_countdown(self):
        self.assertIn('planned_shutdown_countdown("reboot", delay, "restart by an admin")', read('code/modules/admin/admin.dm'))
        self.assertIn('planned_shutdown_countdown("reboot", 0, "immediate reboot by an admin")', read('code/modules/admin/admin.dm'))
        self.assertIn('planned_shutdown_countdown("restart", 300, "scheduled maintenance reboot")', read('code/world.dm'))
        self.assertIn('planned_shutdown_countdown("reboot", delay,', read('code/modules/agent_control/agent_actions.dm'))
        self.assertIn('warn_seconds = warn_seconds)', read('code/modules/persistence/admin.dm'))
        self.assertIn('planned_shutdown_status_text()', read('code/game/mob/mob.dm'))


if __name__ == '__main__':
    unittest.main()
