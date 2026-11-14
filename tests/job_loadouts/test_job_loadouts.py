"""Job loadouts are data: `job_loadout` on the job, equipped by equip_loadout().

Job equip() procs opened with long runs of
`H.equip_to_slot_or_del(new /obj/...(H), slot_x)`. The first straight run in
each proc (no ..() call, no repeated item type) moved into one `job_loadout`
list per job, /type = slot in the original order, and equip() calls
equip_loadout(H) where the run was. frozen_job_loadouts.json holds what each
converted job equipped before the move. PLAIN_CEILING: plain hand-written
equip lines left in job files only go down.
"""
import json
from pathlib import Path
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
JOBS = ROOT / 'code/modules/1713/jobs'
FROZEN = json.loads(Path(__file__).with_name('frozen_job_loadouts.json').read_text(encoding='utf-8'))
DECL = re.compile(r'^(/datum/job/[\w/]+)/job_loadout = list\(\n((?:\t[^\n]+\n)*?\t[^\n]+\))$', re.M)
PAIR = re.compile(r'(/obj/[\w/]+) = (slot_[a-z_0-9]+)')
HEAD = re.compile(r'^(/datum/job/[\w/]+)/equip\(var/mob/living/human/H\)\s*$')
PLAIN = re.compile(r'^\tH\.equip_to_slot_or_del\(new ?/obj/[\w/]+\(H\), ?slot_[a-z_0-9]+\)\s*$', re.M)
PLAIN_CEILING = 1248


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


class JobLoadoutsTest(unittest.TestCase):
    def setUp(self):
        self.files = job_files()

    def declared(self):
        found = {}
        for text in self.files.values():
            for path, body in DECL.findall(text):
                self.assertNotIn(path, found, path)
                found[path] = [list(pair) for pair in PAIR.findall(body)]
        return found

    def test_converted_jobs_keep_their_items_in_order(self):
        found = self.declared()
        self.assertEqual(set(found), set(FROZEN))
        for path, items in FROZEN.items():
            self.assertEqual(found[path], items, path)
            types = [t for t, _ in items]
            self.assertEqual(len(types), len(set(types)), path)

    def test_each_job_with_a_loadout_equips_it_once(self):
        declared = set(self.declared())
        for text in self.files.values():
            for path, body in equip_bodies(text):
                calls = sum(line.strip() == 'equip_loadout(H)' for line in body)
                self.assertEqual(calls, 1 if path in declared else 0, path)
                if path in declared:
                    # ..() would run a parent's equip() with this job's list.
                    self.assertFalse(any('..(' in line for line in body), path)

    def test_helper_equips_in_order(self):
        text = (ROOT / 'code/game/jobs/job.dm').read_text(encoding='utf-8')
        self.assertIn('/datum/job/proc/equip_loadout(var/mob/living/human/H)\n'
                      '\tfor (var/item_type in job_loadout)\n'
                      '\t\tH.equip_to_slot_or_del(new item_type(H), job_loadout[item_type])\n', text)

    def test_plain_equip_lines_only_go_down(self):
        count = sum(len(PLAIN.findall(text)) for text in self.files.values())
        self.assertLessEqual(count, PLAIN_CEILING)


if __name__ == '__main__':
    unittest.main()
