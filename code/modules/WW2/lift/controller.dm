
/obj/lift_controller
	name = "Lift Controller"
	var/jump_name = "Lift Controller"
	var/list/pseudoturfs = list()
	var/search_range = 7
	var/lift_id = null
	var/area_id = "defaultareaid"
	var/area/corresponding_area = null
	var/obj/lift_controller/target = null
	var/istop = TRUE
	var/status = STATUS_LIFT_DOCKED
	var/next_activation = -1
	icon = 'icons/mob/screen1.dmi'
	icon_state = "x2"
	var/islc = FALSE

/obj/lift_controller/New()
	..()
	icon = null
	icon_state = ""
	#ifndef LIFT_DEBUG
	name = ""
	#endif
	lift_list += src

/obj/lift_controller/Destroy()
	lift_list -= src
	..()


// subtypes: to avoid confusion, never use the base /obj/lift_controller

/obj/lift_controller/up
	istop = FALSE
	status = STATUS_LIFT_AWAY

// this one starts docked and is the one connected to the lever
/obj/lift_controller/down
	istop = TRUE
	status = STATUS_LIFT_DOCKED

/obj/lift_controller/down/proc/activate()

	if (world.time < next_activation)
		if (islc)
			visible_message("<span class = 'danger'>The landing craft is not ready to move yet.</span>")
		return
	if (!islc)
		next_activation = world.time + 50
	else
		next_activation = world.time + 400 //to give it time to reach the destination

	#ifdef LIFT_DEBUG
	world << "playing lift sound at [get_turf(src)]"
	#endif
	if (!islc)
		for (var/mob/m in range(12, src))
			m.playsound_local(get_turf(m), 'sound/misc/lift.ogg', 100 - get_dist(m, src))
		for (var/mob/m in range(12, target))
			m.playsound_local(get_turf(m), 'sound/misc/lift.ogg', 100 - get_dist(m, target))
	else
		for (var/mob/m in range(12, src))
			m.playsound_local(get_turf(m), 'sound/landing_craft.ogg', 100 - get_dist(m, src))
/*
	playsound(get_turf(src), 'sound/misc/lift.ogg', 100)
	playsound(get_turf(src), 'sound/misc/lift.ogg', 100)
*/
	#ifdef LIFT_DEBUG
	world << "played lift sound at [get_turf(src)]"
	#endif

	if (!islc)
		spawn (25) // give them time to get on
			switch (status)
				if (STATUS_LIFT_DOCKED) // going down
					for (var/turf/lift1_turf in get_area(src))
						var/turf/lift2_turf = GetBelow(lift1_turf, src)
						#ifdef LIFT_DEBUG
						world << "LIFT GOING DOWN:"
						world << "lift1_turf.loc: [lift1_turf.x], [lift1_turf.y]"
						world << "lift2_turf.loc: [lift2_turf.x], [lift2_turf.y]"
						#endif
						for (var/obj/lift_pseudoturf/lpt in lift1_turf)
							pseudoturfs -= lpt
							lpt._Move(lift2_turf)
							target.pseudoturfs += lpt

					status = STATUS_LIFT_AWAY
				if (STATUS_LIFT_AWAY)
					for (var/turf/lift1_turf in get_area(target))
						var/turf/lift2_turf = GetAbove(lift1_turf, target)
						#ifdef LIFT_DEBUG
						world << "LIFT GOING UP:"
						world << "lift1_turf.loc: [lift1_turf.x], [lift1_turf.y]"
						world << "lift2_turf.loc: [lift2_turf.x], [lift2_turf.y]"
						#endif
						for (var/obj/lift_pseudoturf/lpt in lift1_turf)
							target.pseudoturfs -= lpt
							lpt._Move(lift2_turf)
							pseudoturfs += lpt
					status = STATUS_LIFT_DOCKED
	else
		if (STATUS_LIFT_DOCKED) // going down
			visible_message("<span class = 'danger'>The landing craft is launching!</span>")
		if (STATUS_LIFT_AWAY)
			visible_message("<span class = 'danger'>The landing craft is returning to the ship!</span>")
		spawn (100)
			switch (status)
				if (STATUS_LIFT_DOCKED) // going down
					visible_message("<span class = 'danger'>The landing craft has arrived.</span>")
					for (var/turf/lift1_turf in get_area(src))
						var/turf/lift2_turf = GetBelow(lift1_turf, src)
						#ifdef LIFT_DEBUG
						world << "LIFT GOING DOWN:"
						world << "lift1_turf.loc: [lift1_turf.x], [lift1_turf.y]"
						world << "lift2_turf.loc: [lift2_turf.x], [lift2_turf.y]"
						#endif
						for (var/obj/lift_pseudoturf/lpt in lift1_turf)
							pseudoturfs -= lpt
							lpt._Move(lift2_turf)
							target.pseudoturfs += lpt
					status = STATUS_LIFT_AWAY

				if (STATUS_LIFT_AWAY)
					visible_message("<span class = 'danger'>The landing craft has arrived.</span>")
					for (var/turf/lift1_turf in get_area(target))
						var/turf/lift2_turf = GetAbove(lift1_turf, target)
						#ifdef LIFT_DEBUG
						world << "LIFT GOING UP:"
						world << "lift1_turf.loc: [lift1_turf.x], [lift1_turf.y]"
						world << "lift2_turf.loc: [lift2_turf.x], [lift2_turf.y]"
						#endif
						for (var/obj/lift_pseudoturf/lpt in lift1_turf)
							target.pseudoturfs -= lpt
							lpt._Move(lift2_turf)
							pseudoturfs += lpt
					status = STATUS_LIFT_DOCKED

// more subtypes

/obj/lift_controller/up/soviet
	area_id = "sovietliftcontrol"
	jump_name = "Soviet Lift (Up)"

/obj/lift_controller/down/soviet
	area_id = "sovietliftcontrol"
	jump_name = "Soviet Lift (Down)"


/obj/lift_controller/up/soviet/lc
	area_id = "sovietliftcontrol"
	jump_name = "Soviet Lift (Up)"
	islc = TRUE

/obj/lift_controller/down/soviet/lc
	area_id = "sovietliftcontrol"
	jump_name = "Soviet Lift (Down)"
	islc = TRUE