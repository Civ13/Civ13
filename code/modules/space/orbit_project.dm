// ============================================================
// Starter stations (orbital stations, stage B, 1969)
// ------------------------------------------------------------
// A party can always fly kits up and build a station from scratch. The
// shortcut is a project like the party train (persistence/party_train.dm):
// a launch complex office built beside a launch pad approved for an orbit
// region takes deliveries, and once every line is met its party's members
// board it to their station.
//
// The station is founded by the first member to arrive: it claims a free
// plane (owner "station:<party>"), and builds the starter layout in the
// middle (see "layout" below): a hub with the life support, a workshop with
// the console, a crate of supplies and the return hatch home, quarters, an
// airlock, and a keel of truss and cable carrying the solar wings, the fuel
// cell and the reboost thruster.
// Later arrivals come aboard at the hatch. When every plane is taken the
// office refuses before launch, unless the party already has its station.
//
// The station registry is the plane registry (orbit_world.dm): a station is
// the planes its party owns. The orbit console reads it for status and lists
// the lost drifters it can recover (orbit_eva.dm).
// ============================================================

#define ORBIT_PROJECT_PAD_RANGE 3
#define ORBIT_RECOVERY_DELAY 100

// Material kind = list(stack type, amount needed, label), for the starter layout.
var/global/list/orbit_station_requirements = list(
	"steel" = list(/obj/item/stack/material/steel, 180, "steel"),
	"glass" = list(/obj/item/stack/material/glass, 40, "glass"),
	"copper" = list(/obj/item/stack/material/copper, 40, "copper"),
	"electronics" = list(/obj/item/stack/material/electronics, 60, "electronics"))

/proc/orbit_station_owner(party)
	return "station:[party]"

// The planes a party's station stands on, lowest first.
/proc/orbit_station_planes(party)
	if (!party_train_valid_party(party))
		return list()
	return orbit_owned_planes(orbit_station_owner(party))

// The party whose station owns plane z, or null.
/proc/orbit_station_party(z)
	var/owner = orbit_plane_owner(z)
	if (!istext(owner) || findtext(owner, "station:") != 1)
		return null
	return copytext(owner, 9)

// The habitat modules of the station on plane z (console API).
/proc/orbit_station_modules(z)
	var/list/found = list()
	for (var/obj/structure/habitat_core/C in habitat_cores)
		if (!QDELETED(C) && C.z == z)
			found += C
	return found

// ---------------------------------------------------------------- the office

/obj/structure/region_gate/launch_complex
	name = "launch complex office"
	desc = "A launch control office and assembly hall. A party can have its first space station built and launched here."
	icon = 'icons/obj/computers.dmi'
	icon_state = "solar_screen"
	density = TRUE
	crushable = FALSE
	map_storage_saved_vars = "icon_state;dir;name;pixel_x;pixel_y;party;delivered;completed;completed_at;boarded"
	var/party = null
	var/list/delivered = list()
	var/completed = FALSE
	var/completed_at = null // realtime text, for players and logs
	// Someone has flown up, so the party holds a station plane.
	var/boarded = FALSE

/obj/structure/region_gate/launch_complex/New()
	..()
	if (!islist(delivered))
		delivered = list()

/obj/structure/region_gate/launch_complex/ex_act(severity)
	return

/obj/structure/region_gate/launch_complex/accepts_arrivals()
	return FALSE

// The approved launch pad to orbit within reach, or null.
/obj/structure/region_gate/launch_complex/proc/launch_pad()
	if (!isturf(loc))
		return null
	for (var/obj/structure/region_gate/trail_marker/launch_pad/P in range(ORBIT_PROJECT_PAD_RANGE, src))
		if (P.approved && P.destination && space_flight_orbit_ok(P.destination))
			return P
	return null

/obj/structure/region_gate/launch_complex/proc/remaining()
	var/list/left = list()
	for (var/kind in orbit_station_requirements)
		var/list/need = orbit_station_requirements[kind]
		var/missing = need[2] - (delivered[kind] || 0)
		if (missing > 0)
			left[kind] = missing
	return left

