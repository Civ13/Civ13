"""Source-only staging and receipt contract for the random-walk experiment.

This module does not launch BYOND. An experiment receipt is observational;
validity here is not a gameplay or cadence-parity verdict.
"""
import hashlib
import json
import math
import os
from pathlib import Path
import shutil

SCOPE = 'held/reissued insect random walk; native client and gameplay acceptance excluded'
MODES = ('legacy', 'parent', 'candidate')
TICKS = (0.5, 1.0)
POLICIES = ('held', 'reissue')
PHASES = (0, 2)
KINDS = ('mosquito', 'bat')
MAX_EVENTS = 4096
MAX_PHASE_EVENTS = 512
OBSERVATION_DS = 28
MAX_LIVES = 3
MAX_TRANSACTIONS = 12
MAX_MOVES_PER_SIDE = 210
MAX_LIFE_EVENTS = 14
MAX_TX_EVENTS = 4
MAX_RECEIPT = 4 * 1024 * 1024
MAX_EXPANDED = 16 * 1024 * 1024
MAX_COMPRESSED = 320 * 1024
COMPILE_SECONDS = 90
DAEMON_SECONDS = 60
SETUP_SECONDS = 60
WORK_SECONDS = 490
SPECIES = ('code/game/mob/living/simple_animal/hostile/mosquitoes.dm',
           'code/game/mob/living/simple_animal/hostile/vampirebat.dm')
PUBLISHED_PARENT = '24ab3da9255ad42a4b084c8de18ea43583e529d9'
PARENT_TREE = '0bb798277bfc6bf4db10292e1773cd23660be9df'
HANDOFF_BASE = 'cb2cd5ec16830a9528c2b7f6ac249b7ce055cf76'
HANDOFF_BASE_TREE = 'f41bf05a4fa0f0a96b472e3e4dbcbca437fc9060'
MOVEMENT = 'code/game/mob/living/simple_animal/subtile_movement.dm'
PARENT_MOVEMENT_BLOB = '2b29606bbd3d7bca805e495f5c463c449bc4fe6b'
CANDIDATE_MOVEMENT_BLOB = '2fc2143df9925df0231bb52dda97526a24cd59fd'
PARENT_FIXTURE = 'tests/human_subtile/handoff_parent_subtile.dm.txt'
HANDOFF_FILES = {MOVEMENT, 'tests/human_subtile/cloud_npc_controller.py',
                 'tests/human_subtile/cloud_npc_smoke.py', 'tests/human_subtile/random_cadence_contract.py',
                 'tests/human_subtile/test_random_cadence_contract.py', 'tests/human_subtile/test_wild_handoff.py',
                 'tests/persistence_pointers/test_contract.py', PARENT_FIXTURE,
                 '.github/workflows/wildlife-random-cadence.yml'}
LOCAL_CANDIDATE = '34b5b5cb0fba9063b5d87d81fd82b6516144533b'
CANDIDATE_BLOBS = dict(zip(SPECIES, ('bdb0e42fb6a3e78a01d11dd46a107577457e1595',
                                     'd1be76d011b2825228c03b604f6ce1993a1f172e')))
CANDIDATE_TEST = 'tests/human_subtile/test_insect_random_period.py'
CANDIDATE_TEST_BLOB = '8fbccfac6b8ec710f4073eff7c7df34f739388e0'
FIXTURE_FILES = {'tests/human_subtile/cloud_npc_controller.py','tests/human_subtile/cloud_npc_job.py',
                 'tests/human_subtile/cloud_npc_smoke.py','tests/human_subtile/random_cadence_fixture.dm',
                 'tests/human_subtile/random_cadence_contract.py','tests/human_subtile/test_random_cadence_contract.py',
                 'tests/human_subtile/test_cloud_npc_controller.py','tests/human_subtile/random_cadence_registration.yml',
                 '.github/workflows/wildlife-random-cadence.yml'}
RANDOM_OVERRIDE = b'''\t// The lag-4 random walker was observed at 4 ds between starts only at
\t// 0.5 ds ticks. Keep this calibration separate from the pulse duration;
\t// other tick rates and producers need their own native measurements.
\tif (mode == "random" && world.tick_lag == 0.5 && interval == npc_subtile_native_interval(4))
\t\treturn 4
'''


def require(condition, message):
    if not condition:
        raise ValueError(message)


def selection(suite):
    """Each serialized matrix job executes exactly one explicit tick rate."""
    require(type(suite) is str and suite in ('random05','random10'), 'selector suite')
    return .5 if suite == 'random05' else 1.0


