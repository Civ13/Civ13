// ============================================================
// Spacecraft (docs/craft-core.md, docs/orbital-stations-plan.md)
// ------------------------------------------------------------
// A spacecraft is habitat modules with an orbital helm in one of them: the
// module the helm stands in and every module docked to it, up to
// SPACECRAFT_MAX_MODULES. Her body is a turf body (craft/turf_body.dm), so
// her walls, floors, hatches, air, machines and crew all move as one.
//
// The helm (craft/chart_helm.dm) steers her token on the orbit chart
// (orbit_chart.dm):
//
//  - A burn or a course laid while she lies off a station takes her into the
//    lanes: a plane the plane pool keeps for craft in flight, where she has
//    a slot to herself while her token crosses the chart.
//  - When a course brings her token to a station, the arrival beacon or a
//    site (orbit_sites.dm) she is moved into clear space on that plane. A station takes her in when
//    her party owns it or one of its docking ports welcomes her party.
//  - Lying off a station her thrusters move her a tile at a time, a unit of
//    propellant a tile, to bring a hatch near.
//
// Where she is on the chart is read from the plane her hull lies on, so the
// helm saves only her name, her tank, her party and (with the base console)
// her token's place and motion. Nothing here stores world.time.
// ============================================================

#define SPACECRAFT_MAX_MODULES 5
#define SPACECRAFT_TANK 120
#define SPACECRAFT_THRUST 50
// Propellant a chart step at full burn costs.
#define SPACECRAFT_BURN_PER_STEP 0.25
#define SPACECRAFT_STEP_DELAY 5
#define SPACECRAFT_MAX_THRUST_TILES 8
// Clear tiles kept round a hull that arrives somewhere.
#define SPACECRAFT_BERTH_CLEAR 2
#define SPACECRAFT_LANES "transit"

var/global/list/spacecraft_helms = list()

// The core of the module whose floor T is, or null.
/proc/spacecraft_core_at(turf/T)
	if (!istype(T, /turf/floor/habitat))
		return null
	for (var/obj/structure/habitat_core/C in range(HABITAT_MODULE_RADIUS - 1, T))
		if (!QDELETED(C))
			return C
	return null

// ---------------------------------------------------------------- the body

/datum/craft_body/turfs/spacecraft
	hull_name = "spacecraft"
	open_turf = /turf/floor/space/orbit
	var/obj/structure/chart_helm/orbit/helm
	var/list/cores = list()
	var/fault = ""                // Why she cannot fly as she is built.

/datum/craft_body/turfs/spacecraft/Destroy()
	helm = null
	cores = null
	return ..()

/datum/craft_body/turfs/spacecraft/placed()
	return helm && !QDELETED(helm) && isturf(helm.loc) && helm.z == z && ..()

// Reads the hull again from the module the helm stands in: that module and
// every module docked to it. Sets fault when she cannot fly as built.
/datum/craft_body/turfs/spacecraft/proc/survey(obj/structure/habitat_core/start)
	fault = ""
	var/list/found = list(start)
	var/list/queue = list(start)
	while (queue.len)
		var/obj/structure/habitat_core/C = queue[1]
		queue.Cut(1, 2)
		for (var/d in cardinal)
			var/turf/far = get_turf(C)
			for (var/i in 1 to HABITAT_MODULE_SPACING)
				far = far ? get_step(far, d) : null
			var/obj/structure/habitat_core/N = far ? (locate(/obj/structure/habitat_core) in far) : null
			if (N && !QDELETED(N) && !(N in found))
				found += N
				queue += N
	cores = found
	z = start.z
	px = start.x
	py = start.y
	var/list/seen = list()
	var/list/of = list()
	var/r = HABITAT_MODULE_RADIUS
	for (var/obj/structure/habitat_core/C in found)
		for (var/dx = -r, dx <= r, dx++)
			for (var/dy = -r, dy <= r, dy++)
				var/key = "[C.x + dx - px],[C.y + dy - py]"
				if (seen[key])
					continue
				seen[key] = TRUE
				of += list(list(C.x + dx - px, C.y + dy - py))
	set_offsets(of)
	if (found.len > SPACECRAFT_MAX_MODULES)
		fault = "she is [found.len] modules, and more than [SPACECRAFT_MAX_MODULES] is a station, not a ship"
		return
	for (var/obj/structure/habitat_core/C in found)
		if (istype(C, /obj/structure/habitat_core/node))
			fault = "a node module joins her to other decks"
			return
		for (var/turf/T in C.ring())
			var/obj/structure/habitat_core/other = orbit_other_ring_core(T, C)
			if (other && !(other in found))
				fault = "her hull is built into another module at [T.x],[T.y]"
				return
		for (var/turf/T in C.interior())
			if (locate(/obj/structure/region_gate) in T)
				fault = "a gate aboard is fixed where it stands"
				return

