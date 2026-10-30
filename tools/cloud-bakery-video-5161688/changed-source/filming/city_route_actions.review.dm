// Held source candidate. Requires reviewed world/controller integration.
// Original Little Creek x,y coordinates; crop uses x,y-89,z=1.
var/mob/living/human/intro_actor/city_courier
var/obj/structure/farming/plant/wheat/city_plant
var/obj/structure/mill/city_mill
var/obj/item/weapon/material/kitchen/utensil/knife/city_knife

/proc/city_prepare_route()
	intro_check(BAKERY_VIDEO_RELEASED, "city route source held")
	city_courier = bakery_actor(15, 70, "Courier", /obj/item/clothing/under/civ1)
	city_plant = locate(/obj/structure/farming/plant/wheat) in locate(14, 70, 1)
	city_mill = locate(/obj/structure/mill) in locate(88, 8, 1)
	intro_check(city_plant && city_mill && city_mill.anchored, "authored crop and mill located")
	// Isolated initial fixture state only. Do not represent setup as growth.
	city_plant.stage = city_plant.readyStageMin
	city_plant.icon_state = "wheat-harvest"
	intro_check(city_plant.readyHarvest() && city_plant.Adjacent(city_courier), "staged harvest readiness and reach")
	city_knife = new(city_courier.loc)
	bakery_pickup(city_courier, city_knife)

/proc/city_walk_route(list/path, obj/item/carried)
	var/list/rows = list()
	var/actor_ref = "\ref[city_courier]"
	var/item_ref = "\ref[carried]"
	var/index = 0
	for (var/list/point in path)
		index++
		var/target_x = point[1]
		var/target_y = point[2] - 89
		var/turf/T = locate(target_x, target_y, 1)
		intro_check(T && city_courier.get_active_hand() == carried && carried.loc == city_courier, "route custody and existing target")
		if (index == 1)
			intro_check(city_courier.loc == T, "route begins at current actor location")
		else
			intro_check(get_dist(city_courier, T) == 1, "next route cell adjacent")
			intro_check(step(city_courier, get_dir(city_courier, T)) && city_courier.loc == T, "native step reached exact route cell")
		var/door_open = TRUE
		if ((target_x == 85 && target_y == 6) || (target_x == 74 && target_y == 58))
			var/obj/structure/simple_door/D = locate(/obj/structure/simple_door) in T
			door_open = D && D.state && !D.density
			intro_check(door_open, "normal door is open at route crossing")
		rows += list(list("xy" = list(target_x, target_y + 89), "actor" = actor_ref, "object" = item_ref, "held" = (carried.loc == city_courier && city_courier.get_active_hand() == carried), "door_open" = door_open, "time_ds" = world.time))
		text2file("[world.time] route-index=[index] original=[target_x],[target_y+89] item=[item_ref]", "city-route-steps.txt")
		sleep(4) // A deliberate normal-speed staging pace; never altered playback.
	return rows

/proc/city_run_route()
	intro_check(BAKERY_VIDEO_RELEASED && city_courier && city_plant && city_mill, "city preflight held or unprepared")
	var/list/events = list()
	var/courier_ref = "\ref[city_courier]"
	var/baker_ref = "\ref[bakery_baker]"
	var/list/old_wheat = list()
	for (var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/existing_wheat in city_plant.loc)
		old_wheat += existing_wheat
	intro_check(city_plant.readyHarvest() && city_plant.Adjacent(city_courier) && city_courier.get_active_hand() == city_knife, "ready wheat and normal harvest tool")
	var/turf/harvest_turf = get_turf(city_plant)
	city_plant.attackby(city_knife, city_courier)
	var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/wheat
	for (var/obj/item/weapon/reagent_containers/food/snacks/grown/wheat/harvested_wheat in harvest_turf)
		if (!(harvested_wheat in old_wheat))
			intro_check(!wheat, "exactly one new harvested wheat")
			wheat = harvested_wheat
	intro_check(wheat, "native harvest produced wheat")
	city_courier.drop_item()
	bakery_pickup(city_courier, wheat)
	var/wheat_ref = "\ref[wheat]"
	events += list(list("phase" = "harvest", "time_ds" = world.time, "actor" = courier_ref, "output" = wheat_ref, "ready_harvest" = TRUE, "normal_handler" = TRUE))
	var/list/first_route = city_walk_route(city_route_to_mill(), wheat)
	events += list(list("phase" = "route_to_mill", "time_ds" = world.time, "actor" = courier_ref, "object" = wheat_ref, "steps" = first_route))
	intro_check(city_mill.Adjacent(city_courier) && city_courier.get_active_hand() == wheat && !city_mill.current_work, "mill reachable, empty, same wheat held")
	var/list/old_flour = list()
	for (var/obj/item/weapon/reagent_containers/food/condiment/flour/existing_flour in city_mill.loc)
		old_flour += existing_flour
	var/mill_start = world.time
	city_mill.attackby(wheat, city_courier)
	events += list(list("phase" = "mill_start", "time_ds" = mill_start, "actor" = courier_ref, "input" = wheat_ref, "normal_handler" = TRUE))
	var/obj/item/weapon/reagent_containers/food/condiment/flour/flour
	for (var/obj/item/weapon/reagent_containers/food/condiment/flour/produced_flour in city_mill.loc)
		if (!(produced_flour in old_flour))
			intro_check(!flour, "exactly one new mill flour")
			flour = produced_flour
	intro_check(flour && world.time - mill_start >= 10 && !city_mill.current_work, "native mill completed its actual work")
	var/flour_ref = "\ref[flour]"
	events += list(list("phase" = "mill_finish", "time_ds" = world.time, "input" = wheat_ref, "output" = flour_ref, "completed" = TRUE))
	bakery_pickup(city_courier, flour)
	var/list/second_route = city_walk_route(city_route_to_bakery(), flour)
	events += list(list("phase" = "route_to_bakery", "time_ds" = world.time, "actor" = courier_ref, "object" = flour_ref, "steps" = second_route))
	intro_check(bakery_counter.Adjacent(city_courier) && bakery_counter.Adjacent(bakery_baker), "counter reachable by courier and baker")
	bakery_counter.attackby(flour, city_courier, "icon-x=16;icon-y=16")
	intro_check(flour.loc == bakery_counter.loc && !city_courier.get_active_hand(), "normal counter handoff placed same flour")
	bakery_pickup(bakery_baker, flour)
	intro_check(bakery_baker.get_active_hand() == flour && flour.reagents.get_reagent_amount("flour") >= 5, "baker holds same usable mill flour")
	bakery_flour = flour
	events += list(list("phase" = "flour_handoff", "time_ds" = world.time, "from" = courier_ref, "to" = baker_ref, "object" = flour_ref, "normal_handler" = TRUE))
	text2file(json_encode(list("schema" = 1, "source_revision" = "58404f5bd16e3fed80f1d9844c5db3edd144942c", "map_sha256" = "7d67c4bc869859bcfdaf549a7922497517cd573556731d43365570bf85961dd5", "crop_sha256" = "6f361982bb0c8dd5822d0aae840651e7826db69eda91fa63dc12665a134597ae", "scripted_actors" = TRUE, "capture_performed" = FALSE, "courier" = courier_ref, "baker" = baker_ref, "wheat" = wheat_ref, "flour" = flour_ref, "events" = events)), "city-route-receipt.json")
