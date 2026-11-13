// Encounter sites in orbit (code/modules/space/orbit_sites.dm,
// docs/craft-core.md): derelicts and asteroid fields on the orbit chart that
// are built on a plane of the pool when a spacecraft reaches them and taken
// away when everyone has left.
/world
	hub = ""
	hub_password = ""
	maxx = 64
	maxy = 64
	maxz = 8
	turf = /turf/floor/space/orbit
	area = /area/caribbean/nomads/orbit
	visibility = 0
/world/OpenPort(port)
	if (port == "none")
		return ..()
	return FALSE
/obj/map_metadata/nomads/orbit/probe/New()
	return
/mob/living/human/naval_probe/New()
	return
var/naval_failures = 0
var/naval_runtime_error = FALSE
/proc/naval_check(condition, label)
	if (!condition)
		naval_failures++
	world.log << "[condition ? "PASS" : "FAIL"]: [label]"
/world/Error(exception/e)
	naval_runtime_error = TRUE
	world.log << "runtime error [e] [e.file]:[e.line]"

/obj/structure/probe_rock
	name = "probe rock"
	anchored = TRUE
	density = TRUE

/proc/probe_count(z, path)
	. = 0
	for (var/turf/T in block(locate(1, 1, z), locate(world.maxx, world.maxy, z)))
		if (istype(T, path))
			.++

// Steps the chart until the ship has left the lanes or her token lies still.
/proc/probe_passage(obj/structure/chart_helm/orbit/H)
	var/datum/chart/C = orbit_chart()
	for (var/i = 1, i <= 3000, i++)
		if (!C.run_step())
			return i
	return 0

/proc/probe_cores(z)
	. = list()
	for (var/obj/structure/habitat_core/C in habitat_cores)
		if (!QDELETED(C) && C.z == z)
			. += C

