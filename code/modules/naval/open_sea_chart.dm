// ============================================================
// The open sea chart (docs/craft-core.md): making passage
// ------------------------------------------------------------
// An open-sea world (open_sea.dm) has one steered chart (craft/chart.dm) of
// OPEN_SEA_CHART_SIZE squares, with the home waters in the middle and the
// islands and wrecks (open_sea_sites.dm) scattered round them. A hull built
// at a tiller makes passage on it from the tiller's "Open sea chart":
//
//  - A course laid or a heading steered while she lies in the home waters or
//    off a site puts her to sea: she is moved to a sea cell of her own, where
//    she lies alone while her token crosses the chart.
//  - When her token reaches a place, the place is built in a cell if it is not
//    there already and she is moved to lie off it.
//  - Where a ship is on the chart is read from where her hull lies (the home
//    cell, a site's cell, or neither), so nothing but her token's place and
//    motion has to be saved, and the tiller saves that with the hull.
//
// The sites and which cell each lies in are saved by the sea registry as one
// text.
// ============================================================

#define OPEN_SEA_CHART_SIZE 100
#define OPEN_SEA_SIGHT 30
#define OPEN_SEA_SPEED 0.3
#define OPEN_SEA_ISLANDS 9
#define OPEN_SEA_WRECKS 6
#define OPEN_SEA_SWEEP 3000

var/global/datum/chart/open_sea/open_sea_chart_made = null
var/global/list/open_sea_island_names = list("Gull Island", "Cormorant Rock", "Turtle Cay", "Saltgrass Island", "Whalebone Island", "Petrel Island", "Driftwood Cay", "Heron Island", "Lantern Rock", "Samphire Island", "Osprey Island", "Kelp Cay")
var/global/list/open_sea_wreck_names = list("Marigold", "Sea Otter", "Good Hope", "Plover", "Northern Star", "Mary Anne", "Tern", "Providence", "Swift", "Albatross")

/datum/chart/open_sea
	name = "open sea chart"
	mode = CHART_MODE_STEERED
	width = OPEN_SEA_CHART_SIZE
	height = OPEN_SEA_CHART_SIZE
	var/datum/chart_token/sea_place/home
	var/next_id = 1
	var/tmp/sweep_timer = 0

/datum/chart/open_sea/Destroy()
	if (open_sea_chart_made == src)
		open_sea_chart_made = null
	if (sweep_timer)
		deltimer(sweep_timer)
		sweep_timer = 0
	home = null
	return ..()

// The home waters or a site, as the chart shows it.
/datum/chart_token/sea_place
	kind = "site"
	sensor_range = 0
	var/datum/chart_site/sea/site     // null for the home waters

/datum/chart_token/sea_place/Destroy()
	site = null
	return ..()

// A ship on the open sea.
/datum/chart_token/passage
	sensor_range = OPEN_SEA_SIGHT
	max_speed = OPEN_SEA_SPEED
	var/tmp/unpaid = 0            // Seconds under way since her drives last paid.

// Her drives pay once for every half minute under way, as they do in sight
// of land.
/datum/chart_token/passage/pay(share)
	if (!craft)
		return 1
	craft.fit_drives()
	if (craft.thrust() <= 0)
		return 0
	unpaid += CHART_STEP_SECONDS
	if (unpaid >= VESSEL_HOP_INTERVAL / 10)
		unpaid = 0
		for (var/datum/craft_drive/D in craft.drives)
			D.burn(clamp(share, 0, 1))
	return 1

/datum/chart_token/passage/arrived()
	if (craft)
		craft.open_sea_arrive()

// The chart of this open-sea world, or null off one.
/proc/open_sea_chart()
	if (!open_sea_world())
		return null
	if (!open_sea_chart_made || QDELETED(open_sea_chart_made))
		open_sea_chart_made = new /datum/chart/open_sea
		var/obj/structure/sea_registry/R = sea_get_registry()
		if (!R || !open_sea_chart_made.read_state(R.state))
			open_sea_chart_made.seed_sites()
		open_sea_chart_made.sweep_timer = addtimer(CALLBACK(open_sea_chart_made, TYPE_PROC_REF(/datum/chart/open_sea, sweep)), OPEN_SEA_SWEEP, TIMER_LOOP | TIMER_STOPPABLE)
	return open_sea_chart_made

/datum/chart/open_sea/proc/place_home()
	if (!home)
		home = new /datum/chart_token/sea_place
		home.kind = "harbour"
		home.name = "the home waters"
	add_token(home, round(width / 2), round(height / 2))

