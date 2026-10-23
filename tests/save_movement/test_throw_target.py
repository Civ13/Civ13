"""Offline source-flow checks; disk/native cases are staged, never executed here."""
from types import SimpleNamespace as NS
import re
import tempfile
import unittest
from unittest.mock import patch

import source_adapter as adapter
from source_adapter import extract, project, read

FUNCTIONS = 'code/modules/persistence/functions.dm'
MOVABLE = 'code/game/atoms_movable.dm'
POLICY = '/atom/movable/persistence_runtime_var'


class DMList(list):
    def __ior__(self, values):
        for value in values if isinstance(values, list) else [values]:
            if value not in self:
                self.append(value)
        return self


def policy(parent=lambda key: False, source=None):
    # Inherited proc dispatch is an injected engine boundary.
    return project((source or read(FUNCTIONS)).replace('..()', 'parent(key)'),
                   POLICY, 'src, key', {'parent': parent}, True)


def saved_fields(obj, runtime):
    source = read(FUNCTIONS)
    # Native istype path literals and initial(var) are explicit engine adapters.
    body = extract(source, '/datum/proc/get_saved_vars')
    body = re.sub(r'(?<!\w)/(?:mob|turf|obj|datum)(?:/[\w]+)*', lambda m: repr(m[0]), body)
    body = body.replace('initial(src.vars[key])', 'initial_var(src, key)')
    projected = '/datum/proc/get_saved_vars()\n' + body + '\n'
    env = dict(list=DMList, params2list=lambda value: [], map_storage_saved_vars='',
               istype=lambda value, kind: kind in value.kinds,
               initial_var=lambda value, key: value.defaults.get(key),
               persistence_runtime_var=lambda key: runtime(obj, key))
    return project(projected, '/datum/proc/get_saved_vars', 'src', env)(obj)


