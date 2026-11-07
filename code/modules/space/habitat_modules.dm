// ============================================================
// Habitat modules and life support (space settlement phase 3)
// ------------------------------------------------------------
// A module kit unpacks into a fixed 5x5 module: a ring of hull wall around a
// 3x3 floor with a habitat core in the middle. A module unpacked next to an
// existing one docks to it: the two share a wall, and the middle of that
// wall becomes a hatch. Each module is one habitat ledger (habitat_ledger.dm)
// kept as plain numbers on its core; the floor turfs ask the core within one
// tile for air, so no turf carries gas and nothing needs stamping on load.
//
// Every core ticks while the world has players (an empty module still leaks
// and cools); only breathing depends on who is inside. A ring tile that is
// not hull wall or a closed hatch is a breach, and an open hatch to another
// module mixes the two ledgers. Life support machines inside a module draw
// cable power and act on its ledger: the electrolyser splits water into
// oxygen, the scrubber removes CO2 and the heater holds 20 C. Plants growing
// in a module's hydroponics trays turn CO2 back into oxygen.
//
// Cable runs in through an open hatch like any other floor. Nothing here
// stores world.time.
// ============================================================

#define HABITAT_MODULE_RADIUS 2 // core to hull ring
#define HABITAT_MODULE_SPACING 4 // docked cores share a wall
#define HABITAT_DOCK_RANGE 6
#define HABITAT_TICK_SECONDS 2
#define HABITAT_SEA_OXYGEN_KPA 21
#define HABITAT_SEA_INERT_KPA 79
#define HABITAT_ROOM_C 20
#define HABITAT_CO2_TARGET_KPA 0.4
// Life support rates in kPa-tiles (or degrees) per second, with power.
#define HABITAT_ELECTROLYSIS_PER_SECOND 0.1
#define HABITAT_WATER_PER_OXYGEN 0.5
#define HABITAT_SCRUB_PER_SECOND 0.1
#define HABITAT_HEAT_PER_SECOND 0.5
// One growing plant turns this much CO2 into oxygen per second.
#define HABITAT_PLANT_PER_SECOND 0.005
// The airlock hand pump keeps this fraction of the air it moves.
#define HABITAT_PUMP_EFFICIENCY 0.95

var/global/list/habitat_cores = list()

// ---------------------------------------------------------------- turfs

/turf/wall/habitat_shell
	name = "habitat hull"
	desc = "Insulated, airtight panels of a habitat module."
	icon = 'icons/turf/wall_masks.dmi'
	icon_state = "sub0"
	opacity = 1
	density = 1
	flags = TURF_HAS_EDGES

/turf/floor/habitat
	name = "habitat floor"
	desc = "The grated floor of a sealed habitat module."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "steel_grid"

// The core whose air this floor shares: the one beside it, or, on a hatch
// tile between two modules, either neighbour (an open hatch mixes them).
/turf/floor/habitat/proc/habitat_core()
	for (var/obj/structure/habitat_core/C in range(1, src))
		if (!QDELETED(C))
			return C
	for (var/obj/structure/habitat_core/C in range(HABITAT_MODULE_RADIUS, src))
		if (!QDELETED(C) && (C.x == x || C.y == y))
			return C
	return null

/turf/floor/habitat/outside_air_breathable()
	var/obj/structure/habitat_core/C = habitat_core()
	return C ? C.air().breathable() : FALSE

/turf/floor/habitat/outside_ambient_c()
	var/obj/structure/habitat_core/C = habitat_core()
	return C ? C.air().temperature : barren_ambient_c()

// ---------------------------------------------------------------- hatch

/obj/structure/simple_door/habitat_hatch
	name = "habitat hatch"
	desc = "A pressure hatch between habitat modules, or out onto the surface."
	icon = 'icons/obj/doors/material_doors.dmi'
	icon_state = "blast"
	basic_icon = "blast"
	override_material = TRUE
	health = 1200
	initial_health = 1200

/obj/structure/simple_door/habitat_hatch/proc/is_open()
	return !density

// ---------------------------------------------------------------- core

