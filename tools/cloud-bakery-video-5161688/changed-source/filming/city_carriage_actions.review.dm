// Additional fixture objects are staged before the first recorded frame.
var/mob/living/human/intro_actor/intro_stablehand
var/mob/living/simple_animal/horse/intro_horse
var/obj/structure/vehicle/carriage/intro_carriage
var/obj/structure/simple_door/key_door/anyone/wood/intro_door

/proc/intro_prepare_carriage()
	// Spawn a standard carriage and horse on the authored street; neither is
	// represented as having traveled here. Hitch via the normal timed handler.
	intro_carriage = new(locate(74, 54, 1))
	intro_carriage.set_dir(EAST)
	intro_carriage.initialize()
	intro_stablehand = bakery_actor(73, 54, "Stablehand", /obj/item/clothing/under/civ1)
	intro_horse = new(locate(73, 55, 1))
	intro_check(intro_carriage && intro_horse && !intro_stablehand.client && !intro_stablehand.incapacitated(), "staged carriage, horse and capable handler")
	intro_check(intro_carriage.Adjacent(intro_stablehand) && get_dist(intro_stablehand, intro_horse) <= 1 && !intro_horse.buckled, "normal hitch reach")
	intro_carriage.MouseDrop_T(intro_horse, intro_stablehand)
	intro_check((intro_horse in intro_carriage.ontop) && intro_carriage.buckled_animal_propulsion == 2, "normal horse hitch completed")
	intro_check(step(intro_stablehand, WEST) && intro_stablehand.x == 72 && intro_stablehand.y == 54, "stablehand clears approach")
	sleep(2)
	for (var/ty in 55 to 57)
		intro_check(step(intro_stablehand, NORTH) && intro_stablehand.x == 72 && intro_stablehand.y == ty, "stablehand clears street")
		sleep(2)
	// Door was opened normally by the connected guest during preflight setup.
	intro_door = locate(/obj/structure/simple_door/key_door/anyone/wood) in locate(74, 58, 1)
	intro_check(intro_door && intro_door.state && !intro_door.density, "authored door remains open")
	intro_check(intro_carriage.x == 74 && intro_carriage.y == 54 && intro_carriage.dir == EAST && !intro_carriage.moving && !intro_carriage.driver, "staged eastbound carriage ready")

/proc/intro_customer_step(mob/living/human/H, obj/item/bread, direction, expected_x, expected_y, list/route)
	intro_check(H.get_active_hand() == bread && bread.loc == H && !H.incapacitated() && !H.buckled, "same bread held before walking step")
	intro_check(step(H, direction) && H.x == expected_x && H.y == expected_y && H.z == 1, "normal walking step reaches expected tile")
	intro_check(H.get_active_hand() == bread && bread.loc == H, "same bread held after walking step")
	route += list(list("x" = H.x, "y" = H.y, "time" = world.time, "bread" = "\ref[bread]"))
	sleep(4)

/proc/intro_customer_depart(mob/living/human/H, obj/item/bread)
	var/start_time = world.time
	var/bread_ref = "\ref[bread]"
	var/customer_ref = "\ref[H]"
	var/driver_health = H.health
	var/horse_health = intro_horse.health
	var/carriage_health = intro_carriage.health
	var/list/route = list()
	sleep(5)
	intro_customer_step(H, bread, EAST, 74, 59, route)
	intro_check(intro_door.state && !intro_door.density, "authored doorway remains open")
	intro_customer_step(H, bread, SOUTH, 74, 58, route)
	intro_customer_step(H, bread, SOUTH, 74, 57, route)
	intro_customer_step(H, bread, WEST, 73, 57, route)
	intro_customer_step(H, bread, SOUTH, 73, 56, route)
	intro_customer_step(H, bread, SOUTH, 73, 55, route)
	intro_customer_step(H, bread, SOUTH, 73, 54, route)
	intro_check(intro_carriage.Adjacent(H) && !intro_carriage.moving && !intro_carriage.driver, "customer reaches stationary carriage")
	H.swap_hand()
	intro_check(!H.get_active_hand() && H.get_inactive_hand() == bread && bread.loc == H, "bread retained in inactive hand for reins")
	var/boarding_started = world.time
	intro_carriage.MouseDrop_T(H, H)
	intro_check(intro_carriage.driver == H && H.driver_vehicle == intro_carriage && H.get_active_hand() == intro_carriage.dwheel && H.get_inactive_hand() == bread && bread.loc == H, "normal driver boarding retained bread")
	var/boarded_at = world.time
	sleep(10)
	var/obj/item/vehicleparts/wheel/rope/reins = H.get_active_hand()
	intro_check(istype(reins) && reins == intro_carriage.dwheel && (intro_horse in intro_carriage.ontop) && intro_carriage.buckled_animal_propulsion == 2, "normal reins and hitched horse")
	reins.attack_self(H)
	var/driving_started = world.time
	var/deadline = world.time + 80
	while (intro_carriage.x < 76 && world.time < deadline)
		intro_check(intro_carriage.y == 54 && intro_carriage.z == 1 && intro_carriage.dir == EAST && intro_carriage.driver == H && (intro_horse in intro_carriage.ontop) && H.get_inactive_hand() == bread && bread.loc == H, "native carriage and bread continuity")
		sleep(1)
	intro_check(intro_carriage.x == 76 && intro_carriage.y == 54 && intro_carriage.z == 1, "two-tile native carriage arrival")
	var/arrived_at = world.time
	reins.secondary_attack_self(H)
	intro_check(!intro_carriage.moving && intro_carriage.axis.currentspeed == 0, "normal reins stop")
	var/stopped_at = world.time
	sleep(15)
	intro_check(intro_carriage.x == 76 && intro_carriage.y == 54 && !intro_carriage.moving && intro_carriage.driver == H && H.get_inactive_hand() == bread && bread.loc == H, "settled driver retains original bread")
	intro_check(H.health == driver_health && intro_horse.health == horse_health && intro_carriage.health == carriage_health, "no collision injury during short drive")
	return list("customer" = customer_ref, "bread" = bread_ref, "carriage" = "\ref[intro_carriage]", "horse" = "\ref[intro_horse]", "door" = "\ref[intro_door]", "route" = route, "walk_started" = start_time, "boarding_started" = boarding_started, "boarded_at" = boarded_at, "driving_started" = driving_started, "arrived_at" = arrived_at, "stopped_at" = stopped_at, "ended_at" = world.time, "x" = intro_carriage.x, "y" = intro_carriage.y, "z" = intro_carriage.z, "dir" = intro_carriage.dir, "driver_bound" = (intro_carriage.driver == H), "horse_bound" = (intro_horse in intro_carriage.ontop), "bread_in_inactive_hand" = (H.get_inactive_hand() == bread && bread.loc == H), "reins_in_active_hand" = (H.get_active_hand() == intro_carriage.dwheel), "moving" = intro_carriage.moving, "speed" = intro_carriage.axis.currentspeed)
