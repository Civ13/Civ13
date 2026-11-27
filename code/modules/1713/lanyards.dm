// Lanyards and wrist loops: tethers that keep a small tool, knife, whistle,
// compass, key or pistol from being lost when it is dropped or knocked away.
// Each kind fits the things it was historically made for. See docs/gemstones.md.
// Included after belt_pouches.dm and necklaces.dm.
//
// Wrist loops (wrist thong, sword knot) are fixed to the item itself. While
// the loop is on your wrist, a dropped or knocked away item swings from it
// and you catch it again, so that hand stays busy.
// Lanyards are worn on the outfit or belt. An item stowed on a lanyard is
// tied to it; when that item is dropped it hangs from the lanyard instead of
// falling, and you draw it back from there.
// Tethered items can't be thrown. Untie them, or slip the loop off, first.

#define LANYARD_REGRIP_DELAY 10
#define WRIST_LOOP_TIME 10
#define LANYARD_UNTIE_TIME 10

/obj/item
	var/wrist_loop = null // name of the wrist loop fixed to this item, if any
	var/wrist_looped = FALSE // the loop is round its holder's wrist
	var/lanyard_tied = FALSE // tied to a lanyard its holder wears

// ---- Wrist loops: fixed to a one-handed tool or weapon ----

/obj/item/wrist_loop
	name = "wrist thong"
	desc = "A loop of rawhide thong. Bind it to the handle of a hatchet, club, mace, hammer or knife, held in your other hand, so the tool hangs from your wrist instead of falling when it slips from your grip."
	icon = 'icons/obj/lanyards.dmi'
	icon_state = "wrist_thong"
	w_class = ITEM_SIZE_TINY
	value = 1
	var/list/fits = list(
		/obj/item/weapon/material/hatchet,
		/obj/item/weapon/material/machete,
		/obj/item/weapon/material/kitchen/utensil/knife,
		/obj/item/weapon/melee/classic_baton/club,
		/obj/item/weapon/melee/mace,
		/obj/item/weapon/hammer)
	var/list/never_fits = list(/obj/item/weapon/material/twohanded)

/obj/item/wrist_loop/sword_knot
	name = "sword knot"
	desc = "A leather strap with a tassel. Bind it to the hilt of a one-handed sword or sabre, held in your other hand, and slip your wrist through it so the blade is not lost if it is knocked from your hand."
	icon_state = "sword_knot"
	value = 3
	fits = list(/obj/item/weapon/material/sword)
	never_fits = list(/obj/item/weapon/material/sword/tes13/twohanded)

/obj/item/wrist_loop/attack_self(mob/user)
	var/obj/item/I = user.get_inactive_hand()
	if (!istype(I))
		to_chat(user, SPAN_WARNING("Hold the tool in your other hand to bind \the [src] to it."))
		return
	if (I.wrist_loop)
		to_chat(user, SPAN_WARNING("\The [I] already has \a [I.wrist_loop]."))
		return
	if (!is_type_in_list(I, fits) || is_type_in_list(I, never_fits))
		to_chat(user, SPAN_WARNING("\The [src] is not made for \the [I]."))
		return
	to_chat(user, SPAN_NOTICE("You start binding \the [src] to \the [I]..."))
	if (!do_after(user, 30, I))
		return
	if (QDELETED(src) || QDELETED(I) || I.wrist_loop || user.get_inactive_hand() != I || loc != user)
		return
	I.wrist_loop = name
	I.wrist_looped = FALSE
	to_chat(user, SPAN_NOTICE("You bind \the [src] to \the [I]. Use Wrist Loop to slip your hand through it."))
	user.drop_from_inventory(src)
	qdel(src)

// ---- Lanyards: worn on the outfit or a belt ----

/obj/item/clothing/accessory/storage/lanyard
	name = "neck cord"
	desc = "A loop of twisted cord worn round the neck. Tie a knife, whistle or key to it and it hangs from the cord instead of falling when dropped."
	icon = 'icons/obj/lanyards.dmi'
	icon_state = "neck_cord"
	icon_override = 'icons/mob/lanyards.dmi'
	slot = "decor"
	slot_flags = 0
	slots = 1
	w_class = ITEM_SIZE_SMALL
	ripable = FALSE
	value = 2
	var/list/fits = list(
		/obj/item/weapon/material/kitchen/utensil/knife,
		/obj/item/weapon/whistle,
		/obj/item/weapon/key)
	var/list/never_fits = list(/obj/item/weapon/material/thrown)

