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
/obj/map_metadata/digging_probe/New()
	return
/mob/living/human/digging_probe/New()
	return
/mob/living/human/digging_probe/getStatCoeff(statname)
	return 1
/mob/living/human/digging_probe/adaptStat(statname, multiplier = 1)
	return
var/digging_failures = 0
var/digging_runtime_error = FALSE
var/digging_waits = 0
var/digging_mode = "pass"
var/digging_nested = FALSE
var/turf/digging_target
var/mob/living/human/digging_probe/digging_other
var/obj/item/digging_tool
/proc/digging_check(condition, label)
	if (!condition)
		digging_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	digging_runtime_error = TRUE
	world.log << "runtime error: [e] [e.file]:[e.line]"
// Mirrors do_after's parameter names so named production arguments bind.
/proc/digging_probe_wait(mob/user, delay, atom/target = null, needhand = TRUE, progress = TRUE, incapacitation_flags = null, can_move = FALSE, check_for_repeats = TRUE, mining_context = null, gameplay_context = null)
	digging_waits++
	if (digging_mode == "cancel")
		return FALSE
	if (digging_mode == "compete" && !digging_nested)
		digging_nested = TRUE
		digging_target.attackby(digging_tool, digging_other)
	return TRUE
/proc/digging_output(turf/T, path)
	var/count = 0
	for (var/obj/item/I in T)
		if (istype(I, path))
			count += istype(I, /obj/item/stack) ? I:amount : 1
	return count
/proc/digging_tilling_checks()
	var/turf/floor/dirt/A = new /turf/floor/dirt(locate(8,8,1))
	var/turf/floor/dirt/B = new /turf/floor/dirt/flooded(locate(8,9,1))
	A.available_dirt = 0
	A.soil_nutrition = 35
	A.soil_recovery_schedule(200)
	var/a_deadline = A.soil_recovery_deadline
	B.available_dirt = 1
	B.soil_nutrition = 25
	B.soil_recovery_schedule(0)
	var/count = soil_recovery_pending.len
	var/turf/floor/dirt/ploughed/field = A.till_into_field(/turf/floor/dirt/ploughed)
	digging_check(istype(field) && field.available_dirt == 0 && field.soil_nutrition == 35 && field.soil_recovery_deadline == a_deadline, "normal tilling preserves depleted dirt, fertility, and its deadline")
	digging_check(soil_recovery_pending.len == count && soil_recovery_pending[field.soil_recovery_index] == field && soil_recovery_pending[B.soil_recovery_index] == B, "normal tilling preserves both registry memberships across swap-remove")
	var/turf/floor/dirt/ploughed/flooded/wet = B.till_into_field(/turf/floor/dirt/ploughed/flooded)
	digging_check(istype(wet) && wet.available_dirt == 1 && wet.soil_nutrition == 25 && wet.soil_recovery_deadline == world.time, "flooded tilling retains stocks and a recovery step already due")
	digging_check(soil_recovery_pending.len == count && soil_recovery_pending[field.soil_recovery_index] == field && soil_recovery_pending[wet.soil_recovery_index] == wet, "flooded tilling does not remove its neighbour or double register")
	var/turf/grass_tile = new /turf/floor/grass(locate(8,10,1))
	var/turf/floor/dirt/ploughed/from_grass = grass_tile.till_into_field(/turf/floor/dirt/ploughed)
	digging_check(istype(from_grass) && from_grass.available_dirt == initial(from_grass.available_dirt) && from_grass.soil_nutrition == initial(from_grass.soil_nutrition) && !from_grass.soil_recovery_index, "tilling grass still uses normal field defaults")

/world/New()
	OpenPort("none")
	try
		GLOB.moved_event = new /decl/observ/moved
		movementMachine = new
		map = new /obj/map_metadata/digging_probe
		map.ordinal_age = 2
		populate_material_list()
		digging_tilling_checks()
		var/mob/living/human/digging_probe/H = new(locate(4,5,1))
		digging_other = new(locate(6,5,1))
		H.a_intent = I_HELP
		digging_other.a_intent = I_HELP
		digging_tool = new /obj/item/weapon/material/shovel(H)
		for (var/path in list(/turf/floor/dirt, /turf/floor/beach/sand, /turf/floor/dirt/winter))
			var/turf/T = new path(locate(5,5,1))
			T.available_dirt = 1
			T.available_sand = 1
			T.available_snow = 2
			var/output = path == /turf/floor/dirt ? /obj/item/weapon/barrier : (path == /turf/floor/beach/sand ? /obj/item/stack/ore/glass : /obj/item/weapon/snowwall)
			digging_target = T
			digging_mode = "cancel"
			T.attackby(digging_tool, H)
			digging_check(digging_output(T,output) == 0 && !H.shoveling, "[path] cancellation consumes nothing and releases actor")
			digging_mode = "compete"
			digging_nested = FALSE
			if (path == /turf/floor/dirt/winter)
				T.available_snow = 1
			T.attackby(digging_tool, H)
			T = locate(5,5,1)
			digging_check(digging_output(T,output) == 1, "[path] two actors produce one finite output")
			digging_check(T.available_dirt >= 0 && T.available_sand >= 0 && T.available_snow >= 0 && !H.shoveling && !digging_other.shoveling, "[path] no negative stock or busy actor")
			for (var/obj/item/I in T)
				qdel(I)
		var/turf/floor/dirt/underground/U = new(locate(5,5,1))
		digging_target = U
		digging_tool = new /obj/item/weapon/material/pickaxe(H)
		// Pickaxe mining now requires the pickaxe in a hand slot, not just carried.
		H.r_hand = digging_tool
		H.hand = FALSE
		digging_mode = "cancel"
		digging_waits = 0
		U.attackby(digging_tool,H)
		digging_check(digging_waits == 1 && !U.mining_in_progress && locate(5,5,1) == U, "cancelled mining waits once and releases lock")
		digging_mode = "pass"
		digging_waits = 0
		U.attackby(digging_tool,H)
		digging_check(digging_waits == 1 && !istype(locate(5,5,1),/turf/floor/dirt/underground), "successful mining waits once and converts finite turf")
	catch(var/exception/e)
		digging_check(FALSE,"exception [e]")
	text2file(json_encode(list("commit"=world.params["tested_commit"],"failures"=digging_failures,"runtime_error"=digging_runtime_error,"byond_version"=world.byond_version,"byond_build"=world.byond_build)),"result.json")
	del(world)
