// Climate normals: the outdoor air temperature a climate has at this point in
// the year and the day, before weather, shelter and fires (docs/climate-normals.md).
//
// Each climate has a cold-season mean, a warm-season mean and a daily swing,
// in degrees C. The year runs as a smooth curve through the season's progress
// (coldest in mid-winter, warmest in mid-summer) instead of a jump at each
// season change, and the day adds a wave on top: coldest at Early Morning,
// warmest in the Afternoon. Cloud takes most of the swing away.

// climate = list(cold-season mean, warm-season mean, daily swing)
var/global/list/climate_normals = list(
	"temperate" = list(-2, 20, 10),
	"sea" = list(5, 17, 5),
	"taiga" = list(-18, 15, 12),
	"tundra" = list(-28, 8, 8),
	"semiarid" = list(5, 26, 15),
	"desert" = list(13, 34, 18),
	"savanna" = list(22, 28, 12),
	"jungle" = list(26, 28, 8))

// Share of half the daily swing added in each part of the day.
var/global/list/climate_daily_wave = list(
	"Early Morning" = -1,
	"Morning" = -0.3,
	"Midday" = 0.6,
	"Afternoon" = 1,
	"Evening" = 0.2,
	"Night" = -0.6,
	"Dark Night" = -0.8)

// An unknown climate keeps the old flat 20 C with a modest day.
#define CLIMATE_UNKNOWN_MEAN 20
#define CLIMATE_UNKNOWN_SWING 10

// How far through the current season the world is, 0 to 1; mid-season when
// seasons are off or no change is scheduled.
/proc/climate_season_fraction()
	if (!map)
		return 0.5
	var/list/window = map.season_change_window()
	if (!window)
		return 0.5
	return clamp((world.time - window[1]) / (window[2] - window[1]), 0, 1)

// Where the year stands, in seasons from the start of spring (0 to 4), or
// from the start of the wet season (0 to 2) on the wet and dry cycle.
/proc/climate_year_position(season_name, fraction)
	switch (season_name)
		if (SEASON_SPRING)
			return fraction
		if (SEASON_SUMMER)
			return 1 + fraction
		if (SEASON_FALL)
			return 2 + fraction
		if (SEASON_WINTER)
			return 3 + fraction
		if (SEASON_WET)
			return fraction
		if (SEASON_DRY)
			return 1 + fraction
	return null

// The mean air temperature of a climate at a point in the year.
// Four seasons: warmest at mid-summer (1.5), coldest at mid-winter (3.5).
// Wet and dry: the wet season is the cooler half and the dry season the
// warmer, half the four-season range either side of the annual mean.
/proc/climate_mean_at(climate, season_name, fraction = 0.5)
	var/list/normal = climate_normals[climate]
	if (!normal)
		return CLIMATE_UNKNOWN_MEAN
	var/cold = normal[1]
	var/warm = normal[2]
	var/middle = (cold + warm) / 2
	var/half_range = (warm - cold) / 2
	var/at = climate_year_position(season_name, fraction)
	if (isnull(at))
		return middle
	if (season_name == SEASON_WET || season_name == SEASON_DRY)
		// Wet mid-season (0.5) coolest, dry mid-season (1.5) warmest.
		return middle - (half_range / 2) * cos(180 * (at - 0.5))
	return middle + half_range * cos(90 * (at - 1.5))

// The mean of a whole season, as the almanac prints it: its middle.
/proc/climate_season_mean(climate, season_name)
	return round(climate_mean_at(climate, season_name, 0.5))

/proc/climate_daily_swing(climate)
	var/list/normal = climate_normals[climate]
	return normal ? normal[3] : CLIMATE_UNKNOWN_SWING

// Degrees C the time of day adds to the mean. Cloud and rain keep the day's
// heat in and the sun out, so a storm overhead leaves a third of the swing.
/proc/climate_daily_offset(climate, part_of_day, clouded = FALSE)
	var/wave = climate_daily_wave[part_of_day]
	if (!isnum(wave))
		return 0
	var/swing = climate_daily_swing(climate)
	if (clouded)
		swing /= 3
	return wave * swing / 2

// Degrees C the weather overhead adds: rain cools the air a little more the
// harder it falls, a blizzard brings air colder than the season, and a heat
// system holds hot air over the land. Additive, so rain on freezing ground
// cools it too instead of warming it.
/proc/climate_weather_offset(atom/A)
	. = 0
	switch (weather_at(A))
		if (WEATHER_WET)
			. -= weather_intensity_at(A)
		if (WEATHER_EXTREME)
			var/look = weather_look_at(A)
			if (look == "snow_storm")
				. -= 10
			else if (look == "monsoon")
				. -= 3
	if (weather_heat_at(A))
		. += 6

// The outdoor air at A from its climate, the season and the time of day.
/proc/climate_air_temperature(atom/A, area/where)
	var/climate = where ? where.climate : null
	var/clouded = weather_intensity_at(A) > 0
	return climate_mean_at(climate, season, climate_season_fraction()) + climate_daily_offset(climate, time_of_day, clouded)

#undef CLIMATE_UNKNOWN_MEAN
#undef CLIMATE_UNKNOWN_SWING
