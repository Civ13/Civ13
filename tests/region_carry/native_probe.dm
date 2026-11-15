// Headless region travel carry probe. Test-only: native_probe.py appends it to
// a temporary copy of civ13.dme. It checks which items can travel between
// regions and that a character payload rebuilds them exactly: packaged food,
// medicine, tools, unloaded guns and magazines by round count.
var/global/datum/region_carry_probe/region_carry_probe = new

/datum/region_carry_probe
	var/list/checks = list()
	var/phase = "startup"
	var/started_tod = 0

/datum/region_carry_probe/New()
	if (!all_species || !all_species.len)
		makeDatumRefLists()
	if (!config)
		load_configuration()
		initialize_chemical_reagents()
		initialize_chemical_reactions()
	if (config)
		config.webhook_can_fire = FALSE
		config.ToRban = FALSE
	started_tod = world.timeofday
	spawn(10)
		drive()

/datum/region_carry_probe/proc/mark(name)
	phase = name

/datum/region_carry_probe/proc/pass(name, list/details = null)
	checks += list(list("check" = name, "passed" = TRUE, "details" = details))

/datum/region_carry_probe/proc/require(condition, message)
	if (!condition)
		throw EXCEPTION(message)

/datum/region_carry_probe/proc/wait_for(datum/target, proc_name, deadline_ds, message)
	var/until = world.time + deadline_ds
	while (!call(target, proc_name)())
		if (world.time > until)
			throw EXCEPTION(message)
		sleep(5)

/datum/region_carry_probe/proc/game_playing()
	return ticker && ticker.current_state == GAME_STATE_PLAYING

/datum/region_carry_probe/proc/scheduler_ready()
	return ticker && processScheduler && processes && ticker.current_state >= GAME_STATE_PREGAME

/datum/region_carry_probe/proc/unload(obj/item/weapon/gun/projectile/G)
	for (var/atom/movable/A in G.contents)
		qdel(A)
	G.ammo_magazine = null
	G.chambered = null
	if (islist(G.loaded))
		G.loaded.Cut()

