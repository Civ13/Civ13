// Sealing wax (bee farming 5). Beeswax worked with pine pitch and a pigment
// makes a stick of sealing wax. Wax seals now cost wax: sealing an envelope
// with an envelope seal, or pressing a wax seal (an envelope seal or a
// faction seal matrix) onto paper, needs a stick in the other hand and uses a
// little of it. Ink stamps need nothing.

#define SEALING_WAX_USES 10
#define SEALING_WAX_PITCH 5

/proc/sealing_wax_colours()
	return list("red", "black", "blue", "green", "pink", "white")

/proc/sealing_wax_rgb(colour)
	switch (colour)
		if ("black")
			return "#433a38"
		if ("blue")
			return "#2f4f9a"
		if ("green")
			return "#2f7a3c"
		if ("pink")
			return "#d97aa6"
		if ("white")
			return "#ece6d6"
	return "#a3201b"

/obj/item/sealing_wax
	name = "stick of sealing wax"
	desc = "A stick of beeswax and pitch, coloured with pigment. Hold it in your other hand to seal a letter or press a wax seal onto paper."
	icon = 'icons/farming/bee_products.dmi'
	icon_state = "sealing_wax"
	w_class = ITEM_SIZE_TINY
	flammable = TRUE
	var/wax_colour = "red"
	var/uses = SEALING_WAX_USES

/obj/item/sealing_wax/New(loc, colour = null)
	..(loc)
	if (colour in sealing_wax_colours())
		wax_colour = colour
	update_icon()

/obj/item/sealing_wax/after_load()
	..()
	update_icon()

/obj/item/sealing_wax/update_icon()
	color = sealing_wax_rgb(wax_colour)
	name = "stick of [wax_colour] sealing wax"
	icon_state = uses <= SEALING_WAX_USES / 2 ? "sealing_wax_half" : "sealing_wax"

/obj/item/sealing_wax/examine(mob/user)
	..()
	to_chat(user, "There is enough left for about [uses] seal[uses == 1 ? "" : "s"].")

/obj/item/sealing_wax/proc/use_one(mob/user)
	uses--
	if (uses > 0)
		update_icon()
		return
	if (user)
		to_chat(user, SPAN_NOTICE("That was the last of \the [src]."))
		user.drop_from_inventory(src)
	qdel(src)

// The stick of sealing wax in the hand that is not holding the seal.
/proc/held_sealing_wax(mob/user, obj/item/seal)
	if (!user)
		return null
	for (var/obj/item/sealing_wax/W in list(user.l_hand, user.r_hand))
		if (W != seal && W.uses > 0)
			return W
	return null

/obj/item/weapon/stamp/proc/is_wax_seal()
	return FALSE

/obj/item/weapon/stamp/mail/is_wax_seal()
	return TRUE

/obj/item/weapon/stamp/faction_seal/is_wax_seal()
	return TRUE

// Paper: a wax seal needs wax and spends a little of it.
/obj/item/weapon/paper/attackby(obj/item/weapon/P as obj, mob/user as mob)
	if (!istype(P, /obj/item/weapon/stamp))
		return ..()
	var/obj/item/weapon/stamp/S = P
	if (!S.is_wax_seal())
		return ..()
	var/obj/item/sealing_wax/W = held_sealing_wax(user, S)
	if (!W)
		to_chat(user, SPAN_WARNING("You need a stick of sealing wax in your other hand to press a seal."))
		return
	var/before = islist(stamped) ? stamped.len : 0
	. = ..()
	if ((islist(stamped) ? stamped.len : 0) > before && !QDELETED(W))
		W.use_one(user)

// Envelopes: the seal takes the colour of the wax.
/obj/item/weapon/storage/envelope/attackby(obj/item/W as obj, mob/user as mob)
	if (opened || !istype(W, /obj/item/weapon/stamp/mail))
		return ..()
	if (sealed)
		to_chat(user, SPAN_WARNING("There is a wax seal already!"))
		return TRUE
	var/obj/item/sealing_wax/SW = held_sealing_wax(user, W)
	if (!SW)
		to_chat(user, SPAN_WARNING("You need a stick of sealing wax in your other hand to seal the envelope."))
		return TRUE
	var/wax = SW.wax_colour
	overlays += image("icon" = 'icons/obj/mail.dmi', "icon_state" = "wax_seal_[wax]")
	desc += "<br>This envelope has been sealed with [wax] wax."
	sealed = TRUE
	wax_colour = wax
	SW.use_one(user)
	to_chat(user, SPAN_NOTICE("You drip [wax] wax over the flap and press the seal into it."))
	var/add_name = WWinput(user, "Would you like the seal to bear your name?", "Wax seal", "no", list("yes", "no"))
	if (add_name == "yes" && !QDELETED(src) && user && user.Adjacent(src))
		desc += "<br>There is a name on the seal - <b>[user.real_name]</b>."
	return TRUE

// Beeswax worked with pitch from a tar kiln.
/obj/item/weapon/beeswax/proc/make_sealing_wax(obj/item/weapon/reagent_containers/glass/G, mob/user)
	if (!G.reagents || G.reagents.get_reagent_amount("pitch") < SEALING_WAX_PITCH)
		to_chat(user, SPAN_NOTICE("You need at least [SEALING_WAX_PITCH] units of pitch in \the [G] to make sealing wax."))
		return TRUE
	var/colour = WWinput(user, "What pigment do you work into the wax?", "Sealing wax", "red", sealing_wax_colours() + "cancel")
	if (!(colour in sealing_wax_colours()) || QDELETED(src) || QDELETED(G) || !user.Adjacent(src))
		return TRUE
	user.visible_message(SPAN_NOTICE("[user] melts \the [src] with some pitch and rolls it into a stick."), SPAN_NOTICE("You melt \the [src] with some pitch, work in the pigment and roll a stick of sealing wax."))
	if (!do_after(user, 40, src) || QDELETED(src) || QDELETED(G))
		return TRUE
	if (G.reagents.get_reagent_amount("pitch") < SEALING_WAX_PITCH)
		return TRUE
	G.reagents.remove_reagent("pitch", SEALING_WAX_PITCH)
	var/turf/T = get_turf(src)
	var/mob/M = loc
	if (istype(M))
		M.drop_from_inventory(src)
	qdel(src)
	var/obj/item/sealing_wax/stick = new(T, colour)
	user.put_in_hands(stick)
	return TRUE

#undef SEALING_WAX_USES
#undef SEALING_WAX_PITCH