// The token of a site, made when it is first asked for.
/datum/chart/open_sea/proc/place_of(datum/chart_site/sea/S)
	for (var/datum/chart_token/sea_place/T in tokens)
		if (T.site == S)
			return T
	var/datum/chart_token/sea_place/T = new
	T.site = S
	T.name = S.name
	add_token(T, S.x, S.y)
	return T

// A free spot for a new site: clear of the home waters and of every other.
/datum/chart/open_sea/proc/free_spot()
	for (var/tries = 1, tries <= 200, tries++)
		var/sx = rand(6, width - 5)
		var/sy = rand(6, height - 5)
		if (chart_distance(sx, sy, width / 2, height / 2) < 12)
			continue
		var/crowded = FALSE
		for (var/datum/chart_site/sea/S in open_sea_sites)
			if (chart_distance(sx, sy, S.x, S.y) < 9)
				crowded = TRUE
				break
		if (!crowded)
			return list(sx, sy)
	return null

/datum/chart/open_sea/proc/add_site(path, site_name)
	var/list/spot = free_spot()
	if (!spot)
		return null
	var/datum/chart_site/sea/S = new path
	S.id = "s[next_id++]"
	S.name = site_name
	S.chart = src
	S.x = spot[1]
	S.y = spot[2]
	S.seed = rand(1, 60000)
	sites += S
	place_of(S)
	return S

// A fresh sea: islands and wrecks scattered round the home waters.
/datum/chart/open_sea/proc/seed_sites()
	place_home()
	var/list/islands = open_sea_island_names.Copy()
	for (var/i = 1, i <= OPEN_SEA_ISLANDS && islands.len, i++)
		add_site(/datum/chart_site/sea/island, pick_n_take(islands))
	var/list/wrecks = open_sea_wreck_names.Copy()
	for (var/i = 1, i <= OPEN_SEA_WRECKS && wrecks.len, i++)
		add_site(/datum/chart_site/sea/wreck, "the wreck of the [pick_n_take(wrecks)]")
	return sites.len

// The open sea as one text for the registry, and back. read_state() is
// FALSE when the text holds no sea.
/datum/chart/open_sea/proc/state_text()
	var/list/all = list()
	for (var/datum/chart_site/sea/S in sites)
		all += list(S.site_state())
	return json_encode(list("next" = next_id, "sites" = all))

/datum/chart/open_sea/proc/read_state(text)
	if (!istext(text) || !length(text))
		return FALSE
	var/list/state = null
	try
		state = json_decode(text)
	catch
		return FALSE
	if (!islist(state) || !islist(state["sites"]))
		return FALSE
	for (var/datum/chart_site/sea/S in sites.Copy())
		var/datum/chart_token/sea_place/T = place_of(S)
		qdel(T)
		qdel(S)
	sites.Cut()
	place_home()
	next_id = isnum(state["next"]) ? state["next"] : 1
	for (var/list/one in state["sites"])
		var/datum/chart_site/sea/S = open_sea_site_restore(one)
		if (!S)
			continue
		S.chart = src
		sites += S
		place_of(S)
	return TRUE

// Every few minutes: a site everyone has left starts its count.
/datum/chart/open_sea/proc/sweep()
	for (var/datum/chart_site/sea/S in sites)
		S.watch()

/obj/structure/sea_registry/before_save()
	..()
	var/datum/chart/open_sea/C = open_sea_chart()
	if (C)
		state = C.state_text()

/obj/structure/sea_registry/after_load()
	..()
	sea_registry = src
	if (open_sea_chart_made && !QDELETED(open_sea_chart_made))
		open_sea_chart_made.read_state(state)

// TRUE when two tiles lie in the same waters: always, off the open sea.
/proc/sea_same_waters(turf/a, turf/b)
	if (!open_sea_world())
		return TRUE
	return a && b && sea_cell_of(a) == sea_cell_of(b)

// ---------------------------------------------------------------- the ship

/datum/craft
	var/tmp/datum/chart_token/passage/sea_token

// The place she lies at: the home token, a site's token, or null at sea.
/datum/craft/proc/open_sea_place()
	var/datum/chart/open_sea/C = open_sea_chart()
	var/turf/O = (body && body.placed()) ? body.origin() : null
	if (!C || !O)
		return null
	var/n = sea_cell_of(O)
	if (n == sea_home_cell())
		return C.home
	var/datum/chart_site/sea/S = open_sea_site_in(n)
	return S ? C.place_of(S) : null

