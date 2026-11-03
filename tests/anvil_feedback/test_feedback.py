"""Full selected admission-prefix projection; no anvil gameplay/native engine."""
from pathlib import Path
import importlib.util
import re
import struct
from types import SimpleNamespace
import unittest

ROOT = Path(__file__).resolve().parents[2]
ANVIL = ROOT / 'code/game/objects/structures/blacksmithing/blacksmithing.dm'
spec = importlib.util.spec_from_file_location('anvil_source_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)


def f32(value):
    return struct.unpack('<f', struct.pack('<f', value))[0]


def adjacent(value, delta):
    bits = struct.unpack('<I', struct.pack('<f', value))[0]
    return struct.unpack('<f', struct.pack('<I', bits + delta))[0]


THRESHOLD = f32(1.2)
MAPS = dict(MAP_TRIBES='tribes', MAP_THREE_TRIBES='three', MAP_FOUR_KINGDOMS='four', MAP_GULAG13='gulag')
JOBS = ('Blacksmith', 'Pioneer Blacksmith', 'Town Blacksmith', 'Ferreiro', 'Ferrero',
        'Grofsmid', 'Forgeron', 'British Blacksmith', 'Marooned Pirate Crew', 'Schmied')


def source_prefix():
    source = ANVIL.read_text(encoding='utf-8-sig')
    start = source.index('\tvar/crafting_coefficient = H.getStatCoeff("crafting")')
    end = source.index('\tif ((map.ID == MAP_TRIBES', start)
    return '/proc/anvil_admission(user)\n\tvar/mob/living/human/H = user\n' + source[start:end] + '\treturn TRUE\n'


def literals(match):
    # Exact lexical conversion of this message's one numeric interpolation.
    token = match.group()
    if '[num2text(crafting_coefficient, 9)]' in token:
        return 'f' + token.replace('[num2text(crafting_coefficient, 9)]', '{num2text(crafting_coefficient, 9)}')
    if '[' in token:
        raise AssertionError('Unaudited interpolation: ' + token)
    return token


class Actor:
    def __init__(self, value, job='Blacksmith'):
        self.value = value
        self.original_job_title = job
        self.calls = []
    def getStatCoeff(self, skill):
        self.calls.append(skill)
        return self.value


class Admission:
    def __init__(self, source=None, civilizations=False, map_id='other'):
        self.messages = []
        self.formats = []
        def number(value, digits):
            self.formats.append((value, digits))
            return format(value, '.' + str(digits) + 'g')
        env = dict(MAPS, map=SimpleNamespace(civilizations=civilizations, ID=map_id),
                   to_chat=lambda actor,message:self.messages.append((actor,message)), num2text=number)
        text = source_prefix() if source is None else source
        text = re.sub(r'"(?:[^"\\]|\\.)*"', literals, text)
        # The literal 1.2 is represented by binary32 in DM; model that boundary.
        text = text.replace(' < 1.2)', ' < THRESHOLD)')
        env['THRESHOLD'] = THRESHOLD
        self.call = adapter.project(text, '/proc/anvil_admission', 'user', env)


class AnvilFeedback(unittest.TestCase):
    def test_below_exact_above_gate(self):
        for value,allowed in ((adjacent(THRESHOLD,-1),False),(THRESHOLD,True),(adjacent(THRESHOLD,1),True)):
            with self.subTest(value=value):
                actor=Actor(value);admission=Admission()
                self.assertEqual(admission.call(actor) is True,allowed)
                self.assertEqual(actor.calls,['crafting'])
                self.assertEqual(bool(admission.messages),not allowed)
    def test_skill_refusal_reports_effective_coefficient_and_real_menu(self):
        actor=Actor(f32(1.12));admission=Admission();admission.call(actor)
        recipient,message=admission.messages[0]
        self.assertIs(recipient,actor)
        self.assertIn('effective Crafting coefficient of at least 1.20x',message)
        self.assertIn('yours is '+format(actor.value,'.9g')+'x',message)
        self.assertIn('IC > Skill Progress',message)
        self.assertIn('mood and traits',message)
        self.assertEqual(admission.formats,[(actor.value,9)])
        telecom=(ROOT/'code/modules/1713/modern_telecom.dm').read_text(encoding='utf-8-sig')
        verb=adapter.extract(telecom,'/mob/living/human/verb/show_practice_progress')
        self.assertIn('set name = "Skill Progress"',verb)
        self.assertIn('set category = "IC"',verb)
    def test_closest_failing_floats_do_not_display_the_threshold(self):
        for offset in range(-32,0):
            value=adjacent(THRESHOLD,offset);actor=Actor(value);admission=Admission();admission.call(actor)
            message=admission.messages[0][1]
            displayed=re.search(r'yours is ([^ ]+)x',message)[1]
            self.assertLess(float(displayed),1.2)
            self.assertNotIn(displayed,('1.2','1.20'))
        self.assertEqual(format(adjacent(THRESHOLD,-1),'.6g'),'1.2')
    def test_coefficient_is_evaluated_once_and_shared_by_gate_and_message(self):
        actor=Actor(f32(1.1))
        def changing(skill):
            actor.calls.append(skill)
            return f32(1.1) if len(actor.calls)==1 else f32(2.1)
        actor.getStatCoeff=changing
        admission=Admission();self.assertIsNone(admission.call(actor))
        self.assertEqual(actor.calls,['crafting'])
        self.assertEqual(admission.formats,[(f32(1.1),9)])
    def test_job_refusal_is_distinct_and_does_not_claim_insufficient_skill(self):
        actor=Actor(f32(2),'Farmer');admission=Admission();self.assertIsNone(admission.call(actor))
        self.assertEqual(admission.messages,[(actor,'Your job is not permitted to use this anvil on this map. Ask a blacksmith.')])
        self.assertEqual(admission.formats,[])
    def test_skill_refusal_precedes_job_refusal(self):
        actor=Actor(f32(1.1),'Farmer');admission=Admission();admission.call(actor)
        self.assertEqual(len(admission.messages),1)
        self.assertIn('effective Crafting',admission.messages[0][1])
        self.assertNotIn('Your job',admission.messages[0][1])
    def test_all_original_map_and_job_outcomes_remain_equal(self):
        old=(Path(__file__).parent/'fixtures/legacy_admission.dm').read_text(encoding='utf-8')
        # The frozen fixture predates the 1.7 -> 1.2 retune; compare job/map outcomes at the current gate.
        old=old.replace(' < 1.7)',' < 1.2)')
        for value in (f32(1.0),adjacent(THRESHOLD,-1),THRESHOLD,adjacent(THRESHOLD,1),f32(2.5)):
            for job in JOBS+('Farmer','blacksmith',''):
                for civilizations,map_id in ((False,'other'),(True,'other'))+tuple((False,i) for i in MAPS.values()):
                    with self.subTest(value=value,job=job,civilizations=civilizations,map=map_id):
                        old_run=Admission(old,civilizations,map_id);new_run=Admission(None,civilizations,map_id)
                        self.assertEqual(old_run.call(Actor(value,job)) is True,new_run.call(Actor(value,job)) is True)
    def test_only_the_actor_receives_refusal_feedback(self):
        bystander=Actor(f32(2.5));actor=Actor(f32(1.1));admission=Admission();admission.call(actor)
        self.assertTrue(all(recipient is actor for recipient,_ in admission.messages))
        self.assertEqual(bystander.calls,[])
    def test_wrench_order_and_following_species_guards_remain(self):
        source=ANVIL.read_text(encoding='utf-8-sig')
        self.assertLess(source.index('anchored = !anchored'),source.index('var/crafting_coefficient'))
        self.assertIn('if (crafting_coefficient < 1.2)',source)
        self.assertIn('(H.gorillaman || H.ant || H.wolfman || H.lizard || H.crab)',source)
        self.assertEqual(source_prefix().count('getStatCoeff("crafting")'),1)

if __name__ == '__main__': unittest.main()
