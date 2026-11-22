// Bailing out (aircraft_bailout.dm): only from an airborne aircraft, through
// her door or a jettisoned canopy, down to the ground below; a parachute
// lands softly and no parachute breaks legs; two sheets of glass refit the
// canopy on the ground.
/proc/aircraft_bailout_human(turf/T)
	if (!config)
		config = new
		config.webhook_can_fire = FALSE
	if (!all_species.len)
		makeDatumRefLists()
	if (!GLOB.stat_set_event)
		GLOB.stat_set_event = new
		GLOB.name_set_event = new
	var/mob/living/human/H = new(T)
	H.canmove = TRUE
	H.stat = CONSCIOUS
	return H

/proc/aircraft_bailout_checks()
	for (var/x = 11, x <= 20, x++)
		for (var/y = 1, y <= 60, y++)
			new /turf/sky/building(locate(x, y, 2))
	for (var/y = 1, y <= 55, y++)
		for (var/x = 17, x <= 19, x++)
			new /obj/covers/roads/modern/runway(locate(x, y, 1))
	var/obj/structure/vehicleparts/axis/aircraft/A = build_light_plane(locate(16, 50, 1))
	var/obj/structure/engine/internal/E = A.engine
	E.fueltank.reagents.add_reagent(E.fuels[1], 100, safety = TRUE)
	E.on = TRUE
	var/obj/structure/vehicleparts/frame/car/aircraft/cockpit = A.canopy_frame()
	var/obj/structure/vehicleparts/frame/door = A.door_frame()
	aircraft_check(istype(cockpit, /obj/structure/vehicleparts/frame/car/aircraft/cockpit) && door, "the light plane has a cockpit and a cabin door")
	aircraft_check(A.open_for_bailout(null) == "door" && door.doors_open() && !cockpit.canopy_gone, "with a door she opens it for whoever bails out")
	// Without it, she is a single-seater with only her canopy.
	door.w_right = list("c_wall", TRUE, TRUE, 0, 0.1, FALSE, FALSE)
	aircraft_check(!A.door_frame(), "walled up, she has no door")
	var/mob/living/human/pilot = aircraft_bailout_human(get_turf(cockpit))
	aircraft_check(findtext(cockpit.bailout_refusal(pilot), "on the ground"), "on the ground nobody bails out")
	aircraft_roll(A, A.takeoff_roll + 2)
	aircraft_check(A.airborne() && pilot.z == 2, "she takes off with her pilot")
	var/mob/living/human/stranger = aircraft_bailout_human(locate(1, 1, 1))
	aircraft_check(cockpit.bailout_refusal(stranger), "nobody bails out of an aircraft they are not aboard")
	// With a parachute: the canopy goes and the pilot drifts down.
	pilot.back = new /obj/item/weapon/storage/backpack/paratrooper(pilot)
	var/turf/landed = cockpit.bail_out(pilot, TRUE)
	aircraft_check(landed && pilot.loc == landed && landed.z == 1 && landed.x == cockpit.x && landed.y == cockpit.y, "the pilot comes down on the ground straight below")
	aircraft_check(cockpit.canopy_gone, "a plane with no door jettisons her canopy")
	aircraft_check(aircraft_bailout_landing(pilot, 10) == "parachute" && pilot.getBruteLoss() == 0, "a parachute lands softly")
	// Without one: legs break, worse from above the hills.
	var/mob/living/human/jumper = aircraft_bailout_human(locate(1, 2, 1))
	aircraft_check(aircraft_bailout_landing(jumper, 2) == "hard" && jumper.getBruteLoss() > 0, "a jump just off the ground is a hard landing")
	var/mob/living/human/faller = aircraft_bailout_human(locate(1, 3, 1))
	aircraft_check(aircraft_bailout_landing(faller, 10) == "fall" && faller.getBruteLoss() > jumper.getBruteLoss(), "a jump from altitude with no parachute is a bad fall")
	// The canopy is refitted on the ground only.
	var/obj/item/stack/material/glass/G = new(locate(1, 4, 1))
	G.amount = 1
	aircraft_check(cockpit.canopy_refit(G, stranger) && cockpit.canopy_gone, "one sheet of glass is not enough, and aloft it is refused")
	qdel(pilot)
	qdel(stranger)
	qdel(jumper)
	qdel(faller)
