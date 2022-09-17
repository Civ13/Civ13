/*
	Datum-based species. Should make for much cleaner and easier to maintain race code.
*/

/datum/species

	// Descriptors and strings.
	var/name											 // Species name.
	var/name_plural									  // Pluralized name (since "[name]s" is not always valid)
	var/blurb = "A completely nondescript species."	  // A brief lore summary for use in the chargen screen.

	// Icon/appearance vars.
	var/icobase = 'icons/mob/human_races/r_human.dmi'	// Normal icon set.

	// Damage overlay and masks.
	var/damage_overlays = 'icons/mob/human_races/masks/dam_human.dmi'
	var/damage_mask = 'icons/mob/human_races/masks/dam_mask_human.dmi'
	var/blood_mask = 'icons/mob/human_races/masks/blood_human.dmi'

	var/prone_icon									   // If set, draws this from icobase when mob is prone.
	var/eyes = "eyes_s"								  // Icon for eyes.
	var/has_floating_eyes								// Eyes will overlay over darkness (glow)
	var/blood_color = "#A10808"						  // Red.
	var/flesh_color = "#FFC896"						  // Pink.
	var/base_color									   // Used by changelings. Should also be used for icon previes..
	var/tail											 // Name of tail state in species effects icon file.
	var/tail_animation								   // If set, the icon to obtain tail animation states from.
	var/race_key = FALSE	   								 // Used for mob icon cache string.
	var/icon/icon_template							   // Used for mob icon generation for non-32x32 species.
	var/mob_size	= MOB_MEDIUM
	var/show_ssd = "fast asleep"
	var/virus_immune
	var/blood_volume = 560							   // Initial blood volume.
	var/hunger_factor = DEFAULT_HUNGER_FACTOR			// Multiplier for hunger.
	var/taste_sensitivity = TASTE_NORMAL				 // How sensitive the species is to minute tastes.

	var/teeth_type = /obj/item/stack/teeth/generic 		 //What sort of teeth do the species have

	var/min_age = 18
	var/max_age = 75

	// Language/culture vars.
	var/default_language = "Galactic Common" // Default language is used when 'say' is used without modifiers.
	var/language = "Galactic Common"		 // Default racial language, if any.
	var/list/secondary_langs = list()		// The names of secondary languages that are available to this species.
	var/list/speech_sounds				   // A list of sounds to potentially play when speaking.
	var/list/speech_chance				   // The likelihood of a speech sound playing.
	var/num_alternate_languages = FALSE		  // How many secondary languages are available to select at character creation
	var/name_language = "Galactic Common"	// The language to use when determining names for this species, or null to use the first name/last name generator

	// Combat vars.
	var/total_health = 100				   // Point at which the mob will enter crit.
	var/list/unarmed_types = list(		   // Possible unarmed attacks that the mob will use in combat,
		/datum/unarmed_attack,
		/datum/unarmed_attack/bite
		)
	var/list/unarmed_attacks = null		  // For empty hand harm-intent attack
	var/brute_mod =	 TRUE					// Physical damage multiplier.
	var/burn_mod =	  TRUE					// Burn damage multiplier.
	var/oxy_mod =	   TRUE					// Oxyloss modifier
	var/toxins_mod =	TRUE					// Toxloss modifier
	var/radiation_mod = TRUE					// Radiation modifier
	var/flash_mod =	 TRUE					// Stun from blindness modifier.
	var/vision_flags = SEE_SELF			  // Same flags as glasses.

	// Death vars.
	var/meat_type = /obj/item/weapon/reagent_containers/food/snacks/meat/human
	var/gibber_type = /obj/effect/gibspawner/human
	var/single_gib_type = /obj/effect/decal/cleanable/blood/gibs
	var/gibbed_anim = "gibbed-h"
	var/dusted_anim = "dust-h"
	var/death_sound
	var/death_message = ""//"seizes up and falls limp, their eyes dead and lifeless..."
	var/knockout_message = "has been knocked unconscious!"
	var/halloss_message = "slumps to the ground, too weak to continue fighting."
	var/halloss_message_self = "You're in too much pain to keep going..."

	// Environment tolerance/life processes vars.
	var/reagent_tag								   //Used for metabolizing reagents.
