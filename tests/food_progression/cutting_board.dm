// Isolated cutting-board production handlers and actual entry save/load.
/obj/map_metadata/cutting_fixture/New()
	return
/mob/living/human/cutting_fixture/New()
	return
/mob/living/human/cutting_fixture/update_inv_l_hand(update_icons = 1)
	return
/mob/living/human/cutting_fixture/update_inv_r_hand(update_icons = 1)
	return
/mob/living/human/cutting_fixture/update_action_buttons()
	return
/mob/living/human/cutting_fixture/update_icons()
	return

/obj/structure/cutting_board/food_fixture/wait_for_preparation(mob/living/user, delay)
	return do_after(user, 2, src) // Bound this station's waits only, not production yields/guards.

/proc/cutting_check(condition, message)
	if (!condition)
		text2file("FAIL: [message]", "food_result.txt")
		del(world)
		sleep(1)

/proc/cutting_count(turf/site, path)
	var/count = 0
	for (var/obj/O in site)
		if (!QDELETED(O) && O.type == path)
			count++
	return count

/proc/cutting_clear(turf/site)
	for (var/obj/O in site)
		qdel(O)

/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 3
	maxz = 1
	fps = 20
	turf = /turf/floor/plating
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Topic(T, addr, master, key)
	return "Cutting-board fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e]"
	text2file("FAIL: runtime [e]", "food_result.txt")
	del(world)
	sleep(1)
