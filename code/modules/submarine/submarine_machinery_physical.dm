/obj/structure/machinery/sub_physical
	name = "submarine machinery"
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "transponder"
	density = TRUE
	anchored = TRUE
	var/health = 100
	var/max_health = 100
	var/panel_open = FALSE
	var/datum/submarine/my_sub

/obj/structure/machinery/sub_physical/New()
	..()
	if(global.all_submarines.len)
		my_sub = global.all_submarines[1]

/obj/structure/machinery/sub_physical/proc/can_use_sub(mob/user)
	// Standard check: alive, adjacent, not incapacitated
	if(user.incapacitated() || user.lying) return FALSE
	if(get_dist(user, src) > 1) return FALSE
	// Ghost/dead check: allowed only in single-player mode
	if(user.stat == DEAD || isobserver(user))
		var/obj/map_metadata/subcom13/SM = map
		if(istype(SM) && SM.single_player)
			return TRUE
		return FALSE
	return TRUE

/obj/structure/machinery/sub_physical/attack_hand(mob/user)
	if(!can_use_sub(user)) return
	..()

/obj/structure/machinery/sub_physical/attack_ghost(mob/observer/ghost/user)
	var/obj/map_metadata/subcom13/SM = map
	if(istype(SM) && SM.single_player)
		attack_hand(user)
		return
	..()

/obj/structure/machinery/sub_physical/proc/get_efficiency()
	return max(0, health / max_health)

/obj/structure/machinery/sub_physical/attackby(obj/item/W, mob/user)
	// Screwdriver: Open/Close Panels
	if(istype(W, /obj/item/weapon/screwdriver))
		panel_open = !panel_open
		user.visible_message("<span class='notice'>[user] [panel_open ? "opens" : "closes"] the maintenance panel on [src].</span>")
		playsound(src.loc, 'sound/items/Screwdriver.ogg', 50, 1)
		return

	// Wrench: Secure/Unsecure (Logic for specific components)
	if(istype(W, /obj/item/weapon/wrench))
		anchored = !anchored
		user.visible_message("<span class='notice'>[user] [anchored ? "secures" : "unsecures"] [src].</span>")
		playsound(src.loc, 'sound/items/ratchet.ogg', 50, 1)
		return

	// Welder: Repair structural damage
	if(istype(W, /obj/item/weapon/weldingtool))
		if(health < max_health)
			user.visible_message("<span class='notice'>[user] begins repairing [src] with [W].</span>")
			if(do_after(user, 40, src))
				health = min(max_health, health + 20)
				to_chat(user, "<span class='notice'>You repair some of the structural damage on [src].</span>")
		else
			to_chat(user, "<span class='notice'>[src] is already in good condition.</span>")
		return

	// Multitool: Diagnostic check
	if(istype(W, /obj/item/weapon/wirecutters) || istype(W, /obj/item/weapon/screwdriver))
		to_chat(user, "<span class='notice'><b>Diagnostic Output for [src]:</b></span>")
		to_chat(user, "<span class='notice'>Integrity: [health]/[max_health] ([get_efficiency()*100]%)</span>")
		return

	..()

/* --- STRUCTURAL BASE --- */
// Used for non-processing structures like beds and lockers
/obj/structure/sub_physical
	name = "submarine structure"
	icon = 'icons/obj/machines/submarine.dmi'
	density = TRUE
	anchored = TRUE
	var/health = 100
	var/max_health = 100
	var/datum/submarine/my_sub

/obj/structure/sub_physical/New()
	..()
	if(global.all_submarines.len)
		my_sub = global.all_submarines[1]

/obj/structure/sub_physical/attackby(obj/item/W, mob/user)
	if(istype(W, /obj/item/weapon/weldingtool))
		if(health < max_health)
			user.visible_message("<span class='notice'>[user] repairs [src].</span>")
			if(do_after(user, 30, src))
				health = min(max_health, health + 25)
		return
	if(istype(W, /obj/item/weapon/screwdriver) || istype(W, /obj/item/weapon/wirecutters))
		to_chat(user, "<span class='notice'>Integrity: [health]%</span>")
		return
	..()

// --- 1. REACTOR CORE ---

/obj/structure/machinery/sub_physical/reactor_core
	name = "nuclear reactor core"
	desc = "The humming heart of the submarine. Stay back if the warning lights are flashing."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "reactor_0"
	health = 340
	max_health = 340
	var/id = 1 // Reactor 1 or 2
	var/shielding = 100

