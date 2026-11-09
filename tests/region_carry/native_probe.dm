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
		var/list/items = list("l_hand" = mag, "r_hand" = gun, "l_store" = pack, "r_store" = cola, "head" = helmet, "belt" = crowbar, "s_store" = cracker)
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
