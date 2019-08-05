/*
Contains most of the procs that are called when a mob is attacked by something

bullet_act

*/

/mob/living/carbon/human/attackby(obj/item/weapon/W as obj, mob/user as mob)

	if (stat != DEAD)
		return ..(W, user)

	if (!istype(W) || !W.sharp)
		return ..(W, user)

	var/grabbed_by_user = FALSE
	for (var/obj/item/weapon/grab/G in grabbed_by)
		if (G.assailant == user && G.state >= GRAB_NECK)
			grabbed_by_user = TRUE
	if (user.a_intent == I_HELP && gender == MALE && istype(W,/obj/item/weapon/material/kitchen/utensil/knife/circumcision))
		if (circumcised)
			user << "<span class = 'notice'>[src]is already circumcised!</span>"
			return
		else
			visible_message("<span class = 'notice'>[user] starts to circumcise [src]...</span>")
			if (do_after(user, 90, src) && !circumcised)
				visible_message("<span class = 'notice'>[user] successfully circumcises [src].</span>")
				circumcised = TRUE
				return
	if (W.sharp && !istype(W, /obj/item/weapon/reagent_containers) && user.a_intent == I_HURT && !grabbed_by_user && (istype(W,/obj/item/weapon/material/knife) || istype(W,/obj/item/weapon/material/kitchen/utensil/knife)))
		if (stat == DEAD)
			var/mob/living/carbon/human/H = user
			if (istype(H))
				user.visible_message("<span class = 'notice'>[user] starts to butcher [src].</span>")
				if (do_after(user, 30, src))
					user.visible_message("<span class = 'notice'>[user] butchers [src] into a few meat slabs.</span>")
					for (var/v in 1 to rand(5,7))
						var/obj/item/weapon/reagent_containers/food/snacks/meat/human/meat = new/obj/item/weapon/reagent_containers/food/snacks/meat/human(get_turf(src))
						meat.name = "human meat"
					if (orc)
						var/obj/item/stack/material/orcpelt/HP = new/obj/item/stack/material/orcpelt(get_turf(src))
						HP.amount = 3
					else if (gorillaman)
						var/obj/item/stack/material/gorillapelt/HP = new/obj/item/stack/material/gorillapelt(get_turf(src))
						HP.amount = 3
					else if (ant || crab)
						var/obj/item/stack/material/chitin/HP = new/obj/item/stack/material/chitin(get_turf(src))
						HP.amount = 2
					else if (wolfman)
						var/obj/item/stack/material/wolfpelt/HP = new/obj/item/stack/material/wolfpelt(get_turf(src))
						HP.amount = 3
					else
						var/obj/item/stack/material/humanpelt/HP = new/obj/item/stack/material/humanpelt(get_turf(src))
						HP.amount = 3
					var/obj/item/stack/material/bone/bonedrop = new/obj/item/stack/material/bone(get_turf(src))
					bonedrop.amount = 2
					if (istype(user, /mob/living/carbon/human))
						var/mob/living/carbon/human/HM = user
						HM.adaptStat("medical", 1)
					for (var/obj/item/clothing/I in contents)
						drop_from_inventory(I)
					crush()
					qdel(src)
	else
		return ..(W, user)

