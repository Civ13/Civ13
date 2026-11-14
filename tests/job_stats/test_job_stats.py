"""Job stats are data: `job_stats` on the job, applied by apply_job_stats().

838 job equip() procs each ended with eight to ten `H.setStat("x", STAT_Y)`
lines. The straight runs moved into one `job_stats` list per job and equip()
calls apply_job_stats(H) where the run was. frozen_job_stats.json holds the
stats each converted job set before the move, in order (setStat() rolls its
own randomness per call, so order is kept too). LITERAL_CEILING: hand-written
literal setStat lines left in job files only go down.
"""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
JOBS = ROOT / 'code/modules/1713/jobs'
FROZEN = json.loads((Path(__file__).with_name('frozen_job_stats.json')).read_text(encoding='utf-8'))
DECL = re.compile(r'^(/datum/job/[\w/]+)/job_stats = list\((.*)\)\s*$', re.M)
PAIR = re.compile(r'"([a-z_]+)" = (STAT_[A-Z_]+|[0-9]+)')
HEAD = re.compile(r'^(/datum/job/[\w/]+)/equip\(var/mob/living/human/H\)\s*$')
LITERAL = re.compile(r'^\tH\.setStat\("[a-z_]+", ?(STAT_[A-Z_]+|[0-9]+)\)\s*$', re.M)
LITERAL_CEILING = 123


def job_files():
    return {path: path.read_text(encoding='utf-8') for path in sorted(JOBS.glob('*.dm'))}


def equip_bodies(text):
    lines = text.split('\n')
    for i, line in enumerate(lines):
        match = HEAD.match(line)
        if not match:
            continue
        end = i + 1
        while end < len(lines) and (lines[end] == '' or lines[end][0] in '\t ' or lines[end].startswith('//')):
            end += 1
        yield match.group(1), lines[i + 1:end]


class JobStatsTest(unittest.TestCase):
    def setUp(self):
        self.files = job_files()

    def test_converted_jobs_keep_their_stats_in_order(self):
        found = {}
        for text in self.files.values():
            for path, body in DECL.findall(text):
                self.assertNotIn(path, found, path)
                found[path] = [list(pair) for pair in PAIR.findall(body)]
        for path, stats in FROZEN.items():
            self.assertEqual(found.get(path), stats, path)

    def test_every_job_with_stats_applies_them_once(self):
        declared = set()
        for text in self.files.values():
            declared.update(path for path, _ in DECL.findall(text))
        for text in self.files.values():
            for path, body in equip_bodies(text):
                calls = sum(line.strip() == 'apply_job_stats(H)' for line in body)
                if path in declared:
                    self.assertEqual(calls, 1, path)
                    self.assertFalse(any('setStat(' in line for line in body), path)
                else:
                    self.assertEqual(calls, 0, path)

    def test_apply_keeps_list_order(self):
        job = (ROOT / 'code/game/jobs/job.dm').read_text(encoding='utf-8')
        self.assertIn('/datum/job/proc/apply_job_stats(var/mob/living/human/H)\n'
                      '\tfor (var/stat in job_stats)\n\t\tH.setStat(stat, job_stats[stat])\n', job)

    def test_hand_written_literal_stats_only_go_down(self):
        count = sum(len(LITERAL.findall(text)) for text in self.files.values())
        self.assertLessEqual(count, LITERAL_CEILING)


if __name__ == '__main__':
    unittest.main()