/datum/craft_body/turfs/spacecraft/ready_refusal()
	if (length(fault))
		return fault
	return ..()

// She keeps clear of the seams at a plane's edge.
/datum/craft_body/turfs/spacecraft/tile_refusal(turf/D)
	var/m = ORBIT_SEAM_MARGIN
	if (D.x <= m || D.y <= m || D.x > world.maxx - m || D.y > world.maxy - m)
		return "the edge of the plane"
	return ..()

// Clear space for her on a level, nearest its middle: list(x, y) for
// shift(), or null with last_refusal set.
/datum/craft_body/turfs/spacecraft/proc/berth_on(level)
	var/why = ready_refusal()
	if (why)
		last_refusal = why
		return null
	var/w = beam_tiles()
	var/h = length_tiles()
	var/cx = round((world.maxx - w) / 2) + 1
	var/cy = round((world.maxy - h) / 2) + 1
	var/reach = max(world.maxx, world.maxy)
	var/c = SPACECRAFT_BERTH_CLEAR
	for (var/d = 0, d <= reach, d += 4)
		for (var/dx = -d, dx <= d, dx += 4)
			for (var/dy = -d, dy <= d, dy += 4)
				if (max(abs(dx), abs(dy)) != d)
					continue
				var/x = cx + dx
				var/y = cy + dy
				if (x < 1 || y < 1 || x + w - 1 > world.maxx || y + h - 1 > world.maxy)
					continue
				if (!plan(x, y, level))
					continue
				var/clear = TRUE
				for (var/turf/T in block(locate(max(1, x - c), max(1, y - c), level), locate(min(world.maxx, x + w - 1 + c), min(world.maxy, y + h - 1 + c), level)))
					if (level == z && contains(T))
						continue
					if (blocker(T))
						clear = FALSE
						break
				if (clear)
					return list(x, y)
	last_refusal = "there is no clear space to lie in"
	return null

// ---------------------------------------------------------------- the drive

/datum/craft_drive/spacecraft
	name = "main engine"
	thrust = SPACECRAFT_THRUST
	var/obj/structure/chart_helm/orbit/helm

/datum/craft_drive/spacecraft/Destroy()
	helm = null
	return ..()

/datum/craft_drive/spacecraft/fuel_left()
	return helm ? helm.propellant : 0

/datum/craft_drive/spacecraft/fuel_capacity()
	return SPACECRAFT_TANK

/datum/craft_drive/spacecraft/burn(share = 1)
	if (!ready())
		return 0
	var/need = clamp(share, 0, 1) * SPACECRAFT_BURN_PER_STEP
	if (need <= 0)
		return 1
	if (helm.propellant >= need)
		helm.propellant -= need
		return 1
	. = helm.propellant / need
	helm.propellant = 0

// ---------------------------------------------------------------- the token

/datum/chart_token/spacecraft
	var/obj/structure/chart_helm/orbit/helm

/datum/chart_token/spacecraft/Destroy()
	helm = null
	return ..()

// A burn or a course takes her into the lanes first.
/datum/chart_token/spacecraft/set_burn(new_heading, new_throttle)
	if (new_throttle > 0 && helm)
		var/why = helm.depart()
		if (why)
			helm.tell_crew(SPAN_WARNING("She stays where she lies: [why]."))
			return
	..()