/mob/living/carbon/human/bullet_act(var/obj/item/projectile/P, var/def_zone)
	if (P.damage == 0)
		return // fix for strange bug

	if (def_zone == "mouth")
		if (wear_mask && istype(wear_mask, /obj/item/weapon/grenade))
			var/obj/item/weapon/grenade/G = wear_mask
			if (!G.active)
				visible_message("<span class = 'danger'>The grenade in [src]'s mouth goes off!</span>")
				G.active = TRUE
				G.prime()

	// if we hit a client who's not on our team, increase our stats
	if (client && stat == CONSCIOUS && P.firer && ishuman(P.firer) && P.firedfrom)
		var/mob/living/carbon/human/H = P.firer
		if (!H.original_job || !original_job || H.original_job.base_type_flag() != original_job.base_type_flag())
			switch (P.firedfrom.gun_type)
				if (GUN_TYPE_RIFLE)
					H.adaptStat("rifle", 1)
				if (GUN_TYPE_PISTOL)
					H.adaptStat("pistol", 1)
				if (GUN_TYPE_BOW)
					H.adaptStat("bows", 1)
				if (GUN_TYPE_MG)
					H.adaptStat("mg", 1)

	def_zone = check_zone(def_zone)


	if (!has_organ(def_zone))
		return PROJECTILE_FORCE_MISS //if they don't have the organ in question then the projectile just passes by.

	var/obj/item/organ/external/organ = get_organ()

	//Shields
	var/shield_check = check_shields(P.damage*5, P, null, def_zone, "the [P.name]")

	if (istype(l_hand, /obj/item/weapon/shield) || istype(r_hand, /obj/item/weapon/shield))
		var/obj/item/weapon/shield/SH
		if (istype(l_hand, /obj/item/weapon/shield))
			SH = l_hand
		else
			SH = r_hand
		if (istype(P, /obj/item/projectile/arrow/arrow))
			if (prob(min(SH.base_block_chance*2,92)))
				visible_message("<span class = 'warning'>[src] blocks the arrow with the [SH.name]!</span>")
				P.blockedhit = TRUE
				SH.health -= 2
				return

	if (shield_check)
		if (shield_check < 0)
			return shield_check
		else
			P.on_hit(src, 2, def_zone)
			return 2
	else
		/* bullet grazing is affected by two factors now:
		 * from most to least important, these are:
		   * 1. is the target moving while being shot? Modified by distance
		   * 2. randomness
		*/
		if (P && P.starting)
			var/distcheck = max(abs(P.starting.x - x), abs(P.starting.y - y))

			if (distcheck > 2) // not PB range
				if (!P.execution)

					// shooting a moving target from 19 tiles away (new max scope range) has a 72% graze chance
					// this means if snipers want to hit people they need to shoot at still targets
					// shooting at someone from <= 7 tiles away has no graze chance - Kachnov

					var/graze_chance_multiplier = 5
					if (list("head", "mouth", "eyes").Find(def_zone))
						++graze_chance_multiplier
					graze_chance_multiplier += 1

					if (lastMovedRecently(accuracy_check = TRUE))
						if (prob(graze_chance_multiplier * max(distcheck - 7, 0)))
							visible_message("<span class = 'warning'>[src] is just grazed by the bullet!</span>")
							adjustBruteLoss(pick(14,15))
							P.useless = TRUE
							qdel(P)
							return

		// get knocked back once in a while

		var/KD_check = FALSE

		for (var/obj/structure/noose/N in get_turf(src))
			if (N.hanging == src)
				KD_check = TRUE
				break

		for (var/obj/structure/bed/B in get_turf(src))
			if (B.buckled_mob == src)
				KD_check = TRUE
				break

		if (prob(P.KD_chance/2) && !KD_check)
			SpinAnimation(5,1)
			// P.firer_original_dir is more accurate, since P.dir is never explicitly set? - Kachnov
			var/turf/behind = get_step(src, P.firer_original_dir ? P.firer_original_dir : P.dir)
			if (behind)
				if (behind.density || (locate(/obj/structure) in behind) || (locate(/obj/covers) in behind))
					var/turf/slammed_into = behind
					if (!slammed_into.density)
						for (var/obj/structure/S in slammed_into.contents)
							if (S.density)
								slammed_into = S
								break
						for (var/obj/covers/CC in slammed_into.contents)
							if (CC.density)
								slammed_into = CC
								break
					if (slammed_into.density)
						spawn (1)
							visible_message("<span class = 'danger'>[src] flies back from the force of the blast and slams into \the [slammed_into]!</span>")
						Weaken(3)
						adjustBruteLoss(rand(20,30))
						if (client)
							shake_camera(src, rand(2,3), rand(2,3))
						playsound(get_turf(src), 'sound/effects/gore/fallsmash.ogg', 100, TRUE)
						for (var/obj/structure/window/W in get_turf(slammed_into))
							W.shatter()
				else
					if (!map || !map.check_caribbean_block(src, behind))
						forceMove(behind)
						spawn (1)
							visible_message("<span class = 'danger'>[src] flies back from the force of the blast!</span>")

		// get weakened too
		if (prob(P.KD_chance*0.5))
			Weaken(2)
			stats["stamina"][1] = max(stats["stamina"][1] - 50, 0)
			if (client)
				shake_camera(src, rand(2,3), rand(2,3))

	//Shrapnel
	if (P.can_embed())
		var/armor = getarmor_organ(organ, "gun")
		if (prob(20 + max(P.damage - armor, -10)))
			var/obj/item/weapon/material/shard/shrapnel/SP = new()
			SP.name = (P.name != "shrapnel")? "[P.name] shrapnel" : "shrapnel"
			SP.desc = "[SP.desc] It looks like it was fired from [P.shot_from]."
			SP.loc = organ
			organ.embed(SP)

	if (P.gibs)
		gib()
	else if (P.crushes)
		crush()
	if (istype(P, /obj/item/projectile/arrow/arrow/poisonous))
		//yeah, he is fucked
		apply_damage(15, BRUTE, def_zone)
		spawn(350)
			apply_damage(30, TOX, def_zone)
			eye_blurry += 20
			src << "<span class='danger'><big>You start to feel numb...</big></span>"
			spawn(300)
				eye_blurry += 20
				adjustOxyLoss(10)
				adjustBrainLoss(10)
				src << "<span class='danger'><big>You feel numb... You can barely feel your legs and arms!</big></span>"
				spawn(300)
					Weaken(30)
					adjustOxyLoss(20)
					adjustBrainLoss(20)
					eye_blurry += 30
					src << "<span class='danger'><big>You start losing control of your muscles...</big></span>"
					spawn(300)
						Paralyse(60)
					spawn(500)
						adjustBrainLoss(40)
						adjustOxyLoss(40)
						Paralyse(60)
						eye_blurry += 50
						src << "<span class='danger'><big>You fade out...</big></span>"

	if (istype(P, /obj/item/projectile/arrow/arrow/fire))
		if (prob(5))
			fire_stacks += 1
		IgniteMob()
	..(P, def_zone)
	instadeath_check()
	spawn (0.01)
		qdel(P)

