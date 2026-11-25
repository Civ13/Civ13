// Exercise the production completion step against changed load eligibility.
/proc/carriage_check_load_transactions(obj/structure/vehicle/carriage/C, mob/living/human/loader)
	// State changes during a timed load must not move refused cargo or passengers.
	var/mob/living/human/carriage_probe/passenger = carriage_person(C.x + 2, C.y + 1, "Waiting passenger")
	var/turf/passenger_origin = passenger.loc
	var/obj/structure/chair/chair = new(passenger_origin)
	chair.buckled_mob = passenger
	passenger.buckled = chair
	carriage_check(!C.complete_load(passenger, loader) && passenger.loc == passenger_origin && passenger.buckled == chair && chair.buckled_mob == passenger, "loading preserves a passenger's other seat")
	passenger.buckled = null
	passenger.anchored = TRUE
	carriage_check(!C.complete_load(passenger, loader) && passenger.loc == passenger_origin, "loading leaves an anchored passenger in place")
	chair.buckled_mob = null
	qdel(chair)
	qdel(passenger)
	var/list/extra_cargo = list()
	while (C.free_seat())
		var/obj/structure/closet/crate/extra = new(locate(C.x + 2, C.y, C.z))
		extra_cargo += extra
		C.take_seat(extra, C.free_seat())
	var/obj/structure/closet/crate/waiting = new(locate(C.x + 2, C.y, C.z))
	var/turf/cargo_origin = waiting.loc
	carriage_check(!C.complete_load(waiting, loader) && waiting.loc == cargo_origin && !(waiting in C.seats) && !waiting.anchored, "a full carriage leaves refused cargo at its origin")
	qdel(waiting)
	for (var/obj/structure/closet/crate/loaded in extra_cargo)
		C.let_off(loaded)
		qdel(loaded)
