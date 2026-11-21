// ============================================================
// Heteromorph breath (phase 4 of the Dragonoid plan). Hidden mechanic: keep
// it out of changelog lines, the wiki and the public Crafting Atlas.
// ------------------------------------------------------------
// Two breaths share one cooldown. Fire burns and ignites people in a cone
// ahead of the form; buildings catch only at the far edge of the cone, so a
// breath scorches a street without razing a town. The golden haze does no
// harm, but drains the energy of everyone it touches. A wall stops a breath
// in its column. The cone is worked out once per breath; nothing ticks.
// Art reuses icons/effects/effects.dmi (fire and smoke).
// ============================================================

/datum/heteromorph
	var/list/breaths = null // breath ids this kind's true form has

/datum/heteromorph/dragonoid
	breaths = list("fire", "haze")

/mob/living/simple_animal/heteromorph_form
	var/tmp/heteromorph_breath_ready = 0 // world.time the next breath may come

// The cone ahead of a 2x2 form standing with T as its south-west tile: rows
// of tiles outward from its front, two wide and widening by one each side
// every second row. Returns list(list(turf, row), ...); a dense turf ends
// its column. Rows are 1..length.
/proc/heteromorph_breath_cone(turf/T, dir, length)
	var/list/cone = list()
	if (!T || !(dir in cardinal))
		return cone
	var/maxw = round((length - 1) / 2)
	for (var/p in -maxw to 1 + maxw)
		for (var/row in 1 to length)
			var/w = round((row - 1) / 2)
			if (p < -w || p > 1 + w)
				continue
			var/turf/S
			switch (dir)
				if (NORTH)
					S = locate(T.x + p, T.y + 1 + row, T.z)
				if (SOUTH)
					S = locate(T.x + p, T.y - row, T.z)
				if (EAST)
					S = locate(T.x + 1 + row, T.y + p, T.z)
				if (WEST)
					S = locate(T.x - row, T.y + p, T.z)
			if (!S || S.density)
				break
			cone[++cone.len] = list(S, row)
	return cone

/obj/effect/heteromorph_breath
	name = "breath"
	icon = 'icons/effects/effects.dmi'
	icon_state = "burning_fire2"
	layer = FLY_LAYER
	mouse_opacity = FALSE
	anchored = TRUE

/proc/heteromorph_breath_puff(turf/T, state, colour)
	var/obj/effect/heteromorph_breath/B = new(T)
	B.icon_state = state
	if (colour)
		B.color = colour
	spawn(8)
		if (B && !QDELETED(B))
			qdel(B)

/mob/living/simple_animal/heteromorph_form/proc/heteromorph_breath_problem()
	if (heteromorph_leaving || heteromorph_busy || stat != CONSCIOUS || !isturf(loc))
		return "You cannot draw breath for that now."
	if (world.time < heteromorph_breath_ready)
		return "Your breath has not gathered again yet."
	return null

/mob/living/simple_animal/heteromorph_form/proc/heteromorph_breathe(kind_of_breath)
	var/problem = heteromorph_breath_problem()
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return FALSE
	var/kind = heteromorph_kind_id()
	var/datum/heteromorph/K = heteromorph_kind(kind)
	if (!K || !(kind_of_breath in K.breaths))
		return FALSE
	heteromorph_breath_ready = world.time + heteromorph_balance_num(kind, "breath_cooldown_seconds", 45) * 10
	var/length = heteromorph_balance_num(kind, "breath_length", 5)
	var/list/cone = heteromorph_breath_cone(loc, dir, length)
	var/list/hit = list()
	for (var/list/entry in cone)
		var/turf/S = entry[1]
		var/row = entry[2]
		if (kind_of_breath == "fire")
			heteromorph_breath_puff(S, "burning_fire2", null)
			if (row == length && prob(heteromorph_balance_num(kind, "fire_edge_chance", 50)))
				fire_spread_to(S) // oil_fires.dm: only the far edge sets the ground alight
		else
			heteromorph_breath_puff(S, "smoke", "#F2C94C")
		for (var/mob/living/L in S)
			if (L == src || L == heteromorph_body || (L in hit))
				continue
			hit += L
			if (kind_of_breath == "fire")
				L.adjustBurnLoss(rand(heteromorph_balance_num(kind, "fire_burn_lower", 20), heteromorph_balance_num(kind, "fire_burn_upper", 35)))
				L.fire_stacks += heteromorph_balance_num(kind, "fire_stacks", 2)
				L.IgniteMob()
			else
				heteromorph_wilt(L, kind)
	if (kind_of_breath == "fire")
		visible_message(SPAN_DANGER("\The [src] breathes a roaring torrent of fire!"))
	else
		visible_message(SPAN_WARNING("\The [src] exhales a shimmering golden haze."))
	heteromorph_log("[key_name(src)] breathed [kind_of_breath] at [x],[y],[z], touching [hit.len] [hit.len == 1 ? "creature" : "creatures"][hit.len ? ": [english_list(heteromorph_breath_names(hit))]" : ""].")
	return TRUE

/proc/heteromorph_breath_names(list/hit)
	var/list/names = list()
	for (var/mob/living/L in hit)
		names += L.ckey ? "[L.real_name] ([L.ckey])" : "[L]"
	return names

// The golden haze: no wound, but strength and energy drain away.
/proc/heteromorph_wilt(mob/living/L, kind)
	var/mob/living/human/H = L
	if (istype(H) && islist(H.stats["stamina"]))
		H.stats["stamina"][1] = max(0, H.stats["stamina"][1] - heteromorph_balance_num(kind, "haze_stamina", 60))
	L.Weaken(heteromorph_balance_num(kind, "haze_weaken", 2))
	to_chat(L, SPAN_WARNING("A warm golden haze settles on you, and your limbs grow heavy."))

/mob/living/simple_animal/heteromorph_form/proc/heteromorph_breathe_fire()
	set name = "Breathe Fire"
	set category = "IC"
	set desc = "Breathe a cone of fire ahead of you."
	if (usr != src)
		return
	heteromorph_breathe("fire")

/mob/living/simple_animal/heteromorph_form/proc/heteromorph_breathe_haze()
	set name = "Breathe Golden Haze"
	set category = "IC"
	set desc = "Breathe a haze that leaves those it touches weak and weary."
	if (usr != src)
		return
	heteromorph_breathe("haze")
