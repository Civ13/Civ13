// Barter: trade goods and a barter mat for fair face-to-face trades between
// players. See docs/barter.md. Players only: nothing here buys or sells for an
// NPC.
//
// Two people kneel at a barter mat. Each lays what they offer on their side.
// When both press Agree the offers swap hands. Any change to either offer, or
// either trader walking away, clears both agreements.

#define BARTER_ICON 'icons/obj/barter.dmi'

/obj/item/stack/barter_beads
	name = "beads"
	desc = "Strings of small drilled beads, worth trading."
	icon = BARTER_ICON
	icon_state = "beads_stone"
	singular_name = "string of beads"
	w_class = ITEM_SIZE_TINY
	amount = 1
	max_amount = 50
	flammable = FALSE
	value = 2

/obj/item/stack/barter_beads/stone
	name = "stone beads"
	desc = "Strings of small ground and drilled stone beads, worth trading."
	icon_state = "beads_stone"
	singular_name = "string of stone beads"

/obj/item/stack/barter_beads/bone
	name = "bone beads"
	desc = "Strings of small polished bone beads, worth trading."
	icon_state = "beads_bone"
	singular_name = "string of bone beads"
	value = 1

/obj/item/stack/barter_beads/chitin
	name = "chitin beads"
	desc = "Strings of small polished crab-shell beads, worth trading."
	icon_state = "beads_chitin"
	singular_name = "string of chitin beads"
	value = 1

/obj/structure/barter_mat
	name = "barter mat"
	desc = "A mat with a line down the middle. Two traders each lay their offer on their side, and when both agree the offers change hands."
	icon = BARTER_ICON
	icon_state = "barter_mat"
	anchored = TRUE
	density = FALSE
	flammable = TRUE
	not_movable = FALSE
	not_disassemblable = FALSE
	layer = 2.9
	var/list/traders = list() // two mobs at most
	var/list/offers = list() // trader = list of items
	var/list/agreed = list() // traders who agreed
	var/tmp/agreement_revision = 0 // invalidates Agree responses from open prompts

/obj/structure/barter_mat/persistence_runtime_var(key)
	return key == "traders" || key == "offers" || key == "agreed" || key == "agreement_revision" || ..()

/obj/structure/barter_mat/after_load()
	..()
	traders = list()
	offers = list()
	agreed = list()
	invalidate_agreements()
	for (var/obj/item/I in contents)
		I.forceMove(get_turf(src))

/obj/structure/barter_mat/proc/invalidate_agreements()
	agreement_revision++
	agreed.Cut()

/obj/structure/barter_mat/proc/present(mob/M)
	return M && !QDELETED(M) && M.stat == CONSCIOUS && get_dist(M, src) <= 1

/obj/structure/barter_mat/proc/other_trader(mob/M)
	for (var/mob/T in traders)
		if (T != M)
			return T
	return null

// Gives back the offer of anyone who has walked away.
/obj/structure/barter_mat/proc/tidy()
	for (var/mob/T in traders.Copy())
		if (!present(T))
			leave(T)

/obj/structure/barter_mat/proc/leave(mob/T)
	var/list/offer = offers[T]
	for (var/obj/item/I in offer)
		if (I.loc == src)
			I.forceMove(get_turf(src))
	offers -= T
	traders -= T
	invalidate_agreements()
	update_icon()

/obj/structure/barter_mat/proc/join(mob/M)
	tidy()
	if (M in traders)
		return TRUE
	if (traders.len >= 2)
		return FALSE
	traders += M
	offers[M] = list()
	invalidate_agreements()
	return TRUE

/obj/structure/barter_mat/proc/offer(mob/M, obj/item/I)
	if (!join(M))
		return FALSE
	var/list/offer = offers[M]
	offer += I
	I.forceMove(src)
	invalidate_agreements()
	update_icon()
	return TRUE

/obj/structure/barter_mat/proc/take_back(mob/M)
	var/list/offer = offers[M]
	if (!length(offer))
		return FALSE
	for (var/obj/item/I in offer)
		if (I.loc == src)
			I.forceMove(get_turf(src))
	offer.Cut()
	invalidate_agreements()
	update_icon()
	return TRUE

/obj/structure/barter_mat/proc/agree(mob/M, reviewed_revision)
	tidy()
	if (reviewed_revision != agreement_revision || !(M in traders) || traders.len < 2)
		return FALSE
	agreed |= M
	if (agreed.len < 2)
		return FALSE
	return swap()