/obj/structure/habitat_core
	name = "habitat core"
	desc = "The air and pressure hub of a habitat module."
	icon = 'icons/obj/computers.dmi'
	icon_state = "solar_screen"
	anchored = TRUE
	density = FALSE
	not_movable = TRUE
	not_disassemblable = TRUE
	flammable = FALSE
	layer = TURF_LAYER + 0.2
	var/kind = "quarters"
	// The module's air as plain numbers (habitat_ledger.dm).
	var/air_oxygen = 0
	var/air_co2 = 0
	var/air_inert = 0
	var/air_temperature = HABITAT_ROOM_C
	var/tmp/datum/habitat_ledger/ledger = null

/obj/structure/habitat_core/New()
	..()
	habitat_cores |= src
	processing_objects |= src

/obj/structure/habitat_core/Destroy()
	habitat_cores -= src
	processing_objects -= src
	ledger = null
	return ..()

/obj/structure/habitat_core/proc/volume()
	return (HABITAT_MODULE_RADIUS * 2 - 1) ** 2

/obj/structure/habitat_core/proc/air()
	if (!ledger)
		ledger = new /datum/habitat_ledger(volume())
		if (!ledger.from_list(list("volume" = volume(), "oxygen" = air_oxygen, "co2" = air_co2, "inert" = air_inert, "temperature" = air_temperature)))
			ledger.temperature = BARREN_AMBIENT_C
	return ledger

/obj/structure/habitat_core/proc/store_air()
	if (!ledger)
		return
	air_oxygen = ledger.oxygen
	air_co2 = ledger.co2
	air_inert = ledger.inert
	air_temperature = ledger.temperature

// A fresh module ships pressurised with sea-level air.
/obj/structure/habitat_core/proc/fill_fresh()
	ledger = null
	air_oxygen = HABITAT_SEA_OXYGEN_KPA * volume()
	air_co2 = 0
	air_inert = HABITAT_SEA_INERT_KPA * volume()
	air_temperature = HABITAT_ROOM_C

/obj/structure/habitat_core/proc/interior()
	var/turf/C = get_turf(src)
	if (!C)
		return list()
	var/r = HABITAT_MODULE_RADIUS - 1
	return block(locate(max(1, C.x - r), max(1, C.y - r), C.z), locate(min(world.maxx, C.x + r), min(world.maxy, C.y + r), C.z))

// The 16 hull tiles around the floor.
/obj/structure/habitat_core/proc/ring()
	var/list/tiles = list()
	var/turf/C = get_turf(src)
	if (!C)
		return tiles
	var/r = HABITAT_MODULE_RADIUS
	for (var/dy = -r, dy <= r, dy++)
		for (var/dx = -r, dx <= r, dx++)
			if (abs(dx) != r && abs(dy) != r)
				continue
			var/turf/T = locate(C.x + dx, C.y + dy, C.z)
			if (T)
				tiles += T
	return tiles

// The docked core beyond a ring tile in the middle of a side, if any.
/obj/structure/habitat_core/proc/neighbour_through(turf/T)
	var/dx = T.x - x
	var/dy = T.y - y
	if (dx && dy)
		return null
	var/turf/far = locate(x + ((dx > 0) - (dx < 0)) * HABITAT_MODULE_SPACING, y + ((dy > 0) - (dy < 0)) * HABITAT_MODULE_SPACING, z)
	if (!far)
		return null
	var/obj/structure/habitat_core/N = locate() in far
	return (N && !QDELETED(N)) ? N : null

// Open holes to the outside: ring tiles that are neither hull nor a closed
// hatch, except an open hatch into a docked module (that one mixes instead).
/obj/structure/habitat_core/proc/breaches()
	. = 0
	var/turf/C = get_turf(src)
	if (!C || length(ring()) < 16)
		return 16
	for (var/turf/T in ring())
		if (istype(T, /turf/wall/habitat_shell))
			continue
		var/obj/structure/simple_door/habitat_hatch/H = locate() in T
		if (H && !QDELETED(H))
			if (!H.is_open() || neighbour_through(T))
				continue
		.++

