// ============================================================
// The sea chart and harbours (docs/craft-core.md)
// ------------------------------------------------------------
// Every sea level has one mirror chart (craft/chart.dm): a grid of squares
// SEA_CHART_SQUARE tiles across whose tokens follow the real ships and the
// harbours of that level. Nothing ticks: the chart is brought up to date
// whenever somebody reads it.
//
// A harbour is a mooring post (/obj/structure/berth/quay): a berth on the
// shore with an owner and a rule for who is welcome. A ship within
// QUAY_DOCK_RANGE asks for it from her helm; the post answers with a ticket,
// the water she will lie in is marked for QUAY_DOCK_WARNING, and she then
// slides in alongside, is made fast and lies moored until she next moves.
//
// A mooring is not saved: after a restart a ship lies at anchor beside the
// post, and making for it again moors her.
// ============================================================

#define SEA_CHART_SQUARE 10
#define QUAY_DOCK_RANGE 20
#define QUAY_DOCK_WARNING 100
#define QUAY_BERTH_LENGTH 40
#define QUAY_BERTH_BEAM 12

var/global/list/sea_charts = list()      // "[z]" = /datum/chart/sea
var/global/list/sea_harbours = list()    // /obj/structure/berth/quay

// ---------------------------------------------------------------- the chart

/datum/chart/sea
	name = "sea chart"
	mode = CHART_MODE_MIRROR
	var/z = 0

/datum/chart/sea/New(new_z)
	..()
	z = new_z
	width = max(1, -round(-world.maxx / SEA_CHART_SQUARE))
	height = max(1, -round(-world.maxy / SEA_CHART_SQUARE))
	sea_charts["[z]"] = src

/datum/chart/sea/Destroy()
	if (sea_charts["[z]"] == src)
		sea_charts -= "[z]"
	return ..()

// The chart of a level, made the first time it is asked for.
/proc/sea_chart(z)
	if (!isnum(z) || z < 1 || z > world.maxz)
		return null
	return sea_charts["[z]"] || new /datum/chart/sea(z)

/datum/chart/sea/chart_position(turf/T)
	if (!T || T.z != z)
		return null
	return list(-round(-T.x / SEA_CHART_SQUARE), -round(-T.y / SEA_CHART_SQUARE))

// A square as a navigator says it: letters across, numbers up ("C4").
/datum/chart/proc/square_name(x, y)
	var/letters = ""
	var/n = max(1, round(x))
	while (n > 0)
		letters = ascii2text(65 + ((n - 1) % 26)) + letters
		n = round((n - 1) / 26)
	return "[letters][max(1, round(y))]"

// Where on the real map a token is, or null.
/datum/chart_token/proc/place()
	return craft ? craft.centre() : null

/datum/chart_token/harbour
	kind = "harbour"
	var/obj/structure/berth/quay/quay

/datum/chart_token/harbour/place()
	return (quay && !QDELETED(quay)) ? get_turf(quay) : null

/datum/chart_token/harbour/Destroy()
	if (quay && quay.token == src)
		quay.token = null
	quay = null
	return ..()

// Brings the chart up to date: drops what has gone, adds what has come and
// moves every token to where its ship or harbour really is.
/datum/chart/sea/proc/refresh()
	crafts_prune()
	for (var/datum/chart_token/T in tokens.Copy())
		var/turf/P = T.place()
		if (!P || P.z != z)
			qdel(T)
	for (var/datum/craft/C in crafts)
		var/turf/P = C.centre()
		if (!P || P.z != z)
			continue
		if (!C.token)
			C.token = new /datum/chart_token
			C.token.craft = C
		C.token.name = C.name
		C.token.dark = C.running_dark
		var/list/at = chart_position(P)
		add_token(C.token, at[1], at[2])
	for (var/obj/structure/berth/quay/Q in sea_harbours)
		var/turf/P = get_turf(Q)
		if (QDELETED(Q) || !P || P.z != z || !Q.takes_ships)
			continue
		if (!Q.token)
			Q.token = new /datum/chart_token/harbour
			Q.token.quay = Q
		Q.token.name = Q.berth_name()
		var/list/at = chart_position(P)
		add_token(Q.token, at[1], at[2])
	return tokens.len

// ---------------------------------------------------------------- crafts

/datum/craft
	// list(x, y, heading) while she slides into a berth.
	var/tmp/list/docking = null

