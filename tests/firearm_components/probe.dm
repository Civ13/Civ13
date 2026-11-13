// AK modular parts on a synthetic 6x4x1 world, then a whole-world save/load.
/obj/map_metadata/firearm_parts_fixture/New()
	return
/obj/item/weapon/gun/wait_for_configuration(mob/living/human/H, delay)
	return TRUE
/obj/item/weapon/gun_component/salvage_wait(mob/living/human/H)
	return TRUE
/proc/parts_steel_at(turf/T)
	var/n = 0
	for(var/obj/item/stack/material/steel/S in T)
		if(!QDELETED(S)) n += S.amount
	return n
/proc/parts_check(condition, message)
	if(!condition)
		text2file("FAIL: [message]", "parts_result.txt")
		del(world)
		sleep(1)
/proc/parts_count()
	var/n = 0
	for(var/obj/item/weapon/gun_component/P in world)
		if(!QDELETED(P)) n++
	return n
/proc/parts_unload(obj/item/weapon/gun/projectile/G)
	if(G.ammo_magazine)
		qdel(G.ammo_magazine)
		G.ammo_magazine = null
	if(G.chambered)
		qdel(G.chambered)
		G.chambered = null
	G.loaded.Cut()
/proc/parts_hold(mob/living/human/H, obj/item/I)
	H.drop_from_inventory(H.get_active_hand())
	H.put_in_active_hand(I)
/world
	hub = ""
	hub_password = ""
	maxx = 6
	maxy = 4
	maxz = 1
	fps = 20
	turf = /turf
/world/Topic(T, addr, master, key)
	return "Firearm parts fixture has no remote operations."
