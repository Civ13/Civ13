// ============================================================
// Swimming in deep water (docs/river-flow.md, "Swimming")
// ------------------------------------------------------------
// A person may wade out of their depth and swim. Swimming tires: a swimmer
// stays afloat for about fifty seconds in calm water, less in a storm, and then
// goes under. Under the water they hold their breath for a few seconds more
// and can still reach the shallows, a boat or something that floats; after
// that they drown as anyone in deep water used to at once. Rest on land, in
// the shallows or on a deck brings the strength and the breath back. A lifejacket
// or a sealed diving suit floats its wearer and costs nothing.
//
// Swimming is a body skill (100 to 250). A better swimmer tires more slowly,
// moves faster through deep water, recovers sooner and holds their breath
// longer. It is learned by swimming: every stretch of new water crossed
// under your own power teaches a little, while someone is playing the
// character, and the first swim in each kind of water teaches more. Floating
// on the spot or paddling back and forth over the same few tiles teaches
// nothing. Mastering it pays Natural Science (learning_by_doing.dm).
//
// Only on the open-world maps (map.nomads): battle maps use deep water as
// their edge and keep it closed. People with nobody behind them keep out of
// deep water as before, so nobody walks into the sea on their own.
// ============================================================

#define SWIM_LIMIT 100 // tiredness at which a swimmer goes under
#define SWIM_EFFORT 2 // a life tick (one second) of calm water: 50 seconds afloat
#define SWIM_REST 4 // a life tick out of deep water: 25 seconds to recover
#define SWIM_SKILL_MIN 100
#define SWIM_SKILL_MAX 250
// Deep water costs 20 ds a step; skill divides it, never below this.
#define SWIM_STEP_FLOOR 8
// Training: one lesson per this many tiles not among the last few crossed.
#define SWIM_TRAIN_TILES 10
#define SWIM_RECENT_TILES 24
#define SWIM_TRAIN_GAIN 0.6 // a lesson (adaptStat): about an hour from 100 to 250
#define SWIM_ROUGH_TRAIN 1.5 // rain, snow or a storm sea teach more
#define SWIM_FIRST_GAIN 3 // the first swim in each kind of water...
#define SWIM_FIRST_EVERY (30 MINUTES) // ...at most this often
// Inactive players (client.inactivity, ds) learn nothing.
#define SWIM_TRAIN_IDLE 1200
// Breath: seconds held at skill 100, and the surface refill a second.
#define SWIM_BREATH_BASE 10
#define SWIM_BREATH_REFILL 3
// Extra effort a second for each point of a heavy suit's slowdown.
#define SWIM_SUIT_EFFORT 0.5

/mob/living/human
	var/tmp/swim_tiredness = 0
	var/tmp/swim_breath = -1 // seconds of held breath left; below 0 means full
	var/tmp/swim_under = FALSE // spent and holding their breath under the water
	var/tmp/list/swim_recent = null // the last few tiles crossed swimming
	var/tmp/swim_new_tiles = 0
	var/tmp/list/swim_kind_lessons = null // kind of water => world.time of its last first-swim lesson

// Breath, the spent state and the training record start fresh after a load:
// swim_recent holds turfs, and none of it is worth keeping.
/mob/living/human/persistence_runtime_var(key)
	return (key in list("swim_breath", "swim_under", "swim_recent", "swim_new_tiles")) || ..()

// TRUE when this person may leave the shallows under their own power.
/mob/living/human/proc/can_swim_deep()
	if (!map || !map.nomads)
		return FALSE
	return client || agent_characters[src] ? TRUE : FALSE

// The swimming skill without mood, 100 to 250: thresholds never flicker.
/mob/living/human/proc/swimming_skill()
	ensure_late_stats()
	var/list/pair = islist(stats) ? stats["swimming"] : null
	var/value = (islist(pair) && isnum(pair[1])) ? pair[1] : SWIM_SKILL_MIN
	return clamp(value, SWIM_SKILL_MIN, SWIM_SKILL_MAX)

// Seconds of breath this swimmer can hold: 10 at 100 up to 60 at 250.
/mob/living/human/proc/swim_breath_max()
	return SWIM_BREATH_BASE + (swimming_skill() - SWIM_SKILL_MIN) / 3

// How hard the water here is to swim in, in tiredness a life tick, before skill.
/proc/swim_effort_at(turf/T)
	. = SWIM_EFFORT
	var/wind = weather_wind_at(T)
	if (wind >= 3)
		. += 2 // a storm sea: half the time afloat
	else if (weather_at(T) != WEATHER_NONE)
		. += 1

// This swimmer's effort here: skill divides it, a heavy suit adds to it.
/mob/living/human/proc/swim_effort_for(turf/T)
	. = swim_effort_at(T) * SWIM_SKILL_MIN / swimming_skill()
	if (istype(wear_suit, /obj/item/clothing) && wear_suit.slowdown > 0)
		. += wear_suit.slowdown * SWIM_SUIT_EFFORT

