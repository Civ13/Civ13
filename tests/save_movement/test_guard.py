"""Source-bound save admission, movement and protected-sleep regressions."""
from types import MethodType, SimpleNamespace as NS
import re
import unittest

from source_adapter import ROOT, extract, project, read

MOVABLE = 'code/game/atoms_movable.dm'
FUNCTIONS = 'code/modules/persistence/functions.dm'
HELPERS = 'code/game/mob/living/carbon/human/human_helpers.dm'
DAMAGE = 'code/game/mob/mob_damage.dm'


class Area:
    def __init__(self, admin=False):
        self.admin = admin
    def Entered(self, *args):
        pass
    def Exited(self, *args):
        pass


class Atom:
    """Engine boundary: ancestry, contents, raw loc, Entered/Exited callbacks."""
    def __init__(self, loc=None, turf=False, xyz=(0, 0, 0), human=False):
        self.contents, self._loc = [], None
        self.loc = loc
        self.turf, self.xyz, self.human = turf, xyz, human
        self.gcDestroyed = self.gc_destroyed = False
        self.sleeping = self.stat = 0
        self.inducedSSD = self.buckled = False
        self.lastx = self.lasty = self.lastz = 0
        self.on_entry = self.on_release = self.on_drop = None
        self.drop_calls = self.sleep_calls = 0
    @property
    def loc(self):
        return self._loc
    @loc.setter
    def loc(self, target):
        if isinstance(self._loc, Atom):
            self._loc.contents.remove(self)
        self._loc = target
        if isinstance(target, Atom):
            target.contents.append(self)
    @property
    def x(self):
        return self.xyz[0] if self.turf else (self.loc.x if getattr(self.loc, 'turf', False) else 0)
    @property
    def y(self):
        return self.xyz[1] if self.turf else (self.loc.y if getattr(self.loc, 'turf', False) else 0)
    @property
    def z(self):
        return self.xyz[2] if self.turf else (self.loc.z if getattr(self.loc, 'turf', False) else 0)
    def __iter__(self):
        return iter(self.contents.copy())
    def Entered(self, *args):
        if self.on_entry:
            self.on_entry(*args)
    def Exited(self, *args):
        pass
    def Uncrossed(self, *args):
        pass
    def Crossed(self, *args):
        pass
    def release_protected_sleep_buckle(self):
        return self.on_release() if self.on_release else True
    def drop_item(self):
        self.drop_calls += 1
        if self.on_drop:
            self.on_drop()
    def sleep_update(self):
        self.sleep_calls += 1


def get_turf(atom):
    while isinstance(atom, Atom) and not atom.turf:
        atom = atom.loc
    return atom if isinstance(atom, Atom) and atom.turf else None


