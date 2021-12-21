/datum/martial_art/boxing
	name = "Boxing"
	id = "boxing"
	New()
		..()
		help_verb_text = "<b>[name]</b>\n\
				<span class='notice'>HELP</span>: Nothing.\n\
				<span class='notice'>DISARM</span>: Pushes the target mob away.\n\
				<span class='notice'>GRAB</span>: Attempts to block punches or other disarmed attacks.\n\
				<span class='notice'>HARM</span>: Throws a punch at the target mob. Small chance to KO."
/datum/martial_art/boxing/disarm_act(mob/living/human/A, mob/living/human/D)
	to_chat(A, "<span class='warning'>Can't disarm while boxing!</span>")
	return TRUE

/datum/martial_art/boxing/grab_act(mob/living/human/A, mob/living/human/D)
	to_chat(A, "<span class='warning'>Can't grab while boxing!</span>")
	return TRUE

/datum/martial_art/boxing/harm_act(mob/living/human/A, mob/living/human/D)
	A.do_attack_animation(D)

	var/atk_verb = pick("left hook","right hook","straight punch")

	var/damage = rand(5, 8) + 1
	if(!damage)
		playsound(D.loc, 'sound/weapons/punchmiss.ogg', 25, TRUE, -1)
		D.visible_message("<span class='warning'>[A]'s [atk_verb] misses [D]!</span>", \
						"<span class='danger'>You avoid [A]'s [atk_verb]!</span>")
		to_chat(A, "<span class='warning'>Your [atk_verb] misses [D]!</span>")
		return FALSE


	var/obj/item/organ/external/affecting = D.get_bodypart(ran_zone(A.targeted_organ))
	var/armor_block = D.run_armor_check(affecting, "melee")

	playsound(D.loc, "swing_hit", 25, TRUE, -1)

	D.visible_message("<span class='danger'>[A] [atk_verb]ed [D]!</span>", \
					"<span class='userdanger'>You're [atk_verb]ed by [A]!</span>", "<span class='hear'>You hear a sickening sound of flesh hitting flesh!</span>")
	to_chat(A, "<span class='danger'>You [atk_verb]ed [D]!</span>")

	D.stats["stamina"][1] = max(0,D.stats["stamina"][1] - (0.5*0.45)/D.getStatCoeff("strength"))
	D.attack_log += "\[[time_stamp()]\] <font color='orange'>Punched (boxing) by [A.name] ([A.ckey])</font>"
	if(D.stats["stamina"][1] < 50 && istype(D.mind?.martial_art, /datum/martial_art/boxing))
		var/knockout_prob = D.stats["stamina"][1] + rand(-15,15)
		if((D.stat != DEAD) && prob(knockout_prob))
			D.visible_message("<span class='danger'>[A] knocks [D] out with a haymaker!</span>", \
							"<span class='userdanger'>You're knocked unconscious by [A]!</span>", "<span class='hear'>You hear a sickening sound of flesh hitting flesh!</span>")
			to_chat(A, "<span class='danger'>You knock [D] out with a haymaker!</span>")
			D.apply_effect(200,STUN,armor_block)
			D.SetSleeping(100)
			D.attack_log += "\[[time_stamp()]\] <font color='orange'>Knocked out (boxing) by [A.name] ([A.ckey])</font>"
	return TRUE
