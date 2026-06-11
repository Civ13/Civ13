var/global/list/all_submarines = list()

// ============================================================
// Crew Member datum - tracks individual crew status
// ============================================================
/datum/crew_member
	var/mob/living/human/member   // Reference to the living mob
	var/name = "Unknown"
	var/assignment = "Crewman"    // Job assignment
	var/role = "crew"             // "captain", "officer", "crew"
	var/health = 100              // Current health percentage
	var/total_damage = 0          // Sum of all brute+burn damage
	var/oxygen_status = "Nominal" // "Nominal", "Low O2", "Suffocating", "Drowning"
	var/compartment = ""          // Current compartment ID
	var/conscious = TRUE          // FALSE if unconscious/dead
	var/injured = FALSE           // TRUE if has significant damage

/datum/crew_member/New(var/mob/living/human/_mob, var/_assignment)
	if(!_mob) return
	member = _mob
	name = _mob.real_name
	assignment = _assignment

	// Determine role from assignment
	if(_assignment == "Captain")
		role = "captain"
	else if(_assignment == "Officer")
		role = "officer"
	else
		role = "crew"

/datum/crew_member/proc/update_status()
	if(!member || QDELETED(member))
		return FALSE

	// Health tracking
	health = member.health
	total_damage = member.getBruteLoss() + member.getBurnLoss() + member.getToxLoss() + member.getOxyLoss()
	injured = (total_damage > 20)

	// Consciousness
	conscious = (member.stat == CONSCIOUS)

	// Compartment check
	compartment = ""
	var/turf/floor/sub_deck/T = get_turf(member)
	if(T && istype(T) && T.compartment_id)
		compartment = T.compartment_id

	// Oxygen status
	if(T && istype(T))
		if(T.water_depth >= SUB_WATER_DROWNING_HEAVY)
			oxygen_status = "Drowning"
		else if(T.water_depth >= SUB_WATER_DROWNING_MOD)
			oxygen_status = "Drowning"
		else if(T.oxygen_moles < 5)
			oxygen_status = "Suffocating"
		else if(T.oxygen_moles < SUB_ATMOS_NORMAL_O2 * 0.5)
			oxygen_status = "Low O2"
		else
			oxygen_status = "Nominal"
	else
		oxygen_status = "Unknown"

	return TRUE

/datum/submarine
	// General/Structural
	var/vessel_name = "SSN-Civ13"
	var/crush_depth = 300
	var/keel_depth = 30
	var/has_nuclear_engine = TRUE  // FALSE for diesel-only subs

	// Movement & Physics
	var/x_pos = 500.0
	var/y_pos = 500.0
	var/heading = 0.0
	var/target_heading = 0.0
	var/depth = 0.0
	var/target_depth = 0.0
	var/speed = 0.0
	var/target_speed = 0.0
	var/ballast = 0.0 // Tons
	var/steering_efficiency = 1.0 // Multiplier for turn rate based on stern plane health

	// Power & Endurance
	var/battery_current = 3000.0
	var/battery_max = 3000.0
	var/diesel_fuel = 40000.0
	var/diesel_max = 40000.0
	var/diesel_throttle = 0.0 // 0 to 100
	var/electrolysis_active = FALSE
	var/noise_level = 0 // Represents how much noise the sub is making, affects passive sonar detection
	var/radar_range_long = FALSE // True for long range, false for short

	// Reactors (Indices 1 and 2)
	var/list/r_control_rods = list(100, 100)
	var/list/r_core_temp = list(20.0, 20.0)
	var/list/r_primary_pump_speed = list(0, 0)
	var/list/r_secondary_pump_speed = list(0, 0)
	var/list/r_primary_pressure = list(0, 0)
	var/list/r_secondary_pressure = list(0, 0)
	var/list/r_power_output = list(0.0, 0.0) // MW
	var/list/r_scrammed = list(FALSE, FALSE)
	var/list/r_melted = list(FALSE, FALSE)
	var/reactor_hum_channel = 0

	// Weapons & Sensors
	var/master_arm = FALSE
	var/list/tubes_loaded = list(FALSE, FALSE, FALSE, FALSE)
	var/radar_active = FALSE
	var/sonar_active = FALSE
	var/sonar_mode = SUB_SONAR_PASSIVE
	var/list/detected_targets = list()
	var/datum/vessel_contact/selected_target // For weapons targeting
	var/bearing_sweep = 0            // Current sweep angle (0-360) for sonar bearing display
	var/list/tagged_contacts = list() // Contacts tagged for overworld map display
	
	// Physical World Links
	var/list/internal_turfs = list() // Turfs that make up the interior
	var/list/reactor_turfs = list()  // Turfs in the reactor rooms
	var/list/stern_planes = list()   // References to physical plane objects

	// Crew Management
	var/list/crew = list()           // All /datum/crew_member on this sub
	var/tick_counter = 0             // Process tick counter

