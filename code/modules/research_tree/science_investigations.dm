// Repeatable Natural Science practice through real in-game evidence, separate
// from naturalist's finds, field-work counters, chapter progress and Mathematics.
#define SCIENCE_COMPARE_MIN 24
#define SCIENCE_LAB_MIN 36
#define SCIENCE_INVESTIGATION_CAP 60
#define SCIENCE_INVESTIGATION_TIME (12 SECONDS)
#define SCIENCE_INVESTIGATION_COOLDOWN (30 SECONDS)
#define SCIENCE_INVESTIGATION_HISTORY_MAX 128

/mob/living/human
	var/list/science_investigations = null // first observations; saved with this character
	var/tmp/next_science_investigation = 0

// No player-supplied display text or object references are stored.
/proc/science_investigation_key_valid(key)
	if (!istext(key) || length(key) > 128)
		return FALSE
	var/colon = findtext(key, ":")
	if (!colon || colon >= length(key))
		return FALSE
	if (!(copytext(key, 1, colon) in list("ores", "waters", "firing", "smelt", "glass", "reaction")))
		return FALSE
	for (var/i=colon+1, i<=length(key), i++)
		if (!findtextEx("abcdefghijklmnopqrstuvwxyz0123456789_/+-", copytext(key, i, i+1)))
			return FALSE
	return TRUE

/proc/clean_science_investigations(value)
	var/list/clean = list()
	if (!islist(value) || length(value) > SCIENCE_INVESTIGATION_HISTORY_MAX)
		return clean
	for (var/key in value)
		if (science_investigation_key_valid(key) && isnull(value[key]))
			clean |= key
	return clean

/proc/science_investigations_valid(value)
	return islist(value) && length(value) <= SCIENCE_INVESTIGATION_HISTORY_MAX && length(clean_science_investigations(value)) == length(value)

// Lab actions and sample comparisons use the same eligibility and payout.
/mob/living/human/proc/science_investigation_room(advanced)
	var/level = scholar_level("natural_science")
	if (advanced)
		if (level < SCIENCE_LAB_MIN)
			return 0
		return max(0, SCIENCE_INVESTIGATION_CAP - level)
	if (level < SCIENCE_COMPARE_MIN)
		return 0
	return max(0, SCIENCE_LAB_MIN - level)

/mob/living/human/proc/science_investigation_problem(advanced)
	if (!client || client.mob != src || !map || !map.book_research_enabled())
		return "There's no investigation to record here."
	if (!isturf(loc) || incapacitated() || persistence_admission_blocked())
		return "You can't investigate right now."
	if (!science_investigation_room(advanced))
		if (advanced)
			return "Advanced investigations are for Natural Science levels 36 to 60."
		return "Basic comparisons are for Natural Science levels 24 to 36. After 36 compare a raw material with its processed result, or use Investigate Reaction."
	if (world.time < next_science_investigation)
		return "Take a short break between investigations."
	return null

// Called only after the same actor finishes an admitted comparison or a
// successful controlled bench reaction. First-time exact signatures pay 1.8;
// known evidence continues to teach 0.6, even if a player alternates samples.
/mob/living/human/proc/science_investigation_credit(key, advanced)
	if (!science_investigation_key_valid(key))
		return 0
	var/family = copytext(key, 1, findtext(key, ":"))
	var/is_advanced = (family in list("smelt", "glass", "reaction"))
	if (is_advanced != advanced)
		return 0
	var/room = science_investigation_room(advanced)
	if (room <= 0)
		return 0
	if (!islist(science_investigations))
		science_investigations = list()
	var/novel = !(key in science_investigations) && science_investigations.len < SCIENCE_INVESTIGATION_HISTORY_MAX
	if (novel)
		science_investigations += key
	var/award = 0.6
	if (novel)
		award = 1.8
	var/points = min(room, award)
	var/level = scholar_level("natural_science")
	if (!islist(scholarship))
		scholarship = list()
	scholarship["natural_science"] = round((level + points) * 100 + 0.5) / 100
	next_science_investigation = world.time + SCIENCE_INVESTIGATION_COOLDOWN
	to_chat(src, SPAN_NOTICE("You finish the [novel ? "new" : "repeated"] investigation and gain [round(points * 100 + 0.5) / 100] Natural Science."))
	return points