// Her token on the open sea chart, made when first asked for. While she lies
// at a place it is kept on that place.
/datum/craft/proc/open_sea_token()
	var/datum/chart/open_sea/C = open_sea_chart()
	if (!C || !istype(body, /datum/craft_body/built) || !body.placed())
		return null
	if (!sea_token || QDELETED(sea_token))
		sea_token = new /datum/chart_token/passage
		sea_token.craft = src
		C.add_token(sea_token, C.home.x, C.home.y)
	else if (sea_token.chart != C)
		C.add_token(sea_token, C.home.x, C.home.y)
	sea_token.name = name
	sea_token.dark = running_dark
	var/datum/chart_token/sea_place/at = open_sea_place()
	if (at && !sea_token.on_course && !sea_token.throttle && !sea_token.speed())
		sea_token.x = at.x
		sea_token.y = at.y
	return sea_token

// Her place and motion on the chart for the tiller to save, and back.
/datum/craft/proc/open_sea_state()
	var/datum/chart_token/passage/T = sea_token
	if (!T || QDELETED(T) || !T.chart)
		return null
	return list("x" = T.x, "y" = T.y, "vx" = T.vx, "vy" = T.vy, "heading" = T.heading, "throttle" = T.throttle, "course" = T.on_course ? 1 : 0, "cx" = T.course_x, "cy" = T.course_y, "cname" = T.course_name)

/datum/craft/proc/open_sea_restore(list/state)
	var/datum/chart_token/passage/T = open_sea_token()
	if (!T || !islist(state))
		return FALSE
	var/datum/chart/C = T.chart
	if (isnum(state["x"]) && isnum(state["y"]) && C.in_bounds(state["x"], state["y"]) && !open_sea_place())
		T.x = state["x"]
		T.y = state["y"]
	T.vx = isnum(state["vx"]) ? state["vx"] : 0
	T.vy = isnum(state["vy"]) ? state["vy"] : 0
	T.heading = isnum(state["heading"]) ? state["heading"] : 0
	T.throttle = isnum(state["throttle"]) ? clamp(state["throttle"], 0, 1) : 0
	if (state["course"] && isnum(state["cx"]) && isnum(state["cy"]) && C.in_bounds(state["cx"], state["cy"]))
		T.lay_course(state["cx"], state["cy"], "[state["cname"]]")
	else if (T.throttle > 0 || T.speed() > 0)
		C.wake()
	return TRUE

// Where her hull can lie in cell n: list(x, y) for body.move_to() with the
// heading she has, or null. Off a place she lies near the edge of the cell,
// clear of whatever is in the middle; alone at sea she lies in the middle.
/datum/craft/proc/open_sea_berth(n, at_place)
	var/datum/craft_body/built/B = body
	var/list/box = sea_cell_box(n)
	if (!istype(B) || !box)
		return null
	var/list/hull = B.box(B.offsets)
	var/wide = hull[3] - hull[1] + 1
	var/tall = hull[4] - hull[2] + 1
	var/mid_x = round((box[1] + box[3] - wide) / 2)
	var/mid_y = round((box[2] + box[4] - tall) / 2)
	var/list/tries = list()
	if (!at_place)
		tries += list(list(mid_x, mid_y))
	// South, north, west then east of the middle, a little in from the race,
	// and a few berths along each side.
	for (var/shift in list(0, -12, 12, -24, 24))
		tries += list(list(mid_x + shift, box[2] + 2))
		tries += list(list(mid_x + shift, box[4] - tall - 1))
		tries += list(list(box[1] + 2, mid_y + shift))
		tries += list(list(box[3] - wide - 1, mid_y + shift))
	for (var/list/spot in tries)
		if (spot[1] < box[1] || spot[2] < box[2] || spot[1] + wide - 1 > box[3] || spot[2] + tall - 1 > box[4])
			continue
		if (B.can_move_to(spot[1], spot[2], B.dir))
			return spot
	last_refusal = B.last_refusal
	return null

// Why she cannot be moved by the chart now, or null.
/datum/craft/proc/open_sea_refusal()
	if (!istype(body, /datum/craft_body/built) || !body.placed())
		return "she is not afloat"
	if (anchored)
		return "her anchor is down"
	if (grapple)
		return "grappling lines hold her"
	if (turning_to || docking)
		return "she is busy coming about"
	if (persistence_save_in_progress)
		return "the world is being saved"
	return null

