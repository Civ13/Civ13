"""Candidate spatial-only semantics: offline model, not a DM implementation."""
from copy import deepcopy
from pathlib import Path
import unittest


def capture(actor):
    if actor["pulse"]:
        raise ValueError("native pulse in flight")
    p = deepcopy(actor["position"])
    if actor["transaction_expected"] is not None and actor["transaction_expected"] != p:
        raise ValueError("transaction identity or position changed")
    return {"origin": (p["x"], p["y"], p["z"]), "capsule": None}


def encode(frame, live):
    # Only the per-frame override is authoritative; never touch live position.
    result = {k: v for k, v in live.items()
              if k not in ("step_x", "step_y", "glide_size", "human_subtile_position")}
    return result


def restore_accepts(frame, *, unlinked, clear):
    # Projection of the candidate's saved tile and supported link checks.
    return unlinked and clear


def actor(sx=2, sy=0):
    position = {"x": 1, "y": 2, "z": 1, "sx": sx, "sy": sy}
    return {"pulse": False, "position": position, "transaction_expected": deepcopy(position)}


class Handoff:
    """Bounded offline projection of request ownership and acknowledgement."""
    def __init__(self, actor, operation):
        self.actor = actor
        self.operation = operation
        self.snapshot = None

    def acknowledge(self, actor, operation):
        if self.snapshot is not None or actor is not self.actor or operation is not self.operation:
            return False
        try:
            snapshot = capture(actor)
        except ValueError:
            return False
        self.snapshot = snapshot
        return True


class RollingMembership:
    """Small contract model; it does not execute the production serializer."""
    def __init__(self, initial=()):
        self.records = {identity: {'mode': None, 'initial': True, 'parent': None} for identity in initial}

    def encounter(self, identity, *, direct, linked, offset, pulse=False, parent=None):
        record = self.records.setdefault(identity, {'mode': None, 'initial': False, 'parent': None})
        if record['mode']:
            return record['mode']
        if direct and not linked:
            record['mode'] = 'spatial'
        elif not pulse:
            record['mode'] = 'legacy'
            record['origin'] = parent
        else:
            raise ValueError('legacy requires no pulse')
        return record['mode']

    def attach(self, identity, parent):
        record = self.records[identity]
        if record['mode'] == 'legacy' and parent != record['origin']:
            return record['parent']
        if record['parent'] is None:
            record['parent'] = parent
        return record['parent']


class Location:
    """Offline ownership projection, not a model of BYOND atom execution."""
    def __init__(self, kind, *, loc=None, level=0, valid=True):
        self.kind, self.loc, self.level, self.valid = kind, loc, level, valid


def resolved_level(node):
    seen = set()
    for _ in range(64):
        if node is None or not node.valid or id(node) in seen:
            raise ValueError('invalid containment')
        seen.add(id(node))
        if node.kind == 'turf':
            if node.level < 1:
                raise ValueError('invalid turf')
            return node.level
        if node.kind != 'movable':
            raise ValueError('invalid containment')
        node = node.loc
    raise ValueError('invalid containment')


def bind_legacy(body, file_level):
    level = resolved_level(body)
    if level != file_level or body.loc is None:
        raise ValueError('wrong file level or parent')
    return {'parent': body.loc, 'level': level, 'owner': None}


def attach_legacy(record, parent, *, captured_parent, captured_level):
    if record['parent'] is not captured_parent or resolved_level(captured_parent) != record['level']:
        raise ValueError('stale parent')
    if parent is not captured_parent:
        return record['owner']
    if captured_level != record['level']:
        raise ValueError('wrong captured level')
    if record['owner'] is not None and record['owner'] is not parent:
        raise ValueError('duplicate owner')
    record['owner'] = parent
    return parent