/obj/structure/region_gate/launch_complex/proc/progress_text()
	var/list/parts = list()
	for (var/kind in orbit_station_requirements)
		var/list/need = orbit_station_requirements[kind]
		parts += "[need[3]] [delivered[kind] || 0]/[need[2]]"
	return jointext(parts, ", ")

/obj/structure/region_gate/launch_complex/closed_reason()
	if (!completed)
		return party ? "[party_train_party_name(party)] is building a station here: [progress_text()]." : "No station is being built here yet."
	var/obj/structure/region_gate/trail_marker/launch_pad/P = launch_pad()
	if (!P)
		return "The station is ready, but it needs a launch pad approved for orbit within [ORBIT_PROJECT_PAD_RANGE] tiles of the office."
	destination = P.destination
	if (!boarded && space_flight_orbit_full(destination))
		return "Every plane in [destination_name()] is taken. Wait until one is freed."
	return ..()

/obj/structure/region_gate/launch_complex/depart(mob/living/human/H)
	. = ..()
	if (. == "departed")
		boarded = TRUE

/obj/structure/region_gate/launch_complex/travel_party(mob/living/human/H)
	return party

/obj/structure/region_gate/launch_complex/travel_refusal(mob/living/human/H)
	. = ..()
	if (.)
		return
	if (!party_train_may_board(H, party))
		return "This station belongs to [party_train_party_name(party)]."

/obj/structure/region_gate/launch_complex/attack_hand(mob/living/human/user)
	if (!istype(user) || !user.client)
		return
	if (party && !completed && !length(remaining()))
		complete(user)
	if (completed)
		return ..()
	if (!party)
		start(user)
		return
	to_chat(user, SPAN_NOTICE(closed_reason()))

/proc/orbit_project_office_of(party, exclude = null)
	for (var/obj/structure/region_gate/launch_complex/S in region_gates)
		if (S != exclude && S.party == party && !QDELETED(S))
			return S
	return null

// Null when user's party may start a project here, otherwise why not.
/obj/structure/region_gate/launch_complex/proc/start_refusal(mob/living/human/user, new_party)
	if (!shard_group.enabled)
		return "No orbit serves this land."
	if (!map || map.ordinal_age < ORBIT_MIN_AGE)
		return "Stations can be launched from 1969."
	if (!launch_pad())
		return "A station needs a launch pad approved for orbit within [ORBIT_PROJECT_PAD_RANGE] tiles of the office."
	if (!new_party)
		return "You have no party to build for."
	var/obj/structure/region_gate/launch_complex/other = orbit_project_office_of(new_party, src)
	if (other)
		return "[party_train_party_name(new_party)] already has a station project at [other.x],[other.y]."
	return null

/obj/structure/region_gate/launch_complex/proc/start(mob/living/human/user)
	if (IsGuestKey(user.client.key))
		to_chat(user, SPAN_WARNING("Only players with a BYOND account can build a station."))
		return
	var/new_party = party_train_party_of(user)
	var/reason = start_refusal(user, new_party)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	if (alert(user, "Start building [party_train_party_name(new_party)]'s space station here? Bring [progress_text()] to finish it.", "Space station", "Start", "Cancel") != "Start")
		return
	// The prompt slept: check again.
	if (QDELETED(src) || party || !user.client || !Adjacent(user) || party_train_party_of(user) != new_party)
		return
	reason = start_refusal(user, new_party)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	party = new_party
	log_game("Orbit station: [key_name(user)] started a station for [party] at [x],[y],[z].")
	visible_message(SPAN_NOTICE("[user] starts a space station project for [party_train_party_name(party)]."))

/obj/structure/region_gate/launch_complex/attackby(obj/item/W, mob/user)
	if (!istype(W, /obj/item/stack) || completed || !party)
		return ..()
	var/obj/item/stack/S = W
	for (var/kind in orbit_station_requirements)
		var/list/need = orbit_station_requirements[kind]
		if (!stack_matches_recipe_material(S, need[1]))
			continue
		var/missing = need[2] - (delivered[kind] || 0)
		if (missing <= 0)
			to_chat(user, SPAN_NOTICE("The station needs no more [need[3]]."))
			return TRUE
		var/amount = min(missing, S.amount)
		if (amount < 1 || !S.use(amount))
			return TRUE
		delivered[kind] = (delivered[kind] || 0) + amount
		to_chat(user, SPAN_NOTICE("You hand over [amount] [need[3]]. [progress_text()]."))
		if (!length(remaining()))
			complete(user)
		return TRUE
	return ..()