def budget():
    require(2 * COMPILE_SECONDS + 3 * DAEMON_SECONDS + SETUP_SECONDS <= WORK_SECONDS,
            'phase maxima exceed work ceiling')
    require(MAX_PHASE_EVENTS * 8 <= MAX_EVENTS, 'case allocations exceed daemon event cap')
    require(2 * MAX_MOVES_PER_SIDE + MAX_TRANSACTIONS * MAX_TX_EVENTS +
            MAX_LIVES * MAX_LIFE_EVENTS + 2 <= MAX_PHASE_EVENTS, 'whole phase exceeds case cap')
    return {'compiles': 2, 'compile_seconds': COMPILE_SECONDS, 'daemons': 3,
            'daemon_seconds': DAEMON_SECONDS, 'setup_seconds': SETUP_SECONDS,
            'work_seconds': WORK_SECONDS, 'whole_seconds': 600,
            'reserved_seconds': 110, 'max_events_per_daemon': MAX_EVENTS,
            'max_events_per_phase': MAX_PHASE_EVENTS, 'phases_per_daemon': 8,
            'observation_ds': OBSERVATION_DS, 'max_lives': MAX_LIVES,
            'max_transactions': MAX_TRANSACTIONS, 'max_move_enters': MAX_MOVES_PER_SIDE,
            'max_move_exits': MAX_MOVES_PER_SIDE, 'max_events_per_life': MAX_LIFE_EVENTS,
            'max_events_per_transaction': MAX_TX_EVENTS, 'phase_boundary_events': 2,
            'maximum_accounted_work_seconds': 2 * COMPILE_SECONDS + 3 * DAEMON_SECONDS + SETUP_SECONDS,
            'max_receipt_bytes': MAX_RECEIPT, 'max_expanded_bytes': MAX_EXPANDED,
            'max_compressed_bytes': MAX_COMPRESSED}


def prepare_pair(candidate_out, manifest, current, parent_blobs, candidate_blobs):
    """Clone one bounded source stage and isolate the handoff movement change.

    Caller obtains the blobs from immutable verified commits, and must check the
    production diff between those commits separately. Hardlinks share only the
    immutable unadapted inputs; every input the adapters write is unlinked first.
    """
    candidate_out = Path(candidate_out)
    candidate = candidate_out / 'stage'
    parent_out = candidate_out.parent / 'npc-parent'
    require(not parent_out.exists() and set(parent_blobs) == set(candidate_blobs) == set(SPECIES)|{MOVEMENT},
            'paired source setup')
    for path in SPECIES:
        raw = (candidate / path).read_bytes()
        require(raw == candidate_blobs[path] == parent_blobs[path] and raw.count(RANDOM_OVERRIDE) == 1,
                'shared species source mismatch: ' + path)
    require((candidate/MOVEMENT).read_bytes()==candidate_blobs[MOVEMENT] and
            parent_blobs[MOVEMENT]!=candidate_blobs[MOVEMENT], 'movement source mismatch')
    parent_out.mkdir()
    shutil.copytree(candidate, parent_out / 'stage', copy_function=os.link)
    parent = parent_out / 'stage'
    changed = set(SPECIES) | {
        'code/game/mob/living/simple_animal/simple_ai.dm',
        'code/game/mob/living/simple_animal/simple_animal.dm',
        'code/game/mob/living/simple_animal/subtile_movement.dm',
        'tests/human_subtile/probe.dm', 'tests/human_subtile/scheduler_core_draft.dm',
        'human_subtile.dme',
    }
    for rel in changed:
        path = parent / rel
        require(path.is_file() and not path.is_symlink(), 'missing independent input: ' + rel)
        raw = parent_blobs[rel] if rel in parent_blobs else path.read_bytes()
        path.unlink()
        path.write_bytes(raw)
        require(not os.path.samefile(path, candidate / rel), 'mutable input still shared')
    parent_manifest = json.loads(json.dumps(manifest))
    parent_manifest['paired_preimages'] = {k: hashlib.sha256(v).hexdigest() for k, v in parent_blobs.items()}
    manifest['paired_preimages'] = {k: hashlib.sha256(v).hexdigest() for k, v in candidate_blobs.items()}
    adapt(parent_out, parent_manifest, current, 'parent')
    adapt(candidate_out, manifest, current, 'candidate')
    return parent_out, parent_manifest


def species_fixture_bytes(path, raw):
    """Reconstruct the expected fixture adaptation from a verified Git blob."""
    require(path in SPECIES and isinstance(raw, bytes), 'species fixture source')
    text=raw.decode('utf-8')
    if path.endswith('mosquitoes.dm'):
        replacements=[('if (prob(70))','if (fixture_scheduler_prob(70, src, "mosquito_seek"))'),
                      ('else if (prob(15))','else if (fixture_scheduler_prob(15, src, "mosquito_water"))'),
                      ('if (prob(10))\n\t\t\tfor (var/mob/living/human/TG in range(1,src))',
                       'if (fixture_scheduler_prob(10, src, "mosquito_bite"))\n\t\t\tfor (var/mob/living/human/TG in range(1,src))'),
                      ('try_infect(TG, 20, "malaria")','fixture_scheduler_infect(src, TG, 20, "malaria")')]
    else:
        replacements=[('if (prob(80))','if (fixture_scheduler_prob(80, src, "bat_seek"))'),
                      ('else if (prob(20))\n\t\t\tvar/done = FALSE\n\t\t\tfor (var/mob/living/simple_animal/cow',
                       'else if (fixture_scheduler_prob(20, src, "bat_cow"))\n\t\t\tvar/done = FALSE\n\t\t\tfor (var/mob/living/simple_animal/cow'),
                      ('else if (prob(20))\n\t\t\tvar/done = FALSE\n\t\t\tfor (var/mob/living/simple_animal/bull',
                       'else if (fixture_scheduler_prob(20, src, "bat_bull"))\n\t\t\tvar/done = FALSE\n\t\t\tfor (var/mob/living/simple_animal/bull'),
                      ('if (prob(5))','if (fixture_scheduler_prob(5, src, "bat_bite"))'),
                      ('try_infect(TG, 25, "malaria")','fixture_scheduler_infect(src, TG, 25, "malaria")')]
    replacements.append(('TG.adjustBruteLoss(1,2)','fixture_scheduler_bite(TG, src)'))
    for old,new in replacements:
        require(text.count(old)==1,'species adaptation anchor: '+path)
        text=text.replace(old,new)
    return text.encode('utf-8')


