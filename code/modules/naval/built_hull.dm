// ============================================================
// Player-built hulls (docs/craft-core.md): the tiller
// ------------------------------------------------------------
// Lay floors over water in any shape, free of the shore, set a tiller on one
// of them and commission the hull: every floor joined to the tiller's tile
// becomes one craft with a built body (craft/built_body.dm). She then sails
// like any ship: the tiller rings a speed, weighs the anchor, comes about and
// keeps the ship's papers. What is built aboard later rides along; "Refit"
// surveys the hull again after planks were added or cut away.
//
// The tiller saves the hull as offsets from its own tile, so a loaded world
// finds the hull again around the tiller wherever it lay.
// ============================================================

/obj/structure/hull_tiller
	name = "tiller"
	desc = "A tiller on its post, with a rudder under the planks. Set it on a floor built over water and commission the hull to sail her."
	icon = 'icons/obj/vehicles/vehicleparts_boats.dmi'
	icon_state = "ship_wheel"
	anchored = TRUE
	density = TRUE
	not_movable = TRUE
	var/tmp/datum/craft/craft
	// Saved: the hull (json of body_state() with telegraph and anchor) and
	// the crew register, as text.
	var/hull_state = ""
	var/register_state = ""

/obj/structure/hull_tiller/Destroy()
	if (craft)
		var/datum/craft/C = craft
		craft = null
		C.crew_message(SPAN_WARNING("The tiller is gone: the [C.name] is a hull without a helm."))
		var/datum/craft_body/built/B = C.body
		if (istype(B))
			B.set_afloat(FALSE)
		qdel(C.body)
		qdel(C)
	return ..()

/obj/structure/hull_tiller/proc/body()
	return craft ? craft.body : null

// Surveys the floors around the tiller and makes (or remakes) the craft.
// Returns null when done, else the reason.
/obj/structure/hull_tiller/proc/commission(hull_name = null, heading = null)
	var/turf/T = get_turf(src)
	// A refit would survey a holed tile out of her hull: patch her first.
	// At a berth a floor lifted for a refit is meant to go (berth_refit.dm).
	if (craft && craft.ledger && craft.ledger.holes > 0 && !craft_berth(craft))
		return "Patch the [craft.ledger.holes == 1 ? "hole" : "holes"] in her hull before she is surveyed again."
	var/survey = built_hull_survey(T, craft)
	if (istext(survey))
		return survey
	var/datum/craft_body/built/B = body()
	// A berth may ask more of her (berth_build.dm).
	var/obj/structure/berth = istype(T, /turf/floor/beach/water) ? null : berth_ground_at(T)
	var/berth_why = berth ? berth.berth_commission_refusal(survey, heading || (B ? B.dir : NORTH)) : null
	if (berth_why)
		return berth_why
	if (!B)
		B = new /datum/craft_body/built
		craft = new /datum/craft(B)
	if (B.placed())
		B.set_afloat(FALSE)
	B.adopt(survey, T, heading || B.dir)
	if (hull_name)
		B.hull_name = hull_name
		craft.name = hull_name
	// Her condition afloat: bilge water and what follows (hull_ledger.dm).
	craft.fit_ledger()
	return null

// Strikes the hull: the floors stay where they are, nothing sails.
/obj/structure/hull_tiller/proc/decommission()
	if (!craft)
		return
	end_voyage(null) // A struck or stripped hull is on no voyage, and shows no sea.
	var/datum/craft/C = craft
	craft = null
	var/datum/craft_body/built/B = C.body
	if (istype(B))
		B.set_afloat(FALSE)
	qdel(C.body)
	qdel(C)

/obj/structure/hull_tiller/before_save()
	..()
	var/datum/craft_body/built/B = body()
	if (!B || !B.placed())
		hull_state = ""
		register_state = ""
		return
	var/list/state = B.body_state()
	state["speed"] = craft.speed
	state["anchored"] = craft.anchored
	// Her place and motion on the open sea chart (open_sea_chart.dm).
	var/list/passage = craft.open_sea_state()
	if (passage)
		state["sea"] = passage
	if (craft.ledger)
		state["ledger"] = craft.ledger.to_list()
	hull_state = json_encode(state)
	register_state = (craft.register && craft.register.party) ? craft.register.register_state() : ""