class Fixture:
    def __init__(self, movable_source=None, operation_source=None):
        self.env = dict(persistence_active_operation=None, persistence_save_in_progress=False,
                        persistence_load_recovery_required=False, world_z_budget=NS(active=False),
                        persistence_restart=NS(startup_hold=False, busy=False, exists=lambda: False),
                        get_turf=get_turf, isturf=lambda a: isinstance(a, Atom) and a.turf,
                        ishuman=lambda a: a.human, ADMIN_AREA='admin',
                        istype=lambda a, kind: isinstance(a, Area) and a.admin,
                        list=lambda *args: args, EXCEPTION=RuntimeError,
                        typed_iter=lambda values, kind: [a for a in values if kind == '/atom/movable' or
                                                        (kind == '/obj' and not a.human) or
                                                        (kind == '/mob' and a.human)],
                        CONSCIOUS=0, UNCONSCIOUS=1, DEAD=2)
        self.area, self.admin = Area(), Area(True)
        self.sleep = Atom(self.admin, turf=True, xyz=(1, 1, 1))
        self.home = Atom(self.area, turf=True, xyz=(3, 2, 2))
        self.same = Atom(self.area, turf=True, xyz=(4, 2, 2))
        self.other = Atom(self.area, turf=True, xyz=(3, 2, 3))
        self.same_plane = Atom(self.area, turf=True, xyz=(3, 2, 1))
        self.env['locate'] = lambda x, y, z: next((t for t in (self.sleep, self.home, self.same, self.other, self.same_plane) if t.xyz == (x, y, z)), None)
        movable = movable_source or read(MOVABLE)
        functions = operation_source or read(FUNCTIONS)
        self.env['persistence_save_active'] = project(functions, '/proc/persistence_save_active', '', self.env)
        self.env['persistence_sleep_transfer_blocked'] = project(functions, '/proc/persistence_sleep_transfer_blocked', '', self.env)
        self.env['persistence_live_contents'] = project(movable, '/proc/persistence_live_contents', 'container', self.env)
        self.allow = project(movable, '/proc/persistence_movement_allowed', 'mover, destination', self.env)
        self.env['persistence_movement_allowed'] = self.allow
        self.env['is_protected_sleep_location'] = project(read(HELPERS), '/proc/is_protected_sleep_location', 'location', self.env)
        self.move = project(movable, '/atom/movable/proc/forceMove', 'src, destination, special_event=None', self.env, True)
        self.raw = project(movable, '/atom/movable/proc/persistence_set_loc', 'src, destination', self.env, True)
        self.zmove = project(movable, '/atom/movable/proc/persistence_set_z', 'src, target_z', self.env, True)
        self.enter = project(read(HELPERS), '/mob/living/human/proc/enter_protected_sleep', 'src', self.env, True)
        self.wake = project(read(HELPERS), '/mob/living/human/proc/complete_protected_wakeup', 'src', self.env, True)
        self.sleep_methods = {name: project(read(DAMAGE), '/mob/proc/' + name, 'src, amount', self.env, True)
                              for name in ('Sleeping', 'SetSleeping', 'AdjustSleeping')}
        self.zone = project(read(DAMAGE), '/mob/proc/in_protected_sleep_zone', 'src', self.env, True)
        self.stat = project(read('code/game/mob/mob.dm'), '/mob/proc/set_stat', 'src, new_stat', self.env, True)
        self.begin = project(functions, '/proc/begin_persistence_operation', 'storage, kind, transaction=None', self.env)
        self.env['begin_persistence_operation'] = self.begin
        self.op_methods = {name: project(functions, 'proc/' + name, args, self.env, True)
                           for name, args in (('current', 'src, expected_storage, expected_kind'),
                                              ('enter_backend', 'src, expected_storage, expected_kind'),
                                              ('enter_contents', 'src, expected_storage, expected_kind'),
                                              ('finish', 'src, success'))}
        self.env['new_operation'] = self.operation
        self.backend = project(functions, '/map_storage/proc/run_world_operation', 'src, kind, operation=None', self.env, True)
        self.store = NS(dimension_recovery_required=False, dimension_budget_hold=False)
    def operation(self):
        op = NS(storage=None, kind=None, backend_started=False, contents_started=False,
                mutation_started=False, restoring_players=False)
        for name, function in self.op_methods.items():
            setattr(op, name, MethodType(function, op))
        return op
    def actor(self, loc=None, human=True):
        actor = Atom(loc or self.home, human=human)
        for name, method in dict(forceMove=self.move, persistence_set_loc=self.raw,
                                 persistence_set_z=self.zmove, in_protected_sleep_zone=self.zone,
                                 set_stat=self.stat, **self.sleep_methods).items():
            setattr(actor, name, MethodType(method, actor))
        return actor


