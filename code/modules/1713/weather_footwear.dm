// Footwear that matters for weather and terrain.
// Every pair of shoes carries terrain ratings that the movement code reads:
//   snow_mult  - scales the snow slowdown (snowshoes float on top of it)
//   mud_mult   - scales the mud slowdown (pattens and rubber boots stay above it)
//   wade_mult  - scales the slowdown of flooded ground and shallow water
//   ice_grip   - 0 to 1, how much of the chance to slip on ice is removed
//                (shoes flagged NOSLIP grip at least half as well)
//   slope_grip - scales the chance to trip running down a steep hill
//   offsnow_slowdown - extra delay on bare ground (snowshoes are clumsy there)
//   open_toed  - in snow the feet freeze as if bare
//   waterproof_feet - wading in cold water does not chill the feet
// Sprites for the new pairs: icons/obj/weather_footwear.dmi and
// icons/mob/weather_footwear.dmi, drawn by tests/sprites/create_weather_footwear.py.

#define FOOTWEAR_ICE_SLIP_CHANCE 3 // percent per running step on ice, barefoot or in plain shoes

/obj/item/clothing/shoes
	var/snow_mult = 1
	var/mud_mult = 1
	var/wade_mult = 1
	var/ice_grip = 0
	var/slope_grip = 1
	var/offsnow_slowdown = 0
	var/open_toed = FALSE
	var/waterproof_feet = FALSE

/obj/item/clothing/shoes/examine(mob/user)
	..(user)
	var/list/traits = footwear_trait_notes()
	if (traits.len)
		to_chat(user, SPAN_NOTICE("[jointext(traits, " ")]"))

/obj/item/clothing/shoes/proc/footwear_trait_notes()
	. = list()
	if (snow_mult <= 0.4)
		. += "They keep you on top of deep snow, but are clumsy on bare ground."
	else if (snow_mult < 1)
		. += "They make walking in snow easier."
	else if (snow_mult > 1)
		. += "They are poor in snow."
	if (mud_mult <= 0.6)
		. += "They keep you up out of the mud."
	else if (mud_mult < 1)
		. += "They help a little in mud."
	else if (mud_mult > 1)
		. += "Mud clings to them."
	if (wade_mult < 1)
		. += "They make wading easier."
	if (ice_grip >= 1)
		. += "Their studded soles grip ice."
	else if (ice_grip >= 0.5 || (item_flags & NOSLIP))
		. += "They grip ice fairly well."
	if (slope_grip < 1)
		. += "They give sure footing on steep slopes."
	else if (slope_grip > 1)
		. += "They are unsteady on steep slopes."
	if (waterproof_feet)
		. += "They keep your feet dry when wading."
	if (open_toed)
		. += "They leave your toes bare to the cold."

// How much one terrain kind ("snow", "mud" or "wade") slows this wearer, as a multiplier.
/proc/footwear_terrain_mult(mob/living/human/H, kind)
	if (!istype(H) || !istype(H.shoes, /obj/item/clothing/shoes))
		return 1
	var/obj/item/clothing/shoes/S = H.shoes
	switch (kind)
		if ("snow")
			return S.snow_mult
		if ("mud")
			return S.mud_mult
		if ("wade")
			return S.wade_mult
	return 1

/proc/footwear_offsnow_slowdown(mob/living/human/H)
	if (!istype(H) || !istype(H.shoes, /obj/item/clothing/shoes))
		return 0
	var/obj/item/clothing/shoes/S = H.shoes
	return S.offsnow_slowdown

/proc/footwear_ice_grip(mob/living/human/H)
	if (!istype(H) || !istype(H.shoes, /obj/item/clothing/shoes))
		return 0
	var/obj/item/clothing/shoes/S = H.shoes
	. = S.ice_grip
	if (S.item_flags & NOSLIP)
		. = max(., 0.5)
	return clamp(., 0, 1)

/proc/footwear_slope_grip(mob/living/human/H)
	if (!istype(H) || !istype(H.shoes, /obj/item/clothing/shoes))
		return 1
	var/obj/item/clothing/shoes/S = H.shoes
	return max(0, S.slope_grip)

// Bare, open-toed or uninsulated feet freeze in snow.
/proc/footwear_feet_bare_to_snow(mob/living/human/H)
	if (!H.shoes)
		return TRUE
	var/obj/item/clothing/shoes/S = H.shoes
	if (istype(S) && S.open_toed)
		return TRUE
	return !(H.shoes.cold_protection & FEET)