/obj/item/clothing/accessory/storage/lanyard/New()
	..()
	hold.max_w_class = ITEM_SIZE_NORMAL
	hold.max_storage_space = 4

/obj/item/clothing/accessory/storage/lanyard/internal_storage_accepts(obj/item/W, stop_messages = FALSE)
	var/fits_it = is_type_in_list(W, fits) && !is_type_in_list(W, never_fits)
	if (!fits_it && !stop_messages)
		to_chat(usr, SPAN_NOTICE("\The [src] is not made to carry \the [W]."))
	return fits_it

/obj/item/clothing/accessory/storage/lanyard/fob_chain
	name = "fob chain"
	desc = "A short brass chain with a bar and a spring ring, worn from a waistcoat or belt. It keeps a compass or key from going astray. A chain can't be cut, only unclipped."
	icon_state = "fob_chain"
	flags = CONDUCT
	value = 4
	fits = list(/obj/item/weapon/compass, /obj/item/weapon/key)
	never_fits = list()

/obj/item/clothing/accessory/storage/lanyard/pistol
	name = "pistol lanyard"
	desc = "A braided cord worn over the shoulder, with a clip for the ring on a revolver or pistol butt. It also takes a whistle, compass or clasp knife."
	icon_state = "pistol_lanyard"
	value = 3
	fits = list(
		/obj/item/weapon/gun/projectile/revolver,
		/obj/item/weapon/gun/projectile/pistol,
		/obj/item/weapon/whistle,
		/obj/item/weapon/compass,
		/obj/item/weapon/material/kitchen/utensil/knife)

/obj/item/clothing/accessory/storage/lanyard/retention
	name = "retention lanyard"
	desc = "A coiled nylon cord with a clip at each end, worn from the belt. It holds a pistol, knife, compass, key, whistle or small tool."
	icon_state = "retention_lanyard"
	value = 4
	fits = list(
		/obj/item/weapon/gun/projectile/revolver,
		/obj/item/weapon/gun/projectile/pistol,
		/obj/item/weapon/material/kitchen/utensil/knife,
		/obj/item/weapon/compass,
		/obj/item/weapon/key,
		/obj/item/weapon/whistle,
		/obj/item/weapon/hammer,
		/obj/item/weapon/wrench,
		/obj/item/weapon/screwdriver)

/obj/item/clothing/accessory/storage/lanyard/on_attached(obj/item/clothing/S, mob/user)
	mob_overlay = null
	inv_overlay = null
	..()
	if (istype(S))
		S.update_clothing_icon()

// One lanyard per garment or belt.
/obj/item/clothing/can_attach_accessory(obj/item/clothing/accessory/A)
	if (istype(A, /obj/item/clothing/accessory/storage/lanyard) && (locate(/obj/item/clothing/accessory/storage/lanyard) in accessories))
		return FALSE
	return ..()

// ---- Catching dropped items ----

/obj/item/dropped(mob/user)
	..()
	if ((wrist_looped || lanyard_tied) && ishuman(user))
		addtimer(CALLBACK(src, PROC_REF(tether_catch), user), 1)

// Runs once the drop has settled. An item put somewhere on purpose (a bag,
// another person's hands) is no longer tethered; one left on the ground is
// caught by the loop or lanyard.
/obj/item/proc/tether_catch(mob/living/human/H)
	if (QDELETED(src) || QDELETED(H))
		return
	if (loc == H)
		return
	if (lanyard_tied && istype(loc, /obj/item/weapon/storage/internal))
		var/obj/item/weapon/storage/internal/S = loc
		if (istype(S.master_item, /obj/item/clothing/accessory/storage/lanyard))
			return
	if (!isturf(loc) || H.stat == DEAD || get_dist(src, H) > 1)
		wrist_looped = FALSE
		lanyard_tied = FALSE
		return
	if (wrist_looped && !H.lying && !H.restrained())
		// Hand updates can drop the item before returning. Suppress any new
		// catch during this attempt and only restore the loop on a real grip.
		var/restore_lanyard = lanyard_tied
		wrist_looped = FALSE
		lanyard_tied = FALSE
		var/caught = H.put_in_active_hand(src) || H.put_in_inactive_hand(src)
		lanyard_tied = restore_lanyard
		if (caught && loc == H && H.item_is_in_hands(src))
			wrist_looped = TRUE
			H.setClickCooldown(LANYARD_REGRIP_DELAY)
			H.visible_message(SPAN_WARNING("\The [src] slips from [H]'s grip and swings from the wrist loop."), SPAN_WARNING("\The [src] slips from your grip and swings from your wrist. You grip it again."))
			return
	wrist_looped = FALSE
	if (lanyard_tied)
		var/obj/item/clothing/accessory/storage/lanyard/L = H.lanyard_for(src)
		if (L)
			usr = H
			if (L.hold.handle_item_insertion(src, TRUE))
				lanyard_tied = TRUE
				H.visible_message(SPAN_NOTICE("\The [src] drops and hangs from [H]'s [L.name]."), SPAN_NOTICE("\The [src] drops and hangs from your [L.name]."))
				return
	lanyard_tied = FALSE

