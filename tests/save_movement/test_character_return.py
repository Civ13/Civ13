"""Execute complete return/claim DM bodies with explicit engine boundaries.

Source-flow evidence only: no BYOND, disk save, client or world is launched.
"""
import importlib.util
from pathlib import Path
import re
from types import MethodType, SimpleNamespace as NS
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location('return_source_adapter', Path(__file__).with_name('source_adapter.py'))
adapter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(adapter)

SOURCE = adapter.read('code/modules/persistence/player_reclaim.dm') + '\n' + adapter.read('code/modules/persistence/bed_return.dm')
HELPERS = 'code/game/mob/living/carbon/human/human_helpers.dm'


class DMList(list):
    @property
    def len(self):
        return len(self)

    def __getitem__(self, key):
        return super().__getitem__(key - 1)

    def __ior__(self, value):
        if value not in self:
            self.append(value)
        return self


class Assoc(dict):
    def __getitem__(self, key):
        return self.get(key)

    def Remove(self, key):
        self.pop(key, None)


class Body:
    def __init__(self, fixture, turf, owner='account'):
        self.fixture, self.loc = fixture, turf
        self.persistence_owner_ckey = owner
        self.persistence_restored = True
        self.stat, self.client, self._key = 1, None, None
        self.inducedSSD, self.sleeping = True, 66
        self.buckled = None
        self.riding = self.driver = self.driver_vehicle = self.riding_mob = None
        self.lastx = self.lasty = self.lastz = 0
        self.inventory = [object(), object()]
        self.health, self.nutrition = 23, 83
        self.water = 29
        self.organs = [NS(damage=37), NS(damage=11)]
        self.kind, self.density = '/mob/living/human', True
        self.move_hook = None
        self.gc_destroyed = self.gcDestroyed = False
        self.refuse_move = False
        self.refuse_key = False
        self.sleep_updates = 0

    @property
    def key(self):
        return self._key

    @key.setter
    def key(self, key):
        if self.refuse_key:
            return
        self._key = key
        client = self.fixture.client
        old_lobby = client.mob
        client.mob = self
        old_lobby.client = None
        self.client = client

    @property
    def x(self): return self.loc.x
    @property
    def y(self): return self.loc.y
    @property
    def z(self): return self.loc.z

    def forceMove(self, destination):
        if not self.refuse_move:
            self.loc = destination
        if self.move_hook:
            self.move_hook()

    def release_protected_sleep_buckle(self):
        self.buckled = None
        return True

    def record_persistence_owner(self):
        self.persistence_owner_ckey = self.client.ckey

    def sleep_update(self):
        self.sleep_updates += 1


class Turf(list):
    def __init__(self, xyz=(3, 2, 1), kind='/turf/floor', protected=False):
        super().__init__()
        self.x, self.y, self.z = xyz
        self.kind, self.protected, self.density = kind, protected, False

    def __bool__(self): return True
    def __eq__(self, other): return self is other
    def __ne__(self, other): return self is not other


