"""Source contracts for the DM side of transfer storage. Never launches BYOND.

The design (tools/server-management/TRANSFER-STORAGE-SQLITE.md) needs the
world save to list the transfer effects it contains, report them only after the
completion marker, and reconcile on load. These checks keep that ordering and
the default-off configuration honest.
"""
import os
import re
import unittest

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))


def read(path):
    with open(os.path.join(ROOT, path), encoding='utf-8-sig') as f:
        return f.read().replace('\r\n', '\n')


def proc(source, name):
    start = source.index('\n' + name + '(') + 1
    # The next top-level definition ends the proc; preprocessor lines do not.
    end = re.search(r'\n(?=[^\s#])', source[start + 1:])
    return source[start:start + 1 + end.start()] if end else source[start:]


SAVING = read('code/modules/persistence/saving.dm')
LOADING = read('code/modules/persistence/loading.dm')
FUNCTIONS = read('code/modules/persistence/functions.dm')
BRIDGE = read('code/modules/persistence/transfer_bridge.dm')
DME = read('civ13.dme')


class SaveOrdering(unittest.TestCase):
    def test_capture_is_written_with_round_state_and_reported_after_the_marker(self):
        capture = SAVING.index('var/list/transfer_capture = transfer_capture(generation)')
        stored = SAVING.index('round_state["transfer"] = transfer_capture')
        written = SAVING.index('text2file(json_encode(round_state), "map_saves/round.json")')
        marker = SAVING.index('text2file(generation,"map_saves/save_complete.txt")')
        report = SAVING.index('transfer_saved(transfer_capture)')
        self.assertLess(SAVING.index('operation.diagnostic_phase = "write_marker"'), capture)
        self.assertLess(capture, stored)
        self.assertLess(stored, written)
        self.assertLess(written, marker)
        self.assertLess(marker, report)
        self.assertEqual(SAVING.count('transfer_saved('), 1)

    def test_load_reports_after_the_world_is_restored(self):
        body = proc(LOADING, '/map_storage/proc/load_world_contents')
        self.assertLess(body.index('restore_level_links()'), body.index('transfer_loaded(transfer_round_state)'))
        self.assertLess(body.index('transfer_loaded(transfer_round_state)'), body.index('log_startup_progress("Finished loading.")'))
        # An unreadable round state must not abort a load that already succeeded.
        self.assertIn('try\n\t\ttransfer_round_state = read_round_state()\n\tcatch', body)


class RoundState(unittest.TestCase):
    def test_transfer_key_is_counted_and_validated(self):
        body = proc(FUNCTIONS, '/map_storage/proc/read_round_state')
        self.assertIn('has_transfer = islist(state) && ("transfer" in state)', body)
        self.assertIn('+ has_debug_recovery + has_transfer', body)
        self.assertIn('if(has_transfer && !valid_transfer_capture(state["transfer"])) throw EXCEPTION', body)

    def test_validator_bounds(self):
        body = proc(FUNCTIONS, '/proc/valid_transfer_capture')
        for needle in ('capture.len != 3', '"generation" in capture', '"effects" in capture', '"ledger_seq" in capture',
                       'length(generation) > 128', 'seq != round(seq)', 'seq > 1e12', 'effects.len > 256',
                       'length(effect) > 96'):
            self.assertIn(needle, body)

    def test_fixtures_get_inert_stubs(self):
        self.assertEqual(proc(FUNCTIONS, '/map_storage/proc/transfer_capture').strip().splitlines()[-1].strip(), 'return null')
        for name in ('transfer_saved', 'transfer_loaded'):
            self.assertEqual(proc(FUNCTIONS, '/map_storage/proc/' + name).strip().splitlines()[-1].strip(), 'return')


class Bridge(unittest.TestCase):
    def test_overrides_load_after_the_stubs(self):
        includes = [line for line in DME.splitlines() if line.startswith('#include')]
        bridge = includes.index('#include "code\\modules\\persistence\\transfer_bridge.dm"')
        self.assertGreater(bridge, includes.index('#include "code\\modules\\persistence\\functions.dm"'))
        self.assertGreater(bridge, includes.index('#include "code\\modules\\persistence\\saving.dm"'))

    def test_off_unless_configured(self):
        new = proc(BRIDGE, '/datum/transfer_bridge/New')
        self.assertIn('if(!fexists("config/transfer_agent.json")) return', new)
        self.assertIn('length(secret) < 32', new)
        self.assertLess(new.index('length(secret) < 32'), new.index('port = settings["port"]'))
        self.assertIn('return port && token', proc(BRIDGE, '/datum/transfer_bridge/proc/enabled'))
        self.assertIn('"http://127.0.0.1:[port][path]"', proc(BRIDGE, '/datum/transfer_bridge/proc/request'))

    def test_effects_refused_during_saves_and_before_reconcile(self):
        body = proc(BRIDGE, '/datum/transfer_bridge/proc/begin_effect')
        self.assertIn('if(!ready() || persistence_save_active()) return null', body)
        # Checked again after the request returns, before the effect is recorded.
        self.assertEqual(body.count('persistence_save_active()'), 2)
        self.assertLess(body.rindex('persistence_save_active()'), body.index('applied += result["effect_id"]'))
        self.assertIn('!isnull(ledger_base) && !hold_reason', proc(BRIDGE, '/datum/transfer_bridge/proc/ready'))

    def test_unreconciled_saves_repeat_the_loaded_capture(self):
        body = proc(BRIDGE, '/datum/transfer_bridge/proc/capture')
        self.assertLess(body.index('if(isnull(ledger_base))'), body.index('loaded_capture.Copy()'))
        saved = proc(BRIDGE, '/datum/transfer_bridge/proc/saved')
        self.assertEqual(saved.splitlines()[1].strip(), 'set waitfor = FALSE')
        self.assertIn('if(isnull(ledger_base) || capture["ledger_seq"] > ledger_base) return', saved)


if __name__ == '__main__':
    unittest.main()