// Moves her hull into cell n. Returns null when she lies there, else why not.
/datum/craft/proc/open_sea_shift(n, at_place)
	var/refusal = open_sea_refusal()
	if (refusal)
		return refusal
	var/list/spot = open_sea_berth(n, at_place)
	if (!spot)
		return "there is no room for her there ([last_refusal])"
	set_speed(VESSEL_SPEED_STOP)
	clear_path()
	if (!body.move_to(spot[1], spot[2], body.heading()))
		return body.last_refusal
	return null

// Leaves the place she lies at for a cell of her own. Returns null when she
// is at sea (or was already), else why she cannot leave.
/datum/craft/proc/put_to_sea()
	var/datum/chart_token/sea_place/at = open_sea_place()
	var/datum/chart_token/passage/T = open_sea_token()
	if (!T)
		return "she has no chart"
	if (!at)
		return open_sea_refusal()
	var/refusal = open_sea_refusal()
	if (refusal)
		return refusal
	var/datum/plane_pool/sea/pool = sea_pool()
	var/list/free = pool.free_planes()
	if (!free.len)
		return "every stretch of open water is taken"
	refusal = open_sea_shift(free[1], FALSE)
	if (refusal)
		return refusal
	T.x = at.x
	T.y = at.y
	if (at.site)
		at.site.watch()
	crew_message(SPAN_NOTICE("The [name] puts to sea. [capitalize(at.name)] drops below the horizon."))
	return null

// The place her token has reached, or null: the home waters or a site.
/datum/craft/proc/open_sea_landfall()
	var/datum/chart_token/passage/T = sea_token
	if (!T || !T.chart)
		return null
	for (var/datum/chart_token/sea_place/P in T.chart.tokens)
		if (chart_distance(T.x, T.y, P.x, P.y) <= CHART_ARRIVE_RANGE)
			return P
	return null

// Her token has reached the end of its course: she closes the place there.
// TRUE when she lies off it.
/datum/craft/proc/open_sea_arrive()
	var/datum/chart_token/sea_place/P = open_sea_landfall()
	if (!P)
		crew_message(SPAN_NOTICE("The [name] is on station. Nothing but open water here."))
		return FALSE
	if (open_sea_place() == P)
		return TRUE
	var/n = sea_home_cell()
	if (P.site)
		var/problem = P.site.load()
		if (problem)
			crew_message(SPAN_WARNING("The [name] stands off [P.name]: [problem]. Lay the course again to close it."))
			return FALSE
		n = P.site.cell
		if (P.site.linger_timer)
			deltimer(P.site.linger_timer)
			P.site.linger_timer = 0
	var/refusal = open_sea_shift(n, TRUE)
	if (refusal)
		crew_message(SPAN_WARNING("The [name] stands off [P.name]: [refusal]. Lay the course again to close it."))
		if (P.site)
			P.site.watch()
		return FALSE
	set_anchor(TRUE)
	crew_message(SPAN_NOTICE("<b>Land ho!</b> The [name] raises [P.name] and lets go her anchor off it."))
	return TRUE

/datum/craft/Destroy()
	if (sea_token)
		qdel(sea_token)
		sea_token = null
	return ..()

// What the tiller reads of the open sea.
/datum/craft/proc/open_sea_text()
	var/datum/chart_token/passage/T = open_sea_token()
	if (!T)
		return "She has no open sea chart: only a hull built at a tiller makes passage."
	var/datum/chart_token/sea_place/at = open_sea_place()
	var/list/lines = list()
	fit_drives()
	if (at)
		lines += "<b>Open sea chart:</b> the [name] lies [at.site ? "off [at.name]" : "in [at.name]"]."
	else
		lines += "<b>Open sea chart:</b> the [name] is at sea, [T.motion_text()]."
	if (thrust() <= 0)
		lines += "Nothing drives her: she needs a sail or a running engine to make passage."
	for (var/datum/chart_token/O in T.chart.tokens)
		if (O == T || O == at)
			continue
		var/far = chart_distance(T.x, T.y, O.x, O.y)
		var/datum/chart_token/sea_place/P = O
		if (istype(P) && !P.site)
			lines += "[capitalize(P.name)]: [round(far, 0.1)] miles [chart_bearing_name(chart_bearing(T.x, T.y, O.x, O.y))]."
			continue
		if (far > T.sensor_range)
			continue
		if (istype(P))
			lines += "[capitalize(P.name)] ([P.site.kind][P.site.loaded ? ", a ship has raised it" : ""]): [round(far, 0.1)] miles [chart_bearing_name(chart_bearing(T.x, T.y, O.x, O.y))]."
		else if (O.craft && !O.craft.open_sea_place())
			lines += "[capitalize(O.contact_name())], a sail at sea: [round(far, 0.1)] miles [chart_bearing_name(chart_bearing(T.x, T.y, O.x, O.y))]."
	if (lines.len <= 1 + (thrust() <= 0 ? 1 : 0))
		lines += "No land in sight."
	return jointext(lines, "<br>")

