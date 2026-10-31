"""Offline specification and production-source contracts, not DM execution."""
import random
import unittest

from test_foundations import BASIC, TRAITS, definitions, read, validate


def sample(table, roll, trace=None):
    """Model the bounded prefix sampler against the independent validator spec."""
    if trace is None:
        trace = {'attempts': 0, 'candidates': 0}
    if not isinstance(table, dict) or len(table) > 64:
        return None
    choices, result, matches = [], None, 0
    for choice in table:
        singleton = [choice]
        if validate(singleton, table, False):
            continue
        choices.append(choice)
        if points(singleton, table) == 0:
            matches += 1
            if roll(matches) == 1:
                result = singleton.copy()
    for _ in range(64):
        trace['attempts'] += 1
        order = choices.copy()
        for i in range(len(order), 1, -1):
            other = roll(i) - 1
            order[i - 1], order[other] = order[other], order[i - 1]
        selected = []
        for choice in order:
            if roll(2) == 1:
                continue
            trace['candidates'] += 1
            candidate = selected + [choice]
            if validate(candidate, table, False):
                continue
            selected = candidate
            if points(selected, table) == 0:
                matches += 1
                if roll(matches) == 1:
                    result = selected.copy()
    if (not isinstance(result, list) or not result or validate(result, table)
            or points(result, table) != 0):
        return None
    return result


def points(choices, table):
    return sum(table[name][0] for name in choices)


def admit(current, revision, token, candidate, table, owner=True, usable=True):
    """Atomic UI admission spec: malformed links/results cannot alter choices."""
    if (not owner or not usable or not revision or not isinstance(token, str)
            or token != str(revision)):
        return current, revision, False
    revision += 1
    if (not isinstance(candidate, list) or not candidate or validate(candidate, table)
            or points(candidate, table) != 0):
        return current, revision, False
    return candidate, revision, True


def generator_contract(source):
    body = source.split('/proc/random_zero_point_traits(', 1)[1]
    for guard in ('trait_list.len > 64', 'attempt <= 64', 'i > 1, i--',
                  'get_trait_selection_error(singleton, FALSE)',
                  'get_trait_selection_error(candidate, FALSE)',
                  'get_trait_selection_error(result)', 'check_trait_points(result) != 0',
                  '!islist(result) || !result.len', 'random_source.roll(',
                  'result = singleton.Copy()', 'result = selected.Copy()'):
        if guard not in body:
            raise AssertionError(guard)
    if any(word in body for word in ('while (', 'sleep(', 'spawn(', 'pref.traits', 'trait_list[')):
        raise AssertionError('unbounded, yielding, stateful or duplicated catalog rules')


def ui_contract(source):
    body = source.split('else if (!isnull(href_list["random_traits"]))', 1)[1]
    body = body.split('else if (href_list["add_traits"])', 1)[0]
    for guard in ('user != preference_mob()', 'user.client.prefs != pref',
                  '!CanUseTopic(user)', '!istext(href_list["random_traits"])',
                  'href_list["random_traits"] != "[trait_random_revision]"',
                  '!islist(candidate) || !candidate.len', 'get_trait_selection_error(candidate)',
                  'check_trait_points(candidate) != 0', 'return TOPIC_REFRESH'):
        if guard not in body:
            raise AssertionError(guard)
    consume = body.index('trait_random_revision++')
    generate = body.index('random_zero_point_traits()')
    validate_at = body.index('get_trait_selection_error(candidate)')
    commit = body.index('pref.traits = candidate')
    save = body.index('pref.save_preferences()')
    if not consume < generate < validate_at < commit < save:
        raise AssertionError('admit/generate/validate/commit/save ordering')
    if body.count('pref.traits') != 1 or 'input(' in body or 'alert(' in body or 'sleep(' in body:
        raise AssertionError('partial mutation or yielding dialog')