/obj/item/on_enter_storage(obj/item/weapon/storage/S)
	..()
	wrist_looped = FALSE
	var/obj/item/weapon/storage/internal/I = S
	lanyard_tied = istype(I) && istype(I.master_item, /obj/item/clothing/accessory/storage/lanyard)

// A draw preserves a tie only when it ends in the owner's actual hand.
/obj/item/proc/restore_lanyard_draw(atom/origin, mob/living/human/H)
	if (!istype(H) || loc != H || !H.item_is_in_hands(src))
		return
	var/obj/item/weapon/storage/internal/S = origin
	if (!istype(S))
		return
	var/obj/item/clothing/accessory/storage/lanyard/L = S.master_item
	if (!istype(L) || L.hold != S)
		return
	var/obj/item/clothing/C = L.has_suit
	if (C && C.loc == H && (C == H.w_uniform || C == H.wear_suit || C == H.belt) && L.loc == C && (L in C.accessories))
		lanyard_tied = TRUE

// A worn lanyard with room for this item, if any.
/mob/living/human/proc/lanyard_for(obj/item/I)
	for (var/obj/item/clothing/C in list(w_uniform, wear_suit, belt))
		for (var/obj/item/clothing/accessory/storage/lanyard/L in C.accessories)
			if (!length(L.hold.contents) && L.internal_storage_accepts(I, TRUE))
				return L
	return null

/mob/living/human/throw_item(atom/target)
	var/obj/item/I = get_active_hand()
	if (istype(I) && (I.wrist_looped || I.lanyard_tied))
		throw_mode_off()
		to_chat(src, SPAN_WARNING("\The [I] is tied to you. [I.wrist_looped ? "Slip the wrist loop off" : "Untie it"] first."))
		return
	return ..()

/obj/item/examine(mob/user, var/distance = -1)
	. = ..()
	if (wrist_loop)
		to_chat(user, "It has \a [wrist_loop][wrist_looped ? ", slipped round its holder's wrist" : ""].")
	if (lanyard_tied)
		to_chat(user, "It is tied to a lanyard.")

// ---- Verbs ----

/mob/living/human/verb/toggle_wrist_loop()
	set name = "Wrist Loop"
	set desc = "Slip your hand into, or out of, the wrist loop of the item in your hand."
	set category = "IC"
	var/obj/item/I = get_active_hand()
	if (!istype(I) || !I.wrist_loop)
		to_chat(src, SPAN_WARNING("The item in your hand has no wrist loop."))
		return
	if (!may_do_after)
		return
	if (!do_after(src, I.wrist_looped ? WRIST_LOOP_TIME / 2 : WRIST_LOOP_TIME, I))
		return
	if (QDELETED(I) || get_active_hand() != I)
		return
	I.wrist_looped = !I.wrist_looped
	to_chat(src, SPAN_NOTICE("You slip your hand [I.wrist_looped ? "through" : "out of"] the [I.wrist_loop] on \the [I]."))

/mob/living/human/verb/untie_lanyard()
	set name = "Untie Lanyard"
	set desc = "Untie the item in your hand from your lanyard."
	set category = "IC"
	var/obj/item/I = get_active_hand()
	if (!istype(I) || !I.lanyard_tied)
		to_chat(src, SPAN_WARNING("The item in your hand isn't tied to a lanyard."))
		return
	if (!may_do_after)
		return
	if (!do_after(src, LANYARD_UNTIE_TIME, I))
		return
	if (QDELETED(I) || get_active_hand() != I)
		return
	I.lanyard_tied = FALSE
	to_chat(src, SPAN_NOTICE("You untie \the [I] from your lanyard."))

#undef LANYARD_REGRIP_DELAY
#undef WRIST_LOOP_TIME
#undef LANYARD_UNTIE_TIME