/mob/living/carbon/human/stun_effect_act(var/stun_amount, var/agony_amount, var/def_zone)
	var/obj/item/organ/external/affected = get_organ(check_zone(def_zone))
	var/siemens_coeff = get_siemens_coefficient_organ(affected)
	stun_amount *= siemens_coeff
	agony_amount *= siemens_coeff

	switch (def_zone)
		if ("head")
			agony_amount *= 1.50
		if ("l_hand", "r_hand")
			var/c_hand
			if (def_zone == "l_hand")
				c_hand = l_hand
			else
				c_hand = r_hand

			if (c_hand && (stun_amount || agony_amount > 10))
				msg_admin_attack("[name] ([ckey]) was disarmed by a stun effect")

				drop_from_inventory(c_hand)
			else
				var/emote_scream = pick("screams in pain and ", "lets out a sharp cry and ", "cries out and ")
				emote("me", TRUE, "[(species && species.flags & NO_PAIN) ? "" : emote_scream ]drops what they were holding in their [affected.name]!")

	..(stun_amount, agony_amount, def_zone)

/mob/living/carbon/human/getarmor(var/def_zone, var/type)
	var/armorval = FALSE
	var/total = FALSE

	if (def_zone)
		if (isorgan(def_zone))
			return getarmor_organ(def_zone, type)
		var/obj/item/organ/external/affecting = get_organ(def_zone)
		if (affecting)
			return getarmor_organ(affecting, type)
		//If a specific bodypart is targetted, check how that bodypart is protected and return the value.

	//If you don't specify a bodypart, it checks ALL your bodyparts for protection, and averages out the values
	for (var/organ_name in organs_by_name)
		if (organ_name in organ_rel_size)
			var/obj/item/organ/external/organ = organs_by_name[organ_name]
			if (organ)
				var/weight = organ_rel_size[organ_name]
				armorval += getarmor_organ(organ, type) * weight
				total += weight
	return (armorval/max(total, TRUE))

//this proc returns the Siemens coefficient of electrical resistivity for a particular external organ.
/mob/living/carbon/human/proc/get_siemens_coefficient_organ(var/obj/item/organ/external/def_zone)
	if (!def_zone)
		return 1.0

	var/siemens_coefficient = species.siemens_coefficient

	var/list/clothing_items = list(head, wear_mask, wear_suit, w_uniform, gloves, shoes) // What all are we checking?
	for (var/obj/item/clothing/C in clothing_items)
		if (istype(C) && (C.body_parts_covered & def_zone.body_part)) // Is that body part being targeted covered?
			siemens_coefficient *= C.siemens_coefficient

	return siemens_coefficient

