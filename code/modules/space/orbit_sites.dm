// ============================================================
// Encounter sites in orbit (docs/craft-core.md)
// ------------------------------------------------------------
// A site is a place on the orbit chart (orbit_chart.dm) that is built on a
// plane of the plane pool (craft/plane_pool.dm) when a spacecraft
// (spacecraft.dm) reaches it, and taken away again some minutes after the
// last ship and the last person have left. At most the pool's site_cap are
// loaded at once, and an admin can pause loading.
//
//  - A derelict is one to three dead habitat modules: breached, airless and
//    cold, with salvage in crates. Patched and aired it is a hull like any
//    other. Once it has been visited it is gone for good when it is taken
//    away, and another derelict turns up somewhere else on the chart.
//  - An asteroid field is a scatter of small asteroids to mine
//    (orbit_asteroids.dm). It stays on the chart and has fresh rock each
//    time it is loaded.
//
// A ship's sensors find a site from ORBIT_CHART_SENSOR_RANGE squares; once
// found it stays charted. Stations and the arrival beacon are always
// charted. The sites and what is loaded where are saved by the plane
// registry as one text. Nothing here stores world.time.
// ============================================================

#define ORBIT_SITE_DERELICTS 5
#define ORBIT_SITE_FIELDS 3
// A loaded site is looked at this often; two looks in a row with nobody
// there take it away.
#define ORBIT_SITE_LOOK 3000

var/global/list/orbit_derelict_names = list("Halcyon", "Tern", "Meridian", "Lodestar", "Sparrowhawk", "Calliope", "Winter Rose", "Argent", "Pilgrim", "Corvid", "Long Reach", "Ember")
var/global/list/orbit_field_names = list("the Shoals", "the Gravel Bank", "the Drift", "the Cinders", "the Scatter", "the Reef")

/obj/structure/orbit_registry
	// The sites of the orbit chart as one text (orbit_sites.dm).
	var/site_state = ""

/obj/structure/orbit_registry/before_save()
	..()
	if (orbit_chart_made && !QDELETED(orbit_chart_made))
		site_state = orbit_chart_made.state_text()

/obj/structure/orbit_registry/after_load()
	..()
	if (orbit_chart_made && !QDELETED(orbit_chart_made))
		orbit_chart_made.read_state(site_state)

// ---------------------------------------------------------------- the site

/datum/chart_token/station/site
	kind = "site"
	sensor_range = 0
	var/datum/chart_site/orbit/site

/datum/chart_token/station/site/Destroy()
	site = null
	return ..()

/datum/chart_site/orbit
	var/id = ""
	var/seed = 1
	var/level = 0                 // The plane it is built on while loaded.
	var/charted = FALSE           // Some ship has found it.
	var/visited = FALSE           // Some ship has lain off it.
	var/tmp/idle = 0
	var/tmp/look_timer = 0
	var/datum/chart_token/station/site/token

/datum/chart_site/orbit/Destroy()
	if (look_timer)
		deltimer(look_timer)
		look_timer = 0
	if (token)
		token.site = null
		qdel(token)
		token = null
	if (chart)
		chart.sites -= src
		chart = null
	return ..()

/datum/chart_site/orbit/proc/owner()
	return "site:[id]"

// Builds the site on its plane.
/datum/chart_site/orbit/proc/build(z)
	return

// TRUE when what is left of the site is not worth keeping on the chart.
/datum/chart_site/orbit/proc/spent()
	return FALSE

// Loads the site onto a free plane. Returns null when it is there, else why
// it is not.
/datum/chart_site/orbit/proc/load()
	if (loaded)
		return null
	var/datum/plane_pool/orbit/pool = orbit_pool()
	if (!pool)
		return "this is not orbit"
	var/refusal = pool.claim_refusal(owner())
	if (refusal)
		return refusal
	var/z = pool.claim(owner())
	if (!z)
		return "every plane is taken"
	level = z
	loaded = TRUE
	build(z)
	watch()
	return null

