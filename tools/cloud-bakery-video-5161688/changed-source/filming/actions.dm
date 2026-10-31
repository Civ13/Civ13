// Reviewed native flatbread bake and same-output handoff module.
// Scripted headless actors; ingredients staged before the captured take.
#define BAKERY_VIDEO_RELEASED FALSE
var/mob/living/human/intro_actor/bakery_baker
var/mob/living/human/intro_actor/bakery_customer
var/obj/structure/oven/bakery_oven
var/obj/structure/table/bakery_counter
var/obj/item/weapon/reagent_containers/food/snacks/dough/bakery_dough
var/obj/item/weapon/reagent_containers/glass/bucket/bakery_bucket
var/obj/item/weapon/reagent_containers/food/condiment/flour/bakery_flour

/proc/bakery_actor(tx, ty, actor_name, uniform_type)
	var/mob/living/human/intro_actor/H = new(locate(tx, ty, 1))
	H.real_name = actor_name
	H.name = actor_name
	H.lastarea = get_area(H)
	H.m_intent = "walk"
	H.equip_to_slot(new uniform_type(H), slot_w_uniform)
	H.equip_to_slot(new /obj/item/clothing/shoes/leatherboots(H), slot_shoes)
	intro_check(!H.client && !H.ckey && H.stat == CONSCIOUS, "fixture-owned human, no client impersonation")
	return H

/proc/bakery_pickup(mob/living/human/H, obj/item/I)
	intro_check(I && I.Adjacent(H) && !H.get_active_hand(), "pickup reach and free hand")
	I.attack_hand(H)
	intro_check(H.get_active_hand() == I, "normal pickup completed")

/proc/bakery_prepare_scene()
	bakery_baker = bakery_actor(73, 61, "Baker", /obj/item/clothing/under/civ4)
	bakery_customer = bakery_actor(73, 59, "Customer", /obj/item/clothing/under/civ1)
	bakery_oven = locate(/obj/structure/oven) in locate(72, 61, 1)
	bakery_counter = locate(/obj/structure/table) in locate(73, 60, 1)
	intro_check(bakery_oven && bakery_counter && !bakery_oven.on, "authored oven and counter")
	var/obj/item/weapon/reagent_containers/food/snacks/flatbread/old1 = locate(/obj/item/weapon/reagent_containers/food/snacks/flatbread) in locate(73, 60, 1)
	var/obj/item/weapon/reagent_containers/food/snacks/flatbread/old2 = locate(/obj/item/weapon/reagent_containers/food/snacks/flatbread) in locate(74, 60, 1)
	intro_check(old1 && old2 && old1 != old2, "two preplaced loaves found")
	qdel(old1)
	qdel(old2)
	intro_check(!(locate(/obj/item/weapon/reagent_containers/food/snacks/flatbread) in locate(73, 60, 1)) && !(locate(/obj/item/weapon/reagent_containers/food/snacks/flatbread) in locate(74, 60, 1)), "counter cleared before preflight")
	var/obj/item/stack/material/wood/W = new(bakery_baker.loc)
	W.amount = 1
	bakery_pickup(bakery_baker, W)
	var/old_fuel = bakery_oven.fuel
	intro_check(bakery_oven.Adjacent(bakery_baker), "oven fueling reach")
	bakery_oven.attackby(W, bakery_baker)
	intro_check(bakery_oven.fuel == old_fuel + 1, "normal fuel handler")
	bakery_baker.drop_item()
	bakery_bucket = new(bakery_baker.loc)
	bakery_bucket.reagents.add_reagent("water", 5)
	bakery_pickup(bakery_baker, bakery_bucket)
	bakery_baker.swap_hand()
	intro_check(!bakery_baker.get_active_hand() && bakery_baker.get_inactive_hand() == bakery_bucket, "water staged and flour hand free")