/datum/submarine/New()
	..()
	all_submarines += src

/datum/submarine/proc/process_tick()
	tick_counter++

	// 1. Reactor Thermodynamics Loop
	for(var/i=1, i<=2, i++)
		if(r_melted[i])
			continue

		// Reactor Room Flooding: water degrades coolant pumps and forces SCRAM
		var/reactor_water = 0
		if(global.subcom_flooding)
			reactor_water = global.subcom_flooding.get_compartment_water_level(SUB_COMP_REACTOR_ROOM)

		// Coolant pump degradation: pumps lose effectiveness as water rises
		// At 0cm = 100%, at 100cm = 0% (fully submerged pumps fail)
		var/water_pump_factor = clamp(1.0 - (reactor_water / 100), 0, 1)

		// Full flood: force SCRAM on both reactors
		if(reactor_water >= 100 && !r_scrammed[i])
			r_scrammed[i] = TRUE
			r_control_rods[i] = 100
			world << "<span class='warning'><b>[vessel_name]: REACTOR [i] SCRAMMED — reactor room flooded!</b></span>"

		// Heat Generation: heat increases as rods are pulled out (0 rods = max heat)
		var/heat_added = 0
		if(!r_scrammed[i])
			heat_added = (100 - r_control_rods[i]) * 5

		// Heat Dissipation: proportional to pump speed, temp, and water factor
		var/heat_removed = r_primary_pump_speed[i] * (r_core_temp[i] * 0.05) * water_pump_factor
		
		r_core_temp[i] += (heat_added - heat_removed)
		r_core_temp[i] = max(SUB_AMBIENT_TEMP, r_core_temp[i])

		// Meltdown Check
		if(r_core_temp[i] > SUB_MELTDOWN_TEMP)
			r_melted[i] = TRUE
			handle_meltdown(i)
		
		// Power Output (Turbines): 1% efficiency per secondary pump RPM, degraded by flooding
		r_power_output[i] = r_secondary_pump_speed[i] * (r_core_temp[i] * 0.01) * water_pump_factor

	// 2. Propulsion & Movement Physics
	
	// Heading Control (Shortest turn path)
	var/heading_diff = target_heading - heading
	if(abs(heading_diff) > 0.1)
		if(heading_diff > 180) heading_diff -= 360
		if(heading_diff < -180) heading_diff += 360
		
		heading += clamp(heading_diff, -SUB_TURN_RATE * steering_efficiency, SUB_TURN_RATE * steering_efficiency)
		
		// Normalize to 0-359
		if(heading < 0) heading += 360
		if(heading >= 360) heading -= 360

	// Determine available power source and max speed
	var/current_max_speed = 0
	var/power_source_nuclear = FALSE
	var/power_source_diesel = FALSE

	if(has_nuclear_engine)
		power_source_nuclear = (r_power_output[1] + r_power_output[2]) > 5.0
		if(power_source_nuclear)
			current_max_speed = SUB_MAX_SPEED_NUCLEAR
			if(!reactor_hum_channel && internal_turfs.len)
				var/sound/S = sound('sound/machines/submarine/engine_nuclear_hum.ogg', repeat = TRUE, wait = 0, volume = 25, channel = 773)
				reactor_hum_channel = 773
				src << S
		else
			// Nuclear sub with reactors offline: fall back to battery
			current_max_speed = SUB_MAX_SPEED_ELECTRIC
			if(reactor_hum_channel)
				for(var/mob/M in world)
					if(M.client)
						M << sound(null, channel = reactor_hum_channel)
				reactor_hum_channel = 0
	else
		// Diesel-only submarine
		if(depth == 0 && diesel_throttle > 0 && diesel_fuel > 0)
			power_source_diesel = TRUE
			current_max_speed = SUB_MAX_SPEED_DIESEL
		else
			// Submerged or no diesel power: battery only
			current_max_speed = SUB_MAX_SPEED_ELECTRIC
	
	// Adjust Speed
	var/desired_clamped_speed = clamp(target_speed, 0, current_max_speed)
	if(speed < desired_clamped_speed)
		speed = min(speed + SUB_ACCEL_RATE, desired_clamped_speed)
	else if(speed > desired_clamped_speed)
		speed = max(speed - SUB_ACCEL_RATE, desired_clamped_speed)

	// Diesel Generators
	// Diesel-only subs: diesel provides direct propulsion when surfaced + charges batteries
	// Nuclear subs: diesel only charges batteries when surfaced (backup role)
	// Engine Room Flooding: water shuts down diesel engines entirely
	var/engine_water = 0
	if(global.subcom_flooding)
		engine_water = global.subcom_flooding.get_compartment_water_level(SUB_COMP_ENGINE_ROOM)
	if(engine_water >= 50 && diesel_throttle > 0)
		diesel_throttle = 0
		world << "<span class='warning'><b>[vessel_name]: Diesel engines shut down — engine room flooded!</b></span>"
	if(depth == 0 && diesel_throttle > 0)
		var/fuel_usage = diesel_throttle * 2
		if(diesel_fuel >= fuel_usage)
			diesel_fuel -= fuel_usage
			if(!has_nuclear_engine && power_source_diesel)
				// Diesel-only: engines drive propulsion directly AND charge batteries
				battery_current = min(battery_max, battery_current + (200 * diesel_throttle / 100))
			else
				// Nuclear sub: diesel generators charge batteries (backup)
				battery_current = min(battery_max, battery_current + (350 * 2))
		else
			diesel_throttle = 0

	// Depth Control
	if(depth < target_depth)
		depth = min(depth + 1, target_depth)
	else if(depth > target_depth)
		depth = max(depth - 1, target_depth)

	if(depth > crush_depth)
		trigger_structural_damage()

	// Depth alarm when approaching crush depth
	if(depth > crush_depth * 0.8 && prob(10))
		if(internal_turfs.len)
			playsound(pick(internal_turfs), 'sound/machines/submarine/alarm_depth.ogg', 60, 1)

	// Virtual position update (Trigonometry)
	// heading uses compass convention: 0=North, 90=East, clockwise
	// cos/sin use math convention: 0=East, counterclockwise
	// Convert: math_angle = 90 - heading
	var/move_angle = 90 - heading
	x_pos += cos(move_angle) * (speed * SUB_TICK_SCALE)
	y_pos += sin(move_angle) * (speed * SUB_TICK_SCALE)

	// Wrap around map boundaries (toroidal space)
	x_pos = ((x_pos % SUB_MAP_SIZE) + SUB_MAP_SIZE) % SUB_MAP_SIZE
	y_pos = ((y_pos % SUB_MAP_SIZE) + SUB_MAP_SIZE) % SUB_MAP_SIZE

	// 3. Power Consumption & Electrolysis
	var/total_drain = 5.0 // Baseline kW for lights/electronics (e.g., 5 kW)

	if(sonar_active)
		total_drain += (sonar_mode == SUB_SONAR_ACTIVE) ? SUB_SONAR_POWER_ACTIVE : SUB_SONAR_POWER_PASSIVE
	if(radar_active)
		total_drain += radar_range_long ? SUB_RADAR_POWER_LONG : SUB_RADAR_POWER_SHORT
	
	if(speed > 0)
		var/prop_drain = (speed / 30) * 15000 // kW drain for propulsion
		if(has_nuclear_engine)
			total_drain += prop_drain
		else if(depth > 0)
			// Diesel subs only use electric propulsion when submerged
			total_drain += prop_drain

	// Production from Nuclear Reactor
	var/total_production = 0
	if(has_nuclear_engine)
		total_production = (r_power_output[1] + r_power_output[2]) * 1000 // MW -> kW

	// Apply power balance
	var/power_balance = total_production - total_drain
	battery_current = clamp(battery_current + power_balance, 0, battery_max)

	if(electrolysis_active)
		if(battery_current >= 50)
			battery_current -= 50
			generate_oxygen()
		else // Not enough power for electrolysis
			electrolysis_active = FALSE

	// Emergency Shutdown
	if(battery_current <= 0)
		battery_shutdown()

	// 4. Crew Status Update (every 10 ticks to reduce overhead)
	if(tick_counter % 10 == 0)
		update_crew_status()
		sensor_sweep()

