// Check Movement (IC verb): tells a player what is slowing them and by how
// much, with the hill around the tile they stand on. Read-only: it mirrors
// the costs in human/movement_delay(), human/get_run_delay() and the ground
// block of /client/Move (mob_movement.dm) without changing any of them.
// tests/terrain_height/probe.dm checks the body costs add up to movement_delay().

// One labelled cost: amount in deciseconds per step, added only when nonzero.
/proc/movement_check_add(list/parts, label, amount)
	if (amount)
		parts[label] = (parts[label] || 0) + amount
	return amount

// The body costs that human/movement_delay() adds, by cause.
/mob/living/human/proc/movement_check_body_parts()
	. = list()
	if (species && species.slowdown)
		movement_check_add(., "your build ([species.name])", species.slowdown)
	var/health_deficiency = maxHealth - health
	if (health_deficiency >= 40)
		movement_check_add(., "injuries", health_deficiency / 25)
	if (!(species && (species.flags & NO_PAIN)) && halloss >= 30)
		movement_check_add(., "pain", halloss / 25)
	var/hunger = 0
	switch (nutrition)
		if (-INFINITY to 50)
			hunger = 2.50
		if (50 to 75)
			hunger = 2.25
		if (75 to 100)
			hunger = 2.00
		if (100 to 150)
			hunger = 1.75
		if (150 to 220)
			hunger = 1.50
	movement_check_add(., "hunger (eat until you are over half full)", hunger)
	var/thirst = 0
	switch (water)
		if (-INFINITY to 50)
			thirst = 2.50
		if (50 to 75)
			thirst = 2.25
		if (75 to 100)
			thirst = 2.00
		if (100 to 150)
			thirst = 1.75
		if (150 to 192)
			thirst = 1.50
	movement_check_add(., "thirst (drink until you are over half full)", thirst)
	var/low_mood = 0
	switch (mood)
		if (0 to 20)
			low_mood = 0.90
		if (20 to 40)
			low_mood = 0.8
		if (40 to 60)
			low_mood = 0.2
	movement_check_add(., "low mood", low_mood)
	var/worn = 0
	if (wear_suit)
		var/obj/item/clothing/WS = wear_suit
		worn += WS.slowdown
		if (WS.accessories && WS.accessories.len)
			for (var/obj/item/clothing/accessory/AC in WS.accessories)
				worn += AC.slowdown
	if (w_uniform)
		var/obj/item/clothing/WU = w_uniform
		worn += WU.slowdown
		if (WU.accessories && WU.accessories.len)
			for (var/obj/item/clothing/accessory/AC in WU.accessories)
				worn += AC.slowdown
	movement_check_add(., "bulky clothing or armour", worn)
	if (shoes)
		movement_check_add(., "your [shoes.name]", shoes.slowdown)
	movement_check_add(., "wet clothes (wring them out or dry off by a fire)", wet_clothes_slowdown())
	movement_check_add(., "armour plates", armor_plate_slowdown())
	if (istype(back, /obj/item/weapon/storage/backpack))
		var/obj/item/weapon/storage/backpack/BP = back
		movement_check_add(., "your [BP.name]", BP.carry_slowdown)
	for (var/obj/item/weapon/shield/S in list(l_hand, r_hand))
		movement_check_add(., "your [S.name]", S.slowdown)
	var/limbs = 0
	if (buckled && istype(buckled, /obj/structure/bed/chair/wheelchair))
		for (var/organ_name in list("l_hand", "r_hand", "l_arm", "r_arm"))
			var/obj/item/organ/external/E = get_organ(organ_name)
			if (!E || E.is_stump())
				limbs += 2
				continue
			if (E.status & ORGAN_SPLINTED)
				limbs += 0.4
			else if (E.status & ORGAN_BROKEN)
				limbs += 1
	else
		for (var/organ_name in list("l_foot", "r_foot", "l_leg", "r_leg"))
			var/obj/item/organ/external/E = get_organ(organ_name)
			if (!E || E.is_stump())
				limbs += 4
			else if (E.status & ORGAN_SPLINTED)
				limbs += 0.5
			else if (E.status & ORGAN_BROKEN)
				limbs += 1.5
	movement_check_add(., "broken, splinted or missing limbs", limbs)
	var/obj/item/organ/external/chest = get_organ("chest")
	if (!chest || ((chest.status & ORGAN_BROKEN) && !chest.is_held_still() && chest.brute_dam > chest.min_broken_damage) || (chest.status & ORGAN_MUTATED))
		movement_check_add(., "broken ribs (splint them)", 3)
	else if ((chest.status & ORGAN_BROKEN) && chest.brute_dam > chest.min_broken_damage)
		movement_check_add(., "splinted ribs", 1)
	if (shock_stage >= 10)
		movement_check_add(., "shock", 0.5)
	if (aiming && aiming.aiming_at)
		movement_check_add(., "aiming", 5)
	movement_check_add(., "damaged feet or legs", max(2 * stance_damage, 0))
	if (chem_effects.Find(CE_SPEEDBOOST))
		movement_check_add(., "a stimulant", -0.40)

