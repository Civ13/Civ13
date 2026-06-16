// ============================================================
// Submarine Areas
// ============================================================


// ============================================================
// Submarine Turfs - hull walls, bulkheads, and deck floors
// with water accumulation, atmospheric simulation, and
// compartment-based flooding physics.
// ============================================================

// ---- Hull Walls ----

/turf/wall/sub_hull
	name = "submarine pressure hull"
	icon = 'icons/turf/wall_masks.dmi'
	icon_state = "sub0"
	opacity = 1
	density = 1
	var/hull_integrity = 1000
	var/max_hull_integrity = 1000
	var/breached = FALSE           // TRUE when integrity <= 0
	var/breach_inflow_rate = 0     // cm of water added per tick while breached
	flags = TURF_HAS_EDGES

/turf/wall/sub_hull/New(var/newloc)
	..(newloc,"submarine hull")

/turf/wall/sub_hull/proc/apply_breach_damage(var/damage)
	hull_integrity -= damage
	if(hull_integrity <= 0 && !breached)
		breach_hull()

/turf/wall/sub_hull/proc/breach_hull()
	if(breached) return
	breached = TRUE
	breach_inflow_rate = SUB_BREACH_INFLOW_BASE
	visible_message("<span class='danger'><b>The hull buckles! Seawater erupts through the breach!</b></span>")
	playsound(src, 'sound/machines/submarine/hull_breach.ogg', 90, 1)

	// Find adjacent deck turfs and start continuous flooding
	for(var/turf/floor/sub_deck/D in range(1, src))
		D.add_water(SUB_BREACH_INFLOW_BASE)
		D.water_inflow_rate += SUB_BREACH_INFLOW_BASE  // Ongoing inflow each tick

	// Mark this wall as visually damaged
	overlays += image(icon='icons/turf/damage_overlays.dmi',icon_state=pick("damaged1","damaged2","damaged3"))
	overlays += image(icon='icons/obj/machines/submarine.dmi',icon_state="breach_glow")

/turf/wall/sub_hull/proc/repair_breach()
	if(!breached) return
	breached = FALSE
	breach_inflow_rate = 0
	hull_integrity = max_hull_integrity * 0.5  // Repaired to half
	icon_state = "metal0"
	overlays.Cut()  // Remove damage and breach glow overlays
	// Undo inflow rate on adjacent deck turfs
	for(var/turf/floor/sub_deck/D in range(1, src))
		D.water_inflow_rate = max(0, D.water_inflow_rate - SUB_BREACH_INFLOW_BASE)
	visible_message("<span class='notice'>The hull breach is sealed.</span>")

// ---- Bulkheads ----

/turf/wall/sub_bulkhead
	name = "internal bulkhead"
	icon = 'icons/turf/wall_masks.dmi'
	icon_state = "sub0"
	opacity = 1
	density = 1
	var/health = 200
	var/max_health = 200
	// Bulkheads are watertight: water does NOT flow through them by default
	var/watertight = TRUE
	flags = TURF_HAS_EDGES
	var/draw_color_lines = TRUE
	var/color_lines_color = "#007F00"

/turf/wall/sub_bulkhead/New(var/newloc)
	..(newloc,"submarine hull")

/turf/wall/sub_bulkhead/attackby(obj/item/weapon/W, mob/user)
	if(istype(W, /obj/item/weapon/weldingtool))
		if(health >= max_health && watertight)
			to_chat(user, "<span class='notice'>[src] is already in good condition.</span>")
			return
		if(!watertight)
			to_chat(user, "<span class='notice'>You begin welding the bulkhead seals back into place...</span>")
			playsound(src.loc, 'sound/machines/submarine/gas.ogg', 50, 1)
			if(do_after(user, 80, src))
				watertight = TRUE
				health = min(max_health, health + 60)
				icon_state = initial(icon_state)
				to_chat(user, "<span class='notice'>The bulkhead seals are restored. Watertight integrity re-established.</span>")
				playsound(src.loc, 'sound/machines/submarine/gas.ogg', 50, 1)
		else
			to_chat(user, "<span class='notice'>You begin welding cracks in the bulkhead...</span>")
			playsound(src.loc, 'sound/machines/submarine/gas.ogg', 50, 1)
			if(do_after(user, 40, src))
				health = min(max_health, health + 30)
				to_chat(user, "<span class='notice'>You repair some structural damage on the bulkhead.</span>")
		return
	..()

