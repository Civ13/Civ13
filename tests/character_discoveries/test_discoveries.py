"""Offline, fail-closed source projections/contracts; NOT native DM acceptance."""
from pathlib import Path
import hashlib
import html
import json
import re
import unittest

ROOT = Path(__file__).resolve().parents[2]
MIND = (ROOT / 'code/datums/mind.dm').read_text()
BERRIES = (ROOT / 'code/game/objects/structures/berries.dm').read_text()
SMELL = (ROOT / 'code/modules/reagents/reagent_containers.dm').read_text()


def body(source, signature):
    found = re.search(r'^' + re.escape(signature) + r'\n((?:\t[^\n]*\n|\n)*)', source, re.M)
    if not found:
        raise AssertionError(signature)
    return found[1]


def digest(value):
    # Python JSON bytes are not asserted identical to native DM JSON bytes.
    return hashlib.md5(json.dumps(value, separators=(',', ':')).encode()).hexdigest()


def project(source, signature, arguments, instructions, env):
    lines = ['def projected(' + arguments + '):']
    for raw in body(source, signature).splitlines():
        if raw.strip() and not raw.strip().startswith('//'):
            lines.append('    ' * (len(raw) - len(raw.lstrip('\t'))) + instructions[raw.strip()])
    exec('\n'.join(lines), env)
    return env['projected']


def valid_fields(category, identity, context, label, observation, source=MIND):
    instructions = {
        'if (!istext(category) || !length(category) || length(category) > 64 || !istext(identity) || !length(identity) || length(identity) > 256)':
            'if not isinstance(category, str) or not category or len(category) > 64 or not isinstance(identity, str) or not identity or len(identity) > 256:',
        'if (!istext(context) || !length(context) || length(context) > 128 || !istext(label) || !length(label) || length(label) > 96 || !istext(observation) || !length(observation) || length(observation) > 256)':
            'if not isinstance(context, str) or not context or len(context) > 128 or not isinstance(label, str) or not label or len(label) > 96 or not isinstance(observation, str) or not observation or len(observation) > 256:',
        'return FALSE': 'return False', 'return TRUE': 'return True',
    }
    return project(source, '/datum/mind/proc/discovery_fields_valid(category, identity, context, label, observation)',
                   'category, identity, context, label, observation', instructions, {})(category, identity, context, label, observation)


def learn(mind, category, identity, context, label, observation, source=MIND):
    instructions = {
        'if (!discovery_fields_valid(category, identity, context, label, observation))':
            'if not valid_fields(category, identity, context, label, observation):',
        'return FALSE': 'return False',
        'var/discovery_key = md5(json_encode(list(category, identity, context, observation)))':
            'discovery_key = digest([category, identity, context, observation])',
        'if (!islist(learned_discoveries))': "if not isinstance(mind.get('learned_discoveries'), dict):",
        'learned_discoveries = list()': "mind['learned_discoveries'] = {}",
        'if (learned_discoveries[discovery_key] || learned_discoveries.len >= 256)': "if mind['learned_discoveries'].get(discovery_key) or len(mind['learned_discoveries']) >= 256:",
        'learned_discoveries[discovery_key] = list("category" = category, "identity" = identity, "context" = context, "label" = label, "observation" = observation)':
            "mind['learned_discoveries'][discovery_key] = dict(category=category, identity=identity, context=context, label=label, observation=observation)",
        'if (category == "berry_smell")': "if category == 'berry_smell':",
        'var/berry_records = 0': 'berry_records = 0',
        'for (var/existing_key in learned_discoveries)': "for existing_key in mind['learned_discoveries']:",
        'if (!istext(existing_key) || length(existing_key) > 32)': 'if not isinstance(existing_key, str) or len(existing_key) > 32:',
        'continue': 'continue',
        'var/list/existing_record = learned_discoveries[existing_key]': "existing_record = mind['learned_discoveries'][existing_key]",
        'if (islist(existing_record) && existing_record["category"] == "berry_smell")': "if isinstance(existing_record, dict) and existing_record.get('category') == 'berry_smell':",
        'berry_records++': 'berry_records += 1',
        'if (berry_records >= 64)': 'if berry_records >= 64:',
        'return TRUE': 'return True',
    }
    return project(source, '/datum/mind/proc/learn_discovery(category, identity, context, label, observation)',
                   'mind, category, identity, context, label, observation', instructions,
                   {'digest': digest, 'valid_fields': lambda *a: valid_fields(*a, source=source)})(mind, category, identity, context, label, observation)