class ReturnFixture:
    def __init__(self):
        self.enabled, self.blocked, self.ready = True, False, True
        self.artifacts = []
        self.world, self.messages, self.deleted = [], [], []
        self.claims, self.registered = Assoc(), Assoc()
        self.home, self.bed_turf = Turf(), Turf((4, 2, 2))
        self.zone = Turf((1, 1, 1), protected=True)
        self.body = Body(self, self.home)
        self.world.append(self.body)
        self.bed = NS(kind='/obj/structure/bed', loc=self.bed_turf,
                      persistence_bed_owner_ckey='account', anchored=True,
                      buckle_lying=True, buckled_mob=None, gc_destroyed=False,
                      gcDestroyed=False, density=False)
        self.world.append(self.bed)
        self.client = NS(ckey='account', key='Account', quickBan_isbanned=lambda kind: False)
        self.lobby = NS(client=self.client, spawning=False, close_spawn_windows=lambda: None)
        self.client.mob = self.lobby
        self.registered['account'] = DMList([self.body])
        self.env = dict(world=self.world, map=NS(uses_durable_metadata=lambda: self.enabled),
                        persistence_player_claims=self.claims,
                        persistence_restored_bodies=self.registered,
                        persistence_player_restore_ready=True,
                        persistence_active_operation=None, persistence_load_recovery_required=False,
                        persistence_save_in_progress=False,
                        istype=lambda value, kind: getattr(value, 'kind', '').startswith(kind),
                        isturf=lambda value: isinstance(value, Turf),
                        get_turf=lambda value: value if isinstance(value, Turf) else getattr(value, 'loc', None),
                        is_protected_sleep_location=lambda value: getattr(value, 'loc', value).protected,
                        IsGuestKey=lambda key: key.startswith('Guest'), DEAD=2,
                        typed_iter=lambda values, kind: [v for v in values if
                            (getattr(v, 'kind', '').startswith(('/obj', '/mob')) if kind == '/atom/movable'
                             else getattr(v, 'kind', '').startswith(kind))],
                        list=DMList, length=len, fexists=lambda path: path in self.artifacts,
                        flist=lambda path: DMList(self.artifacts),
                        locate=lambda x, y, z: next((t for t in (self.home, self.zone, self.bed_turf)
                                                   if (t.x, t.y, t.z) == (x, y, z)), None),
                        qdel=self.deleted.append, EXCEPTION=RuntimeError,
                        SPAN_WARNING=lambda text: text, to_chat=lambda actor, text: self.messages.append(text))
        self.env['persistence_bed_return_enabled'] = self.proc('/proc/persistence_bed_return_enabled', '')
        self.env['persistence_sleep_transfer_blocked'] = lambda: self.blocked
        self.env['persistence_character_turf_safe'] = self.proc('/proc/persistence_character_turf_safe', 'T, H')
        self.bed.valid_character_bed = MethodType(self.proc('/obj/structure/bed/proc/valid_character_bed', 'src, H', True), self.bed)
        self.store = NS(dimension_recovery_required=False, dimension_budget_hold=False,
                        player_restoration_blocked=lambda: self.blocked,
                        find_restored_player=lambda account: self.body if self.ready else None)
        for name in ('character_return_turf', 'prepare_character_return', 'local_character_bodies',
                     'character_recovery_unready', 'character_return_pending', 'allow_new_character',
                     'reclaim_saved_player', 'return_player_eligible', 'finish_character_return'):
            argument = {'character_return_turf': 'H', 'prepare_character_return': 'H',
                        'local_character_bodies': 'account', 'character_return_pending': 'account',
                        'allow_new_character': 'lobby', 'reclaim_saved_player': 'lobby',
                        'return_player_eligible': 'H, account', 'finish_character_return': 'H'}.get(name)
            function = self.proc('/map_storage/proc/' + name, 'src' + (', ' + argument if argument else ''), True)
            setattr(self.store, name, MethodType(function, self.store))
        self.env['map_storage'] = self.store
        self.body.enter_saved_bed_sleep = MethodType(self.proc('/mob/living/human/proc/enter_saved_bed_sleep', 'src', True), self.body)

    def proc(self, declaration, args, method=False):
        # Native type paths and one-based lists are injected engine boundaries.
        source = re.sub(r'(istype\([^,\n]+, )(/[\w/]+)', r'\1"\2"', SOURCE)
        # DM gives an uninitialized local null; Python requires explicit binding.
        source = re.sub(r'^(\t+)var/(?:\w+/)*(\w+)\s*$', r'\1var/\2 = null', source, flags=re.M)
        fields = (*adapter.FIELDS, 'gc_destroyed', 'gcDestroyed', 'anchored', 'buckle_lying',
                  'buckled_mob', 'client', 'persistence_owner_ckey', 'x', 'y', 'z',
                  'record_persistence_owner', 'player_restoration_blocked', 'prepare_character_return',
                  'local_character_bodies', 'character_return_turf', 'character_recovery_unready',
                  'character_return_pending', 'reclaim_saved_player', 'find_restored_player',
                  'return_player_eligible', 'finish_character_return',
                  'dimension_recovery_required', 'dimension_budget_hold')
        with patch.object(adapter, 'FIELDS', fields):
            return adapter.project(source, declaration, args, self.env, method)

    def fresh_round_admission(self, can_start=True, startup_hold=False, round_restored=False):
        # Execute real setup admission through PLAYING. Later seeding/hooks are
        # outside this offline boundary; file writes remain an explicit adapter.
        source = adapter.read('code/game/gameticker.dm')
        declaration = '/datum/controller/gameticker/proc/setup'
        start = source.index(declaration + '(')
        end = source.index('\tstop_lobby_music()\n', start)
        source = source[start:end] + '\treturn TRUE\n'
        self.store.round_restored = round_restored
        self.env.update(persistence_restart=NS(startup_hold=startup_hold),
                        sleep=lambda ticks: None, GAME_STATE_PREGAME=1, GAME_STATE_PLAYING=3,
                        job_master=NS(ResetOccupations=lambda: None))
        self.env['map'].can_start = lambda: can_start
        self.env['map'].required_players = 0
        ticker = NS(current_state=1, admin_started=False)
        with patch.object(adapter, 'FIELDS', (*adapter.FIELDS, 'current_state', 'admin_started')):
            return adapter.project(source, declaration, 'src', self.env, True)(ticker)


