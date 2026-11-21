// How the air feels (docs/feels-like.md): wind chill and heat index.
//
// Out of doors a person feels more than the air's temperature:
// - wind chill: at 10 C or below, the wind carries heat away (the Canadian
//   and US formula, from the local wind in weather_wind.dm, storm gusts
//   included). A windproof outer layer keeps most of it off;
// - heat index: at 27 C or above in air 40% humid or more, sweat stops
//   cooling (Rothfusz's regression, from the air grid's humidity);
// - the sun: from 20 C up, a clear Midday or Afternoon sky adds
//   FEELS_LIKE_SUN_C. A brimmed hat or a light, loose robe shades it, and a
//   loose robe lets some of the humid heat out.
// The body's warmth (human_life.dm handle_environment) follows the feels-like
// temperature; the thermometer still reads the air.

#define FEELS_LIKE_SUN_C 3
#define FEELS_LIKE_WIND_CAP 90 // percent of wind chill any clothing keeps off
#define FEELS_LIKE_MESSAGE_GAP 3000 // 5 minutes between warnings

/obj/item/clothing
	var/wind_resist = 0 // percent of wind chill kept off when worn as an outer layer
	var/sun_shade = 0 // percent of the sun's heat kept off (brimmed hats, light robes)

/mob/living/human/var/tmp/next_feels_like_message = 0

// Outer layers: how much of the wind they stop.
/obj/item/clothing/suit
	wind_resist = 20
/obj/item/clothing/suit/storage/coat
	wind_resist = 50
/obj/item/clothing/suit/storage/coat/fur
	wind_resist = 70
/obj/item/clothing/suit/storage/coat/leathercoat_black
	wind_resist = 70
/obj/item/clothing/suit/prehistoricfurcoat
	wind_resist = 60
/obj/item/clothing/suit/oilskin_coat
	wind_resist = 80
/obj/item/clothing/suit/cape
	wind_resist = 40
/obj/item/clothing/suit/storage/jacket/custom/poncho
	wind_resist = 50
/obj/item/clothing/suit/storage/coat/ww2/japcoat_rain
	wind_resist = 70
/obj/item/clothing/suit/nbcponcho
	wind_resist = 90
/obj/item/clothing/accessory/custom/cape
	wind_resist = 30

// Brimmed and draped hats against the sun.
/obj/item/clothing/head/strawhat
	sun_shade = 60
/obj/item/clothing/head/rice_hat
	sun_shade = 70
/obj/item/clothing/head/sombrero
	sun_shade = 80
/obj/item/clothing/head/cowboyhat
	sun_shade = 50
/obj/item/clothing/head/helmet/modern/pith
	sun_shade = 70
/obj/item/clothing/head/keffiyeh
	sun_shade = 50
/obj/item/clothing/head/custom_keffiyeh
	sun_shade = 50
/obj/item/clothing/head/turban
	sun_shade = 40

// Light, loose robes.
/obj/item/clothing/suit/storage/jacket/arabic_robe
	sun_shade = 50
/obj/item/clothing/suit/arabic_robe
	sun_shade = 50
/obj/item/clothing/suit/storage/arabic_robe
	sun_shade = 50
/obj/item/clothing/under/medieval/arabic_tunic
	sun_shade = 30
/obj/item/clothing/under/custom/arabictunic
	sun_shade = 30
/obj/item/clothing/under/toga
	sun_shade = 30
/obj/item/clothing/under/custom/toga
	sun_shade = 30
/obj/item/clothing/under/kimono
	sun_shade = 20
/obj/item/clothing/under/customtribalrobe
	sun_shade = 30
/obj/item/clothing/suit/storage/coat/monk_robes
	sun_shade = 30

// ---- the formulas ---------------------------------------------

// Degrees C the wind takes off air at temp_c with wind_ms m/s: 0 above 10 C
// or below 1.3 m/s (4.8 km/h).
/proc/feels_like_wind_chill(temp_c, wind_ms)
	if (temp_c > 10 || wind_ms < 1.3)
		return 0
	var/v = (wind_ms * 3.6) ** 0.16
	var/chill = 13.12 + 0.6215 * temp_c - 11.37 * v + 0.3965 * temp_c * v
	return max(0, temp_c - chill)

// Degrees C humid heat adds to air at temp_c and rh %: 0 below 27 C or 40%.
/proc/feels_like_heat_index(temp_c, rh)
	if (temp_c < 27 || rh < 40)
		return 0
	var/t = temp_c * 9 / 5 + 32
	var/hi = -42.379 + 2.04901523 * t + 10.14333127 * rh - 0.22475541 * t * rh - 0.00683783 * t * t - 0.05481717 * rh * rh + 0.00122874 * t * t * rh + 0.00085282 * t * rh * rh - 0.00000199 * t * t * rh * rh
	return max(0, (hi - 32) * 5 / 9 - temp_c)