//	var/breath_pressure = 16						  // Minimum partial pressure safe for breathing, kPa
//	var/breath_type = "oxygen"						// Non-oxygen gas breathed, if any.
//	var/poison_type = "plasma"						// Poisonous air.
//	var/exhale_type = "carbon_dioxide"				// Exhaled gas type.
	var/cold_level_1 = 260							// Cold damage level TRUE below this point.
	var/cold_level_2 = 250							// Cold damage level 2 below this point.
	var/cold_level_3 = 220							// Cold damage level 3 below this point.
	var/heat_level_1 = 315							// Heat damage level TRUE above this point.
	var/heat_level_2 = 323							// Heat damage level 2 above this point.
	var/heat_level_3 = 333						   // Heat damage level 3 above this point.
	var/passive_temp_gain = FALSE						  // Species will gain this much temperature every second
//	var/hazard_high_pressure = HAZARD_HIGH_PRESSURE   // Dangerously high pressure.
//	var/warning_high_pressure = WARNING_HIGH_PRESSURE // High pressure warning.
//	var/warning_low_pressure = WARNING_LOW_PRESSURE   // Low pressure warning.
//	var/hazard_low_pressure = HAZARD_LOW_PRESSURE	 // Dangerously low pressure.
	var/light_dam									 // If set, mob will be damaged in light over this value and heal in light below its negative.
	var/body_temperature = 310.15					  // Non-IS_SYNTHETIC species will try to stabilize at this temperature.
													  // (also affects temperature processing)

	var/list/heat_discomfort_strings = list(
		"You feel sweat drip down your neck.",
		"You feel uncomfortably warm.",
		"Your skin prickles in the heat."
		)

	var/list/cold_discomfort_strings = list(
		"You feel chilly.",
		"You shiver suddenly.",
		"Your chilly flesh stands out in goosebumps."
		)

	// HUD data vars.
	var/datum/hud_data/hud
	var/hud_type

	// Body/form vars.
	var/list/inherent_verbs 	  // Species-specific verbs.
	var/has_fine_manipulation = TRUE // Can use small items.
	var/siemens_coefficient = TRUE   // The lower, the thicker the skin and better the insulation.
	var/darksight = 2			 // Native darksight distance.
	var/flags = FALSE				 // Various specific features.
	var/appearance_flags = FALSE	  // Appearance/display related features.
	var/spawn_flags = FALSE		   // Flags that specify who can spawn as this species
	var/slowdown = FALSE			  // Passive movement speed malus (or boost, if negative)
	var/primitive_form			// Lesser form, if any (ie. monkey for humans)
	var/greater_form			  // Greater form, if any, ie. human for monkeys.
	var/holder_type
	var/gluttonous				// Can eat some mobs. Values can be GLUT_TINY, GLUT_SMALLER, GLUT_ANYTHING.
	var/rarity_value = TRUE		  // Relative rarity/collector value for this species.
								  // Determines the organs that the species spawns with and
	var/list/has_organ = list(	// which required-organ checks are conducted.
		"heart" =	/obj/item/organ/heart,
		"lungs" =	/obj/item/organ/lungs,
		"liver" =	/obj/item/organ/liver,
		"kidneys" =  /obj/item/organ/kidneys,
		"brain" =	/obj/item/organ/brain,
		"appendix" = /obj/item/organ/appendix,
		"eyes" =	 /obj/item/organ/eyes
		)
	var/vision_organ			  // If set, this organ is required for vision. Defaults to "eyes" if the species has them.

	var/list/has_limbs = list(
		"chest" =  list("path" = /obj/item/organ/external/chest),
		"groin" =  list("path" = /obj/item/organ/external/groin),
		"head" =   list("path" = /obj/item/organ/external/head),
		"l_arm" =  list("path" = /obj/item/organ/external/arm),
		"r_arm" =  list("path" = /obj/item/organ/external/arm/right),
		"l_leg" =  list("path" = /obj/item/organ/external/leg),
		"r_leg" =  list("path" = /obj/item/organ/external/leg/right),
		"l_hand" = list("path" = /obj/item/organ/external/hand),
		"r_hand" = list("path" = /obj/item/organ/external/hand/right),
		"l_foot" = list("path" = /obj/item/organ/external/foot),
		"r_foot" = list("path" = /obj/item/organ/external/foot/right)
		)

	// Misc
	var/list/genders = list(MALE, FEMALE)

	// Bump vars
	var/bump_flag = HUMAN	// What are we considered to be when bumped?
	var/push_flags = ~HEAVY	// What can we push?
	var/swap_flags = ~HEAVY	// What can we swap place with?

	var/pass_flags = FALSE