/obj/structure/region_gate/launch_complex/proc/complete(mob/user)
	if (completed)
		return
	completed = TRUE
	completed_at = time2text(world.realtime, "YYYY-MM-DD hh:mm")
	log_game("Orbit station: [party] finished its station at [x],[y],[z][user ? " ([key_name(user)])" : ""].")
	visible_message(SPAN_NOTICE("The station of [party_train_party_name(party)] is ready on the pad. Its members can fly up to it from here."))

/obj/structure/region_gate/launch_complex/examine(mob/user)
	..()
	if (completed && party)
		to_chat(user, SPAN_NOTICE("It launched the station of [party_train_party_name(party)] (since [completed_at])."))

// ---------------------------------------------------------------- arrival

// Where a station trip arrives on an orbit world: the party's return hatch,
// founding the station on a free plane first. Null when it cannot be built
// (the traveller then arrives at the arrival point). Never sleeps.
/proc/orbit_station_arrival_turf(list/P)
	var/party = P["party"]
	if (!orbit_world() || !party_train_valid_party(party))
		return null
	var/obj/structure/region_gate/station_hatch/hatch = orbit_station_hatch(party)
	if (!hatch)
		var/z = orbit_claim_plane(orbit_station_owner(party))
		if (!z)
			message_admins("Orbit station: every plane is taken; [html_encode(party_train_party_name(party))] arrived without a station.")
			return null
		hatch = orbit_found_station(party, z)
		if (!hatch)
			orbit_release_plane(z)
			return null
		log_game("Orbit station: [party] founded its station on plane [z].")
	var/from = P["from"]
	if (istext(from) && shard_group.enabled && (from in shard_group.peers))
		hatch.home_region = from
	return isturf(hatch.loc) ? hatch.loc : null

/proc/orbit_station_hatch(party)
	for (var/obj/structure/region_gate/station_hatch/H in region_gates)
		if (H.party == party && !QDELETED(H) && isturf(H.loc))
			return H
	return null

// A cable piece on T running dir (NORTH: vertical, EAST: horizontal).
/proc/orbit_station_cable(turf/T, direction)
	var/obj/structure/cable/C = new(T)
	C.cable_color = "yellow"
	C.d1 = 0
	C.d2 = direction
	C.tiledir = (direction == NORTH || direction == SOUTH) ? "vertical" : "horizontal"
	C.update_icon()
	for (var/obj/structure/cable/N in range(1, C))
		if (N != C && N.tiledir == C.tiledir && N.cable_color == C.cable_color && ((C.tiledir == "vertical" && N.x == C.x) || (C.tiledir == "horizontal" && N.y == C.y)))
			N.connections |= C
			C.connections |= N
	return C

/proc/orbit_station_attach(obj/O, obj/structure/cable/C)
	O.powersource = C
	C.connections |= O

// ---------------------------------------------------------------- layout

// The station is a hub with arms and a keel (north is up, c = cx,cy):
//
//                  [quarters]              2013 only
//    [greenhouse]  [  hub   ]  [workshop]  1969: hub = workshop, quarters east
//                  [airlock ]
//                      |  porch truss outside the outer hatch
//                      |  keel: truss and the cable spine
//              wing ===+=== wing            cross boom, both wings
//                   [isotope]               2013 only
//                  [fuel cell]
//                  [thruster]               aft, pointed along the orbit
//
// The hub holds the life support in its corners, so with the hatches open it
// serves every arm one hop away; its edge-centre tiles stay clear for the
// doorways and the deck hatch stays free for a deck above or below. The
// return capsule hatch, the console and the supply crate are in the
// workshop. Every piece of outside hardware stands on or beside the keel, so
// a suited crew member can reach it hand over hand without drifting.

