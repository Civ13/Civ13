// Living conditions: how a character sleeps, eats, washes and keeps warm moves
// the level their mood settles at (see mood_resting_level() in human_needs.dm).
// These are lasting conditions, read every MOOD_REST_CHECK; none of them pushes
// mood directly, so none can be farmed and each ends the moment it stops.

#define LIVING_BED 4          // last slept in a proper bed
#define LIVING_BEDROLL 2      // or on a bedroll
#define LIVING_SHEET 2        // with a sheet or blanket on it
#define LIVING_PADDING 2      // a proper bed padded with cloth or leather
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
#define LIVING_DRESSED 3      // clothes that suit the season and climate
#define LIVING_DRESSED_TIME 6000 // worn this long (10 minutes) before they count
#define LIVING_DRESSED_COLD 10   // degrees C: below this it takes warm layers
#define LIVING_DRESSED_HOT 27    // degrees C: from here it takes light clothes
#define LIVING_DRESSED_COAT 18   // degrees C: above this a coat is too much
#define LIVING_DRESSED_WARMTH 0.55 // share of body heat the layers must keep in
#define LIVING_HUNGER_SHARE 0.25 // of a full stomach or full water

// How well the character last slept: 0 to LIVING_BED + LIVING_PADDING + LIVING_SHEET. Saved
// with the body, so a good bed still counts after the world restarts.
/mob/living/human/var/sleep_comfort = 0

#define RESTED_LEARNING_MIN_SLEEP (10 MINUTES)
#define RESTED_RESEARCH_POINTS 10

// Save the wall-clock pair with the body so offline time and restarts count.
// Realtime is too coarse for the sleep threshold; use it only for day wraps.
/mob/living/human/var/rested_learning_sleep_timeofday
/mob/living/human/var/rested_learning_sleep_realtime
// One banked bonus, saved with the body. No countdown and no stacking.
/mob/living/human/var/rested_research_ready = FALSE

/mob/living/human/proc/rested_learning_bed_here()
	if (!isturf(loc))
		return FALSE
	for (var/obj/structure/bed/B in loc)
		if (!QDELETED(B) && !istype(B, /obj/structure/bed/chair) && !istype(B, /obj/structure/bed/bedroll))
			return TRUE
	return FALSE

/mob/living/human/proc/rested_learning_timeofday()
	return world.timeofday

/mob/living/human/proc/rested_learning_realtime()
	return world.realtime

/mob/living/human/proc/clear_rested_learning_sleep()
	rested_learning_sleep_timeofday = null
	rested_learning_sleep_realtime = null

/mob/living/human/proc/begin_rested_learning_sleep()
	if (isnull(rested_learning_sleep_timeofday) && !droid && map?.book_research_enabled() && rested_learning_bed_here())
		rested_learning_sleep_timeofday = rested_learning_timeofday()
		rested_learning_sleep_realtime = rested_learning_realtime()

/mob/living/human/proc/finish_rested_learning_sleep()
	if (isnull(rested_learning_sleep_timeofday))
		return FALSE
	var/now_timeofday = rested_learning_timeofday()
	var/now_realtime = rested_learning_realtime()
	var/duration = wall_clock_elapsed(rested_learning_sleep_timeofday, rested_learning_sleep_realtime, now_timeofday, now_realtime)
	clear_rested_learning_sleep()
	if (duration < RESTED_LEARNING_MIN_SLEEP || stat == DEAD || droid || !map?.book_research_enabled() || !rested_learning_bed_here())
		return FALSE
	if (!rested_research_ready)
		rested_research_ready = TRUE
		to_chat(src, SPAN_NOTICE("You wake up refreshed. Your next book research contribution can gain [RESTED_RESEARCH_POINTS] extra points."))
	return TRUE

// Called only after a positive contribution with room left on the chapter.
/mob/living/human/proc/use_rested_research_bonus(room)
	if (!rested_research_ready || room <= 0 || inducedSSD || sleeping || stat != CONSCIOUS || droid || !map?.book_research_enabled())
		return 0
	var/points = min(room, RESTED_RESEARCH_POINTS)
	rested_research_ready = FALSE
	to_chat(src, SPAN_NOTICE("Being well rested adds [points] extra research point[points == 1 ? "" : "s"]."))
	return points