/obj/structure/machinery/sub_physical/reactor_core/process()
	if(!my_sub) return

	var/core_temp = my_sub.r_core_temp[id]
	
	// Meltdown and Damage Logic
	if(health < (max_health * 0.5) || core_temp > 1000)
		radiation_pulse()

/obj/structure/machinery/sub_physical/reactor_core/proc/radiation_pulse()
	// Irradiate everyone in the room
	for(var/mob/living/L in range(3, src))
		to_chat(L, "<span class='danger'>The air feels heavy and metallic...</span>")
		// Standard Rad Act - assuming typical SS13 radiation logic
		// L.rad_act(10) 
	
	if(prob(5))
		visible_message("<span class='warning'>[src] emits a burst of ionizing radiation!</span>")

// --- 2. COOLANT PUMP ---

/obj/structure/machinery/sub_physical/coolant_pump
	name = "coolant circulation pump"
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "smes2"
	var/pump_id = 1
	var/is_primary = TRUE // TRUE = Primary, FALSE = Secondary

/obj/structure/machinery/sub_physical/coolant_pump/process()
	if(!my_sub) return

	var/eff = get_efficiency()
	
	// Degrade global performance based on physical health
	if(is_primary)
		if(my_sub.r_primary_pump_speed[pump_id] > (18 * eff))
			my_sub.r_primary_pump_speed[pump_id] = round(18 * eff)
	else
		if(my_sub.r_secondary_pump_speed[pump_id] > (10 * eff))
			my_sub.r_secondary_pump_speed[pump_id] = round(10 * eff)

	if(health <= 0)
		visible_message("<span class='danger'>[src] seizes up with a violent metallic screech!</span>")
		if(is_primary) my_sub.r_primary_pump_speed[pump_id] = 0
		else my_sub.r_secondary_pump_speed[pump_id] = 0

// --- 3. STEAM TURBINE ---

/obj/structure/machinery/sub_physical/steam_turbine
	name = "main propulsion steam turbine"
	icon = 'icons/obj/engines32.dmi'
	icon_state = "turbine_static"
	health = 200
	max_health = 200
	var/gearbox_integrity = 100

/obj/structure/machinery/sub_physical/steam_turbine/process()
	if(!my_sub) return

	var/eff = get_efficiency()
	var/max_possible_speed = 30 * eff

	// Cap sub target speed based on physical health
	if(my_sub.target_speed > max_possible_speed)
		my_sub.target_speed = max_possible_speed
		if(prob(10))
			to_chat(viewers(src), "<span class='warning'>The turbine groans under the strain of the damaged blades!</span>")

	// Ambient sound logic
	if(my_sub.speed > 20 && prob(5))
		playsound(src.loc, 'sound/effects/doorcreaky.ogg', 40, 1)

// --- 4. DIESEL ENGINE ---

/obj/structure/machinery/sub_physical/diesel_engine
	name = "backup diesel generator"
	icon = 'icons/obj/vehicles/vehicleparts.dmi'
	icon_state = "engine_static"
	health = 150
	max_health = 150
	var/carbon_buildup = 0

/obj/structure/machinery/sub_physical/diesel_engine/process()
	if(!my_sub) return

	// Throttle-based maintenance logic
	if(my_sub.diesel_throttle > 0 && my_sub.diesel_throttle < 40)
		carbon_buildup += 0.1
	
	// Carbon buildup reduces efficiency
	if(carbon_buildup > 50)
		health -= 0.05

	// High throttle risk
	if(my_sub.diesel_throttle >= 95 && health < 100)
		if(prob(2))
			visible_message("<span class='danger'>[src] spits sparks as it overheats!</span>")
			playsound(src.loc, 'sound/machines/submarine/dgenstop.ogg', 50, 1)

// --- 4b. DIESEL PROPULSION MOTOR ---
// Used on diesel-only submarines. Converts diesel engine output to propeller thrust.
// Only functional when surfaced and diesel throttle is engaged.

/obj/structure/machinery/sub_physical/diesel_propulsion
	name = "diesel-electric propulsion motor"
	desc = "A heavy electric traction motor coupled to the propeller shaft. Powered by the diesel generators."
	icon = 'icons/obj/engines32.dmi'
	icon_state = "turbine_static"
	health = 200
	max_health = 200
	var/motor_temp = 20

