"""Stuck-pair resolver contracts: source projections, not native execution.

The nearest-tile helper is translated from the actual DM statements and checked
against every straight pair state the producer can leave behind. The settle,
save-admission and default-on checks are source-order contracts. None of this
launches BYOND, a world or a client.
"""
from pathlib import Path
import re
import sys
import unittest

sys.path.insert(0, str(Path(__file__).resolve().parent))
from test_ownership import projected_shift  # noqa: E402

ROOT = Path(__file__).resolve().parents[2]
PREFIX = 'code/game/mob/living/carbon/human/'
DIRS = dict(NORTH=1, SOUTH=2, EAST=4, WEST=8)


def read(name):
    return (ROOT / name).read_text(encoding='utf-8').replace('\r\n', '\n')


def section(text, start, end):
    value = text[text.index(start):]
    return value[:value.index(end)]


def projected_nearest():
    text = section(read(PREFIX + 'pull_pair_lifecycle.dm'), '/proc/subtile_pull_nearest_tile(',
                   '/datum/subtile_pull_pair/proc/resolve_after')
    exact = {
        'var/list/target = position.Copy()': 'target = dict(position)',
        'if (target["sx"] >= 16)': 'if target["sx"] >= 16:',
        'if (target["sy"] >= 16)': 'if target["sy"] >= 16:',
        'target["x"]++': 'target["x"] += 1',
        'target["y"]++': 'target["y"] += 1',
        'target["sx"] = 0': 'target["sx"] = 0',
        'target["sy"] = 0': 'target["sy"] = 0',
        'return target': 'return target',
    }
    lines = ['def nearest(position):']
    for line in text[text.index('\n') + 1:].rstrip().splitlines():
        value = line.strip()
        if not value or value.startswith('//'):
            continue
        if value not in exact:
            raise ValueError('Unprojected nearest-tile statement: ' + value)
        lines.append('    ' * (len(line) - len(line.lstrip('\t'))) + exact[value])
    namespace = {}
    exec(compile('\n'.join(lines), '<actual-nearest-tile>', 'exec'), {'__builtins__': {'dict': dict}}, namespace)
    return namespace['nearest']


def world(position):
    return position['x'] * 32 + position['sx'], position['y'] * 32 + position['sy']