//this proc returns the armor value for a particular external organ.
/mob/living/carbon/human/proc/getarmor_organ(var/obj/item/organ/external/def_zone, var/type)
	if (!type || !def_zone) return FALSE
	var/protection = FALSE
	if (ant)
		protection += 25
	else if (crab)
		protection += 50
	var/list/protective_gear = list(head, wear_mask, wear_suit, w_uniform, gloves, shoes)
	for (var/gear in protective_gear)
		if (gear && istype(gear ,/obj/item/clothing))
			var/obj/item/clothing/C = gear
			if (istype(C) && C.body_parts_covered & def_zone.body_part)
				protection += C.armor[type]
			if (C.accessories.len)
				for (var/obj/item/clothing/accessory/AC in C.accessories)
					if (AC.body_parts_covered & def_zone.body_part)
						protection += AC.armor[type]
						if (istype(AC, /obj/item/clothing/accessory/armor/coldwar/plates))
							var/obj/item/clothing/accessory/armor/coldwar/plates/ACP = AC
							for (var/obj/item/weapon/armorplates/plt in ACP.hold)
								if (type == "melee" || type == "arrow" || type == "gun")
									protection += 10
	return protection

/mob/living/carbon/human/proc/damage_armor(var/obj/item/organ/external/def_zone, var/dmg = 0)
	if (!dmg || !def_zone) return FALSE
	var/list/protective_gear = list(head, wear_mask, wear_suit, w_uniform, gloves, shoes)
	var/obj/item/organ/external/affecting = get_organ(def_zone)
	if (!affecting)
		return
	for (var/gear in protective_gear)
		if (gear && istype(gear ,/obj/item/clothing))
			var/obj/item/clothing/C = gear
			if (istype(C) && C.body_parts_covered & affecting.body_part)
				C.health -= dmg
				C.check_health()
			if (C.accessories.len)
				for (var/obj/item/clothing/accessory/AC in C.accessories)
					if (AC.body_parts_covered & affecting.body_part)
						AC.health -= dmg
						AC.check_health()
	return TRUE
/mob/living/carbon/human/proc/check_head_coverage()
	var/list/body_parts = list(head, wear_mask, wear_suit, w_uniform)
	for (var/bp in body_parts)
		if (!bp)	continue
		if (bp && istype(bp ,/obj/item/clothing))
			var/obj/item/clothing/C = bp
			if (C.body_parts_covered & HEAD)
				return TRUE
	return FALSE

//Used to check if they can be fed food/drinks/pills
/mob/living/carbon/human/proc/check_mouth_coverage()
	var/list/protective_gear = list(head, wear_mask, wear_suit, w_uniform)
	for (var/obj/item/gear in protective_gear)
		if (istype(gear) && (gear.body_parts_covered & FACE) && !(gear.item_flags & FLEXIBLEMATERIAL))
			return gear
	return null

/mob/living/carbon/human/proc/check_shields(var/damage = FALSE, var/atom/damage_source = null, var/mob/attacker = null, var/def_zone = null, var/attack_text = "the attack")
	for (var/obj/item/shield in list(l_hand, r_hand, wear_suit))
		if (!shield) continue
		. = shield.handle_shield(src, damage, damage_source, attacker, def_zone, attack_text)
		if (.) return
	return FALSE

/mob/living/carbon/human/resolve_item_attack(obj/item/I, mob/living/user, var/target_zone)
	if (check_attack_throat(I, user))
		return null

	if (user == src) // Attacking yourself can't miss
		return target_zone

	var/hit_zone = get_zone_with_miss_chance(target_zone, src)

	if (!hit_zone)
		visible_message("<span class='danger'>\The [user] misses [src] with \the [I]!</span>")
		return null

	if (check_shields(I.force, I, user, target_zone, "the [I.name]"))
		return null
	if (src != user)
		if(attempt_dodge())//Trying to dodge it before they even have the chance to miss us.
			return null

	var/obj/item/organ/external/affecting = get_organ(hit_zone)
	if (!affecting || affecting.is_stump())
		user << "<span class='danger'>They are missing that limb!</span>"
		return null

	return hit_zone