#define ORBIT_KEEL_PORCH 7 // the porch truss, outside the airlock's outer hatch
#define ORBIT_KEEL_BOOM 9 // the solar cross boom
#define ORBIT_KEEL_BOOM_REACH 3 // half the boom's width
#define ORBIT_KEEL_ISOTOPE 10
#define ORBIT_KEEL_FUEL 11
#define ORBIT_KEEL_AFT 12 // the thruster, the end of the keel

// A straight cable run between two turfs on one row or column, returning the
// pieces laid. Crossings get a junction connector.
/proc/orbit_station_cable_run(x1, y1, x2, y2, z)
	var/list/laid = list()
	var/direction = (x1 == x2) ? NORTH : EAST
	for (var/x = min(x1, x2), x <= max(x1, x2), x++)
		for (var/y = min(y1, y2), y <= max(y1, y2), y++)
			var/turf/T = locate(x, y, z)
			if (!T)
				continue
			var/crossing = locate(/obj/structure/cable) in T
			laid += orbit_station_cable(T, direction)
			if (crossing && !(locate(/obj/item/connector) in T))
				var/obj/item/connector/junction = new(T)
				junction.anchored = TRUE
				junction.connect_cables()
	return laid

// Places a piece of hardware on x,y and wires it to the cable there, if any.
/proc/orbit_station_place(path, x, y, z)
	var/turf/T = locate(x, y, z)
	if (!T)
		return null
	var/obj/O = new path(T)
	for (var/obj/structure/cable/C in T)
		orbit_station_attach(O, C)
		break
	return O

// A truss on every listed turf that holds no hardware yet.
/proc/orbit_station_truss(list/turfs)
	for (var/turf/T in turfs)
		var/taken = FALSE
		for (var/obj/O in T)
			if (O.density || istype(O, /obj/structure/orbit_truss))
				taken = TRUE
				break
		if (!taken)
			new /obj/structure/orbit_truss(T)