def movement_replacements(variant):
    require(variant in ('parent','candidate'), 'movement variant')
    common=[('\tnpc_subtile_transaction = T\n\t// Capture this admission',
             '\tnpc_subtile_transaction = T\n\tfixture_random_observe("tx_admitted", src, null, T)\n\t// Capture this admission'),
            ('\tremaining_y -= min(remaining_y, abs(actual_y))\n\tif (P.armed',
             '\tremaining_y -= min(remaining_y, abs(actual_y))\n\tif (!remaining_x && !remaining_y)\n\t\tfixture_random_observe("final_pulse", actor, null, src)\n\tif (P.armed')]
    old='\tactor = null\n\ttarget = null\n\tcombat_target = null\n\tfollowing = null\n\tfinished = TRUE'
    released=('\tfixture_random_observe("tx_actor_released", actor, null, src)\n'
              '\tvar/mob/living/simple_animal/fixture_random_saved_actor = actor\n'+old+'\n')
    if variant=='parent':
        detail='list("hooked" = FALSE, "waiter_matches" = FALSE, "owner_matches" = FALSE, "generation_matches" = FALSE, "revision_matches" = FALSE, "worker_active" = FALSE)'
        common.append((old,released+'\tfixture_random_observe("tx_finished", fixture_random_saved_actor, '+detail+', src)'))
    else:
        common.append((old,released+'\t// Terminal observation follows the full owner-reference cleanup.'))
        old_call='\tintent_owner = null\n\tif (W)\n\t\tW.transaction_finished(src, completed_revision, finish_error)'
        detail=('list("hooked" = !!W, "waiter_matches" = W ? (W.waiting_transaction == src) : FALSE, '
                '"owner_matches" = (W && fixture_random_saved_actor) ? (fixture_random_saved_actor.npc_subtile_wild_walk == W) : FALSE, '
                '"generation_matches" = (W && fixture_random_saved_actor) ? (fixture_random_saved_actor.move_gen == W.generation) : FALSE, '
                '"revision_matches" = W ? (W.revision == completed_revision) : FALSE, "worker_active" = W ? !!W.worker_active : FALSE)')
        common.append((old_call,'\tintent_owner = null\n\tfixture_random_observe("tx_finished", fixture_random_saved_actor, '+detail+', src)\n'
                               '\tif (W)\n\t\tW.transaction_finished(src, completed_revision, finish_error)'))
    return common


def movement_fixture_bytes(raw, variant):
    text=raw.decode('utf-8')
    for old,new in movement_replacements(variant):
        require(text.count(old)==1, 'movement adaptation anchor')
        text=text.replace(old,new)
    return text.encode('utf-8')