/datum/region_carry_probe/proc/drive()
	var/failure = null
	var/failed_phase = null
	try
		mark("startup")
		wait_for(src, "scheduler_ready", 9000, "Scheduler/ticker never became ready")
		ticker.admin_started = TRUE
		if (ticker.pregame_timeleft > 1)
			ticker.pregame_timeleft = 1
		wait_for(src, "game_playing", 3000, "Round did not reach PLAYING")
		var/turf/T = locate(10, 10, 1)

		mark("kinds")
		var/obj/item/weapon/reagent_containers/food/drinks/can/cola/cola = new(T)
		var/obj/item/weapon/reagent_containers/food/snacks/cracker/cracker = new(T)
		var/obj/item/weapon/crowbar/crowbar = new(T)
		var/obj/item/weapon/gun/projectile/pistol/glock17/gun = new(T)
		var/obj/item/ammo_magazine/glock17/mag = new(T)
		var/obj/item/stack/medical/bruise_pack/pack = new(T, 5)
		var/obj/item/clothing/head/helmet/kevlarhelmet/helmet = new(T)
		require(region_travel_item_kind(cola) == "type", "fresh cola: [region_travel_item_kind(cola)]")
		require(region_travel_item_kind(cracker) == "type", "fresh cracker")
		require(region_travel_item_kind(crowbar) == "type", "crowbar")
		require(region_travel_item_kind(pack) == "stack:bruise_pack", "bruise pack: [region_travel_item_kind(pack)]")
		require(region_travel_item_kind(helmet) == "type", "helmet")
		require(region_travel_item_kind(mag) == "ammo:[mag.type]", "full magazine: [region_travel_item_kind(mag)]")
		require(region_travel_ammo_count(mag) == mag.max_ammo, "full magazine count [region_travel_ammo_count(mag)]")
		pass("carry_kinds")

		mark("refusals")
		require(isnull(region_travel_item_kind(gun)), "loaded gun would travel")
		var/obj/item/weapon/reagent_containers/food/drinks/can/cola/sipped = new(T)
		sipped.reagents.remove_any(5)
		require(isnull(region_travel_item_kind(sipped)), "sipped cola would travel")
		var/obj/item/weapon/reagent_containers/food/snacks/cracker/bitten = new(T)
		bitten.bitecount = 1
		require(isnull(region_travel_item_kind(bitten)), "bitten cracker would travel")
		var/obj/item/stack/medical/bruise_pack/bint/bint = new(T, 3)
		require(isnull(region_travel_item_kind(bint)), "bandage subtype would travel")
		var/obj/item/weapon/storage/backpack/bag = new(T)
		require(isnull(region_travel_item_kind(bag)), "backpack would travel")
		var/obj/item/ammo_magazine/glock17/mixed = new(T)
		mixed.stored_ammo += new /obj/item/ammo_casing(mixed)
		require(isnull(region_travel_item_kind(mixed)), "magazine with foreign contents would travel")
		pass("refusals")

		mark("payload")
		unload(gun)
		require(region_travel_item_kind(gun) == "type", "unloaded gun: [region_travel_item_kind(gun)]")
		for (var/i in 1 to 3)
			var/obj/item/ammo_casing/C = mag.stored_ammo[mag.stored_ammo.len]
			mag.stored_ammo.len--
			qdel(C)
		var/rounds = region_travel_ammo_count(mag)
		require(rounds == mag.max_ammo - 3, "partial magazine count [rounds]")
		var/mob/living/human/H = new(T)
		H.persistence_owner_ckey = "carryprobe"
		var/list/items = list("l_hand" = mag, "r_hand" = gun, "l_store" = pack, "r_store" = cola, "head" = helmet, "belt" = crowbar, "id" = cracker)
		var/payload = H.region_travel_payload(items)
		var/list/P = region_travel_decode(payload)
		require(P, "payload did not decode: [payload]")
		require(P["items"].len == 7, "payload items [P["items"].len]")
		var/list/bad = list("v" = 1, "kind" = "character", "owner" = "carryprobe", "name" = "Probe", "gender" = MALE, "age" = 30, "look" = list(), "skills" = list(), "nutrition" = 100, "water" = 100,
			"items" = list(list("l_hand", "ammo:/obj/item/ammo_magazine/glock17", 999)))
		require(!region_travel_decode(json_encode(bad)), "overfull magazine decoded")
		bad["items"] = list(list("l_hand", "/obj/item/weapon/storage/backpack", 1))
		require(!region_travel_decode(json_encode(bad)), "backpack decoded")
		pass("payload_roundtrip", list("bytes" = length(payload)))

		mark("rebuild")
		var/turf/D = locate(20, 20, 1)
		var/mob/living/human/built = region_travel_build(P, D)
		var/list/found = list()
		for (var/obj/item/I in built.contents + D.contents)
			found += I
		var/obj/item/ammo_magazine/glock17/newmag = locate() in found
		require(newmag && region_travel_ammo_count(newmag) == rounds, "rebuilt magazine holds [newmag ? region_travel_ammo_count(newmag) : "nothing"], expected [rounds]")
		var/obj/item/weapon/gun/projectile/pistol/glock17/newgun = locate() in found
		require(newgun && !newgun.contents.len && !newgun.ammo_magazine, "rebuilt gun missing or loaded")
		var/obj/item/stack/medical/bruise_pack/newpack = locate() in found
		require(newpack && newpack.type == /obj/item/stack/medical/bruise_pack && newpack.amount == 5, "rebuilt bruise pack wrong")
		require(locate(/obj/item/weapon/reagent_containers/food/drinks/can/cola) in found, "cola missing")
		require(locate(/obj/item/weapon/crowbar) in found, "crowbar missing")
		require(locate(/obj/item/weapon/reagent_containers/food/snacks/cracker) in found, "cracker missing")
		require(locate(/obj/item/clothing/head/helmet/kevlarhelmet) in found, "helmet missing")
		pass("rebuild")

		mark("whole_items")
		// What the HMS gnome 2's crew could not take (2026-11-15) travels whole.
		var/mob/living/human/V = new(T)
		V.persistence_owner_ckey = "carryprobevoyager"
		var/obj/item/clothing/suit/prehistoricfurcoat/coat = new(T)
		coat.name = "Ada's pelt coat"
		var/obj/item/clothing/under/leaves_skirt/au_naturel/leaves = new(T)
		var/obj/item/weapon/storage/backpack/pack_basket/basket = new(T)
		var/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin/skin = new(T)
		skin.reagents.add_reagent("water", 25)
		var/obj/item/weapon/paddle/paddle = new(T)
		var/obj/item/weapon/book/master = create_stone_age_master_book(T)
		var/chapters = master.research_chapters
		var/obj/item/stack/material/bone/bones = new(T, 7)
		var/obj/item/stack/ore/iron/ore = new(T, 4)
		var/obj/item/weapon/storage/backpack/pack_basket/inner = new(T)
		var/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin/skin2 = new(T)
		skin2.reagents.add_reagent("water", 10)
		inner.handle_item_insertion(skin2, TRUE)
		for (var/obj/item/I in list(bones, ore, inner))
			basket.handle_item_insertion(I, TRUE)
		require(basket.contents.len == 3, "basket holds [basket.contents.len]")
		V.equip_to_slot_or_del(leaves, slot_w_uniform)
		V.equip_to_slot_or_del(coat, slot_wear_suit)
		V.equip_to_slot_or_del(basket, slot_back)
		V.equip_to_slot_or_del(skin, slot_wear_id)
		V.put_in_l_hand(paddle)
		V.put_in_r_hand(master)
		require(V.w_uniform == leaves && V.wear_id == skin, "probe could not dress the voyager")
		var/list/carried = V.region_travel_items()
		require(islist(carried), "voyager refused: [carried]")
		var/list/kinds = list()
		for (var/slot_name in carried)
			kinds[slot_name] = copytext(region_travel_worn_kind(carried[slot_name]), 1, 300)
		require(copytext(kinds["l_hand"], 1, 6) == "item:" && (copytext(kinds["back"], 1, 5) == "bag:" || copytext(kinds["back"], 1, 6) == "item:"), "kinds [json_encode(kinds)]")
		// An untouched crowbar still travels by type alone.
		require(region_travel_worn_kind(new /obj/item/weapon/crowbar(T)) == "type", "plain crowbar is no longer a plain type")
		var/list/VP = region_travel_decode(V.region_travel_payload(carried))
		require(VP, "voyager payload did not decode")
		var/turf/D2 = locate(30, 30, 1)
		var/mob/living/human/arrived = region_travel_build(VP, D2)
		var/list/got = list()
		for (var/obj/item/I in arrived.contents + D2.contents)
			got += I
		var/obj/item/clothing/suit/prehistoricfurcoat/newcoat = locate() in got
		require(newcoat && newcoat.name == "Ada's pelt coat" && newcoat.icon_state == coat.icon_state, "coat came back as [newcoat ? "[newcoat.name]/[newcoat.icon_state]" : "nothing"], sent [coat.icon_state]: [kinds["suit"]]")
		// The coat picks its colour as it is made, so its colour always travels.
		var/list/coat_defaults = region_travel_generic_defaults[coat.type]
		require(coat_defaults && coat_defaults["icon_state"] == "\[random]", "coat colour not seen as random: [coat_defaults ? coat_defaults["icon_state"] : "no samples"]")
		// Dressed from the skin out: the leaves under the coat, the waterskin on them.
		require(istype(arrived.w_uniform, /obj/item/clothing/under/leaves_skirt/au_naturel) && arrived.wear_suit, "arrived undressed: uniform [arrived.w_uniform], suit [arrived.wear_suit]")
		require(locate(/obj/item/weapon/paddle) in got, "paddle missing")
		var/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin/newskin = arrived.wear_id
		require(istype(newskin) && abs(newskin.reagents.get_reagent_amount("water") - 25) < 0.1, "waterskin holds [istype(newskin) ? newskin.reagents.get_reagent_amount("water") : "nothing"]")
		var/obj/item/weapon/book/newmaster = arrived.r_hand
		require(istype(newmaster) && newmaster.research_chapters == chapters && newmaster.name == "Stone Age master book", "master book lost its chapters")
		var/obj/item/weapon/storage/backpack/pack_basket/newbasket = arrived.back
		require(istype(newbasket) && newbasket.contents.len == 3, "basket came back holding [istype(newbasket) ? newbasket.contents.len : "nothing"]")
		var/obj/item/stack/material/bone/newbones = locate() in newbasket.contents
		var/obj/item/stack/ore/iron/newore = locate() in newbasket.contents
		require(newbones && newbones.amount == 7 && newore && newore.amount == 4, "stacks in the basket changed")
		var/obj/item/weapon/storage/backpack/pack_basket/newinner = locate() in newbasket.contents
		var/obj/item/weapon/reagent_containers/food/drinks/drinkingglass/waterskin/newskin2 = newinner ? locate() in newinner.contents : null
		require(newskin2 && abs(newskin2.reagents.get_reagent_amount("water") - 10) < 0.1, "basket in the basket lost its waterskin")
		// A loaded gun travels loaded: links to what it holds are rebuilt.
		var/obj/item/weapon/gun/projectile/pistol/glock17/loadedgun = new(T)
		if (!loadedgun.ammo_magazine)
			loadedgun.ammo_magazine = new /obj/item/ammo_magazine/glock17(loadedgun)
		var/rounds_in = region_travel_ammo_count(loadedgun.ammo_magazine)
		var/obj/item/weapon/gun/projectile/pistol/glock17/gunback = region_travel_make_worn(region_travel_worn_kind(loadedgun), 1, D2)
		require(istype(gunback) && gunback.ammo_magazine && (gunback.ammo_magazine in gunback.contents) && region_travel_ammo_count(gunback.ammo_magazine) == rounds_in, "loaded gun came back without its magazine")
		var/count_mags = 0
		for (var/obj/item/ammo_magazine/M in gunback.contents)
			count_mags++
		require(count_mags == 1, "gun came back with [count_mags] magazines")
		// Large numbers keep every digit; temporary bookkeeping stays behind.
		var/obj/item/weapon/paddle/marked = new(T)
		marked.value = 123456789
		marked.abandonment_index = 77
		var/obj/item/weapon/paddle/markedback = region_travel_make_worn(region_travel_worn_kind(marked), 1, D2)
		require(markedback.value == 123456789 && !markedback.abandonment_index, "paddle came back worth [markedback.value], index [markedback.abandonment_index]")
		// A field of the wrong class is skipped, not a failed arrival.
		var/obj/item/weapon/paddle/odd = region_travel_make_generic("item:[json_encode(list("t" = "/obj/item/weapon/paddle", "v" = list("gender" = "x", "force" = "heavy", "name" = "odd paddle")))]", D2)
		require(istype(odd) && odd.name == "odd paddle" && isnum(odd.force), "odd record broke the build")
		// Nothing holding a creature, and no grab, ever travels.
		var/mob/living/simple_animal/mouse/stowaway = new(skin2)
		require(isnull(region_travel_generic_kind(inner)), "a bag holding a creature would travel")
		qdel(stowaway)
		// Ship decks and chests take the same items.
		require(sea_crossing_item_entry(paddle) && region_travel_worn_valid(sea_crossing_item_entry(paddle)[1], 1), "paddle would not ride a deck")
		var/list/forged = list("t" = "/obj/item/weapon/paddle", "v" = list("loc" = 1))
		require(!region_travel_generic_record("item:[json_encode(forged)]"), "record setting loc accepted")
		forged = list("t" = "/obj/item/weapon/grab")
		require(!region_travel_generic_record("item:[json_encode(forged)]"), "grab record accepted")
		forged = list("t" = "/obj/structure/closet")
		require(!region_travel_generic_record("item:[json_encode(forged)]"), "structure record accepted")
		forged = list("t" = "/obj/item/weapon/paddle", "r" = list(list("not_a_reagent", 5)))
		require(!region_travel_generic_record("item:[json_encode(forged)]"), "unknown reagent accepted")
		pass("whole_items", list("kinds" = kinds, "bytes" = length(json_encode(VP))))
		mark("recipe_knowledge")
		// The rebuild above hands ownership to the rebuilt body; give the
		// sender its own owner again so the knowledge payload can decode.
		H.persistence_owner_ckey = "carryprobeknowledge"
		H.known_recipe_nodes = list("basic_tools", "primitive_construction")
		H.recipe_knowledge_initialized = TRUE
		var/obj/item/weapon/book/node_book/manual = create_node_book(T, "basic_tools")
		require(manual && region_travel_item_kind(manual) == "node:basic_tools", "manual kind missing")
		var/list/book_payload = region_travel_decode(H.region_travel_payload(list("l_hand" = manual)))
		require(book_payload && book_payload["v"] == 2, "knowledge payload not version 2")
		var/mob/living/human/reader = region_travel_build(book_payload, D)
		require(reader.recipe_knowledge_initialized && reader.known_recipe_nodes.len == 2 && ("basic_tools" in reader.known_recipe_nodes), "travel lost character knowledge")
		var/obj/item/weapon/book/node_book/rebuilt_manual = reader.l_hand
		require(istype(rebuilt_manual) && rebuilt_manual.node_id == "basic_tools", "travel lost manual ID")
		H.persistence_owner_ckey = "carryprobescholar"
		H.scholarship = list("engineering" = 30.5, "mathematics" = 15)
		var/list/scholar_payload = region_travel_decode(H.region_travel_payload(list()))
		require(scholar_payload && scholar_payload["v"] == 3, "scholarship payload not version 3")
		var/mob/living/human/scholar = region_travel_build(scholar_payload, D)
		require(scholar.scholar_level("engineering") == 30.5 && scholar.scholar_level("mathematics") == 15 && scholar.known_recipe_nodes.len == 2, "travel lost scholarship")
		scholar_payload["scholarship"] = list("engineering" = 500)
		require(!region_travel_decode(json_encode(scholar_payload)), "out-of-range scholarship accepted")
		H.scholarship = null
		book_payload["v"] = 99
		require(!region_travel_decode(json_encode(book_payload)), "future payload accepted")
		book_payload["v"] = 1
		require(!region_travel_decode(json_encode(book_payload)), "knowledge downgraded to v1")
		book_payload["v"] = 2
		book_payload["known_recipe_nodes"] = list("not_a_real_node")
		require(!region_travel_decode(json_encode(book_payload)), "unknown node accepted")
		book_payload["known_recipe_nodes"] = list("basic_tools", "basic_tools")
		require(!region_travel_decode(json_encode(book_payload)), "duplicate knowledge accepted")
		book_payload["known_recipe_nodes"] = list("basic_tools" = "hidden payload")
		require(!region_travel_decode(json_encode(book_payload)), "associative knowledge accepted")
		book_payload["known_recipe_nodes"] = list()
		book_payload["recipe_knowledge_initialized"] = 2
		require(!region_travel_decode(json_encode(book_payload)), "invalid initialized marker accepted")
		book_payload["recipe_knowledge_initialized"] = FALSE
		require(region_travel_decode(json_encode(book_payload)), "valid empty uninitialized knowledge rejected")
		book_payload["items"] = list()
		book_payload -= "known_recipe_nodes"
		book_payload -= "recipe_knowledge_initialized"
		book_payload["v"] = 1
		var/list/legacy_payload = region_travel_decode(json_encode(book_payload))
		require(legacy_payload, "legacy v1 refused")
		var/mob/living/human/legacy_reader = region_travel_build(legacy_payload, D)
		require(!legacy_reader.recipe_knowledge_initialized && !length(legacy_reader.known_recipe_nodes), "legacy migration marker changed")
		require(!region_travel_item_path("node:not_a_real_node", 1) && !region_travel_item_path("node:basic_tools", 2), "malformed manual admitted")
		pass("recipe_knowledge")

	catch (var/exception/e)
		failure = "[e.name] ([e.file]:[e.line])"
		failed_phase = phase
	var/list/result = list("passed" = isnull(failure), "failure" = failure, "failed_phase" = failed_phase, "checks" = checks, "wall_ds" = world.timeofday - started_tod)
	text2file(json_encode(result), "result.json")
	world.log << (failure ? "FAIL: region carry probe: [failure]" : "PASS: region carry probe")
	sleep(5)
	del(world)
