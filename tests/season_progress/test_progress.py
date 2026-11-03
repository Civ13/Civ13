"""Source checks for the player-facing season progress readout; no compiler or waits."""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
META = ROOT / "code/game/objects/map_metadata"


def read(path):
    return (ROOT / path).read_text() if not isinstance(path, Path) else path.read_text()


class SeasonProgressTests(unittest.TestCase):
    def test_readout_is_included_and_shown_in_status_tab(self):
        dme = read("civ13.dme")
        self.assertIn('#include "code\\game\\objects\\map_metadata\\season_progress.dm"', dme)
        mob = read("code/game/mob/mob.dm")
        self.assertIn('client.add_stat("<b>Season:</b>", get_season_with_progress())', mob)

    def test_shared_loop_notes_the_same_delay_before_scheduling(self):
        meta = read(META / "_map_metadata.dm")
        self.assertIn(
            '\tvar/delay = season_loop_delay()\n\tseason_note_next_change(delay)\n\tif(durable_schedule("season_loop", delay)) return',
            meta,
        )

    def test_every_self_scheduled_season_timer_is_noted(self):
        # Each spawn(N) that leads straight into seasons() must record N first,
        # so the readout matches the real timer.
        pattern = re.compile(r"^(\t+)spawn\(([^)]+)\)\n\1\tseasons\(\)", re.M)
        found = 0
        for path in META.rglob("*.dm"):
            source = path.read_text()
            for match in pattern.finditer(source):
                indent, delay = match.group(1), match.group(2)
                if delay == "1":
                    continue  # immediate kick-off, not a season length
                found += 1
                before = source[: match.start()].rstrip("\n").rsplit("\n", 1)[-1]
                self.assertEqual(before, f"{indent}season_note_next_change({delay})", path.name)
        self.assertGreaterEqual(found, 14)

    def test_readout_is_read_only(self):
        source = read(META / "season_progress.dm")
        for forbidden in ("spawn(", "durable_schedule", "seasons(", "season =", ".cancel("):
            self.assertNotIn(forbidden, source)
        self.assertIn('durable_callbacks.pending["season_loop"]', source)
        self.assertIn("config.seasons_on", source)


if __name__ == "__main__":
    unittest.main()