/obj/structure/hull_tiller/after_load()
	..()
	if (craft || !hull_state)
		return
	var/list/state = null
	try
		state = json_decode(hull_state)
	catch
		return
	var/datum/craft_body/built/B = new
	if (!B.restore_state(state, get_turf(src)))
		qdel(B)
		return
	craft = new /datum/craft(B)
	craft.anchored = state["anchored"] ? TRUE : FALSE
	// A record with no ledger is from before there were any: an empty one
	// still tells her she is an old hull (hull_anchors.dm).
	craft.fit_ledger(islist(state["ledger"]) ? state["ledger"] : list())
	if (register_state)
		craft.register = craft_register_restore(register_state)
	if (isnum(state["speed"]) && state["speed"] > 0)
		craft.set_speed(state["speed"])
	if (islist(state["sea"]) && open_sea_world())
		craft.open_sea_restore(state["sea"])

/obj/structure/hull_tiller/proc/status_text()
	if (!craft)
		return "The tiller is not commissioned. It must stand on a floor built over water, with the hull free of the shore."
	var/datum/craft_body/built/B = craft.body
	var/list/speeds = list("all stop", "slow ahead", "half ahead", "full ahead")
	var/upper = B.upper_tile_count()
	var/hold = B.lower_tile_count()
	var/top = upper ? B.top_tile_count() : 0
	var/list/open = open_sides()
	var/open_text = open.len ? " [open.len] side\s of her deck are open: rail them before she can be refitted." : ""
	return "[capitalize(craft.name)]: [B.tile_count()] tiles of hull[upper ? "[hold ? "," : " and"] [upper] of upper deck[top ? " with [top] of second deck above" : ""]" : ""][hold ? " and [hold] of hold" : ""], [speeds[craft.speed + 1]], bow to the [dir2text(B.dir)], anchor [craft.anchored ? "down" : "up"][craft.running_dark ? ", running dark" : ""][craft.grapple ? ", held by grappling lines" : ""]. [craft.drives_text()] [craft.magnetic_text()][craft.ledger ? " [craft.ledger.status_text()]" : ""][open_text]"

/obj/structure/hull_tiller/examine(mob/user)
	..()
	to_chat(user, status_text())