class GuardTests(unittest.TestCase):
    def test_operating_table_refuses_before_resting_or_announcing(self):
        f = Fixture()
        human, table = f.actor(), f.actor(f.other, human=False)
        events = []
        human.resting = False
        human.visible_message = lambda *args: events.append('message')
        f.env.update(visible_message=lambda *args: events.append('message'),
                     add_fingerprint=lambda *args: events.append('fingerprint'))
        take = project(read('code/game/objects/structures/optable.dm'), '/obj/structure/optable/proc/take_victim', 'src, C, user', f.env, True)
        operation = f.begin(f.store, 'save')
        self.assertFalse(take(table, human, human))
        self.assertFalse(human.resting)
        self.assertEqual(events, [])
        self.assertIs(human.loc, f.home)
        operation.finish(True)
        take(table, human, human)
        self.assertTrue(human.resting)
        self.assertIs(human.loc, f.other)

    def test_football_preflight_is_noop_for_cross_z_but_allows_same_z_save_reset(self):
        f = Fixture()
        human, ball = f.actor(), f.actor(human=False)
        human.original_job = NS(spawn_location='player-spawn')
        human.football = ball
        events = []
        class Client:
            def __lshift__(self, value):
                events.append('sound')
        human.client = Client()
        ball.owner, ball.last_owner = human, None
        class World:
            time = 42
            def __iter__(self):
                return iter([ball])
        def typed(values, kind):
            return [a for a in values if kind == '/atom/movable' or
                    (kind.startswith('/mob') and a.human) or
                    (kind.startswith('/obj') and not a.human)]
        f.env.update(world=World(), player_list=[human], typed_iter=typed,
                     latejoin_turfs={'player-spawn': [f.same], 'football': [f.other]},
                     list=lambda *args: tuple(args) if args else {}, pick=lambda values: values[0],
                     sound=lambda *args, **kwargs: 'whistle', to_chat=lambda *args: events.append('message'),
                     deferred=lambda delay: False)
        reset = project(read('code/game/objects/map_metadata/football.dm'), '/obj/map_metadata/football/proc/reset_ball', 'src', f.env, True)
        metadata = NS(stopped=False, stopped_until=0)
        f.begin(f.store, 'save')
        self.assertFalse(reset(metadata))
        self.assertEqual((metadata.stopped, metadata.stopped_until), (False, 0))
        self.assertEqual(events, [])
        self.assertIs(ball.owner, human)
        self.assertIs(human.loc, f.home)
        f.env['latejoin_turfs']['football'] = [f.same]
        self.assertTrue(reset(metadata))
        self.assertIs(human.loc, f.same)
        self.assertIs(ball.loc, f.same)
        self.assertIsNone(ball.owner)
        self.assertIsNone(human.football)
        self.assertTrue(metadata.stopped)

    def test_admin_jump_refusal_has_no_success_log_or_follow_reset(self):
        f = Fixture()
        human = f.actor()
        events = []
        human.on_mob_jump = lambda: events.append('follow-reset')
        f.env.update(usr=human, config=NS(allow_admin_jump=True), R_ADMIN=1, R_MOD=2, R_DEBUG=4,
                     check_rights=lambda rights: True, log_admin=lambda message: events.append('log'),
                     message_admins=lambda *args: events.append('announcement'), key_name_admin=lambda user: 'fixture')
        jump = project(read('code/modules/admin/verbs/adminjump.dm'), '/client/proc/jumptoturf', 'src, T', f.env, True)
        operation = f.begin(f.store, 'save')
        self.assertFalse(jump(NS(), f.other))
        self.assertEqual(events, [])
        self.assertIs(human.loc, f.home)
        operation.finish(False)
        jump(NS(), f.other)
        self.assertIs(human.loc, f.other)
        self.assertEqual(events, ['log', 'announcement', 'follow-reset'])

    def test_area_callback_refusal_does_not_update_covers_and_can_retry(self):
        f = Fixture()
        cover, human = f.actor(human=False), f.actor()
        cover.is_cover = True
        events = []
        cover.updateturf = lambda: events.append('cover-update')
        teleporter = NS(movement_location='DOWN', scope=[cover, human])
        f.env.update(get_area=lambda source: source.scope, deferred=lambda ticks: True)
        callback = project(read('code/modules/multiz/area_teleporter.dm'), '/obj/effect/area_teleporter/proc/Simple_Up', 'src', f.env, True)
        operation = f.begin(f.store, 'save')
        callback(teleporter)
        self.assertEqual(events, [])
        self.assertIs(cover.loc, f.home)
        self.assertIs(human.loc, f.home)
        operation.finish(True)
        callback(teleporter)
        self.assertEqual(events, ['cover-update'])
        self.assertIs(cover.loc, f.other)
        self.assertIs(human.loc, f.other)

    def test_nonregistered_admin_visitor_requires_exit_without_fake_return(self):
        f = Fixture()
        visitor = f.actor(f.sleep)
        visitor.SetSleeping(0)
        visitor.set_stat(0)
        self.assertEqual((visitor.sleeping, visitor.stat), (2, 1))
        self.assertFalse(f.wake(visitor))
        self.assertEqual((visitor.lastx, visitor.lasty, visitor.lastz), (0, 0, 0))
        operation = f.begin(f.store, 'save')
        self.assertFalse(visitor.forceMove(f.home))
        operation.finish(True)
        self.assertTrue(visitor.forceMove(f.home))
        visitor.SetSleeping(0)
        visitor.set_stat(0)
        self.assertEqual((visitor.sleeping, visitor.stat), (0, 0))

    def test_same_z_sleep_transfers_use_owner_through_all_save_phases(self):
        f = Fixture()
        human = f.actor(f.same_plane)
        for phase in ('preparation', 'backend', 'contents', 'cleanup'):
            with self.subTest(phase=phase):
                operation = f.begin(f.store, 'save')
                if phase != 'preparation':
                    operation.enter_backend(f.store, 'save')
                if phase in ('contents', 'cleanup'):
                    operation.enter_contents(f.store, 'save')
                # Prove helpers are not relying on the compatibility flag.
                f.env['persistence_save_in_progress'] = False
                self.assertTrue(f.allow(human, f.sleep))  # generic same-z motion
                before = human.drop_calls
                self.assertFalse(f.enter(human))
                self.assertEqual(human.drop_calls, before)
                self.assertFalse(human.inducedSSD)
                operation.finish(False)
        self.assertTrue(f.enter(human))
        operation = f.begin(f.store, 'save')
        f.env['persistence_save_in_progress'] = False
        self.assertFalse(f.wake(human))
        self.assertIs(human.loc, f.sleep)
        self.assertTrue(human.inducedSSD)
        operation.finish(True)
        self.assertTrue(f.wake(human))
        self.assertIs(human.loc, f.same_plane)

    def test_retired_and_nullspace_carriers_cannot_launder_live_contents(self):
        f = Fixture()
        box = f.actor(human=False)
        retired_inner = f.actor(box, human=False)
        human = f.actor(retired_inner)
        box.gc_destroyed = retired_inner.gc_destroyed = -1
        operation = f.begin(f.store, 'save')
        self.assertFalse(box.forceMove(None))
        self.assertIs(get_turf(human), f.home)
        self.assertFalse(box.forceMove(f.other))
        operation.finish(False)
        box.loc = None  # already unplaced carrier at next admission
        f.begin(f.store, 'save')
        self.assertFalse(box.forceMove(f.other))
        box.gc_destroyed = retired_inner.gc_destroyed = False
        self.assertFalse(box.persistence_set_loc(f.other))
        self.assertIs(human.loc, retired_inner)
        fresh = Atom()
        fresh.forceMove = MethodType(f.move, fresh)
        self.assertTrue(fresh.forceMove(f.other))  # empty creation exception
        fresh.gc_destroyed = -1
        self.assertTrue(fresh.forceMove(None))  # empty deletion exception
        self.assertFalse(fresh.forceMove(f.home))

    def test_success_false_and_exception_keep_guard_through_backend_and_cleanup(self):
        for outcome in (True, False, RuntimeError('cancelled/failing writer')):
            with self.subTest(outcome=outcome):
                f = Fixture()
                observed = []
                def backend(operation):
                    observed.append(f.env['persistence_active_operation'] is operation)
                    self.assertIsNone(f.begin(f.store, 'save'))
                    self.assertFalse(f.allow(f.actor(), f.other))
                    self.assertTrue(operation.enter_contents(f.store, 'save'))
                    if isinstance(outcome, Exception):
                        raise outcome
                    return outcome
                def cleanup():
                    observed.append(f.env['persistence_active_operation'] is not None)
                f.store.save_world_contents = backend
                f.store.cleanup_world_operation = cleanup
                if isinstance(outcome, Exception):
                    with self.assertRaisesRegex(RuntimeError, 'cancelled'):
                        f.backend(f.store, 'save')
                else:
                    self.assertEqual(f.backend(f.store, 'save'), outcome)
                self.assertTrue(all(observed))
                self.assertEqual(len(observed), 1 if outcome is True else 2)
                self.assertIsNone(f.env['persistence_active_operation'])
                self.assertFalse(f.env['persistence_save_in_progress'])
                self.assertTrue(f.allow(f.actor(), f.other))

    def test_stale_finish_overlap_reentry_and_load_recovery(self):
        f = Fixture()
        first = f.begin(f.store, 'save')
        self.assertIsNone(f.begin(f.store, 'save'))
        self.assertTrue(first.enter_backend(f.store, 'save'))
        self.assertFalse(first.enter_backend(f.store, 'save'))
        self.assertTrue(first.finish(False))  # cancellation before writer
        second = f.begin(f.store, 'save')
        self.assertFalse(f.backend(f.store, 'save', first))
        self.assertFalse(first.finish(True))
        self.assertIs(f.env['persistence_active_operation'], second)
        self.assertFalse(f.allow(f.actor(), f.other))
        second.finish(True)
        load = f.begin(f.store, 'load')
        self.assertTrue(f.allow(f.actor(), f.other))
        load.enter_backend(f.store, 'load')
        load.finish(False)
        self.assertTrue(f.env['persistence_load_recovery_required'])
        self.assertTrue(f.env['persistence_save_in_progress'])

    def test_cleanup_exceptions_still_release_only_the_owned_guard(self):
        f = Fixture()
        attempts, logs = [], []
        class Log:
            def __lshift__(self, message):
                logs.append(message)
        f.env['world'] = NS(log=Log())
        cleanup = project(read(FUNCTIONS), '/map_storage/proc/cleanup_world_operation', 'src', f.env, True)
        def failing_cleanup(label):
            def callback():
                self.assertIsNotNone(f.env['persistence_active_operation'])
                attempts.append(label)
                raise RuntimeError(label)
            return callback
        f.store.clear_bookkeeping = failing_cleanup('bookkeeping')
        f.store.release_durable_world = failing_cleanup('durable')
        f.store.cleanup_world_operation = lambda: cleanup(f.store)
        f.store.save_world_contents = lambda operation: False
        self.assertFalse(f.backend(f.store, 'save'))
        self.assertEqual(attempts, ['bookkeeping', 'durable'])
        self.assertEqual(len(logs), 2)
        self.assertIsNone(f.env['persistence_active_operation'])
        self.assertFalse(f.env['persistence_save_in_progress'])

    def test_legacy_z_setter_uses_physical_container_turf_and_rejects_invalid_target(self):
        f = Fixture()
        container = f.actor(human=False)
        human = f.actor(container)
        f.begin(f.store, 'save')
        self.assertFalse(human.persistence_set_z(3))
        self.assertFalse(container.persistence_set_z(3))
        self.assertFalse(container.persistence_set_z(99))
        self.assertIs(human.loc, container)
        f.env['persistence_active_operation'].finish(True)
        self.assertTrue(container.persistence_set_z(3))
        self.assertIs(get_turf(human), f.other)

    def test_objects_and_nested_players_cannot_cross_z_or_detour_via_null(self):
        f = Fixture()
        box = f.actor(human=False)
        inner = f.actor(box, human=False)
        human = f.actor(inner)
        self.assertEqual(human.z, 0)  # native coordinates hide containment
        operation = f.begin(f.store, 'save')
        for method in (box.forceMove, box.persistence_set_loc):
            box.persistence_set_loc(f.home)
            self.assertFalse(method(f.other))
            self.assertIs(get_turf(human), f.home)
            self.assertFalse(method(None))
            self.assertIs(box.loc, f.home)
            self.assertTrue(method(f.same))
            self.assertIs(get_turf(human), f.same)
        self.assertFalse(human.forceMove(f.other))
        operation.finish(True)
        self.assertTrue(box.forceMove(f.other))
        self.assertIs(get_turf(human), f.other)

    def test_internal_same_z_transfer_and_retirement_do_not_wait(self):
        f = Fixture()
        rack = f.actor(human=False)
        item = f.actor(rack, human=False)
        f.begin(f.store, 'save')
        self.assertTrue(item.forceMove(f.home))
        self.assertFalse(item.forceMove(None))
        item.gc_destroyed = -1  # qdel marks this before Destroy, not gcDestroyed
        self.assertTrue(item.forceMove(None))
        self.assertNotIn('sleep(', extract(read(MOVABLE), '/proc/persistence_movement_allowed'))

    def test_sleep_entry_busy_retry_and_callback_admission(self):
        f = Fixture()
        human = f.actor()
        operation = f.begin(f.store, 'save')
        self.assertFalse(f.enter(human))
        self.assertIs(human.loc, f.home)
        self.assertFalse(human.inducedSSD)
        operation.finish(True)
        human.on_drop = lambda: f.begin(f.store, 'save')
        self.assertFalse(f.enter(human))
        self.assertFalse(human.inducedSSD)
        f.env['persistence_active_operation'].finish(False)
        human.on_drop = None
        self.assertTrue(f.enter(human))
        self.assertIs(human.loc, f.sleep)
        self.assertEqual((human.lastx, human.lasty, human.lastz), f.home.xyz)
        self.assertTrue(human.inducedSSD)

    def test_sleep_zone_natural_forced_and_contained_waking_without_save(self):
        f = Fixture()
        box = f.actor(f.sleep, human=False)
        human = f.actor(box)
        self.assertFalse(human.inducedSSD)
        human.sleeping = 3
        for _ in range(100):
            human.AdjustSleeping(-1)
        self.assertEqual(human.sleeping, 2)
        human.SetSleeping(0)
        self.assertEqual(human.sleeping, 2)
        human.set_stat(0)
        self.assertEqual(human.stat, 1)
        human.loc = f.home
        human.SetSleeping(0)
        human.set_stat(0)
        self.assertEqual((human.sleeping, human.stat), (0, 0))

    def test_safe_normal_return_busy_retry_and_invalid_zone_destination(self):
        f = Fixture()
        human = f.actor()
        self.assertTrue(f.enter(human))
        operation = f.begin(f.store, 'save')
        self.assertFalse(f.wake(human))
        self.assertIs(human.loc, f.sleep)
        self.assertTrue(human.inducedSSD)
        operation.finish(False)
        human.lastx, human.lasty, human.lastz = f.sleep.xyz
        self.assertFalse(f.wake(human))
        human.lastx, human.lasty, human.lastz = f.home.xyz
        human.on_release = lambda: (f.begin(f.store, 'save'), True)[1]
        self.assertFalse(f.wake(human))
        self.assertTrue(human.inducedSSD)
        f.env['persistence_active_operation'].finish(True)
        human.on_release = None
        self.assertTrue(f.wake(human))
        self.assertIs(human.loc, f.home)
        self.assertEqual(human.sleeping, 0)
        self.assertFalse(human.inducedSSD)

    def test_wake_callbacks_cannot_commit_if_they_start_saving_or_redirect(self):
        for redirect in (False, True):
            f = Fixture()
            human = f.actor()
            self.assertTrue(f.enter(human))
            f.home.on_entry = lambda *args: setattr(human, 'loc', f.sleep) if redirect else f.begin(f.store, 'save')
            self.assertFalse(f.wake(human))
            self.assertTrue(human.inducedSSD)
            self.assertGreater(human.sleeping, 0)

    def test_guard_and_stale_owner_negative_controls_are_observable(self):
        source = read(MOVABLE)
        f = Fixture(movable_source=source.replace('return origin.z == target.z', 'return TRUE'))
        f.begin(f.store, 'save')
        self.assertTrue(f.actor(human=False).forceMove(f.other))
        source = read(FUNCTIONS)
        source = source.replace('if(persistence_active_operation != src) return FALSE', 'if(FALSE) return FALSE')
        f = Fixture(operation_source=source)
        first = f.begin(f.store, 'save')
        first.finish(True)
        f.begin(f.store, 'save')
        self.assertTrue(first.finish(True))
        self.assertIsNone(f.env['persistence_active_operation'])


