
/* Job Factions

 - These are/will be used for spies, partisans, and squads.
 - They're like antagonist datums but much simpler. You can have many
 - different factions depending on your job

 - helper functions are at the bottom

*/

#define TEAM_EN 1
#define TEAM_PI 2
#define TEAM_SP 3
#define TEAM_PT 4
#define TEAM_FR 5
#define TEAM_IN 6
#define TEAM_NL 7
#define TEAM_CV 8
#define TEAM_RO 9
#define TEAM_GR 10
#define TEAM_AR 11
var/global/soldiers[11]

/datum/faction
	// redefine these since they don't exist in /datum
	var/icon = 'icons/mob/hud_1713.dmi'
	var/icon_state = ""
	var/mob/living/carbon/human/holder = null
	var/title = "Something that shouldn't exist"
	var/list/objectives = list()
	var/team = null
	var/image/last_returned_image = null
	var/obj/factionhud/last_returned_hud = null

/datum/faction/proc/base_type()
	return "/datum/faction"

// you appear to be a civilian to other civilians
/datum/faction/civilian
	icon_state = "civilian_basic"
	title = "Civilian"
	team = TEAM_CV

/datum/faction/pirates/base_type()
	return "/datum/faction/pirates"

// you appear to be a pirate to other pirates
/datum/faction/pirates
	icon_state = "pirate_basic"
	title = "Pirate"
	team = TEAM_PI

/datum/faction/pirates/base_type()
	return "/datum/faction/pirates"

// you appear to be a pirate to other pirates
/datum/faction/spanish
	icon_state = "spanish_basic"
	title = "Spanish"
	team = TEAM_SP

/datum/faction/spanish/base_type()
	return "/datum/faction/spanish"

// you appear to be a pirate to other pirates
/datum/faction/portuguese
	icon_state = "portuguese_basic"
	title = "Portuguese"
	team = TEAM_PT

/datum/faction/portuguese/base_type()
	return "/datum/faction/portuguese"

// you appear to be a pirate to other pirates
/datum/faction/french
	icon_state = "french_basic"
	title = "French"
	team = TEAM_FR

/datum/faction/french/base_type()
	return "/datum/faction/french"

/datum/faction/indians
	icon_state = "indian_basic"
	title = "Indian"
	team = TEAM_IN

/datum/faction/indians/base_type()
	return "/datum/faction/indians"

// you appear to be a british soldier to all other brits
/datum/faction/british
	icon_state = "rn_basic"
	title = "Royal Navy Sailor"
	team = TEAM_EN

/datum/faction/british/base_type()
	return "/datum/faction/british"

// you appear to be a dutch soldier to all other brits
/datum/faction/dutch
	icon_state = "nl_basic"
	title = "Dutch Sailor"
	team = TEAM_NL

/datum/faction/dutch/base_type()
	return "/datum/faction/dutch"


/datum/faction/roman
	icon_state = ""
	title = "Roman Soldier"
	team = TEAM_RO

/datum/faction/roman/base_type()
	return "/datum/faction/roman"


/datum/faction/greek
	icon_state = ""
	title = "Greek Soldier"
	team = TEAM_GR

/datum/faction/greek/base_type()
	return "/datum/faction/greek"

/datum/faction/arab
	icon_state = ""
	title = "Arab Soldier"
	team = TEAM_AR

/datum/faction/arab/base_type()
	return "/datum/faction/arab"
// CODE
/datum/faction/New(var/mob/living/carbon/human/H, var/datum/job/J)

	if (!H || !istype(H))
		return

	holder = H
	if (istype(J, /datum/job/pirates))
		if ("[type]" == "/datum/faction/pirates")
			soldiers[PIRATES]++
	else if (istype(J, /datum/job/british))
		if ("[type]" == "/datum/faction/british")
			soldiers[BRITISH]++
	else if (istype(J, /datum/job/spanish))
		if ("[type]" == "/datum/faction/spanish")
			soldiers[SPANISH]++
	else if (istype(J, /datum/job/portuguese))
		if ("[type]" == "/datum/faction/portuguese")
			soldiers[PORTUGUESE]++
	else if (istype(J, /datum/job/french))
		if ("[type]" == "/datum/faction/french")
			soldiers[FRENCH]++
	else if (istype(J, /datum/job/dutch))
		if ("[type]" == "/datum/faction/dutch")
			soldiers[DUTCH]++
	else if (istype(J, /datum/job/indians))
		if ("[type]" == "/datum/faction/indians")
			soldiers[INDIANS]++
	else if (istype(J, /datum/job/civilian))
		if ("[type]" == "/datum/faction/civilian")
			soldiers[CIVILIAN]++
	else if (istype(J, /datum/job/roman))
		if ("[type]" == "/datum/faction/roman")
			soldiers[ROMAN]++
	else if (istype(J, /datum/job/greek))
		if ("[type]" == "/datum/faction/greek")
			soldiers[GREEK]++
	else if (istype(J, /datum/job/arab))
		if ("[type]" == "/datum/faction/arab")
			soldiers[ARAB]++
	H.all_factions += src
	..()