/proc/footwear_feet_dry(mob/living/human/H)
	var/obj/item/clothing/shoes/S = H.shoes
	return istype(S) && S.waterproof_feet

/proc/footwear_ice_turf(turf/T)
	if (istype(T, /turf/floor/beach/water/ice))
		return TRUE
	var/turf/floor/F = T
	return istype(F) && F.wet == 3

// Standing in water or mud (not ice) wets the feet.
/proc/footwear_wet_ground(turf/T)
	if (!istype(T))
		return FALSE
	if (istype(T, /turf/floor/beach/water) && !istype(T, /turf/floor/beach/water/ice))
		return TRUE
	if (istype(T, /turf/floor/trench/flooded))
		return TRUE
	var/turf/floor/F = T
	if (istype(F) && F.muddy)
		return TRUE
	for (var/obj/effect/flooding/FLD in T)
		return TRUE
	return FALSE

// Called for each running step: on ice, poorly gripping footwear can slip.
// NOSLIP footwear still only halves the chance; ice grip is its own rating.
/proc/footwear_ice_slip_check(mob/living/human/H, turf/T, distance_fraction = 1)
	if (!istype(H) || H.buckled || H.lying || H.m_intent != "run" || distance_fraction < 1)
		return FALSE
	if (!footwear_ice_turf(T))
		return FALSE
	if (H.species && (H.species.flags & NO_SLIP))
		return FALSE
	var/chance = FOOTWEAR_ICE_SLIP_CHANCE * (1 - footwear_ice_grip(H))
	if (chance <= 0 || !prob(chance))
		return FALSE
	H.stop_pulling()
	to_chat(H, SPAN_WARNING("Your feet skid out from under you on the ice!"))
	playsound(H.loc, 'sound/misc/slip.ogg', 50, TRUE, -3)
	H.Stun(3)
	H.Weaken(2)
	return TRUE

#undef FOOTWEAR_ICE_SLIP_CHANCE

// ---------------------------------------------------------------------------
// Ratings for existing footwear
// ---------------------------------------------------------------------------

// Fur and wool boots: warm and good in snow, but they soak up mud.
/obj/item/clothing/shoes/fur
	snow_mult = 0.75
	mud_mult = 1.15

/obj/item/clothing/shoes/winterboots
	snow_mult = 0.75
	waterproof_feet = TRUE

/obj/item/clothing/shoes/steppe_shoes
	snow_mult = 0.85

// Solid leather and military boots shed water and handle mud a little better.
/obj/item/clothing/shoes/leatherboots
	mud_mult = 0.85
	wade_mult = 0.9
	waterproof_feet = TRUE

/obj/item/clothing/shoes/blackboots
	mud_mult = 0.85
	wade_mult = 0.9
	waterproof_feet = TRUE

/obj/item/clothing/shoes/jackboots
	mud_mult = 0.85
	wade_mult = 0.9
	waterproof_feet = TRUE

/obj/item/clothing/shoes/heavyboots
	mud_mult = 0.85
	wade_mult = 0.9
	waterproof_feet = TRUE

/obj/item/clothing/shoes/workboots
	mud_mult = 0.85
	wade_mult = 0.9
	slope_grip = 0.8
	waterproof_feet = TRUE

/obj/item/clothing/shoes/combat
	mud_mult = 0.85
	wade_mult = 0.9
	waterproof_feet = TRUE

/obj/item/clothing/shoes/swat
	mud_mult = 0.85
	wade_mult = 0.9
	waterproof_feet = TRUE

/obj/item/clothing/shoes/riding1
	mud_mult = 0.85
	waterproof_feet = TRUE

/obj/item/clothing/shoes/riding2
	mud_mult = 0.85
	waterproof_feet = TRUE

// Sandals and slippers: light, but the toes are bare to snow.
/obj/item/clothing/shoes/sandal
	snow_mult = 1.15
	open_toed = TRUE

/obj/item/clothing/shoes/roman
	snow_mult = 1.15
	open_toed = TRUE

/obj/item/clothing/shoes/aztec_sandals
	snow_mult = 1.15
	open_toed = TRUE

/obj/item/clothing/shoes/flipflops
	snow_mult = 1.15
	open_toed = TRUE

/obj/item/clothing/shoes/slippers
	snow_mult = 1.15
	open_toed = TRUE

