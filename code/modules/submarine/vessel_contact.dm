/datum/vessel_contact
	var/name = "Unknown"
	var/bearing = 0           // 0-360 degrees relative to North
	var/range = 0             // Distance in meters
	var/noise_signature = 0   // Decibels or frequency ID
	var/contact_type = SUB_CONTACT_SURFACE
	var/nationality = SUB_NATION_NEUTRAL
	var/source_x = 0          // World-space X of the detected vessel (for torpedo targeting)
	var/source_y = 0          // World-space Y of the detected vessel (for torpedo targeting)

/datum/vessel_contact/New(var/_name, var/_type, var/_nat)
	name = _name
	contact_type = _type
	nationality = _nat

// ============================================================
// NPC Vessel AI - virtual overworld contact with state machine
// ============================================================

/datum/vessel_contact/npc
	// Virtual position on the 1000x1000 grid
	var/x_pos = 0
	var/y_pos = 0
	var/heading = 0
	var/speed = 0

	// Stats loaded from types.txt
	var/max_speed = 30
	var/hull_strength = 800
	var/max_hull_strength = 800
	var/sensor_range = 40000
	var/sonar_range = 25000
	var/passive_sonar_threshold = 20  // NPC detects player if player noise > this
	var/patrol_speed = 12
	var/attack_speed = 25
	var/radar_cross_section = 1.0
	var/enemy_type_ref = null         // Reference to /datum/subcom_enemy that spawned this

	// Acoustic signature (LOFAR tonals in Hz)
	var/sig_low = 0
	var/sig_mid = 0
	var/sig_high = 0
	var/classification = "Unknown"

	// Weapons: list of lists, each inner list = list(name, damage, range, type, cooldown_ticks)
	var/list/weapons = list()
	var/list/weapon_timers = list()  // Cooldown counters, parallel to weapons list

	// AI state machine
	var/ai_state = SUB_AI_PATROL
	var/tick_counter = 0

	// Patrol waypoints
	var/patrol_target_x = 0
	var/patrol_target_y = 0

	// Hunt / attack state: last known player position
	var/last_known_x = 0
	var/last_known_y = 0

	// Attack timing
	var/attack_cooldown = 0

	// Patrol boundary box (NPCs stay within a region)
	var/patrol_min_x = 100
	var/patrol_min_y = 100
	var/patrol_max_x = 900
	var/patrol_max_y = 900

	// Attack circle parameters
	var/circle_angle = 0          // Current angle for circle-strafing
	var/circle_radius = 25        // Radius of attack circle
	var/circle_cw = TRUE          // Direction: TRUE = clockwise

/datum/vessel_contact/npc/New(var/_name, var/_x, var/_y)
	..(_name, SUB_CONTACT_SURFACE, SUB_NATION_HOSTILE)
	x_pos = _x
	y_pos = _y
	generate_patrol_target()

// ---- Types.txt Loading ----

var/global/list/npc_type_cache = list()

/proc/load_npc_types()
	if(npc_type_cache.len)
		return npc_type_cache

	var/list/lines = file2list("data/subcom/types.txt")
	if(!lines || !lines.len)
		return npc_type_cache
	var/current_vessel = null
	var/list/current_data = list()

	for(var/line in lines)
		line = trim(line)
		if(!line || copytext(line, 1, 2) == "#")
			continue

		if(copytext(line, 1, 2) == ascii2text(91))
			// Save previous vessel if any
			if(current_vessel && current_data.len)
				npc_type_cache[current_vessel] = current_data
			current_vessel = null
			current_data = list()
			continue

		var/split = findtext(line, "=")
		if(!split) continue
		var/key = copytext(line, 1, split)
		var/value = copytext(line, split + 1)
		if(key == "name")
			current_vessel = value
		current_data[key] = value

	// Save last vessel
	if(current_vessel && current_data.len)
		npc_type_cache[current_vessel] = current_data

	return npc_type_cache

