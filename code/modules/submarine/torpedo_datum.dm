// ============================================================
// Virtual Torpedo - pure coordinate tracker, no /obj needed
// ============================================================

/datum/projectile/torpedo
	var/x_pos = 0
	var/y_pos = 0
	var/heading = 0
	var/speed = SUB_TORPEDO_SPEED
	var/damage = SUB_TORPEDO_DAMAGE
	var/life_left = SUB_TORPEDO_LIFE
	var/is_homing = FALSE
	var/max_turn_rate = 15  // Max degrees per tick the torpedo can turn
	var/datum/vessel_contact/npc/target   // For NPC targets
	var/datum/submarine/sub_target         // For player sub targets
	var/launched_by_npc = FALSE           // True if an NPC fired this
	var/uid = 0                            // Unique ID for sonar tracking

var/global/next_torpedo_id = 1

/datum/projectile/torpedo/New(var/_x, var/_y, var/_heading, var/_damage = SUB_TORPEDO_DAMAGE, var/_homing = FALSE)
	x_pos = _x
	y_pos = _y
	heading = _heading
	damage = _damage
	is_homing = _homing
	uid = next_torpedo_id++

/datum/projectile/torpedo/proc/process_tick()
	life_left--
	if(life_left <= 0)
		// Torpedo expired without hitting - announce miss to target sub crew
		if(sub_target && !QDELETED(sub_target) && sub_target.internal_turfs.len)
			for(var/turf/T in sub_target.internal_turfs)
				for(var/mob/living/L in T)
					to_chat(L, "<span class='warning'><b>A torpedo passes nearby without contact.</b></span>")
		qdel(src)
		return

	// Homing: adjust heading toward target each tick
	if(is_homing)
		var/target_x = 0
		var/target_y = 0
		if(target && !QDELETED(target))
			target_x = target.source_x
			target_y = target.source_y
		else if(sub_target && !QDELETED(sub_target))
			target_x = sub_target.x_pos
			target_y = sub_target.y_pos
		else
			// No target, go straight
			is_homing = FALSE

		if(is_homing)
			var/dx = target_x - x_pos
			var/dy = target_y - y_pos
			if(abs(dx) > 0.01 || abs(dy) > 0.01)
				var/desired_heading = arctan(dy, dx)
				var/diff = desired_heading - heading
				// Normalize to -180..180
				while(diff > 180) diff -= 360
				while(diff < -180) diff += 360
				// Clamp turn rate
				if(abs(diff) > max_turn_rate)
					diff = diff > 0 ? max_turn_rate : -max_turn_rate
				heading += diff
				// Normalize heading to 0..360
				heading = ((heading % 360) + 360) % 360

	// Move
	x_pos += cos(heading) * speed * SUB_TICK_SCALE
	y_pos += sin(heading) * speed * SUB_TICK_SCALE

	// Boundary check
	if(x_pos < 0 || x_pos > SUB_MAP_SIZE || y_pos < 0 || y_pos > SUB_MAP_SIZE)
		qdel(src)
		return

	// Detonation check
	check_detonation()

// ---- Detonation ----

/datum/projectile/torpedo/proc/check_detonation()
	// Against NPC vessel contact
	if(target && !QDELETED(target))
		var/dist = euclidean_distance(x_pos, y_pos, target.source_x, target.source_y)
		if(dist < SUB_TORPEDO_DETONATE)
			detonate_npc(target)
			return

	// Against player submarine
	if(sub_target && !QDELETED(sub_target))
		var/dist = euclidean_distance(x_pos, y_pos, sub_target.x_pos, sub_target.y_pos)
		if(dist < SUB_TORPEDO_DETONATE)
			detonate_player(sub_target)
			return

/datum/projectile/torpedo/proc/detonate_npc(var/datum/vessel_contact/npc/N)
	if(!N)
		return
	N.apply_damage(damage)
	// Torpedo is consumed on detonation
	qdel(src)

/datum/projectile/torpedo/proc/detonate_player(var/datum/submarine/sub)
	if(!sub)
		return

	// Announce torpedo impact
	if(sub.internal_turfs.len)
		for(var/turf/T in sub.internal_turfs)
			for(var/mob/living/L in T)
				to_chat(L, "<span class='danger'><font size='3'><b>TORPEDO IMPACT!</b></font></span>")

	// Apply hull damage to physical turfs on the sub's Z-level
	sub.torpedo_hit(damage)

	qdel(src)

// ---- Helper ----

/proc/euclidean_distance(var/x1, var/y1, var/x2, var/y2)
	return sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)