/datum/submarine/proc/sensor_sweep()
	if(!sonar_active && !radar_active)
		detected_targets.Cut()
		return

	detected_targets.Cut()
	
	var/s_range = (sonar_mode == SUB_SONAR_ACTIVE) ? SUB_SONAR_RANGE_ACTIVE : SUB_SONAR_RANGE_PASSIVE
	var/r_range = radar_range_long ? SUB_RADAR_RANGE_LONG : SUB_RADAR_RANGE_SHORT

	if(sonar_active)
		// Rotate bearing sweep (15 degrees per sweep update)
		bearing_sweep = (bearing_sweep + 15) % 360

	// Detect other player submarines
	for(var/datum/submarine/other_sub in all_submarines)
		if(other_sub == src) continue
		
		var/raw_dist = sqrt((other_sub.x_pos - x_pos)**2 + (other_sub.y_pos - y_pos)**2)
		var/dist = raw_dist * SUB_MAP_SCALE // Convert to meters
		var/can_detect = FALSE
		var/c_type = SUB_CONTACT_SUBMERGED
		
		// Passive sonar: surface + submerged contacts, within passive range
		if(sonar_active && sonar_mode == SUB_SONAR_PASSIVE && dist <= s_range)
			can_detect = TRUE
			c_type = other_sub.depth == 0 ? SUB_CONTACT_SURFACE : SUB_CONTACT_SUBMERGED
		// Active sonar: surface + submerged contacts, within active range
		if(sonar_active && sonar_mode == SUB_SONAR_ACTIVE && dist <= s_range)
			can_detect = TRUE
			c_type = other_sub.depth == 0 ? SUB_CONTACT_SURFACE : SUB_CONTACT_SUBMERGED
		// Radar: surface + submerged + air contacts, within radar range
		if(radar_active && dist <= r_range)
			can_detect = TRUE
			c_type = other_sub.depth == 0 ? SUB_CONTACT_SURFACE : SUB_CONTACT_SUBMERGED
			
		if(can_detect)
			// Calculate relative bearing
			var/dx = other_sub.x_pos - x_pos
			var/dy = other_sub.y_pos - y_pos
			var/bearing_deg = arctan(dy, dx)
			if(bearing_deg < 0)
				bearing_deg += 360

			var/datum/vessel_contact/C = new(other_sub.vessel_name, c_type, SUB_NATION_NEUTRAL)
			C.range = dist
			C.bearing = (bearing_deg + 360) % 360
			C.noise_signature = other_sub.speed * 5 // Faster speed = higher noise
			detected_targets += C

	// Detect NPC vessels via sensors
	if(global.subcom_map)
		for(var/datum/vessel_contact/npc/NPC in global.subcom_map.active_vessels)
			if(QDELETED(NPC)) continue

			var/raw_dist = euclidean_distance(NPC.x_pos, NPC.y_pos, x_pos, y_pos)
			var/dist = raw_dist * SUB_MAP_SCALE // Convert to meters
			var/can_detect = FALSE
			
			// Radar Check: surface + submerged + air contacts
			if(radar_active && dist <= r_range)
				can_detect = TRUE
					
			// Sonar Check (if not already detected by radar)
			if(sonar_active && dist <= s_range && !can_detect)
				if(sonar_mode == SUB_SONAR_PASSIVE)
					// Passive: surface + submerged contacts, submerged must be moving
					if(NPC.contact_type == SUB_CONTACT_SUBMERGED && NPC.speed > 0)
						can_detect = TRUE
					else if(NPC.contact_type == SUB_CONTACT_SURFACE)
						can_detect = TRUE
				else
					// Active: surface + submerged contacts
					if(NPC.contact_type == SUB_CONTACT_SUBMERGED || NPC.contact_type == SUB_CONTACT_SURFACE)
						can_detect = TRUE

			if(can_detect)
				var/dx = NPC.x_pos - x_pos
				var/dy = NPC.y_pos - y_pos
				var/bearing_deg = arctan(dy, dx)
				if(dx < 0)
					bearing_deg += 180
				else if(dy < 0 && dx >= 0)
					bearing_deg += 360

				var/datum/vessel_contact/C = new(NPC.name, NPC.contact_type, NPC.nationality)
				C.range = dist
				C.bearing = (bearing_deg + 360) % 360
				C.noise_signature = NPC.speed * 5
				detected_targets += C