// Apply stats from the type cache to this NPC instance
/datum/vessel_contact/npc/proc/load_type(var/type_name)
	var/list/types = load_npc_types()
	if(!types[type_name])
		return FALSE

	var/list/data = types[type_name]
	if(data["max_speed"])      max_speed = text2num(data["max_speed"])
	if(data["hull_strength"])  hull_strength = text2num(data["hull_strength"])
	if(data["sensor_range"])   sensor_range = text2num(data["sensor_range"])
	if(data["sonar_range"])    sonar_range = text2num(data["sonar_range"])
	if(data["passive_sonar_threshold"]) passive_sonar_threshold = text2num(data["passive_sonar_threshold"])
	if(data["patrol_speed"])   patrol_speed = text2num(data["patrol_speed"])
	if(data["attack_speed"])   attack_speed = text2num(data["attack_speed"])
	if(data["type"])           contact_type = data["type"]
	if(data["nation"])         nationality = data["nation"]

	// Load weapons (up to 4)
	for(var/wi = 1, wi <= 4, wi++)
		var/wname_key   = "weapon_[wi]_name"
		var/wdmg_key    = "weapon_[wi]_damage"
		var/wrange_key  = "weapon_[wi]_range"
		var/wtype_key   = "weapon_[wi]_type"
		var/wcool_key   = "weapon_[wi]_cooldown"
		if(data[wname_key] && data[wname_key] != "None")
			var/list/weapon_data = list(
				"name"    = data[wname_key],
				"damage"  = text2num(data[wdmg_key]),
				"range"   = text2num(data[wrange_key]),
				"type"    = data[wtype_key],
				"cooldown" = text2num(data[wcool_key])
			)
			weapons += list(weapon_data)
			weapon_timers += 0

	return TRUE

// ---- Patrol Waypoints ----

/datum/vessel_contact/npc/proc/generate_patrol_target()
	patrol_target_x = rand(patrol_min_x, patrol_max_x)
	patrol_target_y = rand(patrol_min_y, patrol_max_y)

// ---- Main AI Tick ----

/datum/vessel_contact/npc/proc/process_tick()
	tick_counter++

	// Decrement weapon cooldowns
	for(var/i = 1, i <= weapon_timers.len, i++)
		if(weapon_timers[i] > 0)
			weapon_timers[i]--

	switch(ai_state)
		if(SUB_AI_PATROL)
			process_patrol()
		if(SUB_AI_HUNT)
			process_hunt()
		if(SUB_AI_ATTACK)
			process_attack()

// ---- AI State: PATROL ----

/datum/vessel_contact/npc/proc/process_patrol()
	speed = patrol_speed
	navigate_to(patrol_target_x, patrol_target_y)

	// Check if we reached the patrol waypoint
	var/dist = toroidal_distance(x_pos, y_pos, patrol_target_x, patrol_target_y)
	if(dist < 5)
		generate_patrol_target()

// ---- AI State: HUNT ----

/datum/vessel_contact/npc/proc/process_hunt()
	speed = attack_speed
	navigate_to(last_known_x, last_known_y)

	var/dist = toroidal_distance(x_pos, y_pos, last_known_x, last_known_y)
	if(dist < 30)
		// Reached last known position, switch to ATTACK
		ai_state = SUB_AI_ATTACK
		attack_cooldown = 0
		// Initialize circle in a random direction
		circle_cw = prob(50)
		circle_angle = rand(0, 360)
	else if(dist > (sensor_range / SUB_MAP_SCALE))
		// Lost the contact, return to patrol after a delay
		if(tick_counter > 30)
			ai_state = SUB_AI_PATROL
			generate_patrol_target()

// ---- AI State: ATTACK ----

/datum/vessel_contact/npc/proc/process_attack()
	if(!global.subcom_map || !global.subcom_map.player_sub)
		return

	var/datum/submarine/player = global.subcom_map.player_sub
	var/dist = toroidal_distance(x_pos, y_pos, player.x_pos, player.y_pos)

	// Circle-strafe around the player instead of sitting still
	var/desired_dist = circle_radius
	if(speed < 5)
		speed = 8  // Maintain minimum speed for maneuvering

	// Calculate target position on the circle around the player
	circle_angle += circle_cw ? 8 : -8  // Degrees per tick
	if(circle_angle >= 360) circle_angle -= 360
	if(circle_angle <= 0) circle_angle += 360

	var/circle_x = player.x_pos + cos(circle_angle) * desired_dist
	var/circle_y = player.y_pos + sin(circle_angle) * desired_dist

	// Steer toward the circle point
	navigate_to(circle_x, circle_y)

	// Fire weapons when in range
	attack_cooldown--
	if(attack_cooldown <= 0)
		fire_weapons_at_player()
		attack_cooldown = 20

	// If player is too far, chase them
	if(dist > 40)
		ai_state = SUB_AI_HUNT
		last_known_x = player.x_pos
		last_known_y = player.y_pos

