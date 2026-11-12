"""Planned shutdown notices (code/modules/persistence/shutdown_notice.dm).

Source checks run everywhere; the countdown probe runs when the pinned BYOND from
scripts/cloud_byond_setup.sh is installed in ~/byond-<version>.
"""
import json
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
NOTICE = ROOT / 'code/modules/persistence/shutdown_notice.dm'


def read(relative):
    return (ROOT / relative).read_text(encoding='utf-8')


def byond_bin():
    pin = json.loads(read('tools/byond/version.json'))['version']
    path = Path.home() / ('byond-' + pin) / 'byond' / 'bin'
    return path if (path / 'DreamMaker').exists() else None


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


@unittest.skipUnless(byond_bin(), 'pinned BYOND not installed (bash scripts/cloud_byond_setup.sh)')
class ShutdownNoticeProbe(unittest.TestCase):
    def test_countdown_milestones_cancel_and_discord(self):
        binp = byond_bin()
        env = dict(os.environ, LD_LIBRARY_PATH=str(binp) + ':' + os.environ.get('LD_LIBRARY_PATH', ''),
                   BYOND_SYSTEM=str(binp.parent), PATH=str(binp) + ':' + os.environ['PATH'])
        with tempfile.TemporaryDirectory(prefix='civ13-shutdown-notice-') as work:
            work = Path(work)
            shutil.copy(NOTICE, work / 'shutdown_notice.dm')
            shutil.copy(Path(__file__).with_name('probe.dm'), work / 'probe.dm')
            (work / 'probe.dme').write_text('#define R_SERVER 2\n#include "shutdown_notice.dm"\n#include "probe.dm"\n')
            built = subprocess.run(['DreamMaker', 'probe.dme'], cwd=work, env=env, capture_output=True, text=True, timeout=120)
            self.assertIn('0 errors, 0 warnings', built.stdout + built.stderr, built.stdout + built.stderr)
            subprocess.run(['DreamDaemon', 'probe.dmb', '0', '-invisible', '-close', '-trusted'], cwd=work, env=env,
                           capture_output=True, text=True, timeout=180)
            result = json.loads((work / 'result.json').read_text())
            self.assertEqual(result['failures'], 0, result['messages'])


if __name__ == '__main__':
    unittest.main()