class SourcePathTests(unittest.TestCase):
    def test_delayed_attachments_admit_before_recording_relationships(self):
        source = read('code/modules/1713/punishment.dm')
        for family in ('noose', 'gallows', 'cross', 'pillory', 'post_execution'):
            body = extract(source, '/obj/structure/' + family + '/MouseDrop_T')
            self.assertLess(body.index('if (!target.persistence_set_loc(get_turf(src))) return FALSE'), body.index('hanging = target'))
            self.assertNotIn('target.loc =', body)
        devour = extract(read('code/game/mob/mob_grab_specials.dm'), '/obj/item/weapon/grab/proc/devour')
        self.assertLess(devour.index('if (!target.persistence_set_loc(user)) return FALSE'), devour.index('admin_attack_log'))
        self.assertLess(devour.index('persistence_set_loc(user)'), devour.index('stomach_contents.Add(target)'))

    def test_confirmed_remote_writers_have_actual_commit_guards(self):
        jobs = read('code/game/jobs/job_controller.dm')
        self.assertIn('if (!H.persistence_set_loc(spawnpoint)) return FALSE', jobs)
        self.assertIn('if (!H.persistence_set_loc(null)) return FALSE', jobs)
        admin = read('code/modules/admin/topic.dm')
        self.assertNotRegex(admin, re.compile(r'^\s+H.loc =', re.M))
        self.assertLess(admin.index('if (persistence_save_active()) return FALSE'), admin.index('job_master.EquipRank(H, J)'))
        objective = extract(read('code/game/objects/effects/spawner.dm'), '/obj/effect/spawner/objective_spawner/proc/spawnerproc')
        self.assertIn('new/obj/item/cursedtreasure(locationtomove)', objective)
        self.assertNotIn('targetobjective.loc =', objective)
        goals = extract(read('code/modules/1713/weapons/football.dm'), '/obj/effect/step_trigger/goal/Trigger')
        self.assertLess(goals.index('if (!MF.reset_ball()) return FALSE'), goals.index('MF.teams[team][2] += 1'))
        table = extract(read('code/game/objects/structures/table.dm'), '/obj/structure/table/proc/tablepush')
        self.assertLess(table.index('if (!G.affecting.persistence_set_loc(loc)) return FALSE'), table.index('G.affecting.Weaken(2)'))
        drone = read('code/game/objects/items/devices/drone.dm')
        self.assertLess(drone.index('if (!I || !persistence_movement_allowed(I, src)) return FALSE'), drone.index('user.remove_from_mob(I)'))
        self.assertIn('if (!I.persistence_set_loc(src)) return FALSE', drone)
        self.assertIn('if (!payload.persistence_set_loc(T)) return FALSE', drone)

    def test_generic_storage_admits_before_hooks_and_guards_the_actual_assignment(self):
        for path in ('code/game/objects/items/weapons/storage/storage.dm', 'code/game/objects/items/weapons/storage/misc.dm'):
            source = read(path)
            self.assertIn('if (!persistence_movement_allowed(W, src)) return FALSE', source)
            self.assertIn('if (!persistence_movement_allowed(W, new_location ? new_location : get_turf(src))) return FALSE', source)
            self.assertIn('if (!W.persistence_set_loc(new_location)) return FALSE', source)
            self.assertNotRegex(source, re.compile(r'^\s+W.loc = (src|new_location|get_turf\(src\))$', re.M))

    def test_move_and_turf_admission_guard_before_callbacks_and_after_collision(self):
        for path, proc in (('code/game/mob/mob_movement.dm', '/atom/movable/Move'),
                           ('code/game/turfs/turf.dm', '/turf/Enter')):
            body = extract(read(path), proc)
            self.assertTrue(body.lstrip().startswith('if (!persistence_movement_allowed('))
        body = extract(read('code/game/turfs/turf.dm'), '/turf/Enter')
        self.assertIn('return persistence_movement_allowed(mover, src)', body)

    def test_explicit_cross_z_transports_have_no_raw_coordinate_writes(self):
        for path in ('code/modules/multiz/structures.dm', 'code/modules/multiz/movement.dm',
                     'code/modules/multiz/open_space.dm', 'code/modules/multiz/area_teleporter.dm',
                     'code/game/objects/effects/step_triggers.dm', 'code/game/objects/controls.dm',
                     'code/modules/1713/transporter/lever.dm', 'code/modules/admin/verbs/adminjump.dm',
                     'code/game/objects/effects/bump_teleporter.dm'):
            source = '\n'.join(line.split('//')[0] for line in read(path).splitlines())
            self.assertNotRegex(source, r'(?:\.|\b)z\s*(?:=(?!=)|[+-]=)')
            if path != 'code/game/objects/controls.dm':
                self.assertNotRegex(source, r'(?:\.|\b)loc\s*=(?!=)')
            self.assertIn('persistence_set_', source)

    def test_delayed_transfers_check_at_callback_time(self):
        for path in ('code/game/objects/effects/bump_teleporter.dm',
                     'code/game/objects/controls.dm', 'code/modules/1713/transporter/lever.dm'):
            source = read(path)
            self.assertLess(source.index('spawn'), source.index('persistence_set_'))
        stairs = read('code/game/objects/effects/step_triggers.dm').split('/obj/effect/step_trigger/teleporter/stairs\n')[1]
        self.assertLess(stairs.index('spawn(timer)'), stairs.index('persistence_set_loc'))
        for path, minimum in (('code/game/objects/controls.dm', 1), ('code/modules/1713/transporter/lever.dm', 4)):
            self.assertGreaterEqual(read(path).count('while (persistence_active_operation && persistence_active_operation.kind == "save")'), minimum)

    def test_status_and_forced_writers_use_zone_guards(self):
        body = extract(read('code/game/mob/living/carbon/human/human_life.dm'), '/mob/living/human/handle_regular_status_updates')
        self.assertLess(body.index('in_protected_sleep_zone()'), body.index('handle_some_updates()'))
        self.assertNotIn('stat = CONSCIOUS', body)
        self.assertIn('AdjustSleeping(-5)', read('code/game/mob/living/carbon/carbon.dm'))
        self.assertIn('M.SetSleeping(0)', read('code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Other.dm'))
        self.assertNotIn('M.sleeping = max(0,', read('code/modules/reagents/Chemistry-Reagents/Chemistry-Reagents-Food-Drinks.dm'))
        for path in ('code/game/mob/living/living.dm', 'code/game/mob/living/carbon/human/human_damage.dm'):
            self.assertNotIn('stat = CONSCIOUS', read(path))

    def test_delayed_sleep_verbs_still_pin_the_initiating_client(self):
        source = read(HELPERS)
        for proc, client in (('mob_sleep', 'sleeping_client'), ('mob_wakeup', 'waking_client')):
            body = extract(source, '/mob/living/human/verb/' + proc)
            self.assertIn(f'client != {client} || {client}.mob != src', body)
        wake = extract(source, '/mob/living/human/verb/mob_wakeup')
        self.assertLess(wake.index('spawn(300)'), wake.index('complete_protected_wakeup()'))


if __name__ == '__main__':
    unittest.main()