/datum/species/proc/get_eyes(var/mob/living/human/H)
	return

/datum/species/New()
	if (hud_type)
		hud = new hud_type()
	else
		hud = new()

	//If the species has eyes, they are the default vision organ
	if (!vision_organ && has_organ["eyes"])
		vision_organ = "eyes"

	unarmed_attacks = list()
	for (var/u_type in unarmed_types)
		unarmed_attacks += new u_type()

/datum/species/proc/get_station_variant()
	return name

/datum/species/proc/get_bodytype()
	return name

/datum/species/proc/get_environment_discomfort(var/mob/living/human/H)
	if (H.bodytemperature > heat_level_1 && !H.orc)
		var/dmod = 1
		if (H.find_trait("Heat Tolerance"))
			dmod = 0.3
		if (H.find_trait("Heat Sensitivity"))
			dmod = 2
		var/area/A = get_area(H)
		if (A.climate == "desert" && A.location == AREA_OUTSIDE)
			if (!H.shoes)
				if (prob(25))
					H << "<span class='danger'>The hot ground burns your feet!</span>"
					H.adjustFireLossByPart(0.3*dmod, pick("l_foot", "r_foot"))

		//Check protected bodyparts
		var/sum = 0
		var/list/exposed_bp = list("l_leg","r_leg","chest","groin","l_arm","r_arm","head")
		for (var/obj/item/clothing/C in list(H.head,H.wear_suit,H.w_uniform,H.shoes,H.gloves,H.wear_mask))
			if (C)
				if (C.heat_protection)
					sum |= C.heat_protection
			if (sum & HEAD)
				exposed_bp -= "head"
			if (sum & UPPER_TORSO)
				exposed_bp -= "chest"
			if (sum & LOWER_TORSO)
				exposed_bp -= "groin"
			if (sum & LEGS)
				exposed_bp -= "l_leg"
				exposed_bp -= "r_leg"
			if (sum & FEET)
				exposed_bp -= "l_foot"
				exposed_bp -= "r_foot"
			if (sum & ARMS)
				exposed_bp -= "l_arm"
				exposed_bp -= "r_arm"
			if (sum & HANDS)
				exposed_bp -= "l_hand"
				exposed_bp -= "r_hand"

		for (var/i in exposed_bp)
			H.adjustFireLossByPart(0.2*dmod, i)

		if (prob(12))
			H << "<span class='danger'>[pick(heat_discomfort_strings)]</span>"

		if (A.weather == WEATHER_EXTREME && findtext(A,"sandstorm"))
			if (prob(15))
				H << "<span class='danger'>The dust abrades your exposed flesh!</span>"
			for (var/i in exposed_bp)
				H.adjustFireLossByPart(1*dmod, i)

	if (H.bodytemperature < cold_level_1 && !H.wolfman)
		var/dmod = 1
		if (H.find_trait("Cold Tolerance"))
			dmod = 0.3
		if (H.find_trait("Cold Sensitivity"))
			dmod = 2
		var/area/A = get_area(H)
		for (var/obj/structure/brazier/BR in range(3, H))
			if (BR.on == TRUE)
				return
		for (var/obj/structure/heatsource/HS in range(3, H))
			if (HS.on == TRUE)
				return
		for (var/obj/structure/oven/fireplace/FP in range(1, H))
			if (FP.on == TRUE)
				return
		var/turf/T = get_turf(H)
		if (istype(T) && T.icon == 'icons/turf/snow.dmi' && H.shoes)
			if (H.shoes.cold_protection != FEET)
				if (prob(25 - (H.shoes ? 15 : 0)))
					H << "<span class='danger'>Your feet are freezing!</span>"
					H.adjustFireLossByPart(1*dmod, pick("l_foot", "r_foot"))

		//Check protected bodyparts
		var/sum = 0
		var/list/exposed_bp = list("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","head")
		for (var/obj/item/clothing/C in list(H.head,H.wear_suit,H.w_uniform,H.shoes,H.gloves,H.wear_mask))
			if (C)
				if (C.cold_protection)
					sum |= C.cold_protection
			if (sum & HEAD)
				exposed_bp -= "head"
			if (sum & UPPER_TORSO)
				exposed_bp -= "chest"
			if (sum & LOWER_TORSO)
				exposed_bp -= "groin"
			if (sum & LEGS)
				exposed_bp -= "l_leg"
				exposed_bp -= "r_leg"
			if (sum & FEET)
				exposed_bp -= "l_foot"
				exposed_bp -= "r_foot"
			if (sum & ARMS)
				exposed_bp -= "l_arm"
				exposed_bp -= "r_arm"
			if (sum & HANDS)
				exposed_bp -= "l_hand"
				exposed_bp -= "r_hand"

		for (var/i in exposed_bp)
			H.adjustFireLossByPart(0.5*dmod, i)

		if (prob(12))
			H << "<span class='danger'>[pick(cold_discomfort_strings)]</span>"

		if (A.icon_state == "snow_storm" && A.location == AREA_OUTSIDE)
			if (prob(12))
				H << "<span class='danger'>The blizzard chills you to the bone!</span>"
			H.adjustFireLoss(0.8*dmod)
