
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
/datum/faction/polish
	icon_state = "partisan_soldier"
	title = "Polish Soldier"
	team = TEAM_PO

/datum/faction/polish/base_type()
	return "/datum/faction/polish"

// you appear to be an officer to all other partisans (UNUSED)
/datum/faction/polish/officer
	icon_state = "partisan_officer"
	team = TEAM_PO
// you appear to be a partisan leader to all other partisans
/datum/faction/polish/commander
	icon_state = "partisan_commander"
	title = "Polish Leader"
	team = TEAM_PO

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
// you appear to be a german soldier to all other germans
/datum/faction/german
	icon_state = "german_soldier"
	title = "Wehrmacht Soldier"
	team = TEAM_GE

/datum/faction/german/base_type()
	return "/datum/faction/german"
// you appear to be a SS soldier to all other germans/italians
/datum/faction/german/SS
	icon_state = "ss_soldier"
	title = "SS Soldier"
	team = TEAM_GE
// you appear to be an officer to all other germans/italians
/datum/faction/german/officer
	icon_state = "german_officer"
	title = "Wehrmacht Officer"
	team = TEAM_GE
// you appear to be a german leader to all other germans/italians
/datum/faction/german/commander
	icon_state = "german_commander"
	title = "Hauptmann"
	team = TEAM_GE
// you appear to be a SS leader to all other germans/italians
/datum/faction/german/commander/SS
	icon_state = "ss_commander"
	title = "SS Commander"
	team = TEAM_GE
// you appear to be an Italian soldier to all other germans/italians
/datum/faction/german/italian
	icon_state = "italian_soldier"
	title = "Italian Soldier"
	team = TEAM_GE
// you appear to be an officer to all other germans/italians
/datum/faction/german/commander/italian
	icon_state = "italian_commander"
	title = "Italian Commander"
	team = TEAM_GE
// you appear to be a soviet soldier to all other sovivets
/datum/faction/soviet
	icon_state = "soviet_soldier"
	title = "Soviet Soldier"
	team = TEAM_RU

/datum/faction/soviet/base_type()
	return "/datum/faction/soviet"
// you appear to be an officer to all other soviets
/datum/faction/soviet/officer
	icon_state = "soviet_officer"
	title = "Soviet Officer"
	team = TEAM_RU
// you appear to be a soviet leader to all other soviets
/datum/faction/soviet/commander
	icon_state = "soviet_commander"
	title = "Kapitan"
	team = TEAM_RU


// you appear to be a jp soldier to all other jp
/datum/faction/japanese
	icon_state = "japanese_soldier"
	title = "Japanese Soldier"
	team = TEAM_JP

/datum/faction/japanese/base_type()
	return "/datum/faction/japanese"

/datum/faction/japanese/officer
	icon_state = "japanese_officer"
	title = "Japanese Officer"
	team = TEAM_JP

/datum/faction/japanese/commander
	icon_state = "japanese_commander"
	title = "Japanese Commander"
	team = TEAM_JP

// you appear to be a us soldier to all other us
/datum/faction/usa
	icon_state = "US_soldier"
	title = "US Soldier"
	team = TEAM_US

/datum/faction/usa/base_type()
	return "/datum/faction/usa"

/datum/faction/usa/officer
	icon_state = "US_officer"
	title = "US Officer"
	team = TEAM_US

/datum/faction/usa/commander
	icon_state = "US_commander"
	title = "US Commander"
	team = TEAM_US


// squads: both german and soviet use the same types. What squad you appear
// to be in, and to whom, depends on your true faction. Spies

/datum/faction/squad
	var/squad = null
	var/is_leader = FALSE
	var/number = "#1"
	var/actual_number = TRUE
	New(var/mob/living/carbon/human/H, var/datum/job/J)

		var/squadmsg = ""

		if (!is_leader)
			squadmsg = "<span class = 'danger'>You've been assigned to squad [squad].[istype(J, /datum/job/german) ? " Meet with the rest of your squad on train car [number]. " : " "]Examine people to see if they're in your squad, or if they're your squad leader."
		else
			squadmsg = "<span class = 'danger'>You are the [J.title] of squad [squad].[istype(J, /datum/job/german) ? " Meet with your squad on train car [number]. " : " "]Examine people to see if they're one of your soldats."

		squadmsg = replacetext(squadmsg, "<span class = 'danger'>", "")
		squadmsg = replacetext(squadmsg, "</span>", "")

	//	H.add_memory(squadmsg)

		..(H, J)