// A spacecraft lying off the site.
/datum/chart_site/orbit/proc/ship_here()
	for (var/obj/structure/chart_helm/orbit/H in spacecraft_helms)
		if (!QDELETED(H) && isturf(H.loc) && H.z == level)
			return H
	return null

/datum/chart_site/orbit/can_unload()
	if (!loaded || kept || ship_here())
		return FALSE
	var/datum/plane_pool/orbit/pool = orbit_pool()
	return pool && !pool.clear_refusal(level)

// Takes the site away: its plane is emptied and given back. FALSE when it
// cannot be.
/datum/chart_site/orbit/proc/unload()
	if (!can_unload())
		return FALSE
	var/datum/plane_pool/orbit/pool = orbit_pool()
	if (!pool.release(level, TRUE))
		return FALSE
	level = 0
	loaded = FALSE
	idle = 0
	if (look_timer)
		deltimer(look_timer)
		look_timer = 0
	var/datum/chart/orbit/C = chart
	if (visited && spent() && istype(C))
		C.replace_site(src)
	return TRUE

// Keeps an eye on a loaded site until it has been taken away.
/datum/chart_site/orbit/proc/watch()
	if (!loaded || look_timer)
		return FALSE
	look_timer = addtimer(CALLBACK(src, PROC_REF(look)), ORBIT_SITE_LOOK, TIMER_STOPPABLE)
	return TRUE

/datum/chart_site/orbit/proc/look()
	look_timer = 0
	if (!loaded)
		return FALSE
	if (can_unload())
		idle++
		if (idle >= 2 && unload())
			return TRUE
	else
		idle = 0
	watch()
	return FALSE

/datum/chart_site/orbit/proc/site_state()
	return list("type" = "[type]", "id" = id, "name" = name, "x" = x, "y" = y, "seed" = seed, "level" = loaded ? level : 0, "charted" = charted ? 1 : 0, "visited" = visited ? 1 : 0)

// ---- Derelicts ----

/datum/chart_site/orbit/derelict

/datum/chart_site/orbit/derelict/spent()
	return TRUE

/datum/chart_site/orbit/derelict/build(z)
	var/datum/sea_dice/dice = new(seed)
	var/modules = dice.cast(3)
	var/cx = round(world.maxx / 2) - (modules - 1) * round(HABITAT_MODULE_SPACING / 2)
	var/cy = round(world.maxy / 2)
	var/list/kinds = list("quarters", "workshop", "storage", "greenhouse")
	var/list/cores = list()
	for (var/i = 0, i < modules, i++)
		var/obj/structure/habitat_core/C = habitat_unfold(locate(cx + i * HABITAT_MODULE_SPACING, cy, z), kinds[dice.cast(kinds.len)], /obj/structure/habitat_core, SOUTH, FALSE)
		if (!C)
			continue
		C.name = "dead [C.kind] core"
		cores += C
	for (var/obj/structure/habitat_core/C in cores)
		// Long dead: no air, and as cold as the dark.
		C.ledger = null
		C.air_oxygen = 0
		C.air_co2 = 0
		C.air_inert = 0
		C.air_temperature = orbit_ambient_c()
		// What the last crew left behind.
		var/list/spots = list()
		for (var/turf/T in C.interior())
			if (T != get_turf(C))
				spots += T
		for (var/n = 1 + dice.cast(2), n > 0 && spots.len, n--)
			var/turf/T = spots[dice.cast(spots.len)]
			spots -= T
			var/obj/structure/closet/crate/crate = new(T)
			crate.name = "salvage crate"
			orbit_derelict_fill(crate, dice)
		if (dice.chance(50) && spots.len)
			var/turf/T = spots[dice.cast(spots.len)]
			spots -= T
			var/list/machines = list(/obj/structure/life_support/scrubber, /obj/structure/life_support/heater, /obj/structure/life_support/electrolyser)
			var/path = machines[dice.cast(machines.len)]
			new path(T)
	// One hole in the first module's hull, clear of any shared wall.
	if (cores.len)
		var/obj/structure/habitat_core/first = cores[1]
		var/turf/hole = locate(first.x - HABITAT_MODULE_RADIUS, first.y + dice.cast(3) - 2, z)
		if (istype(hole, /turf/wall/habitat_shell))
			hole.ChangeTurf(/turf/floor/space/orbit, FALSE, FALSE)

