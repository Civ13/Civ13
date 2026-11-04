"""Offline checks that keep the two-region pilot tied to the real game code.

The pilot itself (pilot/run.py) needs BYOND and rust_g and runs by hand or in
the manual workflow job; these checks only read files.
"""
import importlib.util
import os
import unittest

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
_spec = importlib.util.spec_from_file_location('transfer_pilot', os.path.join(HERE, 'pilot', 'run.py'))
PILOT = importlib.util.module_from_spec(_spec)
_spec.loader.exec_module(PILOT)


def read(path):
    with open(os.path.join(ROOT, path), encoding='utf-8-sig') as f:
        return f.read()


class PilotSources(unittest.TestCase):
    def test_compiles_the_real_transfer_code(self):
        for source in PILOT.SOURCES:
            self.assertTrue(os.path.isfile(os.path.join(ROOT, source)), source)
        self.assertIn('code/modules/persistence/transfer_bridge.dm', PILOT.SOURCES)
        self.assertIn('code/modules/persistence/transfer_trade_post.dm', PILOT.SOURCES)

    def test_hooks_are_cut_from_functions_dm(self):
        hooks = PILOT.transfer_hooks()
        for proc in ('/map_storage/proc/transfer_capture(generation)', '/map_storage/proc/transfer_saved(list/capture)',
                     '/map_storage/proc/transfer_loaded(list/round_state)', '/proc/valid_transfer_capture(list/capture)'):
            self.assertIn(proc, hooks)
        self.assertNotIn('read_round_state', hooks)

    def test_world_uses_the_game_hooks_and_post_actions(self):
        world = read('tests/transfer_storage/pilot/pilot_world.dm')
        for call in ('pilot_storage.transfer_loaded(round_state)', 'pilot_storage.transfer_capture(generation)',
                     'pilot_storage.transfer_saved(capture)', 'pilot_post.ship_stack(', 'pilot_post.collect_goods(',
                     'valid_transfer_capture('):
            self.assertIn(call, world)
        # The completion marker is written after the save body, and the report after the marker.
        save = world[world.index('/proc/pilot_save()'):]
        self.assertLess(save.index('save-[n].json")'), save.index('complete-[n]")'))
        self.assertLess(save.index('complete-[n]")'), save.index('transfer_saved(capture)'))
        self.assertLess(save.index('pilot_save_active = FALSE'), save.index('transfer_saved(capture)'))

    def test_stubs_do_not_redefine_the_code_under_test(self):
        stubs = '\n'.join(line for line in read('tests/transfer_storage/pilot/stubs.dm').splitlines()
                          if not line.lstrip().startswith('//'))
        for name in ('transfer_bridge', 'transfer_trade', 'valid_transfer_capture', '/datum/http_request', 'rustg_'):
            self.assertNotIn(name, stubs)

    def test_rust_g_is_pinned(self):
        self.assertEqual(64, len(PILOT.RUST_G_SHA256['librust_g.so']))


if __name__ == '__main__':
    unittest.main()