// The middle tile of her box on her main level, or null.
/datum/craft/proc/centre()
	if (!body || !body.placed())
		return null
	var/turf/O = body.origin()
	if (!O)
		return null
	var/along = body.length_tiles()
	var/across = body.beam_tiles()
	var/sideways = body.heading() & (EAST | WEST)
	return locate(O.x + round(((sideways ? along : across) - 1) / 2), O.y + round(((sideways ? across : along) - 1) / 2), O.z)

// TRUE while she is under way, whichever body she has.
/datum/craft/proc/making_way()
	var/datum/craft_body/template/B = body
	if (istype(B))
		return B.vessel && B.vessel.speed > 0 && !B.vessel.anchored
	return speed > 0 && !anchored

// The sea chart read at her helm: where she is, the ships her lookout can
// see and every harbour on this sea with whether it would take her.
/datum/craft/proc/sea_chart_text()
	var/turf/here = centre()
	var/datum/chart/sea/S = here ? sea_chart(here.z) : null
	if (!S)
		return "She is not afloat."
	S.refresh()
	if (!token || token.chart != S)
		return "She is not on this chart."
	var/list/lines = list("<b>Sea chart:</b> the [name] lies in square [S.square_name(token.x, token.y)] ([here.x], [here.y])[berth ? ", moored at [berth.berth_name()]" : ""][running_dark ? ". She runs dark" : ""][grapple ? ". Grappling lines hold her" : ""].")
	var/list/ships = list()
	var/list/harbours = list()
	for (var/datum/chart_token/T in S.tokens)
		if (T == token)
			continue
		var/turf/P = T.place()
		if (!P || !sea_same_waters(here, P))
			continue
		var/where = "[get_dist(here, P)] tile\s [submarine_bearing(here, P)], square [S.square_name(T.x, T.y)]"
		var/datum/chart_token/harbour/HT = T
		if (istype(HT))
			var/why = HT.quay.refusal(src)
			var/freight = length(HT.quay.contracts(CONTRACT_OPEN))
			harbours += "[T.name], [where]: [why ? why : "she may berth here"].[freight ? " [freight] freight contract\s on offer." : ""]"
			continue
		var/datum/craft/C = T.craft
		if (C ? !sights(C) : (get_dist(here, P) > lookout_range()))
			continue
		if (!C || !knows(C))
			ships += "[T.contact_name()], [where]."
			continue
		ships += "[C.name], [where][C.running_dark ? ", running dark" : ""], bow to the [dir2text(C.body.heading())], [C.berth ? "moored at [C.berth.berth_name()]" : (C.making_way() ? "under way" : "stopped")]."
	var/murk = sea_murk_name(here)
	var/sees = lookout_range()
	if (murk)
		lines += "In [murk] her lookout sees [sees] tile\s."
	lines += ships.len ? "Lookout, [sees] tiles:" : "Lookout: no other ship within [sees] tiles."
	lines += ships
	// Modular boats and aircraft: the lines the carrier's radar shows, as
	// far as her lookout sees.
	var/list/small = sea_boat_contacts(here, sees, party()) + sea_aircraft_contacts(here, sees, party())
	if (small.len)
		lines += "Boats and aircraft in sight:"
		lines += small
	lines += harbours.len ? "Harbours on this sea:" : "No harbour is charted on this sea."
	lines += harbours
	return jointext(lines, "<br>")

// ---------------------------------------------------------------- small contacts

// What a modular boat or aircraft is called by a viewer of this party: the
// name in its papers when it has one (craft/vehicle_papers.dm), marked as
// ours when it is registered to the viewer's party.
/proc/sea_contact_name(obj/structure/vehicleparts/axis/A, party = null)
	var/datum/craft/vehicle/C = A.craft
	if (!C || QDELETED(C) || !C.register || !C.register.party)
		return A.name
	return (party && C.register.party == party) ? "[C.name] (ours)" : C.name

// Modular boats within reach of a tile of a sea level, one line each. The
// sea chart and the carrier's radar both read these.
/proc/sea_boat_contacts(turf/surface, reach, party = null)
	. = list()
	if (!surface)
		return
	for (var/obj/structure/vehicleparts/axis/ship/S in ship_axes)
		var/turf/T = get_turf(S)
		if (!T || T.z != surface.z || get_dist(T, surface) > reach)
			continue
		. += "Ship: [sea_contact_name(S, party)], [get_dist(T, surface)] tiles [submarine_bearing(surface, T)], heading [dir2text(S.dir)][S.moving ? "" : ", stopped"]."

