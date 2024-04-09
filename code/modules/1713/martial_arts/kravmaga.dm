/datum/martial_art/krav_maga
	name = "Krav Maga"
	id = "kravmaga"
	var/datum/action/neck_chop/neckchop = new/datum/action/neck_chop()
	var/datum/action/leg_sweep/legsweep = new/datum/action/leg_sweep()
	var/datum/action/lung_punch/lungpunch = new/datum/action/lung_punch()

/datum/action/neck_chop
	name = "Neck Chop - Injures the neck, stopping the victim from speaking for a while."
	button_icon_state = "neckchop"

/datum/action/neck_chop/Trigger()
	if(owner.incapacitated())
		to_chat(owner, "<span class='warning'>You can't use [name] while you're incapacitated.</span>")
		return
	if (owner.mind.martial_art.streak == "neck_chop")
		owner.visible_message("<span class='danger'>[owner] assumes a neutral stance.</span>", "<b><i>Your next attack is cleared.</i></b>")
		owner.mind.martial_art.streak = ""
	else
		owner.visible_message("<span class='danger'>[owner] assumes the Neck Chop stance!</span>", "<b><i>Your next attack will be a Neck Chop.</i></b>")
		owner.mind.martial_art.streak = "neck_chop"

/datum/action/leg_sweep
	name = "Leg Sweep - Trips the victim, knocking them down for a brief moment."
	button_icon_state = "legsweep"

/datum/action/leg_sweep/Trigger()
	if(owner.incapacitated())
		to_chat(owner, "<span class='warning'>You can't use [name] while you're incapacitated.</span>")
		return
	if (owner.mind.martial_art.streak == "leg_sweep")
		owner.visible_message("<span class='danger'>[owner] assumes a neutral stance.</span>", "<b><i>Your next attack is cleared.</i></b>")
		owner.mind.martial_art.streak = ""
	else
		owner.visible_message("<span class='danger'>[owner] assumes the Leg Sweep stance!</span>", "<b><i>Your next attack will be a Leg Sweep.</i></b>")
		owner.mind.martial_art.streak = "leg_sweep"

/datum/action/lung_punch//referred to internally as 'quick choke'
	name = "Lung Punch - Delivers a strong punch just above the victim's abdomen, constraining the lungs. The victim will be unable to breathe for a short time."
	button_icon_state = "lungpunch"

/datum/action/lung_punch/Trigger()
	if(owner.incapacitated())
		to_chat(owner, "<span class='warning'>You can't use [name] while you're incapacitated.</span>")
		return
	if (owner.mind.martial_art.streak == "quick_choke")
		owner.visible_message("<span class='danger'>[owner] assumes a neutral stance.</span>", "<b><i>Your next attack is cleared.</i></b>")
		owner.mind.martial_art.streak = ""
	else
		owner.visible_message("<span class='danger'>[owner] assumes the Lung Punch stance!</span>", "<b><i>Your next attack will be a Lung Punch.</i></b>")
		owner.mind.martial_art.streak = "quick_choke"//internal name for lung punch

/datum/martial_art/krav_maga/teach(mob/living/owner, make_temporary=FALSE)
	if(..())
		to_chat(owner, "<span class='userdanger'>You know the arts of [name]!</span>")
		to_chat(owner, "<span class='danger'>Place your cursor over a move at the top of the screen to see what it does.</span>")
		neckchop.Grant(owner)
		legsweep.Grant(owner)
		lungpunch.Grant(owner)

/datum/martial_art/krav_maga/on_remove(mob/living/owner)
	to_chat(owner, "<span class='userdanger'>You suddenly forget the arts of [name]...</span>")
	neckchop.Remove(owner)
	legsweep.Remove(owner)
	lungpunch.Remove(owner)

/datum/martial_art/krav_maga/proc/check_streak(mob/living/human/A, mob/living/human/D)
	switch(streak)
		if("neck_chop")
			streak = ""
			neck_chop(A,D)
			return TRUE
		if("leg_sweep")
			streak = ""
			leg_sweep(A,D)
			return TRUE
		if("quick_choke")//is actually lung punch
			streak = ""
			quick_choke(A,D)
			return TRUE
	return FALSE

/datum/martial_art/krav_maga/proc/leg_sweep(mob/living/human/A, mob/living/human/D)
	if(D.stat || D.paralysis > 0)
		return FALSE
	var/obj/item/organ/external/affecting = D.get_bodypart(BODY_ZONE_CHEST)
	var/armor_block = D.run_armor_check(affecting, "melee")
	D.visible_message("<span class='warning'>[A] leg sweeps [D]!</span>", \
					"<span class='userdanger'>Your legs are sweeped by [A]!</span>", "<span class='hear'>You hear a sickening sound of flesh hitting flesh!</span>", null, A)
	to_chat(A, "<span class='danger'>You leg sweep [D]!</span>")
	playsound(get_turf(A), 'sound/weapons/kick.ogg', 50, TRUE, -1)
	D.apply_damage(rand(20,30), STAMINA, affecting, armor_block)
	D.Knockdown(60)
	D.attack_log += "\[[time_stamp()]\] <font color='orange'>Leg sweeped by [A.name] ([A.ckey])</font>"
	return TRUE