// TRUE where the swimming skill sets the step cost: open deep water.
/mob/living/human/proc/swim_skill_applies(turf/T)
	return istype(T, /turf/floor/beach/water/deep) && !sea_layer_cell(T) && !T.iscovered()

// The step cost of water F for this person, footwear included.
/mob/living/human/proc/water_step_delay(turf/floor/F)
	. = F.move_delay * footwear_terrain_mult(src, "wade")
	if (swim_skill_applies(F))
		// Never slower than an unskilled swimmer, never faster than the floor.
		. = min(., max(SWIM_STEP_FLOOR, . * SWIM_SKILL_MIN / swimming_skill()))

// The kind of water a swim is in, for the first-swim lesson.
/proc/swim_water_kind(turf/T)
	if (weather_wind_at(T) >= 3)
		return "storm"
	if (!istype(T, /turf/floor/beach/water))
		return "flood"
	var/turf/floor/beach/water/W = T
	return W.salty ? "sea" : "river"

// TRUE while someone is actually playing this character.
/mob/living/human/proc/swim_training_active()
	if (agent_characters[src])
		return TRUE
	return client && client.inactivity < SWIM_TRAIN_IDLE

// Lessons from a life tick afloat at T: new water crossed, and the first
// swim in a while in each kind of water.
/mob/living/human/proc/swim_train(turf/T)
	if (!T || !swim_training_active())
		return
	var/kind = swim_water_kind(T)
	if (!islist(swim_kind_lessons))
		swim_kind_lessons = list()
	var/last = swim_kind_lessons[kind]
	if (!isnum(last) || world.time - last >= SWIM_FIRST_EVERY)
		swim_kind_lessons[kind] = world.time
		adaptStat("swimming", SWIM_FIRST_GAIN, "water:[kind]")
	if (!islist(swim_recent))
		swim_recent = list()
	if (T in swim_recent)
		return
	swim_recent += T
	if (swim_recent.len > SWIM_RECENT_TILES)
		swim_recent.Cut(1, 2)
	if (++swim_new_tiles < SWIM_TRAIN_TILES)
		return
	swim_new_tiles = 0
	adaptStat("swimming", swim_effort_at(T) > SWIM_EFFORT ? SWIM_TRAIN_GAIN * SWIM_ROUGH_TRAIN : SWIM_TRAIN_GAIN)

// One life tick in open deep water without anything to float on. Returns
// TRUE while the swimmer is still afloat.
/mob/living/human/proc/swim_step(turf/T)
	if (stat || !can_swim_deep())
		return FALSE
	if (swim_under)
		return FALSE // spent: under until out of deep water
	var/before = swim_tiredness
	swim_tiredness = min(SWIM_LIMIT, swim_tiredness + swim_effort_for(T))
	if (before < 50 && swim_tiredness >= 50)
		to_chat(src, SPAN_WARNING("Your arms and legs are tiring. You cannot swim much longer."))
	else if (before < 80 && swim_tiredness >= 80)
		to_chat(src, SPAN_DANGER("You are nearly spent. Reach the shallows or something that floats, now!"))
	if (swim_tiredness >= SWIM_LIMIT)
		return FALSE
	swim_refill_breath()
	swim_train(T)
	return TRUE

// A life tick spent and under the water. Returns TRUE while the held breath
// lasts, and FALSE once the swimmer is drowning.
/mob/living/human/proc/swim_hold_breath()
	if (stat || !can_swim_deep())
		return FALSE
	if (swim_breath < 0)
		swim_breath = swim_breath_max()
	if (!swim_under)
		swim_under = TRUE
		to_chat(src, SPAN_DANGER("You are spent and slip under the water. Hold your breath and reach the shallows or something that floats!"))
	swim_breath = max(0, swim_breath - 1)
	return swim_breath > 0

/mob/living/human/proc/swim_refill_breath()
	if (swim_breath < 0)
		return
	swim_breath += SWIM_BREATH_REFILL
	if (swim_breath >= swim_breath_max())
		swim_breath = -1

// A life tick anywhere else: breath and strength come back.
/mob/living/human/proc/swim_rest()
	swim_under = FALSE
	swim_refill_breath()
	if (swim_tiredness)
		swim_tiredness = max(0, swim_tiredness - SWIM_REST * swimming_skill() / SWIM_SKILL_MIN)

#undef SWIM_LIMIT
#undef SWIM_EFFORT
#undef SWIM_REST
#undef SWIM_SKILL_MIN
#undef SWIM_SKILL_MAX
#undef SWIM_STEP_FLOOR
#undef SWIM_TRAIN_TILES
#undef SWIM_RECENT_TILES
#undef SWIM_TRAIN_GAIN
#undef SWIM_ROUGH_TRAIN
#undef SWIM_FIRST_GAIN
#undef SWIM_FIRST_EVERY
#undef SWIM_TRAIN_IDLE
#undef SWIM_BREATH_BASE
#undef SWIM_BREATH_REFILL
#undef SWIM_SUIT_EFFORT