class SpatialSnapshotModelTests(unittest.TestCase):
    def test_production_level_binding_and_parent_checks_are_source_bound(self):
        root = Path(__file__).resolve().parents[2]
        saving = (root / 'code/modules/persistence/saving.dm').read_text()
        functions = (root / 'code/modules/persistence/functions.dm').read_text()
        resolver = saving.split('/proc/human_save_containment_turf(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        for required in ('i <= 64', 'isDeleted(current)', 'seen[key]', 'isturf(current)',
                         'locate(T.x, T.y, T.z) != T', 'current = current.loc'):
            self.assertIn(required, resolver)
        classify = saving.split('/map_storage/proc/classify_human_save_entry(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        self.assertLess(classify.index('current_turf.z != saving_z'), classify.index('record["z"] = current_turf.z'))
        self.assertIn('record["origin"] = legacy_parent', classify)
        self.assertIn('save_entry_identity(legacy_parent)', classify)
        self.assertIn('if(record["z"] != saving_z)', classify)
        parent = saving.split('/map_storage/proc/human_save_parent_captured(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        for required in ('saving_references[save_entry_identity(parent)]', 'saving_reference_pins[parent_ref] != parent',
                         'saving_world_movables', 'captured["z"] != saved_z', 'captured["ref"] != parent_ref'):
            self.assertIn(required, parent)
        self.assertIn('human_save_parent_captured(legacy_parent, human_root["z"], frame.entry)', functions)
        self.assertIn('human_save_parent_captured(parent, record["z"], legacy_parent_ref)', saving)
        declared = saving.split('/map_storage/proc/level_link_target(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        self.assertIn('source.persistence_level_link_var(field)', declared)
        self.assertIn('var/turf/T = get_turf(value)', declared)
        self.assertIn('T.z != saving_z', declared)

    def test_nested_contained_body_binds_resolved_level_and_immediate_parent(self):
        floor = Location('turf', level=1)
        outer = Location('movable', loc=floor)
        inner = Location('movable', loc=outer)
        body = Location('movable', loc=inner)
        record = bind_legacy(body, 1)
        self.assertIs(record['parent'], inner)
        self.assertEqual(record['level'], 1)
        self.assertIs(attach_legacy(record, inner, captured_parent=inner, captured_level=1), inner)

    def test_cross_level_reference_missing_cycle_and_deleted_chain_refuse(self):
        floor = Location('turf', level=2)
        body = Location('movable', loc=Location('movable', loc=floor))
        with self.assertRaises(ValueError):
            bind_legacy(body, 1)
        with self.assertRaises(ValueError):
            bind_legacy(Location('movable'), 1)
        cycle = Location('movable')
        cycle.loc = cycle
        with self.assertRaises(ValueError):
            bind_legacy(Location('movable', loc=cycle), 1)
        deep = floor
        for _ in range(64):
            deep = Location('movable', loc=deep)
        with self.assertRaises(ValueError):
            bind_legacy(deep, 2)
        body.loc.valid = False
        with self.assertRaises(ValueError):
            bind_legacy(body, 2)

    def test_captured_parent_identity_and_level_survive_body_exit(self):
        floor = Location('turf', level=1)
        parent = Location('movable', loc=floor)
        body = Location('movable', loc=parent)
        record = bind_legacy(body, 1)
        body.loc = floor
        self.assertIsNone(attach_legacy(record, floor, captured_parent=parent, captured_level=1))
        self.assertIs(attach_legacy(record, parent, captured_parent=parent, captured_level=1), parent)
        with self.assertRaises(ValueError):
            attach_legacy(record, parent, captured_parent=Location('movable', loc=floor), captured_level=1)
        with self.assertRaises(ValueError):
            attach_legacy(record, parent, captured_parent=parent, captured_level=2)
        record['owner'] = Location('movable', loc=floor)
        with self.assertRaises(ValueError):
            attach_legacy(record, parent, captured_parent=parent, captured_level=1)
        record['owner'] = parent
        parent.loc = Location('turf', level=2)
        with self.assertRaises(ValueError):
            attach_legacy(record, parent, captured_parent=parent, captured_level=1)

    def test_seated_and_contained_legacy_keep_first_parent_and_mode(self):
        membership = RollingMembership(('seated', 'contained'))
        self.assertEqual(membership.encounter('seated', direct=True, linked=True, offset=0, parent='floor'), 'legacy')
        self.assertEqual(membership.encounter('contained', direct=False, linked=False, offset=0, parent='crate'), 'legacy')
        self.assertEqual(membership.attach('contained', 'crate'), 'crate')
        self.assertEqual(membership.attach('contained', 'floor'), 'crate')
        self.assertEqual(membership.encounter('seated', direct=True, linked=False, offset=0), 'legacy')

    def test_reference_first_exit_cannot_attach_to_new_live_parent(self):
        membership = RollingMembership(('body',))
        self.assertEqual(membership.encounter('body', direct=False, linked=True, offset=0, parent='crate'), 'legacy')
        self.assertIsNone(membership.attach('body', 'new_floor'))
        self.assertEqual(membership.attach('body', 'crate'), 'crate')

    def test_late_walker_and_contained_partial_keep_their_own_parent(self):
        membership = RollingMembership()
        self.assertEqual(membership.encounter('late', direct=True, linked=False, offset=6), 'spatial')
        self.assertEqual(membership.encounter('partial_in_crate', direct=False, linked=False, offset=6, parent='crate'), 'legacy')
        self.assertEqual(membership.attach('partial_in_crate', 'crate'), 'crate')
        with self.assertRaisesRegex(ValueError, 'pulse'):
            membership.encounter('active_in_crate', direct=False, linked=False, offset=6, pulse=True)

    def test_move_during_legacy_serialization_does_not_rewrite_frozen_anchor(self):
        a = actor()
        f = capture(a)
        a["position"].update(x=3, sx=6)
        fields = encode(f, {"step_x": 6, "step_y": 0, "glide_size": 4,
                            "pixel_x": 7, "human_subtile_position": {"stale": True}})
        self.assertEqual(f["origin"], (1, 2, 1))
        self.assertNotIn("human_subtile_position", fields)
        self.assertNotIn("step_x", fields)
        self.assertNotIn("glide_size", fields)
        self.assertEqual(fields["pixel_x"], 7)

    def test_aligned_snapshot_omits_stale_live_capsule(self):
        f = capture(actor(0, 0))
        fields = encode(f, {"human_subtile_position": {"stale": True}, "step_x": 12})
        self.assertNotIn("human_subtile_position", fields)
        self.assertNotIn("step_x", fields)

    def test_inflight_and_mismatched_transaction_refuse_without_cancelling(self):
        for mutation in (lambda a: a.update(pulse=True),
                         lambda a: a["position"].update(x=4)):
            a = actor()
            mutation(a)
            prior = deepcopy(a)
            with self.assertRaises(ValueError): capture(a)
            self.assertEqual(a, prior)

    def test_saved_tile_or_unlinked_state_can_refuse_candidate(self):
        f = capture(actor())
        self.assertTrue(restore_accepts(f, unlinked=True, clear=True))
        self.assertFalse(restore_accepts(f, unlinked=True, clear=False))
        self.assertFalse(restore_accepts(f, unlinked=False, clear=True))

    def test_handoff_waits_for_stable_boundary_without_stopping_actor(self):
        a = actor()
        op = object()
        request = Handoff(a, op)
        a["pulse"] = True
        self.assertFalse(request.acknowledge(a, op))
        a["position"]["sx"] = 4
        a["pulse"] = False
        self.assertFalse(request.acknowledge(a, op))
        a["transaction_expected"] = deepcopy(a["position"])
        self.assertFalse(request.acknowledge(a, object()))
        self.assertTrue(request.acknowledge(a, op))
        a["position"]["sx"] = 6
        self.assertEqual(request.snapshot["origin"], (1, 2, 1))
        self.assertIsNone(request.snapshot["capsule"])
        self.assertFalse(request.acknowledge(a, op))


class SourceConstraints(unittest.TestCase):
    root = Path(__file__).resolve().parents[2]

    def test_real_serializer_uses_live_fields_and_restore_checks_clearance(self):
        saving = (self.root / "code/modules/persistence/saving.dm").read_text()
        self.assertIn("var/list/changing_vars = A.get_saved_vars()", saving)
        self.assertIn("encode_saved_value(savefile, A.vars[v])", saving)
        self.assertIn("!moving_save_root_edge(content, parent)", saving)
        human = (self.root / "code/game/mob/living/carbon/human/subtile_movement.dm").read_text()
        self.assertIn("human_subtile_import_owned = (\"human_subtile_position\" in F.dir)", human)
        self.assertIn("!human_subtile_unlinked()", human)
        self.assertIn("!human_subtile_destination_clear(S)", human)

    def test_production_handoff_is_between_pulses_and_does_not_wait(self):
        human = (self.root / "code/game/mob/living/carbon/human/subtile_movement.dm").read_text()
        request = human.split("/datum/human_subtile_save_request\n", 1)[1].split("\n/mob/", 1)[0]
        acknowledge = request.split("\tproc/acknowledge(", 1)[1].split("\n\tproc/release()", 1)[0]
        for required in ("operation.current(operation.storage, \"save\")", "H.human_subtile_pulse",
                         "H.human_subtile_transaction != T", "human_subtile_same(T.expected, current)",
                         "origin = start", 'position = list("x" = start.x, "y" = start.y, "z" = start.z, "sx" = 0, "sy" = 0)', "captured = TRUE"):
            self.assertIn(required, acknowledge)
        for forbidden in ("sleep(", "finish(", "wait_paid_interval(", "cancelled =", "human_subtile_pulse ="):
            self.assertNotIn(forbidden, acknowledge)
        perform = human.split("/datum/human_subtile_transaction/proc/perform(", 1)[1].split("\n/datum/", 1)[0]
        self.assertLess(perform.index("actor.human_subtile_pulse = null"), perform.index("expected = after"))
        self.assertLess(perform.index("expected = after"), perform.index("human_subtile_save_request.acknowledge(actor, src)"))
        self.assertIn('"human_subtile_save_request"', human.split("/mob/living/human/persistence_runtime_var", 1)[1])

    def test_roster_is_experimental_and_movement_guard_is_unchanged(self):
        saving = (self.root / "code/modules/persistence/saving.dm").read_text()
        self.assertIn("#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL", saving)
        self.assertNotIn("#define CIV13_HUMAN_SPATIAL_EXPERIMENTAL", saving)
        human = (self.root / "code/game/mob/living/carbon/human/subtile_movement.dm").read_text()
        valid = human.split("/datum/human_subtile_transaction/proc/valid(", 1)[1].split("\n/datum/", 1)[0]
        self.assertIn("persistence_save_in_progress", valid)
        self.assertNotIn("human_save_roots", valid)

    def test_roster_handles_reference_first_and_frozen_origin(self):
        saving = (self.root / "code/modules/persistence/saving.dm").read_text()
        self.assertIn("!human_request && !moving_save_chunk && ishuman(A)", saving)
        self.assertIn("capture_human_save_root(savefile, human_root)", saving)
        self.assertIn('human_root["ref"] = ref', saving)
        capture = saving.split("/map_storage/proc/capture_human_save_root(", 1)[1].split("\n/map_storage/proc/", 1)[0]
        self.assertIn('var/datum/human_subtile_save_request/request = record["request"]', capture)
        self.assertIn('request.origin != record["origin"]', capture)
        self.assertIn("BuildVarDirectory(F, H, 1, FALSE, request)", capture)
        classify = saving.split('/map_storage/proc/classify_human_save_entry(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        self.assertIn('var/deadline = world.time + 100', classify)
        self.assertIn('sleep(world.tick_lag)', classify)
        self.assertIn('record["origin"] = request.origin', classify)
        self.assertNotIn('capture_human_save_roster_positions', saving)
        drain = saving.split("/map_storage/proc/drain_human_save_roster(", 1)[1].split("\n#endif", 1)[0]
        self.assertIn('human_candidate_map_ref(F, saving_z, position["y"], position["x"])', drain)
        self.assertIn("Human save root has conflicting spatial owners", drain)
        self.assertIn("request.spatial_attached = TRUE", drain)
        functions = (self.root / "code/modules/persistence/functions.dm").read_text()
        self.assertIn('frame.source != human_root["origin"]', functions)

    def test_candidate_proof_requires_encoded_checks_and_roster_seal(self):
        human = (self.root / "code/game/mob/living/carbon/human/subtile_movement.dm").read_text()
        saving = (self.root / "code/modules/persistence/saving.dm").read_text()
        functions = (self.root / "code/modules/persistence/functions.dm").read_text()
        self.assertIn("var/encoded_links_checked = FALSE", human)
        self.assertIn("request.encoded_links_checked = TRUE", saving)
        self.assertIn("!request.reciprocal_links_checked", saving)
        self.assertIn("var/encoded_anchor_checked = FALSE", human)
        self.assertIn("request.encoded_anchor_checked = TRUE", saving)
        self.assertIn("var/human_containment_coverage_complete = FALSE", functions)
        seal = functions.split("\tproc/seal_human_containment_proof()", 1)[1].split("\n#endif", 1)[0]
        for check in ("encoded_origin_checked", "encoded_present_slots_checked", "reciprocal_links_checked",
                      "encoded_anchor_checked", "encoded_links_checked", "human_roster_changed",
                      "matched != human_spatial_requests.len"):
            self.assertLess(seal.index(check), seal.index("human_containment_coverage_complete = TRUE"))

    def test_late_creation_login_or_retirement_does_not_blanket_invalidate(self):
        functions = (self.root / "code/modules/persistence/functions.dm").read_text()
        self.assertIn('if(human_roster_changed) throw EXCEPTION("Human roster changed during capture")', functions)
        saving = (self.root / "code/modules/persistence/saving.dm").read_text()
        roster = saving.split("/map_storage/proc/prepare_human_save_roster(", 1)[1].split("\n/map_storage/proc/", 1)[0]
        self.assertIn("operation.human_initial_roster", roster)
        admission = functions.split("/proc/begin_persistence_operation(", 1)[1].split("\n/datum/persistence_world_operation\n", 1)[0]
        self.assertLess(admission.index("operation.human_roster_sealed = TRUE"), admission.index("operation.human_initial_roster = humans.Copy()"))
        for name, procedure in (("human.dm", "/mob/living/human/New("),
                                ("human.dm", "/mob/living/human/Destroy()"),
                                ("update_icons.dm", "/mob/living/human/Login()")):
            source = (self.root / "code/game/mob/living/carbon/human" / name).read_text()
            body = source.split(procedure, 1)[1].split("\n/mob/", 1)[0]
            self.assertNotIn("persistence_note_human_roster_change()", body)

    def test_initial_and_late_humans_have_explicit_capture_modes(self):
        saving = (self.root / "code/modules/persistence/saving.dm").read_text()
        roster = saving.split("/map_storage/proc/prepare_human_save_roster(", 1)[1].split("\n/map_storage/proc/", 1)[0]
        for required in ("for(var/i = 1, i <= copy.len, i++)", '"saveable" = saveable',
                         "operation.human_roster_records = human_save_roots"):
            self.assertIn(required, roster)
        body = saving.split("/map_storage/proc/BuildVarDirectory(", 1)[1].split("\n/datum/", 1)[0]
        self.assertIn('classify_human_save_entry(A, persistence_active_operation)', body)
        self.assertIn('human_root["mode"] == "spatial"', body)
        classify = saving.split('/map_storage/proc/classify_human_save_entry(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        for required in ('if(!record)', 'if(record["mode"])', 'if(record["z"] != saving_z)', 'record["mode"] = "legacy"',
                         'record["mode"] = "spatial"', 'H.human_subtile_pulse || H.human_subtile_transaction'):
            self.assertIn(required, classify)
        functions = (self.root / "code/modules/persistence/functions.dm").read_text()
        self.assertIn("!human_containment_coverage_complete", functions)
        self.assertIn("proc/seal_human_containment_proof()", functions)
        self.assertIn('Legacy human candidate lacks a saved parent', functions)
        self.assertIn('Initial human was not represented in the candidate', functions)

    def test_legacy_frame_freezes_alignment_and_keeps_ordinary_parent_rules(self):
        saving = (self.root / 'code/modules/persistence/saving.dm').read_text()
        functions = (self.root / 'code/modules/persistence/functions.dm').read_text()
        self.assertIn('if(!human_request) frame.human_legacy_aligned = TRUE', saving)
        self.assertIn('changing_vars -= list("step_x", "step_y", "human_subtile_position", "human_subtile_restore_schema")', saving)
        edge = saving.split('/map_storage/proc/moving_save_root_edge(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        self.assertIn('human_root["mode"] == "spatial"', edge)
        attach = functions.split('/map_storage/proc/add_export_content(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        self.assertIn('human_root["mode"] == "spatial"', attach)
        self.assertIn('if(frame.source != legacy_parent) return', attach)
        self.assertIn('save_entry_identity(legacy_parent) != human_root["origin_identity"]', attach)
        self.assertIn('if(owner && owner != frame.entry)', attach)
        self.assertIn('human_root["parent_attached"] = TRUE', attach)
        self.assertIn('human_root["saved_parent_ref"] = frame.entry', attach)
        drain = saving.split('/map_storage/proc/drain_human_save_roster(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        self.assertIn('var/atom/parent = record["origin"]', drain)
        self.assertIn('save_entry_identity(parent) != record["origin_identity"]', drain)
        self.assertIn('record["saved_parent_ref"] = legacy_parent_ref', drain)
        self.assertNotIn('var/atom/parent = H.loc', drain)

    def test_saved_tile_density_remains_but_fractional_geometry_sidecar_is_removed(self):
        saving = (self.root / 'code/modules/persistence/saving.dm').read_text()
        body = saving.split('/map_storage/proc/BuildVarDirectory(', 1)[1].split('\n/datum/', 1)[0]
        self.assertIn('changing_vars |= list("density")', body)
        self.assertNotIn('/human_geometry/', body)
        self.assertNotIn('human_geometry_added_fields', body)
        self.assertNotIn('changing_vars |= list("density", "bound_x",', body)

    def test_late_saved_accounts_are_checked_across_levels_before_marker(self):
        saving = (self.root / 'code/modules/persistence/saving.dm').read_text()
        inspect = saving.split('/map_storage/proc/inspect_human_saved_owners(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        for required in ('var/list/owners = list()', 'operation.human_roster_records',
                         'F["/generation"] != generation', 'validate_saved_player_owner(F, record["ref"], owners)',
                         'world.time >= deadline'):
            self.assertIn(required, inspect)
        save = saving.split('/map_storage/proc/save_world_contents(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        self.assertLess(save.index('inspect_human_saved_owners(operation, generation)'), save.index('text2file(generation,"map_saves/save_complete.txt")'))

    def test_frame_omits_movement_offsets_without_rewriting_live_position(self):
        saving = (self.root / 'code/modules/persistence/saving.dm').read_text()
        self.assertIn('changing_vars -= list("step_x", "step_y", "glide_size", "human_subtile_position", "human_subtile_restore_schema")', saving)
        self.assertNotIn('encode_saved_value(savefile, frame.human_spatial_position)', saving)
        self.assertIn('var/list/position = request.position.Copy()', saving)
        self.assertIn('position["sx"] != 0 || position["sy"] != 0', saving)
        self.assertIn('if(human_request) throw EXCEPTION("Human spatial request reached an existing saved entry")', saving)
        human = (self.root / 'code/game/mob/living/carbon/human/subtile_movement.dm').read_text()
        hook = human.split('/mob/living/human/before_save_context(', 1)[1].split('\n/mob/', 1)[0]
        self.assertIn('. = ..()', hook)
        self.assertIn('human_subtile_save_hook_frame = null', hook)
        self.assertNotIn('human_subtile_position =', hook)
        self.assertIn('frame.human_legacy_aligned', hook)
        self.assertIn('record["mode"] != "legacy"', hook)
        functions = (self.root / 'code/modules/persistence/functions.dm').read_text()
        self.assertIn('frame.human_spatial_request.operation.current(src, "save")', functions)

    def test_operation_owns_and_releases_request_on_both_exit_paths(self):
        functions = (self.root / "code/modules/persistence/functions.dm").read_text()
        operation = functions.split("/datum/persistence_world_operation\n", 1)[1].split("\n/datum/persistence_world_operation/New()", 1)[0]
        self.assertIn('!current(storage, "save")', operation)
        self.assertIn("human_spatial_requests.len >= 8192", operation)
        self.assertIn("request.operation == src", operation)
        for name in ("withdraw", "finish"):
            body = operation.split("\tproc/" + name + "(", 1)[1].split("\n\tproc/", 1)[0]
            self.assertLess(body.index("release_human_spatial_requests()"), body.index("persistence_active_operation = null"))
        human = (self.root / "code/game/mob/living/carbon/human/subtile_movement.dm").read_text()
        create = human.split("/mob/living/human/proc/request_human_subtile_save_position(", 1)[1].split("\n/mob/", 1)[0]
        self.assertLess(create.index("track_human_spatial_request(request)"), create.index("request.acknowledge(src, null)"))

    def test_marker_gate_rejects_unproved_capsules_and_incomplete_edges(self):
        functions = (self.root / "code/modules/persistence/functions.dm").read_text()
        validator = functions.split("\tproc/validate_human_spatial_candidates()", 1)[1].split("\n\t\treturn TRUE\n#endif", 1)[0]
        for field in ("request.serialized", "request.spatial_attached", "request.encoded_origin_checked", "request.encoded_present_slots_checked", "request.reciprocal_links_checked", "request.encoded_anchor_checked", "request.encoded_links_checked"):
            self.assertIn(field, validator)
        self.assertNotIn("round(", validator)
        saving = (self.root / "code/modules/persistence/saving.dm").read_text()
        body = saving.split("/map_storage/proc/save_world_contents(", 1)[1].split("/map_storage/proc/BuildVarDirectory", 1)[0]
        self.assertLess(body.index("operation.validate_human_spatial_candidates()"), body.index('text2file(generation,"map_saves/save_complete.txt")'))

    def test_encoded_origin_inspection_is_not_collision_proof(self):
        saving = (self.root / "code/modules/persistence/saving.dm").read_text()
        inspect = saving.split("/map_storage/proc/inspect_human_saved_origins(", 1)[1].split("\n#endif", 1)[0]
        for required in ('!("format_version" in F.dir)', '!("[x]" in F.dir)',
                         '!("[parent_ref]" in F.dir)', '!("type" in F.dir)',
                         '!("content" in F.dir)', 'if(matches != 1)',
                         'ispath(F["type"], /mob/living/human)', 'request.encoded_origin_checked = TRUE'):
            self.assertIn(required, inspect)
        self.assertNotIn("encoded_links_checked = TRUE", inspect)
        self.assertNotIn("CanPass(", inspect)

    def test_present_slot_inspection_is_partial_and_never_asserts_link_proof(self):
        saving = (self.root / "code/modules/persistence/saving.dm").read_text()
        body = saving.split("/map_storage/proc/inspect_human_present_saved_slots(", 1)[1].split("\n#endif", 1)[0]
        for required in ('if(shards.len > 4096)', 'if(entries.len > 512)',
                         'var/deadline = world.time + 1200', 'raw_contents.len > 256', 'edge_count > 1000000',
                         'round((number - 1) / 512) != shard_number',
                         'if(parents[key])', 'if(!(key in fields)) throw EXCEPTION',
                         'value["kind"] != "entry"', 'request.encoded_present_slots_checked = TRUE'):
            self.assertIn(required, body)
        self.assertNotIn("encoded_links_checked = TRUE", body)
        self.assertNotIn("encoded_anchor_checked = TRUE", body)
        self.assertIn('Legacy human saved parent does not match captured parent', body)
        self.assertIn('human_record["slots_checked"] = TRUE', body)

    def test_candidate_checks_saved_tile_and_links_without_fractional_index(self):
        saving = (self.root / 'code/modules/persistence/saving.dm').read_text()
        body = saving.split('/map_storage/proc/inspect_human_saved_tile_and_links(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        for required in ('human_candidate_map_ref(F, z, position["y"], position["x"])',
                         'human_candidate_scalar_field(F, turf_ref, "density")',
                         'human_spatial_link_fields()', 'Human saved physical link is unsupported',
                         'request.encoded_anchor_checked = TRUE', 'request.encoded_links_checked = TRUE'):
            self.assertIn(required, body)
        self.assertNotIn('.CanPass(', body)
        self.assertNotIn('new type(', body)
        self.assertNotIn('/map_storage/proc/build_human_obstruction_index(', saving)
        self.assertNotIn('/human_geometry/', saving)

    def test_experimental_save_motion_keeps_recovery_holds_and_pull_fallback(self):
        human = (self.root / "code/game/mob/living/carbon/human/subtile_movement.dm").read_text()
        gate = human.split("/proc/human_subtile_save_motion_allowed()", 1)[1].split("\n/mob/", 1)[0]
        for required in ("#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL", 'operation.current(storage, "save")',
                         "!persistence_load_recovery_required", "!storage.dimension_recovery_required",
                         "!storage.dimension_budget_hold", "!persistence_restart.startup_hold", "!persistence_restart.busy", "operation.restart_transaction == persistence_restart",
                         "#else\n\treturn FALSE"):
            self.assertIn(required, gate)
        valid = human.split("/datum/human_subtile_transaction/proc/valid(direction)", 1)[1].split("\n/datum/", 1)[0]
        self.assertIn("persistence_save_in_progress && !human_subtile_save_motion_allowed()", valid)
        functions = (self.root / "code/modules/persistence/functions.dm").read_text()
        admission = functions.split("/proc/begin_persistence_operation(", 1)[1].split("\n/datum/persistence_world_operation\n", 1)[0]
        self.assertIn('if(kind == "save") operation.restart_transaction = transaction', admission)
        self.assertLess(admission.index("transaction != persistence_restart"), admission.index("operation.restart_transaction = transaction"))
        pull = (self.root / "code/game/mob/living/carbon/human/pull_pair_producer.dm").read_text()
        ready = pull.split("/mob/living/human/proc/human_subtile_pull_ready(direct)", 1)[1].split("\n/mob/", 1)[0]
        self.assertLess(ready.index("if (P)"), ready.index("#ifdef CIV13_HUMAN_SPATIAL_EXPERIMENTAL"))
        self.assertIn("if (persistence_save_in_progress && human_subtile_save_motion_allowed())\n\t\treturn FALSE", ready)
        move = human.split("/mob/living/human/SelfMove(", 1)[1].split("\n/mob/", 1)[0]
        self.assertLess(move.index("human_subtile_pull_ready(direct)"), move.index("human_subtile_travel("))
        ownership = (self.root / "code/game/mob/living/carbon/human/pull_pair_ownership.dm").read_text()
        claim = ownership.split("/datum/subtile_pull_ownership/proc/claim(", 1)[1].split("\n/proc/", 1)[0]
        prepare_at = claim.index("P.prepare(")
        publish_at = claim.index("owners[leader] = P")
        self.assertIn("if (persistence_save_in_progress)", claim[:prepare_at])
        self.assertIn("if (persistence_save_in_progress)", claim[prepare_at:publish_at])
        self.assertIn("owners[leader] || owners[follower]", claim)
        supported = human.split("/mob/living/human/proc/human_subtile_input_supported(", 1)[1].split("\n/mob/", 1)[0]
        self.assertLess(supported.index("subtile_pull_ownership.owners[src] || (pulling && subtile_pull_ownership.owners[pulling])"), supported.index("if (!step_x && !step_y)"))
        ready = human.split("/mob/living/human/proc/human_subtile_ready(", 1)[1].split("\n/mob/", 1)[0]
        self.assertIn("pulling && subtile_pull_ownership.owners[pulling]", ready)
        finish = human.split("/datum/human_subtile_transaction/proc/complete()", 1)[1].split("\n/datum/", 1)[0]
        self.assertIn("!completed", finish)
        self.assertEqual(finish.count("actor.living_movement_completed()"), 1)
        self.assertEqual(finish.count("actor.human_movement_completed()"), 1)


if __name__ == "__main__":
    unittest.main()
