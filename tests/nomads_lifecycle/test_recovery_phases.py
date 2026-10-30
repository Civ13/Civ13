"""Offline source-bound ordering controls; not native recovery evidence."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def ordered(source, *tokens):
    position = 0
    for token in tokens:
        position = source.index(token, position) + len(token)


class RecoveryPhases(unittest.TestCase):
    def test_save_and_post_marker_validation_order(self):
        save = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        tx = (ROOT / 'code/modules/persistence/restart_transaction.dm').read_text()
        ordered(save, 'operation.diagnostic_phase = "capture"',
                'operation.diagnostic_phase = "candidate_validation"', 'validate_captured_world_save(round_state)',
                'operation.diagnostic_phase = "write_marker"', 'text2file(generation,"map_saves/save_complete.txt")')
        body = tx.split('/datum/persistence_restart_transaction/proc/execute(', 1)[1].split('/datum/persistence_restart_transaction/proc/resume_startup()', 1)[0]
        sequence = ('diagnostic_phase = "save"', 'save_generation()',
                    'diagnostic_phase = "post_save_validation"', 'current_identity()',
                    'diagnostic_phase = "intent_publication"', 'publish(I)',
                    'diagnostic_phase = "final_validation"', 'matches(I, current_identity())',
                    'request_shutdown(expected_persistence)')
        ordered(body, *sequence)
        with self.assertRaises(ValueError):
            ordered(body.replace('diagnostic_phase = "post_save_validation"', '', 1), *sequence)

    def test_restore_retains_guard_and_player_readiness_order(self):
        tx = (ROOT / 'code/modules/persistence/restart_transaction.dm').read_text().split('/datum/persistence_restart_transaction/proc/resume_startup()', 1)[1]
        ordered(tx, 'diagnostic_phase = "restore_preflight"', 'if(import_started && !import_complete)',
                'diagnostic_phase = "restore"', 'load_generation(I)', 'import_complete = TRUE',
                'diagnostic_phase = "consume_intent"', 'consume(I)', 'diagnostic_phase = "players"',
                'players_ready = map_storage.finish_player_restoration()',
                'diagnostic_phase = players_ready ? "complete" : "readiness_unconfirmed"',
                'catch(var/exception/e)', 'diagnostic_phase = "failed"', 'persistence_save_in_progress = TRUE')
        load = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        ordered(load, 'operation.diagnostic_phase = "preflight"', 'storage.prepare_saved_dimensions(expected_intent, operation)',
                'operation.diagnostic_phase = "restore"', 'storage.ClearMap()',
                'operation.diagnostic_phase = "metadata"', 'storage.restore_durable_world()')


if __name__ == '__main__':
    unittest.main()
