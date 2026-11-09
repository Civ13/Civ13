// Native view()/see_invisible regression. Every player/object here is synthetic.
// No game DME, production startup, credentials, savefiles or external hooks.
/world
	hub = ""
	hub_password = ""
	visibility = 0
	maxx = 15
	maxy = 15
	maxz = 2
	turf = /turf/visibility_floor
	area = /area
	view = 7
/turf/visibility_floor
	name = "fixture floor"
	luminosity = 1
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/world/Topic()
	return null
/world/Export()
	return null
/client/New()
	del(src)
	return

var/list/visibility_checks = list()
var/visibility_failures = 0
var/visibility_runtime_error = FALSE
/proc/visibility_check(condition, label)
	visibility_checks += list(list("label" = label, "ok" = condition ? TRUE : FALSE))
	if (!condition)
		visibility_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	visibility_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/proc/visibility_control()
	var/datum/agent_control/control = new
	var/datum/agent_character/C = new
	C.body = new /mob/living/human(locate(5, 5, 1))
	C.body.name = "fixture observer"
	C.body.see_invisible = 10
	C.body.see_in_dark = 8
	control.fixture_character = C
	return control
/proc/visibility_pair(x, y, z, label, invisibility = 0)
	var/mob/living/human/player = new(locate(x, y, z))
	var/obj/item/object = new(locate(x, y, z))
	player.name = "[label] player"
	object.name = "[label] object"
	player.invisibility = invisibility
	object.invisibility = invisibility
	return list(player, object)
/proc/visibility_call(datum/agent_control/control, since_rev = null, radius = 5)
	var/datum/agent_identity/identity = new
	return control.act_character_observe(identity, list("since_rev" = since_rev, "radius" = radius))
/proc/visibility_refs(list/rows)
	var/list/refs = list()
	for (var/list/row in rows)
		refs += row["ref"]
	return refs
/proc/visibility_pair_check(datum/agent_control/control, list/observation, list/pair, expected, label)
	var/list/refs = visibility_refs(observation["nearby"])
	for (var/atom/movable/AM in pair)
		var/ref = agent_ref(AM)
		visibility_check((ref in refs) == expected, "[label]: [AM.name] nearby")
		visibility_check((ref in control.fixture_character.seen) == expected, "[label]: [AM.name] remembered signature")
/proc/visibility_wall(opaque)
	// Spans the whole level, so diagonal paths cannot see around an edge.
	for (var/y in 1 to world.maxy)
		var/turf/T = locate(8, y, 1)
		T.opacity = opaque
/proc/visibility_clear()
	for (var/z in 1 to world.maxz)
		for (var/x in 1 to world.maxx)
			for (var/y in 1 to world.maxy)
				var/turf/T = locate(x, y, z)
				for (var/atom/movable/AM in T)
					del(AM)
	visibility_wall(FALSE)

/proc/visibility_initial_checks()
	var/datum/agent_control/control = visibility_control()
	var/list/visible = visibility_pair(6, 5, 1, "visible")
	var/list/boundary = visibility_pair(6, 6, 1, "boundary", 10)
	var/list/invisible = visibility_pair(4, 5, 1, "invisible", 11)
	var/list/occluded = visibility_pair(9, 5, 1, "occluded")
	var/list/distant = visibility_pair(13, 5, 1, "distant")
	var/list/other_level = visibility_pair(6, 5, 2, "other level")
	var/obj/container = new(locate(5, 4, 1))
	container.name = "fixture closed container"
	var/list/contained = visibility_pair(5, 4, 1, "contained")
	for (var/atom/movable/AM in contained)
		AM.loc = container
	var/obj/item/nameless = new(locate(4, 4, 1))
	nameless.name = ""
	visibility_wall(TRUE)
	var/list/first = visibility_call(control)
	visibility_check(first["rev"] == 1 && !("changes_since" in first), "first observation is a full baseline")
	visibility_pair_check(control, first, visible, TRUE, "visible atoms included")
	visibility_pair_check(control, first, boundary, TRUE, "see_invisible equality included")
	visibility_pair_check(control, first, invisible, FALSE, "higher invisibility excluded")
	visibility_pair_check(control, first, occluded, FALSE, "opaque wall excluded")
	visibility_pair_check(control, first, distant, FALSE, "outside radius excluded")
	visibility_pair_check(control, first, other_level, FALSE, "other z-level excluded")
	visibility_pair_check(control, first, contained, FALSE, "container contents excluded")
	var/list/refs = visibility_refs(first["nearby"])
	visibility_check(!(agent_ref(nameless) in refs), "nameless atom excluded")
	visibility_check(!(agent_ref(control.fixture_character.body) in refs), "observer excluded from nearby")
	// At the ordinary zero threshold, normal atoms remain visible.
	control.fixture_character.body.see_invisible = 0
	var/list/ordinary = visibility_call(control)
	visibility_pair_check(control, ordinary, visible, TRUE, "zero threshold visible atoms included")
	visibility_pair_check(control, ordinary, boundary, FALSE, "lower threshold hides former boundary")
	visibility_clear()

