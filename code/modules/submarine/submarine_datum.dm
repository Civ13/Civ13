var/global/list/all_submarines = list()

/datum/submarine
	// General/Structural
	var/vessel_name = "SSN-Civ13"
	var/crush_depth = 300
	var/keel_depth = 30

	// Movement & Physics
	var/x_pos = 1000.0
	var/y_pos = 1000.0
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

	// Weapons & Sensors
	var/master_arm = FALSE
	var/list/tubes_loaded = list(FALSE, FALSE, FALSE, FALSE)
	var/radar_active = FALSE
	var/sonar_active = FALSE
	var/sonar_mode = SUB_SONAR_PASSIVE
	var/list/detected_targets = list()
	var/datum/vessel_contact/selected_target // For weapons targeting
	
	// Physical World Links
	var/list/internal_turfs = list() // Turfs that make up the interior
	var/list/reactor_turfs = list()  // Turfs in the reactor rooms
	var/list/stern_planes = list()   // References to physical plane objects

/datum/submarine/New()
	..()
	all_submarines += src

/datum/submarine/proc/process_tick()
	// 1. Reactor Thermodynamics Loop
	for(var/i=1, i<=2, i++)
		if(r_melted[i])
			continue

		// Heat Generation: heat increases as rods are pulled out (0 rods = max heat)
		var/heat_added = 0
		if(!r_scrammed[i])
			heat_added = (100 - r_control_rods[i]) * 5

		// Heat Dissipation: proportional to pump speed and current temp
		var/heat_removed = r_primary_pump_speed[i] * (r_core_temp[i] * 0.05)
		
		r_core_temp[i] += (heat_added - heat_removed)
		r_core_temp[i] = max(SUB_AMBIENT_TEMP, r_core_temp[i])

		// Meltdown Check
		if(r_core_temp[i] > SUB_MELTDOWN_TEMP)
			r_melted[i] = TRUE
			handle_meltdown(i)
		
		// Power Output (Turbines): 1% efficiency per secondary pump RPM
		r_power_output[i] = r_secondary_pump_speed[i] * (r_core_temp[i] * 0.01)

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

	var/power_source_nuclear = (r_power_output[1] + r_power_output[2]) > 5.0 // Threshold for turbine operation
	var/current_max_speed = power_source_nuclear ? SUB_MAX_SPEED_NUCLEAR : SUB_MAX_SPEED_ELECTRIC
	
	// Adjust Speed
	var/desired_clamped_speed = clamp(target_speed, 0, current_max_speed)
	if(speed < desired_clamped_speed)
		speed = min(speed + SUB_ACCEL_RATE, desired_clamped_speed)
	else if(speed > desired_clamped_speed)
		speed = max(speed - SUB_ACCEL_RATE, desired_clamped_speed)

	// Battery Drain if running on Electric
	if(!power_source_nuclear && speed > 0)
		battery_current = max(0, battery_current - SUB_BATTERY_DRAIN_ELECTRIC)

	// Diesel Generators (Surfaced only)
	if(depth == 0 && diesel_throttle > 0)
		var/fuel_usage = diesel_throttle * 2 // Example usage rate
		if(diesel_fuel >= fuel_usage)
			diesel_fuel -= fuel_usage
			// Charge batteries: 350kW per generator (assuming 2 generators)
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

	// Virtual position update (Trigonometry)
	// BYOND handles degrees for sin/cos
	x_pos += cos(heading) * (speed * SUB_TICK_SCALE)
	y_pos += sin(heading) * (speed * SUB_TICK_SCALE)

	// 3. Power Consumption & Electrolysis
	var/total_drain = 5.0 // Baseline kW for lights/electronics (e.g., 5 kW)

	if(sonar_active)
		total_drain += (sonar_mode == SUB_SONAR_ACTIVE) ? SUB_SONAR_POWER_ACTIVE : SUB_SONAR_POWER_PASSIVE
	if(radar_active)
		total_drain += radar_range_long ? SUB_RADAR_POWER_LONG : SUB_RADAR_POWER_SHORT
	
	if(electrolysis_active)
		if(battery_current >= 50)
			battery_current -= 50
			generate_oxygen()
		else // Not enough power for electrolysis
			electrolysis_active = FALSE

	battery_current = max(0, battery_current - total_drain)

	// Emergency Shutdown
	if(battery_current <= 0)
		battery_shutdown()