/turf/wall/sub_bulkhead/proc/take_bulkhead_damage(var/damage)
	health -= damage
	if(health <= 0)
		watertight = FALSE
		visible_message("<span class='warning'>The bulkhead crumples! It no longer holds back water.</span>")
		icon_state = "damaged"
	else if(health < max_health * 0.5)
		watertight = FALSE
		visible_message("<span class='warning'>The bulkhead buckles under pressure! Seals are compromised.</span>")

/turf/wall/sub_bulkhead/sub_shielding
	name = "lead reactor shielding"
	icon = 'icons/turf/wall_masks.dmi'
	icon_state = "solid0"
	opacity = 1
	density = 1
	var/rad_dampening = 1.0
	health = 400
	max_health = 400
	watertight = TRUE
	flags = TURF_HAS_EDGES

/turf/wall/sub_bulkhead/sub_shielding/New(var/newloc)
	..(newloc,"steel")

// ============================================================
// Deck Floor - the core of water/atmos simulation
// ============================================================

/turf/floor/sub_deck
	name = "deck floor"
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "steel_grid"

	// ---- Water Physics ----
	var/water_depth = 0            // Centimeters of water on this tile (0 = dry, 200 = fully flooded)
	var/max_water = 200            // Maximum water depth before tile is considered fully submerged
	var/water_inflow_rate = 0      // cm/tick added by adjacent breaches (set by hull breach procs)
	var/water_sealed = FALSE       // TRUE = watertight door/hatch preventing flow

	// ---- Compartment System ----
	var/compartment_id = ""        // Which compartment this tile belongs to (e.g. "forward_torpedo", "reactor_room")
	var/compartment_pressure = 1   // Atmosphere: 1.0 = 1 atm (normal), <1 = vacuum/low, >1 = overpressure

	// ---- Atmospheric Vars ----
	var/oxygen_moles = 20.0        // Moles of O2 in this tile's air
	var/co2_moles = 0.1            // Moles of CO2 (exhaled by mobs, produced by fires)
	var/atmos_temperature = 293.15 // Kelvin (20 C = 293.15 K) -- avoids collision with turf.temperature
	var/vent_active = FALSE        // Whether a ventilation duct is processing this tile
	var/vent_id = ""               // Links vents to their duct network

	// ---- Visual / Info ----
	var/water_warning_sent = FALSE  // Prevents spamming "water rising!" messages
	var/last_damage_tick = 0        // For drowning damage cooldown

	// ---- Fire State ----
	var/fire_active = FALSE         // TRUE if this tile is on fire
	var/fire_temperature = 0        // Current fire intensity (affects spread chance and damage)
	var/fire_duration = 0           // Ticks remaining before fire burns out

/turf/floor/sub_deck/New()
	..()
	// Register with the flooding controller
	if(global.subcom_flooding)
		global.subcom_flooding.register_turf(src)

/turf/floor/sub_deck/Destroy()
	if(global.subcom_flooding)
		global.subcom_flooding.unregister_turf(src)
	..()

// ============================================================
// Water Accumulation System
// ============================================================

// Add water to this tile (cm). Called by breaches, flooding, etc.
/turf/floor/sub_deck/proc/add_water(var/cm)
	if(water_sealed) return
	var/was_dry = water_depth < 1
	water_depth = min(water_depth + cm, max_water)
	refresh_water_overlay()
	if(was_dry && water_depth >= 1)
		playsound(src, 'sound/machines/submarine/flooding_start.ogg', 50, 1)
		world.log << "FLOOD DEBUG: Water=[cm]cm tile=[x],[y],[z] compartment=[compartment_id] total=[water_depth]"