/*
		var/area/A = get_area(H)
		if (A.weather == WEATHER_WET && findtext(A,"rain"))
			if (prob(15))
				H << "<span class='danger'>The cold rain chills you to the bone.</span>"
			H.adjustFireLoss(3) // wet is bad
		else if (A.weather == WEATHER_WET && findtext(A,"snow"))
			if (prob(15))
				H << "<span class='danger'>The freezing snowfall chills you to the bone.</span>"
			H.adjustFireLoss(2)
*/
/datum/species/proc/sanitize_name(var/name)
	return sanitizeName(name)

/datum/species/proc/get_random_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female)) + " " + capitalize(pick(last_names))
		else
			return capitalize(pick(first_names_male)) + " " + capitalize(pick(last_names))


/datum/species/proc/get_random_english_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_english)) + " " + capitalize(pick(last_names_english))
		else
			return capitalize(pick(first_names_male_english)) + " " + capitalize(pick(last_names_english))


/datum/species/proc/get_random_carib_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_carib))
		else
			return capitalize(pick(first_names_male_carib))


/datum/species/proc/get_random_french_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_french)) + " " + capitalize(pick(last_names_french))
		else
			return capitalize(pick(first_names_male_french)) + " " + capitalize(pick(last_names_french))


/datum/species/proc/get_random_portuguese_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_portuguese)) + " " + capitalize(pick(last_names_portuguese))
		else
			return capitalize(pick(first_names_male_portuguese)) + " " + capitalize(pick(last_names_portuguese))


/datum/species/proc/get_random_spanish_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_spanish)) + " " + capitalize(pick(last_names_spanish))
		else
			return capitalize(pick(first_names_male_spanish)) + " " + capitalize(pick(last_names_spanish))


/datum/species/proc/get_random_dutch_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_dutch)) + " " + capitalize(pick(last_names_dutch))
		else
			return capitalize(pick(first_names_male_dutch)) + " " + capitalize(pick(last_names_dutch))