/mob/living/carbon/human/hit_with_weapon(obj/item/I, mob/living/user, var/effective_force, var/hit_zone)
	var/obj/item/organ/external/affecting = get_organ(hit_zone)
	if (!affecting)
		return //should be prevented by attacked_with_item() but for sanity.
	if (hit_zone == "l_hand" || hit_zone == "r_hand" || hit_zone == "r_foot" || hit_zone == "l_foot")
		if (prob(50))
			if (prob(65))
				visible_message("<span class='notice'>[user] has tried to strike [src]'s [affecting.name] with [I.name] but missed!</span>")
				return
			else
				switch(hit_zone)
					if ("l_hand")
						hit_zone = "l_hand"
					if ("r_hand")
						hit_zone = "r_hand"
					if ("l_foot")
						hit_zone = "l_leg"
					if ("r_foot")
						hit_zone = "r_leg"
				affecting = get_organ(hit_zone)

	else if (hit_zone == "l_leg" || hit_zone == "r_leg" || hit_zone == "r_arm" || hit_zone == "l_arm")
		if (prob(25))
			if (prob(60))
				visible_message("<span class='notice'>[user] has tried to strike [src]'s [affecting.name] with [I.name] but missed!</span>")
				return
			else
				affecting = get_organ("chest")
	else if (hit_zone == "head")
		if (prob(18))
			visible_message("<span class='notice'>[user] has tried to strike [src]'s [affecting.name] with [I.name] but missed!</span>")
			return
	visible_message("<span class='danger'>[src] has been [I.attack_verb.len? pick(I.attack_verb) : "attacked"] in the [affecting.name] with [I.name] by [user]!</span>")
	receive_damage()
	instadeath_check()
	var/blocked = run_armor_check(hit_zone, "melee", I.armor_penetration, "Your armor has protected your [affecting.name].", "Your armor has softened the blow to your [affecting.name].", damage_source = I)
	standard_weapon_hit_effects(I, user, effective_force, blocked, hit_zone)

	return blocked

/mob/living/carbon/human/standard_weapon_hit_effects(obj/item/I, mob/living/user, var/effective_force, var/blocked, var/hit_zone)
	var/obj/item/organ/external/affecting = get_organ(hit_zone)
	if (!affecting)
		return FALSE

	// Handle striking to cripple.
	if(user.a_intent == I_DISARM)
		effective_force *= 0.66 //reduced effective force...
		if(!..(I, user, effective_force, blocked, hit_zone))
			return 0

		//set the dislocate mult less than the effective force mult so that
		//dislocating limbs on disarm is a bit easier than breaking limbs on harm
		attack_joint(affecting, I, effective_force, 0.5, blocked) //...but can dislocate joints
	else if(!..())
		return 0

	if(effective_force > 10 || effective_force >= 5 && prob(33))
		forcesay(hit_appends)	//forcesay checks stat already

	//Ok this block of text handles cutting arteries, tendons, and limbs off.
	//First we cut an artery, the reason for that, is that arteries are funninly enough, not that lethal, and don't have the biggest impact. They'll still make you bleed out, but they're less immediately lethal.
	if(I.sharp && prob(I.force/10) && !(affecting.status & ORGAN_ARTERY_CUT))
		affecting.sever_artery()
		if(affecting.artery_name == "carotid artery")
			src.visible_message("<span class='danger'><b>[user] slices [src]'s throat!</b></span>")
		else
			src.visible_message("<span class='danger'><b>[user] slices open [src]'s [affecting.artery_name] artery!</b></span>")

	//Next tendon, which disables the limb, but does not remove it, making it easier to fix, and less lethal, than losing it.
	else if(I.sharp && prob(I.force/12) && !(affecting.status & ORGAN_TENDON_CUT) && affecting.has_tendon)
		affecting.sever_tendon()
		src.visible_message("<span class='danger'><b>[user] slices open [src]'s [affecting.tendon_name] tendon!</b></span>")

	//Finally if we pass all that, we cut the limb off. This should reduce the number of one hit sword kills.
	else if(I.sharp && I.edge)
		if (istype(user, /mob/living/carbon/human) && istype(I,/obj/item/weapon/material/sword))
			var/obj/item/weapon/material/sword/S = I
			if (S.atk_mode == SLASH)
				var/mob/living/carbon/human/HH = user
				if(affecting.name != "groin" && prob((I.force * HH.getStatCoeff("strength")/6)))
					affecting.droplimb(0, DROPLIMB_EDGE)
					for(var/mob/living/carbon/human/NB in view(6,src))
						if (!NB.orc)
							NB.mood -= 10
							NB.ptsd += 1
	var/obj/item/organ/external/head/O = locate(/obj/item/organ/external/head) in src.organs

	if(I.damtype == BRUTE && !I.edge && prob(I.force * (hit_zone == "mouth" ? 6 : 0)) && O)//Knocking out teeth.
		if(O.knock_out_teeth(get_dir(user, src), round(rand(28, 38) * ((I.force*1.5)/100))))
			src.visible_message("<span class='danger'>[src]'s teeth sail off in an arc!</span>", \
								"<span class='userdanger'>[src]'s teeth sail off in an arc!</span>")

	else if ((I.damtype == BRUTE || I.damtype == HALLOSS) && prob(5 + (effective_force)))
		if (!stat)
			if (headcheck(hit_zone))
				//Harder to score a stun but if you do it lasts a bit longer
				if (prob(effective_force/8))
					visible_message("<span class='danger'>[src] [species.knockout_message]</span>")
					apply_effect(7, PARALYZE, blocked)
			else
				//Easier to score a stun but lasts less time
				if (prob(effective_force/5))
					visible_message("<span class='danger'>[src] has been knocked down!</span>")
					apply_effect(1, WEAKEN, blocked)

	if (prob(I.force * (hit_zone == "mouth" ? 5 : 0)) && O) //Will the teeth fly out?
		if (O.knock_out_teeth(get_dir(user, src), round(rand(28, 38) * ((I.force*1.5)/100))))
			visible_message("<span class='danger'>Some of [src]'s teeth sail off in an arc!</span>", \
								"<span class='userdanger'>Some of [src]'s teeth sail off in an arc!</span>")
		//Apply blood
		if (!(I.flags & NOBLOODY))
			I.add_blood(src)

		if (prob(33 + I.sharp*10))
			var/turf/location = loc
			if (istype(location, /turf))
				location.add_blood(src)
			if (ishuman(user))
				var/mob/living/carbon/human/H = user
				if (get_dist(H, src) <= 1) //people with TK won't get smeared with blood
					H.bloody_body(src)
					H.bloody_hands(src)

			switch(hit_zone)
				if ("head")
					if (wear_mask)
						wear_mask.add_blood(src)
						update_inv_wear_mask(0)
					if (head)
						head.add_blood(src)
						update_inv_head(0)
				if ("chest")
					bloody_body(src)
	if (istype(I, /obj/item/weapon/material/quarterstaff))
		if (istype(user, /mob/living/carbon/human))
			var/mob/living/carbon/human/HH = user
			if (prob(6*HH.getStatCoeff("dexterity")))
				visible_message("<span class='danger'>[src] has been knocked down!</span>")
				Weaken(2)
		else
			if (prob(6))
				visible_message("<span class='danger'>[src] has been knocked down!</span>")
				Weaken(2)
	instadeath_check()