/world/Error(exception/e, datum/e_src)
	world.log << "Runtime error: [e] on [e.file]:[e.line]"
	text2file("FAIL: runtime [e] on [e.file]:[e.line]", "parts_result.txt")
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
	makeDatumRefLists()
	map = new /obj/map_metadata/firearm_parts_fixture
	map.ID = MAP_NOMADS_CONTINENTAL
	map.persistence = TRUE
	season = "SUMMER"
	var/area/caribbean/nomads/semiarid/base = locate(/area/caribbean/nomads/semiarid)
	if(!base) base = new /area/caribbean/nomads/semiarid
	for(var/turf/T in world)
		ChangeArea(T, base)
		T.ChangeTurf(/turf/floor/dirt, FALSE, FALSE)

	var/mob/living/human/H = new(locate(2,2,1))
	var/obj/item/weapon/gun/projectile/submachinegun/ak74/G = new(locate(2,2,1))
	parts_unload(G)
	H.put_in_inactive_hand(G)
	parts_check(H.get_inactive_hand() == G, "human holds the rifle")
	parts_check(isnull(G.firearm_part_ids), "parts stay unbuilt until first use")
	parts_check(!G.firearm_fire_block(), "a preset AK-74 can fire ([G.firearm_fire_block()])")
	parts_check(G.firearm_part_ids.len == 4 && G.firearm_part_ids["barrel"] == "ak/barrel/545x39", "preset builds four parts")
	G.firearm_parts_ready()
	parts_check(G.firearm_part_ids.len == 4, "preset applies once")
	var/base_ergo = initial(G.ergonomics)
	parts_check(G.ergonomics == base_ergo, "fixed stock keeps base ergonomics ([G.ergonomics] vs [base_ergo])")

	// Field strip the magazine well by hand.
	var/obj/item/weapon/gun_component/feed545 = G.firearm_remove("feed", H)
	parts_check(istype(feed545) && feed545.component_id == "ak/feed/545x39" && parts_count() == 1, "magazine well comes off by hand")
	parts_check(G.firearm_fire_block() == "it has no feed", "no magazine well blocks firing ([G.firearm_fire_block()])")
	// The barrel needs a bench.
	parts_check(!G.firearm_remove("barrel", H) && parts_count() == 1 && G.firearm_part_ids["barrel"], "barrel needs a bench and nothing is created without one")
	var/obj/structure/repair/gun/bench = new(locate(3,2,1))
	bench.anchored = TRUE
	var/obj/item/weapon/gun_component/barrel545 = G.firearm_remove("barrel", H)
	parts_check(istype(barrel545) && barrel545.component_id == "ak/barrel/545x39" && parts_count() == 2, "barrel comes off at a bench")

	// Convert to 7.62x39: a 7.62 barrel with the old 5.45 well cannot fire.
	var/obj/item/weapon/gun_component/barrel762 = new /obj/item/weapon/gun_component/ak_barrel_762(locate(2,2,1))
	parts_hold(H, barrel762)
	parts_check(G.firearm_install(barrel762, H) && G.firearm_part_ids["barrel"] == "ak/barrel/762x39", "7.62 barrel installs")
	parts_check(QDELETED(barrel762) && !G.firearm_install(barrel762, H), "an installed part cannot be installed twice")
	parts_hold(H, feed545)
	parts_check(G.firearm_install(feed545, H), "5.45 well installs")
	parts_check(G.firearm_fire_block() == "its barrel and magazine well are for different cartridges", "mismatched conversion blocks firing")
	parts_check(G.firearm_remove("feed", H), "5.45 well removed again")
	var/obj/item/weapon/gun_component/feed762 = new /obj/item/weapon/gun_component/ak_feed_762(locate(2,2,1))
	parts_hold(H, feed762)
	parts_check(G.firearm_install(feed762, H), "7.62 well installs")
	parts_check(!G.firearm_fire_block() && G.caliber == "a762x39" && (/obj/item/ammo_magazine/ak47 in G.good_mags) && !(/obj/item/ammo_magazine/ak74 in G.good_mags), "converted rifle takes 7.62x39 and AKM magazines ([G.caliber])")
	var/obj/item/ammo_magazine/ak47/akm_mag = new(locate(2,2,1))
	parts_hold(H, akm_mag)
	G.load_ammo(akm_mag, H)
	parts_check(G.ammo_magazine == akm_mag, "converted rifle loads an AKM magazine")
	var/obj/item/weapon/gun_component/fixed = new /obj/item/weapon/gun_component/ak_furniture_fixed(locate(2,2,1))
	parts_hold(H, fixed)
	parts_check(!G.firearm_install(fixed, H) && !QDELETED(fixed), "a loaded rifle refuses work and keeps the part")
	parts_unload(G)
	qdel(fixed)

	// Wrong gun and filled slot.
	var/obj/item/weapon/gun/projectile/revolver/makeshift/pistol = new(locate(4,2,1))
	var/obj/item/weapon/gun_component/action = new /obj/item/weapon/gun_component/ak_action(locate(2,2,1))
	parts_check(pistol.firearm_install_block(action) == "this gun takes no modular parts", "non-modular guns refuse parts")
	parts_check(G.firearm_install_block(action) == "the action slot is already filled", "a filled slot refuses a second part")
	qdel(action)

	// Stock off: worse handling, but reapplying never compounds.
	var/obj/item/weapon/gun_component/stock = G.firearm_remove("furniture", H)
	parts_check(stock && abs(G.ergonomics - base_ergo * 0.75) < 0.001, "no stock lowers handling ([G.ergonomics])")
	G.firearm_apply_parts()
	G.firearm_apply_parts()
	parts_check(abs(G.ergonomics - base_ergo * 0.75) < 0.001, "reapplying parts does not compound")
	parts_hold(H, stock)
	parts_check(G.firearm_install(stock, H) && abs(G.ergonomics - base_ergo) < 0.001, "stock restores handling")

	// Parts panel: state, block reasons, swap preview and its actions.
	var/html = G.firearm_panel_html(H)
	parts_check(findtext(html, "Ready to fire") && findtext(html, "Cartridge: 7.62x39mm") && findtext(html, "firearm_action=remove;slot=feed"), "the panel shows a ready 7.62 rifle with remove links")
	parts_check(G.firearm_panel_act(H, list("firearm_action" = "remove", "slot" = "feed")) && !G.firearm_part_ids["feed"], "the panel removes the magazine well")
	var/obj/item/weapon/gun_component/panel_feed = locate(/obj/item/weapon/gun_component) in H
	parts_check(istype(panel_feed) && panel_feed.component_id == "ak/feed/762x39", "the removed well is carried")
	var/obj/item/weapon/gun_component/spare545 = new /obj/item/weapon/gun_component/ak_feed_545(H)
	html = G.firearm_panel_html(H)
	parts_check(findtext(html, "Cannot fire: it has no feed") && findtext(html, "AK magazine well (5.45x39mm)"), "the panel shows the block and the carried parts")
	var/list/bad_preview = G.firearm_fit_preview(spare545)
	var/list/good_preview = G.firearm_fit_preview(panel_feed)
	parts_check(bad_preview["fire_block"] == "its barrel and magazine well are for different cartridges" && isnull(bad_preview["caliber"]), "previewing a 5.45 well on a 7.62 barrel shows it would not fire")
	parts_check(!good_preview["fire_block"] && good_preview["caliber"] == "a762x39" && !G.firearm_part_ids["feed"], "previewing the 7.62 well shows it fires and changes nothing")
	var/list/stock_preview = G.firearm_fit_preview(new /obj/item/weapon/gun_component/ak_furniture_folding(H))
	parts_check(abs(stock_preview["handling"] - 0.95) < 0.001 && G.firearm_part_ids["furniture"] == "ak/furniture/fixed", "previewing a folding stock shows its handling without swapping")
	for(var/obj/item/weapon/gun_component/folding in H)
		if(folding.component_id == "ak/furniture/folding") qdel(folding)
	var/obj/item/weapon/gun_component/floor_part = new /obj/item/weapon/gun_component/ak_feed_762(locate(2,2,1))
	parts_check(!G.firearm_panel_act(H, list("firearm_action" = "fit", "part" = "\ref[floor_part]")) && !G.firearm_part_ids["feed"], "the panel refuses a part the user does not carry")
	qdel(floor_part)
	parts_check(!G.firearm_panel_act(H, list("firearm_action" = "remove", "slot" = "magic")), "the panel refuses an unknown slot")
	parts_hold(H, panel_feed)
	parts_check(findtext(G.firearm_panel_html(H), "firearm_action=fit;part=\ref[panel_feed]"), "the panel offers Fit for the part in the active hand")
	parts_check(G.firearm_panel_act(H, list("firearm_action" = "fit", "part" = "\ref[panel_feed]")) && G.firearm_part_ids["feed"] == "ak/feed/762x39" && !G.firearm_fire_block(), "the panel fits the well back")

	// Salvage at the bench: about half the materials, scaled by condition.
	parts_hold(H, spare545)
	var/list/yield = firearm_salvage_yield(spare545)
	parts_check(yield[/obj/item/stack/material/steel] == 1 && yield.len == 1, "a full 5.45 well salvages for 1 steel")
	var/obj/item/weapon/gun_component/barrel_scrap = new /obj/item/weapon/gun_component/ak_barrel_545(H)
	parts_check(firearm_salvage_yield(barrel_scrap)[/obj/item/stack/material/steel] == 2, "a full barrel salvages for 2 of its 3 steel")
	barrel_scrap.condition = 0.1
	parts_check(!firearm_salvage_yield(barrel_scrap).len && findtext(firearm_salvage_preview(barrel_scrap), "returns nothing usable"), "a worn-out barrel salvages for nothing and says so")
	qdel(barrel_scrap)
	parts_check(findtext(firearm_salvage_preview(spare545), "Salvaging destroys AK magazine well (5.45x39mm) (100%) and returns 1 steel"), "the salvage preview names the part and the return ([firearm_salvage_preview(spare545)])")
	parts_check(G.firearm_panel_act(H, list("firearm_action" = "salvage", "part" = "\ref[spare545]")) && !QDELETED(spare545), "asking to salvage only shows the preview")
	bench.anchored = FALSE
	parts_check(!firearm_salvage(spare545, H) && !QDELETED(spare545), "salvage needs a firearm bench")
	bench.anchored = TRUE
	var/steel_before = parts_steel_at(H.loc)
	parts_check(G.firearm_panel_act(H, list("firearm_action" = "salvage_confirm", "part" = "\ref[spare545]")) && QDELETED(spare545), "confirming salvage destroys the part")
	parts_check(parts_steel_at(H.loc) == steel_before + 1, "salvage drops the steel ([parts_steel_at(H.loc)] vs [steel_before])")
	for(var/obj/item/stack/material/steel/S in H.loc)
		qdel(S)

	// Barrel wear blocks firing and travels with the part.
	for(var/i in 1 to 1000)
		G.firearm_wear()
	parts_check(G.firearm_fire_block() == "its barrel is worn out", "a worn-out barrel blocks firing ([G.firearm_part_condition["barrel"]])")
	var/obj/item/weapon/gun_component/worn = G.firearm_remove("barrel", H)
	parts_check(worn && worn.condition == 0, "worn barrel keeps its condition when removed")
	parts_hold(H, worn)
	parts_check(G.firearm_install(worn, H) && G.firearm_part_condition["barrel"] == 0, "reinstalling a worn barrel does not repair it")
	G.firearm_part_condition["barrel"] = 0.5

	// Factory route: every part and the bare receiver are fabricator outputs,
	// and a receiver built from them fires.
	factory_load_recipes()
	parts_check(!factory_recipe_errors.len, "factory recipes load cleanly ([jointext(factory_recipe_errors, "; ")])")
	var/list/made = list()
	for(var/recipe_name in factory_recipes)
		var/datum/factory_recipe/R = factory_recipes[recipe_name]
		var/recipe_family = null
		if(ispath(R.output_type, /obj/item/weapon/gun_component))
			var/obj/item/weapon/gun_component/part_path = R.output_type
			var/datum/firearm_component/def = firearm_component_def(initial(part_path.component_id))
			parts_check(def, "[recipe_name] makes a registered part")
			recipe_family = def.family
		else if(ispath(R.output_type, /obj/item/weapon/gun))
			var/obj/item/weapon/gun/gun_path = R.output_type
			recipe_family = initial(gun_path.firearm_family)
		if(recipe_family)
			// Each family is gated by the era its design belongs to.
			var/list/era_nodes = list("ak" = "automatic_weapons", "ar" = "automatic_weapons", "m24" = "automatic_weapons", "barrett" = "automatic_weapons",
				"vg" = "selfloading_firearms", "ptrd" = "selfloading_firearms", "pzb" = "selfloading_firearms",
				"sks" = "selfloading_firearms", "gewehr43" = "selfloading_firearms", "svt" = "selfloading_firearms", "garand" = "selfloading_firearms",
				"m1carbine" = "selfloading_firearms", "avtomat" = "selfloading_firearms", "vg5" = "selfloading_firearms", "ptrs" = "selfloading_firearms",
				"svd" = "automatic_weapons", "vss" = "automatic_weapons", "m82" = "automatic_weapons", "bamr" = "automatic_weapons",
				"makarov" = "automatic_weapons", "aps" = "automatic_weapons", "glock" = "automatic_weapons", "beretta" = "automatic_weapons", "jericho" = "automatic_weapons", "sig250" = "automatic_weapons", "p220" = "automatic_weapons", "pl14" = "automatic_weapons", "mp443" = "automatic_weapons", "deagle" = "automatic_weapons", "magnum44" = "automatic_weapons", "mckellen" = "automatic_weapons", "judge" = "automatic_weapons",
				"mp40" = "selfloading_firearms", "erma" = "selfloading_firearms", "mab38" = "selfloading_firearms", "sten" = "selfloading_firearms", "thompson" = "selfloading_firearms", "greasegun" = "selfloading_firearms", "ppsh" = "selfloading_firearms", "ppd" = "selfloading_firearms", "pps" = "selfloading_firearms", "type100" = "selfloading_firearms", "stg" = "selfloading_firearms", "fg42" = "selfloading_firearms",
				"ks23" = "automatic_weapons", "mts225" = "automatic_weapons", "spas" = "automatic_weapons", "saiga" = "automatic_weapons", "usas12" = "automatic_weapons", "ar12" = "automatic_weapons", "mp5" = "automatic_weapons", "uzi" = "automatic_weapons", "skorpion" = "automatic_weapons", "tec9" = "automatic_weapons", "vector" = "automatic_weapons", "mac10" = "automatic_weapons", "p90" = "automatic_weapons", "sr3" = "automatic_weapons", "m14" = "automatic_weapons", "fal" = "automatic_weapons", "g3" = "automatic_weapons", "ar10" = "automatic_weapons", "hk417" = "automatic_weapons", "scar" = "automatic_weapons", "aug" = "automatic_weapons", "l85" = "automatic_weapons", "qbz95" = "automatic_weapons", "vz58" = "automatic_weapons")
			var/want_node = era_nodes[recipe_family] || "cartridge_ammo"
			parts_check(R.node == want_node, "[recipe_name] is gated by [want_node] ([R.node])")
			made += R.output_type
	for(var/path in typesof(/obj/item/weapon/gun_component) - /obj/item/weapon/gun_component)
		parts_check(path in made, "a fabricator makes [path]")
	for(var/gun_path in typesof(/obj/item/weapon/gun))
		var/obj/item/weapon/gun/receiver_path = gun_path
		if(initial(receiver_path.firearm_named_by_parts))
			parts_check(gun_path in made, "a fabricator makes [gun_path]")
	// Long fabricator menus group gun parts by family.
	parts_check(factory_recipe_group(factory_recipes["Glock frame"]) == "Glock parts" && factory_recipe_group(factory_recipes["Glock slide"]) == "Glock parts", "Glock recipes share the Glock parts group")
	for(var/recipe_name in factory_recipes)
		var/datum/factory_recipe/GR = factory_recipes[recipe_name]
		if(!ispath(GR.output_type, /obj/item/weapon/gun_component) && !ispath(GR.output_type, /obj/item/weapon/gun))
			parts_check(factory_recipe_group(GR) == "General", "[recipe_name] is in the General group")
			break
	parts_check(/obj/item/weapon/gun/projectile/submachinegun/ak74/receiver in made, "a fabricator makes the AK receiver")
	parts_check(/obj/item/weapon/gun/projectile/submachinegun/m16/receiver in made, "a fabricator makes the AR receiver")
	parts_check(/obj/item/weapon/gun/projectile/boltaction/gewehr98/receiver in made, "a fabricator makes the Mauser receiver")
	parts_check(/obj/item/weapon/gun/projectile/boltaction/mosin/receiver in made, "a fabricator makes the Mosin receiver")
	parts_check(/obj/item/weapon/gun/projectile/boltaction/arisaka38/receiver in made, "a fabricator makes the Arisaka receiver")
	var/obj/item/weapon/gun/projectile/submachinegun/ak74/receiver/R = new(locate(2,2,1))
	H.drop_from_inventory(G)
	G.forceMove(locate(1,1,1))
	H.put_in_inactive_hand(R)
	parts_check(!R.ammo_magazine && R.firearm_fire_block() == "it has no action" && R.name == "AK receiver", "a bare receiver cannot fire ([R.firearm_fire_block()])")
	for(var/part_type in list(/obj/item/weapon/gun_component/ak_action, /obj/item/weapon/gun_component/ak_barrel_762, /obj/item/weapon/gun_component/ak_feed_762, /obj/item/weapon/gun_component/ak_furniture_fixed))
		var/obj/item/weapon/gun_component/part = new part_type(locate(2,2,1))
		parts_hold(H, part)
		parts_check(R.firearm_install(part, H), "receiver takes [part_type]")
	parts_check(!R.firearm_fire_block() && R.caliber == "a762x39" && R.name == "AK rifle (7.62x39mm)", "a receiver built from factory parts fires as a 7.62 rifle ([R.name])")
	H.drop_from_inventory(R)
	qdel(R)

	// Phase 5: the AR family and the AK-100 series.
	var/obj/item/weapon/gun/projectile/submachinegun/m16/commando/m4/M4 = new(locate(2,2,1))
	parts_unload(M4)
	H.put_in_inactive_hand(M4)
	var/m4_ergo = initial(M4.ergonomics)
	parts_check(!M4.firearm_fire_block() && M4.firearm_part_ids["furniture"] == "ar/furniture/collapsible" && M4.caliber == "a556x45", "an M4 builds an AR carbine preset")
	parts_check((/obj/item/ammo_magazine/m16 in M4.good_mags) && (/obj/item/ammo_magazine/ar15 in M4.good_mags), "an AR magazine well takes M16 and AR-15 magazines")
	parts_check(abs(M4.ergonomics - m4_ergo * 0.95) < 0.001, "a collapsible stock handles like a folding one ([M4.ergonomics])")
	var/obj/item/weapon/gun_component/ar_feed = M4.firearm_remove("feed", H)
	parts_check(istype(ar_feed) && ar_feed.component_id == "ar/feed/556x45", "an AR magazine well comes off by hand")
	var/obj/item/weapon/gun_component/ak_feed556 = new /obj/item/weapon/gun_component/ak_feed_556(locate(2,2,1))
	parts_check(M4.firearm_install_block(ak_feed556) == "that part is for a different gun family", "AK parts do not fit an AR")
	parts_hold(H, ar_feed)
	parts_check(M4.firearm_install(ar_feed, H) && !M4.firearm_fire_block(), "the AR magazine well goes back in")
	var/obj/item/weapon/gun/projectile/submachinegun/fallout_check = new /obj/item/weapon/gun/projectile/submachinegun/m16/fallout/service_rifle(locate(2,2,1))
	parts_check(!fallout_check.firearm_family && !fallout_check.firearm_parts_ready(), "the Service Rifle stays a fixed design")
	qdel(fallout_check)
	var/obj/item/weapon/gun/projectile/submachinegun/ak101/ak102/AK102 = new(locate(2,2,1))
	parts_check(!AK102.firearm_fire_block() && AK102.caliber == "a556x45" && (/obj/item/ammo_magazine/ak101 in AK102.good_mags), "an AK-102 builds a 5.56 AK preset")
	var/obj/item/weapon/gun/projectile/submachinegun/ak101/ak105/AK105 = new(locate(2,2,1))
	parts_check(AK105.caliber == "a545x39" && !AK105.firearm_fire_block() && (/obj/item/ammo_magazine/ak74 in AK105.good_mags), "an AK-105 builds a 5.45 AK preset")
	qdel(AK102)
	qdel(AK105)
	H.drop_from_inventory(M4)
	qdel(M4)
	var/obj/item/weapon/gun/projectile/submachinegun/m16/receiver/ARR = new(locate(2,2,1))
	H.put_in_inactive_hand(ARR)
	parts_check(!ARR.ammo_magazine && ARR.firearm_fire_block() == "it has no action" && ARR.name == "AR receiver", "a bare AR receiver cannot fire")
	for(var/part_type in list(/obj/item/weapon/gun_component/ar_action, /obj/item/weapon/gun_component/ar_barrel_556, /obj/item/weapon/gun_component/ar_feed_556, /obj/item/weapon/gun_component/ar_furniture_fixed))
		var/obj/item/weapon/gun_component/part = new part_type(locate(2,2,1))
		parts_hold(H, part)
		parts_check(ARR.firearm_install(part, H), "AR receiver takes [part_type]")
	parts_check(!ARR.firearm_fire_block() && ARR.caliber == "a556x45" && ARR.name == "AR rifle (5.56x45mm)", "an AR receiver built from factory parts fires ([ARR.name])")
	H.drop_from_inventory(ARR)
	qdel(ARR)
	qdel(ak_feed556)
	// Mauser bolt-action family: internal magazines, stripper clips and a
	// 7.92 to 7.65 conversion at the bench.
	var/obj/item/weapon/gun/projectile/boltaction/gewehr98/karabiner98k/K98 = new(locate(2,2,1))
	parts_unload(K98)
	H.put_in_inactive_hand(K98)
	var/k98_ergo = initial(K98.ergonomics)
	parts_check(!K98.firearm_fire_block() && K98.firearm_part_ids["barrel"] == "mauser/barrel/792x57" && K98.caliber == "a792x57", "a Kar98k builds a 7.92 Mauser preset")
	parts_check(abs(K98.ergonomics - k98_ergo) < 0.001, "the Mauser stock keeps base handling ([K98.ergonomics])")
	parts_check((/obj/item/ammo_magazine/gewehr98 in K98.good_mags) && K98.ammo_type == /obj/item/ammo_casing/a792x57, "the 7.92 magazine takes Gewehr 98 clips")
	var/obj/item/weapon/gun_component/mfeed = K98.firearm_remove("feed", H)
	parts_check(istype(mfeed) && mfeed.component_id == "mauser/feed/792x57", "a Mauser magazine comes off by hand")
	var/obj/item/weapon/gun_component/mbarrel = K98.firearm_remove("barrel", H)
	parts_check(istype(mbarrel) && mbarrel.component_id == "mauser/barrel/792x57", "a Mauser barrel comes off at a bench")
	for(var/part_type in list(/obj/item/weapon/gun_component/mauser_barrel_765, /obj/item/weapon/gun_component/mauser_feed_765))
		var/obj/item/weapon/gun_component/part = new part_type(locate(2,2,1))
		parts_hold(H, part)
		parts_check(K98.firearm_install(part, H), "Kar98k takes [part_type]")
	parts_check(!K98.firearm_fire_block() && K98.caliber == "a765x53" && K98.ammo_type == /obj/item/ammo_casing/a765x53 && (/obj/item/ammo_magazine/gewehr71 in K98.good_mags) && !(/obj/item/ammo_magazine/gewehr98 in K98.good_mags), "a converted Kar98k takes 7.65x53 rounds and clips ([K98.caliber])")
	var/obj/item/ammo_casing/a765x53/round765 = new(locate(2,2,1))
	parts_hold(H, round765)
	K98.bolt_open = TRUE
	H.next_load = 0
	K98.load_ammo(round765, H)
	parts_check(round765 in K98.loaded, "a converted Kar98k loads a 7.65x53 round (bolt [K98.bolt_open], loaded [K98.loaded.len], round at [round765.loc])")
	var/obj/item/weapon/gun_component/ak_bolt = new /obj/item/weapon/gun_component/ak_action(locate(2,2,1))
	parts_check(K98.firearm_install_block(ak_bolt) == "that part is for a different gun family", "AK parts do not fit a Mauser")
	qdel(ak_bolt)
	parts_unload(K98)
	H.drop_from_inventory(K98)
	qdel(K98)
	qdel(mfeed)
	qdel(mbarrel)
	var/obj/item/weapon/gun/projectile/boltaction/mauser1893/M93 = new(locate(2,2,1))
	parts_check(M93.caliber == "a7x57" && !M93.firearm_fire_block() && (/obj/item/ammo_magazine/mauser1893 in M93.good_mags), "a Mauser M1893 builds a 7x57 preset")
	qdel(M93)
	var/obj/item/weapon/gun/projectile/boltaction/gewehr98/receiver/MR = new(locate(2,2,1))
	H.put_in_inactive_hand(MR)
	parts_check(!MR.loaded.len && MR.firearm_fire_block() == "it has no action" && MR.name == "Mauser receiver", "a bare Mauser receiver holds no rounds and cannot fire")
	for(var/part_type in list(/obj/item/weapon/gun_component/mauser_action, /obj/item/weapon/gun_component/mauser_barrel_7x57, /obj/item/weapon/gun_component/mauser_feed_7x57, /obj/item/weapon/gun_component/mauser_furniture_stock))
		var/obj/item/weapon/gun_component/part = new part_type(locate(2,2,1))
		parts_hold(H, part)
		parts_check(MR.firearm_install(part, H), "Mauser receiver takes [part_type]")
	parts_check(!MR.firearm_fire_block() && MR.caliber == "a7x57" && MR.name == "Mauser rifle (7x57mm)", "a Mauser receiver built from factory parts fires ([MR.name])")
	H.drop_from_inventory(MR)
	qdel(MR)

	// Mosin and Arisaka families; the strip verb follows the family.
	var/obj/item/weapon/gun/projectile/boltaction/mosin/m30/M30 = new(locate(2,2,1))
	parts_check(!M30.firearm_fire_block() && M30.caliber == "a762x54" && (/obj/item/ammo_magazine/mosin in M30.good_mags), "a Mosin 91/30 builds the Mosin preset")
	parts_check(/obj/item/weapon/gun/proc/remove_rifle_part in M30.verbs, "a modular rifle has the strip verb")
	var/obj/item/weapon/gun/projectile/boltaction/mosin/obrez/OB = new(locate(2,2,1))
	parts_check(!OB.firearm_family && !OB.firearm_parts_ready() && !(/obj/item/weapon/gun/proc/remove_rifle_part in OB.verbs), "the Obrez stays a fixed design without the strip verb")
	parts_check(!(/obj/item/weapon/gun/proc/remove_rifle_part in pistol.verbs), "a non-modular gun has no strip verb")
	qdel(M30)
	qdel(OB)
	parts_check(/obj/item/weapon/gun/projectile/boltaction/arisaka38::ammo_type == /obj/item/ammo_casing/a65x50, "the Arisaka Type 38 spawns 6.5x50 rounds")
	var/obj/item/weapon/gun/projectile/boltaction/arisaka38/A38 = new(locate(2,2,1))
	parts_unload(A38)
	H.put_in_inactive_hand(A38)
	parts_check(!A38.firearm_fire_block() && A38.caliber == "a65x50" && (/obj/item/ammo_magazine/arisaka in A38.good_mags), "an Arisaka Type 38 builds the 6.5 preset")
	var/obj/item/weapon/gun_component/afeed = A38.firearm_remove("feed", H)
	var/obj/item/weapon/gun_component/abarrel = A38.firearm_remove("barrel", H)
	parts_check(istype(afeed) && istype(abarrel), "an Arisaka magazine and barrel come off")
	for(var/part_type in list(/obj/item/weapon/gun_component/arisaka_barrel_77, /obj/item/weapon/gun_component/arisaka_feed_77))
		var/obj/item/weapon/gun_component/part = new part_type(locate(2,2,1))
		parts_hold(H, part)
		parts_check(A38.firearm_install(part, H), "Type 38 takes [part_type]")
	parts_check(!A38.firearm_fire_block() && A38.caliber == "a77x58" && A38.ammo_type == /obj/item/ammo_casing/a77x58 && (/obj/item/ammo_magazine/arisaka99 in A38.good_mags), "a Type 38 converts to 7.7x58 with Type 99 clips")
	var/obj/item/weapon/gun_component/mosin_part = new /obj/item/weapon/gun_component/mosin_action(locate(2,2,1))
	parts_check(A38.firearm_install_block(mosin_part) == "that part is for a different gun family", "Mosin parts do not fit an Arisaka")
	qdel(mosin_part)
	H.drop_from_inventory(A38)
	qdel(A38)
	qdel(afeed)
	qdel(abarrel)
	for(var/receiver_type in list(/obj/item/weapon/gun/projectile/boltaction/mosin/receiver, /obj/item/weapon/gun/projectile/boltaction/arisaka38/receiver))
		var/obj/item/weapon/gun/projectile/BR = new receiver_type(locate(2,2,1))
		H.put_in_inactive_hand(BR)
		parts_check(!BR.loaded.len && BR.firearm_fire_block() == "it has no action", "a bare [BR.name] holds no rounds and cannot fire")
		var/list/build = istype(BR, /obj/item/weapon/gun/projectile/boltaction/mosin) ? \
			list(/obj/item/weapon/gun_component/mosin_action, /obj/item/weapon/gun_component/mosin_barrel_762, /obj/item/weapon/gun_component/mosin_feed_762, /obj/item/weapon/gun_component/mosin_furniture_stock) : \
			list(/obj/item/weapon/gun_component/arisaka_action, /obj/item/weapon/gun_component/arisaka_barrel_77, /obj/item/weapon/gun_component/arisaka_feed_77, /obj/item/weapon/gun_component/arisaka_furniture_stock)
		for(var/part_type in build)
			var/obj/item/weapon/gun_component/part = new part_type(locate(2,2,1))
			parts_hold(H, part)
			parts_check(BR.firearm_install(part, H), "[receiver_type] takes [part_type]")
		parts_check(!BR.firearm_fire_block() && (BR.name == "Mosin rifle (7.62x54mmR)" || BR.name == "Arisaka rifle (7.7x58mm)"), "a receiver built from factory parts fires ([BR.name])")
		H.drop_from_inventory(BR)
		qdel(BR)

	// Lee-Enfield, Springfield, Lebel, Berthier and Carcano families, plus the
	// Gewehr 71 and Madsen M47 on Mauser parts.
	var/list/presets = list(
		/obj/item/weapon/gun/projectile/boltaction/enfield = list("a303", /obj/item/ammo_magazine/enfield, 10),
		/obj/item/weapon/gun/projectile/boltaction/p14enfield = list("a303", /obj/item/ammo_magazine/enfield, null),
		/obj/item/weapon/gun/projectile/boltaction/springfield/sniper = list("a3006", /obj/item/ammo_magazine/springfield, 5),
		/obj/item/weapon/gun/projectile/boltaction/lebel = list("a8x50", /obj/item/ammo_magazine/c8x50, 8),
		/obj/item/weapon/gun/projectile/boltaction/berthier = list("a8x50", /obj/item/ammo_magazine/c8x50_3clip, 3),
		/obj/item/weapon/gun/projectile/boltaction/berthier/m16 = list("a8x50", /obj/item/ammo_magazine/c8x50_5clip, 5),
		/obj/item/weapon/gun/projectile/boltaction/carcano = list("a65x52", /obj/item/ammo_magazine/carcano, null),
		/obj/item/weapon/gun/projectile/boltaction/gewehr71 = list("a765x53", /obj/item/ammo_magazine/gewehr71, null),
		/obj/item/weapon/gun/projectile/boltaction/madsenm47 = list("a765x53", /obj/item/ammo_magazine/gewehr71, null),
		/obj/item/weapon/gun/projectile/boltaction/murata = list("a8x53", /obj/item/ammo_magazine/murata, 8),
		/obj/item/weapon/gun/projectile/boltaction/berdan = list("a762x54", /obj/item/ammo_magazine/mosin, null),
		/obj/item/weapon/gun/projectile/boltaction/vg = list("a792x33", /obj/item/ammo_magazine/vgclip, 10),
		/obj/item/weapon/gun/projectile/boltaction/m24 = list("a762x51", /obj/item/ammo_magazine/m24, null),
		/obj/item/weapon/gun/projectile/boltaction/singleshot = list("a4570", null, 1),
		/obj/item/weapon/gun/projectile/boltaction/singleshot/rollingblock = list("a4570", null, 1),
		/obj/item/weapon/gun/projectile/boltaction/singleshot/rollingblock/spanish = list("a43", null, 1),
		/obj/item/weapon/gun/projectile/boltaction/singleshot/martini_henry = list("a577", null, 1),
		/obj/item/weapon/gun/projectile/boltaction/singleshot/ptrd = list("a145", null, 1),
		/obj/item/weapon/gun/projectile/boltaction/singleshot/pzb39 = list("a792x94", null, 1),
		/obj/item/weapon/gun/projectile/boltaction/singleshot/barrett/sniper = list("a50cal", null, 1),
		/obj/item/weapon/gun/projectile/semiautomatic/sks = list("a762x39", /obj/item/ammo_magazine/sks, 10),
		/obj/item/weapon/gun/projectile/semiautomatic/sks/chinese = list("a762x39", /obj/item/ammo_magazine/sks, 10),
		/obj/item/weapon/gun/projectile/semiautomatic/sks/sksm = list("a762x39", /obj/item/ammo_magazine/ak47, null),
		/obj/item/weapon/gun/projectile/semiautomatic/g41 = list("a792x57", /obj/item/ammo_magazine/gewehr98, 10),
		/obj/item/weapon/gun/projectile/semiautomatic/g43 = list("a792x57", /obj/item/ammo_magazine/g43, 10),
		/obj/item/weapon/gun/projectile/semiautomatic/svt = list("a762x54", /obj/item/ammo_magazine/svt, null),
		/obj/item/weapon/gun/projectile/semiautomatic/m1garand/match = list("a3006", /obj/item/ammo_magazine/garand, 8),
		/obj/item/weapon/gun/projectile/semiautomatic/m1carbine = list("a762x33", /obj/item/ammo_magazine/m1carbine, null),
		/obj/item/weapon/gun/projectile/semiautomatic/avtomat = list("a65x50", /obj/item/ammo_magazine/avtomat, 25),
		/obj/item/weapon/gun/projectile/semiautomatic/vg5 = list("a792x33", /obj/item/ammo_magazine/stg, 30),
		/obj/item/weapon/gun/projectile/semiautomatic/ptrs = list("a145", /obj/item/ammo_magazine/ptrs, 5),
		/obj/item/weapon/gun/projectile/semiautomatic/svd/acog = list("a762x54", /obj/item/ammo_magazine/svd, 10),
		/obj/item/weapon/gun/projectile/semiautomatic/vintorez = list("a9x39", /obj/item/ammo_magazine/vintorez, null),
		/obj/item/weapon/gun/projectile/semiautomatic/barrett/sniper = list("a50cal", /obj/item/ammo_magazine/barrett, null),
		/obj/item/weapon/gun/projectile/semiautomatic/bamr/telescope = list("a15115", /obj/item/ammo_magazine/bamr, null),
		/obj/item/weapon/gun/projectile/semiautomatic/ar15 = list("a556x45", /obj/item/ammo_magazine/ar15, null),
		/obj/item/weapon/gun/projectile/special/mk18/tan = list("a556x45", /obj/item/ammo_magazine/mk18, null),
		/obj/item/weapon/gun/projectile/special/ak74mtactical = list("a545x39", /obj/item/ammo_magazine/ak74, null),
		/obj/item/weapon/gun/projectile/leveraction/winchesterm1873/gold = list("a44", null, 14),
		/obj/item/weapon/gun/projectile/leveraction/evansrepeater = list("a44", null, 28),
		/obj/item/weapon/gun/projectile/leveraction/winchesterm1886 = list("a4570", null, 9),
		/obj/item/weapon/gun/projectile/leveraction/cowboy_repeater = list("a357", null, 7),
		/obj/item/weapon/gun/projectile/pistol/ww2/nambu = list("c8mmnambu", /obj/item/ammo_magazine/c8mmnambu, null),
		/obj/item/weapon/gun/projectile/pistol/bergmann = list("c8mmnambu", /obj/item/ammo_magazine/bergmann, null),
		/obj/item/weapon/gun/projectile/pistol/luger = list("a9x19", /obj/item/ammo_magazine/luger, null),
		/obj/item/weapon/gun/projectile/pistol/waltherp38/silenced = list("a9x19", /obj/item/ammo_magazine/walther, null),
		/obj/item/weapon/gun/projectile/pistol/browninghp = list("a9x19", /obj/item/ammo_magazine/browninghp, null),
		/obj/item/weapon/gun/projectile/pistol/mauser = list("a762x25", /obj/item/ammo_magazine/mauser, null),
		/obj/item/weapon/gun/projectile/pistol/borchardt = list("a765x25", /obj/item/ammo_magazine/borchardt, null),
		/obj/item/weapon/gun/projectile/pistol/colthammerless = list("a32acp", /obj/item/ammo_magazine/colthammerless, null),
		/obj/item/weapon/gun/projectile/pistol/colthammerless/m1908 = list("a380acp", /obj/item/ammo_magazine/colthammerless/a380acp, null),
		/obj/item/weapon/gun/projectile/pistol/blackm1911/silenced = list("a45acp", /obj/item/ammo_magazine/m1911, null),
		/obj/item/weapon/gun/projectile/pistol/sti2011 = list("a45acp", /obj/item/ammo_magazine/sti2011, null),
		/obj/item/weapon/gun/projectile/pistol/tt30 = list("a762x25", /obj/item/ammo_magazine/tt30, null),
		/obj/item/weapon/gun/projectile/pistol/makarov/silenced = list("a9x18", /obj/item/ammo_magazine/makarov, null),
		/obj/item/weapon/gun/projectile/pistol/aps = list("a9x18", /obj/item/ammo_magazine/aps, null),
		/obj/item/weapon/gun/projectile/pistol/glock17/standardized = list("a9x19", /obj/item/ammo_magazine/glock17, null),
		/obj/item/weapon/gun/projectile/pistol/iogb7 = list("a9x19", /obj/item/ammo_magazine/glock17, null),
		/obj/item/weapon/gun/projectile/pistol/tarus = list("a9x19", /obj/item/ammo_magazine/glock17, null),
		/obj/item/weapon/gun/projectile/pistol/m9beretta/tan = list("a9x19", /obj/item/ammo_magazine/m9beretta, null),
		/obj/item/weapon/gun/projectile/pistol/jericho941 = list("a9x19", /obj/item/ammo_magazine/jericho, null),
		/obj/item/weapon/gun/projectile/pistol/sig250 = list("a9x19", /obj/item/ammo_magazine/sig250, null),
		/obj/item/weapon/gun/projectile/pistol/p220/silenced = list("a45", /obj/item/ammo_magazine/p220, null),
		/obj/item/weapon/gun/projectile/pistol/pl14 = list("a9x19", /obj/item/ammo_magazine/pl14, null),
		/obj/item/weapon/gun/projectile/pistol/mp443 = list("a9x19", /obj/item/ammo_magazine/mp443, null),
		/obj/item/weapon/gun/projectile/pistol/deagle = list("a50cal", /obj/item/ammo_magazine/deagle, null),
		/obj/item/weapon/gun/projectile/pistol/deaglemagnum = list("a44magnum", /obj/item/ammo_magazine/deaglemagnum, null),
		/obj/item/weapon/gun/projectile/revolver/nagant_revolver/silenced = list("a762x38", null, null),
		/obj/item/weapon/gun/projectile/revolver/m1892 = list("a8x27", null, null),
		/obj/item/weapon/gun/projectile/revolver/peacemaker/storekeeper = list("a45", null, null),
		/obj/item/weapon/gun/projectile/revolver/frontier = list("a44", null, null),
		/obj/item/weapon/gun/projectile/revolver/colt1892 = list("a38", null, null),
		/obj/item/weapon/gun/projectile/revolver/coltpolicepositive/standardized = list("a32", null, null),
		/obj/item/weapon/gun/projectile/revolver/smithwesson = list("a32", null, null),
		/obj/item/weapon/gun/projectile/revolver/sw3 = list("a32", null, null),
		/obj/item/weapon/gun/projectile/revolver/snw10 = list("a38", null, null),
		/obj/item/weapon/gun/projectile/revolver/enfieldno2 = list("a41", null, null),
		/obj/item/weapon/gun/projectile/revolver/webley4 = list("a455", null, null),
		/obj/item/weapon/gun/projectile/revolver/t26_revolver = list("c9mm_jap_revolver", null, null),
		/obj/item/weapon/gun/projectile/revolver/derringer = list("a41", null, null),
		/obj/item/weapon/gun/projectile/revolver/magnum44/silenced = list("a44magnum", null, null),
		/obj/item/weapon/gun/projectile/revolver/graysonfito12 = list("a44magnum", null, null),
		/obj/item/weapon/gun/projectile/revolver/taurus = list("a45", null, null),
		/obj/item/weapon/gun/projectile/revolving/colt = list("a44", null, null))
	for(var/gun_type in presets)
		var/list/want = presets[gun_type]
		var/obj/item/weapon/gun/projectile/P = new gun_type(locate(2,2,1))
		parts_check(P.firearm_parts_ready() && !P.firearm_fire_block() && P.caliber == want[1] && (!want[2] || (want[2] in P.good_mags)) && (!want[3] || P.max_shells == want[3]), "[gun_type] builds its preset ([P.caliber], [P.max_shells])")
		for(var/round_type in (islist(P.ammo_type) ? P.ammo_type : list(P.ammo_type)))
			var/obj/item/ammo_casing/loose = round_type
			parts_check(!loose || initial(loose.caliber) == P.caliber, "[gun_type] names loose rounds of its own caliber")
		qdel(P)
	// The makeshift bolt is a fixed design; anti-tank rifles keep every round type.
	var/obj/item/weapon/gun/projectile/boltaction/singleshot/makeshiftbolt/MB = new(locate(2,2,1))
	parts_check(!MB.firearm_parts_ready() && MB.firearm_fixed_reason, "the makeshift bolt stays a fixed design")
	qdel(MB)
	var/obj/item/weapon/gun/projectile/boltaction/singleshot/ptrd/PT = new(locate(2,2,1))
	var/datum/firearm_component/ptrd_feed = PT.firearm_part("feed")
	parts_check(islist(PT.ammo_type) && length(PT.ammo_type) == 2 && PT.ammo_type != ptrd_feed.ammo_type, "a PTRD takes both 14.5mm rounds on its own list")
	qdel(PT)
	// A Rolling-Block rifle converts between .45-70 and .43 Spanish.
	var/obj/item/weapon/gun/projectile/boltaction/singleshot/rollingblock/RB = new(locate(2,2,1))
	parts_unload(RB)
	H.put_in_inactive_hand(RB)
	var/obj/item/weapon/gun_component/rb_feed = RB.firearm_remove("feed", H)
	var/obj/item/weapon/gun_component/rb_barrel = RB.firearm_remove("barrel", H)
	parts_check(istype(rb_feed) && istype(rb_barrel), "a Rolling-Block rifle gives up its barrel and extractor at the bench")
	for(var/part_type in list(/obj/item/weapon/gun_component/rollingblock_barrel_43, /obj/item/weapon/gun_component/rollingblock_feed_43))
		var/obj/item/weapon/gun_component/part = new part_type(locate(2,2,1))
		parts_hold(H, part)
		parts_check(RB.firearm_install(part, H), "a Rolling-Block rifle takes [part_type]")
	parts_check(!RB.firearm_fire_block() && RB.caliber == "a43" && RB.ammo_type == /obj/item/ammo_casing/a43, "a converted Rolling-Block rifle fires .43 Spanish ([RB.caliber])")
	H.drop_from_inventory(RB)
	qdel(RB)
	qdel(rb_feed)
	qdel(rb_barrel)
	// An SKS takes the SKS-M magazine well and then loads AK magazines; the SKS-M goes back to clips.
	var/obj/item/weapon/gun/projectile/semiautomatic/sks/SK = new(locate(2,2,1))
	parts_unload(SK)
	H.put_in_inactive_hand(SK)
	var/obj/item/weapon/gun_component/sk_feed = SK.firearm_remove("feed", H)
	var/obj/item/weapon/gun_component/sk_well = new /obj/item/weapon/gun_component/sks_feed_762x39_detachable(locate(2,2,1))
	parts_hold(H, sk_well)
	parts_check(SK.firearm_install(sk_well, H) && SK.max_shells == 0 && (SK.load_method & MAGAZINE) && SK.cliploader && (/obj/item/ammo_magazine/ak47 in SK.good_mags), "an SKS with the SKS-M magazine well takes AK magazines ([SK.max_shells], [SK.load_method])")
	var/obj/item/weapon/gun_component/sk_well_back = SK.firearm_remove("feed", H)
	parts_hold(H, sk_feed)
	parts_check(SK.firearm_install(sk_feed, H) && SK.max_shells == 10 && !(SK.load_method & MAGAZINE) && !SK.cliploader, "the fixed SKS magazine goes back to ten rounds from clips")
	H.drop_from_inventory(SK)
	qdel(SK)
	qdel(sk_well_back)
	// A Winchester M1873 rebarrelled to .45-70 keeps its own tube length.
	var/obj/item/weapon/gun/projectile/leveraction/winchesterm1873/WM = new(locate(2,2,1))
	parts_unload(WM)
	H.put_in_inactive_hand(WM)
	var/obj/item/weapon/gun_component/wm_feed = WM.firearm_remove("feed", H)
	var/obj/item/weapon/gun_component/wm_barrel = WM.firearm_remove("barrel", H)
	for(var/part_type in list(/obj/item/weapon/gun_component/lever_barrel_4570, /obj/item/weapon/gun_component/lever_feed_4570))
		var/obj/item/weapon/gun_component/part = new part_type(locate(2,2,1))
		parts_hold(H, part)
		parts_check(WM.firearm_install(part, H), "a Winchester M1873 takes [part_type]")
	parts_check(!WM.firearm_fire_block() && WM.caliber == "a4570" && WM.max_shells == 14, "a .45-70 Winchester M1873 keeps fourteen rounds ([WM.caliber], [WM.max_shells])")
	H.drop_from_inventory(WM)
	qdel(WM)
	qdel(wm_feed)
	qdel(wm_barrel)
	// Every modular gun builds its preset and names loose rounds of its own caliber,
	// and every bare receiver builds into a working gun from its family's parts.
	for(var/gun_path in typesof(/obj/item/weapon/gun/projectile))
		var/obj/item/weapon/gun/projectile/gun_type = gun_path
		if(!initial(gun_type.firearm_family) || initial(gun_type.firearm_named_by_parts))
			continue
		var/obj/item/weapon/gun/projectile/SG = new gun_path(locate(2,2,1))
		var/datum/firearm_component/sweep_barrel = SG.firearm_part("barrel")
		parts_check(SG.firearm_parts_ready() && !SG.firearm_fire_block() && sweep_barrel && SG.caliber == sweep_barrel.caliber, "[gun_path] builds its preset ([SG.caliber])")
		for(var/round_type in (islist(SG.ammo_type) ? SG.ammo_type : list(SG.ammo_type)))
			var/obj/item/ammo_casing/sweep_round = round_type
			parts_check(!sweep_round || initial(sweep_round.caliber) == SG.caliber, "[gun_path] names loose rounds of its own caliber")
		qdel(SG)
	for(var/gun_path in typesof(/obj/item/weapon/gun/projectile))
		var/obj/item/weapon/gun/projectile/gun_type = gun_path
		if(!initial(gun_type.firearm_named_by_parts))
			continue
		var/obj/item/weapon/gun/projectile/BR = new gun_path(locate(2,2,1))
		H.put_in_inactive_hand(BR)
		parts_check(!BR.loaded.len && !BR.ammo_magazine && BR.firearm_fire_block() == "it has no action", "a bare [gun_path] holds no rounds and cannot fire")
		var/chosen_caliber = null
		for(var/slot in list("action", "barrel", "feed", "furniture"))
			for(var/part_path in typesof(/obj/item/weapon/gun_component) - /obj/item/weapon/gun_component)
				var/obj/item/weapon/gun_component/part_type = part_path
				var/datum/firearm_component/def = firearm_component_def(initial(part_type.component_id))
				if(def.family != BR.firearm_family || def.slot != slot || (slot == "feed" && def.caliber != chosen_caliber))
					continue
				var/obj/item/weapon/gun_component/part = new part_path(locate(2,2,1))
				parts_hold(H, part)
				parts_check(BR.firearm_install(part, H), "[gun_path] takes [part_path]")
				if(slot == "barrel")
					chosen_caliber = def.caliber
				break
		var/want_name = "[firearm_family_labels[BR.firearm_family]] [BR.firearm_kind] ([firearm_caliber_labels[chosen_caliber]])"
		parts_check(!BR.firearm_fire_block() && BR.name == want_name, "[gun_path] builds into [want_name] ([BR.name], [BR.firearm_fire_block()])")
		H.drop_from_inventory(BR)
		qdel(BR)
	// A Berthier M07/15 takes the longer M16 magazine and then holds five rounds.
	var/obj/item/weapon/gun/projectile/boltaction/berthier/BT = new(locate(2,2,1))
	parts_unload(BT)
	H.put_in_inactive_hand(BT)
	var/obj/item/weapon/gun_component/bfeed = BT.firearm_remove("feed", H)
	parts_check(istype(bfeed), "a Berthier magazine comes off by hand")
	var/obj/item/weapon/gun_component/b5 = new /obj/item/weapon/gun_component/berthier_feed_8x50_5(locate(2,2,1))
	parts_hold(H, b5)
	parts_check(BT.firearm_install(b5, H) && BT.max_shells == 5 && (/obj/item/ammo_magazine/c8x50_5clip in BT.good_mags), "a Berthier with the M16 magazine holds five rounds")
	var/obj/item/weapon/gun_component/lebel_part = new /obj/item/weapon/gun_component/lebel_action(locate(2,2,1))
	parts_check(BT.firearm_install_block(lebel_part) == "that part is for a different gun family", "Lebel parts do not fit a Berthier")
	qdel(lebel_part)
	H.drop_from_inventory(BT)
	qdel(BT)
	qdel(bfeed)
	var/list/builds = list(
		/obj/item/weapon/gun/projectile/boltaction/enfield/receiver = list("Lee-Enfield rifle (.303 British)", /obj/item/weapon/gun_component/enfield_action, /obj/item/weapon/gun_component/enfield_barrel_303, /obj/item/weapon/gun_component/enfield_feed_303, /obj/item/weapon/gun_component/enfield_furniture_stock),
		/obj/item/weapon/gun/projectile/boltaction/springfield/receiver = list("Springfield rifle (.30-06)", /obj/item/weapon/gun_component/springfield_action, /obj/item/weapon/gun_component/springfield_barrel_3006, /obj/item/weapon/gun_component/springfield_feed_3006, /obj/item/weapon/gun_component/springfield_furniture_stock),
		/obj/item/weapon/gun/projectile/boltaction/lebel/receiver = list("Lebel rifle (8x50mmR)", /obj/item/weapon/gun_component/lebel_action, /obj/item/weapon/gun_component/lebel_barrel_8x50, /obj/item/weapon/gun_component/lebel_feed_8x50, /obj/item/weapon/gun_component/lebel_furniture_stock),
		/obj/item/weapon/gun/projectile/boltaction/berthier/receiver = list("Berthier rifle (8x50mmR)", /obj/item/weapon/gun_component/berthier_action, /obj/item/weapon/gun_component/berthier_barrel_8x50, /obj/item/weapon/gun_component/berthier_feed_8x50_5, /obj/item/weapon/gun_component/berthier_furniture_stock),
		/obj/item/weapon/gun/projectile/boltaction/carcano/receiver = list("Carcano rifle (6.5x52mm)", /obj/item/weapon/gun_component/carcano_action, /obj/item/weapon/gun_component/carcano_barrel_65x52, /obj/item/weapon/gun_component/carcano_feed_65x52, /obj/item/weapon/gun_component/carcano_furniture_stock),
		/obj/item/weapon/gun/projectile/boltaction/murata/receiver = list("Murata rifle (8x53mm)", /obj/item/weapon/gun_component/murata_action, /obj/item/weapon/gun_component/murata_barrel_8x53, /obj/item/weapon/gun_component/murata_feed_8x53, /obj/item/weapon/gun_component/murata_furniture_stock),
		/obj/item/weapon/gun/projectile/boltaction/berdan/receiver = list("Berdan rifle (7.62x54mmR)", /obj/item/weapon/gun_component/berdan_action, /obj/item/weapon/gun_component/berdan_barrel_762x54, /obj/item/weapon/gun_component/berdan_feed_762x54, /obj/item/weapon/gun_component/berdan_furniture_stock),
		/obj/item/weapon/gun/projectile/boltaction/vg/receiver = list("Volkssturmgewehr rifle (7.92x33mm Kurz)", /obj/item/weapon/gun_component/vg_action, /obj/item/weapon/gun_component/vg_barrel_792x33, /obj/item/weapon/gun_component/vg_feed_792x33, /obj/item/weapon/gun_component/vg_furniture_stock),
		/obj/item/weapon/gun/projectile/boltaction/m24/receiver = list("M24 rifle (7.62x51mm)", /obj/item/weapon/gun_component/m24_action, /obj/item/weapon/gun_component/m24_barrel_762x51, /obj/item/weapon/gun_component/m24_feed_762x51, /obj/item/weapon/gun_component/m24_furniture_stock),
		/obj/item/weapon/gun/projectile/boltaction/singleshot/receiver = list("Sharps rifle (.45-70)", /obj/item/weapon/gun_component/sharps_action, /obj/item/weapon/gun_component/sharps_barrel_4570, /obj/item/weapon/gun_component/sharps_feed_4570, /obj/item/weapon/gun_component/sharps_furniture_stock),
		/obj/item/weapon/gun/projectile/boltaction/singleshot/rollingblock/receiver = list("Rolling-block rifle (.43 Spanish)", /obj/item/weapon/gun_component/rollingblock_action, /obj/item/weapon/gun_component/rollingblock_barrel_43, /obj/item/weapon/gun_component/rollingblock_feed_43, /obj/item/weapon/gun_component/rollingblock_furniture_stock),
		/obj/item/weapon/gun/projectile/boltaction/singleshot/martini_henry/receiver = list("Martini-Henry rifle (.577/450)", /obj/item/weapon/gun_component/martini_action, /obj/item/weapon/gun_component/martini_barrel_577, /obj/item/weapon/gun_component/martini_feed_577, /obj/item/weapon/gun_component/martini_furniture_stock),
		/obj/item/weapon/gun/projectile/boltaction/singleshot/ptrd/receiver = list("PTRD rifle (14.5x114mm)", /obj/item/weapon/gun_component/ptrd_action, /obj/item/weapon/gun_component/ptrd_barrel_145, /obj/item/weapon/gun_component/ptrd_feed_145, /obj/item/weapon/gun_component/ptrd_furniture_stock),
		/obj/item/weapon/gun/projectile/boltaction/singleshot/pzb39/receiver = list("PzB rifle (7.92x94mm)", /obj/item/weapon/gun_component/pzb_action, /obj/item/weapon/gun_component/pzb_barrel_792x94, /obj/item/weapon/gun_component/pzb_feed_792x94, /obj/item/weapon/gun_component/pzb_furniture_stock),
		/obj/item/weapon/gun/projectile/boltaction/singleshot/barrett/receiver = list("Barrett rifle (.50 BMG)", /obj/item/weapon/gun_component/barrett_action, /obj/item/weapon/gun_component/barrett_barrel_50cal, /obj/item/weapon/gun_component/barrett_feed_50cal, /obj/item/weapon/gun_component/barrett_furniture_stock),
		/obj/item/weapon/gun/projectile/semiautomatic/sks/receiver = list("SKS rifle (7.62x39mm)", /obj/item/weapon/gun_component/sks_action, /obj/item/weapon/gun_component/sks_barrel_762x39, /obj/item/weapon/gun_component/sks_feed_762x39, /obj/item/weapon/gun_component/sks_furniture_stock),
		/obj/item/weapon/gun/projectile/semiautomatic/g43/receiver = list("Gewehr 41/43 rifle (7.92x57mm)", /obj/item/weapon/gun_component/gewehr43_action, /obj/item/weapon/gun_component/gewehr43_barrel_792x57, /obj/item/weapon/gun_component/gewehr43_feed_792x57_detachable, /obj/item/weapon/gun_component/gewehr43_furniture_stock),
		/obj/item/weapon/gun/projectile/semiautomatic/svt/receiver = list("SVT rifle (7.62x54mmR)", /obj/item/weapon/gun_component/svt_action, /obj/item/weapon/gun_component/svt_barrel_762x54, /obj/item/weapon/gun_component/svt_feed_762x54, /obj/item/weapon/gun_component/svt_furniture_stock),
		/obj/item/weapon/gun/projectile/semiautomatic/m1garand/receiver = list("M1 Garand rifle (.30-06)", /obj/item/weapon/gun_component/garand_action, /obj/item/weapon/gun_component/garand_barrel_3006, /obj/item/weapon/gun_component/garand_feed_3006, /obj/item/weapon/gun_component/garand_furniture_stock),
		/obj/item/weapon/gun/projectile/semiautomatic/m1carbine/receiver = list("M1 Carbine rifle (7.62x33mm)", /obj/item/weapon/gun_component/m1carbine_action, /obj/item/weapon/gun_component/m1carbine_barrel_762x33, /obj/item/weapon/gun_component/m1carbine_feed_762x33, /obj/item/weapon/gun_component/m1carbine_furniture_stock),
		/obj/item/weapon/gun/projectile/semiautomatic/avtomat/receiver = list("Fedorov rifle (6.5x50mm)", /obj/item/weapon/gun_component/avtomat_action, /obj/item/weapon/gun_component/avtomat_barrel_65x50, /obj/item/weapon/gun_component/avtomat_feed_65x50, /obj/item/weapon/gun_component/avtomat_furniture_stock),
		/obj/item/weapon/gun/projectile/semiautomatic/vg5/receiver = list("Volkssturmkarabiner rifle (7.92x33mm Kurz)", /obj/item/weapon/gun_component/vg5_action, /obj/item/weapon/gun_component/vg5_barrel_792x33, /obj/item/weapon/gun_component/vg5_feed_792x33, /obj/item/weapon/gun_component/vg5_furniture_stock),
		/obj/item/weapon/gun/projectile/semiautomatic/ptrs/receiver = list("PTRS rifle (14.5x114mm)", /obj/item/weapon/gun_component/ptrs_action, /obj/item/weapon/gun_component/ptrs_barrel_145, /obj/item/weapon/gun_component/ptrs_feed_145, /obj/item/weapon/gun_component/ptrs_furniture_stock),
		/obj/item/weapon/gun/projectile/semiautomatic/svd/receiver = list("SVD rifle (7.62x54mmR)", /obj/item/weapon/gun_component/svd_action, /obj/item/weapon/gun_component/svd_barrel_762x54, /obj/item/weapon/gun_component/svd_feed_762x54, /obj/item/weapon/gun_component/svd_furniture_stock),
		/obj/item/weapon/gun/projectile/semiautomatic/vintorez/receiver = list("VSS rifle (9x39mm)", /obj/item/weapon/gun_component/vss_action, /obj/item/weapon/gun_component/vss_barrel_9x39, /obj/item/weapon/gun_component/vss_feed_9x39, /obj/item/weapon/gun_component/vss_furniture_stock),
		/obj/item/weapon/gun/projectile/semiautomatic/barrett/receiver = list("Barrett M82 rifle (.50 BMG)", /obj/item/weapon/gun_component/m82_action, /obj/item/weapon/gun_component/m82_barrel_50cal, /obj/item/weapon/gun_component/m82_feed_50cal, /obj/item/weapon/gun_component/m82_furniture_stock),
		/obj/item/weapon/gun/projectile/semiautomatic/bamr/receiver = list("BAMR rifle (15x115mm)", /obj/item/weapon/gun_component/bamr_action, /obj/item/weapon/gun_component/bamr_barrel_15115, /obj/item/weapon/gun_component/bamr_feed_15115, /obj/item/weapon/gun_component/bamr_furniture_stock),
		/obj/item/weapon/gun/projectile/leveraction/receiver = list("Lever-action rifle (.357 Magnum)", /obj/item/weapon/gun_component/lever_action, /obj/item/weapon/gun_component/lever_barrel_357, /obj/item/weapon/gun_component/lever_feed_357, /obj/item/weapon/gun_component/lever_furniture_stock),
		/obj/item/weapon/gun/projectile/pistol/nambu/receiver = list("Nambu pistol (8mm Nambu)", /obj/item/weapon/gun_component/nambu_action, /obj/item/weapon/gun_component/nambu_barrel_8mm, /obj/item/weapon/gun_component/nambu_feed_8mm, /obj/item/weapon/gun_component/nambu_furniture_grip),
		/obj/item/weapon/gun/projectile/pistol/glock17/receiver = list("Glock pistol (9x19mm)", /obj/item/weapon/gun_component/glock_action, /obj/item/weapon/gun_component/glock_barrel_9x19, /obj/item/weapon/gun_component/glock_feed_9x19, /obj/item/weapon/gun_component/glock_furniture_grip),
		/obj/item/weapon/gun/projectile/pistol/colthammerless/receiver = list("Colt Pocket Hammerless pistol (.380 ACP)", /obj/item/weapon/gun_component/colthammerless_action, /obj/item/weapon/gun_component/colthammerless_barrel_380acp, /obj/item/weapon/gun_component/colthammerless_feed_380acp, /obj/item/weapon/gun_component/colthammerless_furniture_grip),
		/obj/item/weapon/gun/projectile/pistol/m1911/receiver = list("M1911 pistol (.45 ACP)", /obj/item/weapon/gun_component/m1911_action, /obj/item/weapon/gun_component/m1911_barrel_45acp, /obj/item/weapon/gun_component/m1911_feed_45acp_2011, /obj/item/weapon/gun_component/m1911_furniture_grip),
		/obj/item/weapon/gun/projectile/pistol/deagle/receiver = list("Desert Eagle pistol (.44 Magnum)", /obj/item/weapon/gun_component/deagle_action, /obj/item/weapon/gun_component/deagle_barrel_44magnum, /obj/item/weapon/gun_component/deagle_feed_44magnum, /obj/item/weapon/gun_component/deagle_furniture_grip),
		/obj/item/weapon/gun/projectile/revolver/peacemaker/receiver = list("Colt Single Action revolver (.44-40)", /obj/item/weapon/gun_component/colt_saa_action, /obj/item/weapon/gun_component/colt_saa_barrel_44, /obj/item/weapon/gun_component/colt_saa_feed_44, /obj/item/weapon/gun_component/colt_saa_furniture_grip),
		/obj/item/weapon/gun/projectile/revolver/smithwesson/receiver = list("Smith & Wesson revolver (.38)", /obj/item/weapon/gun_component/smithwesson_action, /obj/item/weapon/gun_component/smithwesson_barrel_38, /obj/item/weapon/gun_component/smithwesson_feed_38, /obj/item/weapon/gun_component/smithwesson_furniture_grip),
		/obj/item/weapon/gun/projectile/revolver/derringer/receiver = list("Derringer pistol (.41)", /obj/item/weapon/gun_component/derringer_action, /obj/item/weapon/gun_component/derringer_barrel_41, /obj/item/weapon/gun_component/derringer_feed_41, /obj/item/weapon/gun_component/derringer_furniture_grip),
		/obj/item/weapon/gun/projectile/revolving/colt/receiver = list("Colt Revolving rifle (.44-40)", /obj/item/weapon/gun_component/revolving_action, /obj/item/weapon/gun_component/revolving_barrel_44, /obj/item/weapon/gun_component/revolving_feed_44, /obj/item/weapon/gun_component/revolving_furniture_stock))
	for(var/receiver_type in builds)
		var/list/plan = builds[receiver_type]
		var/obj/item/weapon/gun/projectile/BR = new receiver_type(locate(2,2,1))
		H.put_in_inactive_hand(BR)
		parts_check(!BR.loaded.len && BR.firearm_fire_block() == "it has no action", "a bare [BR.name] holds no rounds and cannot fire")
		parts_check(receiver_type in made, "a fabricator makes [receiver_type]")
		for(var/i = 2, i <= plan.len, i++)
			var/part_type = plan[i]
			var/obj/item/weapon/gun_component/part = new part_type(locate(2,2,1))
			parts_hold(H, part)
			parts_check(BR.firearm_install(part, H), "[receiver_type] takes [part_type]")
		parts_check(!BR.firearm_fire_block() && BR.name == plan[1], "a receiver built from factory parts fires ([BR.name])")
		H.drop_from_inventory(BR)
		qdel(BR)

	// An AK receiver can also be built for 5.56x45mm.
	var/obj/item/weapon/gun/projectile/submachinegun/ak74/receiver/AKR = new(locate(2,2,1))
	H.put_in_inactive_hand(AKR)
	for(var/part_type in list(/obj/item/weapon/gun_component/ak_action, /obj/item/weapon/gun_component/ak_barrel_556, /obj/item/weapon/gun_component/ak_feed_556))
		var/obj/item/weapon/gun_component/part = new part_type(locate(2,2,1))
		parts_hold(H, part)
		parts_check(AKR.firearm_install(part, H), "AK receiver takes [part_type]")
	parts_check(!AKR.firearm_fire_block() && AKR.name == "AK rifle (5.56x45mm)", "an AK receiver builds as a 5.56 rifle ([AKR.name])")
	H.drop_from_inventory(AKR)
	qdel(AKR)

	// Save/load: converted rifle, untouched legacy-shaped rifle, loose parts.
	H.drop_from_inventory(H.get_active_hand())
	qdel(H)
	qdel(bench)
	qdel(pistol)
	var/obj/item/weapon/gun/projectile/submachinegun/ak47/untouched = new(locate(2,1,1))
	var/obj/item/weapon/gun_component/loose = barrel545
	loose.forceMove(locate(3,1,1))
	loose.condition = 0.4
	for(var/obj/item/weapon/gun_component/P in world)
		if(P != loose)
			qdel(P)
	sleep(10)
	parts_check(isnull(untouched.firearm_part_ids), "untouched rifle saves without parts")
	parts_check(map_storage.Save_World(), "production whole-world export succeeds")
	map_storage.ClearMap()
	parts_check(map_storage.Load_World(), "production whole-world import succeeds: [map_storage.last_error]")
	sleep(10)
	G = locate(/obj/item/weapon/gun/projectile/submachinegun/ak74) in locate(1,1,1)
	untouched = locate(/obj/item/weapon/gun/projectile/submachinegun/ak47) in locate(2,1,1)
	loose = locate(/obj/item/weapon/gun_component) in locate(3,1,1)
	parts_check(G && untouched && loose, "rifles and the loose part are restored")
	parts_check(G.firearm_part_ids["barrel"] == "ak/barrel/762x39" && G.firearm_part_ids["feed"] == "ak/feed/762x39" && G.firearm_part_ids.len == 4, "converted rifle keeps its parts")
	parts_check(G.firearm_part_condition["barrel"] == 0.5 && G.caliber == "a762x39" && !G.firearm_fire_block(), "converted rifle keeps wear and caliber")
	parts_check(/obj/item/weapon/gun/proc/remove_rifle_part in G.verbs, "a restored rifle keeps the strip verb")
	parts_check(abs(G.ergonomics - base_ergo) < 0.001, "loading does not compound handling ([G.ergonomics])")
	parts_check(isnull(untouched.firearm_part_ids) && !untouched.firearm_fire_block() && untouched.firearm_part_ids.len == 4 && untouched.caliber == "a762x39", "untouched rifle gets its preset once after load")
	parts_check(loose.component_id == "ak/barrel/545x39" && loose.condition == 0.4 && loose.name == "AK barrel (5.45x39mm)", "loose part keeps identity and condition")
	parts_check(parts_count() == 1, "no part is duplicated by save/load")

	text2file("PASS: Every modular gun family strips, converts, wears and survives save/load without duplication", "parts_result.txt")
	del(world)
