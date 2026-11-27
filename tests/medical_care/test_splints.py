"""Offline projection of splint completion and removal; no BYOND runtime is run.

Issues #6208 (two helpers splint one limb), #6210 (patient walks away during the
wait), #6211 (Remove splints skips some zones) and #7527 (wrong refund type).
"""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
MEDICAL = ROOT / 'code/game/objects/items/stacks/medical.dm'
STRIPPING = ROOT / 'code/game/mob/living/carbon/human/stripping.dm'
ORGAN = ROOT / 'code/modules/organs/organ_external.dm'
SPLINT = '/obj/item/stack/medical/splint'
WOODEN = SPLINT + '/wooden'
SMALL = SPLINT + '/small'
spec = importlib.util.spec_from_file_location('source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)

ORGAN_BROKEN, ORGAN_SPLINTED = 32, 256  # code/predefines.dm


def read(path):
    return path.read_text(encoding='utf-8-sig')


def splintable(source):
    match = re.search(r'var/global/list/splintable_organs = list\(([^)]*)\)', source)
    if not match:
        raise AssertionError('splintable_organs list missing')
    return re.findall(r'"(\w+)"', match[1])


class Organ:
    def __init__(self, limb_name, status=ORGAN_BROKEN, dislocated=False):
        self.limb_name = self.name = limb_name
        self.status = status
        self.dislocated = dislocated
        self.deleted = False
        self.splint_type = None

    def is_dislocated(self):
        return self.dislocated


class Patient:
    def __init__(self, *organs):
        self.organs = {o.limb_name: o for o in organs}
        self.deleted = False

    def get_organ(self, name):
        return self.organs.get(name)


class User:
    def __init__(self, adjacent=True):
        self.adjacent = adjacent

    def Adjacent(self, other):
        return self.adjacent

    def visible_message(self, *messages):
        pass


def env(messages):
    return {'QDELETED': lambda x: x is None or x.deleted, 'ORGAN_SPLINTED': ORGAN_SPLINTED,
            'ORGAN_BROKEN': ORGAN_BROKEN, 'SPAN_WARNING': lambda t: t,
            'to_chat': lambda *a: messages.append(a)}


def still_needed(source):
    messages = []
    proc = adapter.project(source, '/obj/item/stack/medical/splint/proc/splint_still_needed',
                           'H, affecting, user', env(messages))
    return proc, messages


def complete_attack(source, H, affecting, user, M, subtype=SPLINT, payable=True, deleted=False):
    """Run attack() from the wait onward with the wait succeeding."""
    body = adapter.extract(source, '/obj/item/stack/medical/splint/attack')
    body = body[body.index('\t\tif (kneel_wait(user, M, 50))'):]
    body = '\n'.join(line[1:] for line in body.splitlines())
    body = re.sub(r'user\.visible_message\([^\n]*\)', 'user.visible_message()', body)
    used = []
    check, _ = still_needed(source)

    def use(n):
        used.append(n)
        return payable

    names = env([])
    names.update({'src': SimpleNamespace(deleted=deleted), 'type': subtype, 'can_use': lambda n: payable,
                  'kneel_wait': lambda *a: True, 'use': use, 'prob': lambda p: True,
                  'splint_still_needed': check, 'H': H, 'affecting': affecting,
                  'user': user, 'M': M, 'limb': affecting.name})
    adapter.project('/fixture/run()\n' + body, '/fixture/run', '', names)()
    return used


def recover_helper(organ, made):
    """Project the actual recovery and clearing procs; adapt the DM path and constructor boundary."""
    clear_body = adapter.extract(organ, '/obj/item/organ/external/proc/clear_splint')
    clear_body = re.sub(r'\b(status|splint_type)\b', r'limb.\1', clear_body)
    clear = adapter.project('/fixture/clear(limb)\n' + clear_body, '/fixture/clear', 'limb', env([]))

    def recover(limb, fallback_type):
        body = adapter.extract(organ, '/obj/item/organ/external/proc/recover_splint')
        body = body.replace('/obj/item/stack/medical/splint', 'SPLINT')
        body = re.sub(r'(?<!\.)\b(status|splint_type)\b', r'limb.\1', body)
        body = body.replace('ispath(limb.splint_type, SPLINT) ? limb.splint_type : fallback_type',
                            '(limb.splint_type if ispath(limb.splint_type, SPLINT) else fallback_type)')
        body, count = re.subn(r'return new (\w+)\(drop_site, (\d+), (FALSE|TRUE)\)',
                              r'return make_splint(\1, \2, \3)', body)
        if count != 1:
            raise AssertionError('splint construction boundary changed')

        def make_splint(subtype, amount, merge):
            if merge:
                raise AssertionError('single recovery unit must not merge during creation')
            item = SimpleNamespace(type=subtype, amount=amount, add_fingerprint=lambda u: None)
            made.append(item)
            return item
        names = env([])
        names.update({'SPLINT': SPLINT, 'ispath': lambda item, parent: bool(item and (item == parent or item.startswith(parent + '/'))),
                      'make_splint': make_splint, 'clear_splint': lambda: clear(limb)})
        return adapter.project('/fixture/recover(limb, fallback_type)\n' + body,
                               '/fixture/recover', 'limb, fallback_type', names)(limb, fallback_type)

    return recover


def remove_all(source, patient):
    body = adapter.extract(source, '/mob/living/human/proc/remove_splints')
    body = body.replace('o.recover_splint(get_turf(src), /obj/item/stack/medical/splint)', 'recover(o, SPLINT)')
    # An uninitialised DM var is null.
    body, count = re.subn(r'var/removed_splint\n', 'var/removed_splint = null\n', body)
    if count != 1:
        raise AssertionError('removed_splint declaration changed')
    made, messages = [], []
    names = env(messages)
    names.update({'recover': recover_helper(read(ORGAN), made), 'SPLINT': SPLINT, 'get_organ': patient.get_organ,
                  'splintable_organs': splintable(read(MEDICAL)),
                  'visible_message': lambda *a: messages.append(a),
                  'list': lambda *items: list(items)})  # DM list() literal
    adapter.project('/fixture/run(user)\n' + body, '/fixture/run', 'user', names)(object())
    return made


class SplintTests(unittest.TestCase):
    def setUp(self):
        self.medical = read(MEDICAL)
        self.stripping = read(STRIPPING)

    def test_attack_accepts_exactly_the_shared_list(self):
        self.assertIn('if (!(affecting.limb_name in splintable_organs))', self.medical)
        self.assertEqual(set(splintable(self.medical)),
                         {'chest', 'head', 'groin', 'l_arm', 'r_arm', 'l_leg', 'r_leg',
                          'l_hand', 'r_hand', 'l_foot', 'r_foot'})

    def test_ordinary_treatment_still_splints_and_uses_one(self):
        leg = Organ('l_leg')
        patient, user = Patient(leg), User()
        self.assertEqual(complete_attack(self.medical, patient, leg, user, patient), [1])
        self.assertTrue(leg.status & ORGAN_SPLINTED)

    def test_second_helper_after_first_splint_uses_nothing(self):
        # #6208: the first helper finished during the second helper's wait.
        leg = Organ('l_leg', ORGAN_BROKEN | ORGAN_SPLINTED)
        patient, user = Patient(leg), User()
        self.assertEqual(complete_attack(self.medical, patient, leg, user, patient), [])

    def test_patient_out_of_reach_is_not_splinted(self):
        # #6210
        leg = Organ('l_leg')
        patient, user = Patient(leg), User(adjacent=False)
        self.assertEqual(complete_attack(self.medical, patient, leg, user, patient), [])
        self.assertFalse(leg.status & ORGAN_SPLINTED)

    def test_self_treatment_ignores_reach_and_detached_limb_is_refused(self):
        check, _ = still_needed(self.medical)
        leg = Organ('l_leg')
        patient = Patient(leg)
        self.assertTrue(check(patient, leg, patient))
        self.assertFalse(check(Patient(), leg, User()))  # limb came off during the wait
        healed = Organ('l_leg', 0)
        self.assertFalse(check(Patient(healed), healed, User()))  # healed meanwhile
        dislocated = Organ('l_leg', 0, dislocated=True)
        self.assertTrue(check(Patient(dislocated), dislocated, User()))

    def test_removal_covers_every_splintable_zone(self):
        # #6211
        organs = [Organ(name, ORGAN_SPLINTED) for name in splintable(self.medical)]
        patient = Patient(*organs)
        self.assertEqual(len(remove_all(self.stripping, patient)), len(organs))
        self.assertFalse(any(o.status & ORGAN_SPLINTED for o in organs))
        unsplinted = Patient(Organ('l_hand', ORGAN_BROKEN))
        self.assertEqual(remove_all(self.stripping, unsplinted), [])

    def test_empty_or_deleted_stack_cannot_apply(self):
        for kwargs in ({'payable': False}, {'deleted': True}):
            leg = Organ('l_leg')
            patient = Patient(leg)
            self.assertEqual(complete_attack(self.medical, patient, leg, User(), patient, WOODEN, **kwargs), [])
            self.assertEqual(leg.status, ORGAN_BROKEN)
            self.assertIsNone(leg.splint_type)

    def test_wooden_round_trip_recovers_one_and_cannot_repeat(self):
        leg = Organ('l_leg')
        patient = Patient(leg)
        self.assertEqual(complete_attack(self.medical, patient, leg, User(), patient, WOODEN), [1])
        items = remove_all(self.stripping, patient)
        self.assertEqual([(i.type, i.amount) for i in items], [(WOODEN, 1)])
        self.assertIsNone(leg.splint_type)
        self.assertEqual(remove_all(self.stripping, patient), [])
        # Removing the type assignment reproduces the old generic refund.
        old_attack = self.medical.replace('\t\t\t\taffecting.splint_type = applied_type\n', '', 1)
        self.assertNotEqual(old_attack, self.medical)
        self.assertEqual(complete_attack(old_attack, patient, leg, User(), patient, WOODEN), [1])
        self.assertEqual(remove_all(self.stripping, patient)[0].type, SPLINT)

    def test_missing_or_invalid_subtype_uses_callers_legacy_type(self):
        for recorded in (None, '/obj/item/stack/ore/glass'):
            for fallback in (SPLINT, SMALL):
                leg = Organ('l_leg', ORGAN_SPLINTED)
                leg.splint_type = recorded
                made = []
                item = recover_helper(read(ORGAN), made)(leg, fallback)
                self.assertEqual((item.type, item.amount), (fallback, 1))
                self.assertEqual(len(made), 1)
                self.assertIsNone(leg.splint_type)

    def test_old_guards_are_negative_controls(self):
        old_attack = self.medical.replace(' || !splint_still_needed(H, affecting, user)', '', 1)
        self.assertNotEqual(old_attack, self.medical)
        leg = Organ('l_leg', ORGAN_BROKEN | ORGAN_SPLINTED)
        patient = Patient(leg)
        self.assertEqual(complete_attack(old_attack, patient, leg, User(), patient), [1])
        far = Organ('l_leg')
        self.assertEqual(complete_attack(old_attack, Patient(far), far, User(False), Patient(far)), [1])

        old_strip = self.stripping.replace('for (var/organ in splintable_organs)',
                                           'for (var/organ in list("l_leg","r_leg","l_arm","r_arm"))', 1)
        self.assertNotEqual(old_strip, self.stripping)
        hand = Organ('l_hand', ORGAN_SPLINTED)
        self.assertEqual(remove_all(old_strip, Patient(hand)), [])
        self.assertTrue(hand.status & ORGAN_SPLINTED)


if __name__ == '__main__':
    unittest.main()