// Docked modules behind open hatches.
/obj/structure/habitat_core/proc/open_neighbours()
	var/list/found = list()
	for (var/turf/T in ring())
		var/obj/structure/simple_door/habitat_hatch/H = locate() in T
		if (!H || QDELETED(H) || !H.is_open())
			continue
		var/obj/structure/habitat_core/N = neighbour_through(T)
		if (N)
			found += N
	return found

/obj/structure/habitat_core/proc/breathers()
	. = 0
	for (var/turf/T in interior())
		for (var/mob/living/human/H in T)
			if (H.stat != DEAD)
				.++

/obj/structure/habitat_core/process()
	if (!clients.len)
		return
	barren_hazards_pulse()
	step_air(HABITAT_TICK_SECONDS, breathers())

// One bounded step: breathing, leaks and cooling, then plants and machines,
// then mixing through open hatches.
/obj/structure/habitat_core/proc/step_air(seconds, occupants)
	var/datum/habitat_ledger/L = air()
	if (!L.advance(seconds, occupants, breaches(), barren_ambient_c()))
		return FALSE
	var/dt = habitat_clamp(seconds, 0, HABITAT_MAX_STEP_SECONDS)
	for (var/turf/T in interior())
		for (var/obj/structure/hydroponics_tray/P in T)
			if (P.crop && P.stage > 0)
				var/turned = L.scrub_co2(HABITAT_PLANT_PER_SECOND * dt)
				L.add_gas(turned)
		for (var/obj/structure/life_support/M in T)
			if (M.work(L, dt))
				orbit_machine_heat(L, M, dt)
	orbit_module_heat(L, dt)
	for (var/obj/structure/habitat_core/N in open_neighbours())
		L.mix_with(N.air())
		N.store_air()
	store_air()
	return TRUE

/obj/structure/habitat_core/examine(mob/user)
	..()
	var/datum/habitat_ledger/L = air()
	to_chat(user, SPAN_NOTICE("[capitalize(kind)] module: [round(L.pressure_kpa())] kPa, [round(L.oxygen_kpa(), 0.1)] kPa oxygen, [round(L.co2_kpa(), 0.1)] kPa CO2, [round(L.temperature)] C."))
	var/holes = breaches()
	if (holes)
		to_chat(user, SPAN_DANGER("[holes] breach[holes == 1 ? "" : "es"] in the hull!"))
	else if (!L.breathable())
		to_chat(user, SPAN_WARNING("The air in here is not safe to breathe."))

// ---------------------------------------------------------------- airlock

/obj/structure/habitat_core/airlock
	name = "airlock core"
	desc = "The air hub of an airlock, with a hand pump to move its air into the module next door before the outer hatch opens, and back again."
	kind = "airlock"

// Moves up to amount (kPa-tiles, all gases in proportion) from one ledger to
// another; the pump keeps HABITAT_PUMP_EFFICIENCY of it. Returns what arrived.
/proc/habitat_move_gas(datum/habitat_ledger/source, datum/habitat_ledger/target, amount)
	var/total = source.oxygen + source.co2 + source.inert
	if (total <= 0 || amount <= 0)
		return 0
	var/f = min(1, amount / total)
	var/o = source.oxygen * f
	var/c = source.co2 * f
	var/n = source.inert * f
	source.oxygen -= o
	source.co2 -= c
	source.inert -= n
	target.add_gas(o * HABITAT_PUMP_EFFICIENCY, c * HABITAT_PUMP_EFFICIENCY, n * HABITAT_PUMP_EFFICIENCY)
	return (o + c + n) * HABITAT_PUMP_EFFICIENCY

// The docked module behind a closed hatch, which the pump works against.
/obj/structure/habitat_core/airlock/proc/pump_partner()
	for (var/turf/T in ring())
		var/obj/structure/simple_door/habitat_hatch/H = locate() in T
		if (H && !QDELETED(H) && !H.is_open())
			var/obj/structure/habitat_core/N = neighbour_through(T)
			if (N)
				return N
	return null