#undef RESTED_LEARNING_MIN_SLEEP
#undef RESTED_RESEARCH_POINTS

// The comfort of the place a sleeper lies in. Chairs and seats count for nothing.
/mob/living/human/proc/sleeping_place_comfort()
	. = 0
	var/turf/T = get_turf(src)
	if (!T)
		return
	for (var/obj/structure/bed/B in T)
		if (istype(B, /obj/structure/bed/chair))
			continue
		if (istype(B, /obj/structure/bed/bedroll))
			. = max(., LIVING_BEDROLL)
		else
			. = max(., B.padding_material ? LIVING_BED + LIVING_PADDING : LIVING_BED)
	if (. && locate(/obj/item/weapon/bedsheet) in T)
		. += LIVING_SHEET

/mob/living/human/proc/sleep_comfort_name()
	if (sleep_comfort >= LIVING_BED + LIVING_PADDING + LIVING_SHEET)
		return "a padded bed with sheets to sleep in"
	if (sleep_comfort >= LIVING_BED + LIVING_SHEET)
		return "a fine bed to sleep in"
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
// Clothes that suit the air of this season and climate: warm layers in the
// cold, light clothes in the heat, and no coat once it is mild.
/mob/living/human/proc/mood_dressed_for_weather()
	if (!w_uniform)
		return FALSE
	var/air = get_temp(src)
	if (air < LIVING_DRESSED_COLD)
		return get_cold_protection(air + 273.15) >= LIVING_DRESSED_WARMTH
	if (air > LIVING_DRESSED_COAT && istype(wear_suit, /obj/item/clothing/suit/storage/coat))
		return FALSE
	if (air >= LIVING_DRESSED_HOT)
		return shoes ? TRUE : FALSE
	return TRUE

// When the character began dressing for the weather; 0 while they are not.
/mob/living/human/var/tmp/mood_dressed_since = 0

/mob/living/human/proc/mood_dressed_long_enough()
	if (!mood_dressed_for_weather())
		mood_dressed_since = 0
		return FALSE
	if (!mood_dressed_since)
		mood_dressed_since = world.time
	return world.time - mood_dressed_since >= LIVING_DRESSED_TIME

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
/proc/mood_is_art(obj/S)
	if (istype(S, /obj/structure/painting_frame) || istype(S, /obj/structure/rock_art) || istype(S, /obj/structure/woven_rug))
		return TRUE
	if (istype(S, /obj/item/weapon/reagent_containers/food/drinks/clay/designed)) // pottery_design.dm
		var/obj/item/weapon/reagent_containers/food/drinks/clay/designed/P = S
		return isturf(P.loc) && P.decorated()
	return istype(S, /obj/structure/religious) && !istype(S, /obj/structure/religious/gravestone)

// Works of art in sight, counted up to LIVING_ART_PIECES.
/mob/living/human/proc/mood_art_in_sight()
	. = 0
	for (var/obj/S in view(LIVING_ART_REACH, src))
		if (mood_is_art(S))
			.++
			if (. >= LIVING_ART_PIECES)
				return

// A small pleasure that lifts mood, at most once per gap for each cause.
/mob/living/human/var/tmp/list/mood_leisure_next // cause -> world.time it may lift again

/mob/living/human/persistence_runtime_var(key)
	return key == "mood_leisure_next" || key == "mood_dressed_since" || ..()

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
		home_comfort_sleep_tick()
		if (!isnull(rested_learning_sleep_timeofday) && !rested_learning_bed_here())
			clear_rested_learning_sleep()
		return
	clear_rested_learning_sleep()
	home_comfort_wake()
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
	if (mood_dressed_long_enough())
		parts["being dressed for the weather"] = LIVING_DRESSED
	// A home slept in counts all day, like the bed; otherwise a roof or a fire.
	var/home = home_tier_mood(home_comfort)
	if (home)
		parts["a [home_tier_name(home_comfort)] home"] = home
	else
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
#undef LIVING_PADDING
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
#undef LIVING_DRESSED
#undef LIVING_DRESSED_TIME
#undef LIVING_DRESSED_COLD
#undef LIVING_DRESSED_HOT
#undef LIVING_DRESSED_COAT
#undef LIVING_DRESSED_WARMTH
#undef LIVING_HUNGER_SHARE