/datum/submarine/proc/handle_meltdown(var/index)
	r_scrammed[index] = TRUE
	r_power_output[index] = 0
	if(reactor_hum_channel)
		for(var/mob/M in world)
			if(M.client)
				M << sound(null, channel = reactor_hum_channel)
		reactor_hum_channel = 0
	
	// Find the reactor core object for this index
	var/obj/structure/machinery/sub_physical/reactor_core/the_core
	for(var/obj/structure/machinery/sub_physical/reactor_core/R in world)
		if(R.id == index)
			the_core = R
			break

	// Explosion and radiation at each reactor turf
	for(var/turf/T in reactor_turfs)
		T.visible_message("<span class='danger'>The reactor core has collapsed! Intense radiation fills the room!</span>")
		playsound(T, 'sound/machines/submarine/nuke_exp.ogg', 100, 1)
		playsound(T, 'sound/machines/submarine/scram_alarm.ogg', 80, 1)
		ignite_turf(T, 30, 5) // Fire burns for 30 ticks, 5 damage per tick

	// Explosion from the core itself
	if(the_core)
		explosion(get_turf(the_core), 1, 2, 4, 6)
		// Lethal radiation burst
		radiation_pulse(get_turf(the_core), 5, 300, 50)

	shake_crew(10, 6)

