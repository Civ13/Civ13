/mob/living
	see_in_dark = 2
	see_invisible = SEE_INVISIBLE_LIVING

	//Health and life related vars
	var/maxHealth = 100 //Maximum health that should be possible.
	var/health = 100 	//A mob's health

	var/inventory_shown = TRUE

	//Damage related vars, NOTE: THESE SHOULD ONLY BE MODIFIED BY PROCS
	var/bruteloss = 0.0	//Brutal damage caused by brute force (punching, being clubbed by a toolbox ect... this also accounts for pressure damage)
	var/oxyloss = 0.0	//Oxygen depravation damage (no air in lungs)
	var/toxloss = 0.0	//Toxic damage caused by being poisoned or radiated
	var/fireloss = 0.0	//Burn damage caused by being way too hot, too cold or burnt.
	var/cloneloss = FALSE	//Damage caused by being cloned or ejected from the cloner early. slimes also deal cloneloss damage to victims
	var/brainloss = FALSE	//'Retardation' damage caused by someone hitting you in the head with a bible or being infected with brainrot.
	var/halloss = FALSE		//Hallucination damage. 'Fake' damage obtained through hallucinating or the holodeck. Sleeping should cause it to wear off.
	var/hallucination = FALSE //Directly affects how long a mob will hallucinate for
	var/list/atom/hallucinations = list() //A list of hallucinated people that try to attack the mob. See /obj/effect/fake_attacker in hallucinations.dm

	var/last_special = FALSE //Used by the resist verb, likely used to prevent players from bypassing next_move by logging in/out.

	var/t_plasma = null
	var/t_oxygen = null
	var/t_sl_gas = null
	var/t_n2 = null

	var/now_pushing = null
	var/mob_bump_flag = FALSE
	var/mob_swap_flags = FALSE
	var/mob_push_flags = FALSE
	var/mob_always_swap = FALSE

	var/mob/living/cameraFollow = null
	var/list/datum/action/actions = list()

	var/tod = null // Time of death
	var/update_slimes = TRUE
	var/silent = null 		// Can't talk. Value goes down every life proc.
	var/on_fire = FALSE //The "Are we on fire?" var
	var/fire_stacks

	var/failed_last_breath = FALSE //This is used to determine if the mob failed a breath. If they did fail a brath, they will attempt to breathe each tick, otherwise just once per 4 ticks.
	var/possession_candidate // Can be possessed by ghosts if unplayed.

	var/eye_blind = null	//Carbon
	var/eye_blurry = null	//Carbon
	var/ear_damage = null	//Carbon
	var/stuttering = null	//Carbon
	var/slurring = null		//Carbon
	var/lisp = null		//Carbon

	var/takes_less_damage = FALSE

	var/tactic = "charge"
	var/life_forced = FALSE
	var/datum/language/default_language
