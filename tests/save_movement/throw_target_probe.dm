// Prospective native disk checks. Real serializer/loader and complete throw
// procedures are staged. Minimal type fields and rendering/impact effects are
// adapters, not full stack constructors, material gameplay or native acceptance.
var/list/thrown_list = list()
var/throw_reenter
var/atom/throw_next_target
var/throw_callback_saw_old_target = FALSE
/atom
	var/allow_spin = TRUE
/atom/proc/SpinAnimation(speed, loops)
	return
/proc/get_area(atom/A)
	var/turf/T = get_turf(A)
	return T ? T.loc : null
// Engine/type boundaries of this serializer-only adapter. No human flight is
// exercised here; full-source launch gameplay uses the human_subtile fixture.
/proc/isitem(atom/A)
	return istype(A, /obj/item)
/proc/ishuman(atom/A)
	return istype(A, /mob/living/human)
/proc/isDeleted(datum/A)
	return !A
/atom/movable
	var/tmp/mob/living/human/throw_launch_source
	var/tmp/throw_launch_dx
	var/tmp/throw_launch_dy
	var/tmp/throw_launch_x
	var/tmp/throw_launch_y
	var/throwing = FALSE
	var/thrower
	var/speed = 0
	var/range = 0
	var/turf/throw_source
	var/turf/last_throw_source
	var/atom/original_target
	var/dist_x = 0
	var/dist_y = 0
	var/dx
	var/dy
	var/dist_travelled = 0
	var/error = 0
	var/area/a
	var/throwmode = 0
/atom/movable/proc/throw_impact(atom/hit_atom, speed)
	if(throw_reenter == "impact")
		throw_callback_saw_old_target = original_target != null
		throw_reenter = null
		throw_at(throw_next_target, 5, 2, null)
/turf/cross_level/Entered(atom/movable/A)
	if(throw_reenter == "entered")
		throw_callback_saw_old_target = A.original_target != null
		throw_reenter = null
		A.throw_at(throw_next_target, 5, 2, null)
/obj/item/weapon/reagent_containers/food/drinks/bottle
/obj/item/stack/material/marble
	var/amount = 1
/obj/item/weapon/roofbuilder/glass
/obj/item/throw_relationship_fixture
	var/atom/relationship
	var/atom/alias