/datum/submarine/proc/trigger_structural_damage()
	if(!internal_turfs.len) return
	
	if(prob(10))
		var/turf/T = pick(internal_turfs)
		if(T)
			// If it's a hull wall, breach it (which handles flooding automatically)
			if(istype(T, /turf/wall/sub_hull))
				var/turf/wall/sub_hull/H = T
				H.apply_breach_damage(200)
			else
				// Non-hull interior turf - create a leak effect
				new /obj/effect/step_trigger/sub_leak(T)
				T.visible_message("<span class='danger'>The hull buckles! A high-pressure leak springs open!</span>")
				playsound(T, 'sound/machines/submarine/gas.ogg', 80, 1)
				// Flood adjacent deck turfs
				for(var/turf/floor/sub_deck/D in range(1, T))
					D.add_water(SUB_BREACH_INFLOW_BASE)

/datum/submarine/proc/generate_oxygen()
	// Inject oxygen into all compartments via the flooding controller
	if(global.subcom_flooding)
		for(var/cid in global.subcom_flooding.compartment_turfs)
			global.subcom_flooding.inject_oxygen(cid, 2.0)  // 2 moles per tick per compartment

/datum/submarine/proc/battery_shutdown()
	radar_active = FALSE
	sonar_active = FALSE
	electrolysis_active = FALSE
	// Stop looping sensor sounds
	for(var/mob/M in world)
		if(M.client)
			M << sound(null, channel = 770)
			M << sound(null, channel = 771)
			M << sound(null, channel = 772)
			M << sound(null, channel = 773)
	reactor_hum_channel = 0
	// Diesel-only subs can still run on diesel if surfaced
	if(!has_nuclear_engine && depth == 0 && diesel_fuel > 0 && diesel_throttle > 0)
		target_speed = min(target_speed, SUB_MAX_SPEED_DIESEL)
	else
		target_speed = min(target_speed, SUB_MAX_SPEED_ELECTRIC)
	// Notify bridge
	// bridge_message("MAIN POWER FAILURE: Switch to emergency battery successful. Non-essential systems offline.")

// ---- Torpedo Impact Handler ----
// Called when a virtual torpedo detonates near this submarine.
// Randomly damages physical hull turfs to simulate flooding/breach.

/datum/submarine/proc/apply_hit(var/base_damage)
	torpedo_hit(base_damage)

/datum/submarine/proc/shake_crew(var/duration = 4, var/strength = 3)
	for(var/turf/T in internal_turfs)
		for(var/mob/living/L in T)
			if(L.client && L.stat != DEAD)
				shake_camera(L, duration, strength)

/datum/submarine/proc/torpedo_hit(var/base_damage)
	if(!internal_turfs.len) return

	shake_crew(6, 4)

	// Determine how many hull turfs get damaged
	var/turfs_to_hit = clamp(round(base_damage / 100), 1, 5)

	for(var/i = 1, i <= turfs_to_hit, i++)
		var/turf/T = pick(internal_turfs)
		if(!T) continue

		// Check if it's a hull turf and reduce its integrity
		if(istype(T, /turf/wall/sub_hull))
			var/turf/wall/sub_hull/H = T
			H.apply_breach_damage(base_damage)
		else
			// Non-hull interior turf - flood adjacent deck turfs
			for(var/turf/floor/sub_deck/D in range(1, T))
				if(D.compartment_id)
					D.add_water(round(base_damage / 20))

	// Structural shock: give everyone on board a notification
	for(var/mob/living/L in range(10, pick(internal_turfs)))
		to_chat(L, "<span class='danger'><b>A violent explosion shakes the entire submarine!</b></span>")
		playsound(pick(internal_turfs), 'sound/machines/submarine/crash.ogg', 100, 1)