// Builds the station layout around the middle of plane z and returns the
// return capsule hatch, or null when the layout does not fit. The 1969 layout
// is a workshop hub, quarters east and an airlock south, with a keel below
// carrying two fixed solar wings on a cross boom, a fuelled fuel cell and the
// reboost thruster. From 2013 the hub is a node module (its deck hatch ready
// for a second deck) with the workshop east, a greenhouse west, quarters
// north and the airlock south; tracking arrays replace the wings and a
// radioisotope generator joins the keel, with six reboost burns and a node
// module kit in the crate.
/proc/orbit_found_station(party, z)
	var/modern = map && map.ordinal_age >= 8
	var/cx = round(world.maxx / 2)
	var/cy = round(world.maxy / 2)
	var/s = HABITAT_MODULE_SPACING
	var/r = HABITAT_MODULE_RADIUS
	var/turf/centre = locate(cx, cy, z)
	// Module centres by role; the hub comes first so the others dock to it.
	var/list/modules = list("hub" = centre, "workshop" = locate(cx + s, cy, z), "airlock" = locate(cx, cy - s, z))
	if (modern)
		modules["greenhouse"] = locate(cx - s, cy, z)
		modules["quarters"] = locate(cx, cy + s, z)
	var/low = cy - ORBIT_KEEL_AFT
	if (low < 2 || cx - ORBIT_KEEL_BOOM_REACH < 2 || cx + s + r > world.maxx - 1)
		return null
	for (var/role in modules)
		var/turf/at = modules[role]
		if (!at || at.x - r < 2 || at.y - r < 2 || at.x + r > world.maxx - 1 || at.y + r > world.maxy - 1 || habitat_module_refusal(at, null))
			return null
	// The hub: a node from 2013 (deck hatch south-east of the core), else the
	// workshop itself. Life support sits in its free corners.
	var/obj/structure/habitat_core/hub = modern ? habitat_unfold(centre, "node", /obj/structure/habitat_core/node, SOUTH, FALSE) : habitat_unfold(centre, "station", /obj/structure/habitat_core, SOUTH, FALSE)
	if (!hub)
		return null
	var/obj/structure/habitat_core/workshop = modern ? habitat_unfold(modules["workshop"], "station", /obj/structure/habitat_core, SOUTH, FALSE) : hub
	if (!modern)
		habitat_unfold(modules["workshop"], "quarters")
	habitat_unfold(modules["airlock"], "airlock", /obj/structure/habitat_core/airlock, SOUTH)
	if (modern)
		habitat_unfold(modules["greenhouse"], "greenhouse")
		habitat_unfold(modules["quarters"], "quarters")
	// The cable spine runs down the hub's middle column, out through the
	// airlock to the keel, with a short bar along the hub's top row for the
	// heater and radiator and, from 2013, one along the bottom row for the
	// scrubber (in 1969 the scrubber sits between them on the top row, since
	// nothing docks north).
	var/list/spine = orbit_station_cable_run(cx, cy + 1, cx, low, z)
	orbit_station_cable_run(cx - 1, cy + 1, cx + 1, cy + 1, z)
	orbit_station_place(/obj/structure/life_support/heater, cx - 1, cy + 1, z)
	orbit_station_place(/obj/structure/life_support/radiator, cx + 1, cy + 1, z)
	if (modern)
		orbit_station_cable_run(cx - 1, cy - 1, cx, cy - 1, z)
		orbit_station_place(/obj/structure/life_support/scrubber, cx - 1, cy - 1, z)
	else
		orbit_station_place(/obj/structure/life_support/scrubber, cx, cy + 1, z)
	// The keel: a cross boom with a wing at each end, then the generators.
	var/boom_y = cy - ORBIT_KEEL_BOOM
	orbit_station_cable_run(cx - ORBIT_KEEL_BOOM_REACH, boom_y, cx + ORBIT_KEEL_BOOM_REACH, boom_y, z)
	var/wing_type = modern ? /obj/structure/civ_generator/solar/wing/tracking : /obj/structure/civ_generator/solar/wing
	for (var/dx in list(-ORBIT_KEEL_BOOM_REACH, ORBIT_KEEL_BOOM_REACH))
		var/obj/structure/civ_generator/solar/wing/S = orbit_station_place(wing_type, cx + dx, boom_y, z)
		S.enabled = TRUE
	if (modern)
		var/obj/structure/civ_generator/isotope/I = orbit_station_place(/obj/structure/civ_generator/isotope, cx, cy - ORBIT_KEEL_ISOTOPE, z)
		I.enabled = TRUE
	var/obj/structure/civ_generator/fuel_cell/F = orbit_station_place(/obj/structure/civ_generator/fuel_cell, cx, cy - ORBIT_KEEL_FUEL, z)
	F.hydrogen = F.tank_max
	F.oxygen = F.tank_max
	var/obj/structure/cable/joint = spine[1]
	joint.rebuild_supply()
	// The reboost thruster at the aft end of the keel, with its burns, and a
	// fresh orbit (orbit_upkeep.dm).
	var/obj/structure/orbit_thruster/thruster = new(locate(cx, low, z))
	thruster.propellant = ORBIT_REBOOST_COST * (modern ? 6 : 3)
	orbit_set_station_altitude(party, ORBIT_ALTITUDE_START)
	// Truss from the porch to the aft end, and along the boom, as handholds.
	var/list/frame = list()
	for (var/y = cy - ORBIT_KEEL_PORCH, y >= low, y--)
		frame += locate(cx, y, z)
	for (var/dx = -ORBIT_KEEL_BOOM_REACH, dx <= ORBIT_KEEL_BOOM_REACH, dx++)
		frame |= locate(cx + dx, boom_y, z)
	orbit_station_truss(frame)
	// The workshop: a bench (beside the core in 1969, where the machines take
	// the top row), the supply crate, the console and the way home.
	var/wx = workshop.x
	var/wy = workshop.y
	new /obj/structure/table(modern ? locate(wx, wy + 1, z) : locate(wx - 1, wy, z))
	var/obj/structure/closet/crate/crate = new(locate(wx - 1, wy - 1, z))
	for (var/path in list(/obj/item/habitat_sealant, /obj/item/habitat_sealant, /obj/item/clothing/suit/pressure_suit, /obj/item/clothing/suit/pressure_suit, /obj/item/clothing/head/pressure_helmet, /obj/item/clothing/head/pressure_helmet, /obj/item/pressure_tank, /obj/item/pressure_tank, /obj/item/pressure_suit_patch, /obj/item/eva_tether, /obj/item/eva_tether, /obj/item/stack/cable_coil/yellow))
		new path(crate)
	new /obj/item/sorbent_cartridge(crate)
	new /obj/item/sorbent_cartridge(crate)
	if (modern)
		new /obj/item/habitat_kit/node(crate)
	for (var/i in 1 to 6)
		new /obj/item/weapon/reagent_containers/food/snacks/MRE/generic(crate)
	for (var/i in 1 to 3)
		new /obj/item/weapon/reagent_containers/food/drinks/bottle/canteen(crate)
	new /obj/structure/orbit_console(locate(wx + 1, wy - 1, z))
	var/obj/structure/region_gate/station_hatch/hatch = new(locate(wx, wy - 1, z))
	hatch.party = party
	return hatch