class StuckPairResolverContracts(unittest.TestCase):
    def test_nearest_tiles_never_coincide_and_move_at_most_half_a_tile(self):
        shift, nearest = projected_shift(), projected_nearest()
        cases = 0
        for direction in DIRS.values():
            dx = 1 if direction == 4 else -1 if direction == 8 else 0
            dy = 1 if direction == 1 else -1 if direction == 2 else 0
            leader_origin = dict(x=6, y=6, z=1, sx=0, sy=0)
            follower_origin = dict(x=6 - dx, y=6 - dy, z=1, sx=0, sy=0)
            for leading in range(33):
                for trailing in range(max(0, leading - 2), leading + 1):
                    leader, follower = dict(leader_origin), dict(follower_origin)
                    for amount in [2] * (leading // 2) + [leading % 2] * (leading % 2):
                        leader = shift(leader, direction, amount)
                    for amount in [2] * (trailing // 2) + [trailing % 2] * (trailing % 2):
                        follower = shift(follower, direction, amount)
                    targets = []
                    for actual, origin in ((leader, leader_origin), (follower, follower_origin)):
                        target = nearest(actual)
                        self.assertEqual((target['sx'], target['sy'], target['z']), (0, 0, 1))
                        ax, ay = world(actual)
                        tx, ty = world(target)
                        self.assertLessEqual(abs(ax - tx) + abs(ay - ty), 16)
                        # Only the intent's own origin or destination tile.
                        self.assertIn((target['x'], target['y']), ((origin['x'], origin['y']), (origin['x'] + dx, origin['y'] + dy)))
                        targets.append((target['x'], target['y']))
                    self.assertNotEqual(targets[0], targets[1], (direction, leading, trailing))
                    cases += 1
        self.assertEqual(cases, 4 * 96)

    def test_settle_resolves_unrecoverable_pairs_and_always_schedules_a_fallback(self):
        settle = section(read(PREFIX + 'pull_pair_producer.dm'), '/datum/subtile_pull_pair/proc/settle_intent()',
                         '/datum/subtile_pull_pair/proc/restore_follower_glide()')
        self.assertLess(settle.index('if (release())\n\t\treturn'), settle.index('recovery_required = TRUE'))
        self.assertIn('if (!recovery_possible() && resolve_aligned("unrecoverable"))\n\t\treturn', settle)
        self.assertTrue(settle.rstrip().endswith('resolve_after(recovery_grace)'))
        lifecycle = read(PREFIX + 'pull_pair_lifecycle.dm')
        possible = section(lifecycle, '/datum/subtile_pull_pair/proc/recovery_possible()', '\n\n')
        for requirement in ('leader.client', 'leader.client.mob == leader', 'recovery_ready(leader)'):
            self.assertIn(requirement, possible)
        # recovery_ready rejects orphans and dead/downed/restrained leaders.
        ready = section(read(PREFIX + 'pull_pair_producer.dm'), '/datum/subtile_pull_pair/proc/recovery_ready',
                        '/datum/subtile_pull_pair/proc/begin_recovery')
        self.assertIn('if (orphaned || !registry', ready)
        self.assertIn('!leader_allowed()', ready)
        allowed = read(PREFIX + 'pull_pair_ownership.dm')
        for state in ('!leader.stat', 'leader.canmove', '!leader.lying', '!leader.restrained()'):
            self.assertIn(state, section(allowed, '/datum/subtile_pull_pair/proc/leader_allowed()', '\n\n'))

    def test_timer_retries_until_released_and_stale_epochs_stop(self):
        timer = section(read(PREFIX + 'pull_pair_lifecycle.dm'), '/datum/subtile_pull_pair/proc/resolve_after',
                        '// Settle a quiet held pair')
        self.assertIn('var/epoch = ++resolve_epoch', timer)
        self.assertIn('if (!released && resolve_epoch == epoch && !resolve_aligned("recovery_timeout"))\n\t\t\tresolve_after(delay)', timer)
        self.assertIn('var/recovery_grace = 50', read(PREFIX + 'pull_pair_lifecycle.dm'))

    def test_resolver_waits_for_unwind_and_saves_then_aligns_before_dropping_lease(self):
        text = read(PREFIX + 'pull_pair_lifecycle.dm')
        resolve = section(text, '/datum/subtile_pull_pair/proc/resolve_aligned(reason, datum/persistence_world_operation/admission)',
                          '/datum/subtile_pull_ownership/proc/resolve_quiet')
        guard = resolve.index('if (settling || intent_running || native_inflight || completion_running || issued)\n\t\treturn FALSE')
        save = resolve.index('if (persistence_save_in_progress && !(admission && persistence_active_operation == admission && !admission.backend_started))\n\t\treturn FALSE')
        self.assertLess(guard, resolve.index('cancel(reason)'))
        self.assertLess(save, resolve.index('cancel(reason)'))
        self.assertLess(resolve.index('cancel(reason)'), resolve.index('member.forceMove(destination)'))
        # Executed final-position checks live in test_settle_admission.py.
        self.assertLess(resolve.index('member.forceMove(destination)'), resolve.index('failure = "settle_position_changed"'))
        self.assertLess(resolve.index('failure = "settle_position_changed"'), resolve.index('drop_lease()'))
        self.assertIn('if (isDeleted(member))\n\t\t\tcontinue', resolve)
        self.assertNotRegex(resolve, r'\bloc\s*=(?!=)')
        for forbidden in ('sleep(', 'spawn(', '.Move('):
            self.assertNotIn(forbidden, resolve)
        lease = section(read(PREFIX + 'pull_pair_ownership.dm'), '/datum/subtile_pull_pair/proc/drop_lease()',
                        '/datum/subtile_pull_capability\n')
        for cleared in ('registry.owners -= leader', 'registry.owners -= follower', 'released = TRUE',
                        'leader = null', 'follower = null', 'controller = null', 'registry = null'):
            self.assertIn(cleared, lease)
        release = section(read(PREFIX + 'pull_pair_ownership.dm'), '/datum/subtile_pull_pair/proc/release()',
                          '/datum/subtile_pull_pair/proc/drop_lease()')
        self.assertLess(release.index('cancel("released")'), release.index('drop_lease()'))

    def test_save_admission_reserves_then_settles_quiet_pairs_before_the_hold(self):
        body = section(read('code/modules/persistence/functions.dm'), '/proc/begin_persistence_operation(',
                       '/datum/persistence_world_operation\n')
        resolve = body.index('subtile_pull_ownership.resolve_quiet("save_admission", operation)')
        self.assertLess(body.index('if(persistence_save_in_progress && !(restart_owner'), resolve)
        self.assertLess(body.index('persistence_active_operation = operation'), resolve)
        self.assertLess(resolve, body.index('!subtile_pull_ownership.save_ready()'))
        quiet = section(read(PREFIX + 'pull_pair_lifecycle.dm'), '/datum/subtile_pull_ownership/proc/resolve_quiet',
                        '/datum/subtile_pull_pair/proc/save_checkpoint()')
        self.assertIn('if (P.intent_completed && !P.resolve_aligned(reason, admission))\n\t\t\t. = FALSE', quiet)
        self.assertLess(quiet.index('pairs += P'), quiet.index('P.resolve_aligned(reason, admission)'))

    def test_smooth_pulling_is_on_by_default_and_follows_the_movement_toggle(self):
        producer = read(PREFIX + 'pull_pair_producer.dm')
        self.assertIn('var/tmp/human_subtile_pull_enabled = TRUE', producer)
        ready = section(producer, '/mob/living/human/proc/human_subtile_pull_ready', '/mob/living/human/proc/human_subtile_pull_travel')
        self.assertIn('!human_subtile_pull_enabled || !human_subtile_enabled', ready)
        human = read(PREFIX + 'subtile_movement.dm')
        self.assertIn('if (key == "human_subtile_pull_enabled")\n\t\treturn TRUE', human)
        self.assertRegex(human, r'verb/toggle_smooth_movement\(\)(?:.|\n)*set_human_subtile\(enabled\)')


if __name__ == '__main__':
    unittest.main(verbosity=2)