/datum/submarine/proc/launch_torpedo(var/tube_index)
	if(!master_arm || !tubes_loaded[tube_index] || !selected_target) return FALSE
	
	tubes_loaded[tube_index] = FALSE

	// Calculate launch heading toward the selected target
	var/tgt_x = 0
	var/tgt_y = 0
	if(istype(selected_target, /datum/vessel_contact/npc))
		var/datum/vessel_contact/npc/N = selected_target
		tgt_x = N.x_pos
		tgt_y = N.y_pos
	else
		return FALSE

	var/dx = tgt_x - x_pos
	var/dy = tgt_y - y_pos
	var/launch_heading = arctan(dy, dx)

	// Create a virtual torpedo datum
	var/datum/projectile/torpedo/T = new(x_pos, y_pos, launch_heading, SUB_TORPEDO_DAMAGE, TRUE)
	T.target = selected_target
	T.sub_target = null

	// Register with the world map controller
	if(global.subcom_map)
		global.subcom_map.active_torpedoes += T

	// Notify via radio
	if(global.subcom_map && global.subcom_map.missions && global.subcom_map.missions.radio_console)
		global.subcom_map.missions.radio_console.add_log("TORPEDO AWAY from tube [tube_index]. Bearing [round(launch_heading)] degrees. Godspeed.")

	return TRUE

// ---- Weapon Impact Handler ----
// Handles different weapon types hitting the submarine.

/datum/submarine/proc/apply_weapon_hit(var/damage, var/weapon_type, var/hit_x = 0, var/hit_y = 0)
	switch(weapon_type)
		if("torpedo")
			torpedo_hit(damage)
			if(internal_turfs.len)
				playsound(pick(internal_turfs), 'sound/machines/submarine/crash.ogg', 100, 1)
		if("depth_charge")
			// Depth charges do area damage - hit multiple hull turfs near the explosion
			var/turfs_to_hit = clamp(round(damage / 80), 2, 6)
			if(internal_turfs.len)
				var/turf/center = pick(internal_turfs)
				playsound(center, 'sound/machines/submarine/depth_charge_close.ogg', 100, 1)
				for(var/i = 1, i <= turfs_to_hit, i++)
					var/turf/wall/sub_hull/H = locate(/turf/wall/sub_hull) in range(3, center)
					if(H)
						H.apply_breach_damage(damage)
						center = H
				shake_crew(8, 5)
				for(var/mob/living/L in range(8, center))
					to_chat(L, "<span class='danger'><b>Depth charges detonate nearby! The hull groans under the pressure!</b></span>")
		if("missile")
			// Missiles are like torpedoes but also cause structural shock
			torpedo_hit(damage)
			if(internal_turfs.len)
				playsound(pick(internal_turfs), 'sound/machines/submarine/missile_alarm.ogg', 80, 1)
				playsound(pick(internal_turfs), 'sound/machines/submarine/crash.ogg', 100, 1)
				for(var/mob/living/L in range(6, pick(internal_turfs)))
					to_chat(L, "<span class='danger'><b>The missile impact sends shrapnel flying through the compartment!</b></span>")
		if("gun")
			// Naval guns do localized damage
			torpedo_hit(round(damage / 3))

	// Send damage report via radio
	if(global.subcom_map && global.subcom_map.missions && global.subcom_map.missions.radio_console)
		global.subcom_map.missions.radio_console.add_log("ALERT: Hull impact detected! Weapon type: [uppertext(weapon_type)]. Damage assessment in progress.")

	// Check for critical damage
	check_critical_damage()

// ---- Critical Damage Check ----

/datum/submarine/proc/check_critical_damage()
	if(!internal_turfs.len) return

	// Count breached hull sections
	var/breached_hulls = 0
	for(var/turf/wall/sub_hull/H in internal_turfs)
		if(H.breached)
			breached_hulls++

	if(breached_hulls >= 3)
		if(global.subcom_map && global.subcom_map.missions && global.subcom_map.missions.radio_console)
			global.subcom_map.missions.radio_console.add_log("EMERGENCY: Multiple hull breaches! submarine integrity critically compromised!")

// ============================================================
// Attack Simulation (Admin Debug)
// ============================================================

/datum/submarine/proc/simulate_attack(var/attack_type)
	if(!internal_turfs.len) return

	switch(attack_type)
		if("depth_charge")
			sim_depth_charge()
		if("reactor_meltdown")
			sim_reactor_meltdown()
		if("fire")
			sim_start_fire()
		if("hull_breach")
			sim_hull_breach()
		if("flood")
			sim_flood_compartment()
		if("torpedo")
			sim_torpedo_hit()
		if("missile")
			sim_missile_strike()