// Aircraft flying over that level within reach, one line each.
/proc/sea_aircraft_contacts(turf/surface, reach, party = null)
	. = list()
	if (!surface)
		return
	for (var/obj/structure/vehicleparts/axis/aircraft/A in airborne_aircraft)
		var/turf/T = get_turf(A)
		if (!T || multiz_level_below(T.z) != surface.z)
			continue
		var/turf/below = locate(T.x, T.y, surface.z)
		if (!below || get_dist(below, surface) > reach)
			continue
		. += "Aircraft: [sea_contact_name(A, party)], [get_dist(below, surface)] tiles [submarine_bearing(surface, below)], heading [dir2text(A.dir)][A.flight_state == AIRCRAFT_CRUISE ? ", high" : ", low"]."

// Stops her hopping while she slides into a berth, and lets her go again.
/datum/craft_body/proc/hold(heading)
	if (craft)
		craft.turning_to = heading

/datum/craft_body/template/hold(heading)
	..()
	if (vessel)
		vessel.turning_to = heading

// All stop and anchor down.
/datum/craft_body/proc/make_fast()
	if (craft)
		craft.set_speed(VESSEL_SPEED_STOP)
		craft.set_anchor(TRUE)

/datum/craft_body/template/make_fast()
	if (vessel)
		vessel.set_speed(VESSEL_SPEED_STOP)
		vessel.set_anchor(TRUE)

// Asks a mooring post for its berth. TRUE when she has it and is sliding in;
// FALSE with last_refusal set when she cannot.
/datum/craft/proc/order_dock(obj/structure/berth/quay/Q, forced = FALSE)
	var/turf/here = centre()
	if (!here)
		last_refusal = "she is not afloat"
		return FALSE
	if (turning_to || docking)
		last_refusal = "she is already coming about"
		return FALSE
	if (!istype(Q) || QDELETED(Q) || Q.z != here.z || get_dist(here, Q) > QUAY_DOCK_RANGE)
		last_refusal = "the berth is more than [QUAY_DOCK_RANGE] tiles off"
		return FALSE
	if (berth == Q)
		last_refusal = "she already lies there"
		return FALSE
	var/datum/berth_ticket/T = Q.request(src, forced)
	if (T.refusal)
		last_refusal = T.refusal
		return FALSE
	var/list/chosen = null
	var/why = "there is no open water beside the post"
	for (var/list/plan in Q.berth_plans(src))
		if (body.can_move_to(plan[1], plan[2], plan[3]))
			chosen = plan
			break
		why = body.last_refusal
	if (!chosen)
		T.release()
		last_refusal = "the berth is foul: [why]"
		return FALSE
	mark_path(chosen[1], chosen[2], chosen[3])
	docking = chosen
	body.hold(chosen[3])
	addtimer(CALLBACK(src, PROC_REF(finish_dock)), QUAY_DOCK_WARNING)
	return TRUE

// The slide into the berth, QUAY_DOCK_WARNING after it was ordered.
/datum/craft/proc/finish_dock()
	var/list/plan = docking
	docking = null
	if (!plan)
		return FALSE
	if (body)
		body.hold(0)
	clear_path()
	var/datum/berth_ticket/T = ticket
	if (!body || !body.placed() || !T || !T.granted())
		if (T)
			T.release()
		return FALSE
	var/obj/structure/berth/B = T.berth
	var/turf/O = body.origin()
	// Already lying alongside (after a restart, say): only the lines go out.
	var/there = O && O.x == plan[1] && O.y == plan[2] && body.heading() == plan[3]
	if (!there && !body.move_to(plan[1], plan[2], plan[3]))
		last_refusal = body.last_refusal
		T.release()
		crew_message(SPAN_WARNING("She cannot make the berth: [last_refusal]."))
		return FALSE
	body.make_fast()
	T.complete()
	crew_message(SPAN_NOTICE("The [name] is made fast at [B.berth_name()]."))
	return TRUE