def adapt(out, manifest, current, variant='candidate'):
    """Make identical fixture-only substitutions on each already-frozen source."""
    out = Path(out)
    stage = out / 'stage'
    source = 'tests/human_subtile/probe.dm'
    core = 'tests/human_subtile/scheduler_core_draft.dm'
    movement = 'code/game/mob/living/simple_animal/subtile_movement.dm'
    require((stage / 'tests/human_subtile/random_cadence_fixture.dm').is_file(), 'fixture missing')
    replacements = [
        ('code/game/mob/living/simple_animal/simple_ai.dm',
         'if (client || anchored || clients.len <= 0)',
         'if (client || anchored || (clients.len <= 0 && !(src in fixture_scheduler_test_subjects)))'),
        ('code/game/mob/living/simple_animal/hostile/mosquitoes.dm', 'if (prob(70))',
         'if (fixture_scheduler_prob(70, src, "mosquito_seek"))'),
        ('code/game/mob/living/simple_animal/hostile/mosquitoes.dm', 'else if (prob(15))',
         'else if (fixture_scheduler_prob(15, src, "mosquito_water"))'),
        ('code/game/mob/living/simple_animal/hostile/mosquitoes.dm',
         'if (prob(10))\n\t\t\tfor (var/mob/living/human/TG in range(1,src))',
         'if (fixture_scheduler_prob(10, src, "mosquito_bite"))\n\t\t\tfor (var/mob/living/human/TG in range(1,src))'),
        ('code/game/mob/living/simple_animal/hostile/vampirebat.dm', 'if (prob(80))',
         'if (fixture_scheduler_prob(80, src, "bat_seek"))'),
        ('code/game/mob/living/simple_animal/hostile/vampirebat.dm',
         'else if (prob(20))\n\t\t\tvar/done = FALSE\n\t\t\tfor (var/mob/living/simple_animal/cow',
         'else if (fixture_scheduler_prob(20, src, "bat_cow"))\n\t\t\tvar/done = FALSE\n\t\t\tfor (var/mob/living/simple_animal/cow'),
        ('code/game/mob/living/simple_animal/hostile/vampirebat.dm',
         'else if (prob(20))\n\t\t\tvar/done = FALSE\n\t\t\tfor (var/mob/living/simple_animal/bull',
         'else if (fixture_scheduler_prob(20, src, "bat_bull"))\n\t\t\tvar/done = FALSE\n\t\t\tfor (var/mob/living/simple_animal/bull'),
        ('code/game/mob/living/simple_animal/hostile/vampirebat.dm', 'if (prob(5))',
         'if (fixture_scheduler_prob(5, src, "bat_bite"))'),
        ('code/game/mob/living/simple_animal/simple_animal.dm', 'if (prob(base_chance * dmod))',
         'if (fixture_scheduler_infection_prob(base_chance * dmod, src, target, disease_name))'),
        (core, '\tif (fixture_scheduler_events.len >= 4096)',
         '\t// The random probe already captures canonical Move entry/exit.\n'
         '\tif (!(label in list("mosquito_move_before", "mosquito_move_after", "bat_move_before", "bat_move_after")))\n'
         '\t\tfixture_random_observe("contact_[label]", A, list("choice" = choice, "raw" = raw, "chance" = chance))\n'
         '\tif (fixture_scheduler_events.len >= 4096)'),
        (core, 'tape = fixture_scheduler_scenario == "chase" ? list(TRUE) : list(TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE)',
         'tape = fixture_scheduler_scenario == "random" ? list(FALSE) : (fixture_scheduler_scenario == "chase" ? list(TRUE) : list(TRUE, TRUE, FALSE, TRUE, TRUE, FALSE, TRUE, TRUE))'),
        (source, '\tmaxx = 18\n\tmaxy = 14', '\tmaxx = 65\n\tmaxy = 65'),
        (source, '\t\t\tnpc_subtile_fixture()', '\t\t\tfixture_random_main()'),
        (source, '"scope" = "actual human/codec; headless authority adapter"',
         '"scope" = "' + SCOPE + '", "random_setup" = fixture_random_setup, "random_rows" = fixture_random_rows, "random_partial" = fixture_random_events, "random_case" = fixture_random_case, "random_count" = fixture_random_count, "random_phase_count" = fixture_random_phase_count, "random_overflow" = fixture_random_overflow'),
    ]
    replacements += [(movement, old, new) for old,new in movement_replacements(variant)]
    for path in ('code/game/mob/living/simple_animal/hostile/mosquitoes.dm',
                 'code/game/mob/living/simple_animal/hostile/vampirebat.dm'):
        replacements += [(path, 'TG.adjustBruteLoss(1,2)', 'fixture_scheduler_bite(TG, src)')]
    replacements += [
        ('code/game/mob/living/simple_animal/hostile/mosquitoes.dm', 'try_infect(TG, 20, "malaria")',
         'fixture_scheduler_infect(src, TG, 20, "malaria")'),
        ('code/game/mob/living/simple_animal/hostile/vampirebat.dm', 'try_infect(TG, 25, "malaria")',
         'fixture_scheduler_infect(src, TG, 25, "malaria")'),
    ]
    for relative, old, new in replacements:
        current.adapt(out, manifest, relative, old, new)
    dme = out / manifest['dme']
    with dme.open('a', encoding='utf-8', newline='\n') as stream:
        stream.write('\n#include "tests\\human_subtile\\scheduler_core_draft.dm"\n')
        stream.write('#include "tests\\human_subtile\\random_cadence_fixture.dm"\n')
    for relative in {x[0] for x in replacements} | {dme.relative_to(stage).as_posix()}:
        data = (stage / relative).read_bytes()
        manifest['stage_files'][relative] = {'bytes': len(data), 'sha256': hashlib.sha256(data).hexdigest()}
    manifest['random_scope'] = SCOPE


def finite(value):
    return type(value) in (int, float) and math.isfinite(value)


def setup_used(total_elapsed, child_elapsed):
    require(finite(total_elapsed) and finite(child_elapsed) and 0 <= child_elapsed <= total_elapsed,
            'invalid elapsed timing')
    used = total_elapsed - child_elapsed
    require(used <= SETUP_SECONDS, 'random setup allowance exceeded')
    return used


def point(event):
    return (event['x'] * 32 + event['sx'], event['y'] * 32 + event['sy'], event['z'])


