"""Offline projection of splint completion and removal; no BYOND runtime is run.

Issues #6208 (two helpers splint one limb), #6210 (patient walks away during the
wait) and #6211 (Remove splints skips hands, feet, head, chest and groin).
"""
import importlib.util
from pathlib import Path
import re
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
MEDICAL = ROOT / 'code/game/objects/items/stacks/medical.dm'
STRIPPING = ROOT / 'code/game/mob/living/carbon/human/stripping.dm'
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


def complete_attack(source, H, affecting, user, M):
    """Run attack() from the wait onward with the wait succeeding."""
    body = adapter.extract(source, '/obj/item/stack/medical/splint/attack')
    body = body[body.index('\t\tif (do_mob(user, M, 50))'):]
    body = '\n'.join(line[1:] for line in body.splitlines())
    body = re.sub(r'user\.visible_message\([^\n]*\)', 'user.visible_message()', body)
    used = []
    check, _ = still_needed(source)
    names = env([])
    names.update({'do_mob': lambda *a: True, 'use': used.append, 'prob': lambda p: True,
                  'splint_still_needed': check, 'H': H, 'affecting': affecting,
                  'user': user, 'M': M, 'limb': affecting.name})
    adapter.project('/fixture/run()\n' + body, '/fixture/run', '', names)()
    return used


def remove_all(source, patient):
    body = adapter.extract(source, '/mob/living/human/proc/remove_splints')
    # Item creation and messages are engine boundaries.
    body, count = re.subn(r'var/obj/item/W = new /obj/item/stack/medical/splint\(get_turf\(src\), TRUE\)',
                          'W = make_splint()', body)
    if count != 1:
        raise AssertionError('splint creation boundary changed')
    # An uninitialised DM var is null.
    body, count = re.subn(r'var/removed_splint\n', 'var/removed_splint = null\n', body)
    if count != 1:
        raise AssertionError('removed_splint declaration changed')
    made, messages = [], []

    def make_splint():
        item = SimpleNamespace(add_fingerprint=lambda u: None)
        made.append(item)
        return item
    names = env(messages)
    names.update({'make_splint': make_splint, 'get_organ': patient.get_organ,
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

    def test_old_guards_are_negative_controls(self):
        old_attack = self.medical.replace('\t\t\tif (!splint_still_needed(H, affecting, user))\n\t\t\t\treturn\n', '', 1)
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