/obj/structure/machinery/sub_physical/diesel_propulsion/process()
	if(!my_sub) return
	if(my_sub.has_nuclear_engine) return  // Should not exist on nuclear subs

	var/eff = get_efficiency()

	// Diesel-only propulsion: max speed is capped by motor health
	if(my_sub.depth == 0 && my_sub.diesel_throttle > 0 && my_sub.diesel_fuel > 0)
		var/max_possible_speed = SUB_MAX_SPEED_DIESEL * eff
		if(my_sub.target_speed > max_possible_speed)
			my_sub.target_speed = max_possible_speed
			if(prob(5))
				visible_message("<span class='warning'>The propulsion motor whines under the load!</span>")

		// Motor heating from high throttle
		if(my_sub.diesel_throttle > 70)
			motor_temp += 0.5
		else
			motor_temp = max(SUB_AMBIENT_TEMP, motor_temp - 0.3)

		// Overheating damage
		if(motor_temp > 80)
			health -= 0.1
			if(prob(3))
				visible_message("<span class='warning'>[src] smells of burning insulation!</span>")

		// Motor damage limits output
		if(health <= 0)
			my_sub.diesel_throttle = 0
			visible_message("<span class='danger'>[src] seizes with a shower of sparks! Propulsion lost!</span>")
	else
		// Cooldown when idle
		motor_temp = max(SUB_AMBIENT_TEMP, motor_temp - 0.5)

// --- 5. BILGE PUMP ---
// Reworked to use typed water_depth on /turf/floor/sub_deck.
// Drains water from the turf it sits on and adjacent connected turfs.

/obj/structure/machinery/sub_physical/bilge_pump
	name = "bilge pump"
	desc = "A high-capacity centrifugal pump for evacuating seawater from flooded compartments."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "bilge_pump"
	health = 80
	max_health = 80
	var/active = FALSE
	var/drain_rate = 10            // cm of water removed per tick
	var/power_draw = 15            // kW per tick when active
	var/drain_range = 1            // How many turfs away it can drain (1 = adjacent only)

/obj/structure/machinery/sub_physical/bilge_pump/attack_hand(mob/user)
	if(!can_use_sub(user)) return
	if(!my_sub) return
	active = !active
	if(active)
		to_chat(user, "<span class='notice'>You switch on [src]. It hums to life.</span>")
		playsound(src.loc, 'sound/machines/machine_switch.ogg', 50, 1)
	else
		to_chat(user, "<span class='notice'>You switch off [src].</span>")
		playsound(src.loc, 'sound/machines/click.ogg', 50, 1)

/obj/structure/machinery/sub_physical/bilge_pump/process()
	if(!active || health <= 0) return
	if(!my_sub) return

	// Check power: bilge pumps need battery power
	if(my_sub.battery_current < power_draw)
		active = FALSE
		visible_message("<span class='warning'>[src] sputters and shuts down — insufficient power.</span>")
		playsound(src.loc, 'sound/machines/submarine/alarm_flooding.ogg', 40, 1)
		return

	my_sub.battery_current -= power_draw

	// Find the turf we're on and drain it
	var/turf/floor/sub_deck/my_turf = get_turf(src)
	if(!my_turf || !istype(my_turf)) return

	// Drain our own tile
	if(my_turf.water_depth > 0)
		var/amount = min(my_turf.water_depth, drain_rate)
		my_turf.remove_water(amount)

	// Drain adjacent tiles within range
	if(drain_range > 0)
		for(var/direction in list(NORTH, SOUTH, EAST, WEST))
			var/turf/floor/sub_deck/neighbor = get_step(my_turf, direction)
			if(neighbor && istype(neighbor) && !neighbor.water_sealed)
				if(neighbor.water_depth > 0)
					var/amount = min(neighbor.water_depth, drain_rate * 0.5)
					neighbor.remove_water(amount)

	// Visual feedback: pump is working hard if there's lots of water
	if(my_turf.water_depth > 50 && prob(10))
		visible_message("<span class='notice'>[src] gurgles as it strains against the rising water.</span>")

// --- 5b. EMERGENCY BILGE PUMP ---
// A smaller, emergency-only pump. Slower but doesn't need as much power.

/obj/structure/machinery/sub_physical/bilge_pump/emergency
	name = "emergency bilge pump"
	desc = "A manually-activated backup pump. Slow but better than drowning."
	drain_rate = 5
	power_draw = 8
	drain_range = 0  // Only drains the tile it's on