def inspect_events(events, mode, kind):
    """Check ordered physical/transaction/contact observations and classify commands."""
    physical = point(events[0])
    stack = []
    active = {}
    final = set()
    command = None
    commands = []
    starts = []
    admissions = []
    final_pulses = []
    completions = []
    life = False
    bite_roll = None
    bite_pending = False
    bite_used = False
    opportunities = []
    bites = []
    infections = []
    infection_required = False
    infection_open = False
    infection_choice = None
    for e in events:
        label = e.get('event')
        require(isinstance(label, str), 'event label')
        secondary=('mosquito_water',) if kind=='mosquito' else ('bat_cow','bat_bull')
        allowed={'phase_start','phase_end','move_enter','move_exit','tx_admitted','final_pulse',
                 'tx_actor_released','tx_finished','command_before','command_after','command_suppressed',
                 'contact_'+kind+'_life_before','contact_'+kind+'_life_after','contact_'+kind+'_intent_random',
                 'contact_roll_'+kind+'_seek','contact_roll_'+kind+'_bite','contact_bite_before','contact_bite_after',
                 'contact_infection_before','contact_infection_roll','contact_infection_after'}
        allowed.update('contact_roll_'+site for site in secondary)
        require(label in allowed, 'unexpected/duplicate observer event')
        if (label.startswith(('command_','contact_roll_','contact_bite_','contact_infection_')) or
                label.startswith('contact_'+kind+'_life_') or label.startswith('contact_'+kind+'_intent_')):
            require(e.get('life_depth')==1, 'command or contact outside observed Life')
        if label in ('phase_start','phase_end'):
            require(e.get('life_depth')==0, 'phase boundary overlaps Life')
        now = point(e)
        if label == 'move_enter':
            require(len(stack) < 16 and (stack or now == physical), 'Move entry position')
            if mode != 'legacy':
                require(e.get('active_tx') in active, 'unowned competing Move')
            else:
                require(e.get('active_tx') is None, 'legacy transaction reference')
            stack.append((now, e['at'], e.get('detail'), e.get('active_tx'), e.get('life_depth')))
        elif label == 'move_exit':
            require(stack, 'Move return without entry')
            before, started, direction, owner_tx, life_depth = stack.pop()
            require(mode == 'legacy' or e.get('active_tx') == owner_tx, 'movement ownership changed during callback')
            limit = 32 if mode == 'legacy' else 2
            require(now[2] == before[2] and abs(now[0]-before[0]) <= limit and
                    abs(now[1]-before[1]) <= limit, 'physical move exceeds bound')
            if not stack:
                physical = now
                starts.append({'started': started, 'ended': e['at'], 'requested_dir': direction,
                               'overlaps_life': bool(life_depth),
                               'dx': now[0]-before[0], 'dy': now[1]-before[1]})
        elif not stack:
            require(now == physical, 'unobserved physical movement')

        if label == 'tx_admitted':
            tx = e.get('tx')
            require(mode != 'legacy' and isinstance(tx, str) and tx and tx not in active and
                    e.get('active_tx')==tx and e['transaction'], 'transaction admission')
            require(e.get('tx_dir') in (1, 2, 4, 8, 5, 6, 9, 10) and
                    all(finite(e.get(k)) and 0 <= e[k] <= 32 for k in ('remaining_x', 'remaining_y')) and
                    (e['remaining_x'] or e['remaining_y']), 'transaction geometry')
            active[tx] = {'start': now, 'direction': e['tx_dir'], 'rx': e['remaining_x'],
                          'ry': e['remaining_y'], 'at': e['at']}
            admissions.append({'at': e['at'], 'tx': tx, 'direction': e['tx_dir'],
                               'remaining_x': e['remaining_x'], 'remaining_y': e['remaining_y']})
            final.discard(tx)
        elif label == 'final_pulse':
            require(e.get('tx') in active and e.get('active_tx')==e.get('tx') and e['transaction'] and
                    e.get('tx') not in final and e.get('remaining_x') == 0 and e.get('remaining_y') == 0,
                    'final pulse without completed remaining distance')
            final.add(e['tx'])
            final_pulses.append({'at': e['at'], 'tx': e['tx']})
        elif label == 'tx_actor_released':
            tx = e.get('tx')
            require(tx in active and e.get('arrived') in (0, 1) and not e['transaction'] and
                    e.get('active_tx') is None and e.get('tx_finished')==0 and
                    e.get('tx_actor_present')==1 and not active[tx].get('released'), 'actor release')
            require(not e['arrived'] or tx in final, 'arrival without final pulse')
            admitted = active[tx]
            if e['arrived']:
                direction = admitted['direction']
                sx = 1 if direction & 4 else -1 if direction & 8 else 0
                sy = 1 if direction & 1 else -1 if direction & 2 else 0
                require(now == (admitted['start'][0] + sx * admitted['rx'],
                                admitted['start'][1] + sy * admitted['ry'], admitted['start'][2]),
                        'arrival lacks physical displacement')
            admitted['released']=True
            admitted['released_at']=e['at']
            admitted['arrived']=e['arrived']
        elif label == 'tx_finished':
            tx=e.get('tx')
            detail=e.get('detail')
            require(tx in active and active[tx].get('released') and e.get('arrived')==active[tx]['arrived'] and
                    not e['transaction'] and e.get('active_tx') is None and e.get('tx_finished')==1 and
                    all(e.get(k)==0 for k in ('tx_actor_present','tx_target_present','tx_combat_present',
                                               'tx_following_present')) and
                    (e.get('tx_intent_present') == 0 if mode == 'candidate' else e.get('tx_intent_present') in (0,1)) and
                    isinstance(detail,dict) and set(detail)=={'hooked','waiter_matches','owner_matches',
                        'generation_matches','revision_matches','worker_active'} and
                    all(detail[k] in (0,1) for k in detail) and
                    (not detail['hooked'] or detail['waiter_matches']) and
                    (mode != 'parent' or not detail['hooked']),
                    'transaction finished state')
            admitted=active.pop(tx)
            completions.append({'admitted': admitted['at'], 'actor_released':admitted['released_at'],
                                'finished':e['at'], 'arrived':e['arrived'],
                                'intent_reference_retained':e['tx_intent_present'],'handoff':detail})
            final.discard(tx)

        if label == 'command_before':
            require(command is None, 'overlapping command wrappers')
            command = e
        elif label in ('command_after', 'command_suppressed'):
            require(command is not None, 'command result without issue')
            if label == 'command_suppressed':
                classification = 'fixture_suppressed'
            elif mode == 'legacy':
                # The legacy procedure returns no native acceptance receipt.
                classification = 'native_issued'
            elif not e.get('detail'):
                classification = 'rejected'
            elif e.get('pending'):
                classification = 'deferred'
            elif (command.get('owner') and command.get('owner') == e.get('owner') and
                  all(command.get(k) == e.get(k) for k in ('generation', 'revision', 'due'))):
                classification = 'reaffirmed'
            else:
                require(e.get('owner') and (command.get('owner') != e.get('owner') or
                        command.get('generation') != e.get('generation')), 'ambiguous staged command')
                classification = 'accepted_or_replaced'
            commands.append({'at': command['at'], 'result': classification})
            command = None

        if label == 'contact_' + kind + '_life_before':
            require(not life, 'overlapping Life')
            life = True
            bite_roll = None
            bite_used = False
        elif label == 'contact_roll_' + kind + '_bite':
            require(life and bite_roll is None and isinstance(e.get('detail'), dict) and
                    e['detail'].get('choice') in (0, 1), 'bite roll')
            bite_roll = bool(e['detail']['choice'])
            opportunities.append({'at': e['at'], 'roll': int(bite_roll), 'range': e['range'],
                                  'settled': e['settled']})
        elif label == 'contact_bite_before':
            require(life and bite_roll and not bite_used and not bite_pending and e['range'] and
                    (mode == 'legacy' or e['settled']) and finite(e.get('target_brute')), 'invalid bite')
            bite_used = True
            bite_pending = e['target_brute']
            bites.append(e['at'])
        elif label == 'contact_bite_after':
            require(life and bite_used and bite_pending is not False and finite(e.get('target_brute')) and
                    e['target_brute'] > bite_pending, 'invalid bite result')
            bite_pending = False
            infection_required = e.get('target_disease') == 0
        elif label == 'contact_infection_before':
            require(life and bite_used and bite_pending is False and infection_required and not infection_open and
                    e.get('target_disease')==0, 'unexpected infection call')
            infection_open=True
            infection_choice=None
        elif label == 'contact_infection_roll':
            detail=e.get('detail')
            require(infection_open and infection_choice is None and isinstance(detail,dict) and
                    detail.get('raw') in (0,1) and detail.get('chance')==(20 if kind=='mosquito' else 25) and
                    detail.get('choice')==(0,1)[len(infections)%2], 'invalid infection roll')
            infection_choice=detail['choice']
        elif label == 'contact_infection_after':
            detail=e.get('detail')
            require(infection_open and infection_choice is not None and isinstance(detail,dict) and
                    detail.get('choice')==infection_choice and e.get('target_disease')==infection_choice and
                    (not infection_choice or e.get('target_disease_type')=='malaria'), 'invalid infection result')
            infections.append({'at':e['at'],'choice':infection_choice,'disease':e['target_disease'],
                               'disease_type':e.get('target_disease_type')})
            infection_open=False
            infection_required=False
        elif label == 'contact_' + kind + '_life_after':
            require(life and bite_roll is not None and bite_pending is False and not infection_required and
                    not infection_open, 'incomplete Life')
            life = False
    require(not stack and not active and command is None and not life and bite_pending is False and
            not infection_required and not infection_open,
            'unterminated observation')
    require(sum(bool(m['dx'] or m['dy']) for m in starts) >= 4, 'insufficient physical progress')
    return {'commands': commands, 'physical_moves': starts, 'admissions': admissions,
            'final_pulses': final_pulses, 'cleanups': completions,
            'opportunities': opportunities, 'bites': bites, 'infections': infections}


