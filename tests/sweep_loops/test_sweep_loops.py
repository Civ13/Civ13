"""Offline source contracts for long sleeping sweeps; no BYOND runtime.

A DM for-in loop over a large list that sleeps between batches pays a cost
proportional to the whole list each time it resumes, and world.tick_usage
does not see it. Measured on 516.1688 (300k entries, 20% tick gate): for-in
held the server ~44% behind real time; an index loop over the same list had
no drift. The day/night and season sweeps must therefore index their snapshots.
"""
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = (ROOT / 'code/processes/time_of_day_change.dm').read_text(encoding='utf-8')
SEASON_SOURCES = ('code/game/objects/map_metadata/_map_metadata.dm',
                  'code/game/objects/map_metadata/nomads/nomads_asia.dm',
                  'code/modules/persistence/durable_nomads.dm')
AREA_SOURCE = (ROOT / 'code/_helpers/areas.dm').read_text(encoding='utf-8')


def proc_body(text, header):
    start = text.index(header)
    following = re.search(r'^/', text[start + len(header):], re.M)
    end = start + len(header) + following.start() if following else len(text)
    return text[start:end]


class DaylightSweep(unittest.TestCase):
    def setUp(self):
        self.body = proc_body(SOURCE, '/process/time_of_day_change/proc/apply_daylight(')

    def test_large_sweeps_do_not_use_sleeping_for_in_loops(self):
        for name in ('lighting_overlay_list', 'turfs'):
            with self.subTest(name=name):
                self.assertIsNone(re.search(r'for\s*\([^)]*\bin\s+' + name + r'\s*\)', self.body))

    def test_index_loops_walk_one_time_snapshots(self):
        self.assertIn('var/list/sweep_overlays = lighting_overlay_list.Copy()', self.body)
        self.assertIn('var/list/sweep_turfs = turfs.Copy()', self.body)
        self.assertIn('overlay_index <= sweep_overlays.len', self.body)
        self.assertIn('turf_index <= sweep_turfs.len', self.body)
        # The snapshot lists are not re-read from the live globals per step.
        loops = self.body.split('setup_lighting = TRUE', 1)
        self.assertNotIn('lighting_overlay_list[', self.body)
        self.assertNotIn('turfs[', loops[1].replace('sweep_turfs[', ''))

    def test_both_sweeps_keep_their_budget_and_revision_checks(self):
        self.assertEqual(self.body.count('if (environment_sweep_pause(++work))'), 2)
        self.assertEqual(self.body.count('if (revision != lighting_revision)'), 2)
        # Entries that are not turfs (or deleted overlays) are skipped, as the
        # typed for-in did, instead of raising mid-sweep.
        self.assertIn('if (!istype(T))', self.body)
        self.assertIn('if (LO)', self.body)


class SeasonSweeps(unittest.TestCase):
    def lines(self, path):
        return (ROOT / path).read_text(encoding='utf-8').split('\n')

    def test_no_season_mutation_loop_uses_a_sleeping_for_in(self):
        for path in SEASON_SOURCES:
            lines = self.lines(path)
            for number, line in enumerate(lines[:-1], 1):
                if 'season_work_pause' not in lines[number]:
                    continue
                with self.subTest(path=path, line=number):
                    self.assertIsNone(re.match(r'\s*for\s*\(var/[\w/]+ in ', line), line)

    def test_season_index_loops_skip_entries_like_the_typed_for_in(self):
        counted = 0
        for path in SEASON_SOURCES:
            lines = self.lines(path)
            for number, line in enumerate(lines):
                match = re.match(r'(\t*)var/list/(\w+)_sweep = ', line)
                if not match:
                    continue
                counted += 1
                indent, name = match.groups()
                loop, element, check = lines[number + 1:number + 4]
                with self.subTest(path=path, line=number + 1):
                    self.assertEqual(loop, f'{indent}for (var/{name}_index = 1, {name}_index <= length({name}_sweep), {name}_index++)')
                    item = re.fullmatch(indent + r'\tvar/[\w/]+/(\w+) = ' + name + r'_sweep\[' + name + r'_index\]', element)
                    self.assertIsNotNone(item, element)
                    self.assertEqual(check, f'{indent}\tif (!istype({item.group(1)}))')
                    self.assertIn('season_work_pause', lines[number + 5])
        self.assertGreaterEqual(counted, 37)

    def test_area_turf_discovery_indexes_a_contents_copy(self):
        body = proc_body(AREA_SOURCE, '/proc/get_area_turfs(')
        self.assertIn('var/list/area_contents = A.contents.Copy()', body)
        self.assertIn('content_index <= area_contents.len', body)
        self.assertNotIn('for (var/turf/T in A.contents)\n\t\t\t\tseason_work++', body)
        self.assertEqual(body.count('season_owner.season_work_pause(season_epoch, season_work, TRUE)'), 1)


if __name__ == '__main__':
    unittest.main()
