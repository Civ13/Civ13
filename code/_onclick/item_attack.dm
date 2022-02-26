/*
=== Item Click Call Sequences ===
These are the default click code call sequences used when clicking on stuff with an item.

Atoms:

mob/ClickOn() calls the item's resolve_attackby() proc.
item/resolve_attackby() calls the target atom's attackby() proc.

Mobs:

mob/living/attackby() after checking for surgery, calls the item's attack() proc.
item/attack() generates attack logs, sets click cooldown and calls the mob's attacked_with_item() proc. If you override this, consider whether you need to set a click cooldown, play attack animations, and generate logs yourself.
mob/attacked_with_item() should then do mob-type specific stuff (like determining hit/miss, handling shields, etc) and then possibly call the item's apply_hit_effect() proc to actually apply the effects of being hit.

Item Hit Effects:

item/apply_hit_effect() can be overriden to do whatever you want. However "standard" physical damage based weapons should make use of the target mob's hit_with_weapon() proc to
avoid code duplication. This includes items that may sometimes act as a standard weapon in addition to having other effects (e.g. stunbatons on harm intent).
*/

/atom/proc/resolve_attack_obj(atom/A, mob/user, icon_x, icon_y)
	return src.attack_obj(A, user, icon_x, icon_y)

/atom/proc/resolve_attack_turf(atom/A, mob/user, icon_x, icon_y)
	return src.attack_turf(A, user, icon_x, icon_y)

/obj/item/proc/resolve_attackby(atom/A, mob/user, icon_x, icon_y) //resolving attack of atom A by src item in active hand of user
	var/resolved = FALSE
	add_fingerprint(user)
	if (isturf(A))
		resolved = src.resolve_attack_turf(A, user, icon_x, icon_y)
		if (resolved)
			return TRUE
	resolved = A.attackby(src, user, icon_x, icon_y)
	if (resolved)
		return TRUE
	if (isobj(A))
		resolved = src.resolve_attack_obj(A, user, icon_x, icon_y)
		if (resolved)
			return TRUE
	return FALSE

/obj/item/proc/attack_self(mob/user, icon_x, icon_y) // called when the item is in the active hand, and clicked; alternately, there is an 'activate held object' verb or you can hit Z.
	return FALSE //procedure prototype; if not defined in the child object, it returns FALSE, as it does not resolve the action to complete

/atom/proc/attackby(obj/item/W, mob/user, icon_x, icon_y) 
	return FALSE //procedure prototype; if not defined in the child object, it returns FALSE, as it does not resolve the action to complete

/atom/proc/attack_turf(turf/attacked, mob/user, icon_x, icon_y) 
	return FALSE //procedure prototype; if not defined in the child object, it returns FALSE, as it does not resolve the action to complete

/atom/proc/attack_obj(obj/attacked, mob/user, icon_x, icon_y) 
	return FALSE //procedure prototype; if not defined in the child object, it returns FALSE, as it does not resolve the action to complete

/atom/movable/attackby(obj/item/W, mob/user, icon_x, icon_y)
	if (!(W.flags & NOBLUDGEON) && !(istype(W, /obj/item/weapon/covers)))
		visible_message("<span class='danger'>[src] has been hit by [user] with [W].</span>")
	return

/mob/living/attackby(obj/item/I, mob/user, icon_x, icon_y)
	if (!ismob(user))
		return FALSE
	if (can_operate(src) && do_surgery(src,user,I)) //Surgery
		return TRUE
	var/tgt = user.targeted_organ
	if (user.targeted_organ == "random")
		tgt = pick("l_foot","r_foot","l_leg","r_leg","chest","groin","l_arm","r_arm","l_hand","r_hand","eyes","mouth","head")
	return I.attack(src, user, tgt)

// Proximity_flag is TRUE if this afterattack was called on something adjacent, in your square, or on your person.
// Click parameters is the params string from byond Click() code, see that documentation.
/obj/item/proc/afterattack(atom/target, mob/user, proximity_flag, params)
	if (istype(target, /obj/structure/table))
		var/list/click_params = params2list(params)
		//Center the icon where the user clicked.
		pixel_x = (text2num(click_params["icon-x"]) - 16)
		pixel_y = (text2num(click_params["icon-y"]) - 16)
		layer = user.layer + 0.1
		if (!isnum(click_params))
			return
	return

//I would prefer to rename this attack_as_weapon(), but that would involve touching hundreds of files.
/obj/item/proc/attack(mob/living/M, mob/living/user, var/target_zone)
	if (!force || (flags & NOBLUDGEON))
		return FALSE
	if (M == user && user.a_intent != I_HARM)
		return FALSE
	if (ishuman(user))
		var/mob/living/human/H = user
		if (H.stats["stamina"][1] >= (cooldownw*0.45)/H.getStatCoeff("strength"))
			H.stats["stamina"][1] = max(0,H.stats["stamina"][1] - (cooldownw*0.45)/H.getStatCoeff("strength"))
		else
			H << "<span class='warning'>You need to catch your breath!</span>"
			return
	user.lastattacked = M
	M.lastattacker = user
	if (!no_attack_log)
		user.attack_log += "\[[time_stamp()]\]<font color='red'> Attacked [M.name] ([M.ckey])([M.stat]) with [name] (INTENT: [uppertext(user.a_intent)]) (DAMTYE: [uppertext(damtype)])</font>"
		M.attack_log += "\[[time_stamp()]\]<font color='orange'> Attacked by [user.name] ([user.ckey]) with [name] (INTENT: [uppertext(user.a_intent)]) (DAMTYE: [uppertext(damtype)])</font>"
		msg_admin_attack("[key_name(user)] attacked [key_name(M)] with [name] (INTENT: [uppertext(user.a_intent)]) (DAMTYE: [uppertext(damtype)])" )
	user.setClickCooldown(cooldownw)
	user.do_attack_animation(M)
	var/hit_zone = M.resolve_item_attack(src, user, target_zone)
	if (hit_zone)
		apply_hit_effect(M, user, hit_zone)
	return TRUE

/obj/item/proc/apply_hit_effect(mob/living/target, mob/living/user, var/hit_zone) //Called when a weapon is used to make a successful melee attack on a mob. Returns the blocked result
	if (hitsound)
		playsound(loc, hitsound, 50, TRUE, -1)
	var/power = force
	return target.hit_with_weapon(src, user, power, hit_zone)