/datum/submarine/proc/sim_depth_charge()
	// Area damage across multiple hull sections
	var/turfs_to_hit = rand(2, 5)
	var/turf/center = pick(internal_turfs)
	playsound(center, 'sound/machines/submarine/depth_charge_close.ogg', 100, 1)
	playsound(center, 'sound/machines/submarine/depth_charge_distant.ogg', 80, 1)

	for(var/i = 1, i <= turfs_to_hit, i++)
		var/turf/wall/sub_hull/H = locate(/turf/wall/sub_hull) in range(4, center)
		if(H)
			H.apply_breach_damage(rand(150, 400))
			center = H
	shake_crew(8, 5)
	for(var/mob/living/L in range(10, center))
		to_chat(L, "<span class='danger'><b>Depth charges detonate nearby! The hull groans under the pressure!</b></span>")

	if(global.subcom_map && global.subcom_map.missions && global.subcom_map.missions.radio_console)
		global.subcom_map.missions.radio_console.add_log("ALERT: Multiple depth charge detonations detected in vicinity! Hull damage reported.")

/datum/submarine/proc/sim_reactor_meltdown()
	// SCRAM reactor 1 and force meltdown
	var/index = pick(1, 2)
	if(r_melted[index])
		// Try the other one
		index = index == 1 ? 2 : 1
		if(r_melted[index])
			return // Both already melted

	r_control_rods[index] = 100
	r_scrammed[index] = FALSE
	r_core_temp[index] = SUB_MELTDOWN_TEMP + 100
	// The process_tick will call handle_meltdown() next tick

	if(global.subcom_map && global.subcom_map.missions && global.subcom_map.missions.radio_console)
		global.subcom_map.missions.radio_console.add_log("EMERGENCY: Reactor [index] control rods failed! Core temperature exceeding limits! MELTDOWN IMMINENT!")

/datum/submarine/proc/sim_start_fire()
	// Ignite fires in 1-3 random internal turfs
	var/fires_to_start = rand(1, 3)
	for(var/i = 1, i <= fires_to_start, i++)
		var/turf/T = pick(internal_turfs)
		if(T)
			ignite_turf(T, rand(20, 40), rand(3, 8))
			T.visible_message("<span class='danger'>A fire erupts in the compartment!</span>")
			playsound(T, 'sound/machines/submarine/fire.ogg', 60, 1)
			// Activate fire spread system on sub_deck turfs
			if(istype(T, /turf/floor/sub_deck))
				var/turf/floor/sub_deck/D = T
				D.ignite_deck_fire(rand(20, 40), rand(600, 1000))

	if(global.subcom_map && global.subcom_map.missions && global.subcom_map.missions.radio_console)
		global.subcom_map.missions.radio_console.add_log("ALERT: Fire reported aboard the submarine! All hands to damage control!")

/datum/submarine/proc/sim_hull_breach()
	// Directly breach a random hull section
	var/turf/wall/sub_hull/H = locate(/turf/wall/sub_hull) in internal_turfs
	if(!H)
		// Fallback: search nearby
		H = locate(/turf/wall/sub_hull) in range(5, pick(internal_turfs))
	if(H)
		H.apply_breach_damage(500) // Enough to guarantee a breach
		shake_crew(6, 4)
		for(var/mob/living/L in range(8, H))
			to_chat(L, "<span class='danger'><b>Hull breach! Water is flooding in!</b></span>")

	if(global.subcom_map && global.subcom_map.missions && global.subcom_map.missions.radio_console)
		global.subcom_map.missions.radio_console.add_log("EMERGENCY: Hull breach detected! Flooding in progress!")

/datum/submarine/proc/sim_flood_compartment()
	// Add significant water to a random compartment
	if(!global.subcom_flooding || !global.subcom_flooding.compartment_turfs.len)
		return

	var/list/compartments = list()
	for(var/cid in global.subcom_flooding.compartment_turfs)
		compartments += cid

	if(!compartments.len)
		return

	var/target_comp = pick(compartments)
	var/list/turfs = global.subcom_flooding.compartment_turfs[target_comp]
	for(var/turf/floor/sub_deck/T in turfs)
		T.add_water(rand(80, 150))

	if(internal_turfs.len)
		playsound(pick(internal_turfs), 'sound/machines/submarine/alarm_flooding.ogg', 70, 1)
		for(var/mob/living/L in range(10, pick(internal_turfs)))
			to_chat(L, "<span class='danger'><b>Flooding detected in [target_comp]! Water levels rising rapidly!</b></span>")

	if(global.subcom_map && global.subcom_map.missions && global.subcom_map.missions.radio_console)
		global.subcom_map.missions.radio_console.add_log("ALERT: Flooding reported in [target_comp]! Emergency bulkheads engaging!")