// "down" empties the airlock into its partner; "up" fills it back to the
// partner's pressure. Every hatch must be shut. Returns null or a reason.
/obj/structure/habitat_core/airlock/proc/pump(direction)
	if (breaches())
		return "Close every hatch first."
	var/obj/structure/habitat_core/N = pump_partner()
	if (!N)
		return "The airlock is not docked to a module."
	var/datum/habitat_ledger/A = air()
	var/datum/habitat_ledger/B = N.air()
	if (direction == "down")
		habitat_move_gas(A, B, A.oxygen + A.co2 + A.inert)
	else
		var/want = B.pressure_kpa() * A.volume - A.pressure_kpa() * A.volume
		if (want > 0)
			// Take enough from the partner that what arrives evens the pressures.
			var/take = want / (HABITAT_PUMP_EFFICIENCY + A.volume / B.volume)
			habitat_move_gas(B, A, take)
	A.clamp_contents()
	B.clamp_contents()
	store_air()
	N.store_air()
	return null

/obj/structure/habitat_core/airlock/attack_hand(mob/user as mob)
	if (!ishuman(user))
		return
	var/choice = WWinput(user, "Cycle the airlock with the hand pump. Shut both hatches first.", "Airlock", "Cancel", list("Pump down", "Pressurise", "Cancel"))
	if (choice != "Pump down" && choice != "Pressurise")
		return
	if (!in_range(src, user) || user.incapacitated())
		return
	to_chat(user, SPAN_NOTICE("You work the pump..."))
	if (!do_after(user, 50, src))
		return
	var/result = pump(choice == "Pump down" ? "down" : "up")
	if (result)
		to_chat(user, SPAN_WARNING(result))
		return
	to_chat(user, SPAN_NOTICE(choice == "Pump down" ? "The airlock hisses empty; the outer hatch is safe to open." : "The airlock fills back up to the module's pressure."))

// ---------------------------------------------------------------- kits

/obj/item/habitat_kit
	name = "habitat module kit"
	desc = "A folded quarters module. Use it where you stand and it unfolds into a 5x5 sealed module around you, docking to a module next to it."
	icon = 'icons/obj/storage.dmi'
	icon_state = "densecrate"
	w_class = ITEM_SIZE_HUGE
	var/kind = "quarters"
	var/core_type = /obj/structure/habitat_core

/obj/item/habitat_kit/greenhouse
	name = "greenhouse module kit"
	desc = "A folded greenhouse module with two hydroponics trays. Use it where you stand and it unfolds into a 5x5 sealed module around you."
	kind = "greenhouse"

/obj/item/habitat_kit/workshop
	name = "workshop module kit"
	desc = "A folded workshop module with a workbench. Use it where you stand and it unfolds into a 5x5 sealed module around you."
	kind = "workshop"

/obj/item/habitat_kit/storage
	name = "storage module kit"
	desc = "A folded storage module with two crates. Use it where you stand and it unfolds into a 5x5 sealed module around you."
	kind = "storage"

/obj/item/habitat_kit/airlock
	name = "airlock module kit"
	desc = "A folded airlock with an outer hatch on the side you face, or on the far side from the module it docks to."
	kind = "airlock"
	core_type = /obj/structure/habitat_core/airlock

// Where a module unpacked by someone at T goes: snapped to dock beside the
// nearest core within HABITAT_DOCK_RANGE, else centred on T.
/proc/habitat_module_site(turf/T)
	var/obj/structure/habitat_core/best = null
	for (var/obj/structure/habitat_core/C in habitat_cores)
		if (QDELETED(C) || C.z != T.z || get_dist(C, T) > HABITAT_DOCK_RANGE)
			continue
		if (!best || get_dist(C, T) < get_dist(best, T))
			best = C
	if (!best)
		return T
	var/dx = T.x - best.x
	var/dy = T.y - best.y
	if (!dx && !dy)
		return null
	var/dir = abs(dx) >= abs(dy) ? (dx > 0 ? EAST : WEST) : (dy > 0 ? NORTH : SOUTH)
	var/turf/site = get_turf(best)
	for (var/i in 1 to HABITAT_MODULE_SPACING)
		site = get_step(site, dir)
		if (!site)
			return null
	return site