/datum/martial_art/krav_maga/proc/quick_choke(mob/living/human/A, mob/living/human/D)//is actually lung punch
	D.visible_message("<span class='warning'>[A] pounds [D] on the chest!</span>", \
					"<span class='userdanger'>Your chest is slammed by [A]! You can't breathe!</span>", "<span class='hear'>You hear a sickening sound of flesh hitting flesh!</span>")
	to_chat(A, "<span class='danger'>You pound [D] on the chest!</span>")
	playsound(get_turf(A), "punch_sound", 50, TRUE, -1)
	if(D.losebreath <= 10)
		D.losebreath = clamp(D.losebreath + 5, 0, 10)
	D.adjustOxyLoss(10)
	D.attack_log += "\[[time_stamp()]\] <font color='orange'>Quickchoked by [A.name] ([A.ckey])</font>"
	return TRUE

/datum/martial_art/krav_maga/proc/neck_chop(mob/living/human/A, mob/living/human/D)
	D.visible_message("<span class='warning'>[A] karate chops [D]'s neck!</span>", \
					"<span class='userdanger'>Your neck is karate chopped by [A], rendering you unable to speak!</span>", "<span class='hear'>You hear a sickening sound of flesh hitting flesh!</span>")
	to_chat(A, "<span class='danger'>You karate chop [D]'s neck, rendering [D.p_them()] unable to speak!</span>")
	playsound(get_turf(A), 'sound/effects/hit_punch.ogg', 50, TRUE, -1)
	D.apply_damage(5, A.get_attack_type())
	if (ishuman(D))
		var/mob/living/human/human_defender = D
		if(human_defender.silent <= 10)
			human_defender.silent = clamp(human_defender.silent + 10, 0, 10)
	D.attack_log += "\[[time_stamp()]\] <font color='orange'>Neck chopped by [A.name] ([A.ckey])</font>"
	return TRUE

/datum/martial_art/krav_maga/grab_act(mob/living/human/A, mob/living/human/D)
	if(check_streak(A,D))
		return TRUE
	D.attack_log += "\[[time_stamp()]\] <font color='orange'>Grabbed (Krav Maga) by [A.name] ([A.ckey])</font>"
	..()

/datum/martial_art/krav_maga/harm_act(mob/living/human/A, mob/living/human/D)
	if(check_streak(A,D))
		return TRUE
	D.attack_log += "\[[time_stamp()]\] <font color='orange'>Punched by [A.name] ([A.ckey])</font>"
	var/obj/item/organ/external/affecting = D.get_bodypart(ran_zone(A.targeted_organ))
	var/armor_block = D.run_armor_check(affecting, "melee")
	var/picked_hit_type = pick("punch", "kick")
	var/bonus_damage = 0
	if(D.body_position == LYING_DOWN)
		bonus_damage += 5
		picked_hit_type = "stomp"
	D.apply_damage(rand(5,10) + bonus_damage, A.get_attack_type(), affecting, armor_block)
	if(picked_hit_type == "kick" || picked_hit_type == "stomp")
		A.do_attack_animation(D, ATTACK_EFFECT_KICK)
		playsound(get_turf(D), 'sound/weapons/kick.ogg', 50, TRUE, -1)
	else
		A.do_attack_animation(D, ATTACK_EFFECT_PUNCH)
		playsound(get_turf(D), 'sound/effects/hit_punch.ogg', 50, TRUE, -1)
	D.visible_message("<span class='danger'>[A] [picked_hit_type]s [D]!</span>", \
					"<span class='userdanger'>You're [picked_hit_type]ed by [A]!</span>", "<span class='hear'>You hear a sickening sound of flesh hitting flesh!</span>")
	to_chat(A, "<span class='danger'>You [picked_hit_type] [D]!</span>")
		D.attack_log += "\[[time_stamp()]\] <font color='orange'>[picked_hit_type] by [A.name] ([A.ckey])</font>"
	return TRUE

/datum/martial_art/krav_maga/disarm_act(mob/living/human/A, mob/living/human/D)
	if(check_streak(A,D))
		return TRUE
	var/obj/item/organ/external/affecting = D.get_bodypart(ran_zone(A.targeted_organ))
	var/armor_block = D.run_armor_check(affecting, "melee")
	if(D.body_position == STANDING_UP)
		D.visible_message("<span class='danger'>[A] reprimands [D]!</span>", \
					"<span class='userdanger'>You're slapped by [A]!</span>", "<span class='hear'>You hear a sickening sound of flesh hitting flesh!</span>")
		to_chat(A, "<span class='danger'>You jab [D]!</span>")
		A.do_attack_animation(D, ATTACK_EFFECT_PUNCH)
		playsound(D, 'sound/effects/hit_punch.ogg', 50, TRUE, -1)
		D.apply_damage(rand(5,10), STAMINA, affecting, armor_block)
		D.attack_log += "\[[time_stamp()]\] <font color='orange'>Punched nonlethally by [A.name] ([A.ckey])</font>"
	if(D.body_position == LYING_DOWN)
		D.visible_message("<span class='danger'>[A] reprimands [D]!</span>", \
					"<span class='userdanger'>You're manhandled by [A]!</span>", "<span class='hear'>You hear a sickening sound of flesh hitting flesh!</span>")
		to_chat(A, "<span class='danger'>You stomp [D]!</span>")
		A.do_attack_animation(D, ATTACK_EFFECT_KICK)
		playsound(D, 'sound/effects/hit_punch.ogg', 50, TRUE, -1)
		D.apply_damage(rand(10,15), STAMINA, affecting, armor_block)
		D.attack_log += "\[[time_stamp()]\] <font color='orange'>Stomped nonlethally by [A.name] ([A.ckey])</font>"
	if(prob(D.getStaminaLoss()))
		D.visible_message("<span class='warning'>[D] sputters and recoils in pain!</span>", "<span class='userdanger'>You recoil in pain as you are jabbed in a nerve!</span>")
		D.drop_all_held_items()
	return TRUE