#undef ORBIT_KEEL_PORCH
#undef ORBIT_KEEL_BOOM
#undef ORBIT_KEEL_BOOM_REACH
#undef ORBIT_KEEL_ISOTOPE
#undef ORBIT_KEEL_FUEL
#undef ORBIT_KEEL_AFT

// ---------------------------------------------------------------- way home

// The station's return capsule: it takes members home to their launch
// complex office (party_train_arrival_turf in persistence/party_train.dm).
/obj/structure/region_gate/station_hatch
	name = "return capsule hatch"
	desc = "The hatch of the capsule docked to this station. Members of its party ride it home to their launch complex."
	icon = 'icons/obj/decals_wider.dmi'
	icon_state = "rocket"
	density = FALSE
	anchored = TRUE
	crushable = FALSE
	map_storage_saved_vars = "icon_state;dir;name;pixel_x;pixel_y;party;home_region"
	var/party = null
	var/home_region = null

/obj/structure/region_gate/station_hatch/ex_act(severity)
	return

/obj/structure/region_gate/station_hatch/accepts_arrivals()
	return FALSE

/obj/structure/region_gate/station_hatch/travel_party(mob/living/human/H)
	return party

/obj/structure/region_gate/station_hatch/closed_reason()
	if (!party)
		return "The capsule is not docked to anyone's station."
	if (!home_region || !shard_group.enabled || !(home_region in shard_group.peers))
		return "Nobody knows the way home from here."
	destination = home_region
	return ..()

/obj/structure/region_gate/station_hatch/travel_refusal(mob/living/human/H)
	. = ..()
	if (.)
		return
	if (!party_train_may_board(H, party))
		return "This capsule belongs to [party_train_party_name(party)]."

// ---------------------------------------------------------------- console

// A person lost at an unlinked plane edge: on vacuum at the edge, out of reach
// of anything, and not drifting (orbit_eva.dm).
/proc/orbit_lost_drifters()
	var/list/lost = list()
	if (!orbit_world())
		return lost
	for (var/mob/living/human/H in human_mob_list)
		var/turf/floor/space/orbit/T = H.loc
		if (QDELETED(H) || H.stat == DEAD || !istype(T) || orbit_drifters[H])
			continue
		if (T.orbit_edge_side() && !T.orbit_seam_destination() && !T.orbit_handhold(H))
			lost += H
	return lost

/obj/structure/orbit_console
	name = "orbit console"
	desc = "Station status, the orbital day, and a winch and boom for bringing back anyone who has drifted away."
	icon = 'icons/obj/computers.dmi'
	icon_state = "solar_screen"
	anchored = TRUE
	density = TRUE
	flammable = FALSE

