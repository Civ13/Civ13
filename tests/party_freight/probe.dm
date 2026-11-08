// Party freight: safe house depots and party trains take goods off the map as
// records in a saved field and rebuild them on recall.
/world
	hub = ""
	hub_password = ""
	maxx = 20
	maxy = 20
	maxz = 1
	turf = /turf
	area = /area
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/party_freight_probe/New()
	return
/mob/living/human/party_freight_probe/New()
	return
var/freight_failures = 0
var/freight_runtime_error = FALSE
/proc/freight_check(condition, label)
	if (!condition)
		freight_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	freight_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/freight_count(atom/A, path)
	. = 0
	for (var/obj/item/I in A)
		if (istype(I, path))
			.++

/proc/freight_amount(atom/A, path)
	. = 0
	for (var/obj/item/stack/S in A)
		if (S.type == path)
			. += S.amount

/proc/freight_checks()
	if (!research_nodes.len)
		build_research_tree()
	freight_check(get_recipe_node_req("/obj/structure/safehouse_depot") == "carts", "Carts research gates the safe house depot (got [get_recipe_node_req("/obj/structure/safehouse_depot")])")
	var/mob/living/human/party_freight_probe/H = new(locate(5, 5, 1))
	H.persistence_owner_ckey = "probeplayer"
	var/party = party_train_party_of(H)
	freight_check(party == "ckey:probeplayer", "a player without a faction is their own party (got [party])")

	// A crate of mixed goods goes to the safe house as one shipment.
	var/obj/structure/safehouse_depot/depot = new(locate(4, 4, 1))
	freight_check("freight" in depot.get_saved_vars(), "the depot's freight is a saved field")
	var/obj/structure/closet/crate/rations/fruits/crate = new(locate(5, 4, 1))
	for (var/obj/item/I in crate.contents.Copy())
		qdel(I)
	new /obj/item/stack/material/wood(crate, 30)
	new /obj/item/stack/material/steel(crate, 12)
	new /obj/item/stack/ore/iron(crate, 7)
	new /obj/item/clothing/shoes/leather(crate)
	new /obj/item/weapon/reagent_containers/food/snacks/hardtack(crate)
	new /obj/item/weapon/crowbar(crate)
	if (crate.opened)
		crate.close()
	freight_check(crate in party_freight_crates(depot), "a closed crate next to the depot can be shipped")

	// Something without a record kind refuses the whole crate and nothing goes.
	var/obj/item/weapon/paper/note = new(crate)
	note.info = "a letter"
	var/refused = party_freight_pack(crate, party, H)
	freight_check(copytext(refused, 1, 2) == "!" && findtext(refused, note.name) && !QDELETED(crate) && crate.contents.len == 7, "a crate holding a letter is refused whole ([refused])")
	qdel(note)

	var/text = party_freight_pack(crate, party, H)
	freight_check(istext(text) && copytext(text, 1, 2) != "!", "the crate is packed ([copytext(text, 1, 60)])")
	freight_check(QDELETED(crate) && !freight_count(locate(5, 4, 1), /obj/item), "the crate and its goods leave the map")
	depot.freight += text
	var/list/shipment = party_freight_shipment(text)
	freight_check(shipment && shipment["party"] == party && shipment["crate"] == "/obj/structure/closet/crate/rations/fruits" && length(shipment["items"]) == 6, "the shipment records the party, the crate and six items")
	var/list/held = safehouse_shipments(party)
	freight_check(held.len == 1 && held[text] == depot, "the safe house lists the shipment")

	// A second depot in the land opens onto the same safe house; others' goods stay hidden.
	var/obj/structure/safehouse_depot/other_depot = new(locate(15, 15, 1))
	var/obj/item/stack/material/wood/outsider_wood = new(null, 5)
	var/outsider_text = party_freight_pack(outsider_wood, "civ:local:Rivals", null)
	other_depot.freight += outsider_text
	freight_check(safehouse_shipments(party).len == 1 && safehouse_shipments("civ:local:Rivals").len == 1, "each party sees only its own shipments in every depot")

	// Tampered records are not rebuilt.
	var/tampered = replacetext(text, "\"amount\":30", "\"amount\":5000")
	freight_check(tampered != text && !party_freight_shipment(tampered), "a record with an impossible stack is refused")

	// The saved field alone rebuilds the shipment in a reloaded depot.
	var/list/saved = depot.freight.Copy()
	qdel(depot)
	var/obj/structure/safehouse_depot/reloaded = new(locate(4, 4, 1))
	reloaded.freight = saved
	reloaded.after_load()
	freight_check(safehouse_shipments(party).len == 1, "a depot rebuilt from its saved field still holds the shipment")
	var/list/built = party_freight_recall(other_depot, reloaded.freight, text, party, H)
	var/turf/feet = get_turf(H)
	var/obj/structure/closet/crate/rations/fruits/back = locate() in feet
	freight_check(istype(back) && !back.opened && built && built.len == 6, "the crate comes back closed beside the player with six items")
	if (istype(back))
		freight_check(freight_amount(back, /obj/item/stack/material/wood) == 30 && freight_amount(back, /obj/item/stack/material/steel) == 12 && freight_amount(back, /obj/item/stack/ore/iron) == 7, "stacks come back with their amounts")
		freight_check(freight_count(back, /obj/item/clothing/shoes/leather) == 1 && freight_count(back, /obj/item/weapon/reagent_containers/food/snacks/hardtack) == 1 && freight_count(back, /obj/item/weapon/crowbar) == 1, "clothing, food and tools come back")
		freight_check(back.contents.len == 6, "a stocked crate kind brings back only the shipped goods ([back.contents.len] items)")
		var/unsaved = 0
		for (var/obj/O in vehicle_storage_objects(back.contents.Copy()))
			if (!O.should_save)
				unsaved++
		freight_check(!unsaved, "every recalled item is saved with the map again")
	freight_check(!safehouse_shipments(party).len && !reloaded.freight.len, "a recalled shipment leaves the safe house")
	freight_check(!party_freight_recall(reloaded, reloaded.freight, text, party, H), "a shipment cannot be recalled twice")
	freight_check(!party_freight_recall(other_depot, other_depot.freight, outsider_text, party, H) && other_depot.freight.len == 1, "a player cannot recall another party's shipment")

	// A held item ships alone; a party train carries its own freight.
	var/obj/structure/region_gate/railway_station/office = new(locate(10, 10, 1))
	freight_check(findtext(office.map_storage_saved_vars, "freight"), "the railway office saves its freight")
	office.party = "civ:local:Haulers"
	var/obj/item/clothing/shoes/leather/boots = new(null)
	var/train_text = party_freight_pack(boots, office.party, null)
	office.freight += train_text
	freight_check(QDELETED(boots) && party_freight_names(office.freight, office.party).len == 1, "boots are loaded onto the train")
	party_train_rename_faction("Haulers", "Freighters")
	freight_check(office.party == "civ:local:Freighters" && party_freight_names(office.freight, "civ:local:Freighters").len == 1 && !party_freight_names(office.freight, "civ:local:Haulers").len, "a renamed faction keeps its train freight")
	party_freight_rename("civ:local:Rivals", "civ:local:Others")
	freight_check(safehouse_shipments("civ:local:Others").len == 1, "a renamed faction keeps its safe house")

/proc/freight_run()
	try
		freight_checks()
	catch(var/exception/e)
		freight_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = freight_failures, "runtime_error" = freight_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/party_freight_probe
		freight_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		freight_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		freight_run()