/obj/structure/hull_tiller/attack_hand(mob/living/human/H)
	if (!istype(H))
		return ..()
	if (!craft)
		// A spare tiller or steering oar on a commissioned deck: only the one
		// she was commissioned with steers her, so point the way to it.
		var/datum/craft/aboard = craft_at(get_turf(src))
		var/datum/craft_body/built/deck = aboard ? aboard.body : null
		if (istype(deck) && deck.placed())
			var/turf/helm = locate(deck.px, deck.py, deck.z)
			to_chat(H, SPAN_WARNING("This [name] does not steer the [aboard.name]. Her helm is the tiller or steering oar [get_dist(H, helm)] tile\s to the [dir2text(get_dir(H, helm))] of you: use that one to steer her or set out on a voyage."))
			return
		commission_menu(H)
		return
	craft.fit_drives()
	// At sea on the world chart (ship_voyage.dm), or bound for a land woken for
	// her (ship_crossing.dm): nobody steers until she is back, ashore or gone.
	if (voyage || crossing_hold_current())
		voyage_status_menu(H)
		return
	var/list/options = list("Sea chart", "Ship's papers", "Draw her lines", "Hail a ship", "Make for a berth")
	// Open sides on her deck (hull_sides.dm).
	if (length(open_sides()))
		options += "Rail her sides"
	// Who stands at which station (hull_watch.dm).
	if (craft.ledger)
		options.Insert(4, "Muster the watch")
	if (open_sea_world())
		options.Insert(2, "Open sea chart")
	// Off the edge of the map she can cross to a land across the sea (ship_crossing.dm).
	var/datum/craft_body/built/edge_body = craft.body
	if (istype(edge_body) && edge_body.at_map_edge() && !sea_edge_travel_on() && length(sea_crossing_destinations()))
		options.Insert(2, "Leave these waters")
	// Off a linked edge of the earth group she sails on over it (ship_edge_crossing.dm).
	if (istype(edge_body) && edge_body.at_map_edge() && edge_body.sea_edge_link())
		options.Insert(2, "Sail over the horizon")
	// Off a mainland's edge she can set out across the world chart (ship_voyage.dm).
	if (istype(edge_body) && edge_body.at_map_edge() && shard_group && shard_group.enabled)
		options.Insert(2, "Set out on a voyage")
	// A land across the sea nobody has settled yet (land_choices.dm).
	if (expedition_land_unsettled())
		options.Insert(2, "Settle this land")
	// Every player may claim one land across the sea as their own (land_choices.dm).
	var/own_claim = expedition_personal_claim_option(expedition_personal_claimant(H))
	if (own_claim)
		options.Insert(2, own_claim)
	// A refit to a draught at a berth (berth_refit.dm).
	options += refit_options(H)
	var/best = craft.max_speed()
	if (best >= VESSEL_SPEED_FULL)
		options += "Full ahead"
	if (best >= VESSEL_SPEED_HALF)
		options += "Half ahead"
	options += list("Slow ahead", "All stop", "Head north", "Head east", "Head south", "Head west", craft.anchored ? "Weigh anchor" : "Drop anchor", craft.running_dark ? "Show her lights" : "Run dark", craft.grapple ? (craft.grapple.thrower == craft ? "Cast off the grapple" : "Cut the grapple") : "Grapple a ship", "Refit the hull", "Strike the hull", "Cancel")
	var/choice = WWinput(H, status_text(), name, "Cancel", options)
	if (!choice || choice == "Cancel" || !craft || get_dist(H, src) > 1)
		return
	if (choice in list("Make for a berth", "Full ahead", "Half ahead", "Slow ahead", "Head north", "Head east", "Head south", "Head west", "Leave these waters", "Sail over the horizon", "Set out on a voyage", "Refit the hull"))
		var/plank = craft.gangplank_refusal()
		if (plank)
			to_chat(H, SPAN_WARNING(plank))
			return
	if (choice == "Sea chart")
		to_chat(H, craft.sea_chart_text())
		return
	if (choice == "Open sea chart")
		craft.open_sea_menu(H, src)
		return
	if (choice == "Ship's papers")
		craft.papers(H, src)
		return
	if (choice == "Hail a ship")
		craft.hail_menu(H, src)
		return
	if (choice == "Muster the watch")
		if (craft.ledger)
			to_chat(H, SPAN_NOTICE(craft.ledger.muster_text()))
		return
	// A registered hull answers to her crew (ship_papers.dm).
	switch (craft.helm_access(H))
		if (CRAFT_HELM_CHAINED)
			to_chat(H, SPAN_WARNING("The tiller is chained. The [craft.name] is registered and none of her owners are about."))
			return
		if (CRAFT_HELM_FORCE)
			if (!craft.force_helm(H, src) || !craft)
				return
	if (choice == "Draw her lines")
		draw_lines(H)
		return
	if (refit_action(H, choice))
		return
	if (choice == "Rail her sides")
		rail_sides(H)
		return
	if (choice == "Leave these waters")
		crossing_menu(H)
		return
	if (choice == "Set out on a voyage")
		voyage_menu(H)
		return
	if (choice == "Sail over the horizon")
		sea_edge_menu(H)
		return
	if (choice == "Settle this land")
		settle_menu(H)
		return
	if (choice == "Claim this land" || choice == "Give up your claim")
		personal_claim_menu(H)
		return
	if (choice == "Make for a berth")
		if (craft.grapple)
			to_chat(H, SPAN_WARNING(craft.grapple_refusal()))
			return
		craft.dock_menu(H, src)
		return
	if (choice == "Run dark" || choice == "Show her lights")
		craft.dark_menu(H, src, choice == "Run dark")
		return
	if (choice == "Grapple a ship" || choice == "Cast off the grapple" || choice == "Cut the grapple")
		craft.grapple_menu(H, src)
		return
	if (craft.grapple && (choice in list("Make for a berth", "Full ahead", "Half ahead", "Slow ahead", "Head north", "Head east", "Head south", "Head west", "Refit the hull")))
		to_chat(H, SPAN_WARNING(craft.grapple_refusal()))
		return
	switch (choice)
		if ("Full ahead") craft.set_speed(VESSEL_SPEED_FULL)
		if ("Half ahead") craft.set_speed(VESSEL_SPEED_HALF)
		if ("Slow ahead") craft.set_speed(VESSEL_SPEED_SLOW)
		if ("All stop") craft.set_speed(VESSEL_SPEED_STOP)
		if ("Weigh anchor") craft.set_anchor(FALSE)
		if ("Drop anchor") craft.set_anchor(TRUE)
		if ("Head north", "Head east", "Head south", "Head west")
			var/heading = text2dir(copytext(choice, 6))
			if (craft.anchored)
				to_chat(H, SPAN_WARNING("Weigh anchor before coming about."))
				return
			if (!craft.order_turn(heading))
				to_chat(H, SPAN_WARNING("She cannot come about here: [craft.last_refusal]."))
				return
			if (craft.turning_to)
				craft.crew_message(SPAN_NOTICE("[H] at the tiller: coming about to the [dir2text(heading)]. Stand clear of the marked water."))
			return
		if ("Refit the hull")
			if (!craft.anchored)
				to_chat(H, SPAN_WARNING("Drop anchor before refitting."))
				return
			var/list/refit_survey = built_hull_survey(get_turf(src), craft)
			var/sides = istext(refit_survey) ? null : hull_sides_refusal(refit_survey)
			if (sides)
				to_chat(H, SPAN_WARNING(sides))
				return
			var/problem = commission()
			if (problem)
				to_chat(H, SPAN_WARNING(problem))
				return
			to_chat(H, SPAN_NOTICE("The hull is surveyed again. [status_text()]"))
			if (refit_code)
				report_refit(H, mark_refit(), FALSE)
			return
		if ("Strike the hull")
			if (WWinput(H, "Strike the [craft.name]? Her floors stay where they are, but she is no longer a ship and her papers are lost.", name, "No", list("Yes", "No")) != "Yes" || !craft || get_dist(H, src) > 1)
				return
			log_game("[key_name(H)] struck the built hull [craft.name] at [x],[y],[z].")
			craft.crew_message(SPAN_NOTICE("[H] strikes the [craft.name]. She is a raft of planks again."))
			decommission()
			return
	craft.crew_message(SPAN_NOTICE("[H] at the tiller: [choice]. [status_text()]"))

