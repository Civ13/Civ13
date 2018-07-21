
/* Job Factions

 - These are/will be used for spies, partisans, and squads.
 - They're like antagonist datums but much simpler. You can have many
 - different factions depending on your job

 - helper functions are at the bottom

*/

#define TEAM_RU 1
#define TEAM_GE 2
#define TEAM_PN 3

var/global/spies[3]
var/global/officers[3]
var/global/commanders[3]
var/global/squad_leaders[3]
var/global/soldiers[3]
var/global/squad_members[3]

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
	team = TEAM_GE

/datum/faction/pirates/base_type()
	return "/datum/faction/pirates"

// you appear to be a british soldier to all other brits
/datum/faction/british
	icon_state = "rn_basic"
	title = "Royal Navy Sailor"
	team = TEAM_RU

/datum/faction/british/base_type()
	return "/datum/faction/british"

