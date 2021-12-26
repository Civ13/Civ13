
//Called when the mob is hit with an item in combat.
/mob/living/human/resolve_item_attack(obj/item/I, mob/living/user, var/effective_force, var/hit_zone)
	if (check_attack_throat(I, user))
		return null
	..()

/mob/living/human/standard_weapon_hit_effects(obj/item/I, mob/living/user, var/effective_force, var/blocked, var/hit_zone)
	if (!effective_force || blocked >= 2)
		return FALSE


	//Apply weapon damage
	var/weapon_sharp = is_sharp(I)
	var/weapon_edge = I.edge
	if (prob(getarmor(hit_zone, "melee"))) //melee armor provides a chance to turn sharp/edge weapon attacks into blunt ones
		weapon_sharp = FALSE
		weapon_edge = FALSE

	apply_damage(effective_force, I.damtype, hit_zone, blocked, sharp=weapon_sharp, edge=weapon_edge, used_weapon=I)

	return TRUE

// Attacking someone with a weapon while they are neck-grabbed = throat slitting
/mob/living/human/proc/check_attack_throat(obj/item/W, mob/user)
	if (user.a_intent == I_HARM)
		for (var/obj/item/weapon/grab/G in grabbed_by)
			if (G.assailant == user && G.state >= GRAB_NECK)
				if (attack_throat(W, G, user))
					return TRUE
	return FALSE

// Knifing
/mob/living/human/proc/attack_throat(obj/item/W, obj/item/weapon/grab/G, mob/user, delay = 20)

	if (!W.has_edge() || !W.force || W.damtype != BRUTE)
		return FALSE //unsuitable weapon

	user.visible_message("<span class='danger'>\The [user] begins to slit [src]'s throat with \the [W]!</span>")

	user.next_move = world.time + delay //also should prevent user from triggering this repeatedly
	if (!do_after(user, delay, progress=0))
		return FALSE
	if (!(G && G.assailant == user && G.affecting == src)) //check that we still have a grab
		return FALSE

	var/base_damage_mod = 4.0
	var/damage_mod = base_damage_mod
	//presumably, if they are wearing a helmet that stops pressure effects, then it probably covers the throat as well
	var/obj/item/clothing/head/helmet = get_equipped_item(slot_head)
	if (istype(helmet) && (helmet.body_parts_covered & HEAD) && (helmet.flags & STOPPRESSUREDAMAGE))
		//we don't do an armor_check here because this is not an impact effect like a weapon swung with momentum, that either penetrates or glances off.
		damage_mod = base_damage_mod - (helmet.armor["melee"]/100)

	var/total_damage = FALSE
	for (var/i in TRUE to 3)
		var/damage = min(W.force*1.5, 20)*damage_mod
		apply_damage(damage, W.damtype, "head", FALSE, sharp=W.sharp, edge=W.edge)
		total_damage += damage

	var/oxyloss = total_damage
	if (total_damage >= 40) //threshold to make someone pass out
		oxyloss = 60 // Brain lacks oxygen immediately, pass out

	adjustOxyLoss(min(oxyloss, 100 - getOxyLoss())) //don't put them over 100 oxyloss

	if (total_damage)
		if (oxyloss >= 40)
			user.visible_message("<span class='danger'>\The [user] slit [src]'s throat open with \the [W]!</span>")
		else
			user.visible_message("<span class='danger'>\The [user] cut [src]'s neck with \the [W]!</span>")

		if (W.hitsound)
			playsound(loc, W.hitsound, 50, TRUE, -1)

	G.last_action = world.time
	flick(G.hud.icon_state, G.hud)

	emote("painscream")

	user.attack_log += "\[[time_stamp()]\]<font color='red'> slit [name]'s throat ([ckey],[stat]) with [W.name] (INTENT: [uppertext(user.a_intent)]) (DAMTYE: [uppertext(W.damtype)])</font>"
	attack_log += "\[[time_stamp()]\]<font color='orange'> got throatslit by [user.name] ([user.ckey]) with [W.name] (INTENT: [uppertext(user.a_intent)]) (DAMTYE: [uppertext(W.damtype)])</font>"
	msg_admin_attack("[key_name(user)] slit [key_name(src)]'s throat with [W.name] (INTENT: [uppertext(user.a_intent)]) (DAMTYE: [uppertext(W.damtype)])" )
	return TRUE