// Salvage for one crate.
/proc/orbit_derelict_fill(obj/structure/closet/crate/crate, datum/sea_dice/dice)
	var/list/stacks = list(/obj/item/stack/material/steel = 20, /obj/item/stack/material/glass = 10, /obj/item/stack/material/electronics = 6, /obj/item/stack/material/copper = 10)
	for (var/n = dice.cast(2), n > 0, n--)
		var/path = stacks[dice.cast(stacks.len)]
		var/obj/item/stack/S = new path(crate)
		S.amount = 2 + dice.cast(stacks[path])
	if (dice.chance(40))
		new /obj/item/habitat_sealant(crate)
	if (dice.chance(15))
		var/list/kits = list(/obj/item/habitat_kit, /obj/item/habitat_kit/storage, /obj/item/habitat_kit/workshop)
		var/kit = kits[dice.cast(kits.len)]
		new kit(crate)

// ---- Asteroid fields ----

/datum/chart_site/orbit/field

/datum/chart_site/orbit/field/build(z)
	var/datum/sea_dice/dice = new(seed + rand(0, 999))
	var/mx = round(world.maxx / 2)
	var/my = round(world.maxy / 2)
	var/reach = round(min(world.maxx, world.maxy) / 2) - 6
	for (var/n = 6 + dice.cast(5), n > 0, n--)
		// A ring round the middle, so a ship has room to lie among them.
		var/dx = dice.cast(reach * 2 + 1) - reach - 1
		var/dy = dice.cast(reach * 2 + 1) - reach - 1
		if (max(abs(dx), abs(dy)) < 8)
			continue
		var/turf/T = locate(mx + dx, my + dy, z)
		if (!istype(T, /turf/floor/space/orbit) || length(T.contents))
			continue
		var/obj/structure/orbit_asteroid/A = new(T)
		A.fill()
		// A field's rock keeps its place.
		A.tethered = TRUE

// ---------------------------------------------------------------- the chart

/datum/chart/orbit
	var/next_site = 1
	var/sites_ready = FALSE

/proc/orbit_site(id)
	var/datum/chart/orbit/C = orbit_chart_made
	if (!C || QDELETED(C))
		return null
	for (var/datum/chart_site/orbit/S in C.sites)
		if (S.id == id)
			return S
	return null

// The token of a site, made when first asked for.
/datum/chart/orbit/proc/token_of(datum/chart_site/orbit/S)
	if (!S.token)
		S.token = new /datum/chart_token/station/site
		S.token.site = S
		S.token.owner = S.owner()
	S.token.name = S.name
	if (S.token.chart != src || S.token.x != S.x || S.token.y != S.y)
		add_token(S.token, S.x, S.y)
	return S.token

// A free spot for a new site: clear of the beacon, the stations and every
// other site. list(x, y) or null.
/datum/chart/orbit/proc/free_spot()
	for (var/tries = 1, tries <= 200, tries++)
		var/sx = rand(ORBIT_CHART_EDGE + 1, width - ORBIT_CHART_EDGE)
		var/sy = rand(ORBIT_CHART_EDGE + 1, height - ORBIT_CHART_EDGE)
		if (chart_distance(sx, sy, width / 2, height / 2) < 10)
			continue
		var/crowded = FALSE
		for (var/datum/chart_token/station/T in tokens)
			if (chart_distance(sx, sy, T.x, T.y) < 7)
				crowded = TRUE
				break
		if (!crowded)
			return list(sx, sy)
	return null

