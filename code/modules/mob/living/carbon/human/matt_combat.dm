//Commented out debugging shit.
/*
/mob/living/carbon/human/verb/toggle_combat_mode()
	set name = "Toggle Combat Mode"
	set category = "Combat"

	if(combat_mode)
		combat_mode = 0
		to_chat(src, "You toggle off combat mode.")
	else
		combat_mode = 1
		to_chat(src, "You toggle on combat mode.")
*/

//Going here till I find a better place for it.

/mob/living/proc/attempt_dodge()//Handle parry is an object proc and it's, its own thing.
	if(combat_mode && (defense_intent == I_DODGE) && !lying)//Todo, make use of the check_shield_arc proc to make sure you can't dodge from behind.
		var/mob/living/carbon/human/H_user = src
		if(prob(min(25 * H_user.getStatCoeff("dexterity"), 75)))
			do_dodge()
			return	1

/mob/living/proc/do_dodge()
	var/lol = pick(cardinal)//get a direction.
	playsound(loc, 'sound/weapons/punchmiss.ogg', 80, 1)//play a sound
	step(src,lol)//move them
	var/mob/living/carbon/human/H = src
	H.adaptStat("dexterity", 1)
	visible_message("<b><big>[src.name] dodges out of the way!!</big></b>")//send a message
	//be on our way