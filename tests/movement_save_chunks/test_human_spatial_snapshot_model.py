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
    return {"origin": (p["x"], p["y"], p["z"]),
            "capsule": p if p["sx"] or p["sy"] else None}


def encode(frame, live):
    # Only the per-frame override is authoritative; never touch live position.
    result = {k: v for k, v in live.items()
              if k not in ("step_x", "step_y", "glide_size", "human_subtile_position")}
    if frame["capsule"] is not None:
        result["human_subtile_position"] = deepcopy(frame["capsule"])
    return result


def restore_accepts(frame, *, unlinked, clear):
    # Projection of the existing nonzero-capsule after_load boundary only.
    return frame["capsule"] is None or (unlinked and clear)


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
        elif not offset and not pulse:
            record['mode'] = 'legacy'
            record['origin'] = parent
        else:
            raise ValueError('legacy requires alignment and no pulse')
        return record['mode']

    def attach(self, identity, parent):
        record = self.records[identity]
        if record['mode'] == 'legacy' and parent != record['origin']:
            return record['parent']
        if record['parent'] is None:
            record['parent'] = parent
        return record['parent']


class SpatialSnapshotModelTests(unittest.TestCase):
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

    def test_late_walker_is_admitted_and_unsupported_partial_link_refuses(self):
        membership = RollingMembership()
        self.assertEqual(membership.encounter('late', direct=True, linked=False, offset=6), 'spatial')
        with self.assertRaisesRegex(ValueError, 'alignment'):
            membership.encounter('partial_in_crate', direct=False, linked=False, offset=6)

    def test_move_during_legacy_serialization_does_not_rewrite_frozen_anchor(self):
        a = actor()
        f = capture(a)
        a["position"].update(x=3, sx=6)
        fields = encode(f, {"step_x": 6, "step_y": 0, "glide_size": 4,
                            "human_subtile_position": {"stale": True}})
        self.assertEqual(f["origin"], (1, 2, 1))
        self.assertEqual(fields["human_subtile_position"]["sx"], 2)
        self.assertNotIn("step_x", fields)
        self.assertNotIn("glide_size", fields)

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

    def test_later_solid_or_buckle_can_make_offset_restore_fail(self):
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
        self.assertEqual(request.snapshot["capsule"]["sx"], 4)
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
                         "origin = start", "position = current", "captured = TRUE"):
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
        group = saving.split('/map_storage/proc/capture_human_save_roster_positions(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        self.assertIn('var/deadline = world.time + 100', group)
        self.assertIn('sleep(world.tick_lag)', group)
        frozen = group.split('if(ready) break', 1)[1].split('return TRUE', 1)[0]
        final_pass = frozen.split('for(var/identity in human_save_roots)', 1)[1]
        for forbidden in ('sleep(', 'save_work_check(', 'before_save(', '.Move('):
            self.assertNotIn(forbidden, final_pass)
        self.assertIn('request.acknowledge(H, T)', final_pass)
        self.assertIn('record["origin"] = request.origin', final_pass)
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
        self.assertIn("var/encoded_geometry_checked = FALSE", human)
        self.assertIn("request.encoded_geometry_checked = TRUE", saving)
        self.assertIn("var/human_containment_coverage_complete = FALSE", functions)
        seal = functions.split("\tproc/seal_human_containment_proof()", 1)[1].split("\n#endif", 1)[0]
        for check in ("encoded_origin_checked", "encoded_present_slots_checked", "reciprocal_links_checked",
                      "encoded_geometry_checked", "encoded_links_checked", "human_roster_changed",
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
        for required in ('if(!record)', 'if(record["mode"]) return record', 'record["mode"] = "legacy"',
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
        drain = saving.split('/map_storage/proc/drain_human_save_roster(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        self.assertIn('var/atom/parent = record["origin"]', drain)
        self.assertIn('save_entry_identity(parent) != record["origin_identity"]', drain)
        self.assertNotIn('var/atom/parent = H.loc', drain)

    def test_late_turf_geometry_is_sidecar_not_a_live_object_reference(self):
        saving = (self.root / 'code/modules/persistence/saving.dm').read_text()
        body = saving.split('/map_storage/proc/BuildVarDirectory(', 1)[1].split('\n/datum/', 1)[0]
        self.assertIn('savefile["/human_geometry/[geometry_shard]/[ref]/transforming"] << !!candidate_turf.vehicle_transforming', body)
        self.assertNotIn('changing_vars |= list("density", "vehicle_transforming")', body)
        self.assertIn('if(istype(A, /obj))', body)
        self.assertNotIn('human_object_operation.human_spatial_footprints.len', body)
        self.assertIn('human_geometry_added_fields', body)

    def test_late_saved_accounts_are_checked_across_levels_before_marker(self):
        saving = (self.root / 'code/modules/persistence/saving.dm').read_text()
        inspect = saving.split('/map_storage/proc/inspect_human_saved_owners(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        for required in ('var/list/owners = list()', 'operation.human_roster_records',
                         'F["/generation"] != generation', 'validate_saved_player_owner(F, record["ref"], owners)',
                         'world.time >= deadline'):
            self.assertIn(required, inspect)
        save = saving.split('/map_storage/proc/save_world_contents(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        self.assertLess(save.index('inspect_human_saved_owners(operation, generation)'), save.index('text2file(generation,"map_saves/save_complete.txt")'))

    def test_frame_override_freezes_capsule_without_rewriting_live_position(self):
        saving = (self.root / "code/modules/persistence/saving.dm").read_text()
        for required in ('changing_vars -= list("step_x", "step_y", "glide_size", "human_subtile_position")',
                         'changing_vars |= list("human_subtile_position", "human_subtile_restore_schema")',
                         'encode_saved_value(savefile, frame.human_spatial_position)',
                         'var/list/position = request.position.Copy()'):
            self.assertIn(required, saving)
        self.assertIn('if(human_request) throw EXCEPTION("Human spatial request reached an existing saved entry")', saving)
        human = (self.root / "code/game/mob/living/carbon/human/subtile_movement.dm").read_text()
        hook = human.split("/mob/living/human/before_save_context(", 1)[1].split("\n/mob/", 1)[0]
        self.assertIn(". = ..()", hook)
        self.assertIn("human_subtile_save_hook_frame = null", hook)
        self.assertNotIn("human_subtile_position =", hook)
        functions = (self.root / "code/modules/persistence/functions.dm").read_text()
        self.assertIn("frame.human_spatial_request.operation.current(src, \"save\")", functions)

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
        for field in ("request.serialized", "request.spatial_attached", "request.encoded_origin_checked", "request.encoded_present_slots_checked", "request.reciprocal_links_checked", "request.encoded_geometry_checked", "request.encoded_links_checked"):
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
        self.assertNotIn("encoded_geometry_checked = TRUE", body)

    def test_production_geometry_checks_encoded_footprint_without_constructors(self):
        saving = (self.root / "code/modules/persistence/saving.dm").read_text()
        body = saving.split("/map_storage/proc/validate_human_saved_geometry(", 1)[1].split("\n/map_storage/proc/", 1)[0]
        for required in ("human_candidate_position_matches", 'human_candidate_scalar_field(F, turf_ref, "density")',
                         'human_candidate_turf_transforming(F, turf_ref)',
                         'ispath(F["type"], /turf/floor)',
                         'human_spatial_generic_object(occupant["type"])',
                         'Human saved footprint has a hard or unaudited occupant'):
            self.assertIn(required, body)
        wrapper = saving.split("/map_storage/proc/inspect_human_saved_geometry(", 1)[1].split("\n/map_storage/proc/", 1)[0]
        self.assertIn('validate_human_saved_geometry(', wrapper)
        self.assertIn('request.encoded_geometry_checked = TRUE', wrapper)
        self.assertNotIn("new type(", body)
        self.assertNotIn(".CanPass(", body)
        index = saving.split('/map_storage/proc/build_human_obstruction_index(', 1)[1].split('\n/map_storage/proc/', 1)[0]
        for required in ('human_candidate_map_ref(F, z, y, x)', 'human_candidate_scalar_field(F, ref, key)',
                         '"bound_x", "bound_y", "bound_width", "bound_height", "step_x", "step_y"',
                         'Human obstruction index object has duplicate parents'):
            self.assertIn(required, index)
        self.assertIn('changing_vars |= list("density")', saving)
        self.assertIn('savefile["/human_geometry/[geometry_shard]/[ref]/transforming"] << !!candidate_turf.vehicle_transforming', saving)
        self.assertIn('changing_vars |= list("density", "bound_x", "bound_y", "bound_width", "bound_height", "step_x", "step_y")', saving)

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
