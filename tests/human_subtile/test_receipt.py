"""Synthetic host-oracle controls; no BYOND process is executed."""
import copy
import unittest
import receipt


def row(case, candidate=False):
    active = case in ('human_blocked', 'animal_active')
    mover = 1 if case.startswith('human_') else 2
    events = []
    state = dict(human_x=10, human_y=10, human_z=1, human_sx=0, human_sy=0,
                 animal_x=11, animal_y=10, animal_z=1, animal_sx=2 if case == 'human_blocked' else 0,
                 animal_sy=0, human_active=active, human_offset_owned=(case == 'animal_active'),
                 human_admission=1 if active else None, human_admission_epoch=1 if active else None,
                 animal_active=False, animal_admission=None, animal_generation=1,
                 animal_tx_generation=None, animal_owner_generation=None, animal_wild_owner=False,
                 animal_pending=False, animal_offset_owned=(case == 'human_blocked'))

    def add(kind, role=mover, **extra):
        events.append(dict(state, kind=kind, actor_lifetime=role, **extra))

    if case == 'animal_active':
        add('human_move_before', 1)
        state['human_sy'] = 2
        add('human_move_after', 1)
    if case == 'human_blocked':
        add('human_move_before', 1)
    elif case == 'animal_active':
        state.update(animal_active=True, animal_admission=1, animal_tx_generation=1,
                     animal_owner_generation=1, animal_wild_owner=True)
        add('animal_move_before', 2)
    if not active:
        add('human_move_before' if mover == 1 else 'animal_move_before', mover)
    add('collision', mover, collision_id=1, move_frame=1)
    if case == 'human_blocked':
        add('human_move_after', 1)
    elif case == 'animal_active':
        add('animal_move_after', 2)
    if not active:
        add('human_move_after' if mover == 1 else 'animal_move_after', mover)
    add('deferred_entry', mover, collision_id=1, detail={'yes': 1, 'now_pushing': 0, 'has_loc': 1})
    add('deferred', mover, collision_id=1, latched_guard=active)
    if case == 'animal_active':
        add('animal_stop_before', 2)
        state.update(animal_generation=2, animal_wild_owner=False, animal_owner_generation=None)
        add('animal_stop_after', 2)
        state['animal_active'] = False
        add('animal_living_before', 2, animal_tx_finished=False)
        add('animal_living_after', 2, animal_tx_finished=False)
        add('animal_tx_finished', 2, animal_tx_finished=True)
        state.update(animal_admission=None, animal_tx_generation=None)
        add('human_move_before', 1)
        state['human_sy'] = 4
        add('human_move_after', 1)
    if case in ('human_blocked', 'human_idle'):
        add('swap_branch', mover, collision_id=1)
    if case == 'human_idle' or (case == 'human_blocked' and not candidate):
        add('legacy_swap_leg_before', mover, collision_id=1)
        add('legacy_swap_leg_before', mover, collision_id=1)
    if case == 'animal_active':
        add('human_living_completed', 1)
        add('human_completed', 1)
        state.update(human_active=False, human_admission=None, human_admission_epoch=None)
    elif case == 'human_blocked':
        state.update(human_active=False, human_admission=None, human_admission_epoch=None)
        add('human_call_return', 1)
    add('terminal', 1)
    for i, event in enumerate(events, 1):
        event.update(ordinal=i, time=i * 0.5, raw_ref='same-reused-by-engine-ref')
        if event['kind'] in ('human_move_before', 'human_move_after', 'animal_move_before', 'animal_move_after'):
            event['move_frame'] = 1
    result = {role + '_' + part: state[role + '_' + part]
              for role in ('human', 'animal') for part in ('x', 'y', 'sx', 'sy')}
    result['branch'] = 'observed'
    return dict(case=case, actual_tick=0.5, headless_authority=True,
                human_lifetime=1, animal_lifetime=2, overflow=False,
                quiesced=True, legacy_result=result,
                events=events)


