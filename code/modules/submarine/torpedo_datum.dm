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
	var/datum/vessel_contact/npc/target   // For NPC targets
	var/datum/submarine/sub_target         // For player sub targets
	var/launched_by_npc = FALSE           // True if an NPC fired this

/datum/projectile/torpedo/New(var/_x, var/_y, var/_heading, var/_damage = SUB_TORPEDO_DAMAGE, var/_homing = FALSE)
	x_pos = _x
	y_pos = _y
	heading = _heading
	damage = _damage
	is_homing = _homing

/datum/projectile/torpedo/proc/process_tick()
	life_left--
	if(life_left <= 0)
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
				heading = arctan(dy, dx)

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

	// Apply hull damage to physical turfs on the sub's Z-level
	sub.torpedo_hit(damage)

	qdel(src)

// ---- Helper ----

/proc/euclidean_distance(var/x1, var/y1, var/x2, var/y2)
	return sqrt((x2 - x1) ** 2 + (y2 - y1) ** 2)
