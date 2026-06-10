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

// --- 5. BILGE PUMP ---

/obj/structure/machinery/sub_physical/bilge_pump
	name = "bilge pump"
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "bilge_pump"
	health = 80
	max_health = 80
	var/active = FALSE

/obj/structure/machinery/sub_physical/bilge_pump/process()
	if(!active || health <= 0) return
	
	// Physical water interaction
	var/turf/T = get_turf(src)
	if(T && T.vars.Find("water_level"))
		if(T.vars["water_level"] > 0)
			T.vars["water_level"] = max(0, T.vars["water_level"] - 10)

// --- 6. TORPEDO TUBE ---

/obj/structure/machinery/sub_physical/torpedo_tube
	name = "torpedo launch tube"
	icon = 'icons/obj/machines/submarine.dmi'
	icon_state = "torpedo_tube1"
	var/tube_id = 1 // 1-4
	var/is_loaded = FALSE

/obj/structure/machinery/sub_physical/torpedo_tube/attack_hand(mob/user)
	if(..()) return
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
	if(health < 30)
		to_chat(user, "<span class='warning'>The processor is too damaged to function.</span>")
		return
	if(food_stored <= 0)
		to_chat(user, "<span class='notice'>The galley is out of supplies.</span>")
		return

	food_stored--
	to_chat(user, "<span class='notice'>The machine clunks and produces a nutritional ration.</span>")
	new /obj/item/weapon/reagent_containers/food/snacks/ration(src.loc)

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
		/obj/item/weapon/wrench = 1
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

/obj/item/weapon/reagent_containers/food/snacks/ration
	name = "nutritional ration"
	desc = "A dense, flavorless nutritional paste."
	icon = 'icons/obj/items.dmi'
	icon_state = "ration"
