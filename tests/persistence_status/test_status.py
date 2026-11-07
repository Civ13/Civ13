"""Offline execution of complete report-census helpers and faction tally block.

Native human registration, job datums, area/type queries and output are fake
boundaries. This is production control-flow evidence, not native save/load QA.
"""
from pathlib import Path
import importlib.util
import re
from types import SimpleNamespace as NS
import unittest

ROOT = Path(__file__).resolve().parents[2]
COUNTS = (ROOT / 'code/modules/1713/battlereport_variables.dm').read_text()
REPORT = (ROOT / 'code/modules/admin/verbs/1713.dm').read_text()
FACTIONS = (ROOT / 'code/game/mob/groups/factions.dm').read_text()
spec = importlib.util.spec_from_file_location('status_dm_adapter', ROOT / 'tests/save_movement/source_adapter.py')
adapter = importlib.util.module_from_spec(spec)
spec.loader.exec_module(adapter)
DEFINES = (ROOT / 'code/predefines.dm').read_text()
STATES = {key: int(re.search(r'^#define\s+' + key + r'\s+(\d+)', DEFINES, re.M)[1])
          for key in ('CONSCIOUS', 'UNCONSCIOUS', 'DEAD')}


class DMList:
    def __init__(self, *values):
        self.keys = list(values)
        self.associations = {}

    def __getitem__(self, key):
        if isinstance(key, int):
            return self.keys[key - 1]
        return self.associations.get(key)

    def __setitem__(self, key, value):
        if isinstance(key, int):
            self.keys[key - 1] = value
        else:
            if key not in self.keys:
                self.keys.append(key)
            self.associations[key] = value

    def __iter__(self):
        return iter(self.keys)

    def __bool__(self):
        # A non-null native DM list is truthy even when empty.
        return True

    @property
    def len(self):
        return len(self.keys)

    def __iadd__(self, other):
        for key in other:
            self[key] = other[key]
        return self


def dm_assoc(key, value):
    result = DMList()
    result[key] = value
    return result


def human(faction='CIVILIAN', stat=None, **kwargs):
    values = dict(original_job=NS(base_type_flag=lambda: faction),
                  stat=STATES['CONSCIOUS'] if stat is None else stat,
                  health=100, loc=object(), restoring=False, civilization='none',
                  type='/mob/living/human', area='/area/caribbean', uid='unused')
    values.update(kwargs)
    return NS(**values)


def istype(value, type_path):
    path = value if isinstance(value, str) else getattr(value, 'type', '')
    return bool(path and (path == type_path or path.startswith(type_path + '/')))


def environment(humans=()):
    return dict(STATES, human_mob_list=list(humans), world=list(humans), list=DMList,
                typed_iter=lambda items, path: [item for item in items if istype(item, path)],
                istype=istype, istext=lambda value: isinstance(value, str), length=len,
                get_area=lambda item: item.area,
                CORPSE='/mob/living/human/corpse', ADMIN_AREA='/area/caribbean/admin',
                dm_assoc=dm_assoc)


def project(source, declaration, args, env):
    # Extend the existing audited translator only for the native interpolated
    # output strings and the pre-existing faction-table counted loop/list literal.
    source = source.replace('/mob/living/human/corpse', 'CORPSE')
    source = source.replace('for (var/i=1,i<=map.custom_faction_nr.len,i++)',
                            'for (i in range(1, map.custom_faction_nr.len + 1))')
    source = source.replace('list(map.custom_faction_nr[i] = nu)',
                            'dm_assoc(map.custom_faction_nr[i], nu)')
    for template in re.findall(r'"([^"\n]*\[[^"\n]*)"', source):
        # These selected helpers have no nested string literals or bracket-index
        # depth > 1. Reject anything outside those known forms.
        def expression(match):
            return '{' + match[1] + '}'
        replacement = re.sub(r'\[((?:[^\[\]]|\[\d+\])+)\]', expression, template)
        if '[' in replacement.replace('counts[1]', '').replace('counts[2]', '').replace('counts[3]', ''):
            raise AssertionError('Unsupported interpolation: ' + template)
        source = source.replace('"' + template + '"', 'f"' + replacement + '"')
    return adapter.project(source, declaration, args, env)


def census(humans, source=COUNTS, env=None):
    env = environment(humans) if env is None else env
    return project(source, '/proc/persistence_battle_report_counts', '', env)()


def line(faction_name, faction, counts):
    env = environment()
    return project(COUNTS, '/proc/persistence_battle_report_line',
                   'faction_name, faction, factions', env)(faction_name, faction, counts)


