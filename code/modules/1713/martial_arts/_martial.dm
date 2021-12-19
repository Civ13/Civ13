/// Martial arts attack requested but is not available, allow a check for a regular attack.
#define MARTIAL_ATTACK_INVALID -1

/// Martial arts attack happened but failed, do not allow a check for a regular attack.
#define MARTIAL_ATTACK_FAIL FALSE

/// Martial arts attack happened and succeeded, do not allow a check for a regular attack.
#define MARTIAL_ATTACK_SUCCESS TRUE

/// IF an object is weak against armor, this is the value that any present armor is multiplied by
#define ARMOR_WEAKENED_MULTIPLIER 2


/// Verb added to humans who learn the art of the sleeping carp.
/mob/living/human/verb/martial_arts_help()
	set name = "Check Intent Behavior"
	set desc = "Check what HELP, DISARM, GRAB and HARM intents do."
	set category = "IC"

	if (mind && mind.martial_art)
		to_chat(usr, mind.martial_art.help_verb_text)

/datum/martial_art
	var/name = "Default"
	var/id = ""
	var/streak = ""
	var/max_streak_length = 6
	var/current_target
	var/help_verb_text = "<b>Default Intents:</b>\n\
		<span class='notice'>HELP</span>: Hugs the target mob.\n\
		<span class='notice'>DISARM</span>: Attempts to disarm the target mob.\n\
		<span class='notice'>GRAB</span>: Attempts to grab the target mob.\n\
		<span class='notice'>HARM</span>: Punches the target mob."
	var/smashes_tables = FALSE //If the martial art smashes tables when performing table slams and head smashes
	var/datum/weakref/holder //owner of the martial art
	var/display_combos = FALSE //shows combo meter if true
	var/combo_timer = 6 SECONDS // period of time after which the combo streak is reset.

/datum/martial_art/proc/help_act(mob/living/human/A, mob/living/human/D)
	return MARTIAL_ATTACK_INVALID

/datum/martial_art/proc/disarm_act(mob/living/human/A, mob/living/human/D)
	return MARTIAL_ATTACK_INVALID

/datum/martial_art/proc/harm_act(mob/living/human/A, mob/living/human/D)
	return MARTIAL_ATTACK_INVALID

/datum/martial_art/proc/grab_act(mob/living/human/A, mob/living/human/D)
	return MARTIAL_ATTACK_INVALID

/datum/martial_art/proc/can_use(mob/living/L)
	return TRUE

/datum/martial_art/proc/add_to_streak(element, mob/living/D)
	if(D != current_target)
		reset_streak(D)
	streak = streak+element
	if(length(streak) > max_streak_length)
		streak = copytext(streak, 1 + length(streak[1]))

/datum/martial_art/proc/reset_streak(mob/living/new_target, update_icon = TRUE)
	current_target = new_target
	streak = ""
/datum/martial_art/proc/teach(mob/living/holder_living)
	if(!istype(holder_living) || !holder_living.mind)
		return FALSE
	holder_living.mind.martial_art = src
	holder = holder_living
	return TRUE

/datum/martial_art/proc/remove(mob/living/holder_living)
	if(!istype(holder_living) || !holder_living.mind || holder_living.mind.martial_art != src)
		return
	var/datum/martial_art/default = holder_living.mind.default_martial_art
	default.teach(holder_living)
	holder = null