// Null when a module can unfold around centre, otherwise why not. A tile on
// an existing module's hull is shared; every other tile must be clear open
// ground. The person unpacking may stand on the new floor but not its hull.
/proc/habitat_module_refusal(turf/centre, mob/user)
	if (!centre)
		return "There is no room for a module there."
	var/r = HABITAT_MODULE_RADIUS
	if (centre.x - r < 1 || centre.y - r < 1 || centre.x + r > world.maxx || centre.y + r > world.maxy)
		return "The module would not fit here."
	if (locate(/obj/structure/habitat_core) in centre)
		return "A module already stands here."
	for (var/turf/T in block(locate(centre.x - r, centre.y - r, centre.z), locate(centre.x + r, centre.y + r, centre.z)))
		var/on_ring = abs(T.x - centre.x) == r || abs(T.y - centre.y) == r
		if (on_ring && habitat_shared_hull(T))
			continue
		if (T.density || istype(T, /turf/floor/habitat) || istype(T, /turf/wall/habitat_shell) || istype(T, /turf/floor/lander_deck))
			return "Something is in the way at [T.x],[T.y]."
		for (var/atom/movable/A in T)
			if (A == user)
				if (on_ring)
					return "Stand where the module's floor will be, not on its hull."
				continue
			if (A.density || istype(A, /obj/structure/habitat_core) || istype(A, /mob/living))
				return "Something is in the way at [T.x],[T.y]."
	return null

// TRUE when T is the hull (or hatch) of an existing module.
/proc/habitat_shared_hull(turf/T)
	if (istype(T, /turf/wall/habitat_shell))
		return TRUE
	return istype(T, /turf/floor/habitat) && (locate(/obj/structure/simple_door/habitat_hatch) in T)