/proc/check_valid_relationship()
	var/obj/item/throw_relationship_fixture/H = new(locate(1,1,1))
	var/obj/item/weapon/roofbuilder/glass/R = new(locate(2,1,1))
	R.name = "durable relationship target"
	H.relationship = R
	H.alias = R
	var/savefile/F = new("valid-relationship.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, H, 1)
	var/target_ref = map_storage.saving_references["\ref[R]"]
	cross_check(target_ref && H.relationship == R && H.alias == R, "valid export changed relationship")
	F = null
	F = new("valid-relationship.sav")
	map_storage.clear_bookkeeping()
	var/obj/item/throw_relationship_fixture/restored = map_storage.Load_Entry(F, ref, starting_loc = locate(3,1,1))
	cross_check(restored && restored.relationship && restored.relationship == restored.alias, "valid relationship lost")
	var/obj/item/weapon/roofbuilder/glass/roof = map_storage.Load_Entry(F, target_ref, starting_loc = locate(2,2,1))
	cross_check(roof == restored.relationship && roof.name == R.name && roof.loc == locate(2,2,1), "valid target identity or location lost")

/proc/check_unknown_foreign_relationship()
	cross_capture_target = FALSE
	var/obj/item/throw_relationship_fixture/H = new(locate(1,1,1))
	var/obj/item/weapon/roofbuilder/glass/R = new(locate(2,1,2))
	H.relationship = R
	var/reason = cross_try_save()
	cross_assert_failed_save(reason, "Cross-level object reference cannot be represented", "unknown foreign relationship accepted")
	var/list/failure = map_storage.last_save_reference_failure
	cross_check(failure && failure["kind"] == "cross_level_object", "structured reference failure missing")
	var/list/source = failure["source"]
	var/list/target = failure["target"]
	cross_check(source["field"] == "relationship" && target["type"] == "[R.type]", "structured source/target diagnostic lost")
	cross_check(H.relationship == R && H.loc == locate(1,1,1) && R.loc == locate(2,1,2), "unknown relationship was cleared or target moved")

/proc/check_throw_roundtrip()
	var/obj/item/stack/material/marble/M = new(locate(1,1,1))
	M.amount = 731
	M.name = "retained marble"
	var/obj/item/weapon/roofbuilder/glass/R = new(locate(2,1,2))
	R.name = "independent roofbuilder"
	M.original_target = R
	var/savefile/F = new("throw-target.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, M, 1)
	var/path = map_storage.entry_path(F, ref)
	F.cd = path
	cross_check(!("original_target" in F.dir), "stale foreign target exported")
	cross_check(map_storage.saving_reference_pins.len == 1, "export followed stale target")
	cross_check(M.original_target == R && M.amount == 731 && M.loc == locate(1,1,1), "export mutated live stack")
	// A historical envelope would fail decoding if the runtime gate did not skip it.
	F["[path]/original_target"] << list("kind" = "entry", "ref" = 999999)
	F = null
	F = new("throw-target.sav")
	map_storage.clear_bookkeeping()
	var/obj/item/stack/material/marble/restored = map_storage.Load_Entry(F, ref, starting_loc = locate(2,1,1))
	cross_check(restored && !restored.original_target && restored.amount == 731, "historical target restored or amount lost")
	cross_check(restored.name == M.name && restored.loc == locate(2,1,1), "stack identity or location changed")
	var/savefile/G = new("independent-roof.sav")
	G["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 2
	var/roof_ref = map_storage.BuildVarDirectory(G, R, 1)
	cross_check(roof_ref && R.loc == locate(2,1,2), "independent roof export changed its location")
	G = null
	G = new("independent-roof.sav")
	map_storage.clear_bookkeeping()
	var/obj/item/weapon/roofbuilder/glass/roof = map_storage.Load_Entry(G, roof_ref, starting_loc = locate(3,2,2))
	cross_check(roof && roof.name == R.name && roof.loc == locate(3,2,2), "independent roof not preserved")
	var/savefile/L = new("legacy-throw.sav")
	L["/entries/1/type"] << /obj/item/stack/material/marble
	L["/entries/1/amount"] << 731
	L["/entries/1/original_target"] << "**invalid-runtime-value"
	map_storage.clear_bookkeeping()
	var/obj/item/stack/material/marble/legacy = map_storage.Load_Entry(L, 1, starting_loc = locate(3,1,1))
	cross_check(legacy && !legacy.original_target && legacy.amount == 731 && legacy.loc == locate(3,1,1), "flat legacy field restored")

/proc/check_active_throw_and_cleanup()
	var/obj/item/stack/material/marble/M = new(locate(1,2,1))
	M.amount = 731
	var/obj/item/weapon/roofbuilder/glass/old = new(locate(3,1,2))
	throw_next_target = new /obj/item/weapon/roofbuilder/glass(locate(2,1,2))
	M.throw_at(old, 5, 2, null)
	var/origin = M.loc
	var/savefile/F = new("active-throw.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, M, 1)
	F.cd = map_storage.entry_path(F, ref)
	cross_check(!("original_target" in F.dir), "active target exported")
	cross_check(M.original_target == old && M.throwing && (M in thrown_list), "export changed active throw")
	cross_check(M.loc == origin && M.amount == 731 && M.speed == 2 && M.range == 5, "active throw scalar state changed")
	M.finished_throwing()
	cross_check(!M.original_target && !(M in thrown_list), "completed target retained")
	for(var/phase in list("impact", "entered"))
		M.throw_at(old, 5, 2, null)
		throw_reenter = phase
		throw_callback_saw_old_target = FALSE
		M.finished_throwing()
		cross_check(!throw_callback_saw_old_target && M.original_target == throw_next_target, "newer callback target erased")
		cross_check(M.loc == origin && M.amount == 731, "cleanup changed stack or location")

/world/New()
	OpenPort("none")
	..()
	var/result = "PASS"
	try
		cross_check(!world.port, "fixture opened a port")
		OpenPort(0)
		cross_check(!world.port, "fixture allowed port reopening")
		map = new /obj/map_metadata(locate(3,2,1))
		map_storage = new /map_storage/cross_level("throw-target-fixture")
		check_throw_roundtrip()
		check_active_throw_and_cleanup()
		check_valid_relationship()
		check_unknown_foreign_relationship()
	catch(var/exception/probe_error)
		result = "FAIL: [probe_error.name]"
	text2file(json_encode(list("done" = TRUE, "result" = result, "checks" = cross_checks,
		"runtime_failed" = cross_runtime_failed, "port" = world.port)), "result.json")
	del(world)