// The helm's berth menu: every mooring post in reach.
/datum/craft/proc/dock_menu(mob/living/human/H, atom/at)
	var/turf/here = centre()
	if (!istype(H) || QDELETED(at) || !here)
		return
	var/list/choices = list()
	for (var/obj/structure/berth/quay/Q in sea_harbours)
		if (Q.takes_ships && Q.z == here.z && get_dist(here, Q) <= QUAY_DOCK_RANGE && Q != berth && sea_same_waters(here, get_turf(Q)))
			choices["[capitalize(Q.berth_name())], [get_dist(here, Q)] tiles [submarine_bearing(here, get_turf(Q))]"] = Q
	if (!choices.len)
		to_chat(H, SPAN_WARNING("There is no mooring post within [QUAY_DOCK_RANGE] tiles of the [name]."))
		return
	var/choice = WWinput(H, "Make for which berth? The water she will lie in is marked for ten seconds, then she slides in alongside and is made fast.", "Berths", "Cancel", choices + list("Cancel"))
	var/obj/structure/berth/quay/Q = choices[choice]
	if (!istype(Q) || QDELETED(src) || QDELETED(at) || get_dist(H, at) > 1)
		return
	if (!order_dock(Q))
		to_chat(H, SPAN_WARNING("She cannot berth there: [last_refusal]."))
		return
	log_game("[key_name(H)] ordered the [name] into the berth [Q.berth_name()] at [Q.x],[Q.y],[Q.z].")
	crew_message(SPAN_NOTICE("[H] at the [at.name]: making for [Q.berth_name()]. Stand clear of the marked water."))

// ---------------------------------------------------------------- berths

// What a berth is called on a chart and in the crew's messages.
/obj/structure/berth/proc/berth_name()
	return name

/obj/structure/berth/quay
	name = "mooring post"
	desc = "A stout post for a ship's lines, set at the water's edge. A ship within 20 tiles can make for it from her helm and lie alongside. Click it to claim it, name the harbour and say who is welcome."
	icon = 'icons/obj/structures.dmi'
	icon_state = "wood_pole_good"
	density = TRUE
	berth_length = QUAY_BERTH_LENGTH
	berth_beam = QUAY_BERTH_BEAM
	welcome = BERTH_WELCOME_EVERYONE
	// Saved: the harbour's name. owner_party, welcome and guests save too.
	var/harbour = ""
	var/tmp/datum/chart_token/harbour/token
	// FALSE for a board that is not a berth for ships (freight_depot.dm): it
	// stays off the sea chart and no ship can make for it.
	var/takes_ships = TRUE

/obj/structure/berth/quay/New()
	..()
	sea_harbours += src

/obj/structure/berth/quay/Destroy()
	sea_harbours -= src
	if (token)
		qdel(token)
	return ..()

/obj/structure/berth/quay/berth_name()
	return length(harbour) ? harbour : "the mooring post at [x], [y]"

// The side the water is on: the way the post faces if there is water there,
// else the first side that has some, else 0.
/obj/structure/berth/quay/proc/water_side()
	for (var/side in list(dir, NORTH, EAST, SOUTH, WEST))
		var/turf/T = get_step(src, side)
		if (!istype(T, /turf/floor/beach/water))
			continue
		// A pier is not water; the planks of a hull lying alongside are.
		var/pier = FALSE
		for (var/obj/covers/P in T)
			if (!P.afloat)
				pier = TRUE
				break
		if (!pier)
			return side
	return 0

// Where a craft would lie alongside: list(x, y, heading) for each way round
// she can lie, her present heading first when it is one of them. She lies
// along the shore with her middle abreast of the post.
/obj/structure/berth/quay/proc/berth_plans(datum/craft/C)
	. = list()
	var/side = water_side()
	if (!side || !C || !C.body)
		return
	var/along = C.body.length_tiles()
	var/across = C.body.beam_tiles()
	var/list/headings = (side & (EAST | WEST)) ? list(NORTH, SOUTH) : list(EAST, WEST)
	if (C.body.heading() == headings[2])
		headings = list(headings[2], headings[1])
	var/bx = x
	var/by = y
	switch (side)
		if (EAST)
			bx = x + 1
			by = y - round((along - 1) / 2)
		if (WEST)
			bx = x - across
			by = y - round((along - 1) / 2)
		if (NORTH)
			bx = x - round((along - 1) / 2)
			by = y + 1
		if (SOUTH)
			bx = x - round((along - 1) / 2)
			by = y - across
	for (var/heading in headings)
		. += list(list(bx, by, heading))

/obj/structure/berth/quay/proc/status_text()
	var/list/lines = list()
	lines += length(harbour) ? "This is [harbour]." : "This mooring post has no harbour name."
	if (!owner_party)
		lines += "Nobody has claimed it: any ship may berth here."
	else
		var/list/rule = list(BERTH_WELCOME_OWNERS = "only their own ships are welcome", BERTH_WELCOME_GUESTS = "their own ships and their guests are welcome", BERTH_WELCOME_EVERYONE = "every ship is welcome")
		lines += "It belongs to [party_train_party_name(owner_party)]: [rule[welcome]]."
		if (welcome == BERTH_WELCOME_GUESTS && guests.len)
			var/list/names = list()
			for (var/party in guests)
				names += party_train_party_name(party)
			lines += "Guests: [jointext(names, ", ")]."
	lines += "It takes a ship up to [berth_length] tiles long and [berth_beam] across."
	if (occupant)
		lines += "The [occupant.name] is moored here."
	else if (reserved && reserved.craft)
		lines += "The [reserved.craft.name] is making for it."
	else if (!water_side())
		lines += "There is no open water beside it."
	var/freight = length(contracts(CONTRACT_OPEN))
	if (freight)
		lines += "[freight] freight contract\s on offer."
	return jointext(lines, " ")