/proc/visibility_transition_checks(mode)
	var/datum/agent_control/control = visibility_control()
	var/datum/agent_character/C = control.fixture_character
	var/list/pair = visibility_pair(6, 5, 1, mode)
	var/obj/container = new(locate(5, 4, 1))
	container.name = "fixture closed container"
	var/list/first = visibility_call(control)
	visibility_pair_check(control, first, pair, TRUE, "[mode] initially visible")
	var/list/same = visibility_call(control, first["rev"])
	visibility_check(!length(same["nearby"]) && !length(same["nearby_removed"]), "[mode] unchanged observation empty")
	for (var/atom/movable/AM in pair)
		switch (mode)
			if ("invisibility") AM.invisibility = 11
			if ("observer threshold") AM.invisibility = 1
			if ("occlusion") AM.loc = locate(9, 5, 1)
			if ("distance") AM.loc = locate(13, 5, 1)
			if ("z-level") AM.loc = locate(6, 5, 2)
			if ("container") AM.loc = container
	if (mode == "observer threshold")
		C.body.see_invisible = 0
	if (mode == "occlusion")
		visibility_wall(TRUE)
	var/list/lost = visibility_call(control, same["rev"])
	visibility_check(lost["changes_since"] == same["rev"], "[mode] uses matching baseline")
	visibility_check(length(lost["nearby_removed"]) == pair.len, "[mode] removes exactly the player and object")
	visibility_pair_check(control, lost, pair, FALSE, "[mode] hidden rows and signatures absent")
	for (var/atom/movable/AM in pair)
		visibility_check(agent_ref(AM) in lost["nearby_removed"], "[mode] previously seen [AM.name] removed")
	var/list/still_hidden = visibility_call(control, lost["rev"])
	visibility_check(!length(still_hidden["nearby_removed"]) && !length(still_hidden["nearby"]), "[mode] hidden rows do not reappear or remove twice")
	var/list/stale = visibility_call(control, first["rev"])
	visibility_check(!("changes_since" in stale), "[mode] stale revision receives full baseline")
	visibility_pair_check(control, stale, pair, FALSE, "[mode] stale baseline does not leak hidden atoms")
	for (var/atom/movable/AM in pair)
		AM.loc = locate(6, 5, 1)
		AM.invisibility = 0
	C.body.see_invisible = 10
	visibility_wall(FALSE)
	var/list/returned = visibility_call(control, stale["rev"])
	visibility_pair_check(control, returned, pair, TRUE, "[mode] visible again appears in delta")
	visibility_check(!length(returned["nearby_removed"]), "[mode] reappearance does not remove anything")
	visibility_clear()

/world/New()
	OpenPort("none")
	visibility_check(port == 0, "fixture listening port is closed")
	visibility_check(!OpenPort(0) && port == 0, "fixture refuses to reopen a listening port")
	try
		visibility_initial_checks()
		for (var/mode in list("invisibility", "observer threshold", "occlusion", "distance", "z-level", "container"))
			visibility_transition_checks(mode)
	catch(var/exception/e)
		visibility_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("source_sha256" = world.params["tested_source"], "checks" = visibility_checks, "failures" = visibility_failures, "runtime_error" = visibility_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)
	return