/mob/living/carbon/human/proc/attack_joint(var/obj/item/organ/external/organ, var/obj/item/W, var/blocked)
	if (!organ || (organ.dislocated == 2) || (organ.dislocated == -1) || blocked >= 2)
		return FALSE
	if (prob(W.force / (blocked+1)))
		visible_message("<span class='danger'><b>[src]'s [organ.joint] [pick("gives way","caves in","crumbles","collapses")]!</b></span>")
		organ.dislocate(1)
		return TRUE
	return FALSE

//this proc handles being hit by a thrown atom
/mob/living/carbon/human/hitby(atom/movable/AM as mob|obj,var/speed = THROWFORCE_SPEED_DIVISOR)
	if (isobj(AM))
		var/obj/O = AM

		if (in_throw_mode && !get_active_hand() && speed <= THROWFORCE_SPEED_DIVISOR && prob(round(75/O.w_class)))	//empty active hand and we're in throw mode
			if (canmove && !restrained())
				if (isturf(O.loc))
					put_in_active_hand(O)
					visible_message("<span class='warning'>[src] catches [O]!</span>")
					throw_mode_off()
					return

		var/dtype = O.damtype
		var/throw_damage = O.throwforce*(speed/THROWFORCE_SPEED_DIVISOR)

		var/zone
		if (istype(O.thrower, /mob/living))
			var/mob/living/L = O.thrower
			var/tgt = L.targeted_organ
			if (L.targeted_organ == "random")
				tgt = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
			zone = check_zone(tgt)
		else
			zone = ran_zone("chest",75)	//Hits a random part of the body, geared towards the chest

		//check if we hit
		var/miss_chance = 15
		if (O.throw_source)
			var/distance = get_dist(O.throw_source, loc)
			miss_chance = max(15*(distance-2), 0)
		zone = get_zone_with_miss_chance(zone, src, miss_chance, ranged_attack=1)

		if (zone && O.thrower != src)
			var/shield_check = check_shields(throw_damage, O, thrower, zone, "[O]")
			if (shield_check == PROJECTILE_FORCE_MISS)
				zone = null
			else if (shield_check)
				return

		if (!zone && lying)
			zone = "chest"

		if (!zone)
	//		visible_message("<span class='notice'>\The [O] misses [src] narrowly!</span>")
			return

		if (istype(AM, /obj/item))
			var/obj/item/I = AM
			if (I.throwforce >= 15 && prob(I.throwforce))
				Weaken(ceil(I.throwforce/8))

		O.throwing = FALSE		//it hit, so stop moving

		var/obj/item/organ/external/affecting = get_organ(zone)
		var/hit_area = affecting.name
		if (!hit_area)
			return
		visible_message("<span class = 'red'>[src] has been hit in the [hit_area] by [O].</span>")
		var/armor = run_armor_check(affecting, "melee", O.armor_penetration, "Your armor has protected your [hit_area].", "Your armor has softened hit to your [hit_area].", damage_source = AM) //I guess "melee" is the best fit here

		if(armor < 100)
			var/sharp = O.sharp
			var/edge = O.edge
			if(prob(armor))
				edge = 0
				sharp = 0
			apply_damage(throw_damage,BRUTE, zone, armor, O, sharp, edge)

		if (ismob(O.thrower))
			var/mob/M = O.thrower
			var/client/assailant = M.client
			if (assailant)
				attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been hit with a [O], thrown by [M.name] ([assailant.ckey])</font>")
				M.attack_log += text("\[[time_stamp()]\] <font color='red'>Hit [name] ([ckey]) with a thrown [O]</font>")
				if (!istype(src,/mob/living/simple_animal/mouse))
					msg_admin_attack("[name] ([ckey]) was hit by a [O], thrown by [M.name] ([assailant.ckey]) (<A HREF='?_src_=holder;adminplayerobservecoodjump=1;X=[x];Y=[y];Z=[z]'>JMP</a>)")

		//thrown weapon embedded object code.
		if (dtype == BRUTE && istype(O,/obj/item))
			var/obj/item/I = O
			var/sharp = is_sharp(I)
			var/damage = throw_damage
			if (armor)
				damage /= armor+1

			//blunt objects should really not be embedding in things unless a huge amount of force is involved
			var/embed_chance = sharp? damage/I.w_class : damage/(I.w_class*3)
			var/embed_threshold = sharp? 5*I.w_class : 15*I.w_class

			//Sharp objects will always embed if they do enough damage.
			//Thrown sharp objects have some momentum already and have a small chance to embed even if the damage is below the threshold
			if ((sharp && prob(damage/(10*I.w_class)*100)) || (damage > embed_threshold && prob(embed_chance)))
				if (I.w_class <= 2.0)
					affecting.embed(I)
		if (istype(O, /obj/item/weapon/snowball))
			O.icon_state = "snowball_hit"
			O.update_icon()
			spawn(6)
				qdel(O)
			return
		// Begin BS12 momentum-transfer code.
		var/mass = 1.5
		if (istype(O, /obj/item))
			var/obj/item/I = O
			mass = I.w_class/THROWNOBJ_KNOCKBACK_DIVISOR
		var/momentum = speed*mass

		if (O.throw_source && momentum >= THROWNOBJ_KNOCKBACK_SPEED)
			var/dir = get_dir(O.throw_source, src)

			visible_message("<span class = 'red'>[src] staggers under the impact!</span>","<span class = 'red'>You stagger under the impact!</span>")
			throw_at(get_edge_target_turf(src,dir),1,momentum)

			if (!O || !src) return

			if (O.loc == src && O.sharp) //Projectile is embedded and suitable for pinning.
				var/turf/T = near_wall(dir,2)

				if (T)
					loc = T
					visible_message("<span class='warning'>[src] is pinned to the wall by [O]!</span>","<span class='warning'>You are pinned to the wall by [O]!</span>")
					anchored = TRUE
					pinned += O