class RandomTraits(unittest.TestCase):
    def setUp(self):
        self.table = definitions(read(TRAITS))

    def test_real_catalog_zero_valid_nonempty_and_varied_across_repeated_clicks(self):
        rng = random.Random(3425)
        found = set()
        sizes = set()
        table_before = repr(self.table)
        current = ['Blind']
        for revision in range(1, 201):
            trace = {'attempts': 0, 'candidates': 0}
            candidate = sample(self.table, lambda upper: rng.randint(1, upper), trace)
            self.assertTrue(candidate)
            self.assertIsNone(validate(candidate, self.table))
            self.assertEqual(points(candidate, self.table), 0)
            self.assertEqual(len(candidate), len(set(candidate)))
            self.assertLessEqual(trace['candidates'], 64 * len(self.table))
            self.assertEqual(trace['attempts'], 64)
            current, _, saved = admit(current, revision, str(revision), candidate, self.table)
            self.assertTrue(saved)
            found.add(tuple(sorted(current)))
            sizes.add(len(current))
        self.assertGreater(len(found), 20)
        self.assertGreater(len(sizes), 2)
        self.assertTrue(any('Baldness' in traits for traits in found))
        self.assertTrue(any('Dwarfism' in traits for traits in found))
        self.assertEqual(repr(self.table), table_before)

    def test_zero_cost_fallback_even_with_skip_everything_rng(self):
        candidate = sample(self.table, lambda upper: 1)
        self.assertTrue(candidate)
        self.assertEqual(points(candidate, self.table), 0)
        self.assertEqual(len(candidate), 1)

    def test_singletons_pairs_and_intermediate_positive_total(self):
        # Highest roll includes all entries in deterministic order. Positive first
        # must remain eligible until the later negative choice balances it.
        for table in ({'Zero': (0, [], '')},
                      {'Positive': (3, [], ''), 'Negative': (-3, [], '')},
                      {'Positive': (3, [], ''), 'One': (-1, [], ''), 'Two': (-2, [], '')}):
            candidate = sample(table, lambda upper: upper)
            self.assertTrue(candidate)
            self.assertEqual(points(candidate, table), 0)
            self.assertIsNone(validate(candidate, table))
        self.assertEqual(len(candidate), 3)

    def test_asymmetric_conflicts_and_catalog_eligibility(self):
        for table in ({'A': (1, ['B'], ''), 'B': (-1, [], '')},
                      {'B': (-1, [], ''), 'A': (1, ['B'], '')},
                      {'Self': (0, ['Self'], '')}):
            self.assertIsNone(sample(table, lambda upper: upper))
        table = {'Allowed': (0, [], '')}
        self.assertEqual(sample(table, lambda upper: upper), ['Allowed'])
        for malformed in (['Allowed', 'Disabled'], [7], ['Allowed', 'Allowed']):
            self.assertFalse(admit(['old'], 1, '1', malformed, table)[2])

    def test_termination_impossible_exhausted_and_oversized(self):
        cases = ({}, {'Positive': (1, [], '')}, {'Negative': (-1, [], '')},
                 {'Odd': (3, [], ''), 'Even': (-2, [], '')})
        for table in cases:
            trace = {'attempts': 0, 'candidates': 0}
            self.assertIsNone(sample(table, lambda upper: upper, trace))
            self.assertEqual(trace['attempts'], 64)
            self.assertLessEqual(trace['candidates'], 64 * len(table))
        # Exists, but this deterministic RNG skips every trial. Exhaustion is
        # a supported failure, never permission to return an invalid/empty set.
        table = {'Plus': (1, [], ''), 'Minus': (-1, [], '')}
        self.assertIsNone(sample(table, lambda upper: 1))
        for table in (None, [], {str(i): (0, [], '') for i in range(65)}):
            self.assertIsNone(sample(table, lambda upper: self.fail('must not call RNG')))

    def test_failure_preserves_exact_old_object_and_no_save(self):
        for old in (None, 'malformed', ['Old'], ['Baldness', 'Baldness'], ['Agile']):
            for bad in (None, [], ['Agile'], ['Blind'], ['Short', 'Tall'],
                        ['Baldness', 'Baldness'], ['Disabled'], [7]):
                result, revision, saved = admit(old, 1, '1', bad, self.table)
                self.assertIs(result, old)
                self.assertEqual(revision, 2)
                self.assertFalse(saved)
            result, _, saved = admit(old, 1, '1', ['Baldness'], self.table)
            self.assertEqual(result, ['Baldness'])
            self.assertTrue(saved)

    def test_stale_replay_wrong_owner_and_malformed_link(self):
        old = ['Blind']
        for token in (None, '', 1, '01', '1.0', '2', '-1', '1;add_traits=1', ['1']):
            result, revision, saved = admit(old, 1, token, ['Baldness'], self.table)
            self.assertIs(result, old)
            self.assertEqual(revision, 1)
            self.assertFalse(saved)
        for flags in ({'owner': False}, {'usable': False}):
            self.assertIs(admit(old, 1, '1', ['Baldness'], self.table, **flags)[0], old)
        result, revision, saved = admit(old, 1, '1', ['Baldness'], self.table)
        self.assertTrue(saved)
        replayed, _, saved = admit(result, revision, '1', ['Dwarfism'], self.table)
        self.assertIs(replayed, result)
        self.assertFalse(saved)
        # Redraw advances revision again; new links can randomize repeatedly.
        self.assertTrue(admit(result, revision + 1, str(revision + 1), ['Dwarfism'], self.table)[2])

    def test_production_contracts_and_negative_controls(self):
        traits, basic = read(TRAITS), read(BASIC)
        generator_contract(traits)
        ui_contract(basic)
        self.assertIn('random_traits=[trait_random_revision]', basic)
        self.assertIn("'>Random</a> (total 0)", basic)
        self.assertIn('var/tmp/trait_random_revision = 0', basic)
        self.assertIn('return rand(1, upper)', traits)
        self.assertGreaterEqual(basic.count('trait_random_revision++'), 2)
        for old, new in (('attempt <= 64', 'TRUE'),
                         ('get_trait_selection_error(candidate, FALSE)', 'FALSE'),
                         ('get_trait_selection_error(singleton, FALSE)', 'FALSE'),
                         ('get_trait_selection_error(result)', 'FALSE'),
                         ('check_trait_points(result) != 0', 'FALSE'),
                         ('result = selected.Copy()', 'result = selected'),
                         ('trait_list.len > 64', 'FALSE')):
            with self.subTest(generator_guard=old), self.assertRaises(AssertionError):
                generator_contract(traits.replace(old, new))
        for old, new in (('href_list["random_traits"] != "[trait_random_revision]"', 'FALSE'),
                         ('user.client.prefs != pref', 'FALSE'),
                         ('!istext(href_list["random_traits"])', 'FALSE'),
                         ('get_trait_selection_error(candidate)', 'FALSE'),
                         ('check_trait_points(candidate) != 0', 'FALSE'),
                         ('pref.traits = candidate', 'pref.traits = list()')):
            with self.subTest(ui_guard=old), self.assertRaises((AssertionError, ValueError)):
                ui_contract(basic.replace(old, new))


if __name__ == '__main__':
    unittest.main()