class ThrowTargetTests(unittest.TestCase):
    def stack(self, target):
        return NS(kinds={'/datum', '/obj', '/obj/item', '/atom/movable'},
                  vars=dict(name='marble stack', amount=731, original_target=target,
                            throwing=False, thrower=None),
                  defaults=dict(name='object', amount=1, original_target=None,
                                throwing=False, thrower=None), loc=(1, 1, 1))

    def test_changed_vars_omit_foreign_target_without_changing_stack_or_roof(self):
        roof = NS(kind='glass roofbuilder', loc=(2, 1, 2))
        marble = self.stack(roof)
        before = marble.vars.copy()
        fields = saved_fields(marble, policy())
        self.assertNotIn('original_target', fields)
        self.assertIn('amount', fields)
        self.assertEqual({key: marble.vars[key] for key in fields}, dict(name='marble stack', amount=731))
        self.assertEqual(marble.vars, before)
        self.assertIs(marble.vars['original_target'], roof)
        self.assertEqual((marble.loc, roof.loc), ((1, 1, 1), (2, 1, 2)))
        self.assertIs(roof, before['original_target'])  # independent world atom retained

    def test_omitted_policy_negative_control_exposes_the_original_foreign_edge(self):
        source = read(FUNCTIONS).replace('return key == "original_target" || ..()', 'return ..()')
        roof = NS(loc=(2, 1, 2))
        marble = self.stack(roof)
        self.assertIn('original_target', saved_fields(marble, policy(source=source)))

    def test_policy_delegates_other_fields_and_does_not_exclude_real_relationships(self):
        seen = []
        runtime = policy(lambda key: seen.append(key) or key == 'appearance')
        self.assertTrue(runtime(NS(), 'original_target'))
        self.assertEqual(seen, [])
        self.assertTrue(runtime(NS(), 'appearance'))
        for key in ('amount', 'loc', 'payload', 'buckled'):
            self.assertFalse(runtime(NS(), key))
        self.assertEqual(seen, ['appearance', 'amount', 'loc', 'payload', 'buckled'])

    def test_active_throw_live_state_survives_saved_var_selection(self):
        roof = NS(loc=(2, 1, 2))
        marble = self.stack(roof)
        marble.vars.update(throwing=True, thrower=NS(kind='live thrower'))
        before = marble.vars.copy()
        self.assertNotIn('original_target', saved_fields(marble, policy()))
        self.assertEqual(marble.vars, before)
        self.assertIs(marble.vars['original_target'], roof)
        throw = extract(read(MOVABLE), '/atom/movable/proc/throw_at')
        self.assertIn('original_target = target', throw)
        self.assertIn('thrown_list += src', throw)

    def test_export_and_both_historical_import_branches_filter_before_decoding(self):
        saving = extract(read('code/modules/persistence/saving.dm'), '/map_storage/proc/BuildVarDirectory')
        self.assertLess(saving.index('if(A.persistence_runtime_var(v))'), saving.index('encode_saved_value(savefile, A.vars[v])'))
        loading = extract(read('code/modules/persistence/loading.dm'), '/map_storage/proc/Load_Entry')
        gate = loading.index('if(object.persistence_runtime_var(v))')
        self.assertRegex(loading[gate:], r'^if\(object.persistence_runtime_var\(v\)\)\n\s+continue')
        self.assertLess(gate, loading.index('else if(format_version == 2)'))
        self.assertLess(gate, loading.index('decode_saved_value('))
        self.assertTrue(policy()(NS(), 'original_target'))
        self.assertIn('if(movable.z && movable.z != saving_z)', saving)
        self.assertIn('Cross-level object reference cannot be represented', saving)

    def finish(self, callback):
        old, new = object(), object()
        observed = []
        atom = NS(original_target=old, speed=2, throwing=True, thrower=object(), throw_source=object())
        floor = NS(Entered=lambda actor: callback('entered', actor, new, observed))
        atom.throw_impact = lambda where, speed: callback('impact', atom, new, observed)
        class Thrown:
            def __isub__(self, value):
                return self
        env = dict(thrown_list=Thrown(), get_turf=lambda actor: floor,
                   isobj=lambda actor: True, istype=lambda *args: False, BOTTLE='bottle')
        source = read(MOVABLE).replace('/obj/item/weapon/reagent_containers/food/drinks/bottle', '/BOTTLE')
        fields = (*adapter.FIELDS, 'original_target', 'throwing', 'thrower', 'throw_source', 'speed', 'throw_impact')
        with patch.object(adapter, 'FIELDS', fields):
            finish = project(source, '/atom/movable/proc/finished_throwing', 'src, thrown_list', env, True)
        finish(atom, env['thrown_list'])
        return atom, new, observed

    def test_normal_finish_clears_target_before_both_callback_boundaries(self):
        atom, _, seen = self.finish(lambda phase, actor, new, seen: seen.append((phase, actor.original_target)))
        self.assertEqual(seen, [('impact', None), ('entered', None)])
        self.assertIsNone(atom.original_target)

    def test_reentrant_impact_and_entered_new_targets_are_not_erased(self):
        for selected in ('impact', 'entered'):
            def callback(phase, actor, new, seen):
                if phase == selected:
                    actor.original_target = new  # throw_at assignment at the callback boundary
            atom, new, _ = self.finish(callback)
            self.assertIs(atom.original_target, new)
        body = extract(read(MOVABLE), '/atom/movable/proc/finished_throwing')
        self.assertLess(body.index('original_target = null'), body.index('throw_impact(new_loc,speed)'))
        self.assertLess(body.index('original_target = null'), body.index('new_loc.Entered(src)'))

    def test_native_disk_fixture_stages_actual_production_without_launch(self):
        from prepare_throw_target import prepare
        with tempfile.TemporaryDirectory() as directory:
            result = prepare(directory)
            self.assertFalse(result['native_verified'])
            self.assertIn('throw_cleanup.dm', result['source_projections'])
            self.assertIn('throw_target_probe.dm', result['generated_sha256'])
            from pathlib import Path
            fixture = (Path(directory) / 'throw_target_probe.dm').read_text()
            for text in ('BuildVarDirectory(', 'Load_Entry(', 'original_target', 'amount == 731', 'independent roof'):
                self.assertIn(text, fixture)


if __name__ == '__main__':
    unittest.main()
