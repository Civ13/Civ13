/obj/item/weapon/lipstick
	gender = PLURAL
	name = "red lipstick"
	desc = "A generic brand of lipstick."
	icon = 'icons/obj/items.dmi'
	icon_state = "lipstick"
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_EARS
	var/colour = "red"
	var/open = FALSE


/obj/item/weapon/lipstick/purple
	name = "purple lipstick"
	colour = "purple"
	flags = FALSE

/obj/item/weapon/lipstick/jade
	name = "jade lipstick"
	colour = "jade"

/obj/item/weapon/lipstick/black
	name = "black lipstick"
	colour = "black"


/obj/item/weapon/lipstick/random
	name = "lipstick"

/obj/item/weapon/lipstick/random/on_runtime_spawn()
	..()
	colour = pick("red","purple","jade","black")
	name = "[colour] lipstick"


/obj/item/weapon/lipstick/attack_self(mob/user as mob)
	to_chat(user, "<span class='notice'>You twist \the [src] [open ? "closed" : "open"].</span>")
	open = !open
	if (open)
		icon_state = "[initial(icon_state)]_[colour]"
	else
		icon_state = initial(icon_state)

/obj/item/weapon/lipstick/attack(mob/M as mob, mob/user as mob)
	if (!open)	return

	if (!istype(M, /mob))	return

	if (ishuman(M))
		var/mob/living/human/H = M
		if (H.lip_style)	//if they already have lipstick on
			to_chat(user, "<span class='notice'>You need to wipe off the old lipstick first!</span>")
			return
		if (H == user)
			user.visible_message("<span class='notice'>[user] does their lips with \the [src].</span>", \
								 "<span class='notice'>You take a moment to apply \the [src]. Perfect!</span>")
			H.lip_style = colour
			H.update_body()
		else
			user.visible_message("<span class='warning'>[user] begins to do [H]'s lips with \the [src].</span>", \
								 "<span class='notice'>You begin to apply \the [src].</span>")
			if (do_after(user, 20, H) && do_after(H, 20, src))	//user needs to keep their active hand, H does not.
				if (QDELETED(src) || QDELETED(user) || QDELETED(H) || user.incapacitated() || user.get_active_hand() != src || !open || !user.Adjacent(H))
					return
				if (H.lip_style)
					to_chat(user, "<span class='notice'>You need to wipe off the old lipstick first!</span>")
					return
				user.visible_message("<span class='notice'>[user] does [H]'s lips with \the [src].</span>", \
									 "<span class='notice'>You apply \the [src].</span>")
				H.lip_style = colour
				H.update_body()
	else
		to_chat(user, "<span class='notice'>Where are the lips on that?</span>")

//you can wipe off lipstick with paper! see code/modules/paperwork/paper.dm, paper/attack()


/obj/item/weapon/haircomb //sparklysheep's comb
	name = "comb"
	desc = "A pristine comb made from flexible plastic."
	w_class = ITEM_SIZE_TINY
	slot_flags = SLOT_EARS
	icon = 'icons/obj/items.dmi'
	icon_state = "purplecomb"
	item_state = "comb"
	flammable = TRUE
	flags = FALSE

/obj/item/weapon/haircomb/attack_self(mob/user)
	user.visible_message("<span class='notice'>[user] uses [src] to comb their hair neatly a [user.gender == FEMALE ? "lady" : "guy"].</span>")

// Apply a tailoring dye with a fresh sheet, on yourself only. Head and mouth
// select separate RGBs; neither the cut nor the hair's growth is changed.
/obj/item/stack/material/proc/dye_own_hair(mob/living/human/H, facial)
	var/datum/save_epoch = persistence_admission_identity
	var/turf/site = get_turf(H)
	var/part = facial ? "facial hair" : "hair"
	var/style = hair_dye_style(H, facial)
	if (!hair_dye_ready(H, site, save_epoch))
		return FALSE
	if (!style)
		to_chat(H, SPAN_NOTICE("You don't have any [part] that can take dye."))
		return FALSE
	var/previous = hair_dye_current(H, facial)
	var/selected = choose_hair_dye(H, part, previous)
	if (!hair_dye_ready(H, site, save_epoch) || !hair_dye_allowed(H, selected) || selected == previous || hair_dye_style(H, facial) != style || hair_dye_current(H, facial) != previous)
		return FALSE
	to_chat(H, SPAN_NOTICE("You start dyeing your [part]."))
	if (!do_after(H, 30, H) || !hair_dye_ready(H, site, save_epoch) || !hair_dye_allowed(H, selected) || hair_dye_style(H, facial) != style || hair_dye_current(H, facial) != previous)
		return FALSE
	var/list/rgb_channels = rgb2num(selected)
	if (!use(1))
		return FALSE
	if (facial)
		H.change_facial_hair_color(rgb_channels[1], rgb_channels[2], rgb_channels[3])
	else
		H.change_hair_color(rgb_channels[1], rgb_channels[2], rgb_channels[3])
	to_chat(H, SPAN_NOTICE("You finish dyeing your [part]."))
	return TRUE

/obj/item/stack/material/proc/hair_dye_ready(mob/living/human/H, turf/site, datum/save_epoch)
	if (!site || QDELETED(H) || !is_cloth_sheet(src) || !can_use(1) || loc != H || H.get_active_hand() != src || H.incapacitated() || H.a_intent != I_HELP || get_turf(H) != site || persistence_admission_changed(save_epoch))
		return FALSE
	var/obj/item/organ/external/head/head_organ = H.get_organ("head")
	return head_organ && !head_organ.is_stump()

/proc/hair_dye_style(mob/living/human/H, facial)
	if (QDELETED(H) || !H.species || !H.body_build || H.body_build.nohair || H.body_build.nofacialhair)
		return null
	var/style = facial ? H.f_style : H.h_style
	var/datum/sprite_accessory/S = facial ? facial_hair_styles_list[style] : hair_styles_list[style]
	if (!S || !S.do_colouration || S.icon_state == "bald" || !(H.species.get_bodytype() in S.species_allowed))
		return null
	return style

/proc/hair_dye_current(mob/living/human/H, facial)
	return lowertext(facial ? rgb(H.r_facial, H.g_facial, H.b_facial) : rgb(H.r_hair, H.g_hair, H.b_hair))

/proc/hair_dye_allowed(mob/living/human/H, colour)
	if (!istext(colour) || length(colour) != 7 || copytext(colour, 1, 2) != "#")
		return FALSE
	for (var/i in 2 to 7)
		var/code = text2ascii(colour, i)
		if (!((code >= 48 && code <= 57) || (code >= 97 && code <= 102)))
			return FALSE
	if (crafting_node_allowed(H, "textile_mills"))
		return TRUE
	return colour != "#ffffff" && crafting_node_allowed(H, tailoring_dye_node(colour))

/obj/item/stack/material/proc/choose_hair_dye(mob/living/human/H, part, previous)
	var/list/dyes = tailoring_known_dyes(H)
	if (isnull(dyes))
		var/mixed = WWinput(H, "Choose a colour for your [part]. This uses one cloth sheet.", "Hair dye", previous, "color")
		return istext(mixed) ? lowertext(mixed) : null
	dyes -= "undyed"
	if (!length(dyes))
		crafting_node_allowed_or_warn(H, "weaving")
		return null
	var/picked = WWinput(H, "Choose a dye for your [part]. This uses one cloth sheet.", "Hair dye", null, dyes)
	return (picked in dyes) ? dyes[picked] : null