def largest(humans, registered, source=REPORT):
    start = source.index('\tvar/msg_factions = ""')
    end = source.index('\n\tif (map && !map.faction_organization.Find(BRITISH))', start)
    # Complete existing largest-faction selection, including its map admission.
    selected = '/proc/probe()\n' + source[start:end] + '\n\treturn relpf\n'
    env = environment(humans)
    constants = set(re.findall(r'\bMAP_\w+', selected))
    env.update({name: name for name in constants})
    env['map'] = NS(civilizations=True, ID='MAP_NOMADS', custom_faction_nr=DMList(*registered))
    result = project(selected, '/proc/probe', '', env)()
    return result, env['map'].facl


class PersistenceStatus(unittest.TestCase):
    def test_fresh_load_counts_dead_without_life_or_death_hooks(self):
        bodies = [human(), human(stat=STATES['DEAD']), human(stat=STATES['UNCONSCIOUS'])]
        counts = census(bodies)
        self.assertEqual(counts['CIVILIAN'].keys, [2, 1, 1])
        self.assertEqual(line('Civilians', 'CIVILIAN', counts),
                         'Civilians: 2 alive (1 heavily injured or unconscious), 1 dead bodies currently present.')

    def test_repeated_load_discards_old_uids_without_mutating_history(self):
        history = DMList('old-uid', 'another-deleted-uid')
        env = environment([human(stat=STATES['DEAD'], uid='restored-uid')])
        env.update(dead_civilians=history, alive_civilians=DMList('stale-living-uid'), recently_died=DMList('restored-uid'))
        first = census([], env=env)
        env['human_mob_list'] = [human(uid='different-uid')]
        second = census([], env=env)
        self.assertEqual(first['CIVILIAN'].keys, [0, 1, 0])
        self.assertEqual(second['CIVILIAN'].keys, [1, 0, 0])
        self.assertEqual(history.keys, ['old-uid', 'another-deleted-uid'])
        self.assertEqual(env['alive_civilians'].keys, ['stale-living-uid'])
        self.assertEqual(env['recently_died'].keys, ['restored-uid'])

    def test_revival_deletion_and_missing_body_are_current_not_cumulative(self):
        body = human(stat=STATES['DEAD'])
        self.assertEqual(census([body])['CIVILIAN'].keys, [0, 1, 0])
        body.stat = STATES['CONSCIOUS']
        self.assertEqual(census([body])['CIVILIAN'].keys, [1, 0, 0])
        body.loc = None
        self.assertIsNone(census([body])['CIVILIAN'])
        self.assertIsNone(census([])['CIVILIAN'])

    def test_injury_is_subset_of_living_and_dead_is_disjoint(self):
        bodies = [human(), human(health=0), human(stat=STATES['UNCONSCIOUS']),
                  human(stat=STATES['DEAD'], health=-100)]
        self.assertEqual(census(bodies)['CIVILIAN'].keys, [3, 1, 2])

    def test_admin_decorative_unlocated_restoring_and_jobless_are_excluded(self):
        excluded = [human(area='/area/caribbean/admin'), human(area='/area/caribbean/admin/subtype'),
                    human(type='/mob/living/human/corpse/child'), human(loc=None),
                    human(restoring=True), human(original_job=None)]
        self.assertIsNone(census(excluded)['CIVILIAN'])
        self.assertEqual(census(excluded + [human()])['CIVILIAN'].keys, [1, 0, 0])

    def test_clientless_contained_humans_are_counted_by_job_faction(self):
        bodies = [human('BRITISH', civilization='Different custom name', client=None), human('CAFR'), human('TSFSR')]
        counts = census(bodies)
        for faction in ('BRITISH', 'CAFR', 'TSFSR'):
            self.assertEqual(counts[faction].keys, [1, 0, 0])

    def test_jobs_without_a_valid_faction_flag_are_ignored(self):
        counts = census([human(None), human(0), human(''), human()])
        self.assertEqual(counts.keys, ['CIVILIAN'])
        self.assertEqual(counts['CIVILIAN'].keys, [1, 0, 0])

    def test_empty_factions_show_zero_without_mortality_claim(self):
        text = line('Civilians', 'CIVILIAN', census([]))
        self.assertEqual(text, 'Civilians: 0 alive (0 heavily injured or unconscious), 0 dead bodies currently present.')
        self.assertNotIn('Mortality', text)
        self.assertNotIn('%', text)

    def test_largest_faction_ignores_dead_keeps_unconscious(self):
        bodies = [human(civilization='A'), human(civilization='A', stat=STATES['UNCONSCIOUS'])]
        bodies += [human(civilization='B', stat=STATES['DEAD']) for _ in range(5)]
        winner, counts = largest(bodies, ['A', 'B'])
        self.assertEqual(winner, 'A')
        self.assertEqual(counts['A'], 2)
        self.assertEqual(counts['B'], 0)
        # Defect control: restoring the old predicate elects the corpse majority.
        old = REPORT.replace('relf == H.civilization && H.stat != DEAD', 'relf == H.civilization')
        self.assertEqual(largest(bodies, ['A', 'B'], old)[0], 'B')

    def test_largest_empty_tied_and_unregistered_factions(self):
        self.assertEqual(largest([], ['A', 'B'])[0], '')
        self.assertEqual(largest([human(civilization='A', stat=STATES['DEAD'])], ['A'])[0], '')
        bodies = [human(civilization='A'), human(civilization='B')]
        bodies += [human(civilization='Unregistered') for _ in range(5)]
        self.assertEqual(largest(bodies, ['B', 'A'])[0], 'B')

    def test_faction_list_and_largest_use_same_membership_predicate(self):
        predicate = 'if (relf == H.civilization && H.stat != DEAD)'
        self.assertIn(predicate, REPORT)
        self.assertIn(predicate, FACTIONS)

    def test_all_29_factions_route_to_census_only_for_persistence(self):
        block = REPORT.split('\tvar/report_scope = ""\n', 1)[1].split('\n\tvar/msg_npcs', 1)[0]
        self.assertTrue(block.startswith('\tif (map && map.persistence)\n'))
        expected = 'BRITISH PIRATES CIVILIAN SPANISH PORTUGUESE FRENCH INDIANS DUTCH ROMAN GREEK ARAB JAPANESE RUSSIAN GERMAN AMERICAN VIETNAMESE CHINESE FILIPINO CHECHEN FINNISH NORWEGIAN SWEDISH DANISH POLISH ITALIAN BLUEFACTION REDFACTION CAFR TSFSR'.split()
        actual = re.findall(r'\t\tmsg(\d+) = persistence_battle_report_line\(fact(\d+), (\w+), current_counts\)', block)
        self.assertEqual(actual, [(str(i), str(i), faction) for i, faction in enumerate(expected, 1)])
        self.assertEqual(block.count('persistence_battle_report_counts()'), 1)
        self.assertIn('Removed bodies and historical deaths are not counted', block)
        self.assertEqual(REPORT.count('to_chat(world, report_scope)'), 1)
        self.assertEqual(REPORT.count('shower << report_scope'), 1)
        for number in range(1, 30):
            self.assertIn(f'shower << msg{number}\n', REPORT)

    def test_history_hooks_and_nonpersistent_mortality_are_preserved(self):
        helpers = COUNTS[COUNTS.index('/proc/persistence_battle_report_counts()'):]
        self.assertNotIn('getRoundUID', helpers)
        self.assertNotIn('.death(', helpers)
        self.assertNotIn('.Life(', helpers)
        self.assertNotIn('recently_died', helpers)
        self.assertIn('dead |= getRoundUID()', COUNTS)
        self.assertIn('dead -= getRoundUID()', COUNTS)
        self.assertEqual(len(re.findall(r'var/msg\d+ = .*deceased\. Mortality rate:', REPORT)), 29)
        self.assertIn('mortality_coefficient_british = dead_british.len/total_british', REPORT)

    def test_loading_or_recovery_does_not_publish_a_partial_census(self):
        start = REPORT.index('/proc/show_global_battle_report(')
        guard = REPORT[start:].split('\n\tvar/total_pirates', 1)[0]
        env = environment()
        env['to_chat'] = lambda target, text: None
        source = guard + '\n\treturn TRUE\n'
        for persistence, recovery, operation, expected in (
                (True, False, None, True), (True, False, NS(kind='save'), True),
                (True, False, NS(kind='load'), None), (True, True, None, None),
                (False, True, NS(kind='load'), True)):
            env.update(map=NS(persistence=persistence), persistence_load_recovery_required=recovery,
                       persistence_active_operation=operation)
            proc = project(source, '/proc/show_global_battle_report', 'shower, private=False', env)
            self.assertEqual(proc(None), expected)

    def test_omitted_dead_branch_changes_census_control(self):
        old = COUNTS.replace('if (H.stat == DEAD)', 'if (FALSE)')
        self.assertEqual(census([human(stat=STATES['DEAD'])], old)['CIVILIAN'].keys, [1, 0, 0])


if __name__ == '__main__':
    unittest.main()
