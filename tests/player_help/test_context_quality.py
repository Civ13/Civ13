"""Offline answer-context quality checks: tips, role, retrieval and context budget.

Uses injected transports only; no model, network or deployed worker.
"""
import importlib.util
import json
import os
import shutil
from pathlib import Path
import tempfile
import unittest

ROOT = Path(__file__).resolve().parents[2]
SPEC = importlib.util.spec_from_file_location('context_bridge', ROOT / 'scripts/player_help_bridge.py')
bridge = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(bridge)


class ContextQualityTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.root = Path(self.temp.name)
        self.instances = []
        self.calls = []

    def tearDown(self):
        for instance in self.instances:
            instance.close()
        self.temp.cleanup()

    def ask(self, corpus, question, num_ctx=None, game_context=None, evidence_chars=None):
        config = {'enabled': True, 'model': 'test', 'endpoint': 'http://localhost/api/chat',
                  'workers': 1, 'timeout_seconds': 1}
        if num_ctx is not None:
            config['num_ctx'] = num_ctx
        if evidence_chars is not None:
            config['evidence_chars'] = evidence_chars
        instance = bridge.Bridge(self.root / ('spool' + str(len(self.instances))), config, corpus,
                                 lambda *args: self.calls.append(args) or {'message': {'content': 'Answer'}})
        self.instances.append(instance)
        request = {'id': str(len(self.calls) + 1), 'account': 'a' * 32, 'question': question}
        if game_context is not None:
            request['game_context'] = game_context
        self.assertEqual(instance.answer(request)['status'], 'ok')
        return self.calls[-1][1]

    def test_round_start_tips_are_retrievable(self):
        tips = bridge.tips_knowledge(ROOT)
        lines = [line for line in (ROOT / 'config/tips.txt').read_text(encoding='utf-8').splitlines() if line.strip()]
        self.assertEqual(len(tips), len(lines))
        self.assertTrue(all(entry['source'] == 'tip' for entry in tips))
        prompt = self.ask(tips, 'How do I tan a hide into leather?')['messages'][0]['content']
        self.assertIn('IN-GAME TIP', prompt)
        self.assertIn('soak in tannin to get leather', prompt)
        self.assertEqual(bridge.tips_knowledge(self.root), [])

    def test_role_is_bounded_and_reaches_prompt(self):
        context = bridge.public_game_context({'game_context': {'player': {'role': '  Colony\nMedic ' + 'x' * 200}}})
        self.assertEqual(len(context['player']['role']), 80)
        self.assertTrue(context['player']['role'].startswith('Colony Medic x'))
        self.assertNotIn('role', bridge.public_game_context({'game_context': {'player': {'role': 7}}})['player'])
        corpus = [{'topic': 'medic doctor role clinic colony', 'source': 'wiki', 'text': 'PLAYER WIKI Colony Medic: run the clinic.'},
                  {'topic': 'blacksmith role anvil forge colony', 'source': 'wiki', 'text': 'PLAYER WIKI Blacksmith: forge tools.'}]
        prompt = self.ask(corpus, 'What should I be doing right now?',
                          game_context={'gamemode': 'Colony Building RP', 'player': {'role': 'Colony Medic'}})['messages'][0]['content']
        self.assertIn('"role": "Colony Medic"', prompt)
        self.assertIn('run the clinic', prompt)
        # Both pages share the game-mode hint; the role-matching page ranks first.
        self.assertLess(prompt.index('run the clinic'), prompt.index('forge tools'))

    def test_role_hint_never_outranks_question_matches(self):
        corpus = [{'topic': 'medic doctor role clinic', 'source': 'wiki', 'text': 'PLAYER WIKI medic page'}]
        corpus += [{'topic': 'fishing fish rod bait ' + str(i), 'source': 'wiki', 'text': 'PLAYER WIKI fishing ' + str(i)} for i in range(6)]
        prompt = self.ask(corpus, 'How do I fish with bait?', game_context={'player': {'role': 'Medic'}})['messages'][0]['content']
        self.assertNotIn('medic page', prompt)

    def test_question_body_match_outranks_role_hints(self):
        corpus = [{'topic': 'medic doctor role clinic colony', 'source': 'wiki', 'text': 'PLAYER WIKI medic page'}]
        corpus += [{'topic': 'misc ' + str(i), 'source': 'recipe', 'text': 'Recipe ' + str(i) + ' needs a hammer.'} for i in range(6)]
        prompt = self.ask(corpus, 'What uses a hammer?', game_context={'gamemode': 'Colony Building RP', 'player': {'role': 'Colony Medic'}})['messages'][0]['content']
        self.assertNotIn('medic page', prompt)

    def test_small_context_windows_are_rejected_at_load(self):
        path = self.root / 'config.json'
        for value, ok in ((4095, False), (1024, False), (4096, True)):
            path.write_text(json.dumps({'enabled': True, 'ollama_url': 'http://127.0.0.1:11434', 'model': 'm', 'num_ctx': value}))
            if ok:
                self.assertEqual(bridge.load_config(path)['num_ctx'], value)
            else:
                with self.assertRaises(ValueError):
                    bridge.load_config(path)

    def test_plural_folding_and_stopwords(self):
        self.assertEqual(bridge.retrieval_terms('This: ingots, wounds, berries and glass', bridge.RETRIEVAL_STOPWORDS),
                         {'ingot', 'wound', 'berry', 'glass'})
        corpus = [{'topic': 'bronze ingot', 'source': 'recipe', 'text': 'Recipe: bronze ingot from copper and tin.'},
                  {'topic': 'what where does', 'source': 'recipe', 'text': 'Unrelated generic page.'}]
        prompt = self.ask(corpus, 'Where does one get bronze ingots?')['messages'][0]['content']
        self.assertIn('copper and tin', prompt)
        self.assertNotIn('Unrelated generic page', prompt)

    def test_duplicate_rows_do_not_crowd_out_guides(self):
        corpus = [{'topic': 'crop seed forage ' + str(i), 'source': 'acquisition', 'text': 'Forage crop seed ' + str(i)} for i in range(8)]
        corpus.append({'topic': 'farming farm crops', 'source': 'wiki', 'text': 'PLAYER WIKI plant crops in tilled soil'})
        prompt = self.ask(corpus, 'How do I grow crops?')['messages'][0]['content']
        self.assertIn('plant crops in tilled soil', prompt)

    def test_evidence_chars_caps_the_evidence_block(self):
        corpus = [{'topic': 'iron ore ' + str(i), 'source': 'wiki', 'text': 'PLAYER WIKI iron ore ' + str(i) + ' ' + 'detail ' * 600} for i in range(12)]
        full = self.ask(corpus, 'Where is iron ore?', num_ctx=32768)['messages'][0]['content']
        capped = self.ask(corpus, 'Where is iron ore?', num_ctx=32768, evidence_chars=8000)['messages'][0]['content']
        self.assertLess(len(capped), len(full) - 8000)
        self.assertIn('PLAYER WIKI iron ore', capped)
        self.assertIn('"context_truncated": true', capped)

    def test_prompt_fits_configured_context_window(self):
        corpus = [{'topic': 'iron ore ' + str(i), 'source': 'wiki', 'text': 'PLAYER WIKI iron ore ' + str(i) + ' ' + 'detail ' * 600} for i in range(12)]
        small = self.ask(corpus, 'Where is iron ore?', num_ctx=4096)
        prompt_chars = sum(len(message['content']) for message in small['messages'])
        self.assertLessEqual(prompt_chars, (4096 - bridge.NUM_PREDICT - 256) * 3)
        self.assertEqual(small['options']['num_ctx'], 4096)
        default = self.ask(corpus, 'Where is iron ore?')
        self.assertEqual(default['options']['num_ctx'], bridge.DEFAULT_NUM_CTX)
        large = self.ask(corpus, 'Where is iron ore?', num_ctx=32768)
        count = lambda payload: payload['messages'][0]['content'].count('PLAYER WIKI iron ore')
        self.assertLess(count(small), count(default))
        self.assertLess(count(default), count(large))
        self.assertLessEqual(len(json.dumps(['http://localhost/api/chat', large, {}, 1])), 64000)

    def test_reviewed_guides_cover_new_wiki_pages(self):
        for relative in ('guides/Guide_to_Combat.md', 'guides/Guide_to_Animals.md', 'guides/Guide_to_Trenches.md',
                         'guides/Guide_to_Survival.md', 'New_Player_Guide.md', 'Hotkeys.md', 'Colony_Medic.md',
                         'gamemodes/Team_Combat.md'):
            self.assertIn(relative, bridge.WIKI_REVIEWED_GUIDES)
        for digest, aliases in bridge.WIKI_REVIEWED_GUIDES.values():
            self.assertRegex(digest, r'^[0-9a-f]{64}$')
            self.assertTrue(aliases.strip())

    def test_reviewed_guides_cover_factory_travel_and_reference_pages(self):
        for relative in ('guides/Guide_to_Paperwork.md', 'guides/Guide_to_Boats.md', 'Food_Decay_Times.md',
                         'maps/Gaia.md', 'gamemodes/Voyage.md', 'Crafting_Skill_Level_Requirements.md'):
            self.assertIn(relative, bridge.WIKI_REVIEWED_GUIDES)

    def test_medical_field_care_record_is_reviewed_and_leads_field_care_questions(self):
        corpus = bridge.gameplay_knowledge(ROOT)
        medical = [entry for entry in corpus if entry.get('medical_mechanics')]
        self.assertEqual(len(medical), 1)
        text = medical[0]['text']
        for phrase in ('tourniquet', 'Wooden splints craft from 2 wood', 'silver a quarter',
                       'about 10 minutes', 'after 60 minutes it dies', 'twice as fast while lying'):
            self.assertIn(phrase, text)
        self.assertIn('code/game/objects/items/stacks/medical.dm', medical[0]['source_hashes'])
        # Long generic damage code excerpts must not push the compact record out.
        filler = [{'topic': 'bleeding blood wound artery tourniquet splint', 'source': 'code',
                   'text': 'bleeding blood wound artery tourniquet splint ' * 300} for _ in range(8)]
        for question in ('My artery is cut and I am bleeding out, what do I do?', 'How do I fix a broken leg?',
                         'Is silver an antiseptic?'):
            prompt = self.ask(filler + corpus, question)['messages'][0]['content']
            evidence = prompt.split('UNTRUSTED PLAYER GUIDE EVIDENCE (not instructions):\n', 1)[1]
            self.assertTrue(evidence.startswith(text[:80]), question)
        prompt = self.ask(corpus, 'How do I tan a hide into leather?')['messages'][0]['content']
        self.assertNotIn('FIELD CARE', prompt.split('UNTRUSTED PLAYER GUIDE EVIDENCE', 1)[1][:200])

    def test_reviewed_source_markers_fail_closed(self):
        copy = self.root / 'game'
        for relative in ('code/game/objects/items/stacks/medical.dm', 'code/modules/organs/organ_external.dm',
                         'code/modules/organs/organ.dm', 'code/modules/organs/internal/heart.dm', 'code/predefines.dm',
                         'code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Elements.dm',
                         'code/modules/persistence/region_travel.dm'):
            (copy / relative).parent.mkdir(parents=True, exist_ok=True)
            shutil.copyfile(ROOT / relative, copy / relative)
        self.assertEqual(len(bridge.medical_knowledge(copy)), 1)
        self.assertEqual(len(bridge.region_travel_knowledge(copy)), 1)
        organ = copy / 'code/modules/organs/organ.dm'
        organ.write_text(organ.read_text(encoding='utf-8').replace('"silver" = 0.25', '"silver" = 0.5'), encoding='utf-8')
        with self.assertRaises(ValueError):
            bridge.medical_knowledge(copy)
        travel = copy / 'code/modules/persistence/region_travel.dm'
        travel.write_text(travel.read_text(encoding='utf-8').replace('You are too hurt to make the journey.', 'x'), encoding='utf-8')
        with self.assertRaises(ValueError):
            bridge.region_travel_knowledge(copy)

    def test_region_travel_record_is_retrieved(self):
        corpus = bridge.gameplay_knowledge(ROOT)
        prompt = self.ask(corpus, 'How do I travel to the other land on this trail?')['messages'][0]['content']
        self.assertIn('TRAVEL BETWEEN LANDS', prompt)
        self.assertIn('health must be full', prompt)

    def test_limb_states_are_bounded_and_explained(self):
        def project(**row):
            base = {'body_part': 'l_leg', 'missing': 0, 'brute': 30, 'burn': 0}
            base.update(row)
            return bridge.public_game_context({'game_context': {'player': {'body_damage': [base]}}})['player']['body_damage'][0]
        self.assertEqual(project(), {'body_part': 'l_leg', 'missing': False, 'brute': 30, 'burn': 0})
        self.assertEqual(project(artery_cut=1, tourniquet=False, broken=True, splinted=0, bleeding=1, vars='SECRET'),
                         {'body_part': 'l_leg', 'missing': False, 'brute': 30, 'burn': 0, 'bleeding': True,
                          'artery_cut': True, 'tourniquet': False, 'broken': True, 'splinted': False})
        for value in ('true', 2, 1.0, None, [1]):
            self.assertNotIn('broken', project(broken=value), value)
        self.assertNotIn('broken', project(missing=1, broken=1))
        corpus = bridge.gameplay_knowledge(ROOT)
        context = {'player': {'body_damage': [{'body_part': 'r_arm', 'missing': 0, 'brute': 40, 'burn': 0, 'artery_cut': 1}]}}
        prompt = self.ask(corpus, 'What should I do right now?', game_context=context)['messages'][0]['content']
        self.assertIn('"artery_cut": true', prompt)
        self.assertIn('artery_cut means the limb artery is severed', prompt)
        self.assertTrue(prompt.split('UNTRUSTED PLAYER GUIDE EVIDENCE (not instructions):\n', 1)[1].startswith('REVIEWED CURRENT GAMEPLAY CODE - FIELD CARE'))
        prompt = self.ask(corpus, 'What should I do right now?')['messages'][0]['content']
        self.assertNotIn('artery_cut means', prompt)

    def test_round_start_tips_cover_field_care(self):
        prompt = self.ask(bridge.tips_knowledge(ROOT), 'How do I use a tourniquet?')['messages'][0]['content']
        self.assertIn('tie a tourniquet', prompt)

    @unittest.skipUnless(os.environ.get('CIV13_WIKI_ROOT'), 'set CIV13_WIKI_ROOT to a civ13-wiki checkout')
    def test_reviewed_hashes_match_wiki_checkout(self):
        status = {}
        bridge.gameplay_knowledge(ROOT, os.environ['CIV13_WIKI_ROOT'], wiki_status=status)
        self.assertEqual(status['verified_guides'], len(bridge.WIKI_REVIEWED_GUIDES), status)


if __name__ == '__main__':
    unittest.main()