/datum/chart/orbit/proc/add_site(path, site_name)
	var/list/spot = free_spot()
	if (!spot)
		return null
	var/datum/chart_site/orbit/S = new path
	S.id = "o[next_site++]"
	S.name = site_name
	S.chart = src
	S.x = spot[1]
	S.y = spot[2]
	S.seed = rand(1, 60000)
	sites += S
	token_of(S)
	return S

/datum/chart/orbit/proc/unused_name(list/names, prefix)
	var/list/free = names.Copy()
	for (var/datum/chart_site/orbit/S in sites)
		for (var/n in free.Copy())
			if (S.name == "[prefix][n]")
				free -= n
	return "[prefix][free.len ? pick(free) : "[pick(names)] [next_site]"]"

// A fresh orbit: derelicts and asteroid fields scattered round the beacon.
/datum/chart/orbit/proc/seed_sites()
	for (var/i = 1, i <= ORBIT_SITE_DERELICTS, i++)
		add_site(/datum/chart_site/orbit/derelict, unused_name(orbit_derelict_names, "the derelict "))
	for (var/i = 1, i <= ORBIT_SITE_FIELDS, i++)
		add_site(/datum/chart_site/orbit/field, unused_name(orbit_field_names, ""))
	return sites.len

// A derelict that has been picked over is gone; another turns up.
/datum/chart/orbit/proc/replace_site(datum/chart_site/orbit/old)
	var/path = old.type
	qdel(old)
	if (ispath(path, /datum/chart_site/orbit/derelict))
		return add_site(path, unused_name(orbit_derelict_names, "the derelict "))
	return null

// Makes the sites the first time the chart is used: from the registry's
// text, or fresh.
/datum/chart/orbit/proc/ready_sites()
	if (sites_ready)
		return
	sites_ready = TRUE
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	if (!R || !read_state(R.site_state))
		seed_sites()

/datum/chart/orbit/proc/state_text()
	var/list/all = list()
	for (var/datum/chart_site/orbit/S in sites)
		all += list(S.site_state())
	return json_encode(list("next" = next_site, "sites" = all))

// FALSE when the text holds no sites.
/datum/chart/orbit/proc/read_state(text)
	if (!istext(text) || !length(text))
		return FALSE
	var/list/state = null
	try
		state = json_decode(text)
	catch
		return FALSE
	if (!islist(state) || !islist(state["sites"]))
		return FALSE
	for (var/datum/chart_site/orbit/S in sites.Copy())
		qdel(S)
	sites.Cut()
	sites_ready = TRUE
	next_site = isnum(state["next"]) ? state["next"] : 1
	for (var/list/one in state["sites"])
		var/path = text2path("[one["type"]]")
		if (!ispath(path, /datum/chart_site/orbit))
			continue
		var/datum/chart_site/orbit/S = new path
		S.id = "[one["id"]]"
		S.name = "[one["name"]]"
		S.x = isnum(one["x"]) ? clamp(one["x"], 1, width) : 1
		S.y = isnum(one["y"]) ? clamp(one["y"], 1, height) : 1
		S.seed = isnum(one["seed"]) ? one["seed"] : 1
		S.charted = one["charted"] ? TRUE : FALSE
		S.visited = one["visited"] ? TRUE : FALSE
		// Still loaded only if the registry still gives it that plane.
		var/z = one["level"]
		if (isnum(z) && orbit_plane_owner(z) == S.owner())
			S.level = z
			S.loaded = TRUE
		S.chart = src
		sites += S
		token_of(S)
		S.watch()
	return TRUE

// Stations and the beacon answer from anywhere; a site is found by sensors
// and then stays charted.
/datum/chart/orbit/contacts_of(datum/chart_token/viewer)
	. = ..()
	if (!viewer || viewer.chart != src)
		return
	for (var/datum/chart_token/station/T in tokens)
		if (T == viewer)
			continue
		var/datum/chart_token/station/site/place = T
		if (istype(place))
			if (!place.site)
				. -= place
				continue
			if (place in .)
				place.site.charted = TRUE
			else if (place.site.charted)
				. += place
		else
			. |= T
