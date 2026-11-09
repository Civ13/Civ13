// ============================================================
// Submarine Areas
// ============================================================


// ============================================================
// Submarine Turfs - hull walls, bulkheads, and deck floors
// with water accumulation and compartment-based flooding physics.
// Air is not stored per tile: each compartment shares one habitat
// ledger held by the flooding controller.
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
	var/shored = FALSE             // a shoring kit holds the breach to a seep until the next hit
	flags = TURF_HAS_EDGES

/turf/wall/sub_hull/New(var/newloc)
	..(newloc,"submarine hull")

/turf/wall/sub_hull/proc/apply_breach_damage(var/damage)
	hull_integrity -= damage
	if(hull_integrity <= 0 && !breached)
		breach_hull()
	else if(breached && shored && damage > 0)
		shoring_fails()

// Change the water pouring through this breach onto the decks around it.
/turf/wall/sub_hull/proc/set_breach_inflow(var/rate)
	for(var/turf/floor/sub_deck/D in range(1, src))
		D.water_inflow_rate = max(0, D.water_inflow_rate - breach_inflow_rate + rate)
	breach_inflow_rate = rate

// A shoring kit cuts the breach to a seep.
/turf/wall/sub_hull/proc/shore_breach()
	if(!breached || shored) return
	shored = TRUE
	set_breach_inflow(SUB_SHORED_INFLOW)
	visible_message("<span class='notice'>Shores and a patch wedge the breach down to a seep.</span>")
	overlays -= image(icon='icons/obj/machines/submarine.dmi',icon_state="breach_glow")

// The next hit knocks the shoring out.
/turf/wall/sub_hull/proc/shoring_fails()
	if(!shored) return
	shored = FALSE
	set_breach_inflow(SUB_BREACH_INFLOW_BASE)
	visible_message("<span class='danger'><b>The shoring gives way! Seawater pours through the breach again!</b></span>")
	playsound(src, 'sound/machines/submarine/hull_breach.ogg', 70, 1)
	overlays += image(icon='icons/obj/machines/submarine.dmi',icon_state="breach_glow")

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
	// Undo whatever this breach still pours onto the decks, shored or not.
	set_breach_inflow(0)
	breached = FALSE
	shored = FALSE
	hull_integrity = max_hull_integrity * 0.5  // Repaired to half
	icon_state = "metal0"
	overlays.Cut()  // Remove damage and breach glow overlays
	visible_message("<span class='notice'>The hull breach is sealed.</span>")

/turf/wall/sub_hull/attackby(obj/item/weapon/W, mob/user)
	if(istype(W, /obj/item/weapon/shoring_kit))
		var/obj/item/weapon/shoring_kit/K = W
		K.use_on_hull(src, user)
		return
	if(istype(W, /obj/item/weapon/weldingtool))
		if(breached)
			to_chat(user, "<span class='notice'>You begin welding the hull breach shut...</span>")
			playsound(src.loc, 'sound/machines/submarine/gas.ogg', 50, 1)
			if(do_after(user, 1200, src))
				repair_breach()
				playsound(src.loc, 'sound/machines/submarine/gas.ogg', 50, 1)
		else if(hull_integrity < max_hull_integrity)
			to_chat(user, "<span class='notice'>You begin welding cracks in the hull...</span>")
			playsound(src.loc, 'sound/machines/submarine/gas.ogg', 50, 1)
			if(do_after(user, 1200, src))
				hull_integrity = min(max_hull_integrity, hull_integrity + round(max_hull_integrity * 0.5))
				overlays.Cut()
				to_chat(user, "<span class='notice'>You repair the hull. Integrity: [hull_integrity]/[max_hull_integrity]</span>")
				playsound(src.loc, 'sound/machines/submarine/gas.ogg', 50, 1)
		else
			to_chat(user, "<span class='notice'>The hull is in good condition.</span>")
		return
	..()

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
	sub_bulkheads |= src

// A shoring kit wedges buckled seals shut without mending the steel.
/turf/wall/sub_bulkhead/proc/shore_seals()
	if(watertight || health <= 0) return
	watertight = TRUE
	visible_message("<span class='notice'>Wedges force the bulkhead seals back into place. It holds water again.</span>")

/turf/wall/sub_bulkhead/attackby(obj/item/weapon/W, mob/user)
	if(istype(W, /obj/item/weapon/shoring_kit))
		var/obj/item/weapon/shoring_kit/K = W
		K.use_on_bulkhead(src, user)
		return
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
// Deck Floor - the core of the water simulation
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
	var/tmp/datum/flooding_controller/flooding_owner  // The controller this tile reports to (set on registration)

	// ---- Visual / Info ----
	var/water_warning_sent = FALSE  // Prevents spamming "water rising!" messages
	var/last_damage_tick = 0        // For drowning damage cooldown

	// ---- Fire State ----
	var/fire_active = FALSE         // TRUE if this tile is on fire
	var/fire_temperature = 0        // Current fire intensity (affects spread chance and damage)
	var/fire_duration = 0           // Ticks remaining before fire burns out

/turf/floor/sub_deck/New()
	..()
	// Register with the flooding controller: the vessel's, or SUBCOM13's.
	var/datum/flooding_controller/F = flooding_for(src)
	if(F)
		F.register_turf(src)