// ============================================================
// VENTILATION SYSTEM
// ============================================================

// --- 5c. VENT DUCT ---
// Links deck turfs into a ventilation network. Air equalizes
// across all turfs in the same vent_id network.

/obj/structure/machinery/sub_physical/vent_duct
	name = "ventilation duct"
	desc = "A heavy-duty air duct connecting compartments to the central ventilation system."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "vent"
	health = 60
	max_health = 60
	var/vent_id = "main"           // Network ID — all ducts with same vent_id are connected
	var/flow_rate = 0.3            // Lerp factor for air equalization (0 = no flow, 1 = instant)
	var/active = TRUE

// Predefined vent ducts — one per compartment, each with its own air network
/obj/structure/machinery/sub_physical/vent_duct/fwd_torpedo
	name = "vent duct — forward torpedo"
	vent_id = "fwd_torpedo"

/obj/structure/machinery/sub_physical/vent_duct/fwd_battery
	name = "vent duct — forward battery"
	vent_id = "fwd_battery"

/obj/structure/machinery/sub_physical/vent_duct/operations
	name = "vent duct — operations"
	vent_id = "operations"

/obj/structure/machinery/sub_physical/vent_duct/crew_quarters
	name = "vent duct — crew quarters"
	vent_id = "crew_quarters"

/obj/structure/machinery/sub_physical/vent_duct/galley
	name = "vent duct — galley"
	vent_id = "galley"

/obj/structure/machinery/sub_physical/vent_duct/cpo_quarters
	name = "vent duct — CPO quarters"
	vent_id = "cpo_quarters"

/obj/structure/machinery/sub_physical/vent_duct/aft_battery
	name = "vent duct — after battery"
	vent_id = "aft_battery"

/obj/structure/machinery/sub_physical/vent_duct/reactor_room
	name = "vent duct — reactor room"
	vent_id = "reactor_room"

/obj/structure/machinery/sub_physical/vent_duct/engine_room
	name = "vent duct — engine room"
	vent_id = "engine_room"

/obj/structure/machinery/sub_physical/vent_duct/New()
	..()
	// Register with the flooding controller
	if(global.subcom_flooding)
		var/turf/floor/sub_deck/my_turf = get_turf(src)
		if(my_turf && istype(my_turf))
			global.subcom_flooding.register_vent(vent_id, my_turf)

/obj/structure/machinery/sub_physical/vent_duct/Destroy()
	if(global.subcom_flooding)
		var/turf/floor/sub_deck/my_turf = get_turf(src)
		if(my_turf && istype(my_turf))
			global.subcom_flooding.unregister_vent(vent_id, my_turf)
	..()

/obj/structure/machinery/sub_physical/vent_duct/attack_hand(mob/user)
	if(!can_use_sub(user)) return
	active = !active
	if(active)
		to_chat(user, "<span class='notice'>You open the ventilation duct. Air begins to flow.</span>")
		playsound(src.loc, 'sound/machines/submarine/gas.ogg', 40, 1)
	else
		to_chat(user, "<span class='notice'>You close the ventilation duct. Air flow stops.</span>")

/obj/structure/machinery/sub_physical/vent_duct/attackby(obj/item/W, mob/user)
	if(istype(W, /obj/item/weapon/weldingtool))
		if(health < max_health)
			user.visible_message("<span class='notice'>[user] repairs [src].</span>")
			if(do_after(user, 25, src))
				health = min(max_health, health + 20)
		return
	if(istype(W, /obj/item/weapon/screwdriver) || istype(W, /obj/item/weapon/wirecutters))
		to_chat(user, "<span class='notice'>Network: [vent_id] | Status: [active ? "OPEN" : "CLOSED"]</span>")
		return
	..()

// --- 5d. SCRUBBER ---
// Actively removes CO2 and optionally injects O2.
// Higher power draw than passive vents.

/obj/structure/machinery/sub_physical/scrubber
	name = "CO2 scrubber"
	desc = "An activated-carbon filtration unit that removes carbon dioxide from the air."
	icon = 'icons/obj/modern_structures.dmi'
	icon_state = "airfilter2"
	health = 70
	max_health = 70
	var/active = FALSE
	var/power_draw = 25            // kW per tick
	var/scrub_rate = 0.5           // Moles of CO2 removed per tick
	var/inject_o2 = FALSE          // If TRUE, also injects O2 (from electrolysis)
	var/o2_inject_rate = 0.2       // Moles of O2 added per tick when inject_o2 is TRUE