/datum/submarine/proc/sim_torpedo_hit()
	torpedo_hit(SUB_TORPEDO_DAMAGE)
	if(internal_turfs.len)
		playsound(pick(internal_turfs), 'sound/machines/submarine/crash.ogg', 100, 1)

	if(global.subcom_map && global.subcom_map.missions && global.subcom_map.missions.radio_console)
		global.subcom_map.missions.radio_console.add_log("EMERGENCY: TORPEDO IMPACT! Hull damage sustained! Casualties reported!")

/datum/submarine/proc/sim_missile_strike()
	torpedo_hit(SUB_TORPEDO_DAMAGE + 100)
	if(internal_turfs.len)
		playsound(pick(internal_turfs), 'sound/machines/submarine/missile_alarm.ogg', 80, 1)
		playsound(pick(internal_turfs), 'sound/machines/submarine/crash.ogg', 100, 1)
		for(var/mob/living/L in range(8, pick(internal_turfs)))
			to_chat(L, "<span class='danger'><b>Missile impact! Explosive force tears through the hull!</b></span>")

	if(global.subcom_map && global.subcom_map.missions && global.subcom_map.missions.radio_console)
		global.subcom_map.missions.radio_console.add_log("EMERGENCY: MISSILE STRIKE CONFIRMED! Severe structural damage! All hands brace for impact!")

// ============================================================
// Crew Management Procs
// ============================================================

/datum/submarine/proc/add_crew_member(var/mob/living/human/H, var/assignment)
	if(!H) return
	// Check if already tracked
	for(var/datum/crew_member/CM in crew)
		if(CM.member == H)
			return CM
	var/datum/crew_member/CM = new(H, assignment)
	crew += CM
	return CM

/datum/submarine/proc/remove_crew_member(var/mob/living/human/H)
	for(var/datum/crew_member/CM in crew)
		if(CM.member == H || QDELETED(CM.member))
			crew -= CM
			qdel(CM)
			return

/datum/submarine/proc/update_crew_status()
	// Remove dead/deleted crew
	var/list/to_remove = list()
	for(var/datum/crew_member/CM in crew)
		if(!CM.update_status())
			to_remove += CM
	for(var/datum/crew_member/CM in to_remove)
		crew -= CM
		qdel(CM)

	// Auto-detect crew from mobs on the sub's Z-level
	for(var/mob/living/human/H in world)
		if(H.stat == DEAD) continue
		var/turf/floor/sub_deck/T = get_turf(H)
		if(T && istype(T) && (T in internal_turfs))
			// Check if already tracked
			var/found = FALSE
			for(var/datum/crew_member/CM in crew)
				if(CM.member == H)
					found = TRUE
					break
			if(!found)
				add_crew_member(H, H.original_job_title ? H.original_job_title : "Crewman")

/datum/submarine/proc/get_crew_count()
	return crew.len

/datum/submarine/proc/get_crew_by_role(var/role)
	var/list/result = list()
	for(var/datum/crew_member/CM in crew)
		if(CM.role == role)
			result += CM
	return result

/datum/submarine/proc/get_injured_crew()
	var/list/result = list()
	for(var/datum/crew_member/CM in crew)
		if(CM.injured)
			result += CM
	return result

/datum/submarine/proc/get_suffocating_crew()
	var/list/result = list()
	for(var/datum/crew_member/CM in crew)
		if(CM.oxygen_status != "Nominal")
			result += CM
	return result

/datum/submarine/proc/get_crew_in_compartment(var/compartment_id)
	var/list/result = list()
	for(var/datum/crew_member/CM in crew)
		if(CM.compartment == compartment_id)
			result += CM
	return result

/datum/submarine/proc/get_crew_summary()
	var/total = crew.len
	var/injured_count = 0
	var/suffocating_count = 0
	var/unconscious_count = 0
	for(var/datum/crew_member/CM in crew)
		if(CM.injured) injured_count++
		if(CM.oxygen_status != "Nominal") suffocating_count++
		if(!CM.conscious) unconscious_count++
	return list("total" = total, "injured" = injured_count, "suffocating" = suffocating_count, "unconscious" = unconscious_count)

/obj/effect/step_trigger/sub_leak
	name = "hull breach"
	desc = "A catastrophic breach in the hull."
	icon = 'icons/effects/effects.dmi'
	icon_state = "sparks"