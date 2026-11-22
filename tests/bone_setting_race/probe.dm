// Native probe: bone setting after a mid-operation heal (#6759).
// Run: python3 tests/ecology_spawning/run_linux.py . tests/bone_setting_race/probe.dm
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
/obj/map_metadata/bs_probe/New()
	return

var/bs_failures = 0
var/bs_runtime_error = FALSE
/proc/bs_check(condition, label)
	if (!condition)
		bs_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	bs_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"
/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		GLOB.name_set_event = new /decl/observ/name_set
		GLOB.stat_set_event = new /decl/observ/stat_set
		makeDatumRefLists()
		movementMachine = new
		map = new /obj/map_metadata/bs_probe
		bs_checks()
	catch(var/exception/e)
		bs_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = bs_failures, "runtime_error" = bs_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)


/proc/bs_patient(x)
	var/mob/living/human/H = new(locate(x, 3, 1))
	var/obj/item/organ/external/arm = H.get_organ("l_arm")
	arm.open = 2
	return H

/proc/bs_checks()
	var/datum/surgery_step/set_bone/step = new
	var/mob/living/human/surgeon = new(locate(2, 2, 1))
	var/obj/item/weapon/surgery/bonesetter/tool = new(surgeon)

	// The break heals while the bone is being set: it must stay whole.
	var/mob/living/human/healed = bs_patient(3)
	var/obj/item/organ/external/arm = healed.get_organ("l_arm")
	arm.fracture()
	bs_check(arm.status & ORGAN_BROKEN, "the arm starts broken")
	step.begin_step(surgeon, healed, "l_arm", tool)
	arm.status &= ~ORGAN_BROKEN // splint healing finishes during the wait
	step.end_step(surgeon, healed, "l_arm", tool)
	bs_check(!(arm.status & ORGAN_BROKEN), "a fracture that heals mid-operation is not broken again")
	bs_check(!arm.bone_set_on_fracture, "the operation marker is cleared")

	// A break still present at the end is set.
	var/mob/living/human/broken = bs_patient(4)
	var/obj/item/organ/external/arm2 = broken.get_organ("l_arm")
	arm2.fracture()
	step.begin_step(surgeon, broken, "l_arm", tool)
	step.end_step(surgeon, broken, "l_arm", tool)
	bs_check(!(arm2.status & ORGAN_BROKEN), "a broken bone is set")

	// Setting a bone that was whole from the start still breaks it.
	var/mob/living/human/whole = bs_patient(5)
	var/obj/item/organ/external/arm3 = whole.get_organ("l_arm")
	step.begin_step(surgeon, whole, "l_arm", tool)
	step.end_step(surgeon, whole, "l_arm", tool)
	bs_check(arm3.status & ORGAN_BROKEN, "setting a whole bone still breaks it")
