
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

var/global/officers[6]
var/global/commanders[6]
var/global/soldiers[6]
var/global/squad_members[6]

/datum/faction
	// redefine these since they don't exist in /datum
	var/icon = 'icons/mob/hud_WW2.dmi'
	var/icon_state = ""
	var/mob/living/carbon/human/holder = null
	var/title = "Something that shouldn't exist"
	var/list/objectives = list()
	var/team = null
	var/image/last_returned_image = null
	var/obj/factionhud/last_returned_hud = null

/datum/faction/proc/base_type()
	return "/datum/faction"


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


// CODE
/datum/faction/New(var/mob/living/carbon/human/H, var/datum/job/J)

	if (!H || !istype(H))
		return

	holder = H

/*	if (findtext("[type]", "leader"))
		if (istype(J, /datum/job/pirates))
			squad_leaders[PIRATES]++
		else if (istype(J, /datum/job/british))
			squad_leaders[BRITISH]++
	else if (findtext("[type]", "officer"))
		if (istype(J, /datum/job/german))
			officers[GERMAN]++
		else if (istype(J, /datum/job/soviet))
			officers[SOVIET]++
		else if (istype(J, /datum/job/partisan))
			officers[PARTISAN]++
		else if (istype(J, /datum/job/polish))
			officers[POLISH_INSURGENTS]++
		else if (istype(J, /datum/job/japanese))
			officers[JAPAN]++
		else if (istype(J, /datum/job/usa))
			officers[USA]++
	else if (findtext("[type]", "commander"))
		if (istype(J, /datum/job/german))
			commanders[GERMAN]++
		else if (istype(J, /datum/job/soviet))
			commanders[SOVIET]++
		else if (istype(J, /datum/job/partisan))
			commanders[PARTISAN]++
		else if (istype(J, /datum/job/polish))
			commanders[POLISH_INSURGENTS]++
		else if (istype(J, /datum/job/japanese))
			commanders[JAPAN]++
		else if (istype(J, /datum/job/usa))
			commanders[USA]++
	else if (!J.is_officer && !J.is_commander && !J.is_squad_leader)
		if (istype(J, /datum/job/german))
			if ("[type]" == "/datum/faction/german")
				soldiers[GERMAN]++
			else if (findtext("[type]", "squad") && !src:is_leader)
				squad_members[GERMAN]++
		else if (istype(J, /datum/job/soviet))
			if ("[type]" == "/datum/faction/soviet")
				soldiers[SOVIET]++
			else if (findtext("[type]", "squad") && !src:is_leader)
				squad_members[SOVIET]++
		else if (istype(J, /datum/job/partisan))
			if ("[type]" == "/datum/faction/partisan")
				soldiers[PARTISAN]++
			else if (findtext("[type]", "squad") && !src:is_leader)
				squad_members[PARTISAN]++
		else if (istype(J, /datum/job/polish))
			if ("[type]" == "/datum/faction/polish")
				soldiers[POLISH_INSURGENTS]++
			else if (findtext("[type]", "squad") && !src:is_leader)
				squad_members[POLISH_INSURGENTS]++
		else if (istype(J, /datum/job/usa))
			if ("[type]" == "/datum/faction/usa")
				soldiers[USA]++
			else if (findtext("[type]", "squad") && !src:is_leader)
				squad_members[USA]++
		else if (istype(J, /datum/job/japanese))
			if ("[type]" == "/datum/faction/japanese")
				soldiers[JAPAN]++
			else if (findtext("[type]", "squad") && !src:is_leader)
				squad_members[JAPAN]++
			*/
	if (istype(J, /datum/job/pirates))
		if ("[type]" == "/datum/faction/pirates")
			soldiers[PIRATES]++
	else if (istype(J, /datum/job/british))
		if ("[type]" == "/datum/faction/british")
			soldiers[BRITISH]++
	H.all_factions += src
	..()

/* HELPER FUNCTIONS */
/*
/proc/issquadleader(var/mob/living/carbon/human/H)
	if (H.squad_faction && H.squad_faction.is_leader)
		return TRUE
	return FALSE

/proc/issquadmember(var/mob/living/carbon/human/H)
	if (H.squad_faction && !H.squad_faction.is_leader)
		return TRUE
	return FALSE

/proc/getsquad(var/mob/living/carbon/human/H)
	if (H.squad_faction)
		return H.squad_faction.squad
	return null
*/
/proc/isbritishsquadmember_or_leader(var/mob/living/carbon/human/H)
	return (istype(H.original_job, /datum/job/british))

/proc/ispiratequadmember_or_leader(var/mob/living/carbon/human/H)
	return (istype(H.original_job, /datum/job/pirates))