/mob/living/carbon/human/embed(var/obj/O, var/def_zone=null)
	if (!def_zone) ..()

	var/obj/item/organ/external/affecting = get_organ(def_zone)
	if (affecting)
		affecting.embed(O)

/mob/living/carbon/human/proc/bloody_hands(var/mob/living/source, var/amount = 2)
	if (gloves)
		gloves.add_blood(source)
		gloves:transfer_blood = amount
		gloves:bloody_hands_mob = source
	else
		add_blood(source)
		bloody_hands = amount
		bloody_hands_mob = source
	update_inv_gloves()		//updates on-mob overlays for bloody hands and/or bloody gloves

/mob/living/carbon/human/proc/bloody_body(var/mob/living/source)
	if (wear_suit)
		wear_suit.add_blood(source)
		update_inv_wear_suit(0)
	if (w_uniform)
		w_uniform.add_blood(source)
		update_inv_w_uniform(0)

/mob/living/carbon/human/proc/handle_suit_punctures(var/damtype, var/damage, var/def_zone)
	return

/mob/living/carbon/human/reagent_permeability()
	var/perm = FALSE

	var/list/perm_by_part = list(
		"head" = THERMAL_PROTECTION_HEAD,
		"upper_torso" = THERMAL_PROTECTION_UPPER_TORSO,
		"lower_torso" = THERMAL_PROTECTION_LOWER_TORSO,
		"legs" = THERMAL_PROTECTION_LEG_LEFT + THERMAL_PROTECTION_LEG_RIGHT,
		"feet" = THERMAL_PROTECTION_FOOT_LEFT + THERMAL_PROTECTION_FOOT_RIGHT,
		"arms" = THERMAL_PROTECTION_ARM_LEFT + THERMAL_PROTECTION_ARM_RIGHT,
		"hands" = THERMAL_PROTECTION_HAND_LEFT + THERMAL_PROTECTION_HAND_RIGHT
		)

	for (var/obj/item/clothing/C in get_equipped_items())
		if (C.permeability_coefficient == TRUE || !C.body_parts_covered)
			continue
		if (C.body_parts_covered & HEAD)
			perm_by_part["head"] *= C.permeability_coefficient
		if (C.body_parts_covered & UPPER_TORSO)
			perm_by_part["upper_torso"] *= C.permeability_coefficient
		if (C.body_parts_covered & LOWER_TORSO)
			perm_by_part["lower_torso"] *= C.permeability_coefficient
		if (C.body_parts_covered & LEGS)
			perm_by_part["legs"] *= C.permeability_coefficient
		if (C.body_parts_covered & FEET)
			perm_by_part["feet"] *= C.permeability_coefficient
		if (C.body_parts_covered & ARMS)
			perm_by_part["arms"] *= C.permeability_coefficient
		if (C.body_parts_covered & HANDS)
			perm_by_part["hands"] *= C.permeability_coefficient

	for (var/part in perm_by_part)
		perm += perm_by_part[part]

	return perm


