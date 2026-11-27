// Production vending machines across a whole-world save/load on a synthetic
// 6x4x1 world. Saved product records are constructed without arguments.
/obj/map_metadata/vending_fixture/New()
	return
/obj/structure/vending/vending_fixture
	products = list(/obj/item/stack/material/wood = 2)
/mob/living/vending_fixture/New()
	return
/mob/living/vending_fixture/restrained()
	return FALSE
/mob/living/vending_fixture/update_icons()
	return
/proc/vending_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "vending_result.txt")
		del(world)
		sleep(1)
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 4
	maxz = 1
	fps = 20
	turf = /turf
/world/Topic(T, addr, master, key)
	return "Vending fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "vending_result.txt")
	del(world)
	sleep(1)
/world/New()
	generate_gameid()
	if(config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	GLOB.nanomanager = new /datum/nanomanager
	map = new /obj/map_metadata/vending_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.persistence = TRUE
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)
	// A player-stocked rack holds the real item; a vendor builds its own list.
	var/obj/structure/vending/craftable/rifles/wood/rack = new(locate(2,2,1))
	var/mob/living/vending_fixture/customer = new(locate(2,3,1))
	var/obj/item/stack/material/wood/stocked = new(customer)
	stocked.amount = 5
	customer.l_hand = stocked
	rack.attackby(stocked, customer)
	var/datum/data/vending_product/record = rack.product_records[1]
	vending_check(record && record.product_item.len == 1 && record.product_item[1] == stocked && stocked.loc == rack && stocked.amount == 5 && !customer.l_hand, "normal stock stores the exact five-plank stack")
	var/obj/item/blocked = new /obj/item/weapon/paper(customer)
	blocked.nodrop = TRUE
	customer.l_hand = blocked
	rack.attackby(blocked, customer)
	vending_check(blocked.loc == customer && customer.l_hand == blocked && rack.product_records.len == 1, "refused unequip leaves item and rack unchanged")
	customer.l_hand = null
	qdel(blocked)
	var/obj/item/second = new /obj/item/weapon/paper(customer)
	customer.l_hand = second
	rack.attackby(second, customer)
	vending_check(rack.product_records.len == 2 && second.loc == rack, "second rack item is stored")
	var/obj/structure/vending/vending_fixture/vendor = new(locate(4,2,1))
	// A market stall stocked the way a seller lists goods: one item and a stack.
	var/obj/structure/vending/sales/market_stall/stall = new(locate(5,3,1))
	var/obj/item/weapon/key = new /obj/item/weapon/hammer(locate(5,3,1))
	var/obj/item/stack/material/wood/planks = new(locate(5,3,1))
	planks.amount = 6
	sleep(10)
	vending_check(stall.invisibility == 0, "market stall becomes visible after its colours load")
	vending_check(stall.add_product(key, 4, null), "market stall lists a single item")
	vending_check(stall.add_product(planks, 2, null), "market stall lists a stack")
	vending_check(stall.product_records.len == 2 && key.loc == stall, "market stall holds both listings ([stall.product_records.len])")
	var/datum/data/vending_product/stack_row = stall.product_records[2]
	vending_check(stack_row.amount == 6 && stack_row.price == 2 && stack_row.is_stack, "stack listing keeps its count and price")
	// Pressing Buy before paying waits; the next deposit completes the sale.
	vending_check(!stall.complete_purchase(stack_row, null, 3), "an unpaid purchase waits for money")
	vending_check(stall.currently_vending == stack_row && stall.pending_amount == 3, "the waiting purchase is remembered")
	stall.moneyin = 6
	vending_check(stall.finish_pending_purchase(null), "a deposit completes the waiting purchase")
	sleep(10)
	var/sold = 0
	for (var/obj/item/stack/material/wood/W in locate(5,3,1))
		sold += W.amount
	vending_check(sold == 3 && stack_row.amount == 3 && stall.moneyin == 0 && !stall.currently_vending, "buyer receives 3 planks ([sold], [stack_row.amount] left, [stall.moneyin] in)")
	for (var/obj/item/stack/material/wood/W in locate(5,3,1))
		qdel(W)
	sleep(1)
	vending_check(rack.product_records.len == 2 && vendor.product_records.len == 1, "fixture inventories are built ([rack.product_records.len], [vendor.product_records.len])")
	qdel(customer)
	vending_check(map_storage.Save_World(), "production whole-world export succeeds")
	vending_check(map_storage.validate_world_save(), "production preflight accepts the save: [map_storage.last_error]")
	map_storage.ClearMap()
	vending_check(map_storage.Load_World(), "production whole-world import succeeds: [map_storage.last_error]")
	sleep(10)
	rack = locate(/obj/structure/vending/craftable) in locate(2,2,1)
	vendor = locate(/obj/structure/vending/vending_fixture) in locate(4,2,1)
	vending_check(rack && vendor, "vending machines are restored")
	vending_check(rack.product_records.len == 2, "rack keeps both product records")
	record = rack.product_records[1]
	var/datum/data/vending_product/second_row = rack.product_records[2]
	var/obj/item/stack/material/wood/restored = record.product_item[1]
	vending_check(restored && restored.loc == rack && restored.amount == 5 && record.vending_machine == rack, "rack preserves the real five-plank stack through load")
	vending_check(record.product_image, "rack record has a listing image after load")
	var/first_key = rack.vending_row_key(record)
	var/second_key = rack.vending_row_key(second_row)
	customer = new(locate(2,3,1))
	rack.ui_act("vend", list("value" = first_key), customer, null)
	sleep(10)
	vending_check(restored.loc == get_turf(rack) && restored.amount == 5 && rack.product_records.len == 1, "Take returns the same restored stack with five planks")
	rack.ui_act("vend", list("value" = first_key), customer, null)
	sleep(10)
	vending_check(rack.product_records.len == 1 && rack.find_vending_row(second_key) == second_row, "a stale choice cannot take the surviving row")
	var/obj/structure/vending/usa_apparel_coldwar/equipment = new(locate(3,2,1))
	sleep(8)
	var/datum/data/vending_product/standard
	var/datum/data/vending_product/variant
	for (var/datum/data/vending_product/row in equipment.product_records)
		if (row.product_path == /obj/item/clothing/under/us_uni)
			standard = row
		if (row.product_path == /obj/item/clothing/under/us_uni/us_lightuni)
			variant = row
	vending_check(standard && variant, "apparel rack builds both uniform rows")
	var/obj/item/clothing/under/us_uni/us_lightuni/returning = new(customer)
	customer.l_hand = returning
	equipment.attackby(returning, customer)
	vending_check(standard.amount == 20 && variant.amount == 11, "restocking increments the rolled-sleeve row, not the standard uniform")
	vending_check(vendor.product_records.len == 1, "vendor inventory is not built a second time on load ([vendor.product_records.len])")
	stall = locate(/obj/structure/vending/sales/market_stall) in locate(5,3,1)
	vending_check(stall && stall.product_records.len == 2, "market stall keeps its listings after load")
	stack_row = stall.product_records[2]
	var/datum/data/vending_product/item_row = stall.product_records[1]
	vending_check(stack_row.amount == 3 && stack_row.price == 2 && item_row.price == 4 && item_row.product_item.len == 1 && item_row.vending_machine == stall, "market stall listings keep stock, prices and the stocked item")
	vending_check(stall.invisibility == 0, "loaded market stall is visible")
	text2file("PASS: vending product records survive save/load without duplicates", "vending_result.txt")
	del(world)