// TRUE where the sun beats down on T now.
/proc/feels_like_sunny(turf/T)
	if (time_of_day != "Midday" && time_of_day != "Afternoon")
		return FALSE
	if (weather_storm_count && weather_storm_strength(T.x, T.y) >= WEATHER_BAND_LIGHT)
		return FALSE
	var/cloud = weather_cloud_at(T)
	return isnull(cloud) || cloud < 0.4

// list(wind chill, heat index, sun) in degrees C on open ground at T for air
// at temp_c, before clothing. All 0 under a roof.
/proc/feels_like_parts(turf/T, temp_c)
	. = list(0, 0, 0)
	var/area/A = T ? T.loc : null
	if (!istype(A) || A.location != AREA_OUTSIDE || (locate(/obj/roof) in T))
		return
	if (temp_c <= 10)
		.[1] = feels_like_wind_chill(temp_c, weather_wind_ms_at(T))
	else if (temp_c >= 20)
		if (temp_c >= 27 && weather_air)
			var/rh = weather_humidity_at(T)
			if (isnum(rh))
				.[2] = feels_like_heat_index(temp_c, rh)
		if (feels_like_sunny(T))
			.[3] = FEELS_LIKE_SUN_C

// What the air at A feels like to someone with nothing on, in C.
/proc/weather_feels_like_at(atom/A)
	var/turf/T = get_turf(A)
	if (!T)
		return null
	var/temp = get_temp(T)
	var/list/parts = feels_like_parts(T, temp)
	return temp - parts[1] + parts[2] + parts[3]

// ---- worn gear ------------------------------------------------

// Percent of the wind chill H's outer layers keep off.
/mob/living/human/proc/feels_like_wind_resist()
	var/through = 1
	for (var/obj/item/clothing/C in list(wear_suit, w_uniform))
		if (C.wind_resist)
			through *= 1 - C.wind_resist / 100
		for (var/obj/item/clothing/accessory/AC in C.accessories)
			if (AC.wind_resist)
				through *= 1 - AC.wind_resist / 100
	return min(FEELS_LIKE_WIND_CAP, round(100 * (1 - through)))

// list(shade from the hat, shade from the robe), each a percent.
/mob/living/human/proc/feels_like_shade()
	var/hat = 0
	var/robe = 0
	var/obj/item/clothing/H = head
	if (istype(H))
		hat = H.sun_shade
	for (var/obj/item/clothing/C in list(wear_suit, w_uniform))
		robe = max(robe, C.sun_shade)
	return list(hat, robe)

// The temperature H feels at loc_temp C where they stand, wearing what they wear.
/mob/living/human/proc/feels_like_temperature(loc_temp)
	var/turf/T = get_turf(src)
	if (!T)
		return loc_temp
	var/list/parts = feels_like_parts(T, loc_temp)
	if (!parts[1] && !parts[2] && !parts[3])
		return loc_temp
	var/chill = parts[1] * (1 - feels_like_wind_resist() / 100)
	var/list/shade = feels_like_shade()
	var/sun = parts[3] * (1 - min(100, shade[1] + shade[2]) / 100)
	var/humid = parts[2] * (1 - shade[2] / 200)
	feels_like_warn(parts, chill, humid + sun)
	return loc_temp - chill + humid + sun

// Now and then, tell H what the air is doing to them and what would help.
/mob/living/human/proc/feels_like_warn(list/parts, chill, heat)
	if (world.time < next_feels_like_message || stat)
		return
	if (chill >= 5)
		next_feels_like_message = world.time + FEELS_LIKE_MESSAGE_GAP
		to_chat(src, SPAN_WARNING("The wind cuts through you[feels_like_wind_resist() < 50 ? ". A windproof coat or cloak would keep it off" : ""]."))
	else if (heat >= 4)
		next_feels_like_message = world.time + FEELS_LIKE_MESSAGE_GAP
		if (parts[2] > parts[3])
			to_chat(src, SPAN_WARNING("The air is heavy and humid, and your sweat does not cool you."))
		else
			to_chat(src, SPAN_WARNING("The sun beats down on you. A brimmed hat or a light robe would shade you."))

#undef FEELS_LIKE_SUN_C
#undef FEELS_LIKE_WIND_CAP
#undef FEELS_LIKE_MESSAGE_GAP
