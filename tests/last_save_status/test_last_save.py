"""Offline wiring checks for the Status tab's "Last save" line.

The native save/load round trip (time recorded, re-read after a restart, load
validator accepting saved_at) was checked with the berry_load fixture; this
suite pins the production wiring without a compiler.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
STATUS = (ROOT / 'code/modules/persistence/last_save_status.dm').read_text(encoding='utf-8')
FUNCTIONS = (ROOT / 'code/modules/persistence/functions.dm').read_text(encoding='utf-8')
SAVING = (ROOT / 'code/modules/persistence/saving.dm').read_text(encoding='utf-8')
PANEL = (ROOT / 'code/modules/statpanel/statpanel.dm').read_text(encoding='utf-8')
DME = (ROOT / 'civ13.dme').read_text(encoding='utf-8')


def body(source, header):
    start = source.index(header)
    first = source.index('\n', start) + 1
    match = re.search(r'^[/\w]', source[first:], re.M)
    return source[start:first + match.start()] if match else source[start:]


class LastSaveStatus(unittest.TestCase):
    def test_included(self):
        self.assertIn('#include "code\\modules\\persistence\\last_save_status.dm"', DME)

    def test_status_tab_line_follows_joining(self):
        joining = PANEL.index('add_stat("<b>Joining:</b>"')
        line = PANEL.index('add_stat("<b>Last save:</b>", last_save)')
        self.assertLess(joining, line)
        self.assertIn('if(last_save) add_stat', PANEL)

    def test_only_persistent_rounds(self):
        text = body(STATUS, '/proc/persistence_last_save_text(')
        self.assertLess(text.index('if(!persistence_round_active()) return null'), text.index('persistence_last_save_refresh()'))

    def test_saved_with_round_state_before_marker(self):
        save = body(SAVING, '/map_storage/proc/save_world_contents(')
        stamp = save.index('round_state["saved_at"] = persistence_save_stamp()')
        self.assertLess(stamp, save.index('json_encode(round_state), "map_saves/round.json"'))
        self.assertLess(save.index('"map_saves/save_complete.txt"'), save.index('persistence_last_save = list("generation" = generation'))

    def test_load_validator_admits_optional_saved_at(self):
        read = body(FUNCTIONS, '/map_storage/proc/read_round_state(')
        self.assertIn('+ has_transfer + has_saved_at', read)
        self.assertIn('if(has_saved_at && !valid_persistence_save_stamp(state["saved_at"])) throw EXCEPTION', read)

    def test_refresh_keeps_previous_save_while_saving(self):
        refresh = body(STATUS, '/proc/persistence_last_save_refresh(')
        # A save in progress deletes the marker; keep the last completed time.
        self.assertIn('if(!fexists("map_saves/save_complete.txt")) return', refresh)
        self.assertIn('state["generation"] == marker', refresh)

    def test_elapsed_uses_wall_clock_helper(self):
        self.assertIn('wall_clock_elapsed(stamp["timeofday"], stamp["realtime"], now_timeofday, now_realtime)', STATUS)


if __name__ == '__main__':
    unittest.main()
