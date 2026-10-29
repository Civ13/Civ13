"""Offline source contracts for the mode-bound maintenance lock.

These checks are not a DM compiler or runtime test. The lifecycle fixture has
separate prepared DM assertions for the lock and an ABA serialization case.
"""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]


def check_admin_guards(source):
    for name in ('persistent', 'persistent_chad'):
        marker = f'/datum/admins/proc/{name}()'
        start = source.index(marker)
        end = source.find('\n/datum/', start + len(marker))
        body = source[start:end if end != -1 else None]
        guard = body.index('if (persistence_mode_change_locked())')
        returned = body.index('\n\t\treturn', guard)
        for field in ('map.persistence =', 'map.perschadplus ='):
            for occurrence in (i for i in range(len(body)) if body.startswith(field, i)):
                # The commented historical assignment is not a writer.
                if body[body.rfind('\n', 0, occurrence) + 1:occurrence].lstrip().startswith('//'):
                    continue
                if returned >= occurrence:
                    raise AssertionError(f'{name} changes {field} before lock refusal')


class ModeLockSourceTests(unittest.TestCase):
    def test_both_admin_writers_guard_before_assignment(self):
        source = (ROOT / 'code/modules/persistence/persistence.dm').read_text()
        check_admin_guards(source)
        with self.assertRaises((AssertionError, ValueError)):
            check_admin_guards(source.replace('if (persistence_mode_change_locked())', 'if (FALSE)', 1))

    def test_bound_reservation_covers_zero_and_one(self):
        source = (ROOT / 'code/modules/persistence/nomads_lifecycle.dm').read_text()
        self.assertIn('nomads_lifecycle.busy && !isnull(nomads_lifecycle.expected_persistence)', source)
        self.assertLess(source.index('expected_persistence = ("expected_persistence" in input)'),
                        source.index('busy = TRUE // Reserve'))
        self.assertLess(source.index('busy = FALSE\n\texpected_persistence = null'), len(source))

    def test_saved_metadata_checked_before_restart_intent(self):
        source = (ROOT / 'code/modules/persistence/restart_transaction.dm').read_text()
        self.assertIn('map_storage.round_mode_metadata(splittext(file2text("map_saves/map.txt"), "\\n"))', source)
        self.assertIn('modes.len != 4', source)
        self.assertIn('modes["persistence"] || modes["perschadplus"] || (config && config.allowedgamemodes == "PERSISTENCE")', source)
        save = source.index('if(!save_generation())')
        check = source.index('expected_persistence != saved_persistence_mode()', save)
        self.assertLess(check, source.index('publish(I)', check))
        fixture = (ROOT / 'tests/world_save/lifecycle_probe.dm').read_text()
        self.assertIn('T.aba_mode_during_save = TRUE', fixture)
        self.assertIn('Saved persistence mode differs', fixture)

    def test_bound_nonpersistent_round_blocks_transition_votes(self):
        source = (ROOT / 'code/datums/vote.dm').read_text()
        start = source.index('/proc/persistence_blocks_vote(')
        guard = source.index('if (persistence_mode_change_locked())', start)
        self.assertLess(guard, source.index('if (!persistence_round_active())', start))
        self.assertIn('vote_type in list("restart", "epoch", "map", "gamemode")', source[guard:])


if __name__ == '__main__':
    unittest.main()
