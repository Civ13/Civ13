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
	var/survey = built_hull_survey(T, craft)
	if (istext(survey))
		return survey
	var/datum/craft_body/built/B = body()
	if (!B)
		B = new /datum/craft_body/built
		craft = new /datum/craft(B)
	if (B.placed())
		B.set_afloat(FALSE)
	B.adopt(survey, T, heading || B.dir)
	if (hull_name)
		B.hull_name = hull_name
		craft.name = hull_name
	return null

// Strikes the hull: the floors stay where they are, nothing sails.
/obj/structure/hull_tiller/proc/decommission()
	if (!craft)
		return
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
	if (register_state)
		craft.register = craft_register_restore(register_state)
	if (isnum(state["speed"]) && state["speed"] > 0)
		craft.set_speed(state["speed"])

/obj/structure/hull_tiller/proc/status_text()
	if (!craft)
		return "The tiller is not commissioned. It must stand on a floor built over water, with the hull free of the shore."
	var/datum/craft_body/built/B = craft.body
	var/list/speeds = list("all stop", "slow ahead", "half ahead", "full ahead")
	return "[capitalize(craft.name)]: [B.tile_count()] tiles of hull, [speeds[craft.speed + 1]], bow to the [dir2text(B.dir)], anchor [craft.anchored ? "down" : "up"]."

/obj/structure/hull_tiller/examine(mob/user)
	..()
	to_chat(user, status_text())

/obj/structure/hull_tiller/attack_hand(mob/living/human/H)
	if (!istype(H))
		return ..()
	if (!craft)
		commission_menu(H)
		return
	var/list/options = list("Ship's papers", "Slow ahead", "All stop", "Head north", "Head east", "Head south", "Head west", craft.anchored ? "Weigh anchor" : "Drop anchor", "Refit the hull", "Strike the hull", "Cancel")
	var/choice = WWinput(H, status_text(), name, "Cancel", options)
	if (!choice || choice == "Cancel" || !craft || get_dist(H, src) > 1)
		return
	if (choice == "Ship's papers")
		craft.papers(H, src)
		return
	// A registered hull answers to her crew (ship_papers.dm).
	switch (craft.helm_access(H))
		if (CRAFT_HELM_CHAINED)
			to_chat(H, SPAN_WARNING("The tiller is chained. The [craft.name] is registered and none of her owners are about."))
			return
		if (CRAFT_HELM_FORCE)
			if (!craft.force_helm(H, src) || !craft)
				return
	switch (choice)
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
			var/problem = commission()
			if (problem)
				to_chat(H, SPAN_WARNING(problem))
				return
			to_chat(H, SPAN_NOTICE("The hull is surveyed again. [status_text()]"))
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
