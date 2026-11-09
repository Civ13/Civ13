"""Offline source contracts for handcuffs (#4229, #4230); these do not execute DM."""
from pathlib import Path
import unittest

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "code/game/objects/items/weapons/handcuffs.dm"


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