/datum/faction/squad/one
	icon_state = "squad_one"
	squad = "one"
	number = "#1"
	actual_number = TRUE
/datum/faction/squad/one/leader
	icon_state = "squad_one_leader"
	is_leader = TRUE

/datum/faction/squad/two
	icon_state = "squad_two"
	squad = "two"
	number = "#2"
	actual_number = 2
/datum/faction/squad/two/leader
	icon_state = "squad_two_leader"
	is_leader = TRUE

/datum/faction/squad/three
	icon_state = "squad_three"
	squad = "three"
	number = "#3"
	actual_number = 3
/datum/faction/squad/three/leader
	icon_state = "squad_three_leader"
	is_leader = TRUE

/datum/faction/squad/four
	icon_state = "squad_four"
	squad = "four"
	number = "#4"
	actual_number = 4
/datum/faction/squad/four/leader
	icon_state = "squad_four_leader"
	is_leader = TRUE

// spies use normal faction types

// CODE
/datum/faction/New(var/mob/living/carbon/human/H, var/datum/job/J)

	if (!H || !istype(H))
		return

	holder = H

	if (findtext("[type]", "leader"))
		if (istype(J, /datum/job/german))
			squad_leaders[GERMAN]++
		else if (istype(J, /datum/job/soviet))
			squad_leaders[SOVIET]++
		else if (istype(J, /datum/job/partisan))
			squad_leaders[PARTISAN]++
	else if (findtext("[type]", "officer"))
		if (istype(J, /datum/job/german))
			officers[GERMAN]++
		else if (istype(J, /datum/job/soviet))
			officers[SOVIET]++
		else if (istype(J, /datum/job/partisan))
			officers[PARTISAN]++
	else if (findtext("[type]", "commander"))
		if (istype(J, /datum/job/german))
			commanders[GERMAN]++
		else if (istype(J, /datum/job/soviet))
			commanders[SOVIET]++
		else if (istype(J, /datum/job/partisan))
			commanders[PARTISAN]++
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
		else if (istype(J, /datum/job/pirates))
			if ("[type]" == "/datum/faction/pirates")
				soldiers[PIRATES]++
			else if (findtext("[type]", "squad") && !src:is_leader)
				squad_members[PIRATES]++
		else if (istype(J, /datum/job/british))
			if ("[type]" == "/datum/faction/british")
				soldiers[BRITISH]++
			else if (findtext("[type]", "squad") && !src:is_leader)
				squad_members[BRITISH]++
	H.all_factions += src
	..()

/* HELPER FUNCTIONS */

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

/proc/isgermansquadmember_or_leader(var/mob/living/carbon/human/H)
	return (istype(H.original_job, /datum/job/german) && getsquad(H))

/proc/isgermansquadleader(var/mob/living/carbon/human/H)
	return (istype(H.original_job, /datum/job/german) && issquadleader(H))

/proc/issovietsquadmember_or_leader(var/mob/living/carbon/human/H)
	return (istype(H.original_job, /datum/job/soviet) && getsquad(H))

/proc/issovietsquadleader(var/mob/living/carbon/human/H)
	return (istype(H.original_job, /datum/job/soviet) && issquadleader(H))

/proc/isusasquadmember_or_leader(var/mob/living/carbon/human/H)
	return (istype(H.original_job, /datum/job/usa) && getsquad(H))

/proc/isusasquadleader(var/mob/living/carbon/human/H)
	return (istype(H.original_job, /datum/job/usa) && issquadleader(H))

/proc/isjapansquadmember_or_leader(var/mob/living/carbon/human/H)
	return (istype(H.original_job, /datum/job/japanese) && getsquad(H))

/proc/isjapansquadleader(var/mob/living/carbon/human/H)
	return (istype(H.original_job, /datum/job/japanese) && issquadleader(H))

/proc/sharesquads(var/mob/living/carbon/human/H, var/mob/living/carbon/human/HH)
	return (getsquad(H) && getsquad(H) == getsquad(HH))

/proc/isleader(var/mob/living/carbon/human/H, var/mob/living/carbon/human/HH)
	if (issquadleader(H) && issquadmember(HH) && getsquad(H) == getsquad(HH))
		return TRUE
	return FALSE