/obj/structure/barter_mat/proc/swap()
	var/mob/A = traders[1]
	var/mob/B = traders[2]
	if (!present(A) || !present(B))
		return FALSE
	var/list/to_b = offers[A]
	var/list/to_a = offers[B]
	for (var/obj/item/I in to_b)
		if (I.loc == src)
			I.forceMove(get_turf(B))
	for (var/obj/item/I in to_a)
		if (I.loc == src)
			I.forceMove(get_turf(A))
	log_game("Barter at ([x],[y],[z]): [key_name(A)] gave [offer_text(to_b)]; [key_name(B)] gave [offer_text(to_a)].")
	visible_message(SPAN_NOTICE("[A] and [B] strike a bargain."))
	traders.Cut()
	offers.Cut()
	invalidate_agreements()
	update_icon()
	return TRUE

/obj/structure/barter_mat/proc/offer_text(list/offer)
	var/list/names = list()
	for (var/obj/item/I in offer)
		names += istype(I, /obj/item/stack) ? "[I:amount] [I.name]" : "\a [I]"
	return length(names) ? english_list(names) : "nothing"

/obj/structure/barter_mat/update_icon()
	icon_state = length(contents) ? "barter_mat_goods" : "barter_mat"

/obj/structure/barter_mat/examine(mob/user, distance = -1, infix = "", suffix = "")
	. = ..()
	tidy()
	if (!traders.len)
		to_chat(user, "Nobody is trading here. Lay an item on it to make an offer.")
		return
	for (var/mob/T in traders)
		to_chat(user, "[T] offers [offer_text(offers[T])][(T in agreed) ? " and has agreed" : ""].")

/obj/structure/barter_mat/attackby(obj/item/I, mob/user)
	if (!ishuman(user) || istype(I, /obj/item/weapon/grab) || !user.canUnEquip(I))
		return ..()
	if (!present(user))
		return TRUE
	tidy()
	if (!(user in traders) && traders.len >= 2)
		to_chat(user, SPAN_WARNING("Two people are already trading here."))
		return TRUE
	user.drop_from_inventory(I)
	offer(user, I)
	user.visible_message(SPAN_NOTICE("[user] offers \the [I] on \the [src]."), SPAN_NOTICE("You offer \the [I]. Both traders must agree before anything changes hands."))
	var/mob/other = other_trader(user)
	if (other)
		to_chat(other, SPAN_NOTICE("[user] changed their offer. Agree again if you still want the trade."))
	return TRUE

/obj/structure/barter_mat/attack_hand(mob/user)
	if (!ishuman(user) || !present(user))
		return ..()
	tidy()
	if (!(user in traders))
		examine(user)
		return
	var/list/choices = list("Agree", "Take back my offer", "Leave the trade", "Cancel")
	var/reviewed_revision = agreement_revision
	var/choice = player_input(user, "[src]: [other_trader(user) ? "trading with [other_trader(user)]" : "waiting for someone to trade with"].", "Barter", null, "anything", choices, TRUE)
	if (QDELETED(src) || !choice || choice == "Cancel" || !present(user))
		return
	tidy()
	if (!(user in traders))
		return
	switch (choice)
		if ("Agree")
			if (reviewed_revision != agreement_revision)
				to_chat(user, SPAN_WARNING("The trade changed while this menu was open. Examine the current offers and open the mat again."))
			else if (traders.len < 2)
				to_chat(user, SPAN_WARNING("Nobody is trading with you yet."))
			else if (!agree(user, reviewed_revision))
				var/mob/other = other_trader(user)
				to_chat(user, SPAN_NOTICE("You agree to the trade. Waiting for [other]."))
				to_chat(other, SPAN_NOTICE("[user] agrees to the trade: you give [offer_text(offers[other])] for [offer_text(offers[user])]. Use the mat to agree."))
		if ("Take back my offer")
			take_back(user)
			to_chat(user, SPAN_NOTICE("You take back your offer."))
		if ("Leave the trade")
			leave(user)
			to_chat(user, SPAN_NOTICE("You leave the trade and take your offer back."))

/obj/structure/barter_mat/Destroy()
	for (var/obj/item/I in contents)
		I.forceMove(get_turf(src))
	traders = null
	offers = null
	agreed = null
	return ..()

#undef BARTER_ICON