// Ground costs on F as /client/Move adds them, by cause. Snow and mud vary
// a little from step to step; the average is shown.
/mob/living/human/proc/movement_check_ground_parts(turf/floor/F)
	. = list()
	if (!istype(F) || !isnull(riding_mob))
		return
	var/covered = locate(/obj/covers) in F
	var/water_depth = 0
	for (var/obj/effect/flooding/FLD in F)
		switch (FLD.flood_level)
			if (1)
				water_depth = 2
			if (2)
				water_depth = 4
			if (3)
				water_depth = 6
	if (istype(F, /turf/floor/sub_deck))
		var/turf/floor/sub_deck/SD = F
		if (SD.water_depth >= 150)
			water_depth = 6
		else if (SD.water_depth >= 100)
			water_depth = 4
		else if (SD.water_depth >= 50)
			water_depth = 2
	var/ground_label = "flood water"
	var/ground = water_depth * footwear_terrain_mult(src, "wade")
	if (F.has_snow_cover() && !covered && !lizard)
		ground_label = "snow (snowshoes help; floors and roads stay clear)"
		ground = 1.5 * footwear_terrain_mult(src, "snow")
	else if (F.muddy && !lizard && weather_look_at(F) != "")
		ground_label = "mud (tamped earth, floors and roads never turn to mud)"
		ground = 2.5 * footwear_terrain_mult(src, "mud")
		if (weather_at(F) == WEATHER_EXTREME && findtext(weather_look_at(F), "monsoon"))
			ground = 4.5 * footwear_terrain_mult(src, "mud")
	if (istype(F, /turf/floor/trench/flooded))
		ground_label = "a flooded trench"
		ground = 2.5 * footwear_terrain_mult(src, "wade")
	movement_check_add(., ground_label, ground)
	if (!crab && F.move_delay)
		var/wade = istype(F, /turf/floor/beach/water) ? footwear_terrain_mult(src, "wade") : 1
		movement_check_add(., "wading through [F.name]", F.move_delay * wade)
	if (!(F.has_snow_cover() && !covered))
		movement_check_add(., "snow footwear off the snow", footwear_offsnow_slowdown(src))

// The run delay at this velocity without load or orders (mob/get_run_delay).
/mob/living/human/proc/movement_check_unloaded_run_delay()
	switch (velocity)
		if (0 to 3)
			return run_delay_maximum
		if (4 to 7)
			return run_delay_maximum / 1.03
		if (8 to 11)
			return run_delay_maximum / 1.06
	return run_delay_maximum / 1.09

/mob/living/human/proc/movement_check_intent_mult()
	switch (m_intent)
		if ("walk")
			return 1.5
		if ("stealth")
			return 3
		if ("proning")
			return 0
	return 1

// Speed multiplier from traits and job, as /client/Move divides the step by it.
/mob/living/human/proc/movement_check_speed_mult()
	. = movement_speed_multiplier
	if (find_trait("Slowness"))
		. *= 0.85
	else if (find_trait("Agile"))
		. *= 1.15
	else if (original_job_title == "Tuy Phai")
		. *= 1.25
	if (find_trait("Gigantism"))
		. *= 0.9

// How the hill around T feels, one line per direction that slopes.
/proc/movement_check_hill_lines(turf/T)
	. = list()
	if (!T || !map || !map.terrain_height_file)
		return
	var/datum/terrain_heights/H = map.terrain_heights()
	if (!H || !H.rows_by_z["[T.z]"])
		return
	var/static/list/dir_names = list("[NORTH]" = "north", "[SOUTH]" = "south", "[EAST]" = "east", "[WEST]" = "west")
	for (var/d in cardinal)
		var/turf/N = get_step(T, d)
		if (!N || N.density)
			continue
		var/levels = terrain_step_levels(T, N)
		if (!levels)
			continue
		var/factor = terrain_grade_factor(levels, N.terrain_packed())
		var/dir_name = dir_names["[d]"]
		var/percent = round(abs(factor - 1) * 100)
		if (levels > 0)
			. += "[dir_name]: up [levels] level\s, about [percent]% slower[N.terrain_packed() ? " (tamped earth halves the climb)" : ""]"
		else
			. += "[dir_name]: down [-levels] level\s, about [percent]% faster"

