/obj/item/weapon/handcuffs
	name = "handcuffs"
	desc = "Use this to keep prisoners in line."
	gender = PLURAL
	icon = 'icons/obj/items.dmi'
	icon_state = "handcuff"
	flags = CONDUCT
	slot_flags = SLOT_BELT
	throwforce = WEAPON_FORCE_WEAK
	w_class = ITEM_SIZE_SMALL
	throw_speed = 2
	throw_range = 5
	var/dispenser = FALSE
	var/breakouttime = 1200 //Deciseconds = 120s = 2 minutes
	var/cuff_sound = 'sound/weapons/handcuffs.ogg'
	var/cuff_type = "handcuffs"

/obj/item/weapon/handcuffs/attack(var/mob/living/human/C, var/mob/living/user)

	if (!user.IsAdvancedToolUser())
		return

	if(!C.handcuffed)
		if (C == user)
			place_handcuffs(user, user)
			return

		//check for an aggressive grab (or robutts)
		if(can_place(C, user))
			place_handcuffs(C, user)
		else
			to_chat(user, "<span class='danger'>You need to have a firm grip on [C] before you can put \the [src] on!</span>")
	else
		to_chat(user, "<span class='warning'>\The [C] is already handcuffed!</span>")


/obj/item/weapon/handcuffs/proc/can_place(var/mob/target, var/mob/user)
	if(user == target)
		return 1
	else
		if (target.lying)
			return 1
		for (var/obj/item/weapon/grab/G in target.grabbed_by)
			if (G.loc == user && G.state >= GRAB_AGGRESSIVE)
				return 1
	return 0

/obj/item/weapon/handcuffs/proc/place_handcuffs(var/mob/living/human/target, var/mob/user)
	playsound(loc, cuff_sound, 30, 1, -2)

	var/mob/living/human/H = target
	if (!istype(H))
		return FALSE

	if (!H.has_organ_for_slot(slot_handcuffed))
		user << "<span class='danger'>\The [H] needs at least two wrists before you can cuff them together!</span>"
		return FALSE

	user.visible_message("<span class='danger'>\The [user] is attempting to put [cuff_type] on \the [H]!</span>")

	if (!do_after(user,8, target))
		return FALSE

	if(!can_place(target, user)) // victim may have resisted out of the grab in the meantime
		return FALSE

	admin_attack_log(user, H, "Attempted to handcuff the victim", "Was target of an attempted handcuff", "attempted to handcuff")

	H.attack_log += text("\[[time_stamp()]\] <font color='orange'>Has been handcuffed by [user.name] ([user.ckey])</font>")
	user.attack_log += text("\[[time_stamp()]\] <font color='red'>Handcuff [H.name] ([H.ckey])</font>")


	user.setClickCooldown(DEFAULT_ATTACK_COOLDOWN)
	user.do_attack_animation(H)

	user.visible_message("<span class='danger'>\The [user] has put [cuff_type] on \the [H]!</span>")

	// Apply cuffs.
	var/obj/item/weapon/handcuffs/cuffs = src
	if(dispenser)
		cuffs = new(get_turf(user))
	else
		user.drop_from_inventory(cuffs)
	target.equip_to_slot(cuffs,slot_handcuffed)
	return 1

var/last_chew = FALSE
/mob/living/human/RestrainedClickOn(var/atom/A)
	if (A != src) return ..()
	if (last_chew + 26 > world.time) return

	var/mob/living/human/H = A
	if (!H.handcuffed) return
	if (H.a_intent != I_HARM) return
	if (H.targeted_organ != "mouth") return
	if (H.wear_mask) return
	var/obj/item/organ/external/O = H.organs_by_name[H.hand?"l_hand":"r_hand"]
	if (!O) return

	H.visible_message("<span class='warning'>\The [H] chews on \his [O.name]!</span>", "<span class='warning'>You chew on your [O.name]!</span>")
	attack_log(H, "chewed on their [O.name]!")

	if (O.take_damage(3,0,1,1,"teeth marks"))
		H:UpdateDamageIcon()

	last_chew = world.time


/obj/item/weapon/handcuffs/cable
	name = "cable restraints"
	desc = "Looks like some cables tied together. Could be used to tie something up."
	icon_state = "cuff_white"
	breakouttime = 300 //Deciseconds = 30s
	cuff_sound = 'sound/weapons/cablecuff.ogg'
	cuff_type = "cable restraints"

/obj/item/weapon/handcuffs/cable/red
	color = "#dd0000"

/obj/item/weapon/handcuffs/cable/yellow
	color = "#dddd00"

/obj/item/weapon/handcuffs/cable/blue
	color = "#0000dd"

/obj/item/weapon/handcuffs/cable/green
	color = "#00dd00"

/obj/item/weapon/handcuffs/cable/pink
	color = "#dd00dd"

/obj/item/weapon/handcuffs/cable/orange
	color = "#dd8800"

/obj/item/weapon/handcuffs/cable/cyan
	color = "#00dddd"

/obj/item/weapon/handcuffs/cable/white
	color = "#ffffff"

/obj/item/weapon/handcuffs/rope
	name = "rope handcuffs"
	desc = "Use this to keep prisoners in line."
	icon = 'icons/obj/items.dmi'
	icon_state = "ropecuffs"
	flammable = TRUE

/obj/item/weapon/handcuffs/old
	name = "iron handcuffs"
	desc = "Use this to keep prisoners in line."
	icon = 'icons/obj/items.dmi'
	icon_state = "oldcuff"
	flammable = TRUE

/obj/item/weapon/handcuffs/strips
	name = "strip cuffs"
	desc = "Use this to keep prisoners in line."
	icon = 'icons/obj/items.dmi'
	icon_state = "strips"
	flammable = TRUE