/turf/floor/sub_deck/Destroy()
	var/datum/flooding_controller/F = flooding_owner || flooding_for(src)
	if(F)
		F.unregister_turf(src)
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
	// Air is handled per compartment by the flooding controller: water
	// shrinks the compartment's air pocket and inflow lets air escape.

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
			L.apply_damage(8, OXY)
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
				H.adjustOxyLoss(4)
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
		var/edge_state = "flood_overlay1_edges"
		if(water_depth >= 100)
			overlay_state = "flood_overlay3"
			edge_state = "flood_overlay3_edges"
		else if(water_depth >= 30)
			overlay_state = "flood_overlay2"
			edge_state = "flood_overlay2_edges"
		var/image/water_overlay = image('icons/turf/beach.dmi', overlay_state)
		water_overlay.layer = MOB_LAYER + 0.1
		overlays += water_overlay

		// Edge borders: where water meets dry floor or walls
		var/list/cardinal_dirs = list(NORTH, SOUTH, EAST, WEST)
		for(var/dir in cardinal_dirs)
			var/turf/neighbor = get_step(src, dir)
			var/has_edge = FALSE
			if(!neighbor)
				has_edge = TRUE
			else if(istype(neighbor, /turf/floor/sub_deck))
				var/turf/floor/sub_deck/N = neighbor
				if(N.water_depth <= 0)
					has_edge = TRUE
			else
				has_edge = TRUE
			if(has_edge)
				var/image/edge_img = image('icons/turf/beach.dmi', edge_state, dir=dir)
				edge_img.layer = MOB_LAYER + 0.2
				overlays += edge_img

		// Corner overlays where two edges meet
		var/list/corner_dirs = list(NORTHEAST, NORTHWEST, SOUTHEAST, SOUTHWEST)
		var/list/corner_dir1 = list(NORTH, NORTH, SOUTH, SOUTH)
		var/list/corner_dir2 = list(EAST, WEST, EAST, WEST)
		for(var/i in 1 to 4)
			var/cdir = corner_dirs[i]
			var/dir1 = corner_dir1[i]
			var/dir2 = corner_dir2[i]
			var/turf/T1 = get_step(src, dir1)
			var/turf/T2 = get_step(src, dir2)
			var/edge1 = FALSE
			var/edge2 = FALSE
			if(!T1 || !istype(T1, /turf/floor/sub_deck))
				edge1 = TRUE
			else
				var/turf/floor/sub_deck/SD1 = T1
				if(SD1.water_depth <= 0)
					edge1 = TRUE
			if(!T2 || !istype(T2, /turf/floor/sub_deck))
				edge2 = TRUE
			else
				var/turf/floor/sub_deck/SD2 = T2
				if(SD2.water_depth <= 0)
					edge2 = TRUE
			if(edge1 && edge2)
				var/image/corner_img = image('icons/turf/beach.dmi', edge_state, dir=cdir)
				corner_img.layer = MOB_LAYER + 0.3
				overlays += corner_img

// ============================================================
// Air
// ============================================================

// The compartment air this tile shares, or null outside any compartment.
/turf/floor/sub_deck/proc/compartment_air()
	var/datum/flooding_controller/F = flooding_owner || flooding_for(src)
	if(!F)
		return null
	return F.get_air(compartment_id)

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

	var/datum/habitat_ledger/air = compartment_air()
	if(air)
		if(air.oxygen_kpa() < HABITAT_MIN_OXYGEN_KPA)
			to_chat(user, "<span class='warning'>The air smells stale and oxygen-depleted.</span>")
		if(air.co2_kpa() > HABITAT_MAX_CO2_KPA)
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

// ============================================================
// Explosions and projectiles
// ============================================================
// Hull, bulkhead and deck turfs are never torn out as turfs: a shell or a
// round damages the steel, breaches it or sets the deck alight, and the
// crew's damage control deals with the rest.

/turf/wall/sub_hull/ex_act(severity)
	switch(severity)
		if(1)
			apply_breach_damage(600)
		if(2)
			apply_breach_damage(300)
		if(3)
			apply_breach_damage(100)

/turf/wall/sub_hull/bullet_act(var/obj/item/projectile/Proj)
	apply_breach_damage(min(Proj.get_structure_damage(), 100))

/turf/wall/sub_bulkhead/ex_act(severity)
	switch(severity)
		if(1)
			take_bulkhead_damage(150)
		if(2)
			take_bulkhead_damage(75)
		if(3)
			take_bulkhead_damage(25)

/turf/wall/sub_bulkhead/bullet_act(var/obj/item/projectile/Proj)
	take_bulkhead_damage(min(Proj.get_structure_damage(), 50))

// A blast on the deck starts a fire; the plating itself stays.
/turf/floor/sub_deck/ex_act(severity)
	switch(severity)
		if(1)
			ignite_deck_fire(rand(30, 50), rand(800, 1000))
		if(2)
			if(prob(60))
				ignite_deck_fire(rand(20, 40), rand(600, 900))
		if(3)
			if(prob(20))
				ignite_deck_fire(rand(10, 20), 600)