/world/New()
	if (config)
		config.webhook_can_fire = FALSE
	GLOB.all_observable_events = list()
	GLOB.moved_event = new /decl/observ/moved
	GLOB.dir_set_event = new /decl/observ/dir_set
	GLOB.name_set_event = new /decl/observ/name_set
	GLOB.stat_set_event = new /decl/observ/stat_set
	initialize_chemical_reagents()
	initialize_chemical_reactions()
	map = new /obj/map_metadata/cutting_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	var/turf/site = locate(2,2,1)
	var/mob/living/human/cutting_fixture/H = new(site)
	var/knife_path = /obj/item/weapon/material/kitchen/utensil/knife/wood
	// Every old intended conversion, including previously rejected fillets/cutlets.
	var/list/routes = json_decode(file2text("cutting-board-routes.json"))
	for (var/list/route in routes)
		var/food_path = text2path("/obj/item/weapon/reagent_containers/food/snacks/[route["input"]]")
		var/output_path = text2path("/obj/item/weapon/reagent_containers/food/snacks/[route["output"]]")
		var/obj/structure/cutting_board/food_fixture/B = new(site)
		var/obj/item/weapon/reagent_containers/food/snacks/food = new food_path(H)
		cutting_check(H.put_in_active_hand(food), "food occupies a legal hand")
		B.attackby(food, H)
		cutting_check(QDELETED(food) && islist(B.input) && B.input["type"] == "[food_path]", "load consumes exactly the offered supported food")
		cutting_check(B.icon_state == route["icon"], "intake retains intended ingredient icon")
		del(food) // Reproduce GC hard deletion without a thirty-second wait.
		cutting_check(islist(B.input) && B.input["type"] == "[food_path]", "paid type survives destruction of original food")
		var/list/recipe = cutting_board_recipe(food_path)
		cutting_check(recipe["output"] == output_path && recipe["count"] == route["count"] && recipe["delay"] == route["delay"], "production plan matches frozen intended conversion")
		var/obj/item/weapon/knife = new knife_path(H)
		cutting_check(H.put_in_active_hand(knife), "preindustrial knife occupies a legal hand")
		B.attackby(knife, H)
		cutting_check(!B.input && cutting_count(site, output_path) == route["count"], "production processing keeps original item yield")
		B.attackby(knife, H)
		cutting_check(cutting_count(site, output_path) == route["count"], "empty board cannot produce more food")
		H.remove_from_mob(knife)
		qdel(knife)
		cutting_clear(site)
	// Competing preparers retain one paid slot, so only one can commit.
	var/obj/structure/cutting_board/food_fixture/B = new(site)
	var/obj/item/weapon/reagent_containers/food/snacks/rawfish/food = new(H)
	cutting_check(H.put_in_active_hand(food), "concurrent input legal hand")
	B.attackby(food, H)
	var/mob/living/human/cutting_fixture/other = new(site)
	var/obj/item/weapon/K = new knife_path(H)
	var/obj/item/weapon/K2 = new knife_path(other)
	cutting_check(H.put_in_active_hand(K) && other.put_in_active_hand(K2), "concurrent knives legal hands")
	spawn(0)
		B.attackby(K2, other)
	B.attackby(K, H)
	sleep(3)
	cutting_check(!B.input && cutting_count(site, /obj/item/weapon/reagent_containers/food/snacks/mince) == 2, "concurrent processing consumes the paid slot once")
	H.remove_from_mob(K); qdel(K)
	other.remove_from_mob(K2); qdel(K2); qdel(other)
	cutting_clear(site)
	// Cancelled/replaced/tool-lost actions cannot emit unpaid output.
	for (var/change in list("cancelled", "replacement", "knife moved", "save crossed"))
		B = new(site)
		food = new(H)
		cutting_check(H.put_in_active_hand(food), "rejection input legal hand")
		B.attackby(food, H)
		var/list/paid = B.input
		K = new knife_path(H)
		cutting_check(H.put_in_active_hand(K), "rejection knife legal hand")
		spawn(1)
			switch (change)
				if ("cancelled") H.stat = UNCONSCIOUS
				if ("replacement") B.input = list("type" = paid["type"])
				if ("knife moved") H.remove_from_mob(K)
				if ("save crossed") persistence_admission_identity = new /datum
		B.attackby(K, H)
		cutting_check(B.input && !cutting_count(site, /obj/item/weapon/reagent_containers/food/snacks/mince), "rejected action preserves slot without output: [change]")
		H.stat = 0
		if (K.loc == H) H.remove_from_mob(K)
		qdel(K)
		cutting_clear(site)
	// Scraping must not discard replacement food after its wait.
	B = new(site)
	food = new(H)
	cutting_check(H.put_in_active_hand(food), "scrape input legal hand")
	B.attackby(food, H)
	spawn(1)
		B.input = list("type" = "/obj/item/weapon/reagent_containers/food/snacks/rawfish")
	B.attack_hand(H)
	cutting_check(B.input, "scraping refuses a replacement paid slot")
	B.attack_hand(H)
	cutting_check(!B.input && B.icon_state == "cutting_board_dirty", "intentional scraping discards only the retained input")
	B.attack_hand(H)
	cutting_check(B.icon_state == "cutting_board", "dirty empty board can be cleaned")
	cutting_clear(site)
	// The real custom persistence codec retains only the consumed type marker.
	B = new(site)
	food = new(H)
	cutting_check(H.put_in_active_hand(food), "save input legal hand")
	B.attackby(food, H)
	B.before_save()
	var/savefile/F = new("cutting-board.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, B)
	cutting_check(ref, "loaded board has a saved entry")
	qdel(B)
	map_storage.clear_bookkeeping()
	B = map_storage.Load_Entry(F, ref, starting_loc = site)
	cutting_check(B && islist(B.input) && B.input["type"] == "/obj/item/weapon/reagent_containers/food/snacks/rawfish", "board paid input restores through actual entry codec")
	K = new knife_path(H)
	cutting_check(H.put_in_active_hand(K), "restored board knife legal hand")
	B.attackby(K, H)
	cutting_check(!B.input && cutting_count(site, /obj/item/weapon/reagent_containers/food/snacks/mince) == 2, "restored paid input processes once")
	text2file("PASS: cutting-board intake, original yields, GC independence, concurrency, rejections and actual entry save/load", "food_result.txt")
	del(world)