// Remove water from this tile (cm). Called by bilge pumps, draining.
/turf/floor/sub_deck/proc/remove_water(var/cm)
	water_depth = max(0, water_depth - cm)
	refresh_water_overlay()

// Called each tick by the flooding controller - handles water spreading and drowning
/turf/floor/sub_deck/proc/flood_tick()
	// 1. Apply inflow from breaches
	if(water_inflow_rate > 0)
		add_water(water_inflow_rate)

	// 2. Water spreading: if this tile has water, it flows to adjacent lower-open tiles
	if(water_depth > 1)
		spread_water()

	// 3. Drowning damage to mobs
	if(water_depth >= 50)  // 50cm = ankle-deep, enough to start causing problems
		apply_drowning_damage()

	// 4. Atmospheric updates: significant water displaces oxygen
	if(water_depth >= 30)
		var/water_displacement = water_depth / max_water  // 0 to 1
		oxygen_moles = max(0, oxygen_moles * (1 - water_displacement * 0.3))
		compartment_pressure = max(0.3, 1.0 - (water_displacement * 0.7))

// Water flows to adjacent tiles with lower water depth
/turf/floor/sub_deck/proc/spread_water()
	if(water_depth <= 0) return
	if(compartment_id == "") return  // No compartment = no spreading logic

	for(var/direction in list(NORTH, SOUTH, EAST, WEST))
		var/turf/floor/sub_deck/neighbor = get_step(src, direction)
		if(!neighbor || !istype(neighbor)) continue
		if(neighbor.water_sealed) continue

		// Check for a blast door between these two tiles
		var/obj/structure/simple_door/blast/door = locate(/obj/structure/simple_door/blast) in get_step(src, direction)
		if(door)
			if(!door.state) continue  // Door is closed, block water
			// Door is open: allow flow across compartment boundaries
		else
			// No door: original compartment check
			if(neighbor.compartment_id != compartment_id && neighbor.compartment_id != "") continue

		var/delta = water_depth - neighbor.water_depth
		if(delta > 2)
			var/flow = min(delta * 0.25, 5)
			neighbor.add_water(flow)
			remove_water(flow)

// ============================================================
// Fire Spread System
// ============================================================

/turf/floor/sub_deck/proc/fire_tick()
	if(!fire_active) return

	// Water extinguishes fire
	if(water_depth > 50)
		extinguish_fire()
		return

	fire_duration--
	if(fire_duration <= 0)
		extinguish_fire()
		return

	// Damage mobs on this tile (supplements /obj/effect/fire's own damage)
	for(var/mob/living/L in src)
		if(prob(15))
			L.adjustBurnLoss(rand(3, 8))

	// Smoke effect
	if(prob(4))
		new/obj/effect/effect/smoke(src)

	// Spread: 5-8% chance per tick to ignite an adjacent sub_deck turf
	if(prob(rand(5, 8)))
		var/list/spread_dirs = list(NORTH, SOUTH, EAST, WEST)
		shuffle(spread_dirs)
		for(var/dir in spread_dirs)
			var/turf/floor/sub_deck/neighbor = get_step(src, dir)
			if(!neighbor || !istype(neighbor)) continue
			if(neighbor.fire_active) continue
			if(neighbor.water_depth > 50) continue
			// Don't spread through watertight bulkheads
			var/turf/wall/sub_bulkhead/B = get_step(src, dir)
			if(istype(B) && B.watertight) continue
			// Don't spread through closed blast doors
			var/obj/structure/simple_door/blast/door = locate(/obj/structure/simple_door/blast) in get_step(src, dir)
			if(door && !door.state) continue
			// Ignite the neighbor
			neighbor.ignite_deck_fire(rand(15, 30), fire_temperature)
			break  // Only spread to one tile per tick