/obj/structure/machinery/sub_physical/scrubber/attack_hand(mob/user)
	if(!can_use_sub(user)) return
	if(!my_sub) return
	active = !active
	if(active)
		to_chat(user, "<span class='notice'>You activate [src]. It begins filtering the air.</span>")
		playsound(src.loc, 'sound/machines/submarine/gas.ogg', 40, 1)
	else
		to_chat(user, "<span class='notice'>You deactivate [src].</span>")

/obj/structure/machinery/sub_physical/scrubber/process()
	if(!active || health <= 0) return
	if(!my_sub) return

	// Power check
	if(my_sub.battery_current < power_draw)
		active = FALSE
		visible_message("<span class='warning'>[src] shuts down — insufficient power.</span>")
		return

	my_sub.battery_current -= power_draw

	// Scrub CO2 from all turfs in the compartment
	var/turf/floor/sub_deck/my_turf = get_turf(src)
	if(!my_turf || !istype(my_turf)) return
	if(!my_turf.compartment_id) return

	if(global.subcom_flooding)
		var/list/comp_turfs = global.subcom_flooding.compartment_turfs[my_turf.compartment_id]
		if(comp_turfs)
			for(var/turf/floor/sub_deck/T in comp_turfs)
				T.co2_moles = max(0, T.co2_moles - scrub_rate)
				if(inject_o2)
					T.oxygen_moles = min(30, T.oxygen_moles + o2_inject_rate)

// --- 5e. HULL BREACH SEALANT SPRAYER ---
// Emergency tool: sprays a fast-curing polymer to seal small hull breaches.

/obj/structure/machinery/sub_physical/breach_sealant
	name = "hull breach sealant sprayer"
	desc = "An automated sprayer that coats damaged hull sections with fast-curing polymer sealant."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "sealant"
	health = 50
	max_health = 50
	var/sealant_remaining = 100    // Uses of sealant left
	var/power_draw = 10            // kW per tick
	var/active = FALSE

// Predefined sealant sprayers — one per compartment
/obj/structure/machinery/sub_physical/breach_sealant/fwd_torpedo
	name = "sealant sprayer — forward torpedo"
/obj/structure/machinery/sub_physical/breach_sealant/fwd_battery
	name = "sealant sprayer — forward battery"
/obj/structure/machinery/sub_physical/breach_sealant/operations
	name = "sealant sprayer — operations"
/obj/structure/machinery/sub_physical/breach_sealant/crew_quarters
	name = "sealant sprayer — crew quarters"
/obj/structure/machinery/sub_physical/breach_sealant/galley
	name = "sealant sprayer — galley"
/obj/structure/machinery/sub_physical/breach_sealant/cpo_quarters
	name = "sealant sprayer — CPO quarters"
/obj/structure/machinery/sub_physical/breach_sealant/aft_battery
	name = "sealant sprayer — after battery"
/obj/structure/machinery/sub_physical/breach_sealant/reactor_room
	name = "sealant sprayer — reactor room"
/obj/structure/machinery/sub_physical/breach_sealant/engine_room
	name = "sealant sprayer — engine room"

/obj/structure/machinery/sub_physical/breach_sealant/attack_hand(mob/user)
	if(!can_use_sub(user)) return
	if(!my_sub) return
	if(sealant_remaining <= 0)
		to_chat(user, "<span class='warning'>The sealant supply is depleted!</span>")
		return
	active = !active
	if(active)
		to_chat(user, "<span class='notice'>You activate [src]. It begins scanning for breaches.</span>")
	else
		to_chat(user, "<span class='notice'>You deactivate [src].</span>")

/obj/structure/machinery/sub_physical/breach_sealant/process()
	if(!active || health <= 0) return
	if(!my_sub) return
	if(sealant_remaining <= 0)
		active = FALSE
		return

	// Power check
	if(my_sub.battery_current < power_draw)
		active = FALSE
		return

	my_sub.battery_current -= power_draw

	// Scan adjacent turfs for breached hull walls and attempt to seal
	for(var/direction in list(NORTH, SOUTH, EAST, WEST))
		var/turf/wall/sub_hull/hull = get_step(src, direction)
		if(hull && istype(hull) && hull.breached)
			hull.repair_breach()
			sealant_remaining--
			visible_message("<span class='notice'>[src] sprays sealant onto the hull breach. It hisses as it cures.</span>")
			playsound(src.loc, 'sound/machines/submarine/gas.ogg', 60, 1)
			break  // One repair per tick

