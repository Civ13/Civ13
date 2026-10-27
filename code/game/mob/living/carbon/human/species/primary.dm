/datum/species/human
	name = "Human"
	name_plural = "Humans"
	unarmed_types = list(/datum/unarmed_attack/stomp, /datum/unarmed_attack/kick, /datum/unarmed_attack/punch, /datum/unarmed_attack/bite)
	secondary_langs = list()
	name_language = null // Use the first-name last-name generator rather than a language scrambler
	min_age = 16
	max_age = 75
	teeth_type = /obj/item/stack/teeth/human //Teeth

	spawn_flags = CAN_JOIN
	appearance_flags = HAS_HAIR_COLOR | HAS_SKIN_TONE | HAS_LIPS | HAS_UNDERWEAR | HAS_EYE_COLOR

/datum/species/human/get_bodytype()
	return "Human"