/obj/item/habitat_kit/attack_self(mob/user as mob)
	if (!ishuman(user) || !isturf(user.loc))
		return
	var/turf/centre = habitat_module_site(get_turf(user))
	var/reason = habitat_module_refusal(centre, user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	to_chat(user, SPAN_NOTICE("You start unfolding \the [src]..."))
	if (!do_after(user, 100, user))
		return
	// The wait slept: check again.
	centre = habitat_module_site(get_turf(user))
	reason = habitat_module_refusal(centre, user)
	if (reason)
		to_chat(user, SPAN_WARNING(reason))
		return
	var/obj/structure/habitat_core/C = habitat_unfold(centre, kind, core_type, user.dir)
	if (!C)
		return
	log_game("Habitat: [key_name(user)] unfolded a [kind] module at [C.x],[C.y],[C.z].")
	user.visible_message(SPAN_NOTICE("[user] unfolds \a [kind] module."))
	qdel(src)

// Builds the module. outer_dir is where an airlock's outer hatch goes when it
// docks to nothing. Returns the core.
/proc/habitat_unfold(turf/centre, kind, core_type = /obj/structure/habitat_core, outer_dir = SOUTH)
	var/r = HABITAT_MODULE_RADIUS
	var/z = centre.z
	var/list/docked_dirs = list()
	for (var/dir in cardinal)
		var/turf/far = centre
		for (var/i in 1 to HABITAT_MODULE_SPACING)
			far = far ? get_step(far, dir) : null
		if (far && (locate(/obj/structure/habitat_core) in far))
			docked_dirs += dir
	for (var/turf/T in block(locate(centre.x - r, centre.y - r, z), locate(centre.x + r, centre.y + r, z)))
		var/on_ring = abs(T.x - centre.x) == r || abs(T.y - centre.y) == r
		if (!on_ring)
			T.ChangeTurf(/turf/floor/habitat, FALSE, FALSE)
		else if (!habitat_shared_hull(T))
			T.ChangeTurf(/turf/wall/habitat_shell, FALSE, FALSE)
	// A hatch in the middle of each shared wall.
	for (var/dir in docked_dirs)
		habitat_place_hatch(get_step(get_step(centre, dir), dir))
	var/obj/structure/habitat_core/C = new core_type(centre)
	C.kind = kind
	C.name = "[kind] core"
	C.fill_fresh()
	if (kind == "airlock")
		var/outer = length(docked_dirs) ? turn(docked_dirs[1], 180) : outer_dir
		if (!(outer in cardinal))
			outer = SOUTH
		habitat_place_hatch(get_step(get_step(centre, outer), outer))
	habitat_furnish(C, kind)
	return C

/proc/habitat_place_hatch(turf/T)
	if (!T || (locate(/obj/structure/simple_door/habitat_hatch) in T))
		return
	T = T.ChangeTurf(/turf/floor/habitat, FALSE, FALSE)
	new /obj/structure/simple_door/habitat_hatch(T)

/proc/habitat_furnish(obj/structure/habitat_core/C, kind)
	var/turf/left = locate(C.x - 1, C.y + 1, C.z)
	var/turf/right = locate(C.x + 1, C.y + 1, C.z)
	switch (kind)
		if ("quarters")
			new /obj/structure/bed/lander_bunk(left)
			new /obj/structure/bed/lander_bunk(right)
		if ("greenhouse")
			new /obj/structure/hydroponics_tray(left)
			new /obj/structure/hydroponics_tray(right)
		if ("workshop")
			new /obj/structure/table(locate(C.x, C.y + 1, C.z))
		if ("station")
			new /obj/structure/bed/lander_bunk(locate(C.x - 1, C.y, C.z))
			new /obj/structure/bed/lander_bunk(locate(C.x + 1, C.y, C.z))
			new /obj/structure/closet/crate(locate(C.x - 1, C.y - 1, C.z))
		if ("orbital workshop")
			new /obj/structure/bed/lander_bunk(left)
			new /obj/structure/bed/lander_bunk(right)
			new /obj/structure/table(locate(C.x, C.y + 1, C.z))
			new /obj/structure/closet/crate(locate(C.x - 1, C.y - 1, C.z))
		if ("storage")
			new /obj/structure/closet/crate(left)
			new /obj/structure/closet/crate(right)

// ---------------------------------------------------------------- sealant

/obj/item/habitat_sealant
	name = "hull patch kit"
	desc = "Quick-setting panels and foam for patching a breach in a habitat module's hull. Use it on the hole."
	icon = 'icons/obj/storage.dmi'
	icon_state = "firstaid"
	w_class = ITEM_SIZE_NORMAL

// The core whose hull ring T is part of, or null.
/proc/habitat_ring_core(turf/T)
	if (!T)
		return null
	for (var/obj/structure/habitat_core/C in range(HABITAT_MODULE_RADIUS, T))
		if (!QDELETED(C) && max(abs(C.x - T.x), abs(C.y - T.y)) == HABITAT_MODULE_RADIUS)
			return C
	return null

/obj/item/habitat_sealant/afterattack(atom/target, mob/user, proximity)
	if (!proximity)
		return
	var/turf/T = get_turf(target)
	if (!habitat_patchable(T))
		return ..()
	to_chat(user, SPAN_NOTICE("You start patching the breach..."))
	if (!do_after(user, 50, T) || !habitat_patchable(T))
		return
	T.ChangeTurf(/turf/wall/habitat_shell, FALSE, FALSE)
	user.visible_message(SPAN_NOTICE("[user] seals the breach in the hull."))
	qdel(src)

// TRUE when T is a hole in a module's hull that a patch can close.
/proc/habitat_patchable(turf/T)
	if (!T || istype(T, /turf/wall/habitat_shell) || T.density || !habitat_ring_core(T))
		return FALSE
	if (locate(/obj/structure/simple_door/habitat_hatch) in T)
		return FALSE
	for (var/atom/movable/A in T)
		if (A.density || istype(A, /mob/living))
			return FALSE
	return TRUE

// ---------------------------------------------------------------- machines

/obj/structure/life_support
	name = "life support unit"
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "smes2"
	anchored = TRUE
	density = TRUE
	not_movable = FALSE
	powerneeded = 5

/obj/structure/life_support/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE(powersource ? "It is cabled to a power grid." : "Run a cable to it to power it."))
	if (!istype(get_turf(src), /turf/floor/habitat))
		to_chat(user, SPAN_WARNING("It only works inside a habitat module."))