/turf/floor/sub_deck/proc/ignite_deck_fire(var/duration = 20, var/temperature = 800)
	if(fire_active) return  // Already burning
	if(water_depth > 50) return  // Too much water

	fire_active = TRUE
	fire_temperature = temperature
	fire_duration = duration

	// Spawn the visual fire effect (skip if one already exists on this tile)
	var/has_fire = FALSE
	for(var/obj/effect/fire/F in src)
		has_fire = TRUE
		break
	if(!has_fire)
		var/obj/effect/fire/F = new(src)
		F.timer = duration * 10

	// Sound on first ignition
	if(prob(30))
		playsound(src, 'sound/machines/submarine/fire.ogg', 50, 1)

/turf/floor/sub_deck/proc/extinguish_fire()
	if(!fire_active) return
	fire_active = FALSE
	fire_temperature = 0
	fire_duration = 0

	// Remove all fire effects on this tile
	for(var/obj/effect/fire/F in src)
		qdel(F)

// Drowning damage to mobs standing on this tile
/turf/floor/sub_deck/proc/apply_drowning_damage()
	if(world.time - last_damage_tick < 10) return  // 1 second cooldown
	last_damage_tick = world.time

	for(var/mob/living/L in src)
		if(water_depth >= 150)
			// Fully submerged: heavy damage, chance of drowning
			L.apply_damage(8, BRUTE)
			if(prob(15) && istype(L, /mob/living/human))
				var/mob/living/human/H = L
				H.losebreath = max(H.losebreath + 3, 3)
				to_chat(H, "<span class='danger'>Water fills your lungs!</span>")
				playsound(src, 'sound/machines/submarine/flood.ogg', 40, 1)
		else if(water_depth >= 100)
			// Waist deep: moderate drowning risk
			if(istype(L, /mob/living/human))
				var/mob/living/human/H = L
				H.losebreath = max(H.losebreath + 1, 1)
			if(prob(5))
				to_chat(L, "<span class='warning'>You struggle to breathe above the rising water.</span>")
				playsound(src, 'sound/machines/submarine/alarm_flooding.ogg', 30, 1)
		else if(water_depth >= 50)
			// Ankle deep: annoying, minor oxygen drain
			if(prob(2))
				to_chat(L, "<span class='notice'>Water sloshes around your boots.</span>")

// Update the turf's visual appearance based on water depth
/turf/floor/sub_deck/proc/refresh_water_overlay()
	overlays.Cut()
	icon_state = "steel_grid"

	if(water_depth > 0)
		var/overlay_state = "flood_overlay1"
		if(water_depth >= 100)
			overlay_state = "flood_overlay3"
		else if(water_depth >= 30)
			overlay_state = "flood_overlay2"
		var/image/water_overlay = image('icons/turf/beach.dmi', overlay_state)
		water_overlay.layer = MOB_LAYER + 0.1
		overlays += water_overlay

// ============================================================
// Atmospheric System
// ============================================================

// Called by the flooding controller each tick
/turf/floor/sub_deck/proc/atmos_tick()
	// Oxygen depletion from mobs breathing
	for(var/mob/living/L in src)
		if(oxygen_moles > 0.5)
			oxygen_moles -= 0.05  // Each mob consumes ~0.05 moles/tick
			co2_moles += 0.03     // Produces CO2

	// CO2 buildup: if too high, mobs start suffocating
	if(co2_moles > SUB_ATMOS_DANGER_CO2)
		for(var/mob/living/human/H in src)
			H.losebreath = max(H.losebreath + 1, 1)
			if(prob(3))
				to_chat(H, "<span class='danger'>The air is thick with CO2!</span>")

	// Low oxygen: damage and messages
	if(oxygen_moles < 5)
		for(var/mob/living/human/H in src)
			H.losebreath = max(H.losebreath + 1, 1)
			if(world.time - last_damage_tick > 10)
				H.adjustOxyLoss(2)
				last_damage_tick = world.time
				if(prob(8))
					to_chat(H, "<span class='danger'>You gasp for air — the oxygen is gone!</span>")

	// Ventilation: if a vent is active, equalize with duct network
	if(vent_active && vent_id)
		process_ventilation()

	// Recalculate pressure from gas moles
	// PV = nRT, simplified: pressure in kPa from moles in a ~2m^3 tile
	compartment_pressure = clamp((oxygen_moles + co2_moles) * 8.314 * atmos_temperature / 2000 / 101.325, 0, 2)