/datum/species/proc/get_random_japanese_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_japanese)) + " " + capitalize(pick(last_names_japanese))
		else
			return capitalize(pick(first_names_male_japanese)) + " " + capitalize(pick(last_names_japanese))

/datum/species/proc/get_random_russian_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_russian)) + " " + capitalize(pick(last_names_russian) + "a")
		else
			return capitalize(pick(first_names_male_russian)) + " " + capitalize(pick(last_names_russian))

/datum/species/proc/get_random_ukrainian_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_ukrainian)) + " " + capitalize(pick(last_names_ukrainian))
		else
			return capitalize(pick(first_names_male_ukrainian)) + " " + capitalize(pick(last_names_ukrainian))

/datum/species/proc/get_random_polish_name(var/gender)
	if (!name_language)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_polish)) + " " + capitalize(pick(last_names_polish))
		else
			return capitalize(pick(first_names_male_polish)) + " " + capitalize(pick(last_names_polish))


/datum/species/proc/get_random_greek_name(var/gender)
	if (!name_language)

		return capitalize(pick(first_names_male_greek)) + " " + capitalize(pick(last_names_greek))

/datum/species/proc/get_random_roman_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_roman)) + " " + capitalize(pick(last_names_roman))
		else
			return capitalize(pick(first_names_male_roman)) + " " + capitalize(pick(middle_names_roman)) + " " + capitalize(pick(last_names_roman))
							//some useless code removed

/datum/species/proc/get_random_ancient_name(var/gender)
	if (!name_language)

		return capitalize(pick(ancient_names)) + " " + pick(epithets)

/datum/species/proc/get_random_arab_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_arab)) + " ibn " + capitalize(pick(first_names_male_arab))
		else
			return capitalize(pick(first_names_male_arab)) + " ibn " + capitalize(pick(first_names_male_arab))

/datum/species/proc/get_random_chechen_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_male_chechen)) + " " + capitalize(pick(last_names_chechen) + "a") //will have to changed in case chechen female names get added
		else
			return capitalize(pick(first_names_male_chechen)) + " " + capitalize(pick(last_names_chechen))

/datum/species/proc/get_random_hebrew_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_hebrew)) + " " + capitalize(pick(last_names_hebrew))
		else
			return capitalize(pick(first_names_male_hebrew)) + " " + capitalize(pick(last_names_hebrew))

/datum/species/proc/get_random_german_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_german)) + " " + capitalize(pick(last_names_german))
		else
			return capitalize(pick(first_names_male_german)) + " " + capitalize(pick(last_names_german))

/datum/species/proc/get_random_vietnamese_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_vietnamese)) + " " + capitalize(pick(last_names_vietnamese))
		else
			return capitalize(pick(first_names_male_vietnamese)) + " " + capitalize(pick(last_names_vietnamese))


/datum/species/proc/get_random_ainu_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_ainu)) + " " + capitalize(pick(last_names_ainu,))
		else
			return capitalize(pick(first_names_male_ainu)) + " " + capitalize(pick(last_names_ainu))

/datum/species/proc/get_random_chinese_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_chinese)) + " " + capitalize(pick(last_names_chinese))
		else
			return capitalize(pick(first_names_male_chinese)) + " " + capitalize(pick(last_names_chinese))

/datum/species/proc/get_random_swahili_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_swahili)) + " " + capitalize(pick(last_names_swahili))
		else
			return capitalize(pick(first_names_male_swahili)) + " " + capitalize(pick(last_names_swahili))

/datum/species/proc/get_random_zulu_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_zulu)) + " " + capitalize(pick(last_names_zulu))
		else
			return capitalize(pick(first_names_male_zulu)) + " " + capitalize(pick(last_names_zulu))

/datum/species/proc/get_random_orc_name(var/gender)
	if (!name_language)

		return capitalize(pick(first_names_orc))

