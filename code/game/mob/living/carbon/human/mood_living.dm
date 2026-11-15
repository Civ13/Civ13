// Living conditions: how a character sleeps, eats, washes and keeps warm moves
// the level their mood settles at (see mood_resting_level() in human_needs.dm).
// These are lasting conditions, read every MOOD_REST_CHECK; none of them pushes
// mood directly, so none can be farmed and each ends the moment it stops.

#define LIVING_BED 4          // last slept in a proper bed
#define LIVING_BEDROLL 2      // or on a bedroll
#define LIVING_SHEET 2        // with a sheet or blanket on it
#define LIVING_DIET 5         // three of the four food groups adequate
#define LIVING_DIET_GROUPS 3
#define LIVING_CLEAN 4
#define LIVING_WARM_DRY 3
#define LIVING_FILTHY 8
#define LIVING_FLEAS 5
#define LIVING_SICK 8
#define LIVING_SERIOUSLY_ILL 12
#define LIVING_PAIN 5
#define LIVING_PAIN_SHOCK 50  // traumatic shock that counts as lasting pain
#define LIVING_HUNGER 8
#define LIVING_SHELTER 3      // a roof overhead, or a fire to sit by at night
#define LIVING_ANIMAL 3       // a tame animal close by
#define LIVING_ANIMAL_REACH 3
#define LIVING_ART 2          // each work of art in sight, up to LIVING_ART_PIECES
#define LIVING_ART_PIECES 3
#define LIVING_ART_REACH 4
#define LIVING_HUNGER_SHARE 0.25 // of a full stomach or full water

// How well the character last slept: 0 to LIVING_BED + LIVING_SHEET. Saved
// with the body, so a good bed still counts after the world restarts.
/mob/living/human/var/sleep_comfort = 0

// The comfort of the place a sleeper lies in. Chairs and seats count for nothing.
/mob/living/human/proc/sleeping_place_comfort()
	. = 0
	var/turf/T = get_turf(src)
	if (!T)
		return
	for (var/obj/structure/bed/B in T)
		if (istype(B, /obj/structure/bed/chair))
			continue
		. = max(., istype(B, /obj/structure/bed/bedroll) ? LIVING_BEDROLL : LIVING_BED)
	if (. && locate(/obj/item/weapon/bedsheet) in T)
		. += LIVING_SHEET

/mob/living/human/proc/sleep_comfort_name()
	if (sleep_comfort >= LIVING_BED + LIVING_SHEET)
		return "a fine bed with sheets to sleep in"
	if (sleep_comfort >= LIVING_BED)
		return "a comfortable place to sleep"
	return "a simple place to sleep"

// Whether this map tracks washing and dirt (the maps handle_hygiene() runs on).
/mob/living/human/proc/mood_hygiene_mode()
	return map && (map.civilizations || map.ID == MAP_COLONY || map.ID == MAP_JUNGLE_COLONY || map.ID == MAP_GULAG13 || map.ID == MAP_BAGNE13)

// The body temperature icon reads normal and the clothes are dry.
/mob/living/human/proc/mood_warm_and_dry()
	if (cold_wetness > 0 || !species)
		return FALSE
	var/base = species.body_temperature
	if (isnull(base))
		base = (species.heat_level_1 + species.cold_level_1) / 2
	return bodytemperature > base - (base - species.cold_level_1) / 4 && bodytemperature < base + (species.heat_level_1 - base) / 4

// A roof keeps the weather off; at night a lit fire does nearly as well.
/mob/living/human/proc/mood_shelter_name()
	var/turf/T = get_turf(src)
	if (!T)
		return null
	var/area/A = get_area(T)
	if (A && A.location == AREA_INSIDE)
		return "a roof over your head"
	if ((time_of_day == "Night" || time_of_day == "Dark Night") && near_drying_fire(T))
		return "a fire to sit by at night"
	return null

// A living tame animal within reach: a tamed dog or wolf, a horse or livestock
// that is used to people. Wild and hostile animals are no comfort.
/mob/living/human/proc/mood_tame_animal_near()
	for (var/mob/living/simple_animal/S in range(LIVING_ANIMAL_REACH, src))
		if (S.stat == DEAD)
			continue
		if (istype(S, /mob/living/simple_animal/complex_animal))
			var/mob/living/simple_animal/complex_animal/C = S
			if (C.tamed)
				return TRUE
		else if (S.domesticable && !S.wild)
			return TRUE
	return FALSE