/turf/floor/sub_deck/proc/process_ventilation()
	if(!global.subcom_flooding) return
	var/datum/flooding_controller/FC = global.subcom_flooding

	// Find the duct network for this vent_id
	if(FC.vent_networks[vent_id])
		var/list/network_turfs = FC.vent_networks[vent_id]
		// Average the oxygen across all connected turfs
		var/total_o2 = 0
		var/total_co2 = 0
		var/tile_count = 0
		for(var/turf/floor/sub_deck/T in network_turfs)
			total_o2 += T.oxygen_moles
			total_co2 += T.co2_moles
			tile_count++
		if(tile_count > 0)
			var/avg_o2 = total_o2 / tile_count
			var/avg_co2 = total_co2 / tile_count
			// Gradually equalize (vents don't teleport air instantly)
			oxygen_moles = mix_value(oxygen_moles, avg_o2, 0.3)
			co2_moles = mix_value(co2_moles, avg_co2, 0.3)

// ============================================================
// Examine / Info
// ============================================================

/turf/floor/sub_deck/examine(mob/user)
	..()
	if(water_depth > 0)
		var/water_desc = ""
		switch(water_depth)
			if(1 to 29)
				water_desc = "There is a thin layer of water on the deck."
			if(30 to 99)
				water_desc = "<span class='warning'>Water covers the deck up to ankle height.</span>"
			if(100 to 149)
				water_desc = "<span class='warning'>Water reaches waist height. Movement is difficult.</span>"
			if(150 to 199)
				water_desc = "<span class='danger'>The compartment is nearly fully flooded!</span>"
			if(200)
				water_desc = "<span class='danger'>This compartment is completely submerged!</span>"
		to_chat(user, water_desc)

	if(oxygen_moles < 5)
		to_chat(user, "<span class='warning'>The air smells stale and oxygen-depleted.</span>")
	if(co2_moles > 3)
		to_chat(user, "<span class='danger'>The CO2 concentration is dangerously high!</span>")

// ============================================================
// Compartment Floor Subtypes - pre-configured for mapmaking
// ============================================================

/turf/floor/sub_deck/forward_torpedo
	name = "forward torpedo room floor"
	compartment_id = SUB_COMP_FORWARD_TORPEDO

/turf/floor/sub_deck/storage
	name = "storage floor"
	compartment_id = SUB_COMP_STORAGE

/turf/floor/sub_deck/operations
	name = "operations room floor"
	compartment_id = SUB_COMP_OPERATIONS

/turf/floor/sub_deck/medical_bay
	name = "medical bay floor"
	compartment_id = SUB_COMP_MEDICAL_BAY

/turf/floor/sub_deck/galley
	name = "galley floor"
	compartment_id = SUB_COMP_GALLEY

/turf/floor/sub_deck/central_corridor
	name = "central corridor floor"
	compartment_id = SUB_COMP_CENTRAL_CORRIDOR

/turf/floor/sub_deck/rear_corridor
	name = "rear corridor floor"
	compartment_id = SUB_COMP_REAR_CORRIDOR

/turf/floor/sub_deck/reactor_room
	name = "reactor room floor"
	compartment_id = SUB_COMP_REACTOR_ROOM

/turf/floor/sub_deck/engine_room
	name = "engine room floor"
	compartment_id = SUB_COMP_ENGINE_ROOM

/turf/floor/sub_deck/maneuvering
	name = "maneuvering room floor"
	compartment_id = SUB_COMP_MANEUVERING

/turf/floor/sub_deck/aft_torpedo
	name = "aft torpedo room floor"
	compartment_id = SUB_COMP_AFT_TORPEDO