def validate(receipt, head, mode, tick):
    """Validate identity, complete case set and raw events; never infer parity."""
    require(mode in MODES and tick in TICKS and isinstance(receipt, dict), 'mode or receipt')
    require(receipt.get('head') == head and receipt.get('error') is None and receipt.get('port') == 0 and
            (receipt.get('byond_version'), receipt.get('byond_build')) == (516, 1688) and
            receipt.get('scope') == SCOPE and receipt.get('npc_checks') == 0 and receipt.get('random_overflow') in (0, False) and
            type(receipt.get('random_count')) is int and 0 < receipt['random_count'] <= MAX_EVENTS, 'receipt identity')
    setup = receipt.get('random_setup')
    require(isinstance(setup, dict) and setup.get('stage') == 'ready' and setup.get('mode') == mode and
            setup.get('mode_is_text') in (1, True) and setup.get('tick_is_text') in (1, True) and
            setup.get('raw_tick') == str(tick) and setup.get('requested_tick') == tick and
            setup.get('actual_tick') == tick and finite(setup.get('initial_tick')) and
            setup.get('mode_valid') in (1, True) and setup.get('tick_valid') in (1, True) and
            setup.get('original_combined') in (0, 1, False, True), 'setup diagnostics')
    require(all(finite(setup.get(key)) for key in ('startup_time', 'ready_time', 'startup_usage', 'ready_usage')) and
            0 <= setup['startup_time'] < setup['ready_time'] and 0 <= setup['ready_usage'] < 100,
            'startup readiness')
    rows = receipt.get('random_rows')
    require(isinstance(rows, list) and len(rows) == 8, 'case count')
    require(isinstance(rows[-1],dict) and isinstance(rows[-1].get('events'),list) and
            type(receipt.get('random_phase_count')) is int and
            receipt['random_phase_count']==len(rows[-1].get('events',[])) and
            0<receipt['random_phase_count']<=MAX_PHASE_EVENTS and receipt.get('random_partial')==rows[-1]['events'] and
            receipt.get('random_case')==rows[-1].get('case'), 'last phase count')
    found = {}
    total = 0
    for row in rows:
        name = row.get('subject', '')
        kind = 'mosquito' if '/mosquito/' in name else 'bat' if '/vampirebatblack/' in name else None
        key = (kind, row.get('policy'), row.get('phase_ticks'))
        expected_name = '/mob/living/simple_animal/' + ('mosquito' if kind == 'mosquito' else 'vampirebatblack') + '/scheduler_probe/random_probe'
        require(kind in KINDS and name == expected_name and key[1] in POLICIES and
                type(key[2]) is int and key[2] in PHASES and key not in found and
                row.get('case') == name + ':' + key[1] + ':' + str(key[2]), 'case identity')
        require(row.get('enabled') == (mode != 'legacy') and row.get('tick_lag_ds') == tick and
                row.get('actual_clients') == 0 and row.get('life_interval_ds') == 10 and
                row.get('initial_start_delay_ds') == 6 and row.get('speed_argument') == 0 and
                finite(row.get('step_size')) and row['step_size'] > 0 and row.get('seed') == 741239 and
                finite(row.get('started')) and finite(row.get('ended')) and
                row['started'] >= setup['ready_time'] and
                row.get('observation_ds')==OBSERVATION_DS and
                OBSERVATION_DS <= row['ended'] - row['started'] <= OBSERVATION_DS+11 and
                type(row.get('process_ticks')) is int and
                row['process_ticks'] > 0, 'case setup')
        events = row.get('events')
        require(isinstance(events, list) and events and len(events)<=MAX_PHASE_EVENTS and
                row.get('event_count')==len(events) and all(isinstance(e, dict) for e in events), 'events')
        total += len(events)
        require(total <= MAX_EVENTS, 'daemon event limit')
        prev = row['started']
        for e in events:
            require(finite(e.get('at')) and prev <= e['at'] <= row['ended'] and
                    all(finite(e.get(k)) for k in ('x', 'y', 'z', 'sx', 'sy', 'step_size','tick_usage',
                                                       'target_x', 'target_y', 'target_z', 'target_sx', 'target_sy')) and
                    (e['target_x'], e['target_y'], e['target_z'], e['target_sx'], e['target_sy']) == (33, 34, 1, 0, 0) and
                    0 <= e['tick_usage'] < 100 and e['life_depth'] in (0,1) and e['step_size'] == row['step_size'] and
                    all(type(e[k]) is int for k in ('x','y','z','sx','sy')) and
                    1 <= e['x'] <= 65 and 1 <= e['y'] <= 65 and e['z'] == 1 and
                    0 <= e['sx'] < 32 and 0 <= e['sy'] < 32 and
                    e.get('enabled') == row['enabled'] and
                    e.get('settled') in (0, 1) and e.get('transaction') in (0, 1) and e.get('pulse') in (0,1) and
                    e.get('range') in (0, 1) and e.get('target_disease') in (0,1) and
                    not (e['settled'] and e['transaction']), 'event state')
            prev = e['at']
        require(events[0].get('event') == 'phase_start' and events[0]['at']==row['started'] and
                events[-1].get('event') == 'phase_end' and events[-1]['at']==row['ended'] and
                sum(e.get('event')=='phase_start' for e in events)==1 and
                sum(e.get('event')=='phase_end' for e in events)==1 and
                all(not e['transaction'] and not e['pulse'] and e.get('owner') is None and e.get('pending') is None
                    for e in (events[0],events[-1])), 'phase boundaries or owner quiescence')
        commands = [e for e in events if e.get('event') == 'command_before']
        after = [e for e in events if e.get('event') == 'command_after']
        suppressed = [e for e in events if e.get('event') == 'command_suppressed']
        require(len(commands) == MAX_LIVES and len(after) + len(suppressed) == len(commands) and
                all(isinstance(e.get('detail'), dict) and e['detail'] == {'mode': 'random', 'lag': 4, 'speed_argument': 0}
                    for e in commands), 'commands')
        require((len(after) == 1 and len(suppressed) == len(commands) - 1) if key[1] == 'held'
                else (len(after) == len(commands) and not suppressed), 'policy dispatch')
        intents=[e for e in events if e.get('event')=='contact_'+kind+'_intent_random']
        require(len(intents)==len(after) and all(isinstance(e.get('detail'),dict) and
                e['detail'].get('choice')==0 and e['detail'].get('chance')==4 for e in intents),
                'forwarded random command observations')
        lives = [e for e in events if e.get('event') == 'contact_' + kind + '_life_before']
        require(len(lives) == len(commands) == row.get('life_count') == MAX_LIVES and
                all(b['at']-a['at']>=10 for a,b in zip(lives,lives[1:])), 'real Life observations')
        seek = [e for e in events if e.get('event') == 'contact_roll_' + kind + '_seek']
        require(len(seek)==len(lives) and all(isinstance(e.get('detail'),dict) and
                e['detail'].get('choice')==0 and e['detail'].get('raw') in (0,1) and
                e['detail'].get('chance')==(70 if kind=='mosquito' else 80) for e in seek), 'seek tape')
        secondary=('mosquito_water',) if kind=='mosquito' else ('bat_cow','bat_bull')
        for site in secondary:
            rolls=[e for e in events if e.get('event')=='contact_roll_'+site]
            require(len(rolls)==len(lives) and all(isinstance(e.get('detail'),dict) and
                    e['detail'].get('choice')==0 and e['detail'].get('raw') in (0,1) and
                    e['detail'].get('chance')==(15 if site=='mosquito_water' else 20) for e in rolls),
                    'secondary tape')
        bite_rolls=[e for e in events if e.get('event')=='contact_roll_'+kind+'_bite']
        tape=(1,0,1,1,0,1,1,0)
        require(len(bite_rolls)==len(lives) and all(isinstance(e.get('detail'),dict) and
                e['detail'].get('choice')==tape[i%len(tape)] and e['detail'].get('raw') in (0,1) and
                e['detail'].get('chance')==(10 if kind=='mosquito' else 5) for i,e in enumerate(bite_rolls)),
                'bite tape')
        move_enters=sum(e.get('event') == 'move_enter' for e in events)
        move_exits=sum(e.get('event') == 'move_exit' for e in events)
        require(4 <= move_enters == move_exits <= MAX_MOVES_PER_SIDE and
                move_enters==row.get('move_enter_count') and move_exits==row.get('move_exit_count'),
                'Move observations')
        if mode == 'legacy':
            require(row.get('tx_count')==0 and not any(e.get('event') in ('tx_admitted', 'final_pulse', 'tx_actor_released','tx_finished') for e in events), 'legacy transaction')
        else:
            admitted = [e.get('tx') for e in events if e.get('event') == 'tx_admitted']
            cleaned = [e.get('tx') for e in events if e.get('event') == 'tx_finished']
            require(4 <= len(admitted) <= MAX_TRANSACTIONS and len(admitted)==row.get('tx_count') and
                    all(isinstance(x, str) and x for x in admitted) and
                    len(admitted) == len(cleaned) and sorted(admitted) == sorted(cleaned), 'transaction lifecycle')
            require(all(e.get('arrived') in (0, 1) and not e['transaction'] for e in events
                        if e.get('event') == 'tx_finished'), 'finished state')
        analysis = inspect_events(events, mode, kind)
        require(analysis['bites'] and analysis['infections'] and
                any(not item['roll'] for item in analysis['opportunities']),
                'contact exercise lacks positive bite, infection or suppressed roll')
        # Keep the complete raw stream for independent physical and timing analysis.
        found[key] = {'row': row, 'analysis': analysis}
    require(set(found) == {(a, b, c) for a in KINDS for b in POLICIES for c in PHASES}, 'matrix')
    require(receipt['random_count'] == total, 'event count mismatch')
    require(len(json.dumps(receipt, separators=(',', ':')).encode()) <= MAX_RECEIPT, 'receipt byte cap')
    return found


