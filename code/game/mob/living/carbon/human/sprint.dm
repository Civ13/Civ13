// Sprinting: a run with everything in it. A sprinter moves SPRINT_SPEED_MULT
// times as fast as a runner and spends SPRINT_STAMINA_MULT times the stamina,
// dropping back to a run when stamina runs low. Sprinting into someone can
// knock them over (and maybe the sprinter too); sprinting into a door, gate or
// barricade that will not open rams it; a wall or other fixed obstacle just
// stops the sprinter hard. Strength and dexterity tilt every collision
// (physical_contest.dm).
//
// A sprint is a run: m_intent stays "run" and sprinting marks the faster gait,
// so everything that treats running bodies as running (aim, slips, trips,
// noise) treats sprinters the same way.

/mob/living/human/var/tmp/sprinting = FALSE
/mob/living/human/var/tmp/next_sprint_collision = 0

/mob/living/human/proc/is_sprinting()
	return sprinting && m_intent == "run" && !prone && !lying && !buckled && !riding

/mob/living/human/proc/sprint_stamina_share()
	var/list/S = stats ? stats["stamina"] : null
	if (!islist(S) || S.len < 2 || S[2] <= 0)
		return 0
	return S[1] / S[2]

// Whether this body could break into a sprint now. Tells the player why not
// when feedback is set.
/mob/living/human/proc/can_start_sprint(feedback = TRUE)
	if (stat != CONSCIOUS || lying || buckled || riding)
		return FALSE
	if (legcuffed)
		if (feedback)
			to_chat(src, SPAN_WARNING("You can't sprint with [legcuffed] on your legs."))
		return FALSE
	if (sprint_stamina_share() < SPRINT_START_FRACTION)
		if (feedback)
			to_chat(src, SPAN_WARNING("You're too winded to sprint."))
		return FALSE
	return TRUE

/mob/living/human/proc/update_move_intent_hud()
	if (HUDneed && HUDneed.Find("m_intent"))
		var/obj/screen/mov_intent/I = HUDneed["m_intent"]
		I.update_icon()

// Break into a sprint, standing up from a crawl first. Returns TRUE on success.
/mob/living/human/proc/start_sprint(feedback = TRUE)
	if (!can_start_sprint(feedback))
		return FALSE
	if (m_intent == "proning")
		if (facing_dir)
			set_face_dir()
		prone = FALSE
		update_posture_transform()
	m_intent = "run"
	sprinting = TRUE
	update_move_intent_hud()
	return TRUE

// Ease back to an ordinary run.
/mob/living/human/proc/stop_sprint(message)
	if (!sprinting)
		return FALSE
	sprinting = FALSE
	if (message)
		to_chat(src, message)
	update_move_intent_hud()
	return TRUE

// After each sprint step: drop to a run once stamina runs low.
/mob/living/human/proc/sprint_stamina_check()
	if (sprinting && sprint_stamina_share() < SPRINT_STOP_FRACTION)
		stop_sprint(SPAN_WARNING("You're out of breath and slow to a run."))

/mob/living/human/proc/sprint_mode_name()
	return is_sprinting() ? "sprint" : m_intent

/client/verb/m_intent_sprint()
	set name = "m-intent-sprint"
	set hidden = TRUE
	if (!ishuman(mob))
		return
	var/mob/living/human/H = mob
	if (H.stat != CONSCIOUS)
		return
	if (H.is_sprinting())
		H.stop_sprint()
	else
		H.start_sprint()

// ---- collisions ------------------------------------------------------------

