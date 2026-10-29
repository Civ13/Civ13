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
		cutting_check(!QDELETED(food) && B.input == food && food.loc == B && !H.item_is_in_hands(food), "load retains exactly the paid food outside the actor's hands")
		cutting_check(B.icon_state == route["icon"], "intake retains intended ingredient icon")
		var/list/recipe = cutting_board_recipe(food_path)
		cutting_check(recipe["output"] == output_path && recipe["count"] == route["count"] && recipe["delay"] == route["delay"], "production plan matches frozen intended conversion")
		var/obj/item/weapon/knife = new knife_path(H)
		cutting_check(H.put_in_active_hand(knife), "preindustrial knife occupies a legal hand")
		B.attackby(knife, H)
		cutting_check(QDELETED(food) && !B.input && cutting_count(site, output_path) == route["count"], "production processing consumes the real input once and keeps original item yield")
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
	for (var/change in list("cancelled", "replacement", "knife moved", "save crossed", "rotted"))
		B = new(site)
		food = new(H)
		cutting_check(H.put_in_active_hand(food), "rejection input legal hand")
		B.attackby(food, H)
		var/obj/item/weapon/reagent_containers/food/snacks/paid = B.input
		K = new knife_path(H)
		cutting_check(H.put_in_active_hand(K), "rejection knife legal hand")
		spawn(1)
			switch (change)
				if ("cancelled") H.stat = UNCONSCIOUS
				if ("replacement") B.input = new /obj/item/weapon/reagent_containers/food/snacks/rawfish(B)
				if ("knife moved") H.remove_from_mob(K)
				if ("save crossed") persistence_admission_identity = new /datum
				if ("rotted") paid.rotten = TRUE
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
		B.input = new /obj/item/weapon/reagent_containers/food/snacks/rawfish(B)
	B.attack_hand(H)
	cutting_check(B.input, "scraping refuses a replacement paid slot")
	B.attack_hand(H)
	cutting_check(!B.input && B.icon_state == "cutting_board_dirty", "intentional scraping discards only the retained input")
	B.attack_hand(H)
	cutting_check(B.icon_state == "cutting_board", "dirty empty board can be cleaned")
	cutting_clear(site)
	// Poisonous and already-minced subtypes remain intact, never sanitized/reset.
	B = new(site)
	var/obj/item/weapon/reagent_containers/food/snacks/meat/poisonfrog/frog = new(H)
	cutting_check(H.put_in_active_hand(frog), "poisonous subtype legal hand")
	B.attackby(frog, H)
	cutting_check(!B.input && frog.loc == H && frog.reagents.get_reagent_amount("cyanide") == 25 && frog.reagents.get_reagent_amount("food_poisoning") == 15, "unsupported poisonous frog remains unchanged in hand")
	H.remove_from_mob(frog); qdel(frog)
	var/obj/item/weapon/reagent_containers/food/snacks/driedmeat/dried = new(H)
	cutting_check(H.put_in_active_hand(dried), "dried input legal hand")
	dried.mark_salted_meat()
	dried.decaytimer = dried.decay * 0.8
	B.attackby(dried, H)
	K = new knife_path(H)
	cutting_check(H.put_in_active_hand(K), "dried knife legal hand")
	B.attackby(K, H)
	var/obj/item/weapon/reagent_containers/food/snacks/driedmeat/minced_driedmeat/minced = locate() in site
	cutting_check(minced && minced.salted_meat && minced.decaytimer / minced.decay >= 0.8, "dried product retains paid salt and relative age")
	cutting_check(H.put_in_inactive_hand(minced), "repeat minced input legal hand")
	var/minced_age = minced.decaytimer
	for (var/repeat in 1 to 3)
		B.attackby(minced, H)
		B.attackby(K, H)
	cutting_check(!B.input && minced.loc == H && minced.decaytimer >= minced_age && cutting_count(site, minced.type) == 0, "already-minced product cannot repeat mincing or reset its age")
	H.remove_from_mob(minced); qdel(minced)
	H.remove_from_mob(K); qdel(K)
	cutting_clear(site)
	// Accelerated real food callbacks still charge exposed-board time and rot it.
	B = new(site)
	food = new(H)
	cutting_check(H.put_in_active_hand(food), "aging input legal hand")
	B.attackby(food, H)
	sleep(18)
	cutting_check(!QDELETED(food) && food.loc == B && food.decaytimer >= 4800 && food.rotten, "live board food ages and rots without freezing")
	K = new knife_path(H)
	cutting_check(H.put_in_active_hand(K), "rotten rejection knife legal hand")
	B.attackby(K, H)
	cutting_check(B.input == food && !cutting_count(site, /obj/item/weapon/reagent_containers/food/snacks/mince), "rotten board food cannot become fresh mince")
	H.remove_from_mob(K); qdel(K)
	cutting_clear(site)
	// The real custom persistence codec retains a live paid food child and reagents.
	B = new(site)
	food = new(H)
	food.mark_salted_meat()
	food.decaytimer = food.decay * 0.1
	food.reagents.add_reagent("cyanide", 2)
	food.reagents.add_reagent("food_poisoning", 1)
	food.radiation = 137
	var/paid_food_poison = food.reagents.get_reagent_amount("food_poisoning")
	cutting_check(H.put_in_active_hand(food), "save input legal hand")
	B.attackby(food, H)
	B.before_save()
	var/savefile/F = new("cutting-board.sav")
	F["/format_version"] << 2
	map_storage.clear_bookkeeping()
	map_storage.saving_z = 1
	var/ref = map_storage.BuildVarDirectory(F, B, 1)
	cutting_check(ref, "loaded board has a saved entry")
	qdel(B)
	map_storage.clear_bookkeeping()
	B = map_storage.Load_Entry(F, ref, starting_loc = site)
	var/obj/item/weapon/reagent_containers/food/snacks/restored = B.input
	cutting_check(B && restored && restored.loc == B && !QDELETED(restored) && restored.salted_meat && restored.radiation == 137 && restored.decaytimer / restored.decay >= 0.1 && restored.reagents.get_reagent_amount("cyanide") == 2 && restored.reagents.get_reagent_amount("food_poisoning") == paid_food_poison, "board live food child, age, salt and hazards restore through actual entry codec")
	var/paid_protein = restored.reagents.get_reagent_amount("protein")
	K = new knife_path(H)
	cutting_check(H.put_in_active_hand(K), "restored board knife legal hand")
	B.attackby(K, H)
	cutting_check(!B.input && cutting_count(site, /obj/item/weapon/reagent_containers/food/snacks/mince) == 2, "restored paid input processes once")
	var/protein = 0
	var/cyanide = 0
	var/food_poison = 0
	for (var/obj/item/weapon/reagent_containers/food/snacks/mince/output in site)
		protein += output.reagents.get_reagent_amount("protein")
		cyanide += output.reagents.get_reagent_amount("cyanide")
		food_poison += output.reagents.get_reagent_amount("food_poisoning")
		cutting_check(output.salted_meat && output.radiation == 137 && output.decaytimer / output.decay >= 0.1, "output retains salt, radiation and elapsed relative age")
	cutting_check(abs(protein - paid_protein) < 0.001 && abs(cyanide - 2) < 0.001 && abs(food_poison - paid_food_poison) < 0.001, "output shares preserve total paid protein and poison without constructor nutrition")
	text2file("PASS: cutting-board live food, original yields, elapsed age, salt/reagents, subtype refusal, concurrency, rejections and actual child save/load", "food_result.txt")
	del(world)
