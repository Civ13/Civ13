// Native #7527 regression: actual application, both refund paths, and a
// disk-backed limb round trip. Run with tests/ecology_spawning/run_linux.py.
/world
	hub = ""
	hub_password = ""
	maxx = 12
	maxy = 12
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0

/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE

/obj/map_metadata/splint_probe/New()
	return

var/splint_probe_failures = 0
var/splint_probe_runtime_error = FALSE

/proc/splint_probe_check(condition, label)
	if (!condition)
		splint_probe_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"

/world/Error(exception/e)
	splint_probe_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
		makeDatumRefLists()
		movementMachine = new
		map = new /obj/map_metadata/splint_probe
		splint_probe_cases()
	catch (var/exception/e)
		splint_probe_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = splint_probe_failures, "runtime_error" = splint_probe_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/proc/splint_probe_refunds(turf/T, expected)
	var/list/refunds = list()
	for (var/obj/item/stack/medical/splint/S in T)
		refunds += S
	if (expected)
		var/obj/item/stack/medical/splint/S = refunds.len == 1 ? refunds[1] : null
		. = S && S.type == expected && S.amount == 1
	else
		. = !refunds.len
	for (var/obj/item/S in refunds)
		qdel(S)

/proc/splint_probe_cases()
	var/turf/bed_side = locate(3, 3, 1)
	var/mob/living/human/patient = new(bed_side)
	var/mob/living/human/healer = new(locate(3, 4, 1))
	var/obj/item/organ/external/arm = patient.get_organ("l_arm")
	var/obj/item/organ/external/head = patient.get_organ("head")
	healer.targeted_organ = "l_arm"
	var/obj/item/stack/medical/splint/wooden/stack = new(healer, 2)
	healer.r_hand = stack
	healer.hand = FALSE
	arm.status |= ORGAN_BROKEN
	stack.attack(patient, healer)
	splint_probe_check((arm.status & ORGAN_SPLINTED) && arm.splint_type == stack.type && stack.amount == 1, "actual treatment consumes exactly one wooden splint and records its type")
	patient.remove_splints(healer)
	splint_probe_check(!(arm.status & ORGAN_SPLINTED) && !arm.splint_type && splint_probe_refunds(bed_side, /obj/item/stack/medical/splint/wooden), "manual removal returns one wooden splint and clears attachment")
	patient.remove_splints(healer)
	splint_probe_check(splint_probe_refunds(bed_side, null), "repeated removal does not issue a second refund")

	stack.attack(patient, healer)
	splint_probe_check(QDELETED(stack) && arm.splint_type == /obj/item/stack/medical/splint/wooden, "the final unit is recorded even after its stack is deleted")
	arm.fracture_heal_ticks = FRACTURE_HEAL_TICKS - 1
	// Save the limb rather than the whole player graph, then attach the
	// reloaded limb to the fixture patient for the real healing handler.
	var/arm_type = arm.type
	var/obj/item/organ/external/saved_limb = new arm_type(bed_side)
	saved_limb.splint_type = arm.splint_type
	saved_limb.status = arm.status
	saved_limb.fracture_heal_ticks = arm.fracture_heal_ticks
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/savefile/F = new("splint-limb.sav")
	F["/format_version"] << 2
	var/entry = map_storage.BuildVarDirectory(F, saved_limb, 1)
	F.Flush()
	F = null
	map_storage.clear_bookkeeping()
	F = new("splint-limb.sav")
	var/obj/item/organ/external/reloaded = map_storage.Load_Entry(F, entry, starting_loc = bed_side)
	F = null
	map_storage.clear_bookkeeping()
	if (reloaded)
		reloaded.owner = patient
		reloaded.after_load()
	splint_probe_check(reloaded && reloaded != saved_limb && (reloaded.status & ORGAN_SPLINTED) && reloaded.splint_type == /obj/item/stack/medical/splint/wooden, "disk-backed limb reload preserves the attachment type")
	if (reloaded)
		reloaded.handle_fracture_healing()
		splint_probe_check(!(reloaded.status & (ORGAN_BROKEN | ORGAN_SPLINTED)) && !reloaded.splint_type && splint_probe_refunds(bed_side, /obj/item/stack/medical/splint/wooden), "healing the reloaded limb returns exactly one wooden splint")

	arm.splint_type = null
	patient.remove_splints(healer)
	splint_probe_check(splint_probe_refunds(bed_side, /obj/item/stack/medical/splint), "legacy manual removal retains the regular splint fallback")
	arm.status |= ORGAN_SPLINTED
	arm.fracture_heal_ticks = FRACTURE_HEAL_TICKS - 1
	arm.handle_fracture_healing()
	splint_probe_check(splint_probe_refunds(bed_side, /obj/item/stack/medical/splint/small), "legacy natural healing retains the small splint fallback")

	arm.status |= ORGAN_BROKEN | ORGAN_SPLINTED
	arm.splint_type = /obj/item/stack/medical/splint/wooden
	var/datum/surgery_step/set_bone/set_bone = new
	var/obj/item/weapon/surgery/bonesetter/tool = new(healer)
	set_bone.end_step(healer, patient, "l_arm", tool)
	splint_probe_check(!(arm.status & ORGAN_SPLINTED) && !arm.splint_type && splint_probe_refunds(bed_side, null), "bone setting clears attachment without producing a refund")

	head.status |= ORGAN_BROKEN | ORGAN_SPLINTED
	head.splint_type = /obj/item/stack/medical/splint/wooden
	var/datum/surgery_step/mend_skull/mend_skull = new
	mend_skull.end_step(healer, patient, "head", tool)
	splint_probe_check(!(head.status & ORGAN_SPLINTED) && !head.splint_type && splint_probe_refunds(bed_side, null), "skull surgery clears attachment without producing a refund")

	arm.status |= ORGAN_SPLINTED
	arm.splint_type = /obj/item/stack/medical/splint/wooden
	arm.rejuvenate()
	splint_probe_check(!(arm.status & ORGAN_SPLINTED) && !arm.splint_type && splint_probe_refunds(bed_side, null), "rejuvenation clears attachment without producing a refund")