// --- 5f. BALLAST CONTROL VALVE ---
// Controls water intake for dive planes. Fills/empties ballast tanks.

/obj/structure/machinery/sub_physical/ballast_valve
	name = "ballast control valve"
	desc = "A heavy-duty valve controlling seawater flow into the ballast tanks."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "ballast"
	health = 100
	max_health = 100
	var/valve_open = FALSE
	var/fill_rate = 5              // cm of water moved per tick

/obj/structure/machinery/sub_physical/ballast_valve/attack_hand(mob/user)
	if(!can_use_sub(user)) return
	if(!my_sub) return
	valve_open = !valve_open
	if(valve_open)
		to_chat(user, "<span class='notice'>You open the ballast valve. Water begins flooding the tanks.</span>")
		playsound(src.loc, 'sound/machines/door_open.ogg', 50, 1)
	else
		to_chat(user, "<span class='notice'>You close the ballast valve.</span>")
		playsound(src.loc, 'sound/machines/door_close.ogg', 50, 1)

/obj/structure/machinery/sub_physical/ballast_valve/process()
	if(!valve_open || health <= 0) return
	if(!my_sub) return

	// Ballast fill affects the sub's depth control
	// Each tick, add ballast weight to simulate flooding the tanks
	my_sub.ballast = min(my_sub.ballast + fill_rate, 50)  // Max 50 tons of ballast

// --- 6. TORPEDO TUBE ---

/obj/structure/props/torpedo_tube
	name = "torpedo launch tube"
	desc = "A ship's torpedo tube."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "torpedo_tube2"

/obj/structure/machinery/sub_physical/torpedo_tube
	name = "torpedo launch tube"
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "torpedo_tube1"
	var/tube_id = 1 // 1-4
	var/is_loaded = FALSE

/obj/structure/machinery/sub_physical/torpedo_tube/attack_hand(mob/user)
	if(!can_use_sub(user)) return
	if(!my_sub) return

	to_chat(user, "<span class='notice'>Tube [tube_id] status: [my_sub.tubes_loaded[tube_id] ? "LOADED" : "EMPTY"]</span>")

/obj/structure/machinery/sub_physical/torpedo_tube/attackby(obj/item/I, mob/user)
	if(istype(I, /obj/item/weapon/torpedo))
		if(my_sub.tubes_loaded[tube_id])
			to_chat(user, "<span class='warning'>Tube [tube_id] is already loaded.</span>")
			return
		
		user.visible_message("<span class='notice'>[user] begins sliding [I] into launch tube [tube_id].</span>")
		if(do_after(user, 60, src))
			user.drop_item()
			qdel(I)
			my_sub.tubes_loaded[tube_id] = TRUE
			to_chat(user, "<span class='notice'>Tube [tube_id] is now ready for launch.</span>")
		return

	// Service/Unload
	if(istype(I, /obj/item/weapon/crowbar) || istype(I, /obj/item/weapon/wrench))
		if(my_sub.tubes_loaded[tube_id])
			user.visible_message("<span class='notice'>[user] begins manually extracting the torpedo from tube [tube_id].</span>")
			if(do_after(user, 80, src))
				my_sub.tubes_loaded[tube_id] = FALSE
				new /obj/item/weapon/torpedo(src.loc)
				to_chat(user, "<span class='notice'>You successfully unload the tube.</span>")
		return

	..()

// --- 7. BUNK BED ---

/obj/structure/bed/bunk
	name = "crew bunk"
	desc = "A cramped but essential rest area for the submarine crew."
	icon = 'icons/obj/bed_chair.dmi'
	icon_state = "bunk_bed"

// --- 8. GALLEY ---

/obj/structure/machinery/sub_physical/galley
	name = "galley food processor"
	desc = "Dispenses dense nutritional pastes and synthesized beverages."
	icon = 'icons/obj/vending.dmi'
	icon_state = "hotfood"
	var/food_stored = 50

/obj/structure/machinery/sub_physical/galley/attack_hand(mob/user)
	if(!can_use_sub(user)) return
	if(health < 30)
		to_chat(user, "<span class='warning'>The processor is too damaged to function.</span>")
		return
	if(food_stored <= 0)
		to_chat(user, "<span class='notice'>The galley is out of supplies.</span>")
		return

	food_stored--
	to_chat(user, "<span class='notice'>The machine clunks and produces a nutritional ration.</span>")
	new /obj/item/weapon/reagent_containers/food/snacks/MRE(src.loc)