/obj/structure/orbit_console/proc/status_lines()
	var/list/lines = list()
	if (!orbit_world())
		lines += "No orbit to watch from here."
		return lines
	var/party = orbit_station_party(z)
	lines += party ? "Station of [party_train_party_name(party)]." : "No party owns this plane."
	lines += orbit_sunlit() ? "In sunlight for another [orbit_day_left()] seconds." : "In shadow for another [orbit_day_left()] seconds."
	if (party)
		var/km = orbit_station_altitude(party)
		var/band = orbit_altitude_band(km)
		lines += "Altitude [round(km)] km[band == "high" ? "" : (band == "low" ? ", sinking: reboost soon" : (band == "drag" ? ", in drag: reboost now" : ", skimming the atmosphere: reboost now"))]."
	// Every deck of the station (orbit_decks.dm), or just this plane.
	var/list/planes = party ? orbit_station_planes(party) : list(z)
	for (var/level in planes)
		for (var/obj/structure/habitat_core/C in orbit_station_modules(level))
			var/datum/habitat_ledger/L = C.air()
			var/holes = C.breaches()
			lines += "[capitalize(C.kind)] module[planes.len > 1 ? " (plane [level])" : ""]: [round(L.pressure_kpa())] kPa, [round(L.temperature)] C[holes ? ", [holes] breach[holes == 1 ? "" : "es"]" : ""]."
	return lines

/obj/structure/orbit_console/examine(mob/user)
	..()
	for (var/line in status_lines())
		to_chat(user, SPAN_NOTICE(line))

// Null when user may recover drifters from here, otherwise why not.
/obj/structure/orbit_console/proc/recovery_refusal(mob/user)
	if (!orbit_world())
		return "There is nothing to recover here."
	var/party = orbit_station_party(z)
	if (party && !party_train_may_board(user, party))
		return "The console is locked to [party_train_party_name(party)]."
	return null

// Brings H back beside the console. Returns TRUE when it did.
/obj/structure/orbit_console/proc/recover(mob/living/human/H)
	if (!H || !(H in orbit_lost_drifters()))
		return FALSE
	var/turf/T = get_turf(src)
	var/turf/to_turf = null
	for (var/turf/candidate in orange(1, T))
		if (candidate.density || istype(candidate, /turf/floor/space/orbit))
			continue
		var/blocked = FALSE
		for (var/atom/movable/A in candidate)
			if (A.density)
				blocked = TRUE
				break
		if (!blocked)
			to_turf = candidate
			break
	if (!to_turf)
		to_turf = T
	if (!persistence_movement_allowed(H, to_turf))
		return FALSE
	orbit_stop_drift(H)
	H.forceMove(to_turf)
	to_chat(H, SPAN_NOTICE("A line from the station catches you and reels you back in."))
	log_game("Orbit station: [key_name(H)] was recovered by the console at [x],[y],[z].")
	return TRUE

/obj/structure/orbit_console/attack_hand(mob/living/human/user)
	if (!istype(user) || !user.client)
		return
	for (var/line in status_lines())
		to_chat(user, SPAN_NOTICE(line))
	var/list/lost = orbit_lost_drifters()
	// Pods within range can be steered from here (orbit_pods.dm).
	var/list/pods = steerable_pods(user)
	if (pods.len && (!lost.len || WWinput(user, "Steer a module pod, or recover someone who has drifted away?", "Orbit console", "Steer a pod", list("Steer a pod", "Recover")) == "Steer a pod"))
		var/pick = WWinput(user, "Which pod?", "Orbit console", "Cancel", pods + "Cancel")
		if (pods[pick] && in_range(src, user))
			orbit_pod_steer(pods[pick], user)
		return
	if (!lost.len)
		return
	var/reason = recovery_refusal(user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	var/list/names = list()
	for (var/mob/living/human/H in lost)
		names["[H.real_name] (plane [H.z])"] = H
	var/choice = WWinput(user, "Someone has drifted out of reach. Bring them back?", "Orbit console", "Cancel", names + "Cancel")
	if (!choice || choice == "Cancel" || !names[choice])
		return
	to_chat(user, SPAN_NOTICE("You guide the boom and winch out to them..."))
	if (!do_after(user, ORBIT_RECOVERY_DELAY, src) || recovery_refusal(user))
		return
	if (!recover(names[choice]))
		to_chat(user, SPAN_WARNING("They are no longer out there to recover."))
