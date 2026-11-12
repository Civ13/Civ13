// ============================================================
// Freight depots (docs/craft-core.md): the freight board on land
// ------------------------------------------------------------
// A freight depot is the board of a mooring post (freight.dm) set up inland.
// Crates are offered at it for carriage to any other depot or harbour, and
// handed in at it, by the same contracts. It is not a berth: no ship can
// make for it and it is not on the sea chart.
//
// A contract at a depot is taken by the crew of a registered vehicle
// standing within FREIGHT_DEPOT_REACH tiles (craft/vehicle_papers.dm), or of
// a registered ship lying that near. A party claims a depot the way it
// claims a mooring post, and then chooses whether other parties may offer
// contracts there. Anyone may take a contract or hand freight in. The depot's
// own work, surveys and lost cargo, is in depot_jobs.dm.
// ============================================================

#define FREIGHT_DEPOT_REACH 8

/obj/structure/berth/quay/depot
	name = "freight depot"
	desc = "A board where crates are offered for carriage to another depot or harbour, and handed in. Park a registered vehicle within 8 tiles to take a contract. Click it to claim it, name the depot and see the freight."
	icon = 'icons/obj/structures.dmi'
	icon_state = "nboard02"
	berth_length = 0
	berth_beam = 0
	takes_ships = FALSE
	post_word = "freight depot"
	place_word = "depot"

/obj/structure/berth/quay/depot/berth_name()
	return length(harbour) ? harbour : "the freight depot at [x], [y]"

// Never a berth for a ship, even at the water's edge.
/obj/structure/berth/quay/depot/water_side()
	return 0

/obj/structure/berth/quay/depot/refusal(datum/craft/C, forced = FALSE)
	return "a freight depot is not a berth"

// The registered vehicle or ship of this character within reach.
/obj/structure/berth/quay/depot/freight_crew_craft(mob/living/human/H)
	if (!istype(H))
		return null
	for (var/datum/craft/C in vehicle_crafts + crafts)
		if (!C.register || !C.register.party || !C.register.is_crew(H) || !C.body || !C.body.placed())
			continue
		for (var/turf/P in C.body.cells())
			if (P.z == z && get_dist(P, src) <= FREIGHT_DEPOT_REACH)
				return C
	return null

/obj/structure/berth/quay/depot/status_text()
	var/list/lines = list()
	lines += length(harbour) ? "This is [harbour]." : "This freight depot has no name."
	if (!owner_party)
		lines += "Nobody has claimed it: any party may offer freight here."
	else
		lines += "It belongs to [party_train_party_name(owner_party)]: [welcome == BERTH_WELCOME_EVERYONE ? "any party may offer freight here" : "only they may offer freight here"]."
	var/freight = length(contracts(CONTRACT_OPEN))
	lines += freight ? "[freight] freight contract\s on offer." : "No freight is on offer."
	var/work = length(jobs(CONTRACT_OPEN))
	if (work)
		lines += "[work] job\s of the depot's own on offer."
	return jointext(lines, " ")

/obj/structure/berth/quay/depot/attack_hand(mob/living/human/H)
	if (!istype(H))
		return
	var/party = party_train_party_of(H)
	var/list/options = list("Freight")
	// The depot's own paid jobs show only while they are switched on, or
	// while one is still open from before.
	if (npc_jobs_enabled || length(jobs()))
		options += "Depot work"
	if (!owner_party)
		if (party)
			options += "Claim the depot"
	else if (party == owner_party)
		options += list("Name the depot", welcome == BERTH_WELCOME_EVERYONE ? "Take freight from our party only" : "Take freight from every party", "Give up the depot")
	var/choice = WWinput(H, status_text(), name, "Cancel", options + list("Cancel"))
	if (!(choice in options) || QDELETED(src) || get_dist(H, src) > 1)
		return
	if (choice == "Freight")
		freight_menu(H)
		return
	if (choice == "Depot work")
		jobs_menu(H)
		return
	party = party_train_party_of(H)
	if (choice == "Claim the depot")
		if (owner_party || !party)
			return
		owner_party = party
		log_game("[key_name(H)] claimed the freight depot at [x],[y],[z] for [party].")
		visible_message(SPAN_NOTICE("[H] claims the freight depot for [party_train_party_name(party)]."))
		return
	if (!party || party != owner_party)
		return
	switch (choice)
		if ("Name the depot")
			var/new_name = player_input(H, "Name the depot. Freight bound for it carries the name.", name, harbour, "text", null, TRUE)
			if (isnull(new_name) || QDELETED(src) || get_dist(H, src) > 1 || party_train_party_of(H) != owner_party)
				return
			harbour = sanitize(copytext(new_name, 1, 40))
		if ("Take freight from our party only")
			welcome = BERTH_WELCOME_OWNERS
		if ("Take freight from every party")
			welcome = BERTH_WELCOME_EVERYONE
		if ("Give up the depot")
			owner_party = null
			guests = list()
			welcome = BERTH_WELCOME_EVERYONE
			log_game("[key_name(H)] gave up the freight depot at [x],[y],[z].")
			visible_message(SPAN_NOTICE("[H] gives up the freight depot."))
			return
	to_chat(H, SPAN_NOTICE(status_text()))