/proc/naval_checks()
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	var/alpha = orbit_claim_plane("station:civ:gaia:Alpha")
	var/datum/chart/orbit/C = orbit_chart()
	var/datum/plane_pool/orbit/pool = orbit_pool()
	var/list/derelicts = list()
	var/list/fields = list()
	var/apart = TRUE
	for (var/datum/chart_site/orbit/S in C.sites)
		if (istype(S, /datum/chart_site/orbit/derelict))
			derelicts += S
		else
			fields += S
		if (chart_distance(S.x, S.y, 50, 50) < 10 || S.loaded || !S.token || S.token.x != S.x)
			apart = FALSE
	naval_check(R && alpha == 2 && derelicts.len == 5 && fields.len == 3 && apart, "a fresh orbit chart has five derelicts and three asteroid fields, clear of the beacon and not built ([derelicts.len], [fields.len])")
	naval_check(C == orbit_chart() && C.sites.len == 8 && length(orbit_free_planes()) == 6, "asking for the chart again makes no more, and no plane is held for them")

	habitat_unfold(locate(20, 20, alpha), "quarters")
	var/obj/structure/chart_helm/orbit/helm = new(locate(20, 19, alpha))
	helm.propellant = 120
	helm.set_ship_name("Kestrel")
	var/datum/chart_token/T = helm.helm_token()
	var/datum/craft/S = helm.ship
	var/datum/craft_body/turfs/spacecraft/B = S.body

	// ---- What her sensors make out ----
	var/datum/chart_site/orbit/derelict/D = null
	for (var/datum/chart_site/orbit/derelict/one in derelicts)
		if (chart_distance(T.x, T.y, one.x, one.y) > 16 && (!D || chart_distance(T.x, T.y, one.x, one.y) < chart_distance(T.x, T.y, D.x, D.y)))
			D = one
	if (!D)
		D = derelicts[1]
		D.x = T.x > 50 ? T.x - 30 : T.x + 30
		C.token_of(D)
	var/list/seen = C.contacts_of(T)
	naval_check((C.arrival in seen) && !(D.token in seen) && !D.charted, "the beacon answers from anywhere; a derelict out of sensor range is not on her chart")
	T.x = D.x - 5
	T.y = D.y
	seen = C.contacts_of(T)
	naval_check((D.token in seen) && D.charted, "within sensor range she finds it")
	helm.helm_token()
	naval_check(T.x != D.x - 5 && (D.token in C.contacts_of(T)), "and it stays charted when she is far off again")

	// ---- Closing a derelict ----
	naval_check(T.lay_course(D.x, D.y, D.name) && helm.in_lanes() && !D.loaded, "a course is laid for it; it is not built until she is there")
	probe_passage(helm)
	var/dz = D.level
	var/list/dead = probe_cores(dz)
	naval_check(D.loaded && D.visited && dz > 0 && orbit_plane_owner(dz) == "site:[D.id]" && helm.z == dz && helm.lies_at() == D.token && isnull(pool.slot_of(helm.ship_id)), "reaching it builds it on a plane of its own and she lies off it ([helm.z])")
	var/breaches = 0
	var/airless = TRUE
	var/crates = 0
	var/salvage = 0
	for (var/obj/structure/habitat_core/core in dead)
		if (core == B.cores[1])
			continue
		breaches += core.breaches()
		if (core.air().breathable() || core.air_oxygen > 0)
			airless = FALSE
		for (var/turf/floor in core.interior())
			for (var/obj/structure/closet/crate/crate in floor)
				crates++
				salvage += length(crate.contents)
	naval_check(dead.len >= 2 && dead.len <= 4 && breaches >= 1 && airless && crates >= 2 && salvage >= crates, "the derelict is one to three dead modules, breached and airless, with salvage in crates ([dead.len - 1] modules, [breaches] breaches, [crates] crates, [salvage] things)")
	var/near = 99
	for (var/obj/structure/habitat_core/core in dead)
		if (core != B.cores[1])
			near = min(near, get_dist(core, B.cores[1]))
	naval_check(near >= 7 && near <= 24 && !B.cores[1].breaches(), "she lies clear of it and near it ([near] tiles core to core)")
	naval_check(findtext(helm.read_text(), "She lies off [D.name]") && isnull(helm.thrust(WEST, 1)), "the console names it and her thrusters work there")
	helm.thrust_left = 0
	naval_check(!D.can_unload() && !D.look() && D.loaded && D.look_timer, "it stays while she lies off it")

	// ---- Leaving it: gone for good, another turns up ----
	var/datum/chart_site/orbit/field/F = fields[1]
	F.charted = TRUE
	var/derelict_name = D.name
	naval_check(T.lay_course(F.x, F.y, F.name) && helm.in_lanes(), "she leaves for an asteroid field she has charted")
	naval_check(D.can_unload() && !D.look() && D.loaded, "the derelict is still there at the first look after she has gone")
	naval_check(D.look() && QDELETED(D) && !orbit_plane_owner(dz) && !probe_count(dz, /turf/wall/habitat_shell) && !length(probe_cores(dz)), "at the second it is taken away and its plane is free and empty")
	var/count = 0
	var/again = FALSE
	for (var/datum/chart_site/orbit/derelict/one in C.sites)
		count++
		if (one.name == derelict_name)
			again = TRUE
	naval_check(count == 5 && C.sites.len == 8 && !again, "a picked-over derelict is off the chart and another has turned up")

	// ---- An asteroid field ----
	probe_passage(helm)
	var/fz = F.level
	var/rocks = length(orbit_asteroids_on(fz))
	naval_check(F.loaded && helm.z == fz && rocks >= 3, "reaching the field builds it: [rocks] asteroids")
	var/held = TRUE
	for (var/obj/structure/orbit_asteroid/rock in orbit_asteroids_on(fz))
		if (!rock.tethered || rock.lumps_left() < 1 || B.contains(get_turf(rock)))
			held = FALSE
	naval_check(held, "each holds ore, keeps its place and is clear of her hull")

	// ---- Someone left behind keeps it ----
	var/mob/living/human/naval_probe/castaway = new(locate(5, 5, fz))
	castaway.real_name = "Castaway"
	naval_check(T.lay_course(C.arrival.x, C.arrival.y, "arrival beacon") && helm.in_lanes(), "she sails for the beacon and leaves someone behind")
	naval_check(!F.can_unload() && !F.look() && !F.look() && F.loaded, "the field stays while someone is there")
	qdel(castaway)
	naval_check(!F.look() && F.look() && !F.loaded && !QDELETED(F) && (F in C.sites) && !length(orbit_asteroids_on(fz)) && !orbit_plane_owner(fz), "with nobody there it is taken away after two looks, and stays on the chart")
	probe_passage(helm)
	naval_check(helm.z == 1, "she is home at the beacon")

	// ---- The cap, the pause and a restart ----
	pool.site_cap = 1
	naval_check(isnull(F.load()) && F.loaded, "a site can be built again")
	var/datum/chart_site/orbit/other = fields[2]
	naval_check(findtext(other.load(), "every encounter plane is in use") && !other.loaded, "past the cap another is refused")
	pool.site_cap = 4
	pool.set_paused(TRUE)
	naval_check(findtext(other.load(), "paused") && !other.loaded, "and while loading is paused")
	other.charted = TRUE
	helm.propellant = 120
	T.lay_course(other.x, other.y, other.name)
	probe_passage(helm)
	naval_check(helm.in_lanes() && !other.loaded && T.x == other.x, "a ship that reaches a site she cannot have holds off in the lanes")
	pool.set_paused(FALSE)
	naval_check(helm.arrive() && other.loaded && helm.z == other.level, "and closes it when loading is allowed again")
	R.before_save()
	var/text = R.site_state
	var/f_id = F.id
	var/f_level = F.level
	var/o_id = other.id
	naval_check(length(text) && C.read_state(text) && C.sites.len == 8, "the sites are saved as one text and read back")
	F = orbit_site(f_id)
	other = orbit_site(o_id)
	naval_check(F && F.loaded && F.level == f_level && F.look_timer && other && other.loaded && other.visited && other.charted && helm.lies_at() == other.token, "with what is built where, what is charted, and a watch on each loaded site")
	naval_check(!C.read_state("") && !C.read_state("not json") && C.sites.len == 8, "a bad text changes nothing")

/proc/naval_run()
	try
		naval_checks()
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	text2file(json_encode(list("commit" = world.params["tested_commit"], "failures" = naval_failures, "runtime_error" = naval_runtime_error, "byond_version" = world.byond_version, "byond_build" = world.byond_build)), "result.json")
	del(world)

/world/New()
	// These checks are about passage, not weather (craft/chart_hazards.dm).
	chart_hazards_off = TRUE
	OpenPort("none")
	try
		GLOB.all_observable_events = list()
		GLOB.moved_event = new
		GLOB.dir_set_event = new
		GLOB.destroyed_event = new
		movementMachine = new
		map = new /obj/map_metadata/nomads/orbit/probe
		naval_check(!world.port, "fixture has no listening port")
	catch(var/exception/e)
		naval_check(FALSE, "exception [e] [e.file]:[e.line]")
	spawn(0)
		naval_run()
