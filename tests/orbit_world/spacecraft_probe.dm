// Spacecraft (code/modules/space/spacecraft.dm, code/modules/craft/turf_body.dm,
// docs/craft-core.md): docked habitat modules with an orbital helm fly as one
// ship. Her hull is read from the modules, moves on her thrusters, leaves a
// station for the lanes, crosses the orbit chart and is taken in by a
// station that welcomes her.
/world
	hub = ""
	hub_password = ""
	maxx = 64
	maxy = 64
	maxz = 6
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

/proc/naval_checks()
	var/obj/structure/orbit_registry/R = orbit_get_registry()
	var/alpha = orbit_claim_plane("station:civ:gaia:Alpha")
	var/beta = orbit_claim_plane("station:civ:gaia:Beta")
	naval_check(R && alpha == 2 && beta == 3, "two stations hold planes 2 and 3")
	var/datum/chart/orbit/C = orbit_chart()
	var/datum/chart_token/station/SA = orbit_chart_station("station:civ:gaia:Alpha")
	var/datum/chart_token/station/SB = orbit_chart_station("station:civ:gaia:Beta")
	naval_check(C && SA && SB && C.stations.len == 2, "and both are on the orbit chart")

	// ---- A helm needs a module ----
	var/obj/structure/chart_helm/orbit/lost = new(locate(50, 50, alpha))
	naval_check(isnull(lost.helm_token()) && findtext(lost.fault, "floor of a habitat module") && !lost.ship, "a helm in open space steers nothing ([lost.fault])")
	qdel(lost)

	// ---- The hull is the docked modules ----
	var/obj/structure/habitat_core/Q = habitat_unfold(locate(20, 20, alpha), "quarters")
	var/obj/structure/habitat_core/A = habitat_unfold(locate(24, 20, alpha), "airlock", /obj/structure/habitat_core/airlock, EAST)
	var/obj/structure/chart_helm/orbit/helm = new(locate(20, 19, alpha))
	var/datum/chart_token/T = helm.helm_token()
	var/datum/craft/S = helm.ship
	var/datum/craft_body/turfs/spacecraft/B = S ? S.body : null
	naval_check(T && S && B && B.tile_count() == 45 && B.cores.len == 2 && !length(B.fault), "a helm in a module makes a ship of it and the module docked to it: 45 tiles ([B ? B.tile_count() : 0])")
	naval_check(craft_at(locate(26, 22, alpha)) == S && craft_at(locate(18, 18, alpha)) == S && !craft_at(locate(27, 20, alpha)), "her hull is found from any of her tiles and not from the space beside her")
	naval_check(istype(T, /datum/chart_token/spacecraft) && T.x == SA.x && T.y == SA.y && helm.lies_at() == SA && T.sensor_range == 15, "her token lies on the station she lies off")
	naval_check(S.name == "spacecraft" && length(helm.ship_id) && findtext(helm.read_text(), "She lies off"), "she has a name and an id, and the console says where she lies")
	helm.set_ship_name("Kestrel")
	naval_check(S.name == "Kestrel" && T.name == "Kestrel", "and can be named")
	var/obj/structure/chart_helm/orbit/second = new(locate(24, 20, alpha))
	naval_check(isnull(second.helm_token()) && findtext(second.fault, "already has a helm"), "a second helm aboard is refused ([second.fault])")
	qdel(second)

	// ---- Thrusters ----
	var/obj/structure/closet/crate/crate = new(locate(19, 19, alpha))
	var/mob/living/human/naval_probe/crew = new(locate(21, 19, alpha))
	var/air_was = Q.air_oxygen
	naval_check(findtext(helm.thrust(EAST, 2), "tank is dry"), "with a dry tank her thrusters do nothing")
	naval_check(!T.lay_course(SB.x, SB.y, "Beta station") && helm.z == alpha && !T.on_course, "nor can she leave")
	helm.propellant = 60
	naval_check(isnull(helm.thrust(EAST, 3)) && helm.thrust_left == 3, "with propellant aboard a burn of three tiles is ordered")
	var/moved = 0
	var/crate_glide = crate.glide_size
	var/step_glide = craft_glide_size(SPACECRAFT_STEP_DELAY)
	var/glided = TRUE
	while (helm.thrust_left > 0 && moved < 10)
		if (!helm.thrust_one())
			break
		moved++
		// Each tile is drawn as a glide lasting the step (craft/glide.dm).
		glided = glided && crate.glide_size == step_glide && helm.glide_size == step_glide
	naval_check(glided && step_glide > 0 && length(B.glide_was), "each thruster step glides what she carries for the whole step ([crate.glide_size] of [step_glide])")
	B.glide_rest_now()
	naval_check(crate.glide_size == crate_glide && !length(B.glide_was), "at rest everything aboard has its own glide back")
	naval_check(moved == 3 && helm.x == 23 && Q.x == 23 && A.x == 27 && crate.x == 22 && crew.x == 24 && helm.propellant == 57, "she moves three tiles east with everything aboard for three units of propellant")
	naval_check(istype(locate(18, 20, alpha), /turf/floor/space/orbit) && istype(locate(20, 20, alpha), /turf/floor/space/orbit) && istype(locate(21, 18, alpha), /turf/wall/habitat_shell) && istype(locate(23, 20, alpha), /turf/floor/habitat) && istype(locate(29, 22, alpha), /turf/wall/habitat_shell), "space closes behind her and her walls and floors are where she is")
	naval_check(probe_count(alpha, /turf/wall/habitat_shell) + probe_count(alpha, /turf/floor/habitat) == 45 && !Q.breaches() && !A.breaches() && Q.air_oxygen == air_was && Q.air().breathable(), "her hull is whole and her air is the air she had")
	naval_check(locate(/obj/structure/simple_door/habitat_hatch) in locate(25, 20, alpha), "the hatch between her modules came along")
	var/obj/structure/probe_rock/rock = new(locate(31, 21, alpha))
	helm.thrust(EAST, 4)
	naval_check(helm.thrust_one() && !helm.thrust_one() && helm.x == 24 && helm.thrust_left == 0 && findtext(B.last_refusal, "probe rock") && helm.propellant == 56, "she stops short of a rock in her way ([B.last_refusal])")
	qdel(rock)
	naval_check(!B.turn_to(EAST), "she does not turn")

	// ---- Leaving for the lanes ----
	naval_check(T.lay_course(SB.x, SB.y, "Beta station") && T.on_course, "a course is laid for the other station")
	var/lanes = helm.z
	var/datum/plane_pool/orbit/pool = orbit_pool()
	var/list/slot = pool.slot_of(helm.ship_id)
	naval_check(lanes == 4 && orbit_plane_owner(lanes) == "transit" && helm.in_lanes() && isnull(helm.lies_at()) && slot && slot[1] == lanes, "she is taken into the lanes, a plane of their own, and holds a slot there")
	naval_check(!probe_count(alpha, /turf/wall/habitat_shell) && !probe_count(alpha, /turf/floor/habitat) && probe_count(lanes, /turf/wall/habitat_shell) + probe_count(lanes, /turf/floor/habitat) == 45, "nothing of her is left at the station")
	naval_check(Q.z == lanes && A.z == lanes && crate.z == lanes && crew.z == lanes && !Q.breaches() && get_dist(Q, helm) == 1, "her modules, cargo and crew went with her")
	orbit_chart()
	naval_check(C.stations.len == 2 && isnull(orbit_chart_station("transit")), "the lanes are not charted as a station")
	naval_check(findtext(helm.thrust(NORTH, 1), "nothing near"), "thrusters have nothing to steer by out there")

	// ---- Crossing and arriving ----
	var/steps = probe_passage(helm)
	naval_check(steps > 0 && T.x == SB.x && T.y == SB.y && helm.propellant < 56, "her token crosses the chart to the station, burning propellant ([steps] steps, [helm.propellant] left)")
	naval_check(helm.in_lanes(), "a station that does not welcome her party leaves her holding off")
	var/obj/structure/habitat_core/station = habitat_unfold(locate(33, 33, beta), "station")
	var/obj/structure/docking_port/port = new(locate(33, 34, beta))
	port.welcome = "everyone"
	helm.party = "civ:gaia:Alpha"
	naval_check(spacecraft_welcome(beta, "civ:gaia:Alpha") && spacecraft_welcome(beta, "civ:gaia:Beta") && !spacecraft_welcome(beta, null) && spacecraft_welcome(1, null), "a port open to everyone welcomes a party, the station's own party is always welcome, and the arrival plane takes anyone")
	naval_check(helm.arrive() && helm.z == beta && helm.lies_at() == SB && isnull(pool.slot_of(helm.ship_id)), "welcomed, she is moved to lie off the station and gives her slot back")
	var/near = 99
	for (var/turf/hull in B.cells())
		near = min(near, get_dist(hull, station))
	naval_check(near >= 2 + 2 + 1 && near <= 20 && probe_count(beta, /turf/wall/habitat_shell) == 16 + 25 && station.z == beta && !station.breaches(), "she lies clear of the station's hull and near it ([near] tiles from its core)")
	naval_check(crew.z == beta && crate.z == beta && !Q.breaches() && Q.air_oxygen == air_was, "with her crew, cargo and air")
	naval_check(!length(orbit_owned_planes("transit")) || !probe_count(lanes, /turf/wall/habitat_shell), "and the lanes are empty behind her")

	// ---- A restart ----
	helm.before_save()
	helm.drop_ship()
	T = helm.helm_token()
	S = helm.ship
	B = S ? S.body : null
	naval_check(T && S && S.name == "Kestrel" && T.x == SB.x && T.y == SB.y && B.tile_count() == 45, "her ship and token are made again from the helm where she lies")

	// ---- Home to the beacon ----
	naval_check(T.lay_course(C.arrival.x, C.arrival.y, "arrival beacon") && helm.in_lanes(), "she leaves again for the arrival beacon")
	probe_passage(helm)
	naval_check(helm.z == 1 && helm.lies_at() == C.arrival && !helm.in_lanes(), "and is taken in there without a welcome ([helm.z])")

	// ---- Too big to fly ----
	var/turf/core_at = get_turf(Q)
	for (var/i = 1, i <= 4, i++)
		habitat_unfold(locate(core_at.x, core_at.y + 4 * i, 1), "storage")
	helm.helm_token()
	B = helm.ship.body
	naval_check(B.cores.len == 6 && findtext(B.fault, "a station, not a ship") && findtext(helm.depart(), "a station, not a ship") && !helm.in_lanes(), "six modules are a station, not a ship ([B.fault])")
	naval_check(findtext(helm.read_text(), "cannot fly"), "and the console says so")

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