/proc/bakery_take()
	intro_check(BAKERY_VIDEO_RELEASED, "held bakery source requires separate reviewed admission")
	var/take_start = world.time
	var/flour_ref = "\ref[bakery_flour]"
	var/bucket_ref = "\ref[bakery_bucket]"
	var/water_before = bakery_bucket.reagents.get_reagent_amount("water")
	var/flour_before = bakery_flour.reagents.get_reagent_amount("flour")
	intro_check(bakery_baker.get_active_hand() == bakery_flour && water_before >= 5 && flour_before >= 5, "ingredients held before take")
	intro_check(!(locate(/obj/item/weapon/reagent_containers/food/snacks/flatbread) in locate(73, 60, 1)) && !(locate(/obj/item/weapon/reagent_containers/food/snacks/flatbread) in locate(74, 60, 1)), "counter remains clear at take start")
	// Route preflight witnesses are retained separately; no capture occurs.
	var/list/old_dough = list()
	for (var/obj/item/weapon/reagent_containers/food/snacks/dough/D in world)
		old_dough += D
	sleep(10) // Visible starting state; never change game or playback speed.
	bakery_flour.attack_self(bakery_baker)
	intro_check(bakery_bucket.reagents.get_reagent_amount("water") == water_before - 5 && bakery_flour.reagents.get_reagent_amount("flour") == flour_before - 5, "normal dough recipe paid five water and five flour")
	for (var/obj/item/weapon/reagent_containers/food/snacks/dough/D in bakery_baker.loc)
		if (!(D in old_dough))
			intro_check(!bakery_dough, "exactly one new dough")
			bakery_dough = D
	intro_check(bakery_dough, "recipe created dough during take")
	var/dough_ref = "\ref[bakery_dough]"
	var/mixed_at = world.time
	bakery_baker.drop_item()
	bakery_baker.swap_hand()
	bakery_baker.drop_item()
	bakery_pickup(bakery_baker, bakery_dough)
	sleep(10) // Allow the newly held dough to be seen.
	var/list/old_bread = list()
	for (var/obj/item/weapon/reagent_containers/food/snacks/flatbread/B in world)
		old_bread += B
	intro_check(bakery_oven.Adjacent(bakery_baker) && bakery_baker.get_active_hand() == bakery_dough, "oven loading reach and held dough")
	bakery_oven.attackby(bakery_dough, bakery_baker)
	intro_check(bakery_dough.loc == bakery_oven, "normal oven loading")
	var/fuel_before = bakery_oven.fuel
	intro_check(bakery_oven.cooking_time == 50 && !bakery_dough.leavened && !bakery_dough.risen, "unaltered five-second flatbread recipe")
	var/cook_started = world.time
	bakery_oven.attack_hand(bakery_baker)
	intro_check(bakery_oven.on && bakery_oven.fuel == fuel_before - 1, "normal ignition consumed fuel")
	var/obj/item/weapon/reagent_containers/food/snacks/flatbread/bread
	while (!bread && world.time - cook_started < 150)
		for (var/obj/item/weapon/reagent_containers/food/snacks/flatbread/B in bakery_oven.loc)
			if (!(B in old_bread))
				intro_check(!bread, "exactly one fresh flatbread output")
				bread = B
		if (!bread)
			sleep(1)
	intro_check(bread && world.time - cook_started >= bakery_oven.cooking_time, "fresh flatbread after real cooking timer")
	var/bread_ref = "\ref[bread]"
	var/produced_at = world.time
	sleep(5) // Hold the cooked output before moving it.
	bakery_pickup(bakery_baker, bread)
	var/picked_ref = "\ref[bread]"
	intro_check(picked_ref == bread_ref, "baker holds the same cooked output")
	var/picked_at = world.time
	sleep(10) // Let the baker visibly hold the actual output.
	intro_check(bakery_counter.Adjacent(bakery_baker), "counter reach")
	bakery_counter.attackby(bread, bakery_baker, "icon-x=16;icon-y=16")
	intro_check(bread.loc == bakery_counter.loc && !bakery_baker.get_active_hand(), "normal table placement")
	var/counter_ref = "\ref[bread]"
	var/placed_at = world.time
	sleep(10)
	bakery_pickup(bakery_customer, bread)
	intro_check(bread.loc == bakery_customer && !bakery_baker.client && !bakery_customer.client, "customer received the same newly cooked bread")
	intro_check("\ref[bread]" == bread_ref && counter_ref == bread_ref, "identical produced placed and received flatbread")
	var/received_at = world.time
	var/customer_received_output = bread.loc == bakery_customer && bakery_customer.get_active_hand() == bread
	var/list/departure = intro_customer_depart(bakery_customer, bread)
	text2file(json_encode(list("take_start" = take_start, "bucket" = bucket_ref, "picked_at" = picked_at, "placed_at" = placed_at, "received_at" = received_at, "departure" = departure, "time" = world.time, "flour" = flour_ref, "dough" = dough_ref, "bread" = bread_ref, "customer" = "\ref[bakery_customer]", "customer_holds_output" = customer_received_output, "flour_paid" = (flour_before - bakery_flour.reagents.get_reagent_amount("flour")), "water_paid" = (water_before - bakery_bucket.reagents.get_reagent_amount("water")), "picked_ref" = picked_ref, "placed_ref" = counter_ref, "received_ref" = "\ref[bread]", "mixed_at" = mixed_at, "cook_started" = cook_started, "produced_at" = produced_at, "cooking_time" = bakery_oven.cooking_time, "fuel_paid" = (bakery_oven.fuel == fuel_before - 1))), "city-bakery-receipt.json")