// Called from human/Bump before anything else handles the obstacle. Returns
// TRUE when the sprint collision took the bump.
/mob/living/human/proc/sprint_collide(atom/A)
	if (!A || !is_sprinting() || world.time < next_sprint_collision)
		return FALSE
	if (ishuman(A))
		return sprint_collide_person(A)
	if (istype(A, /obj/structure/simple_door))
		return sprint_ram_door(A)
	if (isobj(A))
		var/obj/O = A
		if (!O.density)
			return FALSE
		if (is_structure_impact_part(O) && istype(O, /obj/structure))
			return sprint_ram_structure(O)
		if (get_dir(src, O) != dir)
			return FALSE
		if (istype(O, /obj/structure/closet) && !(locate(/mob/living) in O))
			return sprint_shove_object(O)
		return sprint_slam(O)
	// A wall: only a head-on hit counts, not a shoulder grazing a corner.
	if (isturf(A) && A.density && get_dir(src, A) == dir)
		return sprint_slam(A)
	return FALSE

// Spend the collision: stamina, the cooldown and the sprint itself.
/mob/living/human/proc/sprint_collision_cost()
	next_sprint_collision = world.time + SPRINT_COLLIDE_COOLDOWN
	stats["stamina"][1] = max(0, stats["stamina"][1] - SPRINT_COLLIDE_STAMINA)
	sprinting = FALSE
	update_move_intent_hud()

/mob/living/human/proc/sprint_fall(stagger = 2)
	Weaken(stagger)
	if (client)
		shake_camera(src, 2, 2)

/mob/living/human/proc/sprint_collide_person(mob/living/human/target)
	if (target == src || target.lying || target.buckled || target.riding || target == pulling || target.stat == DEAD)
		return FALSE
	sprint_collision_cost()
	// Weight and drive knock a body down; balance keeps it up.
	var/ratio = physical_contest_ratio(src, target, 2, 1)
	var/knocked = prob(physical_contest_chance(SPRINT_KNOCKDOWN_CHANCE, ratio))
	// The sprinter keeps their own feet with dexterity, and against someone lighter.
	var/self_fall = prob(physical_contest_chance(SPRINT_SELF_FALL_CHANCE, physical_contest_ratio(target, src, 1, 2)))
	playsound(get_turf(target), "swing_hit", 50, TRUE)
	if (knocked)
		target.sprint_fall(2)
		target.stats["stamina"][1] = max(0, target.stats["stamina"][1] - SPRINT_COLLIDE_STAMINA)
		target.stop_sprint()
	if (knocked && self_fall)
		visible_message(SPAN_DANGER("[src] slams into [target] at a sprint and they both go down!"), SPAN_DANGER("You slam into [target] and you both go down!"))
	else if (knocked)
		visible_message(SPAN_DANGER("[src] slams into [target] at a sprint, knocking them over!"), SPAN_DANGER("You slam into [target] and knock them over!"))
	else if (self_fall)
		visible_message(SPAN_DANGER("[src] slams into [target] at a sprint and bounces off onto the ground!"), SPAN_DANGER("You slam into [target] and bounce off onto the ground!"))
	else
		visible_message(SPAN_WARNING("[src] barrels into [target], who holds their ground."), SPAN_WARNING("You barrel into [target], who holds their ground."))
	if (self_fall)
		sprint_fall(2)
	log_attack("[key_name(src)] sprinted into [key_name(target)][knocked ? ", knocking them down" : ""][self_fall ? " and fell" : ""].")
	return TRUE

// Force behind a sprinting shoulder: mostly strength, some dexterity.
/mob/living/human/proc/sprint_ram_force()
	return SPRINT_RAM_FORCE * clamp(physical_power(3, 1), 0.5, 2)

// Bounce off something solid. Nimble people keep their feet more often.
/mob/living/human/proc/sprint_slam_recoil()
	var/nimble = clamp(physical_power(0, 1), 0.5, 2)
	if (prob(clamp(SPRINT_SLAM_FALL_CHANCE / nimble, 1, 95)))
		sprint_fall(2)
		return TRUE
	return FALSE