/obj/structure/life_support/proc/has_power()
	return draw_cable_power()

// One step on the module's ledger L.
/obj/structure/life_support/proc/work(datum/habitat_ledger/L, seconds)
	return FALSE

/obj/structure/life_support/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/stack/cable_coil))
		if (powersource)
			to_chat(user, SPAN_WARNING("It is already cabled."))
			return
		var/obj/item/stack/cable_coil/CC = W
		var/obj/structure/cable/CB = CC.place_turf(get_turf(src), user, turn(get_dir(user, src), 180))
		if (!CB)
			return
		powersource = CB
		CB.connections |= src
		for (var/obj/structure/cable/N in range(1, CB))
			if (N != CB && N.cable_color == CB.cable_color && N.tiledir == CB.tiledir && ((CB.tiledir == "horizontal" && N.y == CB.y) || (CB.tiledir == "vertical" && N.x == CB.x)))
				CB.connections |= N
				N.connections |= CB
		CB.rebuild_supply()
		to_chat(user, SPAN_NOTICE("You cable \the [src]."))
		return
	return ..()

/obj/structure/life_support/electrolyser
	name = "electrolyser"
	desc = "Splits water into oxygen for the module and vents the hydrogen. Pour water in and cable it."
	powerneeded = 10
	var/water = 0
	var/water_max = 200

/obj/structure/life_support/electrolyser/examine(mob/user)
	..()
	to_chat(user, SPAN_NOTICE("Water: [round(water)]/[water_max] units."))

/obj/structure/life_support/electrolyser/attackby(obj/item/W as obj, mob/user as mob)
	if (istype(W, /obj/item/weapon/reagent_containers) && W.reagents)
		var/amount = min(water_max - water, W.reagents.get_reagent_amount("water"))
		if (amount <= 0)
			to_chat(user, SPAN_WARNING(water >= water_max ? "\The [src] is full." : "\The [src] takes only water."))
			return
		W.reagents.remove_reagent("water", amount)
		water += amount
		to_chat(user, SPAN_NOTICE("You fill \the [src] ([round(water)]/[water_max])."))
		return
	return ..()

/obj/structure/life_support/electrolyser/work(datum/habitat_ledger/L, seconds)
	var/want = HABITAT_SEA_OXYGEN_KPA * L.volume - L.oxygen
	if (want <= 0 || water <= 0 || !has_power())
		return FALSE
	var/made = min(want, HABITAT_ELECTROLYSIS_PER_SECOND * seconds, water / HABITAT_WATER_PER_OXYGEN)
	water = max(0, water - made * HABITAT_WATER_PER_OXYGEN)
	L.add_gas(made)
	return TRUE

/obj/structure/life_support/scrubber
	name = "CO2 scrubber"
	desc = "Draws the module's air through a regenerating sorbent bed to strip out carbon dioxide. Cable it."
	powerneeded = 5

/obj/structure/life_support/scrubber/work(datum/habitat_ledger/L, seconds)
	var/excess = L.co2 - HABITAT_CO2_TARGET_KPA * L.volume
	if (excess <= 0 || !has_power())
		return FALSE
	L.scrub_co2(min(excess, HABITAT_SCRUB_PER_SECOND * seconds))
	return TRUE

/obj/structure/life_support/heater
	name = "habitat heater"
	desc = "Keeps the module at room temperature against the cold outside. Cable it."
	powerneeded = 10

/obj/structure/life_support/heater/work(datum/habitat_ledger/L, seconds)
	if (L.temperature >= HABITAT_ROOM_C || !has_power())
		return FALSE
	L.temperature = min(HABITAT_ROOM_C, L.temperature + HABITAT_HEAT_PER_SECOND * seconds)
	return TRUE
