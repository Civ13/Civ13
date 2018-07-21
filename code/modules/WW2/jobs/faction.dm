
/* Job Factions

 - These are/will be used for spies, partisans, and squads.
 - They're like antagonist datums but much simpler. You can have many
 - different factions depending on your job

 - helper functions are at the bottom

*/

#define TEAM_RU 1
#define TEAM_GE 2
#define TEAM_PN 3
#define TEAM_JP 4
#define TEAM_US 5
#define TEAM_PO 6

var/global/spies[6]
var/global/officers[6]
var/global/commanders[6]
var/global/squad_leaders[6]
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


// you appear to be a partisan to all other partisans
/datum/faction/partisan
	icon_state = "partisan_soldier"
	title = "Partisan Soldier"
	team = TEAM_PN

/datum/faction/partisan/base_type()
	return "/datum/faction/partisan"

// you appear to be an officer to all other partisans (UNUSED)
/datum/faction/partisan/officer
	icon_state = "partisan_officer"
	team = TEAM_PN
// you appear to be a partisan leader to all other partisans
/datum/faction/partisan/commander
	icon_state = "partisan_commander"
	title = "Partisan Leader"
	team = TEAM_PN


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