/datum/submarine/proc/sonar_sweep()
	if(!sonar_active)
		detected_targets.Cut()
		return

	detected_targets.Cut()
	var/sensor_range = (sonar_mode == SUB_SONAR_ACTIVE) ? 50000 : 20000 // meters

	for(var/datum/submarine/other_sub in all_submarines)
		if(other_sub == src) continue
		
		var/dist = sqrt((other_sub.x_pos - x_pos)**2 + (other_sub.y_pos - y_pos)**2)
		if(dist <= sensor_range)
			// Calculate relative bearing
			var/dx = other_sub.x_pos - x_pos
			var/dy = other_sub.y_pos - y_pos
			var/bearing_deg = arctan(dy / dx)
			if(dx < 0)
				bearing_deg += 180
			else if(dy < 0)
				bearing_deg += 360
			
			var/datum/vessel_contact/C = new(other_sub.vessel_name, SUB_CONTACT_SUBMERGED, SUB_NATION_NEUTRAL)
			C.range = dist
			C.bearing = (bearing_deg + 360) % 360
			C.noise_signature = other_sub.speed * 5 // Faster speed = higher noise
			detected_targets += C

/datum/submarine/proc/handle_meltdown(var/index)
	r_scrammed[index] = TRUE
	r_power_output[index] = 0
	
	for(var/turf/T in reactor_turfs)
		// This triggers standard SS13/Civ13 radiation and heat damage logic
		T.visible_message("<span class='danger'>The reactor core has collapsed! Intense radiation fills the room!</span>")
		// Hypothetical atmos/damage triggers:
		// T.assume_gas("fire", 100) 
		// T.rad_act(500)

/datum/submarine/proc/trigger_structural_damage()
	if(!internal_turfs.len) return
	
	if(prob(10))
		var/turf/T = pick(internal_turfs)
		if(T)
			// Create a leak object that drains oxygen and/or creates water
			new /obj/effect/step_trigger/sub_leak(T)
			T.visible_message("<span class='danger'>The hull buckles! A high-pressure leak springs open!</span>")
			// Sound effect placeholder:
			// playsound(T, 'sound/effects/leak.ogg', 100, 1)

/datum/submarine/proc/generate_oxygen()
	// Find the most oxygen-depleted turf inside the sub
	if(!internal_turfs.len) return
	
	var/turf/T = pick(internal_turfs)
	if(T)
		// Standard atmos interaction: inject 5 moles of O2
		// T.zone.air.adjust_gas("o2", 5)
		return TRUE

/datum/submarine/proc/battery_shutdown()
	radar_active = FALSE
	sonar_active = FALSE
	electrolysis_active = FALSE
	target_speed = min(target_speed, SUB_MAX_SPEED_ELECTRIC)
	// Notify bridge
	// bridge_message("MAIN POWER FAILURE: Switch to emergency battery successful. Non-essential systems offline.")

/datum/submarine/proc/launch_torpedo(var/tube_index)
	if(!master_arm || !tubes_loaded[tube_index] || !selected_target) return FALSE
	
	tubes_loaded[tube_index] = FALSE
	// Placeholder for creating a torpedo projectile
	// new /obj/projectile/torpedo(src.loc, selected_target)
	return TRUE

/obj/effect/step_trigger/sub_leak
	name = "hull breach"
	desc = "A catastrophic breach in the hull."
	icon = 'icons/effects/effects.dmi'
	icon_state = "spark"