// --- 9. EQUIPMENT STORAGE ---

/obj/structure/sub_physical/equipment_storage
	name = "emergency equipment locker"
	icon = 'icons/obj/closet.dmi'
	icon_state = "firecloset"
	var/list/stored_gear = list(
		/obj/item/clothing/mask/gas/military = 3,
		/obj/item/clothing/suit/storage/coat/fur = 2, // Heavy rad-protection placeholder
		/obj/item/weapon/weldingtool = 2,
		/obj/item/weapon/reagent_containers/glass/fire_extinguisher = 2,
		/obj/item/weapon/screwdriver = 1,
		/obj/item/weapon/wrench = 1,
		/obj/item/weapon/torpedo = 4
	)

/obj/structure/sub_physical/equipment_storage/attack_hand(mob/user)
	var/dat = "<b>Locker Contents:</b><br><hr>"
	for(var/path in stored_gear)
		var/amt = stored_gear[path]
		if(amt > 0)
			var/obj/O = path
			dat += "<a href='?src=\ref[src];get=[path]'>[initial(O.name)]</a> (x[amt])<br>"
	
	user << browse(dat, "window=sub_locker;size=300x400")

/obj/structure/sub_physical/equipment_storage/Topic(href, href_list)
	if(href_list["get"])
		var/path = text2path(href_list["get"])
		if(stored_gear[path] > 0)
			stored_gear[path]--
			new path(src.loc)
			usr.visible_message("<span class='notice'>[usr] takes an item from the locker.</span>")
	attack_hand(usr)

// --- 10. TORPEDO FUEL STORAGE (HTP) ---

/obj/structure/machinery/sub_physical/fuel_storage
	name = "HTP Fuel Tank"
	desc = "Contains high-test peroxide. Extremely unstable."
	icon = 'icons/obj/barrel.dmi'
	icon_state = "welding_tank"
	health = 80
	var/htp_volume = 100
	var/temperature = 20

/obj/structure/machinery/sub_physical/fuel_storage/process()
	var/turf/T = get_turf(src)
	
	// External heating
	for(var/obj/effect/fire/F in T)
		temperature += 5

	// Volatility Logic
	if(health < 30 || temperature > 45)
		if(prob(20))
			T.visible_message("<span class='warning'>Toxic HTP fumes hiss from [src]!</span>")
			// Simulate toxic leak
			for(var/mob/living/L in range(2, src))
				L.apply_damage(2, TOX)

	if(health <= 0 || temperature > 70)
		explode()

/obj/structure/machinery/sub_physical/fuel_storage/proc/explode()
	visible_message("<span class='danger'><b>[src] CATASTROPHICALLY RUPTURES!</b></span>")
	playsound(src.loc, 'sound/machines/submarine/fire.ogg', 100, 1)
	playsound(src.loc, 'sound/machines/submarine/nuke_exp.ogg', 100, 1)
	explosion(src.loc, 1, 2, 4)
	qdel(src)

// --- 11. STERN PLANE ---

/obj/structure/sub_physical/stern_plane
	name = "stern diving plane"
	desc = "An external hydrofoil used for steering. Requires surfacing for maintenance."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "placeholder_plane"
	var/plane_side = "port"

/obj/structure/sub_physical/stern_plane/New()
	..()
	if(my_sub)
		my_sub.stern_planes += src

/obj/structure/sub_physical/stern_plane/attackby(obj/item/W, mob/user)
	if(my_sub && my_sub.depth > 0)
		to_chat(user, "<span class='warning'>You cannot reach the external planes while submerged!</span>")
		return
	..()
	update_sub_efficiency()

/obj/structure/sub_physical/stern_plane/proc/update_sub_efficiency()
	if(!my_sub || !my_sub.stern_planes.len) return
	var/total_health = 0
	for(var/obj/structure/sub_physical/stern_plane/SP in my_sub.stern_planes)
		total_health += (SP.health / SP.max_health)
	my_sub.steering_efficiency = total_health / my_sub.stern_planes.len


// Dummy item for torpedo implementation
/obj/item/weapon/torpedo
	name = "Mk.48 torpedo"
	desc = "A massive heavyweight acoustic-homing torpedo."
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "torpedo_item"
	w_class = 5.0 // Heavy

