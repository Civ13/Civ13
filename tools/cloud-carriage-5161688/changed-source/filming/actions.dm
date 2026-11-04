// REVIEW ONLY: no DME include, startup hook, observer bridge or runtime grant.
// Explicitly staged native actors; not ordinary-player acceptance.
// Crop: original x-48,y-138,z2 -> crop z1; all authored cells preserved.
#define INTRO_TRANSPORT_RELEASED TRUE

/datum/intro_transport_take
	var/busy = FALSE
	var/used = FALSE

/datum/intro_transport_take/proc/check(ok, label)
	if (!ok)
		throw EXCEPTION("Intro transport stopped: [label]")

/datum/intro_transport_take/proc/admit(mob/living/human/actor, atom/target)
	check(INTRO_TRANSPORT_RELEASED, "source remains held")
	check(actor && target && !actor.incapacitated() && !actor.buckled, "eligible actor")
	check(get_turf(actor) && get_turf(target) && actor.z == target.z && get_dist(actor, target) <= 1, "reachable target")
	check(!used && !busy, "one action per disposable take datum")
	used = TRUE
	busy = TRUE

// Source handlers own all waits, inventory changes and buckling. The caller
// must retain identities and inspect actual results; return values are not
// adequate for these handlers, which often return null after success.
/datum/intro_transport_take/proc/carriage_hitch(obj/structure/vehicle/carriage/C, mob/living/human/H, mob/living/simple_animal/horse/horse)
	admit(H, C)
	check(horse && get_dist(H, horse) <= 1 && horse.z == H.z && !horse.buckled, "reachable free horse")
	check(!C.moving && C.buckled_animal_propulsion == 0, "stationary empty hitch")
	C.MouseDrop_T(horse, H)
	check((horse in C.ontop) && C.buckled_animal_propulsion == 2, "normal horse hitch completed")
	busy = FALSE

/datum/intro_transport_take/proc/carriage_load(obj/structure/vehicle/carriage/C, mob/living/human/H, obj/structure/crate)
	admit(H, C)
	check(crate && !crate.anchored && crate.z == H.z && get_dist(H, crate) <= 1, "reachable movable cargo")
	check(!C.moving && C.current_cargo == 0 && !(crate in C.ontop_o), "empty stationary cargo position")
	C.MouseDrop_T(crate, H)
	check((crate in C.ontop_o) && crate.anchored && C.current_cargo == 1, "normal cargo load completed")
	busy = FALSE

/datum/intro_transport_take/proc/carriage_board(obj/structure/vehicle/carriage/C, mob/living/human/H)
	admit(H, C)
	check(!C.moving && !C.driver && !H.get_active_hand(), "free driver seat and hand")
	C.MouseDrop_T(H, H)
	check(C.driver == H && H.driver_vehicle == C && H.get_active_hand() == C.dwheel, "normal boarding completed")
	busy = FALSE

// One horse, lowest normal speed, original authored facing. No turns, direct
// vehicle moves, speed overrides or teleport corrections. Caller must catch
// ANY exception and stop its owned world; it must never continue the scene.
/datum/intro_transport_take/proc/carriage_straight(obj/structure/vehicle/carriage/C, mob/living/human/H, obj/structure/crate)
	check(INTRO_TRANSPORT_RELEASED && !used && !busy, "held single-use carriage take")
	used = TRUE
	busy = TRUE
	check(C && H && crate && C.x == 8 && C.y == 9 && C.z == 1 && C.dir == SOUTH, "exact authored departure")
	text2file(json_encode(list("phase" = "before_driver_guard", "carriage" = "\ref[C]", "driver" = "\ref[H]", "driver_bound" = C.driver == H, "vehicle_bound" = H.driver_vehicle == C, "driver_dir" = H.dir, "south_facing" = H.dir == SOUTH, "incapacitated" = H.incapacitated(), "stat" = H.stat, "sleeping" = H.sleeping, "paralysis" = H.paralysis, "ssd" = H.ssd_check(), "has_client" = !!H.client, "held_reins" = H.get_active_hand() == C.dwheel)), "intro-checks.txt")
	check(C.driver == H && H.driver_vehicle == C && H.dir == SOUTH && !H.incapacitated(), "native driver and facing")
	check(C.axis && !C.moving && C.axis.currentspeed == 0 && C.buckled_animal_propulsion == 2, "one horse at rest")
	var/obj/item/vehicleparts/wheel/rope/reins = H.get_active_hand()
	check(istype(reins) && reins == C.dwheel && (crate in C.ontop_o), "held reins and retained cargo")
	reins.attack_self(H)
	var/deadline = world.time + 80
	while (C.y > 7 && world.time < deadline)
		check(C.x == 8 && C.z == 1 && C.dir == SOUTH && C.driver == H && (crate in C.ontop_o), "straight carriage continuity")
		sleep(1)
	reins.secondary_attack_self(H)
	check(C.x == 8 && C.y == 7 && C.z == 1 && !C.moving && C.axis.currentspeed == 0, "normal stop at target")
	sleep(25)
	check(C.x == 8 && C.y == 7 && C.driver == H && (crate in C.ontop_o), "settled driver and cargo")
	busy = FALSE