/datum/species/proc/get_random_ant_name(var/gender)
	if (!name_language)

		return capitalize(pick(first_names_ant))

/datum/species/proc/get_random_gorilla_name(var/gender)
	if (!name_language)

		return capitalize(pick(first_names_gorilla))

/datum/species/proc/get_random_wolf_name(var/gender)
	if (!name_language)

		return capitalize(pick(first_names_wolf)) + " " + capitalize(pick(last_names_wolf))

/datum/species/proc/get_random_lizard_name(var/gender)
	if (!name_language)

		return capitalize(pick(first_names_lizard))
/datum/species/proc/get_random_crab_name(var/gender)
	if (!name_language)

		return capitalize(pick(first_names_crab)) + " " + capitalize(pick(last_names_crab))

/datum/species/proc/get_random_gaelic_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_gaelic)) + " " + capitalize(pick(last_names_gaelic))
		else
			return capitalize(pick(first_names_male_gaelic)) + " " + capitalize(pick(last_names_gaelic))

/datum/species/proc/get_random_irish_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_irish)) + " " + capitalize(pick(last_names_irish))
		else
			return capitalize(pick(first_names_male_irish)) + " " + capitalize(pick(last_names_irish))

/datum/species/proc/get_random_italian_name(var/gender)
	if (!name_language)
		if (gender==FEMALE)
			return capitalize(pick(first_names_female_italian)) + " " + capitalize(pick(last_names_italian))
		else
			return capitalize(pick(first_names_male_italian)) + " " + capitalize(pick(last_names_italian))

/datum/species/proc/get_random_oldnorse_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_oldnorse)) + " " + capitalize(pick(last_names_oldnorse))
		else
			return capitalize(pick(first_names_male_oldnorse)) + " " + capitalize(pick(last_names_oldnorse))

/datum/species/proc/get_random_finnish_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_finnish)) + " " + capitalize(pick(last_names_finnish))
		else
			return capitalize(pick(first_names_male_finnish)) + " " + capitalize(pick(last_names_finnish))

/datum/species/proc/get_random_norwegian_name(var/gender)//To be updated to proper Norwegian names
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_oldnorse)) + " " + capitalize(pick(last_names_oldnorse))
		else
			return capitalize(pick(first_names_male_oldnorse)) + " " + capitalize(pick(last_names_oldnorse))

/datum/species/proc/get_random_swedish_name(var/gender)//To be updated to proper Swedish names
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_oldnorse)) + " " + capitalize(pick(last_names_oldnorse))
		else
			return capitalize(pick(first_names_male_oldnorse)) + " " + capitalize(pick(last_names_oldnorse))

/datum/species/proc/get_random_danish_name(var/gender)//To be updated to proper Danish names
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_oldnorse)) + " " + capitalize(pick(last_names_oldnorse))
		else
			return capitalize(pick(first_names_male_oldnorse)) + " " + capitalize(pick(last_names_oldnorse))

/datum/species/proc/get_random_inuit_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_inuit))
		else
			return capitalize(pick(first_names_male_inuit))

/datum/species/proc/get_random_cherokee_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_cherokee))
		else
			return capitalize(pick(first_names_male_cherokee))

/datum/species/proc/get_random_korean_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_korean)) + " " + capitalize(pick(last_names_korean))
		else
			return capitalize(pick(first_names_male_korean)) + " " + capitalize(pick(last_names_korean))

/datum/species/proc/get_random_egyptian_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_egyptian)) + " " + capitalize(pick(last_names_egyptian))
		else
			return capitalize(pick(first_names_male_egyptian)) + " " + capitalize(pick(last_names_egyptian))

/datum/species/proc/get_random_filipino_name(var/gender)
	if (!name_language)
		if (gender == FEMALE)
			return capitalize(pick(first_names_female_filipino)) + " " + capitalize(pick(last_names_filipino))
		else
			return capitalize(pick(first_names_male_filipino)) + " " + capitalize(pick(last_names_filipino))

