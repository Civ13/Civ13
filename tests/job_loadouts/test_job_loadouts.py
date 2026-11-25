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
CAMP = '/datum/job/japanese/camp_officer'
IJN = '/datum/job/japanese/ijn_sergeant'
NAMBU = '/obj/item/weapon/gun/projectile/pistol/ww2/nambu'


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
            expected = items
            if path == CAMP:
                # #7000 moves this rejected fixed-slot item to a free-hand equip.
                self.assertIn([NAMBU, 'slot_l_store'], items)
                expected = [item for item in items if item != [NAMBU, 'slot_l_store']]
            self.assertEqual(found[path], expected, path)
            types = [t for t, _ in expected]
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

    def test_medieval_militia_rolls_all_keep_the_selected_item(self):
        jobs = dict(equip_bodies(self.files[JOBS / 'medieval.dm']))
        inventory = (ROOT / 'code/game/objects/items.dm').read_text()
        material_items = (ROOT / 'code/game/objects/items/weapons/material/misc.dm').read_text()
        classic = (ROOT / 'code/game/objects/items/weapons/swords_axes_etc.dm').read_text()

        for faction in ('british', 'french'):
            body = '\n'.join(jobs[f'/datum/job/{faction}/medieval_militia'])
            with self.subTest(faction=faction):
                self.assertIn('var/randwep = pick(1,2,3,4)', body)
                rolls = re.findall(
                    r'\tif \(randwep == ([1-4])\)\n'
                    r'\t\tH\.equip_to_slot_or_del\(new (/obj/[\w/]+)\(H\), (slot_[a-z_]+)\)',
                    body,
                )
                self.assertEqual(rolls, [
                    ('1', '/obj/item/weapon/material/spear/iron', 'slot_shoulder'),
                    ('2', '/obj/item/weapon/material/pitchfork', 'slot_r_hand'),
                    ('3', '/obj/item/weapon/melee/classic_baton/club', 'slot_back'),
                    ('4', '/obj/item/weapon/material/hatchet/battleaxe', 'slot_belt'),
                ])
                # The optional shield stays in the other hand; none of the
                # unconditional gear takes a selected weapon slot.
                self.assertIn('blue_buckler(H), slot_l_hand)', body)
                for _, _, slot in rolls:
                    self.assertEqual(body.count(f', {slot})'), 1)

        flags = dict(re.findall(r'"\[(slot_[a-z_]+)\]" = ([^,\n]+),', inventory))
        self.assertNotIn('slot_r_hand', flags)
        iron_spear = material_items.split('/obj/item/weapon/material/spear/iron\n', 1)[1].split('\n/', 1)[0]
        self.assertNotIn('slot_flags', iron_spear)
        for file, path, slot in (
            (material_items, '/obj/item/weapon/material/spear', 'slot_shoulder'),
            (classic, '/obj/item/weapon/melee/classic_baton/club', 'slot_back'),
            (material_items, '/obj/item/weapon/material/hatchet/battleaxe', 'slot_belt'),
        ):
            start = file.index(path + '\n') + len(path)
            flags_line = re.search(r'(?m)^\tslot_flags = ([^\n]+)', file[start:].split('\n/', 1)[0])
            self.assertIsNotNone(flags_line, path)
            self.assertIn(flags[slot], set(re.findall(r'SLOT_[A-Z_]+', flags_line.group(1))))

    def test_japanese_sergeants_keep_nambu_and_competing_gear(self):
        jobs = dict(equip_bodies(self.files[JOBS / 'japanese.dm']))
        nambu = f'H.put_in_hands(new {NAMBU}(H))'
        for path in (CAMP, IJN):
            body = '\n'.join(jobs[path])
            with self.subTest(path=path):
                self.assertEqual(body.count(NAMBU), 1)
                self.assertIn(nambu, body)
        self.assertNotIn(NAMBU, dict(self.declared()[CAMP]))
        self.assertIn(['/obj/item/ammo_magazine/c8mmnambu', 'slot_r_store'], self.declared()[CAMP])
        ijn = '\n'.join(jobs[IJN])
        self.assertLess(ijn.index('katana(H), slot_l_hand)'), ijn.index(nambu))
        self.assertIn('arisaka99(H), slot_shoulder)', ijn)

        # The actual placement proc tries the other hand on failure and
        # delegates to ordinary turf placement if both hands are occupied.
        human = (ROOT / 'code/game/mob/living/carbon/human/human.dm').read_text()
        entry = human.split('/mob/living/human/put_in_hands(var/obj/item/W)\n', 1)[1].split('\n/', 1)[0]
        self.assertRegex(entry, r'(?s)if \(put_in_active_hand\(W\)\).*?else if \(put_in_inactive_hand\(W\)\).*?else\n\t\treturn \.\.\(\)')
        for hand in ('l_hand', 'r_hand'):
            proc = human.split(f'/mob/living/human/put_in_{hand}(var/obj/item/W)\n', 1)[1].split('\n/', 1)[0]
            self.assertIn(f'if (!..() || {hand})\n\t\treturn FALSE', proc)
        mob = (ROOT / 'code/game/mob/inventory.dm').read_text()
        fallback = mob.split('/mob/proc/put_in_hands(var/obj/item/W)\n', 1)[1].split('\n/', 1)[0]
        self.assertIn('W.forceMove(get_turf(src))', fallback)
        self.assertNotIn('qdel', fallback)


if __name__ == '__main__':
    unittest.main()