class CharacterReturnTests(unittest.TestCase):
    def test_fresh_round_readiness_survives_ordinary_save_artifacts(self):
        for action in ('new_character', 'reconnect', 'bed_sleep'):
            with self.subTest(action=action):
                f = ReturnFixture()
                f.env['persistence_player_restore_ready'] = False
                f.registered.clear()
                f.body.persistence_restored = f.body.inducedSSD = False
                self.assertTrue(f.fresh_round_admission())
                # Same paths produced by an ordinary in-round save; no disk IO.
                f.artifacts.extend(('map_saves/map.txt', 'map_saves/save_complete.txt'))
                self.assertFalse(f.store.character_recovery_unready())
                self.assertTrue(f.env['persistence_player_restore_ready'])
                if action == 'new_character':
                    f.world.remove(f.body)
                    self.assertTrue(f.store.allow_new_character(f.lobby))
                elif action == 'reconnect':
                    self.assertTrue(f.store.reclaim_saved_player(f.lobby))
                    self.assertIs(f.client.mob, f.body)
                    self.assertIs(f.body.loc, f.home)
                else:
                    f.body.client, f.client.mob = f.client, f.body
                    f.body.loc, f.body.buckled = f.bed_turf, f.bed
                    f.bed.buckled_mob = f.body
                    f.bed_turf.append(f.bed)
                    self.assertTrue(f.body.enter_saved_bed_sleep())

    def test_fresh_admission_does_not_release_saved_or_failed_recovery(self):
        for hold in ('saved_artifacts', 'restart', 'restored_import', 'load_recovery', 'dimension', 'budget', 'error', 'not_started'):
            with self.subTest(hold=hold):
                f = ReturnFixture()
                f.env['persistence_player_restore_ready'] = False
                if hold == 'saved_artifacts': f.artifacts.append('map_saves/1.sav')
                if hold == 'load_recovery': f.env['persistence_load_recovery_required'] = True
                if hold == 'dimension': f.store.dimension_recovery_required = True
                if hold == 'budget': f.store.dimension_budget_hold = True
                if hold == 'error': f.blocked = True
                f.fresh_round_admission(can_start=hold != 'not_started', startup_hold=hold == 'restart',
                                        round_restored=hold == 'restored_import')
                self.assertFalse(f.env['persistence_player_restore_ready'])

    def test_live_readiness_cannot_bypass_save_or_error_holds(self):
        f = ReturnFixture()
        f.env['persistence_player_restore_ready'] = False
        self.assertTrue(f.fresh_round_admission())
        f.artifacts.append('map_saves/1.sav')
        f.env['persistence_active_operation'] = NS(current=lambda *args: False, restoring_players=False)
        self.assertTrue(f.store.character_recovery_unready())
        f.env['persistence_active_operation'] = None
        f.blocked = True  # Actual player_restoration_blocked error/hold boundary.
        self.assertTrue(f.store.character_recovery_unready())
        self.assertTrue(f.env['persistence_player_restore_ready'])
        f.blocked = False
        self.assertFalse(f.store.character_recovery_unready())

    def test_changed_var_export_selects_nondefault_nutrition_and_water(self):
        fields = adapter.extract(adapter.read('code/modules/persistence/functions.dm'), '/datum/proc/get_saved_vars')
        fields = re.sub(r'(?<!\w)/(?:mob|turf|obj|datum)(?:/[\w]+)*', lambda m: repr(m[0]), fields)
        fields = fields.replace('initial(src.vars[key])', 'initial_var(src, key)')
        defaults = {}
        source = adapter.read('code/game/mob/living/carbon/carbon_defines.dm')
        for key in ('nutrition', 'water'):
            defaults[key] = float(re.search(r'var/' + key + r' = ([\d.]+)', source)[1])
        human = NS(vars=dict(nutrition=83, water=29, name='saved person'), defaults=defaults)
        env = dict(list=DMList, params2list=lambda value: [], map_storage_saved_vars='',
                   istype=lambda value, kind: kind in ('/mob', '/datum'),
                   initial_var=lambda value, key: value.defaults.get(key),
                   persistence_runtime_var=lambda key: False)
        saved = adapter.project('/datum/proc/get_saved_vars()\n' + fields + '\n',
                                '/datum/proc/get_saved_vars', 'src', env)(human)
        self.assertIn('nutrition', saved)
        self.assertIn('water', saved)
        self.assertEqual((human.vars['nutrition'], human.vars['water']), (83, 29))

    def test_valid_bed_reclaims_same_body_inventory_and_medical_graph(self):
        f = ReturnFixture()
        items, organs = f.body.inventory, f.body.organs
        self.assertTrue(f.store.reclaim_saved_player(f.lobby))
        self.assertIs(f.client.mob, f.body)
        self.assertIs(f.body.loc, f.bed_turf)
        self.assertIs(f.body.inventory, items)
        self.assertIs(f.body.organs, organs)
        self.assertEqual((f.body.health, f.body.nutrition, f.body.water, f.body.stat), (23, 83, 29, 1))
        self.assertFalse(f.body.inducedSSD)
        self.assertFalse(f.claims)
        self.assertFalse(f.registered)

    def test_missing_or_ambiguous_bed_falls_back_to_saved_location(self):
        for case in ('missing', 'duplicate', 'occupied', 'carried', 'rolling', 'chair', 'destroyed', 'wrong_owner'):
            f = ReturnFixture()
            if case == 'missing': f.world.remove(f.bed)
            if case == 'duplicate': f.world.append(NS(kind='/obj/structure/bed', persistence_bed_owner_ckey='account'))
            if case == 'occupied': f.bed.buckled_mob = object()
            if case == 'carried': f.bed.loc = NS(kind='/obj/container')
            if case == 'rolling': f.bed.anchored = False
            if case == 'chair': f.bed.buckle_lying = False
            if case == 'destroyed': f.bed.gc_destroyed = True
            if case == 'wrong_owner': f.bed.persistence_bed_owner_ckey = 'other'
            with self.subTest(case=case):
                self.assertTrue(f.store.reclaim_saved_player(f.lobby))
                self.assertIs(f.body.loc, f.home)

    def test_legacy_protected_body_uses_valid_return_without_guessing(self):
        f = ReturnFixture()
        f.world.remove(f.bed)
        f.body.loc = f.zone
        f.body.lastx, f.body.lasty, f.body.lastz = (3, 2, 1)
        self.assertTrue(f.store.reclaim_saved_player(f.lobby))
        self.assertIs(f.body.loc, f.home)

    def test_unsafe_missing_return_holds_and_never_falls_through_to_fresh(self):
        f = ReturnFixture()
        f.world.remove(f.bed)
        f.body.loc = f.zone
        self.assertFalse(f.store.allow_new_character(f.lobby))
        self.assertIs(f.client.mob, f.lobby)
        self.assertIs(f.body.loc, f.zone)
        self.assertTrue(f.body.inducedSSD)
        self.assertIs(f.registered['account'][1], f.body)
        self.assertTrue(f.messages)

    def test_refused_move_preserves_claim_and_retry_succeeds(self):
        f = ReturnFixture()
        f.body.refuse_move = True
        self.assertFalse(f.store.allow_new_character(f.lobby))
        self.assertFalse(f.claims)
        self.assertFalse(f.lobby.spawning)
        f.body.refuse_move = False
        self.assertTrue(f.store.reclaim_saved_player(f.lobby))

    def test_reentrant_claim_and_new_character_creation_are_held(self):
        f = ReturnFixture()
        results = []
        f.body.move_hook = lambda: results.extend((f.store.reclaim_saved_player(f.lobby),
                                                  f.store.allow_new_character(f.lobby)))
        self.assertTrue(f.store.reclaim_saved_player(f.lobby))
        self.assertEqual(results, [False, False])
        self.assertIs(f.client.mob, f.body)

    def test_generated_omission_controls_expose_reservation_and_fresh_fallthrough(self):
        omitted = SOURCE.replace('persistence_player_claims[C.ckey] || character_recovery_unready()',
                                 'character_recovery_unready()')
        self.assertNotEqual(omitted, SOURCE)
        with patch.dict(globals(), SOURCE=omitted):
            f = ReturnFixture()
            f.claims['account'] = object()
            self.assertTrue(f.store.reclaim_saved_player(f.lobby))  # would violate the reservation oracle
        omitted = SOURCE.replace('if(character_return_pending(lobby.client.ckey))', 'if(FALSE)')
        self.assertNotEqual(omitted, SOURCE)
        with patch.dict(globals(), SOURCE=omitted):
            f = ReturnFixture()
            f.world.remove(f.bed)
            f.body.loc = f.zone
            self.assertTrue(f.store.allow_new_character(f.lobby))  # would violate the recovery oracle

    def test_move_callback_save_start_holds_without_waking_or_consuming_claim(self):
        f = ReturnFixture()
        f.body.move_hook = lambda: setattr(f, 'blocked', True)
        self.assertFalse(f.store.reclaim_saved_player(f.lobby))
        self.assertIs(f.client.mob, f.lobby)
        self.assertTrue(f.body.inducedSSD)
        self.assertTrue(f.registered['account'])
        self.assertTrue(f.body.inducedSSD)

    def test_move_callback_ban_keeps_lobby_and_claim_for_valid_retry(self):
        for kind in ('Playing', 'Server'):
            with self.subTest(kind=kind):
                f = ReturnFixture()
                banned = set()
                f.client.quickBan_isbanned = banned.__contains__
                f.body.move_hook = lambda: banned.add(kind)
                items, organs = f.body.inventory, f.body.organs
                self.assertFalse(f.store.reclaim_saved_player(f.lobby))
                self.assertIs(f.client.mob, f.lobby)
                self.assertIs(f.lobby.client, f.client)
                self.assertIs(f.registered['account'][1], f.body)
                self.assertFalse(f.claims)
                self.assertFalse(f.lobby.spawning)
                self.assertFalse(f.deleted)
                self.assertIsNone(f.body.key)
                self.assertTrue(f.body.inducedSSD)
                self.assertIs(f.body.inventory, items)
                self.assertIs(f.body.organs, organs)
                banned.clear()
                f.body.move_hook = None
                self.assertTrue(f.store.reclaim_saved_player(f.lobby))
                self.assertIs(f.client.mob, f.body)
                self.assertFalse(f.registered)
                self.assertFalse(f.claims)

    def test_changed_reservation_or_owner_after_callback_cannot_claim(self):
        for case in ('reservation', 'owner', 'retired'):
            f = ReturnFixture()
            def callback():
                if case == 'reservation': f.claims['account'] = object()
                if case == 'owner': f.body.persistence_owner_ckey = 'other'
                if case == 'retired': f.body.gc_destroyed = True
            f.body.move_hook = callback
            with self.subTest(case=case):
                self.assertFalse(f.store.reclaim_saved_player(f.lobby))
                self.assertIs(f.client.mob, f.lobby)
                self.assertTrue(f.body.inducedSSD)
                if case == 'reservation': self.assertIsNotNone(f.claims['account'])
        self.assertFalse(f.claims)

    def test_duplicate_owner_callback_defensively_holds_for_valid_retry(self):
        f = ReturnFixture()
        duplicate = Body(f, f.home)
        # Deliberately skip normal owner recording, which clears the old owner.
        f.body.move_hook = lambda: f.world.append(duplicate)
        items, organs = f.body.inventory, f.body.organs
        self.assertFalse(f.store.reclaim_saved_player(f.lobby))
        self.assertIs(f.client.mob, f.lobby)
        self.assertIs(f.lobby.client, f.client)
        self.assertIs(f.registered['account'][1], f.body)
        self.assertEqual(f.body.persistence_owner_ckey, 'account')
        self.assertFalse(f.claims)
        self.assertFalse(f.lobby.spawning)
        self.assertFalse(f.deleted)
        self.assertIsNone(f.body.key)
        self.assertTrue(f.body.inducedSSD)
        self.assertIs(f.body.inventory, items)
        self.assertIs(f.body.organs, organs)
        self.assertFalse(f.store.allow_new_character(f.lobby))
        f.world.remove(duplicate)
        f.body.move_hook = None
        self.assertTrue(f.store.reclaim_saved_player(f.lobby))
        self.assertIs(f.client.mob, f.body)
        self.assertFalse(f.registered)
        self.assertFalse(f.claims)

    def test_key_failure_cleans_only_owned_reservation(self):
        f = ReturnFixture()
        f.body.refuse_key = True
        with self.assertRaisesRegex(RuntimeError, 'did not receive'):
            f.store.reclaim_saved_player(f.lobby)
        self.assertFalse(f.claims)
        self.assertTrue(f.registered['account'])
        self.assertFalse(f.lobby.spawning)
        self.assertTrue(f.body.inducedSSD)
        f.body.refuse_key = False
        f.body.loc = f.home
        self.assertTrue(f.store.reclaim_saved_player(f.lobby))
        self.assertIs(f.body.loc, f.bed_turf, 'failed key handoff consumed pending bed return')
        self.assertTrue(f.body.persistence_restored)

    def test_corrupt_missing_and_in_progress_generation_never_create_fresh(self):
        for case in ('error', 'partial', 'complete_not_loaded', 'save', 'load_recovery', 'dimension_hold'):
            f = ReturnFixture()
            f.world.remove(f.body)
            f.registered.clear()
            f.env['persistence_player_restore_ready'] = False
            if case == 'error': f.blocked = True
            if case == 'partial': f.artifacts.append('map_saves/1.sav')
            if case == 'complete_not_loaded': f.artifacts.append('map_saves/save_complete.txt')
            if case == 'save': f.env['persistence_active_operation'] = NS(current=lambda *args: False, restoring_players=False)
            if case == 'load_recovery': f.env['persistence_load_recovery_required'] = True
            if case == 'dimension_hold': f.store.dimension_budget_hold = True
            with self.subTest(case=case):
                self.assertFalse(f.store.allow_new_character(f.lobby))

    def test_authoritative_operation_blocks_return_but_owned_final_import_admits(self):
        f = ReturnFixture()
        f.env['persistence_active_operation'] = NS(current=lambda *args: False, restoring_players=False)
        self.assertFalse(f.store.reclaim_saved_player(f.lobby))
        self.assertFalse(f.body.client)
        f.env['persistence_active_operation'] = NS(current=lambda *args: True, restoring_players=True)
        self.assertTrue(f.store.reclaim_saved_player(f.lobby))

    def test_dead_body_not_resurrected_and_tdm_policy_unchanged(self):
        f = ReturnFixture()
        f.body.stat = 2
        self.assertFalse(f.store.reclaim_saved_player(f.lobby))
        self.assertTrue(f.store.allow_new_character(f.lobby))
        self.assertEqual(f.body.stat, 2)
        f.enabled, f.blocked = False, True
        self.assertTrue(f.store.allow_new_character(f.lobby))

    def test_known_missing_occupied_and_duplicate_bodies_hold(self):
        for case in ('missing', 'occupied', 'duplicate', 'ambiguous_registry'):
            f = ReturnFixture()
            if case == 'missing': f.world.remove(f.body)
            if case == 'occupied': f.body.client = object()
            if case == 'duplicate': f.world.append(Body(f, f.home))
            if case == 'ambiguous_registry': f.registered['account'].append(None)
            with self.subTest(case=case):
                self.assertFalse(f.store.allow_new_character(f.lobby))

    def test_fresh_account_is_allowed_only_without_pending_owned_recovery(self):
        f = ReturnFixture()
        f.world.remove(f.body)
        f.registered.clear()
        self.assertTrue(f.store.allow_new_character(f.lobby))
        f.env['persistence_player_restore_ready'] = False
        self.assertTrue(f.store.allow_new_character(f.lobby))  # genuine first world

    def test_runtime_body_reconnect_does_not_teleport(self):
        f = ReturnFixture()
        f.registered.clear()
        f.body.persistence_restored = f.body.inducedSSD = False
        self.assertTrue(f.store.reclaim_saved_player(f.lobby))
        self.assertIs(f.body.loc, f.home)

    def test_imported_body_first_return_is_consumed_before_later_lobby_reclaim(self):
        f = ReturnFixture()
        self.assertTrue(f.store.reclaim_saved_player(f.lobby))
        self.assertIs(f.body.loc, f.bed_turf)
        self.assertTrue(f.body.persistence_restored)
        self.assertFalse(f.registered)
        # Explicit engine boundaries: walk away, disconnect, enter a new lobby.
        # Both returns below still execute the complete production reclaim flow.
        f.body.loc = f.home
        f.body.client, f.body._key = None, None
        second_lobby = NS(client=f.client, spawning=False, close_spawn_windows=lambda: None)
        f.client.mob = second_lobby
        self.assertTrue(f.store.reclaim_saved_player(second_lobby))
        self.assertIs(f.client.mob, f.body)
        self.assertIs(f.body.loc, f.home, 'consumed first return teleported to bed twice')
        self.assertTrue(f.body.persistence_restored, 'customization suppression marker was cleared')

    def test_pending_import_and_ordinary_induced_sleep_have_distinct_return_admission(self):
        for pending in (True, False):
            for sleeping in (True, False):
                f = ReturnFixture()
                f.body.inducedSSD = sleeping
                if not pending: f.registered.clear()
                with self.subTest(pending=pending, sleeping=sleeping):
                    self.assertTrue(f.store.reclaim_saved_player(f.lobby))
                    self.assertIs(f.body.loc, f.bed_turf if pending else f.home)
                    self.assertFalse(f.body.inducedSSD)
                    self.assertTrue(f.body.persistence_restored)

    def test_legacy_physical_zone_return_is_not_disabled_by_consumed_import_claim(self):
        f = ReturnFixture()
        f.registered.clear()
        f.body.loc = f.zone
        self.assertTrue(f.store.reclaim_saved_player(f.lobby))
        self.assertIs(f.body.loc, f.bed_turf)
        self.assertFalse(f.body.inducedSSD)

    def test_reclaim_leaves_delayed_customization_suppression_intact(self):
        nomads = adapter.extract(adapter.read('code/game/mob/living/carbon/human/nomads_spawn.dm'),
                                 '/mob/living/human/proc/nomads_spawn')
        self.assertRegex(nomads, r'if\(persistence_restored\)\n\s+return')
        reclaim = adapter.extract(SOURCE, '/map_storage/proc/reclaim_saved_player')
        self.assertNotIn('persistence_restored =', reclaim)
        self.assertLess(reclaim.index('if(C.mob != H)'), reclaim.index('persistence_restored_bodies.Remove(C.ckey)'))

    def test_saved_container_and_vehicle_relationships_hold_without_extraction(self):
        for case in ('container', 'riding', 'driver', 'driver_vehicle', 'riding_mob'):
            f = ReturnFixture()
            if case == 'container': f.body.loc = NS(kind='/obj/container', loc=f.home)
            else: setattr(f.body, case, object())
            origin, items = f.body.loc, f.body.inventory
            with self.subTest(case=case):
                self.assertFalse(f.store.allow_new_character(f.lobby))
                self.assertIs(f.client.mob, f.lobby)
                self.assertIs(f.body.loc, origin)
                self.assertIs(f.body.inventory, items)

    def test_bed_sleep_keeps_items_location_and_unique_scalar_assignment(self):
        f = ReturnFixture()
        f.body.loc = f.bed_turf
        f.body.inducedSSD = False
        f.body.client = f.client
        f.bed_turf.append(f.bed)
        old = NS(kind='/obj/structure/bed', persistence_bed_owner_ckey='account')
        f.world.append(old)
        inventory = f.body.inventory
        self.assertTrue(f.body.enter_saved_bed_sleep())
        self.assertIs(f.body.loc, f.bed_turf)
        self.assertIs(f.body.inventory, inventory)
        self.assertIsNone(old.persistence_bed_owner_ckey)
        self.assertTrue(f.body.inducedSSD)
        self.assertEqual(f.bed.persistence_bed_owner_ckey, 'account')

    def test_bed_sleep_refusal_does_not_claim_or_move(self):
        for case in ('save', 'guest', 'another_owner', 'dead'):
            f = ReturnFixture()
            f.body.loc, f.body.client, f.body.inducedSSD = f.bed_turf, f.client, False
            f.bed_turf.append(f.bed)
            if case == 'save': f.blocked = True
            if case == 'guest': f.client.key = 'Guest123'
            if case == 'another_owner': f.bed.persistence_bed_owner_ckey = 'other'
            if case == 'dead': f.body.stat = 2
            with self.subTest(case=case):
                self.assertFalse(f.body.enter_saved_bed_sleep())
                self.assertFalse(f.body.inducedSSD)
                self.assertIs(f.body.loc, f.bed_turf)

    def test_unsafe_turfs_rejected_without_arbitrary_spawn(self):
        f = ReturnFixture()
        safe = f.env['persistence_character_turf_safe']
        for kind in ('/turf/wall', '/turf/space', '/turf/floor/beach/water', '/turf/floor/lava'):
            self.assertFalse(safe(Turf(kind=kind), f.body))
        f.home.append(NS(kind='/obj/wall', density=True))
        self.assertFalse(safe(f.home, f.body))

    def test_admission_and_sleep_source_paths_are_wired_before_creation(self):
        join = adapter.read('code/game/mob/new_player/new_player.dm')
        for name in ('handle_lobby_join', 'AttemptLateSpawn', 'create_character'):
            body = adapter.extract(join, '/mob/new_player/proc/' + name)
            self.assertIn('map_storage.allow_new_character(src)', body)
            if 'new mobtype' in body:
                self.assertLess(body.index('allow_new_character'), body.index('new mobtype'))
        sleep = adapter.extract(adapter.read(HELPERS), '/mob/living/human/verb/mob_sleep')
        self.assertLess(sleep.index('enter_saved_bed_sleep()'), sleep.index('enter_protected_sleep()'))
        self.assertIn('Only a completed world save preserves it on disk', sleep)
        wake = adapter.extract(adapter.read(HELPERS), '/mob/living/human/verb/mob_wakeup')
        self.assertIn('persistence_bed_return_enabled() && !is_protected_sleep_location(src)', wake)
        self.assertLess(wake.index('persistence_sleep_transfer_blocked()', wake.index('spawn(300)')), wake.index('inducedSSD = FALSE'))
        self.assertIn('if (in_protected_sleep_zone())', adapter.read('code/game/mob/living/carbon/human/human_life.dm'))


if __name__ == '__main__':
    unittest.main()
