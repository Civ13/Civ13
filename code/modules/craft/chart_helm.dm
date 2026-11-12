// The helm console of a steered chart (docs/craft-core.md): reads the chart
// and steers the token of the craft it stands on by heading and burn, with a
// stop order and a course laid for a contact.
//
// This is the shared base. It has no recipe and is never placed as it is: a
// subtype says which chart it steers on (chart()), and the craft types that
// carry one come with the phases that use them. It saves where its token is
// and how it moves as plain numbers and puts it back after a load.

/obj/structure/chart_helm
	name = "helm console"
	desc = "A chart table and engine controls."
	icon = 'icons/obj/computers.dmi'
	icon_state = "terminal"
	anchored = TRUE
	density = TRUE
	not_movable = TRUE
	not_disassemblable = TRUE
	var/tmp/datum/chart_token/token
	// Saved: the token's place and speed.
	var/chart_x = 0
	var/chart_y = 0
	var/chart_vx = 0
	var/chart_vy = 0

/obj/structure/chart_helm/Destroy()
	if (token)
		qdel(token)
		token = null
	return ..()

// The chart this console steers on. The base console has none.
/obj/structure/chart_helm/proc/chart()
	return null

/obj/structure/chart_helm/proc/helm_craft()
	return craft_at(get_turf(src))

// The token this console steers, put on its chart the first time it is asked
// for: at the saved place, or the middle of the chart.
/obj/structure/chart_helm/proc/helm_token()
	var/datum/chart/C = chart()
	if (!C)
		return null
	if (token && token.chart == C)
		return token
	if (!token)
		token = new /datum/chart_token
	var/datum/craft/mine = helm_craft()
	if (mine)
		token.craft = mine
		token.name = mine.name
		mine.token = token
	else
		token.name = name
	if (!C.add_token(token, C.in_bounds(chart_x, chart_y) ? chart_x : round(C.width / 2), C.in_bounds(chart_x, chart_y) ? chart_y : round(C.height / 2)))
		return null
	token.vx = chart_vx
	token.vy = chart_vy
	if (token.vx || token.vy)
		C.wake()
	return token

/obj/structure/chart_helm/before_save()
	..()
	if (!token || !token.chart)
		return
	chart_x = token.x
	chart_y = token.y
	chart_vx = token.vx
	chart_vy = token.vy

/obj/structure/chart_helm/after_load()
	..()
	helm_token()

// The chart as the console shows it: her place and motion, then every
// contact her sensors make out with its distance and bearing.
/obj/structure/chart_helm/proc/read_text()
	var/datum/chart_token/T = helm_token()
	if (!T)
		return "The console shows no chart."
	var/datum/chart/C = T.chart
	var/list/lines = list("<b>[capitalize(C.name)]:</b> [T.name] at [round(T.x, 0.1)], [round(T.y, 0.1)], [T.motion_text()].")
	var/muddy = C.interference_at(T.x, T.y)
	if (muddy)
		lines += "Interference here cuts her sensors to [max(0, T.sensor_range - muddy)] squares."
	var/list/seen = C.contacts_of(T)
	if (!seen.len)
		lines += "No contacts."
	for (var/datum/chart_token/O in seen)
		lines += "[capitalize(O.contact_name())]: [round(chart_distance(T.x, T.y, O.x, O.y), 0.1)] squares [chart_bearing_name(chart_bearing(T.x, T.y, O.x, O.y))][O.speed() > 0 ? ", moving" : ""]."
	return jointext(lines, "<br>")

/obj/structure/chart_helm/examine(mob/user)
	..()
	to_chat(user, read_text())

/obj/structure/chart_helm/attack_hand(mob/living/human/H)
	if (!istype(H))
		return ..()
	var/datum/chart_token/T = helm_token()
	if (!T)
		to_chat(H, "The console shows no chart.")
		return
	var/choice = WWinput(H, read_text(), name, "Cancel", list("Read the chart", "Burn", "Cut the engines", "Full stop", "Lay a course", "Cancel"))
	if (!choice || choice == "Cancel" || QDELETED(src) || get_dist(H, src) > 1 || !token)
		return
	if (choice == "Read the chart")
		to_chat(H, read_text())
		return
	// A registered craft answers to her crew (naval/ship_papers.dm).
	var/datum/craft/mine = T.craft
	if (mine)
		switch (mine.helm_access(H))
			if (CRAFT_HELM_CHAINED)
				to_chat(H, SPAN_WARNING("The console is locked. The [mine.name] is registered and none of her owners are about."))
				return
			if (CRAFT_HELM_FORCE)
				if (!mine.force_helm(H, src) || QDELETED(src) || !token)
					return
	switch (choice)
		if ("Burn")
			var/list/points = list("North" = 0, "Northeast" = 45, "East" = 90, "Southeast" = 135, "South" = 180, "Southwest" = 225, "West" = 270, "Northwest" = 315)
			var/point = WWinput(H, "Burn along which heading?", name, "Cancel", points + list("Cancel"))
			if (isnull(points[point]) || QDELETED(src) || get_dist(H, src) > 1 || !token)
				return
			var/list/burns = list("Full burn" = 1, "Half burn" = 0.5, "Quarter burn" = 0.25)
			var/burn = WWinput(H, "How hard?", name, "Cancel", burns + list("Cancel"))
			if (isnull(burns[burn]) || QDELETED(src) || get_dist(H, src) > 1 || !token)
				return
			T.set_burn(points[point], burns[burn])
		if ("Cut the engines")
			T.set_burn(T.heading, 0)
		if ("Full stop")
			T.order_stop()
		if ("Lay a course")
			var/list/places = list()
			for (var/datum/chart_token/O in T.chart.contacts_of(T))
				places["[capitalize(O.contact_name())], [round(chart_distance(T.x, T.y, O.x, O.y), 0.1)] squares [chart_bearing_name(chart_bearing(T.x, T.y, O.x, O.y))]"] = O
			if (!places.len)
				to_chat(H, SPAN_WARNING("There is no contact to lay a course for."))
				return
			var/place = WWinput(H, "Lay a course for which contact? She makes for it and stops there.", name, "Cancel", places + list("Cancel"))
			var/datum/chart_token/O = places[place]
			if (!istype(O) || QDELETED(O) || QDELETED(src) || get_dist(H, src) > 1 || !token)
				return
			T.lay_course(O.x, O.y, O.contact_name())
	if (mine)
		mine.crew_message(SPAN_NOTICE("[H] at the [name]: [choice]. She is [T.motion_text()]."))
	else
		to_chat(H, SPAN_NOTICE("She is [T.motion_text()]."))
