// The crane car (docs/trains.md#crane-car). A steam crane (power_cranes.dm)
// built onto a short ballasted flatcar, so the hoist goes wherever the track
// does.
//
// - It lifts only while it stands on a rail car whose outriggers are down
//   (the same lever and `braced` flag as the railway gun car), so a train
//   never moves with a load on the hook.
// - Like any steam crane it raises and lowers a load one level and burns a
//   haul of fuel a haul. Its jib also picks a load up anywhere within reach
//   on its own level and swings it onto another car or down beside the track.

/obj/structure/workshop_machine/shear_legs/crane/steam/rail
	name = "rail crane"
	desc = "A steam crane on a turntable, built for a crane car. Lower the car's outriggers, load coal, charcoal or wood, then drag an unfastened object within five tiles onto the crane: it swings the load onto another car, sets it down beside the track, or raises or lowers it one level through open air. Click it with an empty hand to haul up something lying below."
	icon = 'icons/obj/vehicles/train_loads.dmi'
	icon_state = "rail_crane"
	base_state = "rail_crane"
	pixel_x = -32
	pixel_y = -32
	layer = 3.3
	reach = 5
	fuel_limit = 40

/obj/structure/workshop_machine/shear_legs/crane/steam/rail/sling_reach()
	return reach

// The rail car a turf is part of the deck of, if any.
/proc/train_deck_at(turf/T)
	if (!T)
		return null
	for (var/obj/structure/trains/platform/P in range(1, T))
		if (T in train_platform_tiles(P.loc, P.dir))
			return P
	return null

// Why the crane cannot lift where it stands, or null when it can.
/obj/structure/workshop_machine/shear_legs/crane/steam/rail/proc/rail_problem()
	var/obj/structure/trains/platform/P = train_deck_at(get_turf(src))
	if (!P)
		return "\The [src] has to stand on a rail car to work."
	if (!P.braced)
		return "Lower the car's outriggers first, or the load would tip it off the rails."
	return null

/obj/structure/workshop_machine/shear_legs/crane/steam/rail/MouseDrop_T(atom/movable/dropping, mob/living/human/user)
	if (!istype(user) || !istype(dropping) || ismob(dropping) || user.incapacitated() || get_dist(src, user) > 1)
		return
	var/problem = rail_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))
		return
	return ..()

/obj/structure/workshop_machine/shear_legs/crane/steam/rail/attack_hand(mob/living/human/H)
	if (!istype(H))
		return
	var/problem = rail_problem()
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return
	return ..()

/obj/structure/workshop_machine/shear_legs/crane/steam/rail/hauler_ready(mob/living/human/H)
	return ..() && !rail_problem()

// On top of the steam crane's raise and lower: the nearest clear deck of
// another car, and the nearest clear ground off the track, both within reach
// (train_crane_swings(), train_goods.dm).
/obj/structure/workshop_machine/shear_legs/crane/steam/rail/haul_choices(atom/movable/load)
	var/list/choices = ..()
	var/obj/structure/trains/platform/mine = train_deck_at(get_turf(src))
	if (!mine)
		return choices
	return train_crane_swings(src, load, choices, mine.car_id)

/obj/structure/workshop_machine/shear_legs/crane/steam/rail/examine(mob/user, distance)
	..(user, distance)
	var/problem = rail_problem()
	if (problem)
		to_chat(user, SPAN_WARNING(problem))

/obj/structure/train_car_kit/crane_car
	name = "crane car kit"
	car_kind = "crane_car"