// The places a course can be laid for: text = token.
/datum/craft/proc/open_sea_courses()
	. = list()
	var/datum/chart_token/passage/T = open_sea_token()
	if (!T)
		return
	var/datum/chart_token/sea_place/at = open_sea_place()
	for (var/datum/chart_token/sea_place/P in T.chart.tokens)
		if (P == at)
			continue
		var/far = chart_distance(T.x, T.y, P.x, P.y)
		if (P.site && far > T.sensor_range)
			continue
		.["[capitalize(P.name)], [round(far, 0.1)] miles [chart_bearing_name(chart_bearing(T.x, T.y, P.x, P.y))]"] = P

// The tiller's open sea menu.
/datum/craft/proc/open_sea_menu(mob/living/human/H, atom/at)
	if (!istype(H) || QDELETED(at))
		return
	if (!open_sea_token())
		to_chat(H, SPAN_WARNING(open_sea_text()))
		return
	var/choice = WWinput(H, open_sea_text(), "Open sea chart", "Cancel", list("Read the chart", "Lay a course", "Steer by compass", "Heave to", "Cancel"))
	if (!choice || choice == "Cancel" || QDELETED(src) || QDELETED(at) || get_dist(H, at) > 1 || !sea_token)
		return
	if (choice == "Read the chart")
		to_chat(H, open_sea_text())
		return
	switch (helm_access(H))
		if (CRAFT_HELM_CHAINED)
			to_chat(H, SPAN_WARNING("The tiller is chained. The [name] is registered and none of her owners are about."))
			return
		if (CRAFT_HELM_FORCE)
			if (!force_helm(H, at) || QDELETED(src) || QDELETED(at) || !sea_token)
				return
	var/datum/chart_token/passage/T = sea_token
	switch (choice)
		if ("Heave to")
			T.order_stop()
			crew_message(SPAN_NOTICE("[H] at the tiller: heave to. She is [T.motion_text()]."))
		if ("Lay a course")
			var/list/places = open_sea_courses()
			if (!places.len)
				to_chat(H, SPAN_WARNING("There is nowhere in sight to lay a course for."))
				return
			var/place = WWinput(H, "Lay a course for where? She puts to sea, makes for it and anchors off it.", "Open sea chart", "Cancel", places + list("Cancel"))
			var/datum/chart_token/sea_place/P = places[place]
			if (!istype(P) || QDELETED(P) || QDELETED(src) || QDELETED(at) || get_dist(H, at) > 1 || !sea_token)
				return
			if (thrust() <= 0)
				to_chat(H, SPAN_WARNING("Nothing drives her: she needs a sail or a running engine to make passage."))
				return
			var/refusal = put_to_sea()
			if (refusal)
				to_chat(H, SPAN_WARNING("She cannot put to sea: [refusal]."))
				return
			T.lay_course(P.x, P.y, P.name)
			crew_message(SPAN_NOTICE("[H] at the tiller lays a course for [P.name]. She is [T.motion_text()]."))
		if ("Steer by compass")
			var/list/points = list("North" = 0, "Northeast" = 45, "East" = 90, "Southeast" = 135, "South" = 180, "Southwest" = 225, "West" = 270, "Northwest" = 315)
			var/point = WWinput(H, "Steer which way? She puts to sea and holds that heading until you heave to or lay a course.", "Open sea chart", "Cancel", points + list("Cancel"))
			if (isnull(points[point]) || QDELETED(src) || QDELETED(at) || get_dist(H, at) > 1 || !sea_token)
				return
			if (thrust() <= 0)
				to_chat(H, SPAN_WARNING("Nothing drives her: she needs a sail or a running engine to make passage."))
				return
			var/refusal = put_to_sea()
			if (refusal)
				to_chat(H, SPAN_WARNING("She cannot put to sea: [refusal]."))
				return
			T.set_burn(points[point], 1)
			crew_message(SPAN_NOTICE("[H] at the tiller: steer [lowertext(point)]. She is [T.motion_text()]."))