class ReceiptTests(unittest.TestCase):
    def setUp(self):
        self.baseline = [row(c) for c in receipt.CASES]
        self.candidate = [row(c, True) for c in receipt.CASES]

    def test_case_local_ordinals_allow_same_raw_ref_across_fresh_actors(self):
        self.assertTrue(receipt.validate_pair(self.baseline, self.candidate))

    def test_duplicate_callback_is_bound_to_same_move_and_gate(self):
        data = copy.deepcopy(self.candidate[1])
        events = data['events']
        first = next(e for e in events if e['kind'] == 'collision')
        duplicate = dict(first, collision_id=2)
        events.insert(events.index(first) + 1, duplicate)
        accepted = next(e for e in events if e['kind'] == 'deferred')
        entry = dict(accepted, kind='deferred_entry', collision_id=2,
                     detail={'yes': 0, 'now_pushing': 0, 'has_loc': 1})
        reject = dict(entry, kind='deferred_reject')
        at = events.index(accepted) + 1
        events[at:at] = [entry, reject]
        for i, event in enumerate(events, 1):
            event.update(ordinal=i, time=i * 0.5)
        self.assertTrue(receipt.validate_row(data, True))
        for target, field, value in ((duplicate, 'move_frame', 2),
                                     (duplicate, 'human_sy', 10),
                                     (entry, 'detail', {'yes': 1, 'now_pushing': 0, 'has_loc': 1}),
                                     (reject, 'kind', 'deferred')):
            old = target[field]
            target[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                receipt.validate_row(data, True)
            target[field] = old
        events.append(dict(reject, collision_id=3, ordinal=len(events) + 1, time=events[-1]['time'] + 0.5))
        with self.assertRaisesRegex(ValueError, 'unmatched callback outcomes'):
            receipt.validate_row(data, True)

    def test_blocked_human_requires_owned_goat_and_no_paid_completion(self):
        for field, value in (('animal_offset_owned', False), ('animal_sx', 0)):
            data = copy.deepcopy(self.candidate[0])
            next(e for e in data['events'] if e['kind'] == 'collision')[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                receipt.validate_row(data, True)
        data = copy.deepcopy(self.candidate[0])
        events = data['events']
        returned = next(e for e in events if e['kind'] == 'human_call_return')
        events.insert(events.index(returned), dict(returned, kind='human_completed'))
        for i, event in enumerate(events, 1):
            event['ordinal'] = i
        with self.assertRaisesRegex(ValueError, 'paid completion'):
            receipt.validate_row(data, True)

    def test_missing_collision_or_deferred_fails(self):
        for kind in ('collision', 'deferred'):
            data = copy.deepcopy(self.candidate)
            index = next(i for i, event in enumerate(data[0]['events']) if event['kind'] == kind)
            del data[0]['events'][index]
            for ordinal, event in enumerate(data[0]['events'], 1):
                event['ordinal'] = ordinal
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                receipt.validate_pair(self.baseline, data)

    def test_postimpact_position_and_generation_mutations_fail(self):
        mutations = (
            ('human_blocked', 'deferred', 'human_x', 11, 'blocked offset integrity'),
            ('human_blocked', 'deferred', 'animal_sx', 4, 'blocked offset integrity'),
            ('human_blocked', 'human_move_after', 'animal_sx', 4, 'blocked offset integrity'),
            ('human_blocked', 'deferred', 'human_admission_epoch', 2, 'blocked admission changed'),
            ('human_blocked', 'deferred', 'human_admission_epoch', True, 'blocked admission changed'),
            ('human_blocked', 'deferred', 'animal_offset_owned', False, 'blocked offset integrity'),
            ('animal_active', 'animal_move_after', 'animal_x', 10, 'unattributed'),
            ('animal_active', 'animal_move_after', 'animal_sx', 2, 'unattributed'),
            ('animal_active', 'human_move_after', 'human_sy', 0, 'unattributed'),
            ('animal_active', 'deferred', 'animal_generation', 2, 'generation changed'),
            ('animal_active', 'deferred', 'animal_generation', True, 'generation changed'),
            ('animal_active', 'animal_stop_after', 'animal_owner_generation', 1, 'owner persisted'),
            ('animal_active', 'animal_stop_after', 'animal_active', 'unknown', 'invalid owner flag'),
            ('animal_active', 'animal_tx_finished', 'animal_admission', 2, 'animal completion'),
            ('animal_active', 'terminal', 'human_z', 2, 'human position bounds'),
        )
        for case, kind, field, value, expected in mutations:
            data = copy.deepcopy(next(row for row in self.candidate if row['case'] == case))
            impact = next(e['ordinal'] for e in data['events'] if e['kind'] == 'collision')
            event = next(e for e in data['events'] if e['kind'] == kind and e['ordinal'] > impact)
            event[field] = value
            with self.subTest(case=case, kind=kind, field=field), self.assertRaisesRegex(ValueError, expected):
                receipt.validate_row(data, True)

    def test_forged_terminal_and_excessive_postimpact_pulse_fail(self):
        data = copy.deepcopy(self.candidate[0])
        data['events'][-1]['human_x'] = 11
        data['legacy_result']['human_x'] = 11  # Matching a forged summary is insufficient.
        with self.assertRaisesRegex(ValueError, 'blocked offset integrity'):
            receipt.validate_row(data, True)
        data = copy.deepcopy(self.candidate[1])
        impact = next(e['ordinal'] for e in data['events'] if e['kind'] == 'collision')
        after = next(e for e in data['events'] if e['kind'] == 'human_move_after' and e['ordinal'] > impact)
        after['human_sy'] = 8
        with self.assertRaisesRegex(ValueError, 'unattributed'):
            receipt.validate_row(data, True)

    def test_deferred_guard_after_legitimate_human_release_is_allowed(self):
        data = copy.deepcopy(self.candidate[0])
        events = data['events']
        returned = next(e for e in events if e['kind'] == 'human_call_return')
        events.remove(returned)
        index = next(i for i, e in enumerate(events) if e['kind'] == 'deferred')
        events[index:index] = [returned]
        for event in events[index + 1:]:
            event.update(human_active=False, human_admission=None, human_admission_epoch=None)
        for i, event in enumerate(events, 1):
            event.update(ordinal=i, time=i * 0.5)
        self.assertTrue(receipt.validate_row(data, True))

    def test_real_two_pixel_animal_progress_can_finish_with_owned_offset(self):
        data = copy.deepcopy(self.candidate[1])
        impact = next(e['ordinal'] for e in data['events'] if e['kind'] == 'collision')
        after = next(e for e in data['events'] if e['kind'] == 'animal_move_after' and e['ordinal'] > impact)
        for event in data['events'][after['ordinal'] - 1:]:
            event.update(animal_x=10, animal_sx=30)
            if event is not after:
                event['animal_offset_owned'] = True
        data['legacy_result'].update(animal_x=10, animal_sx=30)
        self.assertTrue(receipt.validate_row(data, True))

    def test_candidate_cannot_swap_after_latched_collision(self):
        event = dict(kind='legacy_swap_leg_before', actor_lifetime=2, collision_id=1,
                     ordinal=len(self.candidate[0]['events']) + 1, time=20)
        self.candidate[0]['events'].append(event)
        with self.assertRaises(ValueError):
            receipt.validate_pair(self.baseline, self.candidate)

    def test_wrong_generation_and_duplicate_completion_fail(self):
        for mutation in ('generation', 'duplicate'):
            data = copy.deepcopy(self.candidate)
            events = data[1]['events']
            completed = next(event for event in events if event['kind'] == 'human_completed')
            if mutation == 'generation':
                completed['human_admission_epoch'] = 2
            else:
                extra = dict(completed, ordinal=len(events) + 1, time=20)
                events.append(extra)
            with self.subTest(mutation=mutation), self.assertRaises(ValueError):
                receipt.validate_pair(self.baseline, data)

    def test_late_old_or_unrequested_new_pulse_rejected(self):
        event = dict(kind='human_pulse', actor_lifetime=1, human_admission=1,
                     human_admission_epoch=1, ordinal=len(self.candidate[0]['events']) + 1, time=20,
                     raw_ref='same-reused-by-engine-ref')
        self.candidate[0]['events'].append(event)
        with self.assertRaises(ValueError):
            receipt.validate_pair(self.baseline, self.candidate)
        # Ref reuse is allowed across cases; this case does not request a new move.
        event['human_admission'] = 2
        event['human_admission_epoch'] = 2
        with self.assertRaises(ValueError):
            receipt.validate_pair(self.baseline, self.candidate)

    def test_idle_reverse_direction_is_compared_not_forced_to_swap(self):
        self.baseline[3]['legacy_result']['branch'] = 'swap_denied'
        self.candidate[3]['legacy_result']['branch'] = 'swap_denied'
        self.assertTrue(receipt.validate_pair(self.baseline, self.candidate))
        self.candidate[3]['legacy_result']['branch'] = 'swap'
        with self.assertRaises(ValueError):
            receipt.validate_pair(self.baseline, self.candidate)

    def test_animal_duplicate_terminal_or_late_move_fails(self):
        for kind in ('animal_tx_finished', 'animal_move_before'):
            data = copy.deepcopy(self.candidate)
            events = data[1]['events']
            events.append(dict(kind=kind, actor_lifetime=2, animal_admission=1,
                               animal_tx_generation=1, animal_tx_finished=True,
                               ordinal=len(events) + 1, time=20))
            with self.subTest(kind=kind), self.assertRaises(ValueError):
                receipt.validate_pair(self.baseline, data)

    def test_no_partial_offset_and_overflow_fail(self):
        for field, value in (('human_sy', 0), ('overflow', True)):
            data = copy.deepcopy(self.candidate)
            (next(e for e in data[1]['events'] if e['kind'] == 'collision') if field == 'human_sy' else data[0])[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                receipt.validate_pair(self.baseline, data)

    def test_boolean_values_cannot_impersonate_identity_integers(self):
        for field, kind, expected in (('ordinal', 'human_move_before', 'event ordinal'),
                                      ('actor_lifetime', 'human_move_before', 'event actor lifetime'),
                                      ('human_admission_epoch', 'collision', 'blocked admission'),
                                      ('collision_id', 'collision', 'collision ids'),
                                      ('human_admission', 'human_move_before', 'blocked movement admission')):
            data = copy.deepcopy(self.candidate[0])
            next(event for event in data['events'] if event['kind'] == kind)[field] = True
            with self.subTest(field=field), self.assertRaisesRegex(ValueError, expected):
                receipt.validate_row(data, True)

    def test_released_animal_cannot_forge_duplicate_with_boolean_admission(self):
        data = copy.deepcopy(self.candidate[1])
        events = data['events']
        original = next(e for e in events if e['kind'] == 'animal_living_before')
        duplicate = dict(original, animal_admission=True)
        events.insert(events.index(original) + 1, duplicate)
        for i, event in enumerate(events, 1):
            event.update(ordinal=i, time=i * 0.5)
        with self.assertRaisesRegex(ValueError, 'unexpected released animal admission'):
            receipt.validate_row(data, True)

    def test_complete_receipt_rejects_bad_identity_or_truncation(self):
        head = 'a' * 40
        data = dict(head=head, error=None, byond_version=516, byond_build=1688, port=0,
                    scope=receipt.SCOPE, bump_variant='candidate', bump_rows=self.candidate,
                    bump_case=receipt.CASES[-1], bump_checks=50, bump_overflow=0,
                    bump_partial=self.candidate[-1]['events'],
                    bump_setup=dict(tick=0.5, startup_time=0, ready_time=0.5, ready_usage=10))
        self.assertEqual(receipt.validate_receipt(data, head, True), self.candidate)
        for field, value in (('head', 'b' * 40), ('error', 'failed'), ('port', 1),
                             ('bump_variant', 'baseline'), ('bump_rows', self.candidate[:-1]),
                             ('bump_partial', []), ('bump_overflow', 1)):
            bad = copy.deepcopy(data)
            bad[field] = value
            with self.subTest(field=field), self.assertRaises(ValueError):
                receipt.validate_receipt(bad, head, True)


if __name__ == '__main__':
    unittest.main()