// Whether a thing is a work of art worth looking at.
/proc/mood_is_art(obj/structure/S)
	if (istype(S, /obj/structure/painting_frame) || istype(S, /obj/structure/rock_art))
		return TRUE
	return istype(S, /obj/structure/religious) && !istype(S, /obj/structure/religious/gravestone)

// Works of art in sight, counted up to LIVING_ART_PIECES.
/mob/living/human/proc/mood_art_in_sight()
	. = 0
	for (var/obj/structure/S in view(LIVING_ART_REACH, src))
		if (mood_is_art(S))
			.++
			if (. >= LIVING_ART_PIECES)
				return

// A small pleasure that lifts mood, at most once per gap for each cause.
/mob/living/human/var/tmp/list/mood_leisure_next // cause -> world.time it may lift again

/mob/living/human/persistence_runtime_var(key)
	return key == "mood_leisure_next" || ..()

/mob/living/human/proc/mood_leisure(cause, amount, gap)
	if (stat != CONSCIOUS)
		return FALSE
	if (!islist(mood_leisure_next))
		mood_leisure_next = list()
	if (isnum(mood_leisure_next[cause]) && world.time < mood_leisure_next[cause])
		return FALSE
	mood_leisure_next[cause] = world.time + gap
	adjust_mood(amount, cause)
	return TRUE

// A sleeper keeps the conditions they fell asleep with; the bed is noted for
// when they wake.
/mob/living/human/refresh_mood_rest()
	if (inducedSSD && sleeping)
		sleep_comfort = sleeping_place_comfort()
		return
	..()

/mob/living/human/collect_mood_rest_parts(list/parts)
	..()
	if (inducedSSD || droid)
		return
	if (mood_hygiene_mode())
		// A bit dirty is neither: skipping a wash costs the lift, not a penalty.
		if (hygiene >= HYGIENE_LEVEL_NORMAL)
			parts["being clean"] = LIVING_CLEAN
		else if (hygiene < HYGIENE_LEVEL_DIRTY)
			parts["being filthy"] = -LIVING_FILTHY
		if (has_fleas)
			parts["fleas"] = -LIVING_FLEAS
	if (disease && disease_type != "none")
		if (is_severe_disease() && disease_progression >= 180)
			parts["being seriously ill"] = -LIVING_SERIOUSLY_ILL
		else
			parts["being sick"] = -LIVING_SICK
	if (traumatic_shock >= LIVING_PAIN_SHOCK)
		parts["being in pain"] = -LIVING_PAIN
	if (!mood_needs_mode())
		return
	if (sleep_comfort > 0)
		parts[sleep_comfort_name()] = sleep_comfort
	if (diet_adequate_groups() >= LIVING_DIET_GROUPS)
		parts["a varied diet"] = LIVING_DIET
	if (mood_warm_and_dry())
		parts["being warm and dry"] = LIVING_WARM_DRY
	var/shelter = mood_shelter_name()
	if (shelter)
		parts[shelter] = LIVING_SHELTER
	if (mood_tame_animal_near())
		parts["animal company"] = LIVING_ANIMAL
	var/art = mood_art_in_sight()
	if (art)
		parts["art around you"] = art * LIVING_ART
	if (nutrition <= max_nutrition * LIVING_HUNGER_SHARE)
		parts["going hungry"] = -LIVING_HUNGER
	if (water <= max_water * LIVING_HUNGER_SHARE)
		parts["going thirsty"] = -LIVING_HUNGER

#undef LIVING_BED
#undef LIVING_BEDROLL
#undef LIVING_SHEET
#undef LIVING_DIET
#undef LIVING_DIET_GROUPS
#undef LIVING_CLEAN
#undef LIVING_WARM_DRY
#undef LIVING_FILTHY
#undef LIVING_FLEAS
#undef LIVING_SICK
#undef LIVING_SERIOUSLY_ILL
#undef LIVING_PAIN
#undef LIVING_PAIN_SHOCK
#undef LIVING_HUNGER
#undef LIVING_SHELTER
#undef LIVING_ANIMAL
#undef LIVING_ANIMAL_REACH
#undef LIVING_ART
#undef LIVING_ART_PIECES
#undef LIVING_ART_REACH
#undef LIVING_HUNGER_SHARE
