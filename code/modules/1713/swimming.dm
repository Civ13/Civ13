// ============================================================
// Swimming in deep water (docs/river-flow.md, "Swimming")
// ------------------------------------------------------------
// A person may wade out of their depth and swim. Swimming tires: a swimmer
// stays afloat for about fifty seconds in calm water, less in a storm, and then
// goes under and drowns as anyone in deep water used to at once. Rest on
// land, in the shallows or on a deck brings the strength back. A lifejacket
// or a sealed diving suit floats its wearer and costs nothing.
//
// Only on the open-world maps (map.nomads): battle maps use deep water as
// their edge and keep it closed. People with nobody behind them keep out of
// deep water as before, so nobody walks into the sea on their own.
// ============================================================

#define SWIM_LIMIT 100 // tiredness at which a swimmer goes under
#define SWIM_EFFORT 2 // a life tick (one second) of calm water: 50 seconds afloat
#define SWIM_REST 4 // a life tick out of deep water: 25 seconds to recover

/mob/living/human
	var/tmp/swim_tiredness = 0

// TRUE when this person may leave the shallows under their own power.
/mob/living/human/proc/can_swim_deep()
	if (!map || !map.nomads)
		return FALSE
	return client || agent_characters[src] ? TRUE : FALSE

// How hard the water here is to swim in, in tiredness a life tick.
/proc/swim_effort_at(turf/T)
	. = SWIM_EFFORT
	var/wind = weather_wind_at(T)
	if (wind >= 3)
		. += 2 // a storm sea: half the time afloat
	else if (weather_at(T) != WEATHER_NONE)
		. += 1

// One life tick in open deep water without anything to float on. Returns
// TRUE while the swimmer is still afloat.
/mob/living/human/proc/swim_step(turf/T)
	if (stat || !can_swim_deep())
		return FALSE
	var/before = swim_tiredness
	swim_tiredness = min(SWIM_LIMIT, swim_tiredness + swim_effort_at(T))
	if (before < 50 && swim_tiredness >= 50)
		to_chat(src, SPAN_WARNING("Your arms and legs are tiring. You cannot swim much longer."))
	else if (before < 80 && swim_tiredness >= 80)
		to_chat(src, SPAN_DANGER("You are nearly spent. Reach the shallows or something that floats, now!"))
	return swim_tiredness < SWIM_LIMIT

// A life tick anywhere else: breath and strength come back.
/mob/living/human/proc/swim_rest()
	if (swim_tiredness)
		swim_tiredness = max(0, swim_tiredness - SWIM_REST)

#undef SWIM_LIMIT
#undef SWIM_EFFORT
#undef SWIM_REST