def compare(receipts, head, tick):
    """Report measured timing/opportunities without declaring behavioral parity."""
    require(isinstance(receipts, dict) and set(receipts) == set(MODES), 'comparison modes')
    by_mode = {mode: validate(receipts[mode], head, mode, tick) for mode in MODES}
    comparison = {}
    for key in sorted(by_mode['legacy']):
        sizes = {by_mode[mode][key]['row']['step_size'] for mode in MODES}
        require(len(sizes) == 1, 'effective native step sizes differ')
        observed = {}
        for mode in MODES:
            info = by_mode[mode][key]['analysis']
            movement = info['physical_moves']
            cycle_starts = ([m['started'] for m in movement if not m['overlaps_life']] if mode == 'legacy'
                            else [t['at'] for t in info['admissions']])
            forwarded = [c for c in info['commands'] if c['result'] != 'fixture_suppressed']
            require(len(cycle_starts)>=4 and forwarded and cycle_starts[0]>=forwarded[0]['at'],
                    'insufficient attributable cycle observations')
            observed[mode] = {'commands': info['commands'], 'physical_moves': movement,
                              'admissions': info['admissions'], 'final_pulses': info['final_pulses'],
                              'cleanups': info['cleanups'], 'opportunities': info['opportunities'],
                              'infections': info['infections'],
                              'bites': info['bites'],
                              'cycle_starts': cycle_starts,
                              'first_delay': cycle_starts[0]-forwarded[0]['at'],
                              'completion_delays': [t['finished']-t['admitted'] for t in info['cleanups']],
                              'intervals': [b - a for a, b in zip(cycle_starts, cycle_starts[1:])]}
        comparison[':'.join(map(str, key))] = observed
    return {'tick_lag_ds': tick, 'step_size_basis': 'native Speed=0 uses recorded step_size',
            'directions': 'actual displacements are retained; common seed does not align directions',
            'legacy_cycle_basis': 'Move starts outside observed Life extent; background producer identity is not proven',
            'parity_established': False, 'cases': comparison}