/proc/science_ore_kind(obj/item/I)
	switch (I.type)
		if (/obj/item/stack/ore/iron)
			return "iron"
		if (/obj/item/stack/ore/copper)
			return "copper"
		if (/obj/item/stack/ore/tin)
			return "tin"
		if (/obj/item/stack/ore/zinc)
			return "zinc"
		if (/obj/item/stack/ore/lead)
			return "lead"
		if (/obj/item/stack/ore/silver)
			return "silver"
		if (/obj/item/stack/ore/gold)
			return "gold"
		if (/obj/item/stack/ore/coal, /obj/item/stack/ore/coal/twentyfive)
			return "coal"
		if (/obj/item/stack/ore/iron_sand)
			return "iron_sand"
	return null

/proc/science_fired_pair(obj/item/weapon/clay/raw, obj/item/fired)
	return istype(raw) && ispath(raw.result, /obj/item) && raw.result != raw.type && raw.result == fired.type && !stone_mold_type(raw.type) && raw.amount >= 1

// Classify actual contents, not container labels or player-written notes.
// These are observations of in-game sample composition, not claims of origin.
/proc/science_water_kind(obj/item/weapon/reagent_containers/C)
	if ((!istype(C, /obj/item/weapon/reagent_containers/glass) && !istype(C, /obj/item/weapon/reagent_containers/food/drinks)) || !C.is_open_container() || !C.reagents)
		return null
	var/water = C.reagents.get_reagent_amount("water")
	if (water < 2)
		return null
	var/salt = C.reagents.get_reagent_amount("sodiumchloride")
	var/germs = C.reagents.get_reagent_amount("cholera")
	if (C.reagents.total_volume > water + salt + germs + 0.01)
		return null
	if (salt >= 0.05)
		return germs >= 0.05 ? "salty_dirty" : "salty"
	return germs >= 0.05 ? "dirty" : "fresh"

/proc/science_pair_key(family, first, second)
	if (!first || !second || first == second)
		return null
	var/list/ordered = sortList(list(first, second))
	return "[family]:[ordered[1]]+[ordered[2]]"

// Exact game outputs with real production paths; no permission bypass or
// crafting action is performed here. The samples can be made by the scholar
// or acquired from someone else, but the investigation itself is their work.
/proc/science_processed_pair(obj/item/A, obj/item/B)
	if (A.type == /obj/item/stack/ore/glass && B.type == /obj/item/stack/material/glass)
		return "glass:sand+sheet"
	if (A.type == /obj/item/stack/ore/iron)
		switch (B.type)
			if (/obj/item/stack/ore/iron_sponge)
				return "smelt:iron+bloom"
			if (/obj/item/stack/ore/iron_sponge/steely)
				return "smelt:iron+steely_bloom"
			if (/obj/item/stack/ore/iron_pig)
				return "smelt:iron+pig"
	if (A.type == /obj/item/stack/ore/iron_sand && B.type == /obj/item/stack/ore/kera)
		return "smelt:iron_sand+kera"
	if (A.type == /obj/item/stack/ore/iron_sponge && B.type == /obj/item/stack/material/iron)
		return "smelt:bloom+wrought"
	var/ore = science_ore_kind(A)
	if (ore in list("copper", "tin", "zinc", "lead", "silver", "gold"))
		if (ispath(B.type, /obj/item/stack/material) && "[B.type]" == "/obj/item/stack/material/[ore]")
			return "smelt:[ore]+ingot"
	return null

// Data describes the actual evidence and cost: family, stable key, optional
// unfired piece to debit. Ordinary sample stacks are always whole game units.
/proc/science_sample_comparison(obj/item/A, obj/item/B)
	if (QDELETED(A) || QDELETED(B) || A == B)
		return null
	if (istype(A, /obj/item/stack) && istype(B, /obj/item/stack))
		if (A.amount < 1 || B.amount < 1)
			return null
		var/processed = science_processed_pair(A, B)
		if (!processed)
			processed = science_processed_pair(B, A)
		if (processed)
			return list("processed", processed)
		var/ores = science_pair_key("ores", science_ore_kind(A), science_ore_kind(B))
		if (ores)
			return list("ores", ores)
	var/waters = science_pair_key("waters", science_water_kind(A), science_water_kind(B))
	if (waters)
		return list("waters", waters)
	if (science_fired_pair(A, B))
		return list("firing", "firing:[A.type]", A)
	if (science_fired_pair(B, A))
		return list("firing", "firing:[B.type]", B)
	return null