/datum/species/proc/create_organs(var/mob/living/human/H) //Handles creation of mob organs.

	for (var/obj/item/organ/organ in H.contents)
		if ((organ in H.organs) || (organ in H.internal_organs))
			qdel(organ)

	if (H.organs)				  H.organs.Cut()
	if (H.internal_organs)		 H.internal_organs.Cut()
	if (H.organs_by_name)		  H.organs_by_name.Cut()
	if (H.internal_organs_by_name) H.internal_organs_by_name.Cut()

	H.organs = list()
	H.internal_organs = list()
	H.organs_by_name = list()
	H.internal_organs_by_name = list()

	for (var/limb_type in has_limbs)
		var/list/organ_data = has_limbs[limb_type]
		var/limb_path = organ_data["path"]
		var/obj/item/organ/O = new limb_path(H)
		organ_data["descriptor"] = O.name

	for (var/organ_tag in has_organ)
		var/organ_type = has_organ[organ_tag]
		var/obj/item/organ/O = new organ_type(H,1)
		if (organ_tag != O.organ_tag)
			warning("[O.type] has a default organ tag \"[O.organ_tag]\" that differs from the species' organ tag \"[organ_tag]\". Updating organ_tag to match.")
			O.organ_tag = organ_tag
		H.internal_organs_by_name[organ_tag] = O

/datum/species/proc/hug(var/mob/living/human/H,var/mob/living/target)

	var/t_him = "them"
	switch(target.gender)
		if (MALE)
			t_him = "him"
		if (FEMALE)
			t_him = "her"

	H.visible_message("<span class='notice'>[H] hugs [target] to make [t_him] feel better!</span>", \
					"<span class='notice'>You hug [target] to make [t_him] feel better!</span>")

/datum/species/proc/remove_inherent_verbs(var/mob/living/human/H)
	if (inherent_verbs)
		for (var/verb_path in inherent_verbs)
			H.verbs -= verb_path
	return

/datum/species/proc/add_inherent_verbs(var/mob/living/human/H)
	if (inherent_verbs)
		for (var/verb_path in inherent_verbs)
			H.verbs |= verb_path
	return

/datum/species/proc/handle_post_spawn(var/mob/living/human/H) //Handles anything not already covered by basic species assignment.
	add_inherent_verbs(H)
	H.mob_bump_flag = bump_flag
	H.mob_swap_flags = swap_flags
	H.mob_push_flags = push_flags
	H.pass_flags = pass_flags
	H.mob_size = mob_size

/datum/species/proc/handle_death(var/mob/living/human/H) //Handles any species-specific death events (such as dionaea nymph spawns).
	return

// Builds the HUD using species-specific icons and usable slots.
/datum/species/proc/build_hud(var/mob/living/human/H)
	return

//Used by xenos understanding larvae and dionaea understanding nymphs.
/datum/species/proc/can_understand(var/mob/other)
	return

// Called in life() when the mob has no client.
/datum/species/proc/handle_npc(var/mob/living/human/H)
	return

/datum/species/proc/get_vision_flags(var/mob/living/human/H)
	return vision_flags

/datum/species/proc/handle_vision(var/mob/living/human/H)
	H.update_sight()
	H.sight |= get_vision_flags(H)
	H.sight |= H.equipment_vision_flags

	if (H.stat == DEAD)
		return TRUE

	if (!H.druggy)
		H.see_in_dark = (H.sight == SEE_TURFS|SEE_MOBS|SEE_OBJS) ? 8 : min(darksight + H.equipment_darkness_modifier, 8)
		if(H.equipment_see_invis)
			H.see_invisible = max(H.see_invisible, H.equipment_see_invis)

	if (H.equipment_tint_total >= TINT_BLIND)
		H.eye_blind = max(H.eye_blind, TRUE)

/*	if (H.blind)
		H.blind.alpha = (H.eye_blind ? 255 : FALSE)*/

	if (!H.client)//no client, no screen to update
		return TRUE

	for (var/overlay in H.equipment_overlays)
		H.client.screen |= overlay

	return TRUE