/obj/structure/hull_tiller/proc/commission_menu(mob/living/human/H)
	var/survey = built_hull_survey(get_turf(src))
	if (istext(survey))
		to_chat(H, SPAN_WARNING(survey))
		return
	var/list/found = survey
	var/sides = hull_sides_refusal(found)
	if (sides)
		if (WWinput(H, sides, name, "Cancel", list("Rail her sides", "Cancel")) == "Rail her sides" && !craft && get_dist(H, src) <= 1)
			rail_sides(H)
		return
	var/list/headings = list("Bow to the north" = NORTH, "Bow to the east" = EAST, "Bow to the south" = SOUTH, "Bow to the west" = WEST)
	var/choice = WWinput(H, "The hull around this tiller is [found.len] tiles of floor. Commission her? Choose where her bow points.", name, "Cancel", headings + list("Cancel"))
	if (isnull(headings[choice]) || craft || get_dist(H, src) > 1)
		return
	var/hull_name = player_input(H, "Name her.", name, "hull", "text", null, TRUE)
	if (isnull(hull_name) || craft || get_dist(H, src) > 1)
		return
	hull_name = sanitize(copytext(hull_name, 1, 40))
	if (!length(hull_name))
		hull_name = "hull"
	var/problem = commission(hull_name, headings[choice])
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return
	log_game("[key_name(H)] commissioned the built hull [hull_name] ([found.len] tiles) at [x],[y],[z].")
	visible_message(SPAN_NOTICE("[H] commissions the [hull_name]. She lies at anchor."))