/mob/living/human/verb/investigate_science_samples()
	set name = "Investigate Samples"
	set category = "IC"
	set desc = "Compare actual held samples to improve Natural Science, without a research desk."
	var/obj/item/A = l_hand
	var/obj/item/B = r_hand
	var/list/evidence = science_sample_comparison(A, B)
	if (!evidence)
		to_chat(src, SPAN_WARNING("Hold matching evidence in both hands. See Natural Science in the Skills Guide for examples."))
		return
	var/advanced = evidence[1] == "processed"
	var/problem = science_investigation_problem(advanced)
	if (problem)
		to_chat(src, SPAN_WARNING(problem))
		return
	if (A.loc != src || B.loc != src || A.nodrop || B.nodrop || A.nodrop_special_check() || B.nodrop_special_check())
		return
	var/client/actor = client
	var/datum/admission = persistence_admission_identity
	to_chat(src, SPAN_NOTICE("You start comparing the samples. The test uses one unit from each solid sample, one unit of water from each liquid sample, or one unfired clay piece."))
	if (!do_after(src, SCIENCE_INVESTIGATION_TIME, src, FALSE))
		return
	if (QDELETED(src) || client != actor || !actor || actor.mob != src || persistence_admission_changed(admission) || l_hand != A || r_hand != B || science_investigation_problem(advanced))
		return
	var/list/current = science_sample_comparison(A, B)
	if (!current || current[2] != evidence[2] || A.loc != src || B.loc != src || A.nodrop || B.nodrop || A.nodrop_special_check() || B.nodrop_special_check())
		return
	if (current[1] == "waters")
		var/obj/item/weapon/reagent_containers/left = A
		var/obj/item/weapon/reagent_containers/right = B
		if (left.reagents == right.reagents)
			return
		if (!left.reagents.remove_reagent("water", 1, TRUE) || !right.reagents.remove_reagent("water", 1, TRUE))
			return
	else if (current[1] == "firing")
		var/obj/item/weapon/clay/raw = current[3]
		if (raw.loose_pile_use(1) != 1) // the finished comparison piece survives
			return
	else
		var/obj/item/stack/left = A
		var/obj/item/stack/right = B
		if (!left.can_use(1) || !right.can_use(1))
			return
		if (!left.use(1) || !right.use(1))
			return
	science_investigation_credit(current[2], advanced)

/obj/structure/reaction_bench/verb/investigate_science_reaction()
	set name = "Investigate Reaction"
	set category = "Object"
	set src in range(1)
	var/mob/living/human/H = usr
	if (!istype(H) || !H.Adjacent(src))
		return
	var/problem = H.science_investigation_problem(TRUE)
	if (problem)
		to_chat(H, SPAN_WARNING(problem))
		return
	if (!collector || collector.loc != src)
		to_chat(H, SPAN_WARNING("Secure a beaker containing the game's reaction inputs first."))
		return
	var/obj/item/weapon/reagent_containers/glass/beaker = collector
	var/client/actor = H.client
	var/datum/admission = persistence_admission_identity
	var/list/options = list()
	for (var/path in reaction_paths)
		var/datum/chemical_reaction/R = new path()
		options[R.name] = R.id
	var/choice = player_input(H, "Run and investigate which game reaction?", "Investigate Reaction", null, "anything", options, TRUE)
	if (!choice || !(choice in options) || !science_reaction_actor_valid(H, actor, beaker, admission))
		return
	if (!do_after(H, SCIENCE_INVESTIGATION_TIME, src, FALSE))
		return
	if (!science_reaction_actor_valid(H, actor, beaker, admission))
		return
	var/reaction_id = options[choice]
	if (!synthesize(reaction_id))
		to_chat(H, SPAN_WARNING("No completed reaction to investigate. Check the inputs, catalyst, heat and available output space."))
		return
	H.science_investigation_credit("reaction:[reaction_id]", TRUE)

/obj/structure/reaction_bench/proc/science_reaction_actor_valid(mob/living/human/H, client/actor, obj/item/weapon/reagent_containers/glass/beaker, datum/admission)
	return !QDELETED(src) && !QDELETED(H) && actor && H.client == actor && actor.mob == H && H.Adjacent(src) && !QDELETED(beaker) && collector == beaker && beaker.loc == src && !persistence_admission_changed(admission) && !H.science_investigation_problem(TRUE)

#undef SCIENCE_COMPARE_MIN
#undef SCIENCE_LAB_MIN
#undef SCIENCE_INVESTIGATION_CAP
#undef SCIENCE_INVESTIGATION_TIME
#undef SCIENCE_INVESTIGATION_COOLDOWN
#undef SCIENCE_INVESTIGATION_HISTORY_MAX