def render(mind, berry_context, source=MIND):
    instructions = {
        'var/output = "<br><br><b>Discoveries</b><br><br>"': 'output = "<br><br><b>Discoveries</b><br><br>"',
        'if (!islist(learned_discoveries) || !learned_discoveries.len)': "if not isinstance(mind.get('learned_discoveries'), dict) or not mind['learned_discoveries']:",
        'return output + "<i>No discoveries recorded.</i>"': 'return output + "<i>No discoveries recorded.</i>"',
        'var/berry_context = berry_discovery_context()': 'pass',
        'var/omitted = learned_discoveries.len > 256': "omitted = len(mind['learned_discoveries']) > 256",
        'for (var/record_index = 1, record_index <= min(learned_discoveries.len, 256), record_index++)': "for record_index in range(min(len(mind['learned_discoveries']), 256)):",
        'var/discovery_key = learned_discoveries[record_index]': "discovery_key = list(mind['learned_discoveries'])[record_index]",
        'if (!istext(discovery_key) || length(discovery_key) > 32)': 'if not isinstance(discovery_key, str) or len(discovery_key) > 32:',
        'omitted = TRUE': 'omitted = True',
        'var/list/record = learned_discoveries[discovery_key]': "record = mind['learned_discoveries'][discovery_key]",
        'if (!islist(record) || !discovery_fields_valid(record["category"], record["identity"], record["context"], record["label"], record["observation"]))':
            "if not isinstance(record, dict) or not valid_fields(*(record.get(k) for k in ('category', 'identity', 'context', 'label', 'observation'))):",
        'continue': 'continue',
        'output += "<b>[html_encode(record["label"])]</b>: [html_encode(record["observation"])]"': "output += '<b>' + html.escape(record['label']) + '</b>: ' + html.escape(record['observation'])",
        'if (record["category"] == "berry_smell")': "if record.get('category') == 'berry_smell':",
        'output += "<br><i>Observation of a sample, not proof that these berries are safe to eat.</i>"': 'output += "<br><i>Observation of a sample, not proof that these berries are safe to eat.</i>"',
        'if (!berry_context || record["context"] != berry_context)': "if not berry_context or record.get('context') != berry_context:",
        'output += "<br><i>Historical observation: the world\'s berry configuration has changed or is unavailable.</i>"': 'output += "<br><i>Historical observation: the world\'s berry configuration has changed or is unavailable.</i>"',
        'output += "<br><br>"': 'output += "<br><br>"',
        'if (learned_discoveries.len >= 256)': "if len(mind['learned_discoveries']) >= 256:",
        'output += "<i>Discovery notes are full (256 records). Existing knowledge is kept; new observations are not added. Personal notes remain available.</i><br>"': 'output += "<i>Discovery notes are full (256 records). Existing knowledge is kept; new observations are not added. Personal notes remain available.</i><br>"',
        'var/berry_records = 0': 'berry_records = 0',
        'berry_records++': 'berry_records += 1',
        'if (berry_records >= 64)': 'if berry_records >= 64:',
        'output += "<i>Berry smell notes are full (64 records). Existing observations are kept; other categories remain subject to the overall limit.</i><br>"': 'output += "<i>Berry smell notes are full (64 records). Existing observations are kept; other categories remain subject to the overall limit.</i><br>"',
        'if (omitted)': 'if omitted:',
        'output += "<i>Some stored discoveries exceed display limits or are invalid and are not shown. Stored records have not been changed.</i>"': 'output += "<i>Some stored discoveries exceed display limits or are invalid and are not shown. Stored records have not been changed.</i>"',
        'return output': 'return output',
    }
    return project(source, '/datum/mind/proc/discoveries_html()', 'mind, berry_context', instructions,
                   {'html': html, 'valid_fields': lambda *a: valid_fields(*a, source=source)})(mind, berry_context)