/mob/living/carbon/human/kick_act(var/mob/living/carbon/human/user)
	if(!..())//If we can't kick then this doesn't happen.
		return
	if(user == src)//Can't kick yourself dummy.
		return

	var/hit_zone = user.targeted_organ
	if (user.targeted_organ == "random")
		hit_zone = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
	var/too_high_message = "You can't reach that high."
	var/obj/item/organ/external/affecting = get_organ(hit_zone)
	if(!affecting || affecting.is_stump())
		user << "<span class='danger'>They are missing that limb!</span>"
		return

	var/armour = run_armor_check(hit_zone, "melee")
	switch(hit_zone)
		if("chest")//If we aim for the chest we kick them in the direction we're facing.
			if(lying)
				var/turf/target = get_turf(src.loc)
				var/range = src.throw_range
				var/throw_dir = get_dir(user, src)
				for(var/i = 1; i < range; i++)
					var/turf/new_turf = get_step(target, throw_dir)
					target = new_turf
					if(new_turf && new_turf.density)
						break
				src.throw_at(target, rand(1,3), src.throw_speed)
			if(user.lying)
				user << "[too_high_message]"
				return

		if("mouth")//If we aim for the mouth then we kick their teeth out.
			if(lying)
				if(istype(affecting, /obj/item/organ/external/head) && prob(95))
					var/obj/item/organ/external/head/U = affecting
					U.knock_out_teeth(get_dir(user, src), rand(1,3))//Knocking out one tooth at a time.
			else
				user << "[too_high_message]"
				return

		if("head")
			if(!lying)
				user << "[too_high_message]"
				return

	var/kickdam = rand(0,15)
	stats["stamina"][1] = max(stats["stamina"][1] - kickdam, 0)
	if(kickdam)
		playsound(user.loc, 'sound/weapons/kick.ogg', 50, 0)
		apply_damage(kickdam, BRUTE, hit_zone, armour)
		user.visible_message("<span class=danger>[user] kicks [src] in the [affecting.name]!<span>")
		admin_attack_log(user, src, "Has kicked [src]", "Has been kicked by [user].")
	else
		user.visible_message("<span class=danger>[user] tried to kick [src] in the [affecting.name], but missed!<span>")
		playsound(loc, 'sound/weapons/punchmiss.ogg', 50, 1)
