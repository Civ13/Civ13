#define STRONG_PUNCH_COMBO "HH"
#define LAUNCH_KICK_COMBO "HD"
#define DROP_KICK_COMBO "HG"

/datum/martial_art/the_sleeping_carp
	name = "The Sleeping Carp"
	id = "sleepingcarp"
	display_combos = TRUE
	help_verb_text = "<b><i>You retreat inward and recall the teachings of the Sleeping Carp...</i></b>\n\
	<span class='notice'>Gnashing Teeth</span>: Harm Harm. Deal additional damage every second (consecutive) punch!\n\
	<span class='notice'>Crashing Wave Kick</span>: Harm Disarm. Launch your opponent away from you with incredible force!\n\
	<span class='notice'>Keelhaul</span>: Harm Grab. Kick an opponent to the floor, knocking them down! If your opponent is already prone, this move will disarm them and deal additional stamina damage to them.\n\
	Also, you are more resilient against suffering wounds in combat, and your limbs cannot be dismembered. This grants you extra staying power during extended combat, especially against slashing and other bleeding weapons.\
	You are not invincible, however- while you may not suffer debilitating wounds often, you must still watch your health and appropriate medical supplies when possible for use during downtime.\
	In addition, your training has imbued you with a loathing of guns, and you can no longer use them.</span>"
/datum/martial_art/the_sleeping_carp/proc/check_streak(mob/living/human/A, mob/living/human/D)
	if(findtext(streak,STRONG_PUNCH_COMBO))
		streak = ""
		strongPunch(A,D)
		return TRUE
	if(findtext(streak,LAUNCH_KICK_COMBO))
		streak = ""
		launchKick(A,D)
		return TRUE
	if(findtext(streak,DROP_KICK_COMBO))
		streak = ""
		dropKick(A,D)
		return TRUE
	return FALSE

///Gnashing Teeth: Harm Harm, consistent 20 force punch on every second harm punch
/datum/martial_art/the_sleeping_carp/proc/strongPunch(mob/living/human/A, mob/living/human/D)
	///this var is so that the strong punch is always aiming for the body part the user is targeting and not trying to apply to the chest before deviating
	var/obj/item/organ/external/affecting = D.get_bodypart(ran_zone(A.targeted_organ))
	A.do_attack_animation(D, ATTACK_EFFECT_PUNCH)
	var/atk_verb = pick("precisely kick", "brutally chop", "cleanly hit", "viciously slam")
	D.visible_message("<span class='danger'>[A] [atk_verb]s [D]!</span>", \
					"<span class='userdanger'>[A] [atk_verb]s you!</span>", null, null, A)
	to_chat(A, "<span class='danger'>You [atk_verb] [D]!</span>")
	playsound(get_turf(D), 'sound/weapons/punch1.ogg', 25, TRUE, -1)
	D.attack_log += "\[[time_stamp()]\] <font color='orange'>Strong punched (Sleeping Carp) by [A.name] ([A.ckey])</font>"
	D.apply_damage(20, A.get_attack_type(), affecting)
	return

///Crashing Wave Kick: Harm Disarm combo, throws people seven tiles backwards
/datum/martial_art/the_sleeping_carp/proc/launchKick(mob/living/human/A, mob/living/human/D)
	A.do_attack_animation(D, ATTACK_EFFECT_KICK)
	D.visible_message("<span class='warning'>[A] kicks [D] square in the chest, sending them flying!</span>", \
					"<span class='userdanger'>You are kicked square in the chest by [A], sending you flying!</span>", "<span class='hear'>You hear a sickening sound of flesh hitting flesh!</span>")
	playsound(get_turf(A), 'sound/weapons/kick.ogg', 50, TRUE, -1)
	var/atom/throw_target = get_edge_target_turf(D, A.dir)
	D.throw_at(throw_target, 7, 14, A)
	D.apply_damage(15, A.get_attack_type(), BODY_ZONE_CHEST, wound_bonus = CANT_WOUND)
	D.attack_log += "\[[time_stamp()]\] <font color='orange'>Launchkicked (Sleeping Carp) by [A.name] ([A.ckey])</font>"
	return

///Keelhaul: Harm Grab combo, knocks people down, deals stamina damage while they're on the floor
/datum/martial_art/the_sleeping_carp/proc/dropKick(mob/living/human/A, mob/living/human/D)
	A.do_attack_animation(D, ATTACK_EFFECT_KICK)
	playsound(get_turf(A), 'sound/weapons/kick.ogg', 50, TRUE, -1)
	if(D.body_position == STANDING_UP)
		D.apply_damage(10, A.get_attack_type(), BODY_ZONE_HEAD, wound_bonus = CANT_WOUND)
		D.apply_damage(40, STAMINA, BODY_ZONE_HEAD)
		D.Knockdown(40)
		D.visible_message("<span class='warning'>[A] kicks [D] in the head, sending them face first into the floor!</span>", \
					"<span class='userdanger'>You are kicked in the head by [A], sending you crashing to the floor!</span>", "<span class='hear'>You hear a sickening sound of flesh hitting flesh!</span>")
	else
		D.apply_damage(5, A.get_attack_type(), BODY_ZONE_HEAD, wound_bonus = CANT_WOUND)
		D.apply_damage(40, STAMINA, BODY_ZONE_HEAD)
		D.drop_all_held_items()
		D.visible_message("<span class='warning'>[A] kicks [D] in the head!</span>", \
					"<span class='userdanger'>You are kicked in the head by [A]!</span>", "<span class='hear'>You hear a sickening sound of flesh hitting flesh!</span>")
	D.attack_log += "\[[time_stamp()]\] <font color='orange'>Dropkicked (Sleeping Carp) by [A.name] ([A.ckey])</font>"
	return

/datum/martial_art/the_sleeping_carp/grab_act(mob/living/human/A, mob/living/human/D)
	add_to_streak("G",D)
	if(check_streak(A,D))
		return TRUE
	D.attack_log += "\[[time_stamp()]\] <font color='orange'>Grabbed (Sleeping Carp) by [A.name] ([A.ckey])</font>"
	return ..()

/datum/martial_art/the_sleeping_carp/harm_act(mob/living/human/A, mob/living/human/D)
	add_to_streak("H",D)
	if(check_streak(A,D))
		return TRUE
	var/obj/item/organ/external/affecting = D.get_bodypart(ran_zone(A.targeted_organ))
	A.do_attack_animation(D, ATTACK_EFFECT_PUNCH)
	var/atk_verb = pick("kick", "chop", "hit", "slam")
	D.visible_message("<span class='danger'>[A] [atk_verb]s [D]!</span>", \
					"<span class='userdanger'>[A] [atk_verb]s you!</span>", null, null, A)
	to_chat(A, "<span class='danger'>You [atk_verb] [D]!</span>")
	D.apply_damage(rand(10,15), BRUTE, affecting, wound_bonus = CANT_WOUND)
	playsound(get_turf(D), 'sound/weapons/punch1.ogg', 25, TRUE, -1)
	D.attack_log += "\[[time_stamp()]\] <font color='orange'>Punched (Sleeping Carp) by [A.name] ([A.ckey])</font>"
	return TRUE

/datum/martial_art/the_sleeping_carp/disarm_act(mob/living/human/A, mob/living/human/D)
	add_to_streak("D",D)
	if(check_streak(A,D))
		return TRUE
		D.attack_log += "\[[time_stamp()]\] <font color='orange'>Disarmed (Sleeping Carp) by [A.name] ([A.ckey])</font>"
	return ..()
