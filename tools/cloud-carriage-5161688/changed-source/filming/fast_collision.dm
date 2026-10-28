// Unpublished fixture only. Production reins, movementloop, do_move and collision
// methods remain inherited. No direct vehicle movement or speed-field writes.
var/mob/living/simple_animal/horse/intro_second_horse
var/obj/structure/intro_collision_target/intro_barrier
var/list/intro_fast_steps = list()
var/list/intro_fast_leases = list()
var/list/intro_fast_priors = list()
var/intro_fast_checks = 0
var/intro_collision_checks = 0

/obj/structure/intro_collision_target
	name = "fixture collision barrier"
	density = TRUE
	anchored = TRUE

/proc/intro_fast_check(ok, label)
	intro_check(ok, label)
	intro_fast_checks++
	text2file(json_encode(list("probe"="production_fast_collision_v1", "check"=label, "pass"=TRUE, "tick"=world.time)), "intro-checks.txt")

/proc/intro_fast_prepare()
	intro_fast_check(intro_carriage.x == 8 && intro_carriage.y == 9 && intro_carriage.buckled_animal_propulsion == 2, "original one-horse staging")
	intro_second_horse = new(get_turf(intro_carriage))
	intro_carriage.MouseDrop_T(intro_second_horse, intro_driver)
	intro_fast_check(intro_second_horse in intro_carriage.ontop && intro_carriage.buckled_animal_propulsion == 4, "normal second horse hitch")
	// A dense fixture object tests real collision predicates without modifying turf.
	intro_barrier = new(locate(8,2,1))
	for (var/atom/movable/A in list(intro_carriage,intro_driver,intro_horse,intro_second_horse,intro_crate))
		intro_fast_priors[A] = A.glide_size

/obj/structure/vehicle/carriage/fast_acceptance/do_move(m_dir, interval)
	intro_fast_check(src == intro_carriage && m_dir == SOUTH && x == 8 && y >= 4 && y <= 9, "bounded real south step")
	intro_fast_check(intro_fast_steps.len < 6, "six-step ceiling")
	var/expected_interval = intro_fast_steps.len ? 2.6 : 11
	intro_fast_check(abs(interval - expected_interval) < 0.00001, "normal gear delay captured")
	intro_fast_steps += list(list("tick"=world.time,"interval"=interval,"gear"=axis.currentspeed,"x"=x,"y"=y))
	. = ..()
	var/datum/carriage_glide_lease/L = carriage_glide
	intro_fast_check(L && L.members.len == 5, "all five native members owned")
	for (var/atom/movable/A in list(src,intro_driver,intro_horse,intro_second_horse,intro_crate))
		intro_fast_check(A.carriage_glide_owner == L && abs(A.glide_size - 32*world.tick_lag/interval) < 0.00001, "native fractional glide matches requested interval")
	intro_fast_leases += L
	if (intro_fast_steps.len == 1)
		var/obj/item/vehicleparts/wheel/rope/reins = intro_driver.get_active_hand()
		reins.attack_self(intro_driver)
		reins.attack_self(intro_driver)
		intro_fast_check(axis.currentspeed == 3 && abs(vehicle_m_delay - 1.6) < 0.00001, "normal reins select fast fractional gear")

/obj/structure/vehicle/carriage/fast_acceptance/do_vehicle_check()
	var/oldx=x
	var/oldy=y
	var/oldhealth=health
	var/oldgear=axis.currentspeed
	. = ..()
	if (!. && oldy == 3)
		intro_collision_checks++
		intro_fast_check(oldgear == 3 && x == oldx && y == oldy && !moving && axis.currentspeed == 0, "real collision blocks step and stops")
		intro_fast_check(health < oldhealth && !driver && !intro_driver.driver_vehicle && !(intro_driver in ontop), "real fast collision damage and ejection")
		intro_fast_check(!intro_driver.carriage_glide_owner, "ejected driver releases visual ownership")

/datum/intro_transport_take/proc/carriage_fast_collision(obj/structure/vehicle/carriage/C, mob/living/human/H, obj/structure/crate)
	check(INTRO_TRANSPORT_RELEASED && !used && !busy,"held single-use fast collision")
	used=TRUE
	busy=TRUE
	check(C == intro_carriage && H == intro_driver && C.driver == H && !C.moving && C.axis.currentspeed == 0,"normal staged driver")
	var/obj/item/vehicleparts/wheel/rope/reins=H.get_active_hand()
	reins.attack_self(H)
	var/deadline=world.time+45
	while (intro_collision_checks == 0 && world.time < deadline)
		sleep(0.5)
	intro_fast_check(intro_collision_checks == 1 && intro_fast_steps.len == 6 && C.x == 8 && C.y == 3,"bounded native route completes in collision")
	sleep(5)
	intro_fast_check(!C.movement_processes && !C.carriage_glide,"collision wake drained")
	for (var/datum/carriage_glide_lease/L in intro_fast_leases)
		intro_fast_check(intro_lease_empty(L),"retired fast lease absent from observers")
	for (var/atom/movable/A in list(C,H,intro_horse,intro_second_horse,crate))
		intro_fast_check(!A.carriage_glide_owner && !A.carriage_glide_step && A.glide_size == intro_fast_priors[A],"all prior glides restored after collision")
	text2file(json_encode(list("probe"="production_fast_collision_v1","source"="5260b60f0efef2c0af70fae204b1180106ef50b3","complete"=TRUE,"steps"=intro_fast_steps,"collision_count"=intro_collision_checks,"checks"=intro_fast_checks)),"intro-fast-result.json")
	busy=FALSE
