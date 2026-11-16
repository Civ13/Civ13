// Water quality by kind (docs/water-quality.md).
//
// A water tile's `sickness` is what it holds by its kind (fresh 1, jungle
// river and flooded riverbed 2, swamp 3). What the water is doing changes it:
// a river with a current carries its dirt away and holds half as many germs,
// and still fresh water in summer heat goes stagnant. Everything that draws,
// drinks or bathes in open water asks water_germ_level(), never `sickness`.

// Air temperature (C) at which still fresh water stagnates.
#define WATER_STAGNANT_HEAT 27
// Germ level of still fresh water in that heat.
#define WATER_STAGNANT_GERMS 1.5

/turf/floor/beach/water/proc/water_germ_level()
	. = water_kind_germs()
	// What a river carries down from upstream (river_foul.dm).
	if (!salty)
		. += river_foul_germs(src)

/turf/floor/beach/water/proc/water_kind_germs()
	if (sickness <= 0)
		return 0
	// Swamps and floodwater stay as foul as they are, moving or not.
	if (istype(src, /turf/floor/beach/water/swamp) || istype(src, /turf/floor/beach/water/flooded))
		return sickness
	if (river_current_direction(src))
		return sickness * 0.5
	if (!salty && sickness == 1 && get_temp(src) >= WATER_STAGNANT_HEAT)
		return WATER_STAGNANT_GERMS
	return sickness

// What a person sees when they look closely at the water.
/turf/floor/beach/water/proc/water_quality_reading()
	if (salty || istype(src, /turf/floor/beach/water/ice))
		return null
	if (istype(src, /turf/floor/beach/water/swamp))
		return "The water is stagnant and smells of rot."
	if (istype(src, /turf/floor/beach/water/flooded))
		return "The water is thick with mud."
	if (river_current_direction(src))
		return sickness > 1 ? "The water is brown with silt, but it keeps moving." : "The water runs clear and quick."
	if (water_kind_germs() > sickness)
		return "The water lies still and warm, green at the edges."
	return "The water lies still."

/turf/floor/beach/water/examine(mob/user)
	..()
	if (ishuman(user) && get_dist(user, src) <= 2)
		var/reading = water_quality_reading()
		if (reading)
			to_chat(user, reading)
		if (!salty && river_fouled_at(src))
			to_chat(user, SPAN_WARNING("There is scum on the water. Something upstream is fouling it."))

#undef WATER_STAGNANT_HEAT
#undef WATER_STAGNANT_GERMS