class DiscoveryTests(unittest.TestCase):
    def remember(self, mind, context='world-a', label='tinto berries', observation='I smelled a sample and noticed fruit.'):
        return learn(mind, 'berry_smell', '/berries/tinto|tinto', context, label, observation)

    def test_unknown_until_actually_learned(self):
        mind = {}
        self.assertIn('No discoveries recorded.', render(mind, 'world-a'))
        self.assertTrue(self.remember(mind))
        self.assertIn('noticed fruit', render(mind, 'world-a'))

    def test_deduplicates_same_observation_not_distinct_smells(self):
        mind = {}
        self.assertTrue(self.remember(mind))
        self.assertFalse(self.remember(mind))
        self.assertTrue(self.remember(mind, observation='I smelled a sample and noticed bitterness.'))
        self.assertEqual(len(mind['learned_discoveries']), 2)

    def test_private_notes_not_changed_and_two_characters_isolated(self):
        first = {'memory': 'private text', 'notes': {'role': ['private role note']}}
        second = {}
        self.remember(first)
        self.assertEqual(first['memory'], 'private text')
        self.assertEqual(first['notes'], {'role': ['private role note']})
        self.assertIn('No discoveries', render(second, 'world-a'))
        self.assertNotIn('private text', render(first, 'world-a'))

    def test_changed_world_and_unavailable_context_are_historical(self):
        mind = {}
        self.remember(mind)
        self.assertNotIn('Historical observation', render(mind, 'world-a'))
        for context in ('world-b', None):
            self.assertIn('Historical observation', render(mind, context))
        self.assertIn('not proof', render(mind, 'world-a'))
        self.assertTrue(self.remember(mind, context='world-b'))
        self.assertEqual(len(mind['learned_discoveries']), 2)

    def test_html_is_escaped_and_internal_context_is_not_rendered(self):
        mind = {}
        self.remember(mind, context='SECRET-CONFIG', label='<img src=x>', observation='<script>poison</script> & fruit')
        rendered = render(mind, 'SECRET-CONFIG')
        self.assertNotIn('<img', rendered)
        self.assertNotIn('<script>', rendered)
        self.assertIn('&lt;script&gt;', rendered)
        self.assertNotIn('SECRET-CONFIG', rendered)
        self.assertNotIn('/berries/tinto', rendered)

    def test_scalar_record_projection_roundtrip_and_legacy_empty(self):
        mind = {}
        self.remember(mind)
        restored = json.loads(json.dumps(mind))  # Data-shape only, NOT the native saver.
        self.assertEqual(render(mind, 'world-a'), render(restored, 'world-a'))
        self.assertFalse(self.remember(restored))
        self.assertIn('No discoveries', render({}, 'world-a'))

    def test_future_category_is_generic_and_does_not_roll_preferences(self):
        mind = {}
        self.assertTrue(learn(mind, 'food_preference', 'food-category', 'character-version', 'A learned preference', 'Observed only'))
        self.assertNotIn('berry configuration', render(mind, 'other'))
        proc = body(MIND, '/datum/mind/proc/learn_discovery(category, identity, context, label, observation)')
        self.assertNotRegex(proc, r'\b(?:rand|pick|client|prefs)\b')

    def test_invalid_inputs_do_not_allocate_records(self):
        for index in range(5):
            for invalid in (None, '', 42, []):
                args = ['berry_smell', 'identity', 'context', 'label', 'observation']
                args[index] = invalid
                mind = {}
                self.assertFalse(learn(mind, *args))
                self.assertEqual(mind, {})

    def test_projection_rejects_unreviewed_statements(self):
        mutated = MIND.replace('\treturn TRUE\n', '\tunexpected_mutation()\n\treturn TRUE\n', 1)
        with self.assertRaises(KeyError):
            learn({}, 'a', 'b', 'c', 'd', 'e', source=mutated)

    def test_smell_delivery_precedes_learning_and_explicit_actor(self):
        action = body(SMELL, '/obj/item/weapon/reagent_containers/proc/smell_for(mob/user)')
        self.assertLess(action.index('if (isnull(observation))'), action.index('to_chat(user,'))
        self.assertLess(action.index('to_chat(user,'), action.index('record_smell_discovery(user, observation)'))
        self.assertIn('!get_turf(user) || get_turf(user) != get_turf(src)', action)
        self.assertIn('html_encode(observation)', action)
        self.assertIn('smell_for(usr)', body(SMELL, '/obj/item/weapon/reagent_containers/verb/smell() //set amount_per_transfer_from_this'))
        secondary = body(SMELL, '/obj/item/weapon/reagent_containers/secondary_attack_self(mob/living/human/user)')
        self.assertIn('smell_for(user)', secondary)

    def test_only_berry_hook_records_exact_observation(self):
        hook = body(BERRIES, '/obj/item/weapon/reagent_containers/food/snacks/grown/berries/record_smell_discovery(mob/user, observation)')
        self.assertIn('user.mind.current != user', hook)
        self.assertIn('user.stat != CONSCIOUS', hook)
        self.assertIn('"[type]|[randeffect]"', hook)
        self.assertIn('I smelled a sample and noticed [observation].', hook)
        self.assertNotRegex(hook, r'nutriment_desc|i\[2\]|i\[3\]|poisonous|reagent_list')
        default = body(SMELL, '/obj/item/weapon/reagent_containers/proc/record_smell_discovery(mob/user, observation)')
        self.assertEqual(default.strip(), 'return')

    def test_context_is_versioned_configuration_not_a_display_field(self):
        context = body(BERRIES, '/proc/berry_discovery_context()')
        self.assertIn('list("berry-smell-v1", "[map.type]", map.berryeffects)', context)
        schema = (ROOT / 'code/modules/persistence/durable_contract.dm').read_text()
        self.assertIn('"berryeffects"', schema)

    def test_lifecycle_uses_mind_not_account_and_existing_saver(self):
        self.assertIn('var/list/learned_discoveries\n', MIND)
        self.assertNotIn('var/static/list/learned_discoveries', MIND)
        login = (ROOT / 'code/game/mob/new_player/login.dm').read_text()
        self.assertIn('mind = new /datum/mind(key)', login)
        mob = (ROOT / 'code/game/mob/mob.dm').read_text()
        self.assertIn('var/mob/new_player/M = new /mob/new_player()', body(mob, '/mob/verb/abandon_mob()'))
        self.assertIn('mind.key = key', body(MIND, '/mob/living/proc/mind_initialize()'))
        saver = (ROOT / 'code/modules/persistence/functions.dm').read_text()
        self.assertIn('if (src.vars[key] != initial(src.vars[key])', saver)
        encoder = (ROOT / 'code/modules/persistence/saving.dm').read_text()
        self.assertIn('if(islist(value))', encoder)
        self.assertIn('if(istype(value, /datum))', encoder)
        show = body(MIND, '/datum/mind/proc/show_memory(mob/recipient)')
        self.assertIn('recipient.mind != src', show)
        self.assertIn('output += discoveries_html()', show)
        self.assertIn('if (memory)', show)

    def test_smell_algorithm_is_byte_identical_to_audited_master(self):
        # Master 6b075397, original Smell body between taste locals and delivery.
        algorithm = SMELL.split('\tvar/list/tastes = list()', 1)[1].split('\n\treturn english_list(out,', 1)[0]
        self.assertEqual(hashlib.sha256(algorithm.encode()).hexdigest(), '491f611a7e24876a548adf7f7afa7c012b887cf59d70693144f8d1cecf379454')

    def test_mutation_controls_detect_duplicate_and_stale_regressions(self):
        no_dedupe = MIND.replace('\tif (learned_discoveries[discovery_key] || learned_discoveries.len >= 256)\n\t\treturn FALSE\n', '')
        mind = {}
        self.remember(mind)
        self.assertTrue(learn(mind, 'berry_smell', '/berries/tinto|tinto', 'world-a', 'tinto berries', 'I smelled a sample and noticed fruit.', source=no_dedupe))
        # The ordinary dedupe assertion expects False and rejects this mutant.
        stale_line = '\t\t\t\toutput += "<br><i>Historical observation: the world\'s berry configuration has changed or is unavailable.</i>"\n'
        no_stale = MIND.replace(stale_line, '\t\t\t\toutput += "<br><br>"\n')
        self.assertNotEqual(no_stale, MIND)
        self.assertNotIn('Historical observation', render(mind, 'world-b', source=no_stale))
        self.assertIn('Historical observation', render(mind, 'world-b'))

    def test_repeated_renames_keep_first_label_and_single_record(self):
        mind = {}
        self.remember(mind, label='first label')
        for n in range(100):
            self.assertFalse(self.remember(mind, label=f'renamed {n}'))
        self.assertEqual(len(mind['learned_discoveries']), 1)
        self.assertIn('first label', render(mind, 'world-a'))
        self.assertNotIn('renamed', render(mind, 'world-a'))

    def test_all_field_boundaries_and_reject_not_truncate(self):
        limits = (64, 256, 128, 96, 256)
        for index, limit in enumerate(limits):
            args = ['category', 'identity', 'context', 'label', 'observation']
            args[index] = 'x' * limit
            self.assertTrue(learn({}, *args))
            args[index] += 'x'
            mind = {'memory': 'keep', 'notes': {'private': ['keep']}}
            before = json.dumps(mind)
            self.assertFalse(learn(mind, *args))
            self.assertEqual(json.dumps(mind), before)

    def test_berry_capacity_reserves_room_for_other_categories_without_eviction(self):
        mind = {}
        for n in range(64):
            self.assertTrue(self.remember(mind, observation=f'Observed sample {n}'))
        before = json.dumps(mind)
        self.assertFalse(self.remember(mind, observation='extra'))
        self.assertEqual(json.dumps(mind), before)
        self.assertTrue(learn(mind, 'future_taste', 'food', 'character', 'taste', 'observed'))
        self.assertIn('Berry smell notes are full (64 records)', render(mind, 'world-a'))

    def test_overall_capacity_preserves_all_established_records(self):
        mind = {'memory': 'private'}
        for n in range(256):
            self.assertTrue(learn(mind, 'future_taste', str(n), 'character', 'taste', 'observed'))
        before = json.dumps(mind)
        self.assertFalse(learn(mind, 'future_taste', 'extra', 'character', 'taste', 'observed'))
        self.assertEqual(json.dumps(mind), before)
        self.assertIn('Discovery notes are full (256 records)', render(mind, 'world-a'))
        self.assertEqual(render(mind, 'world-a').count('<b>taste</b>'), 256)

    def test_bad_import_is_bounded_without_mutating_stored_data(self):
        mind = {}
        self.remember(mind)
        good = next(iter(mind['learned_discoveries'].values()))
        records = {'oversized-key' * 100: good, 99999999: good, 'bad-shape': ['bad']}
        for field in ('category', 'identity', 'context', 'label', 'observation'):
            records[field] = dict(good, **{field: '<script>' * 1000})
        for n in range(400):
            records[str(n)] = dict(good, label=f'label-{n}')
        mind['learned_discoveries'] = records
        before = json.dumps(mind)
        output = render(mind, 'world-a')
        self.assertEqual(json.dumps(mind), before)
        self.assertNotIn('<script>', output)
        self.assertNotIn('label-300', output)
        self.assertLessEqual(output.count('noticed fruit'), 256)
        self.assertLess(len(output), 650000)
        self.assertIn('Some stored discoveries exceed display limits', output)
        self.assertFalse(self.remember(mind, observation='new'))
        self.assertEqual(json.dumps(mind), before)

    def test_malformed_keys_do_not_break_learning_scan(self):
        mind = {'learned_discoveries': {99999999: {}, 'x' * 10000: {}, 'bad': ['bad']}}
        self.assertTrue(self.remember(mind))
        self.assertEqual(len(mind['learned_discoveries']), 4)

    def test_render_worst_case_escaped_output_is_bounded(self):
        mind = {}
        for n in range(256):
            self.assertTrue(learn(mind, 'future', str(n), 'context', '"' * 96, '"' * 256))
        output = render(mind, 'world-a')
        self.assertLess(len(output), 650000)
        self.assertEqual(output.count('&quot;'), 256 * (96 + 256))

    def test_bounds_negative_controls(self):
        mind = {}
        for n in range(256):
            learn(mind, 'future', str(n), 'context', 'label', 'observation')
        no_limit = MIND.replace('\tif (learned_discoveries[discovery_key] || learned_discoveries.len >= 256)\n\t\treturn FALSE\n', '')
        self.assertTrue(learn(mind, 'future', 'extra', 'context', 'label', 'observation', source=no_limit))
        self.assertEqual(len(mind['learned_discoveries']), 257)
        # Ordinary capacity assertion rejects this mutation; baseline render still
        # enforces its independent inspection bound on the oversized imported list.
        self.assertEqual(render(mind, 'context').count('<b>label</b>'), 256)
        no_category_limit = MIND.replace('\t\tif (berry_records >= 64)\n\t\t\treturn FALSE\n', '')
        berries = {}
        for n in range(64):
            self.remember(berries, observation=str(n))
        self.assertTrue(learn(berries, 'berry_smell', 'berry', 'world', 'label', 'extra', source=no_category_limit))
        self.assertEqual(len(berries['learned_discoveries']), 65)

    def test_ci_step_is_narrow_offline_and_explicitly_guarded(self):
        workflow = (ROOT / '.github/workflows/test.yml').read_text()
        name = '      - name: Test character discoveries and berry smell contracts offline\n'
        self.assertEqual(workflow.count(name), 1)
        block = name + workflow.split(name, 1)[1].split('      - name:', 1)[0]
        self.assertEqual(block, name +
            "        if: needs.changes.outputs.extensive == 'true' || contains(fromJSON(needs.changes.outputs.new_tests), 'tests/character_discoveries')\n" +
            "        run: python3 -I -B -m unittest discover -s tests/character_discoveries -p 'test_*.py' -v\n")
        job = re.search(r'^  evidence-checker:\n(.*?)(?=^  [A-Za-z0-9_-]+:|\Z)', workflow, re.M | re.S)
        self.assertIsNotNone(job)
        self.assertIn(name, job[1])

    def test_threshold_remains_strictly_above_fifteen_percent(self):
        smell = body(SMELL, '/obj/item/weapon/reagent_containers/proc/smell_description()')
        self.assertIn('if (percent > 15)', smell)
        self.assertIn('else if (percent <= 15)\n\t\t\t\tcontinue', smell)
        self.assertIn('if (!R.taste_mult)\n\t\t\tcontinue', smell)
        self.assertIn('return english_list(out, "something indescribable")', smell)
        self.assertNotIn('berryeffects', smell)


if __name__ == '__main__':
    unittest.main()