// A door that would not open for this sprinter. An open or openable door
// is left to open the ordinary way.
/obj/structure/simple_door/proc/sprint_door_holds(mob/user)
	if (!density || state || isSwitchingStates)
		return FALSE
	if (istype(src, /obj/structure/simple_door/key_door))
		var/obj/structure/simple_door/key_door/K = src
		if (istype(K, /obj/structure/simple_door/key_door/custom))
			if (K.locked)
				return TRUE
		else if (K.keyslot && K.keyslot.locked && !istype(K, /obj/structure/simple_door/key_door/anyone))
			return TRUE
	return !canOpen(user)

// Doors that a ram can damage: the ones a kick wears down, not jail, faction
// or event doors.
/obj/structure/simple_door/proc/sprint_ram_damages()
	if (istype(src, /obj/structure/simple_door/party_train) || istype(src, /obj/structure/simple_door/train_raid_crew))
		return FALSE
	if (istype(src, /obj/structure/simple_door/key_door))
		var/obj/structure/simple_door/key_door/K = src
		if (!K.door_takes_kick_damage() || istype(K, /obj/structure/simple_door/key_door/faction_door))
			return FALSE
	return !isnull(health)

/mob/living/human/proc/sprint_ram_door(obj/structure/simple_door/D)
	if (!D.sprint_door_holds(src))
		return FALSE
	sprint_collision_cost()
	if (istype(D.material, /material/wood))
		playsound(get_turf(D), 'sound/effects/wooddoorhit.ogg', 100)
	else if (istype(D.material, /material/paper))
		playsound(get_turf(D), 'sound/effects/cardboardpunch.ogg', 100)
	else
		playsound(get_turf(D), 'sound/effects/grillehit.ogg', 100)
	visible_message(SPAN_DANGER("[src] rams \the [D] with their shoulder!"), SPAN_DANGER("You ram \the [D] with your shoulder!"))
	apply_damage(rand(1, 3), BRUTE, pick("l_arm", "r_arm"))
	if (D.sprint_ram_damages())
		D.structure_impact(sprint_ram_force(), IMPACT_CRUSH, src, dir)
	sprint_slam_recoil()
	log_attack("[key_name(src)] rammed [D] at [get_area_name(D)] ([D.x],[D.y],[D.z]).")
	return TRUE

// Gates, barricades and other breakable building parts in the way.
/mob/living/human/proc/sprint_ram_structure(obj/structure/S)
	sprint_collision_cost()
	playsound(get_turf(S), 'sound/effects/bang.ogg', 50, TRUE)
	visible_message(SPAN_DANGER("[src] rams \the [S] with their shoulder!"), SPAN_DANGER("You ram \the [S] with your shoulder!"))
	apply_damage(rand(1, 3), BRUTE, pick("l_arm", "r_arm"))
	S.structure_impact(sprint_ram_force(), IMPACT_CRUSH, src, dir)
	sprint_slam_recoil()
	return TRUE

// A loose crate or locker takes the hit and slides a tile.
/mob/living/human/proc/sprint_shove_object(obj/O)
	sprint_collision_cost()
	playsound(get_turf(O), 'sound/effects/thud.ogg', 50, TRUE)
	if (step(O, dir))
		visible_message(SPAN_WARNING("[src] slams into \the [O], shoving it along."), SPAN_WARNING("You slam into \the [O] and shove it along."))
	else
		visible_message(SPAN_WARNING("[src] slams into \the [O]."), SPAN_WARNING("You slam into \the [O]."))
		sprint_slam_recoil()
	return TRUE

// A wall, tree or anything else solid: a hard stop.
/mob/living/human/proc/sprint_slam(atom/A)
	sprint_collision_cost()
	playsound(get_turf(src), 'sound/effects/thud.ogg', 50, TRUE)
	apply_damage(rand(1, 3), BRUTE, pick("l_arm", "r_arm", "head"))
	if (sprint_slam_recoil())
		visible_message(SPAN_DANGER("[src] runs straight into \the [A] and falls over!"), SPAN_DANGER("You run straight into \the [A] and fall over!"))
	else
		visible_message(SPAN_WARNING("[src] runs straight into \the [A]."), SPAN_WARNING("You run straight into \the [A]."))
	return TRUE