/obj/item/clothing/shoes/slippers_worn
	snow_mult = 1.15
	open_toed = TRUE

// Geta stand on wooden teeth that lift the foot out of the mud.
/obj/item/clothing/shoes/geta
	mud_mult = 0.6
	open_toed = TRUE

// ---------------------------------------------------------------------------
// New footwear
// ---------------------------------------------------------------------------

/obj/item/clothing/shoes/weather
	icon = 'icons/obj/weather_footwear.dmi'
	icon_override = 'icons/mob/weather_footwear.dmi'
	force = WEAPON_FORCE_WEAK
	siemens_coefficient = 0.6

// Stone Age (wood): float on deep snow, clumsy on bare ground.
/obj/item/clothing/shoes/weather/snowshoes
	name = "snowshoes"
	desc = "Wide frames of bent wood laced with rawhide, tied over fur-wrapped feet. They keep you on top of the snow."
	icon_state = "snowshoes"
	item_state = "fur"
	slowdown = 0
	snow_mult = 0.2
	offsnow_slowdown = 0.4
	mud_mult = 1.2
	slope_grip = 1.5
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
	flammable = TRUE
	can_hold_knife = FALSE

// Stone Age (leather): warm soft boots for snow; poor in wet ground.
/obj/item/clothing/shoes/weather/mukluks
	name = "mukluks"
	desc = "Soft knee-high hide boots with a fur cuff, warm and quiet on snow."
	icon_state = "mukluks"
	item_state = "fur"
	armor = list(melee = 10, arrow = 5, gun = FALSE, energy = 15, bomb = 30, bio = 10, rad = 10)
	snow_mult = 0.6
	ice_grip = 0.5
	mud_mult = 1.2
	wade_mult = 1.1
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
	flammable = TRUE

// Iron Age (leather, iron smithing): iron studs grip ice and hillsides.
/obj/item/clothing/shoes/weather/hobnail_boots
	name = "hobnailed boots"
	desc = "Stout leather boots with iron hobnails driven through the soles. They bite into ice and rough slopes."
	icon_state = "hobnail_boots"
	item_state = "sailorboots2"
	armor = list(melee = 15, arrow = 20, gun = FALSE, energy = 25, bomb = 50, bio = 10, rad = 0)
	item_flags = NOSLIP
	slowdown = 0
	ice_grip = 1
	slope_grip = 0.6
	snow_mult = 0.9
	mud_mult = 0.9
	waterproof_feet = TRUE
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE

// Medieval (wood, tailoring): raised wooden soles worn over shoes in mud.
/obj/item/clothing/shoes/weather/pattens
	name = "pattens"
	desc = "Shoes strapped onto raised wooden soles that lift you clear of mud and puddles. Wobbly on hills and ice."
	icon_state = "pattens"
	item_state = "sailorboots2"
	slowdown = 0
	mud_mult = 0.4
	wade_mult = 0.8
	slope_grip = 1.4
	waterproof_feet = TRUE
	flammable = TRUE

// Industrial (plastic, ready-made clothing): rubber boots for mud and water.
/obj/item/clothing/shoes/weather/rubber_boots
	name = "rubber boots"
	desc = "Calf-high rubber boots. Mud and water stay outside."
	icon_state = "rubber_boots"
	item_state = "jackboots"
	slowdown = -0.1
	mud_mult = 0.5
	wade_mult = 0.6
	snow_mult = 0.9
	ice_grip = 0.25
	waterproof_feet = TRUE
	siemens_coefficient = 0.2

// Modern (steel, alloys): insulated mountaineering boots with crampons.
/obj/item/clothing/shoes/weather/climbing_boots
	name = "mountaineering boots"
	desc = "Stiff insulated climbing boots with steel crampons strapped under the soles. Sure-footed on ice, snow and steep ground."
	icon_state = "climbing_boots"
	item_state = "jackboots"
	armor = list(melee = 15, arrow = 15, gun = FALSE, energy = 25, bomb = 50, bio = 10, rad = 10)
	item_flags = NOSLIP
	slowdown = 0.1
	ice_grip = 1
	slope_grip = 0.3
	snow_mult = 0.7
	mud_mult = 0.9
	waterproof_feet = TRUE
	cold_protection = FEET
	min_cold_protection_temperature = SHOE_MIN_COLD_PROTECTION_TEMPERATURE
