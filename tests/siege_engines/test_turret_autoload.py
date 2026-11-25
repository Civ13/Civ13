"""Source-level checks for the turret panel's asynchronous autoload transaction."""
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
TURRET = Path('code/modules/1713/siege/turret.dm')
CANNON = Path('code/modules/1713/siege/piece.dm')


def entry(source, name):
    return source.split(name, 1)[1].split('\n/', 1)[0]


class TurretAutoloadTest(unittest.TestCase):
    def setUp(self):
        self.source = (ROOT / TURRET).read_text(encoding='utf-8')
        self.topic = entry(self.source, '/obj/structure/turret/Topic(')

    def test_busy_guard_precedes_unload_and_delay_claim(self):
        guard = 'if (istype(A) && A.is_loading)'
        self.assertIn(guard, self.topic)
        self.assertLess(self.topic.index(guard), self.topic.index('C.loaded -= S'))
        self.assertLess(self.topic.index('A.is_loading = TRUE'), self.topic.index('finish_autoload(A, user, loadable)'))

    def test_cancelled_and_empty_attempts_share_cleanup_without_releasing_early(self):
        self.assertIn('/proc/finish_autoload(', self.source)
        finish = entry(self.source, '/proc/finish_autoload(')
        choose = entry(self.source, '/proc/choose_autoload_shell(')
        self.assertIn('var/did_load = choose_autoload_shell(cannon, actor, loadable)\n'
                      '\tif (QDELETED(cannon))\n\t\treturn\n\tcannon.is_loading = FALSE', finish)
        self.assertIn('if (!loadable.len)\n', choose)
        self.assertIn('= WWinput(actor,', choose)
        self.assertIn('if (!istype(chosen) || QDELETED(chosen) || !(chosen in loadable))\n\t\treturn FALSE', choose)
        self.assertNotIn('is_loading = FALSE', choose)

    def test_selection_rechecks_custody_before_committing_shell(self):
        self.assertIn('/proc/choose_autoload_shell(', self.source)
        choose = entry(self.source, '/proc/choose_autoload_shell(')
        expected = ('= WWinput(actor,',
                    'cannon.loaded.len >= cannon.max_loaded',
                    'rack.storage != storage || !(rack in range(1, src))',
                    'if (!chosen.persistence_set_loc(src))\n\t\treturn FALSE',
                    'cannon.loaded += chosen')
        indexes = [choose.index(anchor) for anchor in expected]
        self.assertEqual(indexes, sorted(indexes))

    def test_success_updates_existing_panel_only_after_releasing_busy_flag(self):
        self.assertIn('/proc/finish_autoload(', self.source)
        finish = entry(self.source, '/proc/finish_autoload(')
        render = entry(self.source, '/proc/do_html(')
        interact = entry(self.source, '/obj/structure/turret/ui_interact(')
        self.assertIn('if (did_load && !QDELETED(src))', finish)
        self.assertLess(finish.index('cannon.is_loading = FALSE'), finish.index('GLOB.nanomanager.update_uis(src)'))
        self.assertNotIn('do_html(', finish)
        self.assertIn('do_html(viewer, ui_key, ui, force_open)', interact)
        self.assertIn('ui_key = ui_key, ui = ui, force_open = force_open', render)

    def test_in_flight_loader_flag_is_not_persisted(self):
        cannon = (ROOT / CANNON).read_text(encoding='utf-8')
        self.assertIn('var/tmp/is_loading = FALSE', cannon)
        self.assertNotIn('var/is_loading =', cannon)


if __name__ == '__main__':
    unittest.main()
