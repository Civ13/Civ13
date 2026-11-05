"""Offline checks for the research persistence probe; no compiler or server."""
from pathlib import Path
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
import run  # noqa: E402

ROOT = run.ROOT


class ResearchPersistenceSource(unittest.TestCase):
    def test_controls_and_extracted_procs_are_unique(self):
        for control in (None, *run.CONTROLS):
            for path in (run.FACTION, run.DEFINES, run.NODE, run.METADATA):
                run.read(path, control)
        metadata = run.read(run.METADATA, None)
        self.assertIn('return TRUE', run.proc_text(metadata, '/obj/map_metadata/proc/legacy_age_advance('))
        self.assertIn('/proc/get_research_node(', run.node_datum(run.read(run.NODE, None)))

    def test_tick_syncs_baselines_and_every_legacy_step_is_guarded(self):
        metadata = (ROOT / run.METADATA).read_text(encoding='utf-8')
        self.assertIn('\tif (nomads)\n\t\tsync_autoresearch_baselines()\n', metadata)
        tick = metadata.split('/obj/map_metadata/proc/tick()', 1)[1].split('\n/obj/map_metadata/proc/', 1)[0]
        self.assertEqual(tick.count('legacy_age_advance('), 9)
        self.assertNotIn('set_ordinal_age()', tick)


if __name__ == '__main__':
    unittest.main()