/proc/movement_check_number(n)
	return "[round(n, 0.01)]"

/mob/living/human/verb/check_movement()
	set name = "Check Movement"
	set category = "IC"
	set desc = "See what is slowing you down and how to move faster."
	if (stat == DEAD)
		return
	to_chat(src, jointext(movement_check_report(), "<br>"))

/mob/living/human/proc/movement_check_report()
	. = list("<b>What affects your speed here</b>")
	if (riding_mob)
		. += "You are riding [riding_mob]: your mount sets the pace."
		return
	var/turf/T = get_turf(src)
	handle_stance()
	var/intent_mult = movement_check_intent_mult()
	var/base_step = movement_check_unloaded_run_delay() * (intent_mult || 1)
	var/list/costs = movement_check_body_parts()
	var/list/ground = movement_check_ground_parts(T)
	for (var/label in ground)
		costs[label] = ground[label]
	if (drowsyness > 0)
		costs["drowsiness"] = 3
	for (var/obj/item/weapon/material/spear/sarissa/S in list(l_hand, r_hand))
		if (S.deployed)
			costs["your deployed [S.name]"] = (costs["your deployed [S.name]"] || 0) + 6
	if (pulling)
		if (ismob(pulling))
			costs["pulling [pulling]"] = 1.25 * pull_drag_mult()
		else if (istype(pulling, /obj/item/weapon/gun/projectile/automatic/stationary))
			costs["pulling [pulling]"] = 1 * pull_drag_mult()
		else if (istype(pulling, /obj/structure))
			var/obj/structure/pulled_structure = pulling
			costs["pulling [pulling]"] = pulled_structure.drag_delay(src) * pull_drag_mult()
	if (grab_list && grab_list.len)
		costs["holding or carrying someone"] = grab_move_cost()
	// Carried weight scales the walking and running pace.
	if (intent_mult)
		var/load = get_run_delay() / max(0.01, movement_check_unloaded_run_delay() * leader_order_move_mult())
		if (load > 1.001)
			costs["carried weight (drop or stow heavy things)"] = base_step * (load - 1)
	var/list/slower = list()
	var/list/faster = list()
	var/total = base_step
	for (var/label in costs)
		var/amount = costs[label]
		total += amount
		var/percent = round(abs(amount) / max(0.01, base_step) * 100)
		if (!percent)
			continue
		if (amount > 0)
			slower += "- [label]: about [percent]% slower"
		else
			faster += "- [label]: about [percent]% faster"
	var/order = leader_order_move_mult()
	if (order < 1 && intent_mult)
		faster += "- your leader's order: about [round((1 - order) * 100)]% faster"
		total -= movement_check_unloaded_run_delay() * intent_mult * (1 - order)
	var/speed = movement_check_speed_mult()
	if (speed < 0.999)
		slower += "- your traits: about [round((1 / speed - 1) * 100)]% slower"
	else if (speed > 1.001)
		faster += "- your traits: about [round((1 - 1 / speed) * 100)]% faster"
	total /= max(0.1, speed)
	. += "Moving at a [m_intent == "proning" ? "crawl" : m_intent] on flat ground, a step takes about [movement_check_number(total / 10)] s (unhindered: [movement_check_number(base_step / 10)] s)."
	if (slower.len)
		. += "<b>Slowing you:</b>"
		. += slower
	else
		. += "Nothing on you or under you is slowing you down."
	if (faster.len)
		. += "<b>Speeding you up:</b>"
		. += faster
	. += movement_check_ground_line(T)
	var/list/hill = movement_check_hill_lines(T)
	if (hill.len)
		. += "<b>Hills from here</b> (on top of the above):"
		for (var/line in hill)
			. += "- [line]"
	. += "<i>Fastest paths: lay a floor or a road over the ground. Built ground is level and never muddy. Tamped earth keeps the hill but halves the climb, and grading can only move ground two levels.</i>"

// What the tile underfoot does to hills.
/mob/living/human/proc/movement_check_ground_line(turf/T)
	if (!T)
		return "You are not standing on the ground."
	if (!map || !map.terrain_height_file)
		return "There are no hills on this map."
	if (T.terrain_smoothed())
		return "You stand on built ground ([T.name]): it is level, so hills do not slow you here."
	var/height = terrain_height_at(T)
	if (T.terrain_packed())
		return "You stand on tamped earth at hill level [height]: climbs onto tamped earth cost half."
	return "You stand on natural ground ([T.name]) at hill level [height]."