// ---- Toroidal Distance Helper ----

/datum/vessel_contact/npc/proc/toroidal_distance(var/x1, var/y1, var/x2, var/y2)
	var/dx = abs(x1 - x2)
	var/dy = abs(y1 - y2)
	dx = min(dx, SUB_MAP_SIZE - dx)
	dy = min(dy, SUB_MAP_SIZE - dy)
	return sqrt(dx * dx + dy * dy)

// ---- Navigation ----

/datum/vessel_contact/npc/proc/navigate_to(var/target_x, var/target_y)
	var/dx = target_x - x_pos
	var/dy = target_y - y_pos
	// Toroidal shortest-path: pick the shorter wrap direction
	if(dx > SUB_MAP_SIZE / 2) dx -= SUB_MAP_SIZE
	else if(dx < -SUB_MAP_SIZE / 2) dx += SUB_MAP_SIZE
	if(dy > SUB_MAP_SIZE / 2) dy -= SUB_MAP_SIZE
	else if(dy < -SUB_MAP_SIZE / 2) dy += SUB_MAP_SIZE
	if(abs(dx) < 0.5 && abs(dy) < 0.5)
		return

	var/target_hdg = arctan(dy, dx)
	heading = target_hdg

	x_pos += cos(heading) * speed * SUB_TICK_SCALE
	y_pos += sin(heading) * speed * SUB_TICK_SCALE

	// Wrap around map boundaries (toroidal space)
	x_pos = ((x_pos % SUB_MAP_SIZE) + SUB_MAP_SIZE) % SUB_MAP_SIZE
	y_pos = ((y_pos % SUB_MAP_SIZE) + SUB_MAP_SIZE) % SUB_MAP_SIZE

// ---- Detection Checks (called by world_map_controller) ----

/datum/vessel_contact/npc/proc/check_player_detection(var/datum/submarine/player)
	if(!player)
		return

	var/dist = toroidal_distance(x_pos, y_pos, player.x_pos, player.y_pos) * SUB_MAP_SCALE  // Convert to meters

	// Active sonar ping detected
	if(player.sonar_active && player.sonar_mode == SUB_SONAR_ACTIVE && dist <= sonar_range)
		react_to_detection(player.x_pos, player.y_pos)
		return

	// Passive sonar: noise level exceeds our threshold
	if(player.noise_level >= passive_sonar_threshold && dist <= sonar_range)
		react_to_detection(player.x_pos, player.y_pos)
		return

// ---- Detection Reaction ----

/datum/vessel_contact/npc/proc/react_to_detection(var/detected_x, var/detected_y)
	last_known_x = detected_x
	last_known_y = detected_y

	if(ai_state == SUB_AI_PATROL)
		ai_state = SUB_AI_HUNT

// ---- Weapons ----

/datum/vessel_contact/npc/proc/fire_weapons_at_player()
	if(!global.subcom_map || !global.subcom_map.player_sub)
		return
	var/datum/submarine/player = global.subcom_map.player_sub

	for(var/i = 1, i <= weapons.len, i++)
		if(weapon_timers[i] > 0)
			continue
		var/list/weapon = weapons[i]
		var/dist = toroidal_distance(x_pos, y_pos, player.x_pos, player.y_pos) * SUB_MAP_SCALE  // Convert to meters
		if(dist <= weapon["range"])
			// Fire weapon
			switch(weapon["type"])
				if("torpedo")
					var/datum/projectile/torpedo/T = new(x_pos, y_pos, arctan(player.y_pos - y_pos, player.x_pos - x_pos), weapon["damage"], FALSE)
					T.sub_target = player
					global.subcom_map.active_torpedoes += T
				if("missile")
					player.apply_weapon_hit(weapon["damage"], "missile", x_pos, y_pos)
				if("depth_charge")
					// Depth charges have their own range check via weapon["range"]
					player.apply_weapon_hit(weapon["damage"], "depth_charge", x_pos, y_pos)
				if("gun")
					player.apply_weapon_hit(weapon["damage"], "gun", x_pos, y_pos)
			weapon_timers[i] = weapon["cooldown"]
			break  // Fire one weapon per volley cycle

// ---- NPC Taking Damage ----

/datum/vessel_contact/npc/proc/apply_damage(var/damage)
	hull_strength -= damage
	if(hull_strength <= 0)
		qdel(src)