/datum/chart_token/spacecraft/lay_course(x, y, place_name = "")
	if (chart_distance(src.x, src.y, x, y) <= CHART_ARRIVE_RANGE)
		if (helm)
			helm.tell_crew(SPAN_NOTICE("She is there already."))
		return FALSE
	if (helm)
		var/why = helm.depart()
		if (why)
			helm.tell_crew(SPAN_WARNING("She stays where she lies: [why]."))
			return FALSE
	return ..()

/datum/chart_token/spacecraft/arrived()
	if (helm)
		helm.arrive()

// ---------------------------------------------------------------- the lanes

// The slot of the lanes a ship holds or is given: list(z, n), or null.
/proc/spacecraft_lane_slot(id)
	var/datum/plane_pool/orbit/pool = orbit_pool()
	if (!pool || !istext(id) || !length(id))
		return null
	var/list/have = pool.slot_of(id)
	if (have)
		return have
	spacecraft_lanes_sweep()
	for (var/z in orbit_owned_planes(SPACECRAFT_LANES))
		var/n = pool.claim_slot(id, z)
		if (n)
			return list(z, n)
	// Like a station's own planes, the lanes are not held up by the pause.
	var/fresh = orbit_claim_plane(SPACECRAFT_LANES)
	if (!fresh)
		return null
	var/n = pool.claim_slot(id, fresh)
	return n ? list(fresh, n) : null

// Gives back the slots of ships that are no longer in the lanes.
/proc/spacecraft_lanes_sweep()
	var/datum/plane_pool/orbit/pool = orbit_pool()
	if (!pool)
		return
	var/list/flying = list()
	for (var/obj/structure/chart_helm/orbit/O in spacecraft_helms)
		if (!QDELETED(O) && isturf(O.loc) && O.in_lanes() && length(O.ship_id))
			flying[O.ship_id] = TRUE
	var/list/table = pool.slot_table()
	for (var/key in table.Copy())
		var/owner = table[key]
		if (istext(owner) && findtext(owner, "ship:") == 1 && !flying[owner])
			table -= key

// TRUE when a station plane takes in a ship of this party: her own station,
// a plane nobody's station owns, or a docking port that welcomes her.
/proc/spacecraft_welcome(level, party)
	var/station = orbit_station_party(level)
	if (!station || station == party)
		return TRUE
	if (!party)
		return FALSE
	for (var/obj/structure/docking_port/P in orbit_docking_ports)
		if (!QDELETED(P) && P.owner() == station && P.welcomes(party))
			return TRUE
	return FALSE

// ---------------------------------------------------------------- the helm

/obj/structure/chart_helm/orbit
	var/ship_name = ""
	var/ship_id = ""
	var/propellant = 0
	// The party of whoever last gave her an order: who she arrives as.
	var/party = null
	var/tmp/datum/craft/ship = null
	var/tmp/fault = ""
	var/tmp/thrust_left = 0
	var/tmp/thrust_dir = 0

/obj/structure/chart_helm/orbit/New()
	..()
	spacecraft_helms |= src

/obj/structure/chart_helm/orbit/Destroy()
	spacecraft_helms -= src
	thrust_left = 0
	if (ship)
		qdel(ship)
		ship = null
	return ..()

/obj/structure/chart_helm/orbit/proc/drop_ship()
	if (ship)
		qdel(ship)
		ship = null
	if (token)
		qdel(token)
		token = null

// The ship this helm steers, with her hull read again, or null with fault
// saying why there is none.
/obj/structure/chart_helm/orbit/helm_craft()
	var/turf/here = get_turf(src)
	var/obj/structure/habitat_core/C = isturf(loc) ? spacecraft_core_at(here) : null
	if (!C || !orbit_world())
		fault = "It must stand on the floor of a habitat module in orbit."
		drop_ship()
		return null
	for (var/obj/structure/chart_helm/orbit/O in spacecraft_helms)
		if (O != src && !QDELETED(O) && O.ship && !QDELETED(O.ship) && O.ship.body && O.ship.body.contains(here))
			fault = "The [O.ship.name] already has a helm."
			drop_ship()
			return null
	var/datum/craft_body/turfs/spacecraft/B
	if (!ship || QDELETED(ship) || !ship.body)
		ship = null
		B = new
		B.helm = src
		if (length(ship_name))
			B.hull_name = ship_name
		B.survey(C)
		ship = new /datum/craft(B)
		var/datum/craft_drive/spacecraft/D = new
		D.helm = src
		ship.add_drive(D)
		if (!length(ship_id))
			ship_id = "ship:[rand(100000, 999999)][rand(100, 999)]"
	else
		B = ship.body
		B.survey(C)
	fault = B.fault
	return ship

/obj/structure/chart_helm/orbit/proc/in_lanes()
	return orbit_plane_owner(z) == SPACECRAFT_LANES

// The token of the place her hull lies off, or null in the lanes.
/obj/structure/chart_helm/orbit/proc/lies_at()
	var/datum/chart/orbit/C = orbit_chart()
	if (!C || !isturf(loc))
		return null
	return C.place_of_owner(orbit_plane_owner(z))

/obj/structure/chart_helm/orbit/helm_token()
	var/datum/craft/S = helm_craft()
	if (!S)
		return null
	if (!token)
		var/datum/chart_token/spacecraft/fresh = new
		fresh.helm = src
		token = fresh
	. = ..()
	if (!token || !.)
		return
	token.sensor_range = ORBIT_CHART_SENSOR_RANGE
	token.craft = S
	S.token = token
	token.name = S.name
	// Lying off a place, she is where the place is.
	var/datum/chart_token/place = lies_at()
	if (place)
		token.x = place.x
		token.y = place.y
		token.vx = 0
		token.vy = 0
		token.throttle = 0
		token.stopping = FALSE
		token.on_course = FALSE

/obj/structure/chart_helm/orbit/proc/tell_crew(text)
	if (ship && !QDELETED(ship))
		ship.crew_message(text)

// Takes her from the place she lies off into the lanes. Returns null when
// she is there (or was already), else why she cannot leave.
/obj/structure/chart_helm/orbit/proc/depart()
	var/datum/craft/S = helm_craft()
	if (!S)
		return fault
	if (in_lanes())
		return null
	var/datum/craft_body/turfs/spacecraft/B = S.body
	var/why = B.ready_refusal()
	if (why)
		return why
	if (thrust_left > 0)
		return "her thrusters are still firing"
	if (propellant <= 0)
		return "her tank is dry"
	var/datum/plane_pool/orbit/pool = orbit_pool()
	var/list/slot = spacecraft_lane_slot(ship_id)
	if (!pool || !slot)
		return "the lanes are full"
	var/list/box = pool.slot_box(slot[2])
	var/x = box[1] + round((pool.slot_size - B.beam_tiles()) / 2)
	var/y = box[2] + round((pool.slot_size - B.length_tiles()) / 2)
	if (!B.shift(x, y, slot[1]))
		pool.release_slot(slot[1], slot[2])
		return B.last_refusal
	S.crew_message(SPAN_NOTICE("The [S.name] pulls away into open space."))
	return null

// The place her token has reached, or null.
/obj/structure/chart_helm/orbit/proc/landfall()
	var/datum/chart/orbit/C = orbit_chart()
	if (!C || !token)
		return null
	for (var/datum/chart_token/station/O in C.tokens)
		if (chart_distance(token.x, token.y, O.x, O.y) <= CHART_ARRIVE_RANGE)
			return O
	return null

// The level a place on the chart is, or 0.
/obj/structure/chart_helm/orbit/proc/level_of(datum/chart_token/station/place)
	if (!place)
		return 0
	if (place.owner == "arrival")
		return ORBIT_ARRIVAL_PLANE
	var/list/owned = orbit_owned_planes(place.owner)
	return owned.len ? owned[1] : 0

// Her token has reached the end of its course: she closes the place there.
// TRUE when she lies off it.
/obj/structure/chart_helm/orbit/proc/arrive()
	var/datum/craft/S = helm_craft()
	if (!S || !token || !in_lanes())
		return FALSE
	var/datum/chart_token/station/place = landfall()
	// A site is built when the first ship reaches it (orbit_sites.dm).
	var/datum/chart_token/station/site/found = place
	if (istype(found) && found.site)
		var/why = found.site.load()
		if (why)
			S.crew_message(SPAN_WARNING("The [S.name] cannot close [place.name]: [why]. She holds off in open space."))
			return FALSE
	var/level = level_of(place)
	if (!level)
		S.crew_message(SPAN_NOTICE("The [S.name] lies still in open space."))
		return FALSE
	if (!spacecraft_welcome(level, party))
		S.crew_message(SPAN_WARNING("[capitalize(place.name)] does not answer: no docking port there welcomes you. The [S.name] holds off in open space."))
		return FALSE
	var/datum/craft_body/turfs/spacecraft/B = S.body
	var/list/at = B.berth_on(level)
	if (!at || !B.shift(at[1], at[2], level))
		S.crew_message(SPAN_WARNING("The [S.name] cannot close [place.name]: [B.last_refusal]. She holds off in open space."))
		return FALSE
	var/datum/plane_pool/orbit/pool = orbit_pool()
	var/list/slot = pool ? pool.slot_of(ship_id) : null
	if (slot)
		pool.release_slot(slot[1], slot[2])
	helm_token()
	if (istype(found) && found.site)
		found.site.charted = TRUE
		found.site.visited = TRUE
	S.crew_message(SPAN_NOTICE("The [S.name] lies off [place.name]."))
	return TRUE

// ---- Thrusters ----

/obj/structure/chart_helm/orbit/proc/thrust_refusal()
	var/datum/craft/S = helm_craft()
	if (!S)
		return fault
	if (in_lanes())
		return "there is nothing near to steer by out here"
	var/datum/craft_body/turfs/spacecraft/B = S.body
	. = B.ready_refusal()
	if (.)
		return
	if (thrust_left > 0)
		return "her thrusters are already firing"
	if (propellant < 1)
		return "her tank is dry"
	return null

// Starts her moving up to tiles in a direction. Returns null or why not.
/obj/structure/chart_helm/orbit/proc/thrust(direction, tiles)
	. = thrust_refusal()
	if (.)
		return
	if (!(direction in cardinal))
		return "pick a direction"
	thrust_left = clamp(round(tiles), 1, SPACECRAFT_MAX_THRUST_TILES)
	thrust_dir = direction
	addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(spacecraft_thrust_step), src), SPACECRAFT_STEP_DELAY)
	return null

// One tile on her thrusters. TRUE when she moved.
/obj/structure/chart_helm/orbit/proc/thrust_one()
	var/datum/craft/S = helm_craft()
	var/datum/craft_body/turfs/spacecraft/B = S ? S.body : null
	var/turf/O = B ? B.origin() : null
	if (!O || propellant < 1)
		thrust_left = 0
		return FALSE
	var/dx = (thrust_dir == EAST) - (thrust_dir == WEST)
	var/dy = (thrust_dir == NORTH) - (thrust_dir == SOUTH)
	// Each tile is shown as a glide lasting the step (craft/glide.dm).
	B.glide_time = SPACECRAFT_STEP_DELAY
	var/moved = B.move_to(O.x + dx, O.y + dy, NORTH)
	B.glide_time = 0
	if (!moved)
		B.glide_rest(SPACECRAFT_STEP_DELAY)
		thrust_left = 0
		S.crew_message(SPAN_WARNING("Her thrusters cut out: [B.last_refusal]."))
		return FALSE
	propellant = max(0, propellant - 1)
	thrust_left = max(0, thrust_left - 1)
	if (propellant < 1 && thrust_left > 0)
		thrust_left = 0
		S.crew_message(SPAN_WARNING("Her thrusters sputter out: the tank is dry."))
	if (thrust_left <= 0)
		B.glide_rest(SPACECRAFT_STEP_DELAY)
	return TRUE

/proc/spacecraft_thrust_step(obj/structure/chart_helm/orbit/H)
	if (!H || QDELETED(H) || H.thrust_left <= 0)
		return
	if (H.thrust_one() && H.thrust_left > 0)
		addtimer(CALLBACK(GLOBAL_PROC, GLOBAL_PROC_REF(spacecraft_thrust_step), H), SPACECRAFT_STEP_DELAY)

// ---- At the console ----

/obj/structure/chart_helm/orbit/read_text()
	if (!helm_craft())
		return fault
	. = ..()
	var/datum/chart_token/place = lies_at()
	. += "<br>[place ? "She lies off [place.name]." : "She is in open space, in the lanes."]"
	. += "<br>Propellant: [round(propellant, 0.1)]/[SPACECRAFT_TANK]."
	if (length(fault))
		. += "<br>She cannot fly as she is: [fault]."

/obj/structure/chart_helm/orbit/attack_hand(mob/living/human/H)
	if (istype(H) && !helm_token())
		to_chat(H, SPAN_WARNING(fault))
		return
	return ..()

/obj/structure/chart_helm/orbit/extra_orders(mob/living/human/H)
	return list("Thrusters", "Name her")

/obj/structure/chart_helm/orbit/ordered(mob/living/human/H, choice)
	party = party_train_party_of(H)

/obj/structure/chart_helm/orbit/extra_order(mob/living/human/H, choice)
	if (choice == "Name her")
		var/new_name = player_input(H, "Name her.", name, ship_name || "spacecraft", "text", null, TRUE)
		if (!new_name || QDELETED(src) || get_dist(H, src) > 1)
			return
		new_name = sanitize(copytext(new_name, 1, 40))
		if (!length(new_name))
			return
		set_ship_name(new_name)
		to_chat(H, SPAN_NOTICE("She is the [ship_name]."))
		return
	var/why = thrust_refusal()
	if (why)
		to_chat(H, SPAN_WARNING("[capitalize(why)]."))
		return
	var/list/dirs = list("North" = NORTH, "East" = EAST, "South" = SOUTH, "West" = WEST)
	var/pick = WWinput(H, "Fire her thrusters which way? Each tile costs a unit of propellant ([round(propellant)] left).", name, "Cancel", list("North", "East", "South", "West", "Cancel"))
	if (!dirs[pick] || QDELETED(src) || get_dist(H, src) > 1)
		return
	var/tiles = player_input(H, "How many tiles (1 to [SPACECRAFT_MAX_THRUST_TILES])?", name, 1, "num", null, TRUE)
	if (!tiles || QDELETED(src) || get_dist(H, src) > 1)
		return
	why = thrust(dirs[pick], tiles)
	if (why)
		to_chat(H, SPAN_WARNING("[capitalize(why)]."))
		return
	tell_crew(SPAN_NOTICE("[H] fires the [ship ? ship.name : "ship"]'s thrusters."))

/obj/structure/chart_helm/orbit/proc/set_ship_name(new_name)
	ship_name = new_name
	if (!helm_craft())
		return
	var/datum/craft_body/turfs/spacecraft/B = ship.body
	B.hull_name = new_name
	ship.name = new_name
	if (token)
		token.name = new_name

/obj/structure/chart_helm/orbit/attackby(obj/item/W, mob/user)
	if (istype(W, /obj/item/weapon/reagent_containers) && W.reagents)
		var/amount = min(SPACECRAFT_TANK - propellant, W.reagents.get_reagent_amount("rocket_propellant"))
		if (amount <= 0)
			to_chat(user, SPAN_WARNING(propellant >= SPACECRAFT_TANK ? "Her tank is full." : "Her tank takes only rocket propellant."))
			return
		W.reagents.remove_reagent("rocket_propellant", amount)
		propellant += amount
		to_chat(user, SPAN_NOTICE("You fill her tank ([round(propellant)]/[SPACECRAFT_TANK])."))
		return
	return ..()