/obj/structure/berth/quay/examine(mob/user)
	..()
	to_chat(user, status_text())

// Strangers' ships within reach whose owners are not guests yet: name = party.
/obj/structure/berth/quay/proc/guest_candidates()
	. = list()
	for (var/datum/craft/C in crafts)
		var/turf/P = C.centre()
		var/party = C.party()
		if (!P || P.z != z || get_dist(P, src) > QUAY_DOCK_RANGE || !party || party == owner_party || (party in guests))
			continue
		.["[party_train_party_name(party)] (the [C.name])"] = party

/obj/structure/berth/quay/attack_hand(mob/living/human/H)
	if (!istype(H))
		return ..()
	var/party = party_train_party_of(H)
	var/list/options = list()
	if (!owner_party)
		options += "Claim the berth"
	else if (party && party == owner_party)
		options += list("Name the harbour", "Welcome only our ships", "Welcome our guests", "Welcome every ship")
		if (guest_candidates().len)
			options += "Add a guest"
		if (guests.len)
			options += "Strike a guest"
		options += "Give up the berth"
	// The freight board (naval/freight.dm) is open to everyone.
	options += "Freight"
	var/choice = WWinput(H, status_text(), name, "Cancel", options + list("Cancel"))
	if (!choice || choice == "Cancel" || QDELETED(src) || get_dist(H, src) > 1)
		return
	if (choice == "Freight")
		freight_menu(H)
		return
	party = party_train_party_of(H)
	if (choice == "Claim the berth")
		if (owner_party || !party)
			return
		owner_party = party
		log_game("[key_name(H)] claimed the mooring post at [x],[y],[z] for [party].")
		visible_message(SPAN_NOTICE("[H] claims the mooring post for [party_train_party_name(party)]."))
		return
	if (!party || party != owner_party)
		return
	switch (choice)
		if ("Name the harbour")
			var/new_name = player_input(H, "Name the harbour. Ships read it on their charts.", name, harbour, "text", null, TRUE)
			if (isnull(new_name) || QDELETED(src) || get_dist(H, src) > 1 || party_train_party_of(H) != owner_party)
				return
			harbour = sanitize(copytext(new_name, 1, 40))
			to_chat(H, SPAN_NOTICE(status_text()))
		if ("Welcome only our ships")
			welcome = BERTH_WELCOME_OWNERS
			to_chat(H, SPAN_NOTICE(status_text()))
		if ("Welcome our guests")
			welcome = BERTH_WELCOME_GUESTS
			to_chat(H, SPAN_NOTICE(status_text()))
		if ("Welcome every ship")
			welcome = BERTH_WELCOME_EVERYONE
			to_chat(H, SPAN_NOTICE(status_text()))
		if ("Add a guest")
			var/list/found = guest_candidates()
			var/pick = WWinput(H, "Whose ships are your guests? Their ship must lie within [QUAY_DOCK_RANGE] tiles of the post.", name, "Cancel", found + list("Cancel"))
			var/guest = found[pick]
			if (!guest || QDELETED(src) || get_dist(H, src) > 1 || party_train_party_of(H) != owner_party)
				return
			guests |= guest
			to_chat(H, SPAN_NOTICE(status_text()))
		if ("Strike a guest")
			var/list/named = list()
			for (var/guest in guests)
				named[party_train_party_name(guest)] = guest
			var/pick = WWinput(H, "Strike which guest?", name, "Cancel", named + list("Cancel"))
			var/guest = named[pick]
			if (!guest || QDELETED(src) || get_dist(H, src) > 1 || party_train_party_of(H) != owner_party)
				return
			guests -= guest
			to_chat(H, SPAN_NOTICE(status_text()))
		if ("Give up the berth")
			owner_party = null
			guests = list()
			welcome = BERTH_WELCOME_EVERYONE
			log_game("[key_name(H)] gave up the mooring post at [x],[y],[z].")
			visible_message(SPAN_NOTICE("[H] gives up the mooring post. Any ship may berth here."))
