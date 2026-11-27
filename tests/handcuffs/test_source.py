"""Offline source contracts for applying and removing restraints; these do not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "code/game/objects/items/weapons/handcuffs.dm"
STRIP = ROOT / "code/game/mob/living/carbon/human/stripping.dm"
INVENTORY = ROOT / "code/game/mob/living/carbon/human/human.dm"


def place_body(source):
    return source.split('/obj/item/weapon/handcuffs/proc/place_handcuffs(', 1)[1].split('\n/mob/', 1)[0]


def chew_body(source):
    return source.split('/mob/living/human/RestrainedClickOn(', 1)[1].split('\n/obj/', 1)[0]


def project_cuffing(source):
    """Two actors finish cuffing the same target; returns (equipped, in_target, lost)."""
    body = place_body(source)
    wait = body.index('do_after(user,8, target)')
    rechecks_occupancy = 'if (H.handcuffed)' in body[wait:body.index('equip_to_slot')]
    target = {'handcuffed': None, 'contents': []}
    lost = []
    for cuffs in ('first', 'second'):
        if rechecks_occupancy and target['handcuffed']:
            continue  # aborted; the actor keeps their cuffs
        target['contents'].append(cuffs)
        if target['handcuffed']:
            lost.append(target['handcuffed'])
        target['handcuffed'] = cuffs
    return target['handcuffed'], target['contents'], lost


def project_chew(source, attempts):
    """attempts: list of (who, world_time); returns who actually chewed."""
    body = chew_body(source)
    per_actor = 'var/tmp/last_chew' in source.split('/mob/living/human\n', 1)[-1] and '\nvar/last_chew' not in source
    allows_first = '!isnull(last_chew) &&' in body
    shared = {'value': False}
    owners = {}
    chewed = []
    for who, now in attempts:
        last = owners.get(who) if per_actor else shared['value']
        if allows_first and last is None:
            blocked = False
        else:
            blocked = (last or 0) + 26 > now
        if blocked:
            continue
        chewed.append(who)
        if per_actor:
            owners[who] = now
        else:
            shared['value'] = now
    return chewed


class HandcuffsSource(unittest.TestCase):
    def setUp(self):
        self.source = SOURCE.read_text(encoding="utf-8")

    def test_occupancy_and_ownership_rechecked_after_wait(self):
        body = place_body(self.source)
        wait = body.index('do_after(user,8, target)')
        after = body[wait:]
        self.assertLess(after.index('if (H.handcuffed)'), after.index('equip_to_slot'))
        self.assertLess(after.index('if (!dispenser && loc != user)'), after.index('equip_to_slot'))

    def test_success_reported_only_after_equip(self):
        body = place_body(self.source)
        equip = body.index('target.equip_to_slot(cuffs,slot_handcuffed)')
        self.assertLess(equip, body.index('if (H.handcuffed != cuffs || cuffs.loc != H)'))
        self.assertLess(equip, body.index('has put [cuff_type] on'))
        self.assertIn('user.put_in_hands(cuffs)', body)

    def test_both_completion_records_follow_equip_verification(self):
        body = place_body(self.source)
        equip_guard = body.index('if (H.handcuffed != cuffs || cuffs.loc != H)')
        reject = body.index('return FALSE', equip_guard)
        self.assertLess(body.index('admin_attack_log(user, H, "Attempted to handcuff'), equip_guard)
        for record in ('H.append_attack_log(', 'user.append_attack_log('):
            self.assertLess(reject, body.index(record))

    def test_cuff_links_are_removal_only_and_never_drop_an_occupied_active_hand(self):
        inventory = INVENTORY.read_text(encoding="utf-8")
        self.assertIn('item=[slot_handcuffed]', inventory)
        self.assertIn('item=[slot_legcuffed]', inventory)
        self.assertIn('handle_strip(href_list["item"],usr)', inventory)
        strip = STRIP.read_text(encoding="utf-8").split('// Empty out', 1)[0]
        self.assertIn('var/cuff_slot = slot_id == slot_handcuffed || slot_id == slot_legcuffed', strip)
        cuff_entry = strip[strip.index('if (cuff_slot)'):strip.index('switch(slot_to_strip)')]
        self.assertIn('if (!istype(target_slot))\n\t\t\treturn', cuff_entry)
        self.assertIn('if (user.get_active_hand())', cuff_entry)
        self.assertIn('Switch to an empty hand', cuff_entry)
        self.assertTrue(cuff_entry.rstrip().endswith('return'))

    def test_cuff_removal_rechecks_actor_and_original_slot_after_wait(self):
        strip = STRIP.read_text(encoding="utf-8").split('// Empty out', 1)[0]
        wait = strip.rindex('do_mob(user,src,HUMAN_STRIP_DELAY,progress = FALSE)')
        log = strip.index('admin_attack_log(user, src')
        self.assertLess(log, strip.index('unEquip(target_slot)'))
        guards = strip[wait:log]
        self.assertIn('if (stripping)\n\t\tif (cuff_slot)', guards)
        self.assertIn('!user.Adjacent(src)', guards)
        self.assertIn('user.incapacitated()', guards)
        self.assertIn('user.get_active_hand()', guards)
        self.assertIn('offline_sleep_refuses(user)', guards)
        self.assertIn('target_slot.loc != src', guards)
        self.assertIn('get_equipped_item(slot_id) != target_slot', guards)
        self.assertIn('!target_slot.canremove', guards)

    def test_concurrent_cuffing_keeps_first_pair(self):
        equipped, contents, lost = project_cuffing(self.source)
        self.assertEqual((equipped, contents, lost), ('first', ['first'], []))
        unguarded = self.source.replace('if (H.handcuffed) //', 'if (FALSE) //', 1)
        self.assertEqual(project_cuffing(unguarded)[2], ['first'])

    def test_chew_cooldown_is_per_human(self):
        self.assertNotIn('\nvar/last_chew', self.source)
        self.assertIn('var/tmp/last_chew = null', self.source)
        self.assertIn('key == "last_chew" || ..()', self.source)
        # Second human chews right after the first; both chew at world start.
        attempts = [('a', 0), ('b', 5), ('a', 10), ('a', 30)]
        self.assertEqual(project_chew(self.source, attempts), ['a', 'b', 'a'])
        old = self.source.replace('/mob/living/human\n\tvar/tmp/last_chew = null', '\nvar/last_chew = FALSE', 1)
        old = old.replace('if (!isnull(last_chew) && last_chew + 26', 'if (last_chew + 26', 1)
        self.assertEqual(project_chew(old, attempts), ['a'])


if __name__ == "__main__":
    